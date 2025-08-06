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

class WeatherCamViewModel: ObservableObject {
    @Published var weatherCams: [WeatherCam] = []
    @Published var groupedWeatherCams: [String: [WeatherCam]] = [:]
    @Published var isLoading: Bool = false
    
    private(set) var siteViewModel: SiteViewModel?
    
    // Instance Tracking code
    private let vmtype = "WeatherCamViewModel"
    private let instanceID = UUID()
    init() { print("✅ \(vmtype) \(instanceID) initialized") }
    deinit { print("🗑️ \(vmtype) \(instanceID) deinitialized") }


    func setSiteViewModel(_ siteViewModel: SiteViewModel) {
        self.siteViewModel = siteViewModel
    }

    func fetchWeatherCams() {
        guard siteViewModel != nil else {
            print("Missing SiteViewModel — skipping fetch for weather cams")
            return
        }

        DispatchQueue.main.async {
            self.isLoading = true
        }
        
        let rangeName = "WeatherCams"
        
        // Build region sheet URL
        guard let regionGoogleSheetID = AppRegionManager.shared.getRegionGoogleSheet(),
              let regionURL = URL(string: "https://sheets.googleapis.com/v4/spreadsheets/\(regionGoogleSheetID)/values/\(rangeName)?alt=json&key=\(googleAPIKey)") else {
            print("Invalid or missing region Google Sheet ID for region: \(RegionManager.shared.activeAppRegion)")
            DispatchQueue.main.async {
                self.isLoading = false
            }
            return
        }

        URLSession.shared.dataTask(with: regionURL) { [weak self] data, response, error in
            guard let self = self else { return }
            
            defer {
                // Always hide the progress indicator when this closure exits
                DispatchQueue.main.async {
                    self.isLoading = false
                }
            }
            
            if let error = error {
                print("Failed to fetch data: \(error.localizedDescription)")
                return
            }
            guard let data = data else {
                print("No data received")
                return
            }
            
            do {
                let response = try JSONDecoder().decode(WeatherCamGoogleSheetResponse.self, from: data)
                
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
                            name:     row[2],
                            linkURL:  row[3],
                            imageURL: row[4]
                        )
                    }
                
                DispatchQueue.main.async {
                    self.weatherCams = cams
                    self.groupedWeatherCams = Dictionary(grouping: cams, by: \.area)
                }
                
            } catch {
                print("Failed to decode JSON: \(error)")
            }
        }
        .resume()
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
