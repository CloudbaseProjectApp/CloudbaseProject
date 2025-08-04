import SwiftUI
import Combine
import Charts

struct ReadingsData: Codable {
    let STATION: [Station]
}

struct Station: Codable {
    let OBSERVATIONS: Observations
}

struct Observations: Codable {
    let date_time: [String]
    let wind_speed_set_1: [Double?]
    let wind_gust_set_1: [Double?]?
    let wind_direction_set_1: [Double]
}

struct ReadingsHistoryData {
    var times: [String]
    var windSpeed: [Double]
    var windGust: [Double?]
    var windDirection: [Double]
    var errorMessage: String?
}

class StationReadingsHistoryDataModel: ObservableObject {
    @Published var readingsHistoryData = ReadingsHistoryData(
        times: [],
        windSpeed: [],
        windGust: [],
        windDirection: [],
        errorMessage: nil
    )
    private var cancellable: AnyCancellable?
    private var cancellables = Set<AnyCancellable>()
    
    func GetReadingsHistoryData(stationID: String, readingsSource: String) {
        switch readingsSource {
        case "Mesonet":
            let readingsLink = AppURLManager.shared.getAppURL(URLName: "mesonetHistoryReadingsAPI") ?? "<Unknown Mesonet readings history API URL>"
            let updatedReadingsLink = updateURL(url: readingsLink, parameter: "station", value: stationID) + synopticsAPIToken
            let url = URL(string: updatedReadingsLink)!
            if printReadingsURL { print(url) }
            cancellable = URLSession.shared.dataTaskPublisher(for: url)
                .map { $0.data }
                .map { data in
                    // Convert data to string, replace "null" with "0.0", and convert back to data
                    if var jsonString = String(data: data, encoding: .utf8) {
                        jsonString = jsonString.replacingOccurrences(of: "null", with: "0.0")
                        return Data(jsonString.utf8)
                    }
                    return data
                }
                .decode(type: ReadingsData.self, decoder: JSONDecoder())
                .replaceError(with: ReadingsData(STATION: []))
                .receive(on: DispatchQueue.main)
                .sink { [weak self] data in
                    guard let self = self, let station = data.STATION.first else {
                        print("No valid data found for station: \(stationID)")
                        self?.readingsHistoryData.errorMessage = "No valid data found for station: \(stationID)"
                        return
                    }
                    let recentTimes = Array(station.OBSERVATIONS.date_time.suffix(8))
                    let recentWindSpeed = Array(station.OBSERVATIONS.wind_speed_set_1.suffix(8)).map { $0 ?? 0.0 }
                    let recentWindGust = station.OBSERVATIONS.wind_gust_set_1?.suffix(8).map { $0 ?? 0.0 } ?? Array(repeating: nil, count: 8)
                    let recentWindDirection = Array(station.OBSERVATIONS.wind_direction_set_1.suffix(8))
                    if let latestTimeString = recentTimes.last,
                       let latestTime = ISO8601DateFormatter().date(from: latestTimeString),
                       Date().timeIntervalSince(latestTime) > 2 * 60 * 60 {
                        self.readingsHistoryData.errorMessage = "Station \(stationID) has not updated in the past 2 hours"
                        print("Station \(stationID) has not updated in the past 2 hours")
                    } else {
                        self.readingsHistoryData.times = recentTimes
                        self.readingsHistoryData.windSpeed = recentWindSpeed
                        self.readingsHistoryData.windGust = recentWindGust
                        self.readingsHistoryData.windDirection = recentWindDirection
                        self.readingsHistoryData.errorMessage = nil
                    }
                }

        case "CUASA":
            let readingInterval: Double = 5 * 60 // 5 minutes in seconds
            let readingEnd = Date().timeIntervalSince1970 // current timestamp in seconds
            let readingStart = readingEnd - (readingInterval * 10) // to ensure >= 8 readings
            let readingsLink = AppURLManager.shared.getAppURL(URLName: "CUASAHistoryReadingsAPI") ?? "<Unknown CUASA readings history API URL>"
            var updatedReadingsLink = updateURL(url: readingsLink, parameter: "station", value: stationID)
            updatedReadingsLink = updateURL(url: updatedReadingsLink, parameter: "readingStart", value: String(readingStart))
            updatedReadingsLink = updateURL(url: updatedReadingsLink, parameter: "readingEnd", value: String(readingEnd))
            updatedReadingsLink = updateURL(url: updatedReadingsLink, parameter: "readingInterval", value: String(readingInterval))

            guard let url = URL(string: updatedReadingsLink) else {
                self.readingsHistoryData.errorMessage = "Invalid CUASA readings URL"
                print("Invalid CUASA readings URL")
                return
            }
            if printReadingsURL { print(url) }
            URLSession.shared.dataTaskPublisher(for: url)
                .map { $0.data }
                .decode(type: [CUASAReadingsData].self, decoder: JSONDecoder())
                .receive(on: DispatchQueue.main)
                .sink(receiveCompletion: { completion in
                    switch completion {
                    case .failure(let error):
                        self.readingsHistoryData.errorMessage = error.localizedDescription
                        print("Error fetching CUASA data: \(error.localizedDescription)")
                    case .finished:
                        break
                    }
                }, receiveValue: { [weak self] readingsHistoryDataArray in
                    self?.processCUASAReadingsHistoryData(readingsHistoryDataArray)
                })
                .store(in: &cancellables)

        case "RMHPA":
            let readingsLink = AppURLManager.shared.getAppURL(URLName: "RMHPAHistoryReadingsAPI") ?? "<Unknown CUASA readings history API URL>"
            let updatedReadingsLink = updateURL(url: readingsLink, parameter: "station", value: stationID)
            guard let url = URL(string: updatedReadingsLink) else {
                self.readingsHistoryData.errorMessage = "Invalid RMPHA readings URL"
                print("Invalid RMPHA readings URL")
                return
            }
            
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.setValue(RMHPAAPIKey, forHTTPHeaderField: "x-api-key")
            request.setValue("application/json", forHTTPHeaderField: "Accept")

            if printReadingsURL { print(url) }
            URLSession.shared.dataTaskPublisher(for: request)
                .map { $0.data }
                .decode(type: RMHPAAPIResponse.self, decoder: JSONDecoder())
                .receive(on: DispatchQueue.main)
                .sink(receiveCompletion: { completion in
                    switch completion {
                    case .failure(let error):
                        self.readingsHistoryData.errorMessage = error.localizedDescription
                        print("Error fetching RMPHA data: \(error.localizedDescription)")
                    case .finished:
                        break
                    }
                }, receiveValue: { [weak self] response in
                    self?.processRMHPAReadingHistoryData(response.data)
                })
                .store(in: &cancellables)
        default:
            print("Invalid readings source for station: \(stationID)")
        }
    }
    
    private func processCUASAReadingsHistoryData(_ readingsHistoryDataArray: [CUASAReadingsData]) {
        guard let latestEntry = readingsHistoryDataArray.last else {
            self.readingsHistoryData.errorMessage = "No data available"
            print("No data available from CUASA")
            return
        }
        let currentTime = Date().timeIntervalSince1970
        let twoHoursInSeconds: Double = 2 * 60 * 60
        if currentTime - latestEntry.timestamp > twoHoursInSeconds {
            self.readingsHistoryData.errorMessage = "Station has not updated in the past 2 hours"
            print("Station has not updated in the past 2 hours")
            return
        }
        let recentEntries = Array(readingsHistoryDataArray.suffix(8))
        updateCUASAReadingsHistory(with: recentEntries)
    }
    
    private func processRMHPAReadingHistoryData(_ readingsHistoryDataArray: [RMHPAReadingData]) {

        guard let latestEntry = readingsHistoryDataArray.last else {
            self.readingsHistoryData.errorMessage = "No data available"
            print("No data available from RMHPA")
            return
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"
        formatter.timeZone = TimeZone(secondsFromGMT: 0) // 'Z' means UTC

        // Make sure there is a recent reading
        let twoHoursInSeconds: Double = 2 * 60 * 60
        if let latestReadingTimestamp = formatter.date(from: latestEntry.timestamp) {
            if Date().timeIntervalSince(latestReadingTimestamp) > twoHoursInSeconds {
                self.readingsHistoryData.errorMessage = "Station has not updated in the past 2 hours"
                print("Station has not updated in the past 2 hours")
                return
            }
        } else {
            self.readingsHistoryData.errorMessage = "Could not parse timestamp: \(latestEntry.timestamp)"
            print("Failed to parse timestamp")
            return
        }
        let recentEntries = Array(readingsHistoryDataArray.suffix(8))
        updateRMPHAReadingHistory(with: recentEntries)
    }

    
    private func updateCUASAReadingsHistory(with readingsHistoryDataArray: [CUASAReadingsData]) {
        var times = [String]()
        var windSpeed = [Double]()
        var windGust = [Double?]()
        var windDirection = [Double]()
        for data in readingsHistoryDataArray {
            let date = Date(timeIntervalSince1970: data.timestamp)
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "H:mm"
            times.append(dateFormatter.string(from: date))
            windSpeed.append(convertKMToMiles(data.windspeed_avg))
            windGust.append(convertKMToMiles(data.windspeed_max))
            windDirection.append(data.wind_direction_avg)
        }
        self.readingsHistoryData = ReadingsHistoryData(
            times: times,
            windSpeed: windSpeed,
            windGust: windGust,
            windDirection: windDirection,
            errorMessage: nil
        )
    }
    
    private func updateRMPHAReadingHistory(with readingsHistoryDataArray: [RMHPAReadingData]) {
        var times = [String]()
        var windSpeed = [Double]()
        var windGust = [Double?]()
        var windDirection = [Double]()
        for data in readingsHistoryDataArray {
            
            // Get time from data in format: "2025-07-31T05:45:00.000"
            var formattedTime = ""
            let inputFormatter = DateFormatter()
            inputFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"
            inputFormatter.timeZone = TimeZone(secondsFromGMT: 0) // 'Z' means UTC
            let outputFormatter = DateFormatter()
            outputFormatter.dateFormat = "h:mm"
            if let date = inputFormatter.date(from: data.timestamp) {
                formattedTime = outputFormatter.string(from: date)
            }
            
            // Append data for each history reading
            times.append(formattedTime)
            windSpeed.append(data.wind_speed ?? 0.0)
            windGust.append(data.wind_gust)
            windDirection.append(data.wind_direction ?? 0.0)
        }
        self.readingsHistoryData = ReadingsHistoryData(
            times: times,
            windSpeed: windSpeed,
            windGust: windGust,
            windDirection: windDirection,
            errorMessage: nil
        )
    }

}
