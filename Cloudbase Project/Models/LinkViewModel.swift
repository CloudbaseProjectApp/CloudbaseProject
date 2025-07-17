import SwiftUI
import Combine

struct LinkGoogleSheetResponse: Codable {
    let range: String
    let majorDimension: String
    let values: [[String]]
}

struct LinkItem: Identifiable {
    let id = UUID()
    let category: String
    let title: String
    let description: String
    let link: String
}

import Combine

class LinkViewModel: ObservableObject {
    @Published var groupedLinks: [String: [LinkItem]] = [:]
    @Published var isLoading = false

    private var cancellable: AnyCancellable?

    func fetchLinks(appRegion: String) {
        isLoading = true
        
        let rangeName = "Links"
        
        // Build global sheet URL
        guard let globalURL = URL(string: "https://sheets.googleapis.com/v4/spreadsheets/\(globalGoogleSheetID)/values/\(rangeName)?alt=json&key=\(googleAPIKey)") else {
            print("Invalid global Google Sheet URL")
            isLoading = false
            return
        }
        
        guard let regionGoogleSheetID = AppRegionManager.shared.getRegionGoogleSheet(appRegion: appRegion),
              let regionURL = URL(string: "https://sheets.googleapis.com/v4/spreadsheets/\(regionGoogleSheetID)/values/\(rangeName)?alt=json&key=\(googleAPIKey)") else {
            print("Invalid or missing region Google Sheet ID for region: \(appRegion)")
            isLoading = false
            return
        }

        // Coomon decoding logic
        func fetchAndParse(from url: URL) -> AnyPublisher<[String: [LinkItem]], Never> {
            URLSession.shared.dataTaskPublisher(for: url)
                .map(\.data)
                .decode(type: LinkGoogleSheetResponse.self, decoder: JSONDecoder())
                .map { response -> [String:[LinkItem]] in
                    let dataRows = response.values.dropFirst()
                    let linkItems = dataRows.compactMap { row -> LinkItem? in
                        guard row.count >= 4,
                              !row[3].trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        else { return nil }
                        return LinkItem(category: row[0],
                                        title: row[1],
                                        description: row[2],
                                        link: row[3])
                    }
                    return Dictionary(grouping: linkItems, by: \.category)
                }
                .replaceError(with: [:])
                .eraseToAnyPublisher()
        }

        // Fetch both sheets concurrently and combine results
        let globalPublisher = fetchAndParse(from: globalURL)
        let regionPublisher = fetchAndParse(from: regionURL)

        cancellable = Publishers.CombineLatest(globalPublisher, regionPublisher)
            .map { global, region -> [String: [LinkItem]] in
                var combined = global
                for (category, items) in region {
                    combined[category, default: []] += items
                }
                return combined
            }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] combinedLinks in
                self?.groupedLinks = combinedLinks
                self?.isLoading = false
            }
    }
}
