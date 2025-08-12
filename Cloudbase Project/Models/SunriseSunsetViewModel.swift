import SwiftUI
import Combine

// Get sunrise/sunset times for common use
// Sunrise and sunset URL fetch response structure
struct SunriseSunsetResponse: Codable {
    let results: Results
    let status: String
}
// Sunrise and sunset JSON decode for Results portion of URL response
struct Results: Codable {
    let sunrise: String
    let sunset: String
}
// Published view model structure
struct SunriseSunset: Codable {
    var sunrise: String
    var sunset: String
}
class SunriseSunsetViewModel: ObservableObject {
    @Published var sunriseSunset: SunriseSunset?
    
    // Get sunrise / sunset for region
    func getSunriseSunset(completion: @escaping () -> Void) {
        var sunriseSunset: SunriseSunset = .init(sunrise: "", sunset: "")
        
        // Get coordinates for region
        guard let coords = AppRegionManager.shared.getRegionSunriseCoordinates() else {
            print("Region not found fetching sunrise coordinates: \(RegionManager.shared.activeAppRegion)")
            return
        }
        
        let baseURL = AppURLManager.shared.getAppURL(URLName: "sunriseSunsetAPI") ?? "<Unknown sunrise/sunset URL>"
        var updatedURL = updateURL(url: baseURL, parameter: "latitude", value: String(coords.latitude))
        updatedURL = updateURL(url: updatedURL, parameter: "longitude", value: String(coords.longitude))
        guard let url = URL(string: updatedURL) else {
            print("Invalid URL for sunrise and sunset times")
            DispatchQueue.main.async { completion() }
            return
        }
        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            if let error = error {
                print("Error for sunrise and sunset times: \(error.localizedDescription)")
                print("sunrise URL: \(url)")
                DispatchQueue.main.async { completion() }
                return
            }
            guard let data = data else {
                print("No data received for sunrise and sunset times")
                DispatchQueue.main.async { completion() }
                return
            }
            let decoder = JSONDecoder()
            if let decodedResponse = try? decoder.decode(SunriseSunsetResponse.self, from: data) {
                DispatchQueue.main.async {
                    sunriseSunset.sunrise = convertISODateToLocalTime(isoDateString: decodedResponse.results.sunrise)
                    sunriseSunset.sunset = convertISODateToLocalTime(isoDateString: decodedResponse.results.sunset)
                    self?.sunriseSunset = sunriseSunset
                    completion()
                }
            } else {
                DispatchQueue.main.async { completion() }
            }
        }.resume()
    }
}
