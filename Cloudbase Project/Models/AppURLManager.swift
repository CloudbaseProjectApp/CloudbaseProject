import Foundation

// Make app URL functions available globally (without injecting view model each time)
// To call, use this format:
//      AppURLManager.shared.getAppURL(URLName: "<URL name to get>")

final class AppURLManager: ObservableObject {

    static let shared = AppURLManager()
    
    private init() {}

    @Published private(set) var appURLs: [AppURL] = []

    func setAppURLs(_ appURLs: [AppURL]) {
        self.appURLs = appURLs
    }

    func getAppURL(URLName: String) -> String? {
        let regionCountry = AppRegionManager.shared.getRegionCountry()

        // Try exact country match
        if let match = appURLs.first(where: {
            $0.appCountry == regionCountry && $0.URLName == URLName
        }) {
            return match.URL
        }

        // Fallback to Global
        return appURLs.first(where: {
            $0.appCountry == "Global" && $0.URLName == URLName
        })?.URL
    }
}
