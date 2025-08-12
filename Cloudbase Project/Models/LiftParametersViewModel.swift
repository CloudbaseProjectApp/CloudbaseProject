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
    static let shared = LiftParametersViewModel() // <-- singleton instance
    
    @Published var liftParameters: LiftParameters?
    @Published var colorMappings: [String: [ColorMappingRow]] = [:]
    
    private init() {} // <-- prevent creating new instances from outside
    
    func getLiftParameters(completion: @escaping () -> Void) {
        var liftParameters = LiftParameters(
            thermalLapseRate: 0,
            thermalVelocityConstant: 0,
            initialTriggerTempDiff: 0,
            ongoingTriggerTempDiff: 0,
            thermalRampDistance: 0,
            thermalRampStartPct: 0,
            cloudbaseLapseRatesDiff: 0,
            thermalGliderSinkRate: 0
        )
        
        let rangeName = "LiftParameters"
        let urlString = "https://sheets.googleapis.com/v4/spreadsheets/\(globalGoogleSheetID)/values/\(rangeName)?alt=json&key=\(googleAPIKey)"
        
        guard let url = URL(string: urlString) else {
            print("Invalid URL for lift parameters")
            completion()
            return
        }
        
        URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            guard let data = data else {
                DispatchQueue.main.async { completion() }
                return
            }
            
            let decoder = JSONDecoder()
            if let decodedResponse = try? decoder.decode(LiftParametersResponse.self, from: data) {
                DispatchQueue.main.async {
                    for row in decodedResponse.values.dropFirst() {
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
                                case "thermalLapseRate":
                                    liftParameters.thermalLapseRate = value
                                case "thermalVelocityConstant":
                                    liftParameters.thermalVelocityConstant = value
                                case "initialTriggerTempDiff":
                                    liftParameters.initialTriggerTempDiff = value
                                case "ongoingTriggerTempDiff":
                                    liftParameters.ongoingTriggerTempDiff = value
                                case "thermalRampDistance":
                                    liftParameters.thermalRampDistance = value
                                case "thermalRampStartPct":
                                    liftParameters.thermalRampStartPct = value
                                case "cloudbaseLapseRatesDiff":
                                    liftParameters.cloudbaseLapseRatesDiff = value
                                case "thermalGliderSinkRate":
                                    liftParameters.thermalGliderSinkRate = value
                                default:
                                    break
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
                            var arr = self?.colorMappings[parameter] ?? []
                            arr.append(ColorMappingRow(minValue: minVal, maxValue: maxVal, colorName: colorName))
                            arr.sort { $0.minValue < $1.minValue } // ensure ascending order
                            self?.colorMappings[parameter] = arr
                        }
                    }
                    
                    self?.liftParameters = liftParameters
                    completion()
                }
            } else {
                DispatchQueue.main.async { completion() }
            }
        }.resume()
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

