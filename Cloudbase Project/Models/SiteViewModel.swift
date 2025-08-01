import SwiftUI
import Combine

struct Site: Codable, Identifiable, Equatable, Hashable {
    var id = UUID()
    var area: String
    var siteName: String
    var readingsNote: String
    var forecastNote: String
    var siteType: String        // sites have types of Soaring, Mountain, Airport, or blank
                                // Detailed forecast uses type of Aloft
                                // Map view and favorites also use type of Station
    var readingsAlt: String
    var readingsSource: String
    var readingsStation: String
    var pressureZoneReadingTime: String
    var siteLat: String
    var siteLon: String
    var sheetRow: Int           // Used to manage updates to Google sheet via API
    var windDirectionN: String  // Used to specify good/ok wind directions for flying
    var windDirectionNE: String
    var windDirectionE: String
    var windDirectionSE: String
    var windDirectionS: String
    var windDirectionSW: String
    var windDirectionW: String
    var windDirectionNW: String
}

struct SitesResponse: Codable {
    let values: [[String]]
}

class SiteViewModel: ObservableObject {
    @Published var areaOrder: [String] = []
    @Published var sites: [Site] = []
    private var cancellables = Set<AnyCancellable>()
    
    func getSites(completion: @escaping () -> Void) {
        let rangeName = "Sites"
        
        guard let regionGoogleSheetID = AppRegionManager.shared.getRegionGoogleSheet(),
              let regionURL = URL(string: "https://sheets.googleapis.com/v4/spreadsheets/\(regionGoogleSheetID)/values/\(rangeName)?alt=json&key=\(googleAPIKey)") else {
            print("Invalid or missing region Google Sheet ID for region: \(RegionManager.shared.activeAppRegion)")
            DispatchQueue.main.async { completion() }
            return
        }

        URLSession.shared.dataTaskPublisher(for: regionURL)
            .map { $0.data }
            .decode(type: SitesResponse.self, decoder: JSONDecoder())
            .map { response in
                response.values.enumerated().compactMap { index, row -> Site? in
                    guard index > 0 else { return nil }
                    guard row.count >= 12 else { return nil }
                    guard row[0] != "Yes" else { return nil }
                    let siteLat = row[10].trimmingCharacters(in: .whitespacesAndNewlines)
                    let siteLon = row[11].trimmingCharacters(in: .whitespacesAndNewlines)
                    guard let _ = Double(siteLat), let _ = Double(siteLon) else {
                        print("Skipping row with invalid coordinates: \(row[10]), \(row[11])")
                        return nil
                    }

                    return Site(
                        area:               row[1],
                        siteName:           row[2],
                        readingsNote:       row[3],
                        forecastNote:       row[4],
                        siteType:           row[5],
                        readingsAlt:        row[6],
                        readingsSource:     row[7],
                        readingsStation:    row[8],
                        pressureZoneReadingTime: row[9],
                        siteLat:            siteLat,
                        siteLon:            siteLon,
                        sheetRow:           index + 1,
                        windDirectionN:     row.count > 12 ? row[12] : "",
                        windDirectionNE:    row.count > 13 ? row[13] : "",
                        windDirectionE:     row.count > 14 ? row[14] : "",
                        windDirectionSE:    row.count > 15 ? row[15] : "",
                        windDirectionS:     row.count > 16 ? row[16]: "",
                        windDirectionSW:    row.count > 17 ? row[17] : "",
                        windDirectionW:     row.count > 18 ? row[18]: "",
                        windDirectionNW:    row.count > 19 ? row[19] : ""
                    )
                }
            }
            .replaceError(with: [])
            .receive(on: DispatchQueue.main)
            .sink { [weak self] sites in
                self?.sites = sites

                self?.fetchAreaOrder { orderedAreas in
                    DispatchQueue.main.async {
                        self?.areaOrder = orderedAreas
                        completion()
                    }
                }
            }
            .store(in: &cancellables)
    }

    func fetchAreaOrder(completion: @escaping ([String]) -> Void) {
        let rangeName = "Areas"

        guard let regionGoogleSheetID = AppRegionManager.shared.getRegionGoogleSheet(),
              let areaURL = URL(string: "https://sheets.googleapis.com/v4/spreadsheets/\(regionGoogleSheetID)/values/\(rangeName)!A2:B?alt=json&key=\(googleAPIKey)") else {
            print("Invalid or missing region Google Sheet ID for Areas tab.")
            completion([])
            return
        }

        URLSession.shared.dataTask(with: areaURL) { data, response, error in
            guard let data = data,
                  let response = try? JSONDecoder().decode(SitesResponse.self, from: data) else {
                print("Failed to fetch or parse Areas tab.")
                completion([])
                return
            }

            // Column A = Exclude flag, Column B = Area name
            let orderedAreas = response.values.compactMap { row -> String? in
                guard row.count >= 2 else { return nil }

                let exclude = row[0].trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "yes"
                let areaName = row[1].trimmingCharacters(in: .whitespacesAndNewlines)

                return exclude ? nil : areaName
            }

            completion(orderedAreas)
        }.resume()
    }
    
}
