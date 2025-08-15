import SwiftUI
import Combine

// Note:  Use the globally available function calls in AppURLManager to access data

struct AppURL {
    let appCountry: String                  // Country code or "Global"
    let URLName: String
    let URL: String
}

struct AppURLResponse: Codable {
    let values: [[String]]
}

class AppURLViewModel: ObservableObject {
    @Published var appURLs: [AppURL] = []
    private var cancellables = Set<AnyCancellable>()
    
    let sheetName = "URLs"
    
    @MainActor
    func getAppURLs() async {
        let urlString = "https://sheets.googleapis.com/v4/spreadsheets/\(globalGoogleSheetID)/values/\(sheetName)?alt=json&key=\(googleAPIKey)"
        guard let url = URL(string: urlString) else {
            print("Invalid URL for app URLs metadata")
            self.appURLs = []
            return
        }

        do {
            let response: AppURLResponse = try await AppNetwork.shared.fetchJSONAsync(url: url, type: AppURLResponse.self)

            let urls: [AppURL] = response.values.dropFirst().compactMap { row in
                guard row.count >= 3 else {
                    print("Skipping malformed app URL metadata row: \(row)")
                    return nil
                }
                let appCountry = row[0]
                let URLName = row[1]
                let URL = row[2]

                guard !URLName.isEmpty, !URL.isEmpty else {
                    print("Skipping app URL metadata row with missing critical fields: \(row)")
                    return nil
                }

                return AppURL(appCountry: appCountry, URLName: URLName, URL: URL)
            }

            self.appURLs = urls
            AppURLManager.shared.setAppURLs(urls)

        } catch {
            print("Failed to fetch app URLs: \(error)")
            self.appURLs = []
        }
    }
}
