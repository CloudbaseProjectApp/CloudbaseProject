import Foundation

// appRegion functions are available globally (without injecting view model each time)
// To call these functions, use this format:
//      AppRegionCodesManager.shared.getRegionCountry()

final class AppRegionCodesManager {
    static let shared = AppRegionCodesManager()
    
    private init() {}
    
    private(set) var appRegionCodes: [AppRegionCode] = []
    
    func setAppRegionCodes(_ regionCodes: [AppRegionCode]) {
        self.appRegionCodes = regionCodes
    }
    
    func getWeatherAlertCodes() -> [(name: String, code: String)] {
        return appRegionCodes
            .filter { code in
                code.appRegion == RegionManager.shared.activeAppRegion && !code.weatherAlerts.trimmingCharacters(in: .whitespaces).isEmpty
            }
            .map { code in
                let resultCode = code.weatherAlerts == "Yes" ? code.airportCode : code.weatherAlerts
                return (name: code.name, code: resultCode)
            }
    }

    
    func getAFDCodes() -> [(name: String, code: String)] {
        return appRegionCodes
            .filter { code in
                code.appRegion == RegionManager.shared.activeAppRegion && !code.AFD.trimmingCharacters(in: .whitespaces).isEmpty
            }
            .map { code in
                let resultCode = code.AFD == "Yes" ? code.airportCode : code.AFD
                return (name: code.name, code: resultCode)
            }
    }

    func getSoaringForecastCodes() -> [(name: String, forecastType: String, code: String)] {
        let richCodes = appRegionCodes
            .filter { code in
                code.appRegion == RegionManager.shared.activeAppRegion && !code.soaringForecastRichSimple.trimmingCharacters(in: .whitespaces).isEmpty
            }
            .map { code in
                let resultCode = code.soaringForecastRichSimple == "Yes" ? code.airportCode : code.soaringForecastRichSimple
                return (name: code.name, forecastType: "rich", code: resultCode)
            }
        let basicCodes = appRegionCodes
            .filter { code in
                code.appRegion == RegionManager.shared.activeAppRegion && !code.soaringForecastBasic.trimmingCharacters(in: .whitespaces).isEmpty
            }
            .map { code in
                let resultCode = code.soaringForecastBasic == "Yes" ? code.airportCode : code.soaringForecastBasic
                return (name: code.name, forecastType: "basic", code: resultCode)
            }
        return richCodes + basicCodes
    }
    
    func getWindsAloftCodes() -> [(name: String, code: String)] {
        return appRegionCodes
            .filter { code in
                code.appRegion == RegionManager.shared.activeAppRegion && !code.windsAloft.trimmingCharacters(in: .whitespaces).isEmpty
            }
            .map { code in
                let resultCode = code.windsAloft == "Yes" ? code.airportCode : code.windsAloft
                return (name: code.name, code: resultCode)
            }
    }


}
