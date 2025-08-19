import SwiftUI
import Combine

struct StationLatestReading: Identifiable {
    let id = UUID()
    let stationID: String
    let stationName: String
    let readingsSource: String
    let stationElevation: String
    let stationLatitude: String
    let stationLongitude: String
    let windSpeed: Double?
    let windDirection: Double?
    let windGust: Double?
    let windTime: String?
}

// Structures to parse Mesonet latest readings data
struct MesonetLatestResponse: Codable {
    let station: [MesonetLatestStation]
    
    enum CodingKeys: String, CodingKey {
        case station = "STATION"
    }
}

struct MesonetLatestStation: Codable {
    let id: String
    let stationID: String
    let stationName: String
    let elevation: String
    let latitude: String
    let longitude: String
    let status: String
    let observations: MesonetLatestObservations
    
    enum CodingKeys: String, CodingKey {
        case id = "ID"
        case stationID = "STID"
        case stationName = "NAME"
        case elevation = "ELEVATION"
        case latitude = "LATITUDE"
        case longitude = "LONGITUDE"
        case status = "STATUS"
        case observations = "OBSERVATIONS"
    }
}

struct MesonetLatestObservations: Codable {
    let airTemp: MesonetLatestObservationsValues?
    let windSpeed: MesonetLatestObservationsValues?
    let windDirection: MesonetLatestObservationsValues?
    let windGust: MesonetLatestObservationsValues?
    
    enum CodingKeys: String, CodingKey {
        case airTemp = "air_temp_value_1"
        case windSpeed = "wind_speed_value_1"
        case windDirection = "wind_direction_value_1"
        case windGust = "wind_gust_value_1"
    }
}

struct MesonetLatestObservationsValues: Codable {
    let value: Double?
    let dateTime: String?
    
    enum CodingKeys: String, CodingKey {
        case value
        case dateTime = "date_time"
    }
}

struct CUASAStationData: Codable {
    var id: Int
    var name: String
    var lat: Double
    var lon: Double
}

struct CUASAReadingsData: Codable {
    var ID: String
    var timestamp: Double
    var windspeed: Double
    var windspeed_avg: Double
    var windspeed_max: Double
    var windspeed_min: Double
    var wind_direction: Double
    var wind_direction_avg: Double
    var battery_level: Double?
    var internal_temp: Double?
    var external_temp: Double?
    var current: Double?
    var pwm: Double?
}

// Decoding model for API response
struct RMHPAAPIResponse: Decodable {
    let metadata: RHMPHAMetadata
    let data: [RMHPAReadingData]
}

struct RHMPHAMetadata: Decodable {
    let name: String
    let id: String
    let device_id: String
    let timezone: String
    let lat: Double
    let lon: Double
    let elevation: Int
    let link: String
}

struct RMHPAReadingData: Decodable {
    let timestamp: String
    let absolute: Double?
    let relative: Double?
    let wind_direction: Double?
    let wind_gust: Double?
    let wind_speed: Double?
}

@MainActor
class StationLatestReadingViewModel: ObservableObject {
    @Published var latestSiteReadings: [StationLatestReading] = []
    @Published var latestAllReadings: [StationLatestReading] = []
    @Published var stationParameters: String = ""
    @Published var isLoading = false
    
    private var lastSiteFetchTime: Date? = nil
    private var lastAllFetchTime: Date? = nil
    private var lastFavoriteStationIDs: Set<String> = []    // Used to force a refresh if new favorite stations are added from map page
    
    let siteViewModel: SiteViewModel
    let userSettingsViewModel: UserSettingsViewModel
    
    init(siteViewModel: SiteViewModel,
         userSettingsViewModel: UserSettingsViewModel) {
        self.siteViewModel = siteViewModel
        self.userSettingsViewModel = userSettingsViewModel
    }
    
    // Allows forced reset when user changes regions, resets metadata, etc.
    func resetLastFetchTimes() {
        latestSiteReadings = []
        latestAllReadings = []
        lastSiteFetchTime = nil
        lastAllFetchTime = nil
    }
    
    // sitesOnly determines whether to only get Mesonet readings for stations associated with sites (SiteView)
    // or all stations in region (MapView)
    func getLatestReadingsData(sitesOnly: Bool) async {

        var favoriteStationIDs: Set<String> = []
        
        if sitesOnly {
            let mesonetStations = siteViewModel.sites
                .filter { $0.readingsSource == "Mesonet" && !$0.readingsStation.isEmpty }
                .map { $0.readingsStation }
            
            let currentRegion = RegionManager.shared.activeAppRegion
            favoriteStationIDs = Set(
                userSettingsViewModel.userFavoriteSites
                    .filter {
                        $0.appRegion == currentRegion &&
                        $0.favoriteType.lowercased() == "station" &&
                        $0.readingsSource == "Mesonet" &&
                        !$0.stationID.isEmpty
                    }
                    .map { $0.stationID }
            )
            
            let allStations = Set(mesonetStations).union(favoriteStationIDs)
            guard !allStations.isEmpty else { return }
            
            stationParameters = allStations.map { "&stid=\($0)" }.joined()
        }
        
        // Check if refresh interval has passed
        let now = Date()
        let lastFetchTime = sitesOnly ? lastSiteFetchTime : lastAllFetchTime
        var shouldForceRefresh = false
        
        if sitesOnly {
            // Compare favoriteStationIDs to last fetched set
            if favoriteStationIDs != lastFavoriteStationIDs {
                shouldForceRefresh = true
                lastFavoriteStationIDs = favoriteStationIDs
            }
        }
        
        if !shouldForceRefresh, let last = lastFetchTime, now.timeIntervalSince(last) < readingsRefreshInterval {
            return
        }
        
        // Set loading status for network calls
        isLoading = true
        defer { isLoading = false }

        // Update last fetch times
        if sitesOnly {
            lastSiteFetchTime = now
        } else {
            lastAllFetchTime = now
        }
        
        // Build API call parameters
        let regionCountry = AppRegionManager.shared.getRegionCountry() ?? ""
        let regionState = AppRegionManager.shared.getRegionState() ?? ""
        let stationParams = sitesOnly
            ? stationParameters
            : (regionCountry == "US"
               ? "&state=\(regionState)"
               : "&country=\(regionCountry)")
        
        // Fetch all three sources in parallel
        async let mesonetReadings = getLatestMesonetReadings(stationParameters: stationParams)
        async let cuasaReadings = getLatestCUASAReadings()
        async let rmhpaReadings = getLatestRMHPAReadings()
        
        let mesonetResult = await mesonetReadings
        let cuasaResult   = await cuasaReadings
        let rmhpaResult   = await rmhpaReadings
        let combined = mesonetResult + cuasaResult + rmhpaResult
        
        if sitesOnly {
            latestSiteReadings = combined
        } else {
            latestAllReadings = combined
        }
    }
    
    // Mesonet
    func getLatestMesonetReadings(stationParameters: String) async -> [StationLatestReading] {
        let baseURL = AppURLManager.shared.getAppURL(URLName: "mesonetLatestReadingsAPI") ?? ""
        let updated = updateURL(url: baseURL, parameter: "stationlist", value: stationParameters) + synopticsAPIToken
        guard let url = URL(string: updated) else { return [] }
        
        do {
            let data = try await AppNetwork.shared.fetchDataAsync(url: url)
            let decoded = try JSONDecoder().decode(MesonetLatestResponse.self, from: data)
            return decoded.station.compactMap { station in
                guard let _ = station.observations.windSpeed?.value,
                      let _ = station.observations.windSpeed?.dateTime else { return nil }
                return StationLatestReading(
                    stationID:          station.stationID,
                    stationName:        station.stationName,
                    readingsSource:     "Mesonet",
                    stationElevation:   station.elevation,
                    stationLatitude:    station.latitude,
                    stationLongitude:   station.longitude,
                    windSpeed:          station.observations.windSpeed?.value,
                    windDirection:      station.observations.windDirection?.value,
                    windGust:           station.observations.windGust?.value,
                    windTime:           station.observations.windSpeed?.dateTime
                )
            }
        } catch {
            print("Mesonet fetch failed: \(error)")
            return []
        }
    }
    
    // CUASA
    func getLatestCUASAReadings() async -> [StationLatestReading] {
        let cuasaStations = Array(
            Dictionary(grouping: siteViewModel.sites.filter { $0.readingsSource == "CUASA" }, by: { $0.readingsStation })
                .compactMap { $0.value.first }
        )
        guard !cuasaStations.isEmpty else { return [] }
        
        var results: [StationLatestReading] = []
        let readingInterval: Double = 5 * 60
        let readingEnd = Date().timeIntervalSince1970
        let readingStart = readingEnd - readingInterval
        
        for station in cuasaStations {
            do {
                let infoURLString = updateURL(url: AppURLManager.shared.getAppURL(URLName: "CUASAStationInfoAPI") ?? "",
                                              parameter: "station", value: station.readingsStation)
                guard let infoURL = URL(string: infoURLString) else { continue }
                let infoData = try await AppNetwork.shared.fetchDataAsync(url: infoURL)
                let stationInfo = try JSONDecoder().decode(CUASAStationData.self, from: infoData)
                
                var readingsURLString = updateURL(url: AppURLManager.shared.getAppURL(URLName: "CUASAHistoryReadingsAPI") ?? "",
                                                  parameter: "station", value: station.readingsStation)
                readingsURLString = updateURL(url: readingsURLString, parameter: "readingStart", value: String(readingStart))
                readingsURLString = updateURL(url: readingsURLString, parameter: "readingEnd", value: String(readingEnd))
                readingsURLString = updateURL(url: readingsURLString, parameter: "readingInterval", value: String(readingInterval))
                guard let readingsURL = URL(string: readingsURLString) else { continue }
                
                let readingsData = try await AppNetwork.shared.fetchDataAsync(url: readingsURL)
                let readingsArray = try JSONDecoder().decode([CUASAReadingsData].self, from: readingsData)
                
                if let latest = readingsArray.max(by: { $0.timestamp < $1.timestamp }) {
                    let date = Date(timeIntervalSince1970: latest.timestamp)
                    let formatter = DateFormatter()
                    formatter.dateFormat = "h:mm"
                    let formattedTime = formatter.string(from: date)
                    
                    results.append(StationLatestReading(
                        stationID:              latest.ID,
                        stationName:            stationInfo.name,
                        readingsSource:         "CUASA",
                        stationElevation:       station.readingsAlt,
                        stationLatitude:        String(stationInfo.lat),
                        stationLongitude:       String(stationInfo.lon),
                        windSpeed:              convertKMToMiles(latest.windspeed_avg).rounded(),
                        windDirection:          latest.wind_direction_avg,
                        windGust:               convertKMToMiles(latest.windspeed_max).rounded(),
                        windTime:               formattedTime
                    ))
                }
            } catch {
                print("CUASA fetch error: \(error)")
            }
        }
        
        return results
    }
    
    // RMHPA
    func getLatestRMHPAReadings() async -> [StationLatestReading] {
        let rmhpaStations = Array(
            Dictionary(grouping: siteViewModel.sites.filter { $0.readingsSource == "RMHPA" }, by: { $0.readingsStation })
                .compactMap { $0.value.first }
        )
        guard !rmhpaStations.isEmpty else { return [] }
        
        var results: [StationLatestReading] = []
        
        for station in rmhpaStations {
            do {
                let urlString = updateURL(url: AppURLManager.shared.getAppURL(URLName: "RMHPALatestReadingsAPI") ?? "",
                                          parameter: "station", value: station.readingsStation)
                guard let url = URL(string: urlString) else { continue }

                var request = URLRequest(url: url)
                request.httpMethod = "GET"
                request.setValue(RMHPAAPIKey, forHTTPHeaderField: "x-api-key")
                request.setValue("application/json", forHTTPHeaderField: "Accept")
                
                let data = try await AppNetwork.shared.fetchDataAsync(request: request)
                let apiResponse = try JSONDecoder().decode(RMHPAAPIResponse.self, from: data)
                guard let reading = apiResponse.data.first else { continue }
                
                let metadata = apiResponse.metadata
                let inputFormatter = DateFormatter()
                inputFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"
                inputFormatter.timeZone = TimeZone(secondsFromGMT: 0)
                
                let outputFormatter = DateFormatter()
                outputFormatter.dateFormat = "h:mm"
                let formattedTime = inputFormatter.date(from: reading.timestamp).map { outputFormatter.string(from: $0) } ?? ""
                
                results.append(StationLatestReading(
                    stationID: metadata.device_id,
                    stationName: metadata.name,
                    readingsSource: "RMHPA",
                    stationElevation: String(metadata.elevation),
                    stationLatitude: String(metadata.lat),
                    stationLongitude: String(metadata.lon),
                    windSpeed: reading.wind_speed,
                    windDirection: reading.wind_direction,
                    windGust: reading.wind_gust,
                    windTime: formattedTime
                ))
                
            } catch {
                print("RMHPA fetch error: \(error)")
            }
        }
        
        return results
    }
}
