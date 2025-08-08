import SwiftUI
import Combine

struct WindsAloftReading {
    let altitude: Int
    let windDirection: Int?
    let windSpeed: Int?
    let temperature: Int?
}

// Winds Aloft forecast
class WindsAloftViewModel: ObservableObject {
    @Published var readings: [WindsAloftReading] = []
    @Published var cycle: String = ""
    @Published var isLoading = false
    
    func getWindsAloftData(airportCode: String) {
        isLoading = true

        // Get base URL, update parameters, and format into URL format
        guard let baseURL = AppURLManager.shared.getAppURL(URLName: "windsAloftURL")
        else {
            print("Could not find winds aloft URL for appRegion: \(RegionManager.shared.activeAppRegion)")
            isLoading = false
            return
        }
        let cycle = windsAloftCycle()
        self.cycle = cycle
        let updatedURL = updateURL(url: baseURL, parameter: "cycle", value: cycle)
        
        // Format URL
        guard let URL = URL(string: updatedURL)
        else {
            print("Invalid winds aloft URL for appRegion: \(RegionManager.shared.activeAppRegion)")
            isLoading = false
            return
        }
        
        // Process URL query
        let task = URLSession.shared.dataTask(with: URL) { data, response, error in
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
    
    private func parseWindsAloftData(code: String, data: String) {
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

        // Parse wind direction
        let windDirSource = reading.prefix(2)
        var windDirection: Int? = (windDirSource == "  ") ? nil : 10 * (Int(windDirSource) ?? 0)

        // Parse wind speed
        let windSpeedSource = reading.dropFirst(2).prefix(2)
        var windSpeedKnots: Int? = (windSpeedSource == "  ") ? nil : (Int(windSpeedSource) ?? 0)
        
        // Check for wind greater than 100 knots, which is indicated by adding 500 degrees to the wind direction
        // (anything greater than 199 knots is indicated as 199 knots)
        // Ignore 990, which indicated light and variable winds
        if let direction = windDirection, direction > 360 && direction < 990 {
            windDirection = direction - 360
            windSpeedKnots = (windSpeedKnots ?? 0) + 100
        }
        
        // Convert wind speed to mph
        let windSpeed: Int? = (windSpeedSource == "  ") ? nil : convertKnotsToMPH(windSpeedKnots ?? 0)
        
        // Convert wind direction to arrow direction (offset by 180 degrees)
        if let direction = windDirection {
            windDirection = (direction + 180) % 360
        }
        
        // Parse temperature, convert to F, and return results
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
            return WindsAloftReading(altitude: altitude, windDirection: windDirection, windSpeed: windSpeed, temperature: nil)
        }
    }
}
