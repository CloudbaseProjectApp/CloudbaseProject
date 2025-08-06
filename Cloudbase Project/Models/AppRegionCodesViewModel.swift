import SwiftUI
import Combine

// Note:  Use the globally available function calls in AppRegionManager to access data

struct AppRegionCode {
    let appRegion: String
    let airportCode: String
    let stationCode: String
    let name: String
    let AFD: String
    let soundingModel: String
    let windsAloft: String
    let soaringForecastRichSimple: String
    let soaringForecastBasic: String
    let weatherAlerts: String
}

struct AppRegionCodesResponse: Codable {
    let values: [[String]]
}

class AppRegionCodesViewModel: ObservableObject {
    @Published var appRegionCodes: [AppRegionCode] = []
    private var cancellables = Set<AnyCancellable>()
    let sheetName = "RegionCodes"
    
    // Instance Tracking code
    private let vmtype = "AppRegionCodesViewModel"
    private let instanceID = UUID()
    init() { print("✅ \(vmtype) \(instanceID) initialized") }
    deinit { print("🗑️ \(vmtype) \(instanceID) deinitialized") }

    func getAppRegionCodes(completion: @escaping () -> Void) {
        let appRegionCodesURLString = "https://sheets.googleapis.com/v4/spreadsheets/\(globalGoogleSheetID)/values/\(sheetName)?alt=json&key=\(googleAPIKey)"
        guard let url = URL(string: appRegionCodesURLString) else {
            print("Invalid URL for app region codes")
            DispatchQueue.main.async { completion() }
            return
        }
        URLSession.shared.dataTaskPublisher(for: url)
            .map { $0.data }
            .decode(type: AppRegionCodesResponse.self, decoder: JSONDecoder())
        
            .map { response -> [AppRegionCode] in
                // Skip first three header rows
                response.values.dropFirst(3).compactMap { row in
                    guard row.count >= 2 else {
                        print("Skipping malformed app region code row: \(row)")
                        return nil
                    }
                    let appRegion = row[0]
                    let airportCode = row[1]
                    let stationCode = row.count > 2 ? row[2] : ""
                    let name = row.count > 3 ? row[3] : ""
                    let AFD = row.count > 4 ? row[4] : ""
                    let soundingModel = row.count > 5 ? row[5] : ""
                    let windsAloft = row.count > 6 ? row[6] : ""
                    let soaringForecastRichSimple = row.count > 7 ? row[7] : ""
                    let soaringForecastBasic = row.count > 8 ? row[8] : ""
                    let weatherAlerts = row.count > 9 ? row[9] : ""
                    
                    // Make sure region, airport code are populated
                    guard !appRegion.isEmpty,
                          !airportCode.isEmpty else {
                        print("Skipping app region code row with missing critical fields: \(row)")
                        return nil
                    }
                    
                    return AppRegionCode(appRegion: appRegion,
                                     airportCode: airportCode,
                                     stationCode: stationCode,
                                     name: name,
                                     AFD: AFD,
                                     soundingModel: soundingModel,
                                     windsAloft: windsAloft,
                                     soaringForecastRichSimple: soaringForecastRichSimple,
                                     soaringForecastBasic: soaringForecastBasic,
                                     weatherAlerts: weatherAlerts
                    )
                }
            }
            .replaceError(with: [])
            .receive(on: DispatchQueue.main)

            // Save region codess globally so they can be accessed from anywhere in the app
            .handleEvents(receiveOutput: { [weak self] appRegionCodes in
                self?.appRegionCodes = appRegionCodes
                AppRegionCodesManager.shared.setAppRegionCodes(appRegionCodes) // global set
            }, receiveCompletion: { _ in
                completion()
            })
        
            .sink { _ in }
            .store(in: &cancellables)
    }
    
}
