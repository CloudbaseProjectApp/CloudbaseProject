import SwiftUI
import Combine
import MapKit

// Pilot live tracking structure
struct PilotTrack: Identifiable, Equatable, Hashable {
    let id: UUID = UUID()
    let pilotName: String   // For consistency, this is set based on pilots.pilotName, not pilot name from InReach data
    let dateTime: Date
    let latitude: Double
    let longitude: Double
    let speed: Double
    let altitude: Double
    let heading: Double
    let inEmergency: Bool
    let message: String?
}

// Listing of pilot live tracks by pilot name and date
// used to determine track groupings for line rendering on track
struct PilotTrackKey: Hashable {
    let pilotName: String
    let date: Date
}

// Annotation for pilot tracks to allow polylines as an overlay on map
class PilotTrackAnnotation: NSObject, MKAnnotation {
    let coordinate: CLLocationCoordinate2D
    let title: String?
    let subtitle: String?
    let annotationType: String
    let pilotTrack: PilotTrack?

    let pilotName: String
    let isFirst: Bool
    let isLast: Bool
    let isEmergency: Bool
    let hasMessage: Bool
    
    init(coordinate: CLLocationCoordinate2D,
         title: String?,
         subtitle: String?,
         annotationType: String,
         pilotTrack: PilotTrack?,
         pilotName: String,
         isFirst: Bool,
         isLast: Bool,
         isEmergency: Bool,
         hasMessage: Bool
    ) {
        self.coordinate = coordinate
        self.title = title
        self.subtitle = subtitle
        self.annotationType = annotationType
        self.pilotTrack = pilotTrack
        self.pilotName = pilotName
        self.isFirst = isFirst
        self.isLast = isLast
        self.isEmergency = isEmergency
        self.hasMessage = hasMessage        
    }
    
}

@MainActor
class PilotTrackViewModel: ObservableObject {
    @Published private(set) var pilotTracks: [PilotTrack] = []
    @Published var isLoading = false

    private let pilotViewModel: PilotViewModel
    private var cancellables = Set<AnyCancellable>()
    
    private let maxConcurrentRequests = 8
    private var inflightTasks: [Task<Void, Never>] = []
    private var cacheDate: Date = Calendar.current.startOfDay(for: Date())

    private struct CacheEntry {
        let urlString: String
        var lastFetch: Date
        var lastDays: Double
        var tracks: [PilotTrack]
    }
    private var cache: [String: CacheEntry] = [:]

    init(pilotViewModel: PilotViewModel) {
        self.pilotViewModel = pilotViewModel
        pilotViewModel.$pilots
            .sink { _ in /* no-op */ }
            .store(in: &cancellables)
    }

    func getPilotTracks(days: Double, selectedPilots: [Pilot], completion: @escaping () -> Void) {
        let today = Calendar.current.startOfDay(for: Date())
        if today > cacheDate {
            cache.removeAll()
            cacheDate = today
        }

        let pilotsToConsider = selectedPilots.isEmpty ? pilotViewModel.pilots : selectedPilots
        isLoading = true
        inflightTasks.forEach { $0.cancel() }
        inflightTasks.removeAll()

        let task = Task { [weak self] in
            guard let self = self else { return }
            let freshTracks = await self.fetchAllTracks(pilots: pilotsToConsider, days: days)
            self.pilotTracks = freshTracks.sorted { $0.dateTime < $1.dateTime }
            self.isLoading = false
            completion()
        }
        inflightTasks.append(task)
    }

    private func fetchAllTracks(pilots: [Pilot], days: Double) async -> [PilotTrack] {
        let semaphore = AsyncSemaphore(value: maxConcurrentRequests)
        return await withTaskGroup(of: [PilotTrack].self) { group in
            for pilot in pilots {
                group.addTask {
                    await semaphore.wait()
                    defer { Task { await semaphore.signal() } }
                    return await self.fetchTracks(for: pilot, days: days)
                }
            }

            var combined: [PilotTrack] = []
            for await chunk in group { combined.append(contentsOf: chunk) }
            return combined
        }
    }

    private func fetchTracks(for pilot: Pilot, days: Double) async -> [PilotTrack] {
        guard !pilot.inactive,
              let url = constructURL(trackingURL: pilot.trackingFeedURL, days: days) else { return [] }
        let urlStr = url.absoluteString

        if let entry = cache[pilot.pilotName],
           entry.urlString == urlStr,
           entry.lastDays == days,
           Date().timeIntervalSince(entry.lastFetch) < pilotTrackRefreshInterval
        {
            return entry.tracks
        }

        do {
            let kmlText = try await AppNetwork.shared.fetchTextAsync(url: url)
            let parsed = parseKML(pilotName: pilot.pilotName, text: kmlText)
            cache[pilot.pilotName] = CacheEntry(urlString: urlStr, lastFetch: Date(), lastDays: days, tracks: parsed)
            return parsed
        } catch {
            print("Error fetching tracks for \(pilot.pilotName): \(error)")
            return []
        }
    }

    private func constructURL(trackingURL: String, days: Double) -> URL? {
        let date = getDateForDays(days: days)
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime]
        let dateString = iso.string(from: date)
        return URL(string: "\(trackingURL)?d1=\(dateString)")
    }

    private func parseKML(pilotName: String, text: String) -> [PilotTrack] {
        let placemarks = extractAllValues(from: text, using: "<Placemark>", endTag: "</Placemark>")
        guard !placemarks.isEmpty else { return [] }

        let formatter = DateFormatter()
        formatter.dateFormat = "M/d/yyyy h:mm:ss a"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(abbreviation: "UTC")

        return placemarks.compactMap { pm in
            guard
                let timeStr = extractValue(from: pm, using: "<Data name=\"Time UTC\">", endTag: "</Data>"),
                let latStr = extractValue(from: pm, using: "<Data name=\"Latitude\">", endTag: "</Data>"),
                let lonStr = extractValue(from: pm, using: "<Data name=\"Longitude\">", endTag: "</Data>")
            else { return nil }

            let dateTime = formatter.date(from: timeStr) ?? Date()
            let speedKM = extractNumber(from: extractValue(from: pm, using: "<Data name=\"Velocity\">", endTag: "</Data>") ?? "") ?? 0
            let speed = convertKMToMiles(speedKM).rounded()
            let altM = extractNumber(from: extractValue(from: pm, using: "<Data name=\"Elevation\">", endTag: "</Data>") ?? "") ?? 0
            let altitude = Double(convertMetersToFeet(altM))
            let course = extractNumber(from: extractValue(from: pm, using: "<Data name=\"Course\">", endTag: "</Data>") ?? "") ?? 0
            let inEmg = Bool(extractValue(from: pm, using: "<Data name=\"In Emergency\">", endTag: "</Data>")?.lowercased() ?? "false") ?? false
            let message = extractValue(from: pm, using: "<Data name=\"Text\">", endTag: "</Data>")

            return PilotTrack(
                pilotName: pilotName,
                dateTime: dateTime,
                latitude: Double(latStr) ?? 0,
                longitude: Double(lonStr) ?? 0,
                speed: speed,
                altitude: altitude,
                heading: course,
                inEmergency: inEmg,
                message: message
            )
        }
    }

    private func extractAllValues(from text: String, using startTag: String, endTag: String) -> [String] {
        var results: [String] = []
        var searchRange: Range<String.Index>? = text.startIndex..<text.endIndex
        while let start = text.range(of: startTag, range: searchRange),
              let end = text.range(of: endTag, range: start.upperBound..<text.endIndex)
        {
            results.append(String(text[start.upperBound..<end.lowerBound]))
            searchRange = end.upperBound..<text.endIndex
        }
        return results
    }

    private func extractValue(from text: String, using startTag: String, endTag: String) -> String? {
        guard
            let start = text.range(of: startTag),
            let end = text.range(of: endTag, range: start.upperBound..<text.endIndex)
        else { return nil }
        let tagContents = String(text[start.upperBound..<end.lowerBound])
        guard let vStart = tagContents.range(of: "<value>"),
              let vEnd = tagContents.range(of: "</value>", range: vStart.upperBound..<tagContents.endIndex)
        else { return nil }
        return String(tagContents[vStart.upperBound..<vEnd.lowerBound])
    }

    actor AsyncSemaphore {
        private var available: Int
        private var waiters: [CheckedContinuation<Void, Never>] = []

        init(value: Int) { self.available = value }

        func wait() async {
            if available > 0 { available -= 1 }
            else { await withCheckedContinuation { cont in waiters.append(cont) } }
        }

        func signal() {
            if let cont = waiters.first {
                waiters.removeFirst()
                cont.resume()
            } else { available += 1 }
        }
    }
}
