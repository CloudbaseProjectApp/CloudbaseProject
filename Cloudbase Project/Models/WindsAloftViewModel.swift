import SwiftUI
import Combine

struct WindsAloftReading {
    let altitude: Int
    let windDirection: Int
    let windSpeed: Int
    let temperature: Int
}

// Winds Aloft forecast
class WindsAloftViewModel: ObservableObject {
    @Published var readings: [WindsAloftReading] = []
    @Published var cycle: String = ""
    @Published var isLoading = false
        
    func getWindsAloftData(airportCode: String) {
        isLoading = true
print("Getting winds aloft data")
        // Get base URL, update parameters, and format into URL format
        guard let baseURL = AppURLManager.shared.getAppURL(URLName: "windsAloftURL")
        else {
            print("Could not find winds aloft URL for appRegion: \(RegionManager.shared.activeAppRegion)")
            isLoading = false
            return
        }
        var updatedURL = updateURL(url: baseURL, parameter: "airportcode", value: airportCode)
        updatedURL = updateURL(url: updatedURL, parameter: "cycle", value: determineCycle())
        
        // Format URL
        guard let URL = URL(string: updatedURL)
        else {
            print("Invalid winds aloft URL for appRegion: \(RegionManager.shared.activeAppRegion)")
            isLoading = false
            return
        }
print("winds aloft url: \(URL)")
        
        // Set headers to prevent server-side cache resulting in no data found
        var request = URLRequest(url: URL)
        request.httpMethod = "GET"
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("no-cache, no-store, must-revalidate", forHTTPHeaderField: "Cache-Control")
        request.setValue("0", forHTTPHeaderField: "Pragma")
        request.setValue("\(Date().timeIntervalSince1970)", forHTTPHeaderField: "X-Bypass-Cache-Key")

        // Process URL query
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let httpResponse = response as? HTTPURLResponse {
                print("X-Cache header:", httpResponse.value(forHTTPHeaderField: "X-Cache") ?? "none")
            }
            guard let data = data, error == nil else {
                print("URL response error for: \(RegionManager.shared.activeAppRegion); error: \(error ?? NSError())")
                DispatchQueue.main.async { self.isLoading = false }
                return
            }
            if let responseString = String(data: data, encoding: .utf8) {
                self.parseWindsAloftData(code: airportCode,
                                        data: responseString)
            }
        }
        task.resume()
    }
    
    private func determineCycle() -> String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 3...13:
            return "12"
        case 14...18:
            return "06"
        default:
            return "24"
        }
    }
    
    private func parseWindsAloftData(code: String, data: String) {
print("parsing for code: \(code) using data: \(data)")
        let lines = data.split(separator: "\n")
        guard let regionLine = lines.first(where: { $0.starts(with: code) }) else {
            print("Could not find a matching row for code: \(code)")
            DispatchQueue.main.async { self.isLoading = false }
            return
        }

        // Fixed-width column offsets (based on space-separated but fixed-length layout)
        // PHX[0–2]      - Station code
        // <space>[3]
        // 3000[4–7]     - Skip
        // <space>[8]
        // 6000[9–15]    - needed
        // <space>[16]
        // 9000[17–23]   - needed
        // <space>[24]
        // 12000[25–31]  - needed
        // <space>[32]
        // 18000[33–39]  - needed
        // <space>[40]
        // Additional levels can be ignored

        let offsets: [(altitude: Int, range: Range<Int>)] = [
            (6000, 9..<16),
            (9000, 17..<24),
            (12000, 25..<32),
            (18000, 33..<40)
        ]

        var newReadings: [WindsAloftReading] = []

        for (altitude, range) in offsets {
            if range.upperBound <= regionLine.count {
                let start = regionLine.index(regionLine.startIndex, offsetBy: range.lowerBound)
                let end = regionLine.index(regionLine.startIndex, offsetBy: range.upperBound)
                let substring = regionLine[start..<end].trimmingCharacters(in: .whitespaces)

                if !substring.isEmpty, let parsedReading = parseReading(substring, altitude: altitude) {
                    newReadings.append(parsedReading)
                }
            }
        }

        DispatchQueue.main.async {
            self.isLoading = false
            self.readings = newReadings.reversed()
        }
    }
    
    private func parseReading(_ reading: String, altitude: Int) -> WindsAloftReading? {
        guard reading.count >= 4 else { return nil }
        var windDirection = 10 * (Int(reading.prefix(2)) ?? 0)
        var windSpeedKnots = Int(reading.dropFirst(2).prefix(2)) ?? 0
        // Check for wind greater than 100 knots, which is indicated by adding 500 degrees to the wind direction
        // (anything greater than 199 knots is indicated as 199 knots)
        // Ignore 990, which indicated light and variable winds
        if windDirection > 360 && windDirection < 990 {
            windDirection = windDirection - 360
            windSpeedKnots = windSpeedKnots + 100
        }
        let windSpeed = convertKnotsToMPH(windSpeedKnots)
        // Convert wind direction to arrow direction (offset by 180 degrees)
        windDirection = (windDirection + 180) % 360
        var temperature: Int? = nil
        if reading.count > 4 {
            let tempString = reading.dropFirst(4)
            if let tempValue = Int(tempString) {
                temperature = Int(tempValue)
            }
        }
        if let tempCelsius = temperature {
            let tempFahrenheit = convertCelsiusToFahrenheit(Int(tempCelsius))
            return WindsAloftReading(altitude: altitude, windDirection: windDirection, windSpeed: windSpeed, temperature: tempFahrenheit)
        } else {
            return WindsAloftReading(altitude: altitude, windDirection: windDirection, windSpeed: windSpeed, temperature: 0)
        }
    }
}
