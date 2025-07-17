import SwiftUI
import Combine

// Winds Aloft forecast
class WindAloftData: ObservableObject {
    @Published var readings: [WindAloftReading] = []
    @Published var cycle: String = ""
    struct WindAloftReading {
        let altitude: Int
        let windDirection: Int
        let windSpeed: Int
        let temperature: Int
    }
    func fetchWindAloftData(appRegion: String) {
        let cycle = determineCycle()
        self.cycle = cycle
        let urlString = AppRegionManager.shared.getRegionWindsAloftURL(appRegion: appRegion) ?? ""
        guard let url = URL(string: urlString) else { return }
        
        let code = AppRegionManager.shared.getRegionWindsAloftCode(appRegion: appRegion) ?? ""

        URLSession.shared.dataTask(with: url) { data, response, error in
            guard let data = data, error == nil else { return }
            if let responseString = String(data: data, encoding: .utf8) {
                self.parseWindAloftData(code: code,
                                        data: responseString)
            }
        }.resume()
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
    
    private func parseWindAloftData(code: String, data: String) {
        let lines = data.split(separator: "\n")
        guard let regionLine = lines.first(where: { $0.starts(with: code) }) else { return }

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

        var newReadings: [WindAloftReading] = []

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
            self.readings = newReadings.reversed()
        }
    }
    
    private func parseReading(_ reading: String, altitude: Int) -> WindAloftReading? {
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
            return WindAloftReading(altitude: altitude, windDirection: windDirection, windSpeed: windSpeed, temperature: tempFahrenheit)
        } else {
            return WindAloftReading(altitude: altitude, windDirection: windDirection, windSpeed: windSpeed, temperature: 0)
        }
    }
}
