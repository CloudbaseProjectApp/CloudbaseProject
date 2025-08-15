import SwiftUI
import Combine

// Weather Alerts
struct WeatherAlert: Identifiable, Decodable {
    let id = UUID()
    let areaDescription: String?
    let effectiveDate: String?
    let onsetDate: String?
    let endDate: String?
    let status: String?
    let category: String?
    let severity: String?
    let certainty: String?
    let urgency: String?
    let event: String?
    let headline: String?
    let description: String?
    let instruction: String?

    enum CodingKeys: String, CodingKey {
        case areaDescription = "areaDesc"
        case effectiveDate = "effective"
        case onsetDate = "onset"
        case endDate = "ends"
        case status
        case category
        case severity
        case certainty
        case urgency
        case event
        case headline
        case description
        case instruction
    }
}

struct WeatherAlertsResponse: Decodable {
    let features: [Feature]
    
    struct Feature: Decodable {
        let properties: WeatherAlert
    }
}

@MainActor
class WeatherAlertViewModel: ObservableObject {
    @Published var weatherAlerts: [WeatherAlert] = []
    @Published var isLoading = false
    
    func getWeatherAlerts() async {
        isLoading = true
        
        guard let baseURLString = AppURLManager.shared.getAppURL(URLName: "weatherAlertsURL") else {
            print("Could not find weather alerts URL for appRegion: \(RegionManager.shared.activeAppRegion)")
            isLoading = false
            return
        }
        
        let updatedURLString = updateURL(url: baseURLString, parameter: "appregion", value: RegionManager.shared.activeAppRegion)
        guard let url = URL(string: updatedURLString) else {
            print("Invalid weather alerts URL for appRegion: \(RegionManager.shared.activeAppRegion)")
            isLoading = false
            return
        }
        
        do {
            let response: WeatherAlertsResponse = try await AppNetwork.shared.fetchJSONAsync(url: url, type: WeatherAlertsResponse.self)
            self.weatherAlerts = response.features.map { $0.properties }
        } catch {
            print("Failed to fetch or decode weather alerts: \(error)")
        }
        
        isLoading = false
    }
}
