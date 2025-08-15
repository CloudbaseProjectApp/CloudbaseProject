import SwiftUI
import Combine

struct WindsAloftReading {
    let altitude: Int
    let windDirection: Int?
    let windSpeed: Int?
    let temperature: Int?
}

@MainActor
class WindsAloftViewModel: ObservableObject {
    @Published var readings: [WindsAloftReading] = []
    @Published var cycle: String = ""
    @Published var isLoading = false
    
    func getWindsAloftData(airportCode: String) async {
        isLoading = true
        
        guard let baseURL = AppURLManager.shared.getAppURL(URLName: "windsAloftURL") else {
            print("Could not find winds aloft URL for appRegion: \(RegionManager.shared.activeAppRegion)")
            isLoading = false
            return
        }
        
        let cycle = windsAloftCycle()
        self.cycle = cycle
        let updatedURL = updateURL(url: baseURL, parameter: "cycle", value: cycle)
        
        guard let url = URL(string: updatedURL) else {
            print("Invalid winds aloft URL for appRegion: \(RegionManager.shared.activeAppRegion)")
            isLoading = false
            return
        }
        
        do {
            let dataString = try await AppNetwork.shared.fetchTextAsync(url: url)
            parseWindsAloftData(code: airportCode, data: dataString)
        } catch {
            print("Failed to fetch winds aloft data: \(error)")
            isLoading = false
        }
    }
    
    private func parseWindsAloftData(code: String, data: String) {
        let lines = data.split(separator: "\n")
        guard let regionLine = lines.first(where: { $0.starts(with: code) }) else {
            print("Could not find a matching row for code: \(code)")
            isLoading = false
            return
        }

        let offsets: [(altitude: Int, range: Range<Int>)] = [
            (6000, 9..<16),
            (9000, 17..<24),
            (12000, 25..<32),
            (18000, 33..<40)
        ]

        var newReadings: [WindsAloftReading] = []

        for (altitude, range) in offsets {
            if range.upperBound <= regionLine.count {
                let start = regionLine.index(regionLine.startIndex, offsetBy: range.lowerBound)
                let end = regionLine.index(regionLine.startIndex, offsetBy: range.upperBound)
                let substring = regionLine[start..<end].trimmingCharacters(in: .whitespaces)

                if !substring.isEmpty, let parsedReading = parseReading(substring, altitude: altitude) {
                    newReadings.append(parsedReading)
                }
            }
        }

        self.readings = newReadings.reversed()
        self.isLoading = false
    }
    
    private func parseReading(_ reading: String, altitude: Int) -> WindsAloftReading? {
        guard reading.count >= 4 else { return nil }

        // Parse wind direction
        let windDirSource = reading.prefix(2)
        var windDirection: Int? = (windDirSource == "  ") ? nil : 10 * (Int(windDirSource) ?? 0)

        // Parse wind speed
        let windSpeedSource = reading.dropFirst(2).prefix(2)
        var windSpeedKnots: Int? = (windSpeedSource == "  ") ? nil : (Int(windSpeedSource) ?? 0)
        
        if let direction = windDirection, direction > 360 && direction < 990 {
            windDirection = direction - 360
            windSpeedKnots = (windSpeedKnots ?? 0) + 100
        }
        
        let windSpeed: Int? = (windSpeedSource == "  ") ? nil : convertKnotsToMPH(windSpeedKnots ?? 0)
        
        if let direction = windDirection {
            windDirection = (direction + 180) % 360
        }
        
        var temperature: Int? = nil
        if reading.count > 4 {
            let tempString = reading.dropFirst(4)
            if let tempValue = Int(tempString) {
                temperature = convertCelsiusToFahrenheit(tempValue)
            }
        }
        
        return WindsAloftReading(
            altitude: altitude,
            windDirection: windDirection,
            windSpeed: windSpeed,
            temperature: temperature
        )
    }
}
