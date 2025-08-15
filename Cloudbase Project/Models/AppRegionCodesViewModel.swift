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
    
    @MainActor
    func getAppRegionCodes() async {
        let urlString = "https://sheets.googleapis.com/v4/spreadsheets/\(globalGoogleSheetID)/values/\(sheetName)?alt=json&key=\(googleAPIKey)"
        guard let url = URL(string: urlString) else {
            print("Invalid URL for app region codes")
            self.appRegionCodes = []
            return
        }
        
        do {
            let response: AppRegionCodesResponse = try await AppNetwork.shared.fetchJSONAsync(url: url, type: AppRegionCodesResponse.self)
            
            let codes: [AppRegionCode] = response.values.dropFirst(3).compactMap { row in
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
                
                guard !appRegion.isEmpty, !airportCode.isEmpty else {
                    print("Skipping row with missing critical fields: \(row)")
                    return nil
                }
                
                return AppRegionCode(
                    appRegion: appRegion,
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
            
            self.appRegionCodes = codes
            AppRegionCodesManager.shared.setAppRegionCodes(codes)
            
        } catch {
            print("Failed to fetch app region codes: \(error)")
            self.appRegionCodes = []
        }
    }
}
