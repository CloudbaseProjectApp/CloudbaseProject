import SwiftUI

struct SunriseSunsetResponse: Codable {
    let results: Results
    let status: String
}

struct Results: Codable {
    let sunrise: String
    let sunset: String
}

struct SunriseSunset: Codable {
    var sunrise: String
    var sunset: String
}

@MainActor
class SunriseSunsetViewModel: ObservableObject {
    @Published var sunriseSunset: SunriseSunset?

    func getSunriseSunset() async {
        // Get coordinates for the active region
        guard let coords = AppRegionManager.shared.getRegionSunriseCoordinates() else {
            print("Error: Could not get sunrise coordinates for region \(RegionManager.shared.activeAppRegion)")
            return
        }

        // Get the API base URL
        guard let baseURL = AppURLManager.shared.getAppURL(URLName: "sunriseSunsetAPI") else {
            print("Error: sunriseSunsetAPI URL not found in AppURLManager")
            return
        }

        // Build the URL with query parameters
        var updatedURL = updateURL(url: baseURL, parameter: "latitude", value: String(coords.latitude))
        updatedURL = updateURL(url: updatedURL, parameter: "longitude", value: String(coords.longitude))
        guard let url = URL(string: updatedURL) else {
            print("Error: Invalid sunrise/sunset URL after adding coordinates: \(updatedURL)")
            return
        }

        do {
            let response: SunriseSunsetResponse = try await AppNetwork.shared.fetchJSONAsync(url: url, type: SunriseSunsetResponse.self)
            let sunrise = convertISODateToLocalTime(isoDateString: response.results.sunrise)
            let sunset = convertISODateToLocalTime(isoDateString: response.results.sunset)
            self.sunriseSunset = SunriseSunset(sunrise: sunrise, sunset: sunset)
        } catch {
            print("Failed to fetch sunrise/sunset: \(error)")
        }
    }
}
