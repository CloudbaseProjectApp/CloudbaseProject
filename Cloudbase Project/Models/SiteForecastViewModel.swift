import SwiftUI
import Combine

struct ForecastData: Codable {
    var id: String = ""              // default value, will be set manually based on site/favorite/station ID
    var elevation: Double
    var hourly: HourlyData

    private enum CodingKeys: String, CodingKey {
        case elevation, hourly
        // exclude `id` so it's not decoded from JSON
    }
}

struct HourlyData: Codable {
    var time: [String]
    var weathercode: [Int]
    var cloudcover: [Double]
    var precipitation_probability: [Double]
    var cape: [Double]
    var temperature_2m: [Double]
    var windspeed_500hPa: [Double]
    var windspeed_550hPa: [Double]
    var windspeed_600hPa: [Double]
    var windspeed_650hPa: [Double]
    var windspeed_700hPa: [Double]
    var windspeed_750hPa: [Double]
    var windspeed_800hPa: [Double]
    var windspeed_850hPa: [Double]
    var windspeed_900hPa: [Double]
    var windspeed_10m: [Double]
    var windgusts_10m: [Double]
    var winddirection_500hPa: [Double]
    var winddirection_550hPa: [Double]
    var winddirection_600hPa: [Double]
    var winddirection_650hPa: [Double]
    var winddirection_700hPa: [Double]
    var winddirection_750hPa: [Double]
    var winddirection_800hPa: [Double]
    var winddirection_850hPa: [Double]
    var winddirection_900hPa: [Double]
    var winddirection_10m: [Double]
    var temperature_500hPa: [Double]
    var temperature_550hPa: [Double]
    var temperature_600hPa: [Double]
    var temperature_650hPa: [Double]
    var temperature_700hPa: [Double]
    var temperature_750hPa: [Double]
    var temperature_800hPa: [Double]
    var temperature_850hPa: [Double]
    var temperature_900hPa: [Double]
    var dewpoint_500hPa: [Double]
    var dewpoint_550hPa: [Double]
    var dewpoint_600hPa: [Double]
    var dewpoint_650hPa: [Double]
    var dewpoint_700hPa: [Double]
    var dewpoint_750hPa: [Double]
    var dewpoint_800hPa: [Double]
    var dewpoint_850hPa: [Double]
    var dewpoint_900hPa: [Double]
    var geopotential_height_500hPa: [Double]
    var geopotential_height_550hPa: [Double]
    var geopotential_height_600hPa: [Double]
    var geopotential_height_650hPa: [Double]
    var geopotential_height_700hPa: [Double]
    var geopotential_height_750hPa: [Double]
    var geopotential_height_800hPa: [Double]
    var geopotential_height_850hPa: [Double]
    var geopotential_height_900hPa: [Double]
    var dateTime: [Date]?
    var newDateFlag: [Bool]?
    var formattedDay: [String]?
    var formattedDate: [String]?
    var formattedTime: [String]?
    var weatherCodeImage: [String]?
    var thermalVelocity_500hPa: [Double]?
    var thermalVelocity_550hPa: [Double]?
    var thermalVelocity_600hPa: [Double]?
    var thermalVelocity_650hPa: [Double]?
    var thermalVelocity_700hPa: [Double]?
    var thermalVelocity_750hPa: [Double]?
    var thermalVelocity_800hPa: [Double]?
    var thermalVelocity_850hPa: [Double]?
    var thermalVelocity_900hPa: [Double]?
    var topOfLiftTemp: [Double]?
    var gustFactor: [Double]?
    // formatted variables to prevent errors where compiler cannot determine types when converting double to string in a view
    var formattedCloudbaseAltitude: [String]?
    var topOfLiftAltitude: [Double]?
    var formattedTopOfLiftAltitude: [String]?
    var formattedTopOfLiftTemp: [String]?
    var formattedCAPE: [String]?
    var formattedPrecipProbability: [String]?
    var formattedCloudCover: [String]?
    var formattedSurfaceTemp: [String]?
    // Flying potential data
    var combinedColorValue: [Int]?
    var cloudCoverColorValue: [Int]?
    var precipColorValue: [Int]?
    var CAPEColorValue: [Int]?
    var windDirectionColorValue: [Int]?
    var surfaceWindColorValue: [Int]?
    var surfaceGustColorValue: [Int]?
    var gustFactorColorValue: [Int]?
    var windsAloftColorValue: [Int]?
    var thermalVelocityColorValue: [Int]?
    var windsAloftMax: [Double]?
    var thermalVelocityMax: [Double]?
}

// Structure used to store data that is common for all altitudes and pass to thermal calculation function
struct ForecastBaseData {
    var siteName: String
    var date: String
    var time: String
    var surfaceAltitude: Double
    var surfaceTemp: Double
}

// Used to prevent re-querying and processing forecast for a given site if recently processed
private struct ForecastCacheEntry {
    let data: ForecastData
    let timestamp: Date
}

class SiteForecastViewModel: ObservableObject {
    @Published var forecastData: ForecastData?
    @Published var maxPressureReading: Int = defaultMaxPressureReading
    
    private var liftParametersViewModel: LiftParametersViewModel
    private var sunriseSunsetViewModel: SunriseSunsetViewModel
    private var weatherCodesViewModel: WeatherCodeViewModel

    // Forecast cache based on each forecast URL
    private var forecastCache: [String: ForecastCacheEntry] = [:]
    
    // Define a specific URL session to number of concurrent API requests (e.g., when called from Flying Potential with many sites)
    private let urlSession: URLSession
    
    // Make thermal lift parameters, weather code images, and sunrise/sunset times available in this view model
    init(liftParametersViewModel: LiftParametersViewModel,
         sunriseSunsetViewModel: SunriseSunsetViewModel,
         weatherCodesViewModel: WeatherCodeViewModel) {
        self.liftParametersViewModel = liftParametersViewModel
        self.sunriseSunsetViewModel = sunriseSunsetViewModel
        self.weatherCodesViewModel = weatherCodesViewModel
        
        // Set limit on number of concurrent API requests for this session
        let config = URLSessionConfiguration.default
        config.httpMaximumConnectionsPerHost = 3   // allow only 3 concurrent requests
        self.urlSession = URLSession(configuration: config)
    }
    
    func clearForecastCache() {
        forecastCache.removeAll()
    }
    
    func fetchForecast(id: String,
                       siteName: String,
                       latitude: String,
                       longitude: String,
                       siteType: String,
                       siteWindDirection: SiteWindDirection) {

        let encodedTimezone = AppRegionManager.shared.getRegionEncodedTimezone() ?? ""
        let baseForecastURL = AppURLManager.shared.getAppURL(URLName: "forecastURL") ?? "<Unknown forecast URL>"
        var updatedForecastURL = updateURL(url: baseForecastURL, parameter: "latitude", value: latitude)
        updatedForecastURL = updateURL(url: updatedForecastURL, parameter: "longitude", value: longitude)
        updatedForecastURL = updateURL(url: updatedForecastURL, parameter: "encodedTimezone", value: encodedTimezone)
        
        if printForecastURL { print(updatedForecastURL) }

        // Cache check
        if let cached = forecastCache[updatedForecastURL],
           Date().timeIntervalSince(cached.timestamp) < forecastCacheInterval {
            DispatchQueue.main.async {
                self.forecastData = cached.data
                self.maxPressureReading = self.maxPressureReading  // Optional: re-process if needed
            }
            return
        }

        guard let forecastURL = URL(string: updatedForecastURL) else { return }
        
        urlSession.dataTask(with: forecastURL) { data, response, error in
            if let data = data {
                let decoder = JSONDecoder()
                let modifiedData = replaceNullsInJSON(data: data)
                if var forecastData = try? decoder.decode(ForecastData.self, from: modifiedData ?? data) {
                    DispatchQueue.main.async {
                        
                        // Set id based on site/station/favorite id passed in
                        forecastData.id = id
                        
                        // Process forecast data
                        let (maxPressure, processed) = self.processForecastData(id:                 id,
                                                                                siteName:           siteName,
                                                                                siteType:           siteType,
                                                                                siteWindDirection:  siteWindDirection,
                                                                                data:               forecastData)
                        self.forecastData = processed
                        self.maxPressureReading = maxPressure
                        self.forecastCache[updatedForecastURL] = ForecastCacheEntry(data: processed, timestamp: Date())
                    }
                } else {
                    print("JSON decode failed for forecast")
                }
            }
        }.resume()
    }
    
    // Overloaded version with completion handler for use in FlyingPotentialView
    func fetchForecast(id: String,
                       siteName: String,
                       latitude: String,
                       longitude: String,
                       siteType: String,
                       siteWindDirection: SiteWindDirection,
                       completion: @escaping (ForecastData?) -> Void) {

        let encodedTimezone = AppRegionManager.shared.getRegionEncodedTimezone() ?? ""
        let baseForecastURL = AppURLManager.shared.getAppURL(URLName: "forecastURL") ?? "<Unknown forecast URL>"
        
        var updatedForecastURL = updateURL(url: baseForecastURL, parameter: "latitude", value: latitude)
        updatedForecastURL = updateURL(url: updatedForecastURL, parameter: "longitude", value: longitude)
        updatedForecastURL = updateURL(url: updatedForecastURL, parameter: "encodedTimezone", value: encodedTimezone)

        if printForecastURL { print(updatedForecastURL) }

        // Cache check
        if let cached = forecastCache[updatedForecastURL],
           Date().timeIntervalSince(cached.timestamp) < forecastCacheInterval {
            DispatchQueue.main.async {
                completion(cached.data)
            }
            return
        }
        guard let forecastURL = URL(string: updatedForecastURL) else {
            completion(nil)
            return
        }
        
        urlSession.dataTask(with: forecastURL) { data, response, error in
            if let data = data {
                let decoder = JSONDecoder()
                let modifiedData = replaceNullsInJSON(data: data)
                do {
                    let forecastData = try decoder.decode(ForecastData.self, from: modifiedData ?? data)
                    let (_, processed) = self.processForecastData(id:                   id,
                                                                  siteName:             siteName,
                                                                  siteType:             siteType,
                                                                  siteWindDirection:    siteWindDirection,
                                                                  data:                 forecastData)
                    DispatchQueue.main.async {
                        self.forecastCache[updatedForecastURL] = ForecastCacheEntry(data: processed, timestamp: Date())
                        completion(processed)
                    }
                } catch {
                    print("Decoding error: \(error)")
                    print("Raw JSON: \(String(data: modifiedData ?? data, encoding: .utf8) ?? "Invalid data")")
                    DispatchQueue.main.async {
                        completion(nil)
                    }
                }
            } else {
                DispatchQueue.main.async {
                    completion(nil)
                }
            }
        }.resume()
    }
    
    func processForecastData(id: String,
                             siteName: String,
                             siteType: String,
                             siteWindDirection: SiteWindDirection,
                             data: ForecastData) -> (maxPressureReading: Int, ForecastData) {
        
        var processedHourly = HourlyData(
            time: [],
            weathercode: [],
            cloudcover: [],
            precipitation_probability: [],
            cape: [],
            temperature_2m: [],
            windspeed_500hPa: [],
            windspeed_550hPa: [],
            windspeed_600hPa: [],
            windspeed_650hPa: [],
            windspeed_700hPa: [],
            windspeed_750hPa: [],
            windspeed_800hPa: [],
            windspeed_850hPa: [],
            windspeed_900hPa: [],
            windspeed_10m: [],
            windgusts_10m: [],
            winddirection_500hPa: [],
            winddirection_550hPa: [],
            winddirection_600hPa: [],
            winddirection_650hPa: [],
            winddirection_700hPa: [],
            winddirection_750hPa: [],
            winddirection_800hPa: [],
            winddirection_850hPa: [],
            winddirection_900hPa: [],
            winddirection_10m: [],
            temperature_500hPa: [],
            temperature_550hPa: [],
            temperature_600hPa: [],
            temperature_650hPa: [],
            temperature_700hPa: [],
            temperature_750hPa: [],
            temperature_800hPa: [],
            temperature_850hPa: [],
            temperature_900hPa: [],
            dewpoint_500hPa: [],
            dewpoint_550hPa: [],
            dewpoint_600hPa: [],
            dewpoint_650hPa: [],
            dewpoint_700hPa: [],
            dewpoint_750hPa: [],
            dewpoint_800hPa: [],
            dewpoint_850hPa: [],
            dewpoint_900hPa: [],
            geopotential_height_500hPa: [],
            geopotential_height_550hPa: [],
            geopotential_height_600hPa: [],
            geopotential_height_650hPa: [],
            geopotential_height_700hPa: [],
            geopotential_height_750hPa: [],
            geopotential_height_800hPa: [],
            geopotential_height_850hPa: [],
            geopotential_height_900hPa: [],
            dateTime: [],
            newDateFlag: [],
            formattedDay: [],
            formattedDate: [],
            formattedTime: [],
            weatherCodeImage: [],
            thermalVelocity_500hPa: [],
            thermalVelocity_550hPa: [],
            thermalVelocity_600hPa: [],
            thermalVelocity_650hPa: [],
            thermalVelocity_700hPa: [],
            thermalVelocity_750hPa: [],
            thermalVelocity_800hPa: [],
            thermalVelocity_850hPa: [],
            thermalVelocity_900hPa: [],
            topOfLiftTemp: [],
            gustFactor: [],
            formattedCloudbaseAltitude: [],
            topOfLiftAltitude: [],
            formattedTopOfLiftAltitude: [],
            formattedTopOfLiftTemp: [],
            formattedCAPE: [],
            formattedPrecipProbability: [],
            formattedCloudCover: [],
            formattedSurfaceTemp: [],
            combinedColorValue: [],
            cloudCoverColorValue: [],
            precipColorValue: [],
            CAPEColorValue: [],
            windDirectionColorValue: [],
            surfaceWindColorValue: [],
            surfaceGustColorValue: [],
            gustFactorColorValue: [],
            windsAloftColorValue: [],
            thermalVelocityColorValue: [],
            windsAloftMax: [],
            thermalVelocityMax: []
        )
        
        // Get sunrise/sunset times from environment object
        var forecastStartTime = 6
        var forecastEndTime = 21
        if let sunriseSunset = sunriseSunsetViewModel.sunriseSunset {
            // Get the hour from sunrise and sunset times (provided in format hh:mm)
            // Add 13 to sunset to convert to pm and provide forecast at least until after sunset
            forecastStartTime = Int(sunriseSunset.sunrise.split(separator: ":", maxSplits: 1).first ?? "6") ?? 6
            forecastEndTime = ( Int(sunriseSunset.sunset.split(separator: ":", maxSplits: 1).first ?? "6") ?? 6 ) + 13
        } else {
            print("Sunrise/sunset not available")
            if logThermalCalcs {logToFile("Sunrise/sunset times not available") }
        }
        
        let currentDate = Date()
        let startOfDay = Calendar.current.startOfDay(for: currentDate)
        let oneHourAgo = Calendar.current.date(byAdding: .hour, value: -1, to: currentDate)!
        var priorReadingFormattedDate: String?
        var newDateFlag: Bool = true
        var thermalTriggerReachedForDay: Bool = false
        
        // Determine altitude in feet and limit wind readings to only those more than 200 ft above the surface
        // by reducing the number of rows to display and specifying the max pressure reading to display
        let surfaceAltitude = Double(convertMetersToFeet(data.elevation) + 10).rounded()
        let surfaceBuffer = 200.0           // Don't display winds aloft within surface buffer distance above surface
        var maxPressureReading: Int = maxPressureReading
        if (data.hourly.geopotential_height_900hPa.first ?? 0).rounded() < (surfaceAltitude + surfaceBuffer) { maxPressureReading = 850 }
        if (data.hourly.geopotential_height_850hPa.first ?? 0).rounded() < (surfaceAltitude + surfaceBuffer) { maxPressureReading = 800 }
        if (data.hourly.geopotential_height_800hPa.first ?? 0).rounded() < (surfaceAltitude + surfaceBuffer) { maxPressureReading = 750 }
        if (data.hourly.geopotential_height_750hPa.first ?? 0).rounded() < (surfaceAltitude + surfaceBuffer) { maxPressureReading = 700 }
        if (data.hourly.geopotential_height_700hPa.first ?? 0).rounded() < (surfaceAltitude + surfaceBuffer) { maxPressureReading = 650 }
        if (data.hourly.geopotential_height_650hPa.first ?? 0).rounded() < (surfaceAltitude + surfaceBuffer) { maxPressureReading = 600 }
        if (data.hourly.geopotential_height_600hPa.first ?? 0).rounded() < (surfaceAltitude + surfaceBuffer) { maxPressureReading = 550 }
        if (data.hourly.geopotential_height_550hPa.first ?? 0).rounded() < (surfaceAltitude + surfaceBuffer) { maxPressureReading = 500 }
        if (data.hourly.geopotential_height_500hPa.first ?? 0).rounded() < (surfaceAltitude + surfaceBuffer) { maxPressureReading = 450 }

        for (index, time) in data.hourly.time.enumerated() {
            let timeFormatter = DateFormatter()
            timeFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm"
            if let timeObj = timeFormatter.date(from: time) {
                // Process all times starting at beginning of today in order to correctly calculate if
                // thermal trigger temperature was reached for today.
                // There is logic below to filter the display for only times starting from one hour prior to now
                if timeObj >= startOfDay {
                    let hour = Calendar.current.component(.hour, from: timeObj)
                    if hour >= forecastStartTime && hour <= forecastEndTime {

                        let dateFormatter = DateFormatter()
                        dateFormatter.dateFormat = "E"
                        let formattedDay = dateFormatter.string(from: timeObj)
                        dateFormatter.dateFormat = "M/d"
                        let formattedDate = dateFormatter.string(from: timeObj)
                        timeFormatter.dateFormat = "h a"
                        let formattedTime = timeFormatter.string(from: timeObj).lowercased()
                        let surfaceTemp = convertCelsiusToFahrenheit(Int(data.hourly.temperature_2m[index]))
                                                
                        // Determine if this reading is a new day to set a divider in the view
                        if formattedDate == priorReadingFormattedDate {
                            newDateFlag = false
                        } else {
                            newDateFlag = true
                            // Reset thermal trigger temp reached for the day
                            thermalTriggerReachedForDay = false
                        }
                        priorReadingFormattedDate = formattedDate
                        
                        // Set weather code image
                        let weatherCodeImage = self.weatherCodesViewModel.weatherCodeImage (
                            weatherCode: Int(data.hourly.weathercode[index]),
                            cloudcover: data.hourly.cloudcover[index],
                            precipProbability: data.hourly.precipitation_probability[index],
                            tempF: Double(surfaceTemp)) ?? ""
                        
                        // Create variables to store thermal lift at each altitude
                        var thermalVelocity_900hPa: Double = 0.0
                        var thermalVelocity_850hPa: Double = 0.0
                        var thermalVelocity_800hPa: Double = 0.0
                        var thermalVelocity_750hPa: Double = 0.0
                        var thermalVelocity_700hPa: Double = 0.0
                        var thermalVelocity_650hPa: Double = 0.0
                        var thermalVelocity_600hPa: Double = 0.0
                        var thermalVelocity_550hPa: Double = 0.0
                        var thermalVelocity_500hPa: Double = 0.0
                        
                        // Set base data (common for all altitudes) used to calculate thermal velocity
                        let forecastBaseData = ForecastBaseData(
                            siteName: siteName,
                            date: formattedDate,
                            time: formattedTime,
                            surfaceAltitude: surfaceAltitude,
                            surfaceTemp: data.hourly.temperature_2m[index]
                        )
                        // 900 hpa pressure level thermal calcs
                        var thermalResult = calcThermalVelocity (
                            forecastBaseData: forecastBaseData,
                            altitude: data.hourly.geopotential_height_900hPa[index],
                            ambientTemp: data.hourly.temperature_900hPa[index],
                            ambientDPTemp: data.hourly.dewpoint_900hPa[index],
                            priorAmbientDPTemp: 0.0,
                            priorThermalDPTemp: data.hourly.temperature_2m[index],
                            priorAltitude: surfaceAltitude,
                            thermalTriggerReachedForDay: thermalTriggerReachedForDay,
                            topOfLiftAltitude: 0.0,
                            topOfLiftTemp: 0.0,
                            cloudbaseAltitude: 0.0)
                        thermalVelocity_900hPa = thermalResult.thermalVelocity
                        
                        // 850 hpa pressure level thermal calcs
                        thermalResult = calcThermalVelocity (
                            forecastBaseData: forecastBaseData,
                            altitude: data.hourly.geopotential_height_850hPa[index],
                            ambientTemp: data.hourly.temperature_850hPa[index],
                            ambientDPTemp: data.hourly.dewpoint_850hPa[index],
                            priorAmbientDPTemp: data.hourly.dewpoint_900hPa[index],
                            priorThermalDPTemp: thermalResult.thermalDPTemp,
                            priorAltitude: data.hourly.geopotential_height_900hPa[index],
                            thermalTriggerReachedForDay: thermalResult.thermalTriggerReachedForDay,
                            topOfLiftAltitude: thermalResult.topOfLiftAltitude,
                            topOfLiftTemp: thermalResult.topOfLiftTemp,
                            cloudbaseAltitude: thermalResult.cloudbaseAltitude)
                        thermalVelocity_850hPa = thermalResult.thermalVelocity
                        
                        // 800 hpa pressure level thermal calcs
                        thermalResult = calcThermalVelocity (
                            forecastBaseData: forecastBaseData,
                            altitude: data.hourly.geopotential_height_800hPa[index],
                            ambientTemp: data.hourly.temperature_800hPa[index],
                            ambientDPTemp: data.hourly.dewpoint_800hPa[index],
                            priorAmbientDPTemp: data.hourly.dewpoint_850hPa[index],
                            priorThermalDPTemp: thermalResult.thermalDPTemp,
                            priorAltitude: data.hourly.geopotential_height_850hPa[index],
                            thermalTriggerReachedForDay: thermalResult.thermalTriggerReachedForDay,
                            topOfLiftAltitude: thermalResult.topOfLiftAltitude,
                            topOfLiftTemp: thermalResult.topOfLiftTemp,
                            cloudbaseAltitude: thermalResult.cloudbaseAltitude)
                        thermalVelocity_800hPa = thermalResult.thermalVelocity
                        
                        // 750 hpa pressure level thermal calcs
                        thermalResult = calcThermalVelocity (
                            forecastBaseData: forecastBaseData,
                            altitude: data.hourly.geopotential_height_750hPa[index],
                            ambientTemp: data.hourly.temperature_750hPa[index],
                            ambientDPTemp: data.hourly.dewpoint_750hPa[index],
                            priorAmbientDPTemp: data.hourly.dewpoint_800hPa[index],
                            priorThermalDPTemp: thermalResult.thermalDPTemp,
                            priorAltitude: data.hourly.geopotential_height_800hPa[index],
                            thermalTriggerReachedForDay: thermalResult.thermalTriggerReachedForDay,
                            topOfLiftAltitude: thermalResult.topOfLiftAltitude,
                            topOfLiftTemp: thermalResult.topOfLiftTemp,
                            cloudbaseAltitude: thermalResult.cloudbaseAltitude)
                        thermalVelocity_750hPa = thermalResult.thermalVelocity
                        
                        // 700 hpa pressure level thermal calcs
                        thermalResult = calcThermalVelocity (
                            forecastBaseData: forecastBaseData,
                            altitude: data.hourly.geopotential_height_700hPa[index],
                            ambientTemp: data.hourly.temperature_700hPa[index],
                            ambientDPTemp: data.hourly.dewpoint_700hPa[index],
                            priorAmbientDPTemp: data.hourly.dewpoint_750hPa[index],
                            priorThermalDPTemp: thermalResult.thermalDPTemp,
                            priorAltitude: data.hourly.geopotential_height_750hPa[index],
                            thermalTriggerReachedForDay: thermalResult.thermalTriggerReachedForDay,
                            topOfLiftAltitude: thermalResult.topOfLiftAltitude,
                            topOfLiftTemp: thermalResult.topOfLiftTemp,
                            cloudbaseAltitude: thermalResult.cloudbaseAltitude)
                        thermalVelocity_700hPa = thermalResult.thermalVelocity
                        
                        // 650 hpa pressure level thermal calcs
                        thermalResult = calcThermalVelocity (
                            forecastBaseData: forecastBaseData,
                            altitude: data.hourly.geopotential_height_650hPa[index],
                            ambientTemp: data.hourly.temperature_650hPa[index],
                            ambientDPTemp: data.hourly.dewpoint_650hPa[index],
                            priorAmbientDPTemp: data.hourly.dewpoint_700hPa[index],
                            priorThermalDPTemp: thermalResult.thermalDPTemp,
                            priorAltitude: data.hourly.geopotential_height_700hPa[index],
                            thermalTriggerReachedForDay: thermalResult.thermalTriggerReachedForDay,
                            topOfLiftAltitude: thermalResult.topOfLiftAltitude,
                            topOfLiftTemp: thermalResult.topOfLiftTemp,
                            cloudbaseAltitude: thermalResult.cloudbaseAltitude)
                        thermalVelocity_650hPa = thermalResult.thermalVelocity
                        
                        // 600 hpa pressure level thermal calcs
                        thermalResult = calcThermalVelocity (
                            forecastBaseData: forecastBaseData,
                            altitude: data.hourly.geopotential_height_600hPa[index],
                            ambientTemp: data.hourly.temperature_600hPa[index],
                            ambientDPTemp: data.hourly.dewpoint_600hPa[index],
                            priorAmbientDPTemp: data.hourly.dewpoint_650hPa[index],
                            priorThermalDPTemp: thermalResult.thermalDPTemp,
                            priorAltitude: data.hourly.geopotential_height_650hPa[index],
                            thermalTriggerReachedForDay: thermalResult.thermalTriggerReachedForDay,
                            topOfLiftAltitude: thermalResult.topOfLiftAltitude,
                            topOfLiftTemp: thermalResult.topOfLiftTemp,
                            cloudbaseAltitude: thermalResult.cloudbaseAltitude)
                        thermalVelocity_600hPa = thermalResult.thermalVelocity
                        
                        // 550 hpa pressure level thermal calcs
                        thermalResult = calcThermalVelocity (
                            forecastBaseData: forecastBaseData,
                            altitude: data.hourly.geopotential_height_550hPa[index],
                            ambientTemp: data.hourly.temperature_550hPa[index],
                            ambientDPTemp: data.hourly.dewpoint_550hPa[index],
                            priorAmbientDPTemp: data.hourly.dewpoint_600hPa[index],
                            priorThermalDPTemp: thermalResult.thermalDPTemp,
                            priorAltitude: data.hourly.geopotential_height_600hPa[index],
                            thermalTriggerReachedForDay: thermalResult.thermalTriggerReachedForDay,
                            topOfLiftAltitude: thermalResult.topOfLiftAltitude,
                            topOfLiftTemp: thermalResult.topOfLiftTemp,
                            cloudbaseAltitude: thermalResult.cloudbaseAltitude)
                        thermalVelocity_550hPa = thermalResult.thermalVelocity
                        
                        // 500 hpa pressure level thermal calcs
                        thermalResult = calcThermalVelocity (
                            forecastBaseData: forecastBaseData,
                            altitude: data.hourly.geopotential_height_500hPa[index],
                            ambientTemp: data.hourly.temperature_500hPa[index],
                            ambientDPTemp: data.hourly.dewpoint_500hPa[index],
                            priorAmbientDPTemp: data.hourly.dewpoint_550hPa[index],
                            priorThermalDPTemp: thermalResult.thermalDPTemp,
                            priorAltitude: data.hourly.geopotential_height_550hPa[index],
                            thermalTriggerReachedForDay: thermalResult.thermalTriggerReachedForDay,
                            topOfLiftAltitude: thermalResult.topOfLiftAltitude,
                            topOfLiftTemp: thermalResult.topOfLiftTemp,
                            cloudbaseAltitude: thermalResult.cloudbaseAltitude)
                        thermalVelocity_500hPa = thermalResult.thermalVelocity

                        // Maintain status if thermal trigger has been reached for the day
                        thermalTriggerReachedForDay = thermalResult.thermalTriggerReachedForDay
                        
                        // Format cloudbase data if present (is a number and not 0 or very large)
                        // Altitudes are / 1000 so they can be displayed like "13k)
                        var formattedCloudbaseAltitude = ""
                        if thermalResult.cloudbaseAltitude > 0 && thermalResult.cloudbaseAltitude < 100000 {
                            formattedCloudbaseAltitude = String(Int((thermalResult.cloudbaseAltitude/1000).rounded())) + "k"
                        }
                        
                        // Format top of lift data
                        // Altitudes are / 1000 so they can be displayed like "13k)
                        var topOfLiftAltitude = thermalResult.topOfLiftAltitude
                        var formattedTopOfLiftAltitude = ""
                        var topOfLiftTemp = 0.0
                        if topOfLiftAltitude > 0 {
                            if topOfLiftAltitude > surfaceAltitude {
                                formattedTopOfLiftAltitude = String(Int((topOfLiftAltitude/1000).rounded())) + "k"
                            } else {
                                formattedTopOfLiftAltitude = ""
                                topOfLiftTemp = data.hourly.temperature_2m[index]
                            }
                        } else if thermalResult.thermalDPTemp > data.hourly.dewpoint_500hPa[index] {
                            // Never reached top of lift
                            formattedTopOfLiftAltitude = "rocket"
                            topOfLiftAltitude = defaultTopOfLiftAltitude
                            topOfLiftTemp = data.hourly.temperature_500hPa[index]
                        }
                        // Convert top of Lift Temp to F
                        let topOfLiftTempF = convertCelsiusToFahrenheit(Int(topOfLiftTemp))
                        
                        // Calculate surface gust factor
                        let gustFactor =  Int(data.hourly.windgusts_10m[index]) - Int(data.hourly.windspeed_10m[index])

                        // Only append display structure for times that are no more than an hour ago
                        // (earlier times only processed to determine if thermal trigger temp has already been reached today)
                        if timeObj >= oneHourAgo {
                            processedHourly.time.append(time)
                            processedHourly.dateTime?.append(timeObj)
                            processedHourly.formattedDay?.append(formattedDay)
                            processedHourly.formattedDate?.append(formattedDate)
                            processedHourly.formattedTime?.append(formattedTime)
                            processedHourly.newDateFlag?.append(newDateFlag)
                            processedHourly.weatherCodeImage?.append(weatherCodeImage)
                            processedHourly.weathercode.append(data.hourly.weathercode[index])
                            processedHourly.cloudcover.append(data.hourly.cloudcover[index])
                            if data.hourly.cloudcover[index] == 0 {
                                processedHourly.formattedCloudCover?.append("")
                            } else {
                                processedHourly.formattedCloudCover?.append(String(Int(data.hourly.cloudcover[index])))
                            }
                            processedHourly.precipitation_probability.append(data.hourly.precipitation_probability[index])
                            if data.hourly.precipitation_probability[index] == 0 {
                                processedHourly.formattedPrecipProbability?.append("")
                            } else {
                                processedHourly.formattedPrecipProbability?.append(String(Int(data.hourly.precipitation_probability[index])))
                            }
                            processedHourly.cape.append(data.hourly.cape[index])
                            if data.hourly.cape[index].rounded() == 0 {
                                processedHourly.formattedCAPE?.append("")
                            } else {
                                processedHourly.formattedCAPE?.append(String(Int(data.hourly.cape[index].rounded())))
                            }
                            processedHourly.temperature_2m.append(Double(surfaceTemp))
                            processedHourly.formattedSurfaceTemp?.append(String(surfaceTemp) + "°")
                            processedHourly.windspeed_500hPa.append(data.hourly.windspeed_500hPa[index].rounded())
                            processedHourly.windspeed_550hPa.append(data.hourly.windspeed_550hPa[index].rounded())
                            processedHourly.windspeed_600hPa.append(data.hourly.windspeed_600hPa[index].rounded())
                            processedHourly.windspeed_650hPa.append(data.hourly.windspeed_650hPa[index].rounded())
                            processedHourly.windspeed_700hPa.append(data.hourly.windspeed_700hPa[index].rounded())
                            processedHourly.windspeed_750hPa.append(data.hourly.windspeed_750hPa[index].rounded())
                            processedHourly.windspeed_800hPa.append(data.hourly.windspeed_800hPa[index].rounded())
                            processedHourly.windspeed_850hPa.append(data.hourly.windspeed_850hPa[index].rounded())
                            processedHourly.windspeed_900hPa.append(data.hourly.windspeed_900hPa[index].rounded())
                            processedHourly.windspeed_10m.append(data.hourly.windspeed_10m[index].rounded())
                            processedHourly.windgusts_10m.append(data.hourly.windgusts_10m[index].rounded())
                            processedHourly.winddirection_500hPa.append(data.hourly.winddirection_500hPa[index])
                            processedHourly.winddirection_550hPa.append(data.hourly.winddirection_550hPa[index])
                            processedHourly.winddirection_600hPa.append(data.hourly.winddirection_600hPa[index])
                            processedHourly.winddirection_650hPa.append(data.hourly.winddirection_650hPa[index])
                            processedHourly.winddirection_700hPa.append(data.hourly.winddirection_700hPa[index])
                            processedHourly.winddirection_750hPa.append(data.hourly.winddirection_750hPa[index])
                            processedHourly.winddirection_800hPa.append(data.hourly.winddirection_800hPa[index])
                            processedHourly.winddirection_850hPa.append(data.hourly.winddirection_850hPa[index])
                            processedHourly.winddirection_900hPa.append(data.hourly.winddirection_900hPa[index])
                            processedHourly.winddirection_10m.append(data.hourly.winddirection_10m[index])
                            // Heights are divided by 1,000 and rounded so they can be displayed like "12k ft"
                            processedHourly.geopotential_height_500hPa.append((data.hourly.geopotential_height_500hPa[index]/1000).rounded())
                            processedHourly.geopotential_height_550hPa.append((data.hourly.geopotential_height_550hPa[index]/1000).rounded())
                            processedHourly.geopotential_height_600hPa.append((data.hourly.geopotential_height_600hPa[index]/1000).rounded())
                            processedHourly.geopotential_height_650hPa.append((data.hourly.geopotential_height_650hPa[index]/1000).rounded())
                            processedHourly.geopotential_height_700hPa.append((data.hourly.geopotential_height_700hPa[index]/1000).rounded())
                            processedHourly.geopotential_height_750hPa.append((data.hourly.geopotential_height_750hPa[index]/1000).rounded())
                            processedHourly.geopotential_height_800hPa.append((data.hourly.geopotential_height_800hPa[index]/1000).rounded())
                            processedHourly.geopotential_height_850hPa.append((data.hourly.geopotential_height_850hPa[index]/1000).rounded())
                            processedHourly.geopotential_height_900hPa.append((data.hourly.geopotential_height_900hPa[index]/1000).rounded())
                            processedHourly.thermalVelocity_900hPa?.append(thermalVelocity_900hPa)
                            processedHourly.thermalVelocity_850hPa?.append(thermalVelocity_850hPa)
                            processedHourly.thermalVelocity_800hPa?.append(thermalVelocity_800hPa)
                            processedHourly.thermalVelocity_750hPa?.append(thermalVelocity_750hPa)
                            processedHourly.thermalVelocity_700hPa?.append(thermalVelocity_700hPa)
                            processedHourly.thermalVelocity_650hPa?.append(thermalVelocity_650hPa)
                            processedHourly.thermalVelocity_600hPa?.append(thermalVelocity_600hPa)
                            processedHourly.thermalVelocity_550hPa?.append(thermalVelocity_550hPa)
                            processedHourly.thermalVelocity_500hPa?.append(thermalVelocity_500hPa)
                            // Add top of lift results to data structure
                            processedHourly.formattedCloudbaseAltitude?.append(formattedCloudbaseAltitude)
                            if topOfLiftAltitude.isNaN {
                                print(String(topOfLiftAltitude))
                                topOfLiftAltitude = 0 }
                            // Set top of lift altitude to a minimum of surface altitude for area chart
                            // (leaves formatted top of lift altitude set to ""
                            processedHourly.topOfLiftAltitude?.append(max(topOfLiftAltitude, surfaceAltitude))
                            processedHourly.formattedTopOfLiftAltitude?.append(formattedTopOfLiftAltitude)
                            processedHourly.topOfLiftTemp?.append(Double(topOfLiftTempF))
                            processedHourly.formattedTopOfLiftTemp?.append(String(topOfLiftTempF) + "°")
                            processedHourly.gustFactor?.append(Double(gustFactor))
                            
                            //------------------------------------------------------------------------------------------------------
                            // Flying potential section
                            //------------------------------------------------------------------------------------------------------
                            
                            let cloudCoverColorValue = FlyingPotentialColor.value(for: cloudCoverColor(Int(data.hourly.cloudcover[index])))
                            let precipColorValue = FlyingPotentialColor.value(for: precipColor(Int(data.hourly.precipitation_probability[index])))
                            let CAPEColorValue = FlyingPotentialColor.value(for: CAPEColor(Int(data.hourly.cape[index])))
                            let surfaceWindColorValue = FlyingPotentialColor.value(for: windSpeedColor(windSpeed: Int(data.hourly.windspeed_10m[index]), siteType: siteType))
                            let surfaceGustColorValue = FlyingPotentialColor.value(for: windSpeedColor(windSpeed: Int(data.hourly.windgusts_10m[index]), siteType: siteType))
                            let gustFactorColorValue = FlyingPotentialColor.value(for: gustFactorColor(gustFactor))
                            
                            // Winds aloft and thermals up to 6k ft (800 hpa) for all sites; higher altitude for mountain sites
                            var windsAloftMax: Double = max(data.hourly.windspeed_900hPa[index],
                                                    data.hourly.windspeed_850hPa[index],
                                                    data.hourly.windspeed_800hPa[index])
                            var thermalVelocityMax: Double = max(thermalVelocity_900hPa,
                                                         thermalVelocity_850hPa,
                                                         thermalVelocity_800hPa)
                            if siteType == "Mountain" {
                                windsAloftMax = max(windsAloftMax,
                                                    data.hourly.windspeed_750hPa[index],
                                                    data.hourly.windspeed_700hPa[index],
                                                    data.hourly.windspeed_650hPa[index])
                                thermalVelocityMax = max(thermalVelocityMax,
                                                         thermalVelocity_750hPa,
                                                         thermalVelocity_700hPa,
                                                         thermalVelocity_650hPa)
                            }
                            let thermalVelocityColorValue = FlyingPotentialColor.value(for: thermalColor(thermalVelocityMax))
                            let windsAloftColorValue = FlyingPotentialColor.value(for: windSpeedColor(
                                    windSpeed: Int(windsAloftMax), siteType: siteType))

                            // Determine wind direction color for site
                            let windDirectionColorValue = FlyingPotentialColor.value(for: windDirectionColor(
                                siteWindDirection:  siteWindDirection,
                                siteType:           siteType,
                                windDirection:      Int(data.hourly.winddirection_10m[index]),
                                windSpeed:          Int(data.hourly.windspeed_10m[index]),
                                windGust:           Int(data.hourly.windgusts_10m[index])))

                            // Determine potential
                            var combinedColorValue = max(cloudCoverColorValue,
                                                         precipColorValue,
                                                         CAPEColorValue,
                                                         windsAloftColorValue,
                                                         surfaceWindColorValue,
                                                         surfaceGustColorValue,
                                                         gustFactorColorValue,
                                                         windDirectionColorValue)
                            
                            // For soaring sites, reduce the value if wind speed can is too low to soar
                            if siteType == "Soaring" {
                                if combinedColorValue <= FlyingPotentialColor.value(for: .green) {
                                    // No warning conditions; base color on wind, including "downgrading" if there isn't enough surface wind
                                    combinedColorValue = max(surfaceWindColorValue, surfaceGustColorValue)
                                }
                            }
                            // Note:  Not currently checking top of lift to limit winds aloft readings
                            
                            // Store potential results
                            processedHourly.combinedColorValue?.append(combinedColorValue)
                            processedHourly.cloudCoverColorValue?.append(cloudCoverColorValue)
                            processedHourly.precipColorValue?.append(precipColorValue)
                            processedHourly.CAPEColorValue?.append(CAPEColorValue)
                            processedHourly.windDirectionColorValue?.append(windDirectionColorValue)
                            processedHourly.surfaceWindColorValue?.append(surfaceWindColorValue)
                            processedHourly.surfaceGustColorValue?.append(surfaceGustColorValue)
                            processedHourly.gustFactorColorValue?.append(gustFactorColorValue)
                            processedHourly.windsAloftColorValue?.append(windsAloftColorValue)
                            processedHourly.thermalVelocityColorValue?.append(thermalVelocityColorValue)
                            processedHourly.windsAloftMax?.append(windsAloftMax)
                            processedHourly.thermalVelocityMax?.append(thermalVelocityMax)
                            
                        }
                    }
                }
            }
        }
        return (maxPressureReading, ForecastData(id:        id,
                                                 elevation: data.elevation,
                                                 hourly:    processedHourly))
    }
    
    struct ThermalResult {
        let thermalVelocity: Double
        let thermalDPTemp: Double
        let cloudbaseAltitude: Double
        let topOfLiftAltitude: Double
        let topOfLiftTemp: Double
        let thermalTriggerReachedForDay: Bool
    }
    
    func calcThermalVelocity(
        forecastBaseData: ForecastBaseData,
        altitude: Double,
        ambientTemp: Double,
        ambientDPTemp: Double,
        priorAmbientDPTemp: Double,
        priorThermalDPTemp: Double,
        priorAltitude: Double,
        thermalTriggerReachedForDay: Bool,
        topOfLiftAltitude: Double,
        topOfLiftTemp: Double,
        cloudbaseAltitude: Double
    ) -> ThermalResult {

        // Set buffer for calculation altitudes (should be the same as the buffer set in the above function)
        let surfaceBuffer = 200.0
        
        // Base values passed (common for all altitudes)
        let siteName = forecastBaseData.siteName
        let forecastDate = forecastBaseData.date
        let forecastTime = forecastBaseData.time
        let surfaceAltitude = forecastBaseData.surfaceAltitude
        let surfaceTemp = forecastBaseData.surfaceTemp
        
        // Initial values (setting here to allow all to be written to log file)
        var thermalDPTemp = priorThermalDPTemp
        var thermalVelocity: Double = 0.0
        var cloudbaseRatio: Double = 0.0
        var cloudbaseAltitude = cloudbaseAltitude
        var topOfLiftAltitude  = topOfLiftAltitude
        var topOfLiftTemp = topOfLiftTemp
        var thermalTriggerReachedForDay = thermalTriggerReachedForDay
        var topOfLiftRatio: Double = 0.0
        var altitudeChange: Double = 0.0
        var thermalRampTop: Double = 0.0
        var rampImpactAltitude: Double = 0.0
        var rampImpactPortion: Double = 0.0
        var rampReductionFactor: Double = 0.0
        var thermalDPTempToAmbientDPTempDiff: Double = 0.0
        var ambientTempToAmbientDPTempDiff: Double = 0.0
        var ambientDPTempDiff: Double = 0.0
        var priorAmbientDPTempToAmbientTempDiff: Double = 0.0
        var priorAltitudeThermalDPDiff: Double = 0.0
        var priorThermalDPTempToAmbientDPTempDiff: Double = 0.0

        // Get thermal lift parameters from environment object
        guard let liftParameters = liftParametersViewModel.liftParameters else {
            // End processing if lift parameters are not available
            print("Error - thermal lift parameters not available")
            if logThermalCalcs {logToFile("Error - thermal lift parameters not available") }
            return ThermalResult(
                thermalVelocity: thermalVelocity,
                thermalDPTemp: thermalDPTemp,
                cloudbaseAltitude: cloudbaseAltitude,
                topOfLiftAltitude: topOfLiftAltitude,
                topOfLiftTemp: topOfLiftTemp,
                thermalTriggerReachedForDay: thermalTriggerReachedForDay)
        }

        // Check if altitude is less than surfaceAltitude
        guard altitude >= (surfaceAltitude + surfaceBuffer) else {
            // End processing if altitude is less than surfaceAltitude
            return ThermalResult(
                thermalVelocity: thermalVelocity,
                thermalDPTemp: thermalDPTemp,
                cloudbaseAltitude: cloudbaseAltitude,
                topOfLiftAltitude: topOfLiftAltitude,
                topOfLiftTemp: topOfLiftTemp,
                thermalTriggerReachedForDay: thermalTriggerReachedForDay)
        }
        
        // Set priorAltitude to surfaceAltitude if it is less than surfaceAltitude
        let adjustedPriorAltitude = priorAltitude < surfaceAltitude ? surfaceAltitude : priorAltitude
        
        // Only process if top of lift has not been previously reached
        if topOfLiftAltitude < surfaceAltitude {
            
            // Check if initial thermal trigger temperature difference between ground temp and ambient temp is not yet reached for the day
            // If it has previously been reached, use ongoing thermal trigger temperature difference instead
            var adjustedThermalTriggerTempDiff = liftParameters.initialTriggerTempDiff
            if thermalTriggerReachedForDay {
                adjustedThermalTriggerTempDiff = liftParameters.ongoingTriggerTempDiff
            }
            // if thermals not yet triggering; set top of lift to surface altitude
            if  surfaceTemp < ( ambientTemp + adjustedThermalTriggerTempDiff) {
                topOfLiftAltitude = adjustedPriorAltitude
            }
            // Thermal trigger temp reached...continue processing
            else {

                // Ensure thermal trigger temp reached is set to true
                thermalTriggerReachedForDay = true
                
                // Determine altitude change
                altitudeChange = altitude - adjustedPriorAltitude
                
                // Convert altitude from feet to kilometers
                let altitudeKm = convertFeetToMeters(altitude) / 1000
                let adjustedPriorAltitudeKm = convertFeetToMeters(adjustedPriorAltitude) / 1000
                let altitudeChangeKm = altitudeKm - adjustedPriorAltitudeKm
                
                // Td = T - (DALR * altitudeChange in km) where DALR is the thermalLapseRate
                thermalDPTemp = priorThermalDPTemp - ( liftParameters.thermalLapseRate * altitudeChangeKm )
                
                // Calculate temperature differences
                thermalDPTempToAmbientDPTempDiff = max( (thermalDPTemp - ambientDPTemp), 0.0 )
                ambientTempToAmbientDPTempDiff = max( (ambientTemp - ambientDPTemp), 0.0 )
                ambientDPTempDiff = max( (priorAmbientDPTemp - ambientDPTemp), 0.0 )
                priorAmbientDPTempToAmbientTempDiff = max( priorAmbientDPTemp - ambientTemp, 0.0)
                priorAltitudeThermalDPDiff = max( (priorAmbientDPTemp - thermalDPTemp), 0.0 )
                priorThermalDPTempToAmbientDPTempDiff = max( (priorThermalDPTemp - priorAmbientDPTemp), 0.0 )
                
                // Determine if cloudbase is reached (thermal dew point temp does not exceed ambient temp)
                if  ambientTemp <= ambientDPTemp {
                    if ambientDPTempDiff == 0 {
                        cloudbaseAltitude = adjustedPriorAltitude
                    } else {
                        cloudbaseRatio = priorAmbientDPTempToAmbientTempDiff / priorAltitudeThermalDPDiff
                        cloudbaseAltitude = adjustedPriorAltitude + ( altitudeChange * cloudbaseRatio )
                    }
                }
                
                // Determine if top of lift is reached (thermal dew point temp does not exceed ambient dew point)
                if thermalDPTemp <= ambientDPTemp {
                    if priorThermalDPTempToAmbientDPTempDiff == 0 {
                        topOfLiftAltitude = adjustedPriorAltitude
                        topOfLiftTemp = ambientTemp     // Should actually be prior ambient temp, which is not available
                    } else {
                        if priorAltitudeThermalDPDiff == 0 {
                            // Prior ambient DP temp <= thermal DP temp (top of lift should have been already reached)
                            // May be indicative of an inversion layer
                            topOfLiftAltitude = adjustedPriorAltitude
                            topOfLiftTemp = ambientTemp     // Should actually be prior ambient temp, which is not available
                        } else {
                            topOfLiftRatio = ( priorAmbientDPTempToAmbientTempDiff / priorAltitudeThermalDPDiff )
                            if topOfLiftRatio.isNaN {
                                print("topOfLiftRatio is NaN, \(priorAmbientDPTempToAmbientTempDiff), \(priorAltitudeThermalDPDiff), \(priorAmbientDPTemp), \(thermalDPTemp)")
                                topOfLiftRatio = 0.0
                            }
                            topOfLiftAltitude = adjustedPriorAltitude + ( altitudeChange * topOfLiftRatio )
                            topOfLiftTemp = ambientTemp     // Should actually be a ratio of prior and current ambient Temps
                        }
                    }
                }
                
                // If cloudbase < top of lift, set top of (usable) lift to cloudbase
                if cloudbaseAltitude > 0.0 && topOfLiftAltitude > 0.0 && cloudbaseAltitude < topOfLiftAltitude {
                    topOfLiftAltitude = cloudbaseAltitude
                }
                
                // If neither cloudbase or top of lift is reached, calculate thermal velocity (w)
                if cloudbaseAltitude == 0.0 && topOfLiftAltitude == 0.0 {
                    // w = thermalVelocityConstant * sqrt [ ((1.1)^(thermalDPTemp - ambDPTemp) - 1) / ((1.1)^(ambTemp - ambDPTemp)-1) ]
                    // Thermal velocity:
                    //      Increases with warmer or dryer thermal compared to ambient air
                    //      Decreases with dryer ambient air
                    thermalVelocity = liftParameters.thermalVelocityConstant * sqrt( (pow(1.1, thermalDPTempToAmbientDPTempDiff) - 1) / (pow(1.1, ambientTempToAmbientDPTempDiff) - 1))
                    
                    // Adjust thermal velocity if within thermal ramp distance (near the surface)
                    thermalRampTop = surfaceAltitude + liftParameters.thermalRampDistance
                    if thermalRampTop > adjustedPriorAltitude {
                        rampImpactAltitude = min(altitude, thermalRampTop) - adjustedPriorAltitude
                        rampImpactPortion = rampImpactAltitude / (altitude - adjustedPriorAltitude)
                        rampReductionFactor = liftParameters.thermalRampStartPct / 100 * rampImpactPortion
                        thermalVelocity = thermalVelocity * (1 - rampReductionFactor)
                    }
                    
                    // Adjust thermal velocity for glider sink rate
                    thermalVelocity = max( (thermalVelocity - liftParameters.thermalGliderSinkRate ), 0.0)
                    
                    // Adjust down top of usaeable lift if thermalVelocity is less than glider sink rate
                    if thermalVelocity <= 0 {
                        if topOfLiftAltitude > 0 {
                            topOfLiftAltitude = min(altitude, topOfLiftAltitude)
                            topOfLiftTemp = ambientTemp
                        } else {
                            // Set top of lift conservatively to the bottom of the altitude range being evaluated
                            topOfLiftAltitude = adjustedPriorAltitude
                            topOfLiftTemp = ambientTemp     // Should actually be prior ambient temp, which is not available
                        }
                    }
                }
            }
        }
        
        // If logging is turned on, write data for thermal calc troubleshooting
        if logThermalCalcs {
            logToFile(
                "\(siteName)," +
                "\(forecastDate)," +
                "\(forecastTime)," +
                "\(surfaceAltitude)," +
                "\(surfaceTemp)," +
                "\(altitude)," +
                "\(ambientTemp)," +
                "\(ambientDPTemp)," +
                "\(thermalVelocity)," +
                "\(thermalTriggerReachedForDay)," +
                "\(topOfLiftAltitude)," +
                "\(cloudbaseAltitude)," +
                "\(adjustedPriorAltitude)," +
                "\(altitudeChange)," +
                "\(topOfLiftRatio)," +
                "\(cloudbaseRatio)," +
                "\(priorAmbientDPTemp)," +
                "\(thermalDPTemp)," +
                "\(priorThermalDPTemp)," +
                "\(thermalDPTempToAmbientDPTempDiff)," +
                "\(ambientTempToAmbientDPTempDiff)," +
                "\(ambientDPTempDiff)," +
                "\(priorThermalDPTempToAmbientDPTempDiff)," +
                "\(priorAmbientDPTempToAmbientTempDiff)," +
                "\(thermalRampTop)," +
                "\(rampImpactAltitude)," +
                "\(rampImpactPortion)," +
                "\(rampReductionFactor)," +
                "\(liftParameters.thermalLapseRate)," +
                "\(liftParameters.thermalVelocityConstant)," +
                "\(liftParameters.initialTriggerTempDiff)," +
                "\(liftParameters.ongoingTriggerTempDiff)," +
                "\(liftParameters.thermalRampDistance)," +
                "\(liftParameters.thermalRampStartPct)," +
                "\(liftParameters.cloudbaseLapseRatesDiff)," +
                "\(liftParameters.thermalGliderSinkRate)"
            )
        }
        
        return ThermalResult(
            thermalVelocity: roundToOneDecimal(thermalVelocity),
            thermalDPTemp: thermalDPTemp,
            cloudbaseAltitude: cloudbaseAltitude,
            topOfLiftAltitude: topOfLiftAltitude,
            topOfLiftTemp: topOfLiftTemp,
            thermalTriggerReachedForDay: thermalTriggerReachedForDay
        )
    }
}
