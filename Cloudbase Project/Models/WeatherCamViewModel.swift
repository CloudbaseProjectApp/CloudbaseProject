import SwiftUI
import Combine

struct WeatherCam: Identifiable {
    let id = UUID()
    let area: String
    let name: String
    let linkURL: String
    let imageURL: String
}

struct WeatherCamGoogleSheetResponse: Codable {
    let values: [[String]]
}

@MainActor
class WeatherCamViewModel: ObservableObject {
    @Published var weatherCams: [WeatherCam] = []
    @Published var groupedWeatherCams: [String: [WeatherCam]] = [:]
    @Published var isLoading: Bool = false
    
    private(set) var siteViewModel: SiteViewModel?

    func setSiteViewModel(_ siteViewModel: SiteViewModel) {
        self.siteViewModel = siteViewModel
    }

    func fetchWeatherCams() async {
        guard siteViewModel != nil else {
            print("Missing SiteViewModel — skipping fetch for weather cams")
            return
        }
        
        isLoading = true
        
        let rangeName = "WeatherCams"
        
        // Build region sheet URL
        guard let regionGoogleSheetID = AppRegionManager.shared.getRegionGoogleSheet(),
              let regionURL = URL(string: "https://sheets.googleapis.com/v4/spreadsheets/\(regionGoogleSheetID)/values/\(rangeName)?alt=json&key=\(googleAPIKey)") else {
            print("Invalid or missing region Google Sheet ID for region: \(RegionManager.shared.activeAppRegion)")
            isLoading = false
            return
        }

        do {
            let response: WeatherCamGoogleSheetResponse = try await AppNetwork.shared.fetchJSONAsync(url: regionURL, type: WeatherCamGoogleSheetResponse.self)
            
            let skipCondition: ([String]) -> Bool = { row in
                row.first == "Yes"
            }
            
            let cams: [WeatherCam] = response.values
                .dropFirst() // skip header row
                .compactMap { row in
                    guard row.count >= 5 else {
                        print("Skipping malformed row (not enough columns): \(row)")
                        return nil
                    }
                    if skipCondition(row) {
                        return nil
                    }
                    return WeatherCam(
                        area: row[1],
                        name: row[2],
                        linkURL: row[3],
                        imageURL: row[4]
                    )
                }
            
            weatherCams = cams
            groupedWeatherCams = Dictionary(grouping: cams, by: \.area)
            
        } catch {
            print("Failed to fetch or decode weather cams: \(error)")
        }
        
        isLoading = false
    }
    
    func sortedGroupedWeatherCams() -> [(String, [WeatherCam])] {
        let existing = groupedWeatherCams
        var result: [(String, [WeatherCam])] = []

        if let siteViewModel = siteViewModel {
            // 1. Add areas in specified order
            for area in siteViewModel.areaOrder {
                if let cams = existing[area] {
                    result.append((area, cams))
                }
            }

            // 2. Append remaining areas not in areaOrder
            let remaining = existing.keys
                .filter { !siteViewModel.areaOrder.contains($0) }
                .sorted()
            for area in remaining {
                if let cams = existing[area] {
                    result.append((area, cams))
                }
            }
        } else {
            // Fallback: return in default dictionary insertion order
            result = Array(existing)
        }

        return result
    }
}
