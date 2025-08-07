import SwiftUI
import Combine

struct DailyForecastData: Codable {
    var elevation: Double
    var daily: Daily
}

struct Daily: Codable {
    let time: [String]
    let weather_code: [Int]
    let temperature_2m_max: [Double]
    let temperature_2m_min: [Double]
    let precipitation_sum: [Double]
    let precipitation_probability_max: [Int]
    let wind_speed_10m_mean: [Double]
    let wind_direction_10m_dominant: [Int]
    let cloud_cover_mean: [Int]
    var forecastDay: [String]?
    var forecastDate: [String]?
    var weatherCodeImage: [String]?
    var formattedMinTemp: [String]?
    var formattedMaxTemp: [String]?
    var precipImage: [String]?
}

class SiteDailyForecastViewModel: ObservableObject {
    @Published var dailyForecastData: DailyForecastData?
    private var weatherCodesViewModel: WeatherCodeViewModel
    private var cancellable: AnyCancellable?

    // Cache (URL → (timestamp, data))
    private static var forecastCache: [String: (timestamp: Date, data: DailyForecastData)] = [:]
    private let cacheTTL: TimeInterval = forecastCacheInterval

    // Instance Tracking
    private let vmtype = "DailyForecastViewModel"
    private let instanceID = UUID()
    deinit { print("🗑️ \(vmtype) \(instanceID) deinitialized") }

    init(weatherCodesViewModel: WeatherCodeViewModel) {
        self.weatherCodesViewModel = weatherCodesViewModel
        print("✅ \(vmtype) \(instanceID) initialized")
    }

    func fetchDailyWeatherData(latitude: String, longitude: String) {
        // Build URL
        let encodedTimezone = AppRegionManager.shared.getRegionEncodedTimezone() ?? ""
        let baseDailyForecastURL = AppURLManager.shared.getAppURL(URLName: "dailyForecastURL") ?? "<Unknown daily forecast URL>"
        var updatedDailyForecastURL = updateURL(url: baseDailyForecastURL, parameter: "latitude", value: latitude)
        updatedDailyForecastURL = updateURL(url: updatedDailyForecastURL, parameter: "longitude", value: longitude)
        updatedDailyForecastURL = updateURL(url: updatedDailyForecastURL, parameter: "encodedTimezone", value: encodedTimezone)

        if printForecastURL { print(updatedDailyForecastURL) }
        guard let dailyForecastURL = URL(string: updatedDailyForecastURL) else { return }

        let cacheKey = dailyForecastURL.absoluteString

        // Use cache if still valid
        if let (timestamp, cachedData) = Self.forecastCache[cacheKey],
           Date().timeIntervalSince(timestamp) < cacheTTL {
            DispatchQueue.main.async {
                self.dailyForecastData = cachedData
            }
            return
        }

        // Fetch from network
        URLSession.shared.dataTask(with: dailyForecastURL) { [weak self] data, response, error in
            guard let self = self else { return }

            if let data = data {
                let decoder = JSONDecoder()
                let modifiedData = replaceNullsInJSON(data: data)
                if let dailyForecastData = try? decoder.decode(DailyForecastData.self, from: modifiedData ?? data) {
                    DispatchQueue.main.async {
                        let dateFormatter = DateFormatter()
                        dateFormatter.dateFormat = "yyyy-MM-dd"
                        let dayFormatter = DateFormatter()
                        dayFormatter.dateFormat = "E"
                        let shortDateFormatter = DateFormatter()
                        shortDateFormatter.dateFormat = "M/d"

                        var forecastDay = [String](repeating: "", count: dailyForecastData.daily.time.count)
                        var forecastDate = [String](repeating: "", count: dailyForecastData.daily.time.count)
                        var weatherCodeImage = [String](repeating: "", count: dailyForecastData.daily.time.count)
                        var formattedMaxTemp = [String](repeating: "", count: dailyForecastData.daily.time.count)
                        var formattedMinTemp = [String](repeating: "", count: dailyForecastData.daily.time.count)
                        var precipImage = [String](repeating: "", count: dailyForecastData.daily.time.count)

                        for index in 0..<dailyForecastData.daily.time.count {
                            let date = dateFormatter.date(from: dailyForecastData.daily.time[index])
                            forecastDay[index] = dayFormatter.string(from: date ?? Date())
                            forecastDate[index] = shortDateFormatter.string(from: date ?? Date())
                            formattedMaxTemp[index] = String(Int(dailyForecastData.daily.temperature_2m_max[index].rounded()))
                            formattedMinTemp[index] = String(Int(dailyForecastData.daily.temperature_2m_min[index].rounded()))

                            weatherCodeImage[index] = self.weatherCodesViewModel.weatherCodeImage(
                                weatherCode: Int(dailyForecastData.daily.weather_code[index]),
                                cloudcover: Double(dailyForecastData.daily.cloud_cover_mean[index]),
                                precipProbability: Double(dailyForecastData.daily.precipitation_probability_max[index]),
                                tempF: (dailyForecastData.daily.temperature_2m_max[index])
                            ) ?? ""

                            precipImage[index] = "drop.fill"
                            if Int(dailyForecastData.daily.temperature_2m_max[index].rounded()) <= 32 {
                                precipImage[index] = "snowflake"
                            }
                        }

                        var updatedDaily = dailyForecastData.daily
                        updatedDaily.forecastDay = forecastDay
                        updatedDaily.forecastDate = forecastDate
                        updatedDaily.weatherCodeImage = weatherCodeImage
                        updatedDaily.formattedMaxTemp = formattedMaxTemp
                        updatedDaily.formattedMinTemp = formattedMinTemp
                        updatedDaily.precipImage = precipImage

                        let finalData = DailyForecastData(elevation: dailyForecastData.elevation, daily: updatedDaily)
                        self.dailyForecastData = finalData

                        // Cache the result
                        Self.forecastCache[cacheKey] = (Date(), finalData)
                    }
                } else {
                    print("JSON decode failed for forecast")
                }
            } else if let error = error {
                print("Network error: \(error.localizedDescription)")
            }
        }.resume()
    }
}
