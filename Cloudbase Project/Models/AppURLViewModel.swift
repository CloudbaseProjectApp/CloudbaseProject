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
    
    func getAppURLs(completion: @escaping () -> Void) {
        let appURLsURLString = "https://sheets.googleapis.com/v4/spreadsheets/\(globalGoogleSheetID)/values/\(sheetName)?alt=json&key=\(googleAPIKey)"
        guard let url = URL(string: appURLsURLString) else {
            print("Invalid URL for app URLs metadata")
            DispatchQueue.main.async { completion() }
            return
        }
        URLSession.shared.dataTaskPublisher(for: url)
            .map { $0.data }
            .decode(type: AppURLResponse.self, decoder: JSONDecoder())
        
            .map { response -> [AppURL] in
                response.values.dropFirst().compactMap { row in
                    guard row.count >= 3 else {
                        print("Skipping malformed app URL metadata row: \(row)")
                        return nil
                    }
                    let appCountry = row[0]
                    let URLName = row[1]
                    let URL = row[2]
                    
                    // Make sure URL name and URL are populated
                    guard !URLName.isEmpty,
                          !URL.isEmpty else {
                        print("Skipping app URL metadata row with missing critical fields: \(row)")
                        return nil
                    }
                    
                    return AppURL(appCountry: appCountry,
                                  URLName: URLName,
                                  URL: URL
                    )
                }
            }
            .replaceError(with: [])
            .receive(on: DispatchQueue.main)

            // Save URLs globally so they can be accessed from anywhere in the app
            .handleEvents(receiveOutput: { [weak self] appURLs in
                self?.appURLs = appURLs
                AppURLManager.shared.setAppURLs(appURLs) // global set
            }, receiveCompletion: { _ in
                completion()
            })
        
            .sink { _ in }
            .store(in: &cancellables)
    }
    
}
