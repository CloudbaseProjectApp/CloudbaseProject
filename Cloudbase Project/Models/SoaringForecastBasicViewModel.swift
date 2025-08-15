import SwiftUI
import Combine

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
    let amWindSpeed: Int            // mph
    let pmWindDirection: Int
    let pmWindSpeed: Int            // mph
}

struct BasicModelData: Identifiable {
    let id = UUID()
    let value: String
}

@MainActor
class SoaringForecastBasicViewModel: ObservableObject {
    @Published var soaringForecastBasic: SoaringForecastBasic?
    @Published var isLoading = false
    
    private let vmtype = "SoaringForecastViewModel (Basic)"
    private let instanceID = UUID()
    private let network = AppNetwork.shared
    
    init() { print("✅ \(vmtype) \(instanceID) initialized") }
    deinit { print("🗑️ \(vmtype) \(instanceID) deinitialized") }
    
    func fetchSoaringForecast(airportCode: String) {
        Task {
            isLoading = true
            
            guard let baseURL = AppURLManager.shared.getAppURL(URLName: "soaringForecastBasic") else {
                print("Could not find basic soaring forecast URL for appRegion: \(RegionManager.shared.activeAppRegion)")
                isLoading = false
                return
            }
            
            let updatedURL = updateURL(url: baseURL, parameter: "airportcode", value: airportCode)
            guard let url = URL(string: updatedURL) else {
                print("Invalid basic soaring forecast URL for appRegion: \(RegionManager.shared.activeAppRegion)")
                isLoading = false
                return
            }
            
            do {
                let data: Data = try await AppNetwork.shared.fetchDataAsync(url: url)
                guard let content = String(data: data, encoding: .utf8) else {
                    print("Failed to decode soaring forecast as UTF-8 string")
                    isLoading = false
                    return
                }
                parseBasicSoaringForecast(content: content)
            } catch {
                print("Basic soaring forecast fetch failed: \(error)")
            }
            
            isLoading = false
        }
    }
    
    // Parsing
    func parseModelData(_ input: String) -> [BasicModelData] {
        input
            .split(separator: "\n")
            .map { BasicModelData(value: String($0)) }
    }
    
    func parseBasicSoaringForecast(content: String) {
        let start = "SOARING FORECAST FOR "
        let datePrefix = "DATE..."
        let liftPrefix = "HEIGHT      |   TI   | TOC  |  POTENTIAL LIFT"
        let soaringPrefix = "HEIGHT OF THE "
        let soaringSuffix = "UPPER LEVEL WINDS"
        let soundingPrefix = "Morning  ####  Afternoon"
        let endPrefix = "IT IS EMPHASIZED"
        
        guard let startRange = content.range(of: start),
              let dateRange = content.range(of: datePrefix, range: startRange.upperBound..<content.endIndex),
              let liftRange = content.range(of: liftPrefix, range: dateRange.upperBound..<content.endIndex),
              let soaringRange = content.range(of: soaringPrefix, range: liftRange.upperBound..<content.endIndex),
              let soaringRangeEnd = content.range(of: soaringSuffix, range: soaringRange.upperBound..<content.endIndex),
              let soundingRange = content.range(of: soundingPrefix, range: soaringRange.upperBound..<content.endIndex),
              let endRange = content.range(of: endPrefix, range: soundingRange.upperBound..<content.endIndex)
        else {
            print("Basic soaring forecast: could not parse required sections")
            isLoading = false
            return
        }
        
        let date = String(content[dateRange.upperBound...].prefix(9)).trimmingCharacters(in: .whitespacesAndNewlines)
        
        let liftDataString = removeExtraBlankLines(String(content[liftRange.upperBound..<soaringRange.lowerBound]))
        let liftData = parseBasicLiftData(liftDataString)
        
        let soaringDataString = removeExtraBlankLines(String(content[soaringRange.upperBound..<soaringRangeEnd.lowerBound]))
        let soaringForecast = parseBasicSoaringForecastData(soaringDataString)
        
        let soundingDataString = removeExtraBlankLines(String(content[soundingRange.upperBound..<endRange.lowerBound]))
        let soundingData = parseBasicSoundingData(soundingDataString)
        
        // Find forecast max temp
        var forecastMaxTemp: Int = 0
        let pattern = #"MAX TEMPERATURE FORECAST\s+\.*(\d+)DEGREES F"#
        if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
           let match = regex.firstMatch(in: soaringDataString, range: NSRange(location: 0, length: soaringDataString.utf16.count)),
           let range = Range(match.range(at: 1), in: soaringDataString) {
            forecastMaxTemp = Int(soaringDataString[range]) ?? 0
        }
        
        soaringForecastBasic = SoaringForecastBasic(
            date: date,
            soaringForecastFormat: "Basic",
            basicSoaringForecastData: soaringForecast,
            basicLiftData: liftData.reversed(),
            basicSoundingData: soundingData.reversed(),
            forecastMaxTemp: forecastMaxTemp
        )
        
        isLoading = false
    }
    
    func parseBasicLiftData(_ input: String) -> [BasicLiftData] {
        let formattedInput = input
            .replacingOccurrences(of: "FT ASL", with: "")
            .replacingOccurrences(of: " ", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        return formattedInput
            .split(separator: "\n")
            .compactMap { line -> BasicLiftData? in
                let columns = line.split(separator: "|", omittingEmptySubsequences: true)
                guard columns.count >= 4 else { return nil }
                
                let altitude = String(columns[0])
                let thermalIndex = Double(extractNumber(from: String(columns[1])) ?? 0.0)
                let tempOfConvection = Int(extractNumber(from: String(columns[2])) ?? 0)
                let liftRate = Int(extractNumber(from: String(columns[3])) ?? 0)
                let liftRateMSec = convertFtMinToMSec(Double(liftRate))
                
                return BasicLiftData(
                    altitude: altitude,
                    thermalIndex: thermalIndex,
                    tempOfConvection: tempOfConvection,
                    liftRate: liftRateMSec
                )
            }
    }
    
    func parseBasicSoaringForecastData(_ input: String) -> [BasicSoaringForecastData] {
        var formattedInput = input
            .replacingOccurrences(of: "TEMPERATURE", with: "TEMP")
            .replacingOccurrences(of: "ASL", with: "")
            .replacingOccurrences(of: "DEGREES ", with: "°")
            .replacingOccurrences(of: "GREAT BASIN SOARING INDEX", with: "")
            .replacingOccurrences(of: "(", with: "")
            .replacingOccurrences(of: ")", with: "")
        
        let pattern = #"(\d+)\sFT/MIN"#
        if let regex = try? NSRegularExpression(pattern: pattern),
           let match = regex.firstMatch(in: formattedInput, range: NSRange(formattedInput.startIndex..., in: formattedInput)),
           let numberRange = Range(match.range(at: 1), in: formattedInput),
           let fullRange = Range(match.range, in: formattedInput),
           let ftMin = Double(formattedInput[numberRange]) {
            let mSec = convertFtMinToMSec(ftMin)
            formattedInput.replaceSubrange(fullRange, with: String(format: "%.2f m/s", mSec))
        }
        
        formattedInput = formatNumbersInString(formattedInput)
            .capitalized
            .replacingOccurrences(of: "M/S", with: "m/s")
            .replacingOccurrences(of: "Ft", with: "ft")
        
        return formattedInput
            .split(separator: "\n")
            .map { line -> BasicSoaringForecastData in
                let components = line.split(separator: ".", omittingEmptySubsequences: true)
                if components.count > 1 {
                    let heading = components[0].trimmingCharacters(in: .whitespacesAndNewlines)
                    let value = components.dropFirst().joined(separator: ".").trimmingCharacters(in: .whitespacesAndNewlines)
                    return BasicSoaringForecastData(heading: heading, value: value)
                } else {
                    return BasicSoaringForecastData(heading: line.trimmingCharacters(in: .whitespacesAndNewlines), value: nil)
                }
            }
    }
    
    func parseBasicSoundingData(_ input: String) -> [BasicSoundingData] {
        input
            .split(separator: "\n")
            .compactMap { line -> BasicSoundingData? in
                let columns = line.split(separator: " ", omittingEmptySubsequences: true)
                guard columns.count >= 6,
                      let altitude = Int(columns[0]),
                      altitude <= 18000 else { return nil }
                
                let amWindDirection = Int(columns[1]) ?? 0
                let amWindSpeedKt = Int(columns[2]) ?? 0
                let pmWindDirection = Int(columns[4]) ?? 0
                let pmWindSpeedKt = Int(columns[5]) ?? 0
                
                return BasicSoundingData(
                    altitude: String(altitude),
                    amWindDirection: amWindDirection,
                    amWindSpeed: convertKnotsToMPH(amWindSpeedKt),
                    pmWindDirection: pmWindDirection,
                    pmWindSpeed: convertKnotsToMPH(pmWindSpeedKt)
                )
            }
    }
}
