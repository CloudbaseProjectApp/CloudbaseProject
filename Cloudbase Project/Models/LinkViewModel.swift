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

class LinkViewModel: ObservableObject {
    @Published var groupedLinks: [String: [LinkItem]] = [:]
    @Published var orderedGroupNames: [String] = []
    @Published var isLoading = false
    
    private var cancellable: AnyCancellable?
    
    func fetchLinks() {
        isLoading = true
        let linksRange = "Links"

        guard let regionGoogleSheetID = AppRegionManager.shared.getRegionGoogleSheet() else {
            print("Region Google Sheet ID not available")
            isLoading = false
            return
        }

        guard let globalLinksURL = URL(string: "https://sheets.googleapis.com/v4/spreadsheets/\(globalGoogleSheetID)/values/\(linksRange)?alt=json&key=\(googleAPIKey)"),
              let regionLinksURL = URL(string: "https://sheets.googleapis.com/v4/spreadsheets/\(regionGoogleSheetID)/values/\(linksRange)?alt=json&key=\(googleAPIKey)") else {
            print("Invalid sheet URLs")
            isLoading = false
            return
        }

        // Step 1: Fetch LinkGroups first
        fetchLinkGroupOrder { [weak self] groupOrder in
            guard let self = self else { return }

            self.orderedGroupNames = groupOrder

            // Step 2: Fetch global and region links concurrently
            let globalPublisher = self.fetchAndParseLinks(from: globalLinksURL)
            let regionPublisher = self.fetchAndParseLinks(from: regionLinksURL)

            self.cancellable = Publishers.CombineLatest(globalPublisher, regionPublisher)
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
    
    // Parses a given link sheet into [Category: [LinkItem]]
    private func fetchAndParseLinks(from url: URL) -> AnyPublisher<[String: [LinkItem]], Never> {
        Future { promise in
            AppNetwork.shared.fetchJSON(url: url, type: LinkGoogleSheetResponse.self) { result in
                switch result {
                case .success(let response):
                    let dataRows = response.values.dropFirst()
                    let linkItems = dataRows.compactMap { row -> LinkItem? in
                        guard row.count >= 4,
                              !row[3].trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        else { return nil }
                        return LinkItem(
                            category: row[0],
                            title: row[1],
                            description: row[2],
                            link: row[3]
                        )
                    }
                    let grouped = Dictionary(grouping: linkItems, by: \.category)
                    promise(.success(grouped))
                    
                case .failure(let error):
                    print("Failed to fetch links: \(error)")
                    promise(.success([:]))
                }
            }
        }
        .eraseToAnyPublisher()
    }
    
    // Fetch group names in display order from LinkGroups!A2:A
    private func fetchLinkGroupOrder(completion: @escaping ([String]) -> Void) {
        let rangeName = "Validations!A2:A"
        guard let url = URL(string: "https://sheets.googleapis.com/v4/spreadsheets/\(globalGoogleSheetID)/values/\(rangeName)?alt=json&key=\(googleAPIKey)") else {
            print("Invalid LinkGroups URL")
            DispatchQueue.main.async { completion([]) }
            return
        }

        AppNetwork.shared.fetchJSON(url: url, type: LinkGoogleSheetResponse.self) { result in
            switch result {
            case .success(let response):
                let groupOrder = response.values.compactMap { $0.first?.trimmingCharacters(in: .whitespacesAndNewlines) }
                DispatchQueue.main.async { completion(groupOrder) }
            case .failure:
                DispatchQueue.main.async { completion([]) }
            }
        }
    }
    
    func sortedGroupedLinks() -> [(String, [LinkItem])] {
        let existing = groupedLinks
        let sorted: [(String, [LinkItem])] = orderedGroupNames.compactMap { name -> (String, [LinkItem])? in
            guard let items = existing[name] else { return nil }
            return (name, items)
        }
        return sorted
    }
}
