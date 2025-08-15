import SwiftUI

struct SiteWindDirection: Codable, Equatable, Hashable {
    var N:  String
    var NE: String
    var E:  String
    var SE: String
    var S:  String
    var SW: String
    var W:  String
    var NW: String
}

struct Site: Codable, Identifiable, Equatable, Hashable {
    var id: String
    var area: String
    var siteName: String
    var readingsNote: String
    var forecastNote: String
    var siteType: String
    var readingsAlt: String
    var readingsSource: String
    var readingsStation: String
    var pressureZoneReadingTime: String
    var siteLat: String
    var siteLon: String
    var sheetRow: Int
    var windDirection: SiteWindDirection
}

struct SitesResponse: Codable {
    let values: [[String]]
}

@MainActor
class SiteViewModel: ObservableObject {
    @Published var areaOrder: [String] = []
    @Published var sites: [Site] = []

    func getSites() async {
        guard let regionGoogleSheetID = AppRegionManager.shared.getRegionGoogleSheet(),
              let sitesURL = URL(string: "https://sheets.googleapis.com/v4/spreadsheets/\(regionGoogleSheetID)/values/Sites?alt=json&key=\(googleAPIKey)") else {
            print("Invalid or missing region Google Sheet ID for region: \(RegionManager.shared.activeAppRegion)")
            return
        }

        do {
            let response: SitesResponse = try await AppNetwork.shared.fetchJSONAsync(url: sitesURL, type: SitesResponse.self)
            var parsedSites: [Site] = []

            for (index, row) in response.values.enumerated() {
                guard index > 0, row.count >= 12, row[0] != "Yes" else { continue }
                let siteLat = row[10].trimmingCharacters(in: .whitespacesAndNewlines)
                let siteLon = row[11].trimmingCharacters(in: .whitespacesAndNewlines)
                guard Double(siteLat) != nil, Double(siteLon) != nil else {
                    print("Skipping row with invalid coordinates: \(row[10]), \(row[11])")
                    continue
                }

                let windDirection = SiteWindDirection(
                    N:  row.count > 12 ? row[12] : "",
                    NE: row.count > 13 ? row[13] : "",
                    E:  row.count > 14 ? row[14] : "",
                    SE: row.count > 15 ? row[15] : "",
                    S:  row.count > 16 ? row[16] : "",
                    SW: row.count > 17 ? row[17] : "",
                    W:  row.count > 18 ? row[18] : "",
                    NW: row.count > 19 ? row[19] : ""
                )

                parsedSites.append(Site(
                    id: "\(row[1])-\(row[2])",
                    area: row[1],
                    siteName: row[2],
                    readingsNote: row[3],
                    forecastNote: row[4],
                    siteType: row[5],
                    readingsAlt: row[6],
                    readingsSource: row[7],
                    readingsStation: row[8],
                    pressureZoneReadingTime: row[9],
                    siteLat: siteLat,
                    siteLon: siteLon,
                    sheetRow: index + 1,
                    windDirection: windDirection
                ))
            }

            self.sites = parsedSites
            self.areaOrder = await fetchAreaOrder()
        } catch {
            print("Failed to fetch Sites: \(error)")
            self.sites = []
            self.areaOrder = []
        }
    }

    private func fetchAreaOrder() async -> [String] {
        guard let regionGoogleSheetID = AppRegionManager.shared.getRegionGoogleSheet(),
              let areasURL = URL(string: "https://sheets.googleapis.com/v4/spreadsheets/\(regionGoogleSheetID)/values/Areas!A2:B?alt=json&key=\(googleAPIKey)") else {
            print("Invalid or missing region Google Sheet ID for Areas tab.")
            return []
        }

        do {
            let response: SitesResponse = try await AppNetwork.shared.fetchJSONAsync(url: areasURL, type: SitesResponse.self)
            let orderedAreas = response.values.compactMap { row -> String? in
                guard row.count >= 2 else { return nil }
                let exclude = row[0].trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "yes"
                let areaName = row[1].trimmingCharacters(in: .whitespacesAndNewlines)
                return exclude ? nil : areaName
            }
            return orderedAreas
        } catch {
            print("Failed to fetch Areas tab: \(error)")
            return []
        }
    }
}
