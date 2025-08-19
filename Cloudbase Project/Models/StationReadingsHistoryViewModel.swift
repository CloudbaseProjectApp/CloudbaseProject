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
    let wind_direction_set_1: [Double?]?
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
 
    func GetReadingsHistoryData(stationID: String, readingsSource: String) async {
        do {
            switch readingsSource {
            case "Mesonet":
                let readingsLink = AppURLManager.shared.getAppURL(URLName: "mesonetHistoryReadingsAPI")
                    ?? "<Unknown Mesonet readings history API URL>"
                let updatedReadingsLink = updateURL(url: readingsLink, parameter: "station", value: stationID) + synopticsAPIToken
                
                guard let url = URL(string: updatedReadingsLink) else {
                    await MainActor.run {
                        self.readingsHistoryData.errorMessage = "Invalid Mesonet readings URL"
                    }
                    return
                }
                
                let request = URLRequest(url: url)
                let data = try await AppNetwork.shared.fetchDataAsync(request: request)
                let decoded = try JSONDecoder().decode(ReadingsData.self, from: data)
                
                guard let station = decoded.STATION.first else {
                    await MainActor.run {
                        self.readingsHistoryData.errorMessage = "No valid data found for station: \(stationID)"
                    }
                    return
                }
                
                let recentTimes = Array(station.OBSERVATIONS.date_time.suffix(8))
                let recentWindSpeed = Array(station.OBSERVATIONS.wind_speed_set_1.suffix(8)).map { $0 ?? 0.0 }
                let recentWindGust = station.OBSERVATIONS.wind_gust_set_1?.suffix(8).map { $0 ?? 0.0 }
                    ?? Array(repeating: nil, count: 8)
                let recentWindDirection = Array((station.OBSERVATIONS.wind_direction_set_1 ?? Array(repeating: nil, count: 8))
                    .suffix(8).map { $0 ?? 0.0 })
                
                if let latestTimeString = recentTimes.last,
                   let latestTime = ISO8601DateFormatter().date(from: latestTimeString),
                   Date().timeIntervalSince(latestTime) > 2 * 60 * 60 {
                    await MainActor.run {
                        self.readingsHistoryData.errorMessage = "Station \(stationID) has not updated in the past 2 hours"
                    }
                } else {
                    await MainActor.run {
                        self.readingsHistoryData = ReadingsHistoryData(
                            times: recentTimes,
                            windSpeed: recentWindSpeed,
                            windGust: recentWindGust,
                            windDirection: recentWindDirection,
                            errorMessage: nil
                        )
                    }
                }
                
            case "CUASA":
                let readingInterval: Double = 5 * 60
                let readingEnd = Date().timeIntervalSince1970
                let readingStart = readingEnd - (readingInterval * 10)
                
                let readingsLink = AppURLManager.shared.getAppURL(URLName: "CUASAHistoryReadingsAPI")
                    ?? "<Unknown CUASA readings history API URL>"
                
                var updatedLink = updateURL(url: readingsLink, parameter: "station", value: stationID)
                updatedLink = updateURL(url: updatedLink, parameter: "readingStart", value: String(readingStart))
                updatedLink = updateURL(url: updatedLink, parameter: "readingEnd", value: String(readingEnd))
                updatedLink = updateURL(url: updatedLink, parameter: "readingInterval", value: String(readingInterval))
                
                guard let url = URL(string: updatedLink) else {
                    await MainActor.run {
                        self.readingsHistoryData.errorMessage = "Invalid CUASA readings URL"
                    }
                    return
                }
                
                let request = URLRequest(url: url)
                let data = try await AppNetwork.shared.fetchDataAsync(request: request)
                let decoded = try JSONDecoder().decode([CUASAReadingsData].self, from: data)
                
                await MainActor.run {
                    self.processCUASAReadingsHistoryData(decoded)
                }
                
            case "RMHPA":
                let readingsLink = AppURLManager.shared.getAppURL(URLName: "RMHPAHistoryReadingsAPI")
                    ?? "<Unknown RMHPA readings history API URL>"
                let updatedLink = updateURL(url: readingsLink, parameter: "station", value: stationID)
                
                guard let url = URL(string: updatedLink) else {
                    await MainActor.run {
                        self.readingsHistoryData.errorMessage = "Invalid RMHPA readings URL"
                    }
                    return
                }
                
                var request = URLRequest(url: url)
                request.httpMethod = "GET"
                request.setValue(RMHPAAPIKey, forHTTPHeaderField: "x-api-key")
                request.setValue("application/json", forHTTPHeaderField: "Accept")
                
                let data = try await AppNetwork.shared.fetchDataAsync(request: request)
                let decoded = try JSONDecoder().decode(RMHPAAPIResponse.self, from: data)
                
                await MainActor.run {
                    self.processRMHPAReadingHistoryData(decoded.data)
                }
                
            default:
                print("Invalid readings source for station: \(stationID)")
            }
        } catch {
            await MainActor.run {
                self.readingsHistoryData.errorMessage = "Error: \(error.localizedDescription)"
            }
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
        updateRMHPAReadingHistory(with: recentEntries)
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
    
    private func updateRMHPAReadingHistory(with readingsHistoryDataArray: [RMHPAReadingData]) {
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
            windGust.append(data.wind_gust ?? 0.0)
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
