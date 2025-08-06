import SwiftUI
import Combine

// "Basic" Soaring Forecast and Sounding for locations that do not use summer/winter soaring forecasts

struct SoaringForecastBasic: Identifiable {
    let id = UUID()
    let date: String
    let soaringForecastFormat: String
    let basicSoaringForecastData: [BasicSoaringForecastData]
    let basicLiftData: [BasicLiftData]
    let basicSoundingData: [BasicSoundingData]
    let forecastMaxTemp: Int
}

struct BasicSoaringForecastData: Identifiable {
    let id = UUID()
    let heading: String
    let value: String?
}
    
struct BasicLiftData: Identifiable {
    let id = UUID()
    let altitude: String
    let thermalIndex: Double
    let tempOfConvection: Int       // Fahrenheit
    let liftRate: Double            // Converted to m/s
}
    
struct BasicSoundingData: Identifiable {
    let id = UUID()
    let altitude: String
    let amWindDirection: Int
    let amWindSpeed: Int            // converted to mph
    let pmWindDirection: Int
    let pmWindSpeed: Int            // converted to mph
}
    
struct BasicModelData: Identifiable {
    let id = UUID()
    let value: String
}

class SoaringForecastBasicViewModel: ObservableObject {
    @Published var soaringForecastBasic: SoaringForecastBasic?
    @Published var isLoading = false
    
    // Instance Tracking code
    private let vmtype = "SoaringForecastViewModel (Basic)"
    private let instanceID = UUID()
    init() { print("✅ \(vmtype) \(instanceID) initialized") }
    deinit { print("🗑️ \(vmtype) \(instanceID) deinitialized") }
    
    func fetchSoaringForecast(airportCode: String) {
        isLoading = true
        
        // Get base URL, update parameters, and format into URL format
        guard let baseURL = AppURLManager.shared.getAppURL(URLName: "soaringForecastBasic") else {
            print("Could not find basic soaring forecast URL for appRegion: \(RegionManager.shared.activeAppRegion)")
            isLoading = false
            return
        }
        let updatedURL = updateURL(url: baseURL, parameter: "airportcode", value: airportCode)
        
        // Format URL
        guard let URL = URL(string: updatedURL) else {
            print("Invalid basic soaring forecast URL for appRegion: \(RegionManager.shared.activeAppRegion)")
            isLoading = false
            return
        }

        // Process URL query
        URLSession.shared.dataTask(with: URL) { [weak self] data, response, error in
            guard let self = self else { return }
            guard let data = data, error == nil else {
                DispatchQueue.main.async { self.isLoading = false }
                return
            }
            if let content = String(data: data, encoding: .utf8) {
                self.parseBasicSoaringForecast(content: content)
            }
        }.resume()
    }
    
    
    func parseModelData(_ input: String) -> [ModelData] {
        let lines = input.split(separator: "\n")
        var dataRows: [ModelData] = []
        for line in lines {
            dataRows.append(ModelData(value: String(line)))
        }
        return dataRows
    }
    
    // Winter soaring forecast with limited data
    func parseBasicSoaringForecast(content: String) {
        let start = "SOARING FORECAST FOR "
        let datePrefix = "DATE..."
        let liftPrefix = "HEIGHT      |   TI   | TOC  |  POTENTIAL LIFT"
        let soaringPrefix = "HEIGHT OF THE "
        let soaringSuffix = "UPPER LEVEL WINDS"
        let soundingPrefix = "Morning  ####  Afternoon"
        let endPrefix = "IT IS EMPHASIZED"
        
        guard let startRange = content.range(of: start)
        else {
            print("Basic soaring forecast: could not parse start date (e.g., no row for \(start))")
            DispatchQueue.main.async { self.isLoading = false }
            return
        }
        guard let dateRange = content.range(of: datePrefix, range: startRange.upperBound..<content.endIndex)
        else {
            print("Basic soaring forecast: could not parse date range (e.g., no row for \(datePrefix))")
            DispatchQueue.main.async { self.isLoading = false }
            return
        }
        guard let liftRange = content.range(of: liftPrefix, range: dateRange.upperBound..<content.endIndex)
        else {
            print("Basic soaring forecast: could not parse lift range (e.g., no row for \(liftPrefix))")
            DispatchQueue.main.async { self.isLoading = false }
            return
        }
        guard let soaringRange = content.range(of: soaringPrefix, range: liftRange.upperBound..<content.endIndex)
        else {
            print("Basic soaring forecast: could not parse soaring forecast range (e.g., no row for \(soaringPrefix))")
            DispatchQueue.main.async { self.isLoading = false }
            return
        }
        guard let soaringRangeEnd = content.range(of: soaringSuffix, range: soaringRange.upperBound..<content.endIndex)
        else {
            print("Basic soaring forecast: could not parse soaring forecast range (e.g., no row for \(soaringPrefix))")
            DispatchQueue.main.async { self.isLoading = false }
            return
        }
        guard let soundingRange = content.range(of: soundingPrefix, range: soaringRange.upperBound..<content.endIndex)
        else {
            print("Basic soaring forecast: could not parse sounding data range (e.g., no row for \(soundingPrefix))")
            DispatchQueue.main.async { self.isLoading = false }
            return
        }
        guard let endRange = content.range(of: endPrefix, range: soundingRange.upperBound..<content.endIndex)
        else {
            print("Basic soaring forecast: Could not parse end range (e.g., no row for \(endPrefix))")
            DispatchQueue.main.async { self.isLoading = false }
            return
        }
        
        let date = String(content[dateRange.upperBound...].prefix(9)).trimmingCharacters(in: .whitespacesAndNewlines)
        
        let liftDataString = removeExtraBlankLines(String(content[liftRange.upperBound..<soaringRange.lowerBound]))
        let liftData = parseBasicLiftData(liftDataString)
        
        let soaringDataString = removeExtraBlankLines(String(content[soaringRange.upperBound..<soaringRangeEnd.lowerBound]))
        let soaringForecast = parseBasicSoaringForecastData(soaringDataString)
        
        let soundingDataString = removeExtraBlankLines(String(content[soundingRange.upperBound..<endRange.lowerBound]))
        let soundingData = parseBasicSoundingData(soundingDataString)
        
        // Find forecast max temp to use in skew-T diagarm
        var forecastMaxTemp: Int = 0
        let pattern = "MAX TEMPERATURE FORECAST\\s+\\.+\\d+\\DEGREES F)"
        let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive)
        let nsString = soaringDataString as NSString
        let results = regex?.matches(in: soaringDataString, options: [], range: NSRange(location: 0, length: nsString.length))
        if let match = results?.first, let range = Range(match.range(at: 1), in: soaringDataString) {
            forecastMaxTemp = Int(soaringDataString[range]) ?? 0
        }
        
        DispatchQueue.main.async {
            self.isLoading = false
            self.soaringForecastBasic = SoaringForecastBasic(date:                      date,
                                                             soaringForecastFormat:     "Basic",
                                                             basicSoaringForecastData:  soaringForecast,
                                                             basicLiftData:             liftData.reversed(),
                                                             basicSoundingData:         soundingData.reversed(),
                                                             forecastMaxTemp:           forecastMaxTemp)
        }
    }
    
    func parseBasicLiftData(_ input: String) -> [BasicLiftData] {
        let formattedInput = input
            .replacingOccurrences(of: "FT ASL", with: "")
            .replacingOccurrences(of: " ", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let lines = formattedInput.split(separator: "\n")
        var basicLiftData: [BasicLiftData] = []
        for line in lines { // Header rows parsed out above; otherwise use .dropFirst()
            let columns = line.split(separator: "|", omittingEmptySubsequences: true)
            if columns.count >= 4 {
                let altitude = String(columns[0])
                let thermalIndex = Double(extractNumber(from: String(columns[1])) ?? 0.0)
                let tempOfConvection = Int(extractNumber(from: String(columns[2])) ?? 0)
                let liftRate = Int(extractNumber(from: String(columns[3])) ?? 0)
                let liftRateMSec = convertFtMinToMSec(Double(liftRate))
                let dataRow = BasicLiftData(
                    altitude:           altitude,
                    thermalIndex:       thermalIndex,
                    tempOfConvection:   tempOfConvection,
                    liftRate:           liftRateMSec
                )
                basicLiftData.append(dataRow)
                    
            }
        }
        return basicLiftData
    }
    
    func parseBasicSoaringForecastData(_ input: String) -> [BasicSoaringForecastData] {
        var formattedInput = input
            .replacingOccurrences(of: "TEMPERATURE", with: "TEMP")
            .replacingOccurrences(of: "ASL", with: "")
            .replacingOccurrences(of: "DEGREES ", with: "°")
            .replacingOccurrences(of: "GREAT BASIN SOARING INDEX", with: "")
            .replacingOccurrences(of: "(", with: "")
            .replacingOccurrences(of: ")", with: "")
        
        // Convert max lift to m/s
        let pattern = #"(\d+)\sFT/MIN"#
        let regex = try! NSRegularExpression(pattern: pattern)
        let input = formattedInput

        if let match = regex.firstMatch(in: input, range: NSRange(input.startIndex..., in: input)),
           let numberRange = Range(match.range(at: 1), in: input),
           let fullRange = Range(match.range, in: input) {

            let numberStr = String(input[numberRange])
            if let ftMin = Double(numberStr) {
                let mSec = convertFtMinToMSec(ftMin)
                formattedInput = input.replacingCharacters(in: fullRange, with: String(format: "%.2f m/s", mSec))
            }
        }
        
        formattedInput = formatNumbersInString(formattedInput)
            .capitalized
            .replacingOccurrences(of: "M/S", with: "m/s")
            .replacingOccurrences(of: "Ft", with: "ft")
        let lines = formattedInput.split(separator: "\n")
        var dataRows: [BasicSoaringForecastData] = []
        for line in lines {
            let components = line.split(separator: ".", omittingEmptySubsequences: true)
            if components.count > 1 {
                let heading = components[0].trimmingCharacters(in: .whitespacesAndNewlines)
                let value = components.dropFirst().joined(separator: ".").trimmingCharacters(in: .whitespacesAndNewlines)
                dataRows.append(BasicSoaringForecastData(heading: heading, value: value))
            } else {
                let heading = line.trimmingCharacters(in: .whitespacesAndNewlines)
                dataRows.append(BasicSoaringForecastData(heading: heading, value: nil))
            }
        }
        return dataRows
    }

    func parseBasicSoundingData(_ input: String) -> [BasicSoundingData] {
        let lines = input.split(separator: "\n")
        var basicSoundingData: [BasicSoundingData] = []
        for line in lines { // Header rows parsed out above; otherwise use .dropFirst(3)
            let columns = line.split(separator: " ", omittingEmptySubsequences: true)
            if columns.count >= 5, let altitude = Int(columns[0]), altitude <= 18000 {
                let amWindDirection = Int(columns[1]) ?? 0
                let amWindSpeedKt = Int(columns[2]) ?? 0
                // Ignore column 3; it contains #### as a separator
                let pmWindDirection = Int(columns[4]) ?? 0
                let pmWindSpeedKt = Int(columns[5]) ?? 0
                
                let amWindSpeed = convertKnotsToMPH(amWindSpeedKt)
                let pmWindSpeed = convertKnotsToMPH(pmWindSpeedKt)

                let dataRow = BasicSoundingData(altitude:           String(altitude),
                                                amWindDirection:    amWindDirection,
                                                amWindSpeed:        amWindSpeed,
                                                pmWindDirection:    pmWindDirection,
                                                pmWindSpeed:        pmWindSpeed)
                basicSoundingData.append(dataRow)
            }
        }
        return basicSoundingData
    }

}
