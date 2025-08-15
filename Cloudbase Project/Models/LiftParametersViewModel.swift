import SwiftUI
import Combine

// Can access throughout the app as:
//  LiftParametersViewModel.shared.getLiftParameters {
//      print("Loaded!")
//  }
//
//  let color = LiftParametersViewModel.shared.colorFor(parameter: "thermalLapseRate", value: 5.0)

struct LiftParameterSource: Codable, Identifiable {
    var id = UUID()
    var parameter: String
    var value: Double
    var notes: String
}

struct LiftParametersResponse: Codable {
    var values: [[String]]
}

struct LiftParameters: Codable {
    var thermalLapseRate: Double
    var thermalVelocityConstant: Double
    var initialTriggerTempDiff: Double
    var ongoingTriggerTempDiff: Double
    var thermalRampDistance: Double
    var thermalRampStartPct: Double
    var cloudbaseLapseRatesDiff: Double
    var thermalGliderSinkRate: Double
}

struct ColorMappingRow {
    var minValue: Double
    var maxValue: Double
    var colorName: String
}

class LiftParametersViewModel: ObservableObject {
    static let shared = LiftParametersViewModel()
    
    @Published var liftParameters: LiftParameters?
    @Published var colorMappings: [String: [ColorMappingRow]] = [:]
    
    private init() {} // singleton
    
    @MainActor
    func getLiftParameters() async {
        let rangeName = "LiftParameters"
        let urlString = "https://sheets.googleapis.com/v4/spreadsheets/\(globalGoogleSheetID)/values/\(rangeName)?alt=json&key=\(googleAPIKey)"
        guard let url = URL(string: urlString) else {
            print("Invalid URL for lift parameters")
            self.liftParameters = nil
            return
        }

        do {
            let response: LiftParametersResponse = try await AppNetwork.shared.fetchJSONAsync(url: url, type: LiftParametersResponse.self)

            var liftParams = LiftParameters(
                thermalLapseRate: 0,
                thermalVelocityConstant: 0,
                initialTriggerTempDiff: 0,
                ongoingTriggerTempDiff: 0,
                thermalRampDistance: 0,
                thermalRampStartPct: 0,
                cloudbaseLapseRatesDiff: 0,
                thermalGliderSinkRate: 0
            )

            var newColorMappings: [String: [ColorMappingRow]] = [:]

            for row in response.values.dropFirst() {
                guard !row.isEmpty else { continue }
                let parameter = row[0].trimmingCharacters(in: .whitespacesAndNewlines)
                let thirdColumnHasValue: Bool = {
                    if row.count > 2 {
                        let val = row[2].trimmingCharacters(in: .whitespacesAndNewlines)
                        return !val.isEmpty
                    }
                    return false
                }()

                if !thirdColumnHasValue {
                    // Single value processing
                    if row.count > 1,
                       let value = Double(row[1].trimmingCharacters(in: .whitespacesAndNewlines)) {
                        switch parameter {
                        case "thermalLapseRate": liftParams.thermalLapseRate = value
                        case "thermalVelocityConstant": liftParams.thermalVelocityConstant = value
                        case "initialTriggerTempDiff": liftParams.initialTriggerTempDiff = value
                        case "ongoingTriggerTempDiff": liftParams.ongoingTriggerTempDiff = value
                        case "thermalRampDistance": liftParams.thermalRampDistance = value
                        case "thermalRampStartPct": liftParams.thermalRampStartPct = value
                        case "cloudbaseLapseRatesDiff": liftParams.cloudbaseLapseRatesDiff = value
                        case "thermalGliderSinkRate": liftParams.thermalGliderSinkRate = value
                        default: break
                        }
                    }
                } else {
                    // Range color processing
                    guard row.count > 3,
                          let minVal = Double(row[1].trimmingCharacters(in: .whitespacesAndNewlines)),
                          let maxVal = Double(row[2].trimmingCharacters(in: .whitespacesAndNewlines)) else {
                        print("Invalid range row: \(row)")
                        continue
                    }
                    let colorName = row[3].trimmingCharacters(in: .whitespacesAndNewlines)
                    var arr = newColorMappings[parameter] ?? []
                    arr.append(ColorMappingRow(minValue: minVal, maxValue: maxVal, colorName: colorName))
                    arr.sort { $0.minValue < $1.minValue }
                    newColorMappings[parameter] = arr
                }
            }

            // Update published properties once at the end
            self.liftParameters = liftParams
            self.colorMappings = newColorMappings

        } catch {
            print("Failed to fetch lift parameters: \(error)")
            self.liftParameters = nil
            self.colorMappings = [:]
        }
    }
}

extension LiftParametersViewModel {
    func colorFor(parameter: String, value: Double?) -> Color {
        guard let value = value,
              let mappings = colorMappings[parameter] else {
            return .clear
        }
        
        if let match = mappings.first(where: { value >= $0.minValue && value <= $0.maxValue }) {
            return colorFromName(match.colorName)
        }
        
        return .clear
    }
    
    private func colorFromName(_ name: String) -> Color {
        switch name {
        case "displayValueBlue": return displayValueBlue
        case "displayValueTeal": return displayValueTeal
        case "displayValueGreen": return displayValueGreen
        case "displayValueYellow": return displayValueYellow
        case "displayValueOrange": return displayValueOrange
        case "displayValueRed": return displayValueRed
        case "displayValueLime": return displayValueLime
        case "displayValueWhite": return displayValueWhite
        default: return .clear
        }
    }
}
