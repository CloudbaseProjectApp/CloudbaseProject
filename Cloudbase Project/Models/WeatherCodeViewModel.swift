import SwiftUI
import Combine

struct WeatherCode: Identifiable {
    let id = UUID()
    let weatherCode: Int
    let imageName: String
}

struct WeatherCodesResponse: Codable {
    let values: [[String]]
}

@MainActor
class WeatherCodeViewModel: ObservableObject {
    @Published var weatherCodes: [WeatherCode] = []

    let sheetName = "WeatherCodes"

    // Async function to fetch codes
    func getWeatherCodes() async {
        guard let url = URL(string: "https://sheets.googleapis.com/v4/spreadsheets/\(globalGoogleSheetID)/values/\(sheetName)?alt=json&key=\(googleAPIKey)") else {
            print("Invalid URL for weather codes")
            return
        }

        do {
            let response: WeatherCodesResponse = try await AppNetwork.shared.fetchJSONAsync(url: url, type: WeatherCodesResponse.self)
            
            let codes = response.values.dropFirst().compactMap { row -> WeatherCode? in
                guard row.count >= 2 else {
                    print("Skipping malformed weather code row: \(row)")
                    return nil
                }
                guard let code = Int(row[0]) else { return nil }
                return WeatherCode(weatherCode: code, imageName: row[1])
            }
            
            self.weatherCodes = codes
        } catch {
            print("Failed to fetch weather codes: \(error)")
            self.weatherCodes = []
        }
    }

    func weatherCodeImage(weatherCode: Int, cloudcover: Double, precipProbability: Double, tempF: Double) -> String? {
        var weatherCodeImage: String = weatherCodes.first { $0.weatherCode == weatherCode }?.imageName ?? ""
        
        // Adjust sun/cloud/rain weather code image based on high % precip
        if ["cloud.sun.fill", "sun.max.fill", "cloud.fill"].contains(weatherCodeImage) {
            if precipProbability > 50.0 {
                weatherCodeImage = (tempF < 32.0) ? "cloud.snow.fill" : "cloud.rain.fill"
            } else if cloudcover > 70.0 {
                weatherCodeImage = "cloud.fill"
            } else if cloudcover > 30.0 {
                weatherCodeImage = "cloud.sun.fill"
            } else {
                weatherCodeImage = "sun.max.fill"
            }
        }
        return weatherCodeImage
    }
}
