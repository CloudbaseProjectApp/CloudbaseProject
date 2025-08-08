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

class WeatherAlertViewModel: ObservableObject {
    @Published var weatherAlerts: [WeatherAlert] = []
    @Published var isLoading = false
    
    func getWeatherAlerts() {
        isLoading = true

        guard let baseURL = AppURLManager.shared.getAppURL(URLName: "weatherAlertsURL") else {
            print("Could not find weather alerts URL for appRegion: \(RegionManager.shared.activeAppRegion)")
            isLoading = false
            return
        }

        let updatedURL = updateURL(url: baseURL, parameter: "appregion", value: RegionManager.shared.activeAppRegion)

        guard let url = URL(string: updatedURL) else {
            print("Invalid weather alerts URL for appRegion: \(RegionManager.shared.activeAppRegion)")
            isLoading = false
            return
        }

        URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                print("Weather alerts request failed: \(error.localizedDescription)")
                DispatchQueue.main.async { self.isLoading = false }
                return
            }

            guard let data = data else {
                print("No data received in weather alerts response")
                DispatchQueue.main.async { self.isLoading = false }
                return
            }
            self.parseWeatherAlertsData(data: data)

        }.resume()
    }
    
    private func parseWeatherAlertsData(data: Data) {
        do {
            let decodedResponse = try JSONDecoder().decode(WeatherAlertsResponse.self, from: data)
            DispatchQueue.main.async {
                self.weatherAlerts = decodedResponse.features.map { $0.properties }
                self.isLoading = false
            }
        } catch {
            print("Error decoding weather alerts JSON: \(error)")
            DispatchQueue.main.async { self.isLoading = false }
        }
    }
    
}
