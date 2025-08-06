import SwiftUI
import Combine

// Note:  Use the globally available function calls in AppRegionManager to access data

struct AppRegion {
    let appRegion: String                   // Two digit code for U.S. states (used in Synoptics station map call)
                                            // AppRegion must be unique (without appCountry); so do not use US states for other regions
    let appCountry: String                  // Two or three digit country code (US, CA, MX, NZ, etc.) (used in Synoptics station map call)
    let appRegionName: String
    let appRegionGoogleSheetID: String
    let timezone: String                    // Use TZ Identifier values from: https://en.wikipedia.org/wiki/List_of_tz_database_time_zones
    let sunriseLatitude: Double
    let sunriseLongitude: Double
    let mapInitLatitude: Double             // Center point for map on initial opening
    let mapInitLongitude: Double
    let mapInitLatitudeSpan: Double         // Size of map on initial opening
    let mapInitLongitudeSpan: Double        // mapInitLatitudeSpan * 1.5
    let mapDefaultZoomLevel: Double
    let appRegionStatus: String             // "Development" or blank
}

struct AppRegionResponse: Codable {
    let values: [[String]]
}

class AppRegionViewModel: ObservableObject {
    @Published var appRegions: [AppRegion] = []
    private var cancellables = Set<AnyCancellable>()
    
    // Instance Tracking code
    private let vmtype = "AppRegionViewModel"
    private let instanceID = UUID()
    init() { print("✅ \(vmtype) \(instanceID) initialized") }
    deinit { print("🗑️ \(vmtype) \(instanceID) deinitialized") }

    let sheetName = "Regions"
    
    func getAppRegions(completion: @escaping () -> Void) {
        let appRegionsURLString = "https://sheets.googleapis.com/v4/spreadsheets/\(globalGoogleSheetID)/values/\(sheetName)?alt=json&key=\(googleAPIKey)"
        guard let url = URL(string: appRegionsURLString) else {
            print("Invalid URL for app regions")
            DispatchQueue.main.async { completion() }
            return
        }
        URLSession.shared.dataTaskPublisher(for: url)
            .map { $0.data }
            .decode(type: AppRegionResponse.self, decoder: JSONDecoder())
        
            .map { response -> [AppRegion] in
                response.values.dropFirst().compactMap { row in
                    guard row.count >= 5 else {
                        print("Skipping malformed app region row: \(row)")
                        return nil
                    }
                    let appRegion               = row[0]
                    let appCountry              = row[1]
                    let appRegionName           = row[2]
                    let appRegionGoogleSheetID  = row[3]
                    let timezone                = row[4]
                    let sunriseLatitude         = row.count > 5 ? Double(row[5]) ?? 0.0 : 0.0
                    let sunriseLongitude        = row.count > 6 ? Double(row[6]) ?? 0.0 : 0.0
                    let mapInitLatitude         = row.count > 7 ? Double(row[7]) ?? 0.0 : 0.0
                    let mapInitLongitude        = row.count > 8 ? Double(row[8]) ?? 0.0 : 0.0
                    let mapInitLatitudeSpan     = row.count > 9 ? Double(row[9]) ?? 0.0 : 0.0
                    let mapInitLongitudeSpan    = row.count > 10 ? Double(row[10]) ?? 0.0 : 0.0
                    let mapDefaultZoomLevel     = row.count > 11 ? Double(row[11]) ?? 0.0 : 0.0
                    let appRegionStatus         = row.count > 12 ? row[12] : ""
                    
                    // Make sure region, country, name, Google sheet, and time zone are populated
                    guard !appRegion.isEmpty,
                          !appCountry.isEmpty,
                          !appRegionName.isEmpty,
                          !appRegionGoogleSheetID.isEmpty,
                          !timezone.isEmpty else {
                        print("Skipping app region row with missing critical fields: \(row)")
                        return nil
                    }
                    
                    return AppRegion(appRegion:                 appRegion,
                                     appCountry:                appCountry,
                                     appRegionName:             appRegionName,
                                     appRegionGoogleSheetID:    appRegionGoogleSheetID,
                                     timezone:                  timezone,
                                     sunriseLatitude:           sunriseLatitude,
                                     sunriseLongitude:          sunriseLongitude,
                                     mapInitLatitude:           mapInitLatitude,
                                     mapInitLongitude:          mapInitLongitude,
                                     mapInitLatitudeSpan:       mapInitLatitudeSpan,
                                     mapInitLongitudeSpan:      mapInitLongitudeSpan,
                                     mapDefaultZoomLevel:       mapDefaultZoomLevel,
                                     appRegionStatus:           appRegionStatus
                    )
                }
            }
            .replaceError(with: [])
            .receive(on: DispatchQueue.main)

            // Save regions globally so they can be accessed from anywhere in the app
            .handleEvents(receiveOutput: { [weak self] appRegions in
                self?.appRegions = appRegions
                AppRegionManager.shared.setAppRegions(appRegions) // global set
            }, receiveCompletion: { _ in
                completion()
            })
        
            .sink { _ in }
            .store(in: &cancellables)
    }
    
}
