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
    
    // Instance Tracking code
    private let vmtype = "LinkViewModel"
    private let instanceID = UUID()
    init() { print("✅ \(vmtype) \(instanceID) initialized") }
    deinit { print("🗑️ \(vmtype) \(instanceID) deinitialized") }

    private var cancellable: AnyCancellable?

    func fetchLinks() {
        isLoading = true
        let linksRange = "Links"

        guard let globalLinksURL = URL(string: "https://sheets.googleapis.com/v4/spreadsheets/\(globalGoogleSheetID)/values/\(linksRange)?alt=json&key=\(googleAPIKey)"),
              let regionGoogleSheetID = AppRegionManager.shared.getRegionGoogleSheet(),
              let regionLinksURL = URL(string: "https://sheets.googleapis.com/v4/spreadsheets/\(regionGoogleSheetID)/values/\(linksRange)?alt=json&key=\(googleAPIKey)") else {
            print("Invalid sheet URLs")
            isLoading = false
            return
        }

        let globalPublisher = fetchAndParseLinks(from: globalLinksURL)
        let regionPublisher = fetchAndParseLinks(from: regionLinksURL)

        // Step 1: Fetch LinkGroups first
        fetchLinkGroupOrder { [weak self] groupOrder in
            guard let self = self else { return }

            self.orderedGroupNames = groupOrder

            // Step 2: Fetch links concurrently
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
        URLSession.shared.dataTaskPublisher(for: url)
            .map(\.data)
            .decode(type: LinkGoogleSheetResponse.self, decoder: JSONDecoder())
            .map { response in
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
                return Dictionary(grouping: linkItems, by: \.category)
            }
            .replaceError(with: [:])
            .eraseToAnyPublisher()
    }

    // Fetch group names in display order from LinkGroups!A2:A
    private func fetchLinkGroupOrder(completion: @escaping ([String]) -> Void) {
        let rangeName = "Validations!A2:A"

        guard let url = URL(string: "https://sheets.googleapis.com/v4/spreadsheets/\(globalGoogleSheetID)/values/\(rangeName)?alt=json&key=\(googleAPIKey)") else {
            print("Invalid LinkGroups URL")
            DispatchQueue.main.async {
                completion([])
            }
            return
        }

        URLSession.shared.dataTask(with: url) { data, _, _ in
            guard let data = data,
                  let response = try? JSONDecoder().decode(LinkGoogleSheetResponse.self, from: data) else {
                print("Failed to fetch LinkGroups")
                DispatchQueue.main.async {
                    completion([])
                }
                return
            }

            let groupOrder = response.values.compactMap { $0.first?.trimmingCharacters(in: .whitespacesAndNewlines) }

            // Ensure this runs on the main thread
            DispatchQueue.main.async {
                completion(groupOrder)
            }
        }.resume()
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
