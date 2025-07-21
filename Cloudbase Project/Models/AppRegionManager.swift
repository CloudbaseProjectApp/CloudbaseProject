import Foundation

// appRegion functions are available globally (without injecting view model each time)
// To call these functions, use this format:
//      AppRegionManager.shared.getRegionCountry()

final class AppRegionManager {
    static let shared = AppRegionManager()
    
    private init() {}
    
    private(set) var appRegions: [AppRegion] = []
    
    func setAppRegions(_ regions: [AppRegion]) {
        self.appRegions = regions
    }
    
    func getRegionName() -> String? {
        appRegions.first(where: { $0.appRegion == RegionManager.shared.activeAppRegion })?.appRegionName
    }
    
    func getRegionGoogleSheet() -> String? {
        appRegions.first(where: { $0.appRegion == RegionManager.shared.activeAppRegion })?.appRegionGoogleSheetID
    }
    
    func getRegionCountry() -> String? {
        appRegions.first(where: { $0.appRegion == RegionManager.shared.activeAppRegion })?.appCountry
    }
    
    func getRegionEncodedTimezone() -> String? {
        guard let timezone = appRegions.first(where: { $0.appRegion == RegionManager.shared.activeAppRegion })?.timezone else { return nil }
        var allowed = CharacterSet.urlQueryAllowed
        allowed.remove(charactersIn: "/")
        return timezone.addingPercentEncoding(withAllowedCharacters: allowed)
    }
    
    func getRegionSunriseCoordinates() -> (latitude: Double, longitude: Double)? {
        guard let region = appRegions.first(where: { $0.appRegion == RegionManager.shared.activeAppRegion }) else { return nil }
        return (region.sunriseLatitude, region.sunriseLongitude)
    }
    
    func getRegionMapDefaults() -> (mapInitLatitude: Double,
                                    mapInitLongitude: Double,
                                    mapInitLatitudeSpan: Double,
                                    mapInitLongitudeSpan: Double,
                                    mapDefaultZoomLevel: Double)? {
        guard let region = appRegions.first(where: { $0.appRegion == RegionManager.shared.activeAppRegion }) else { return nil }
        return (region.mapInitLatitude,
                region.mapInitLongitude,
                region.mapInitLatitudeSpan,
                region.mapInitLongitudeSpan,
                region.mapDefaultZoomLevel)
    }
    
    // TO BE REMOVED *************
    
    func getRegionLatestModelSoundingURL() -> String? {
        guard let region = appRegions.first(where: { $0.appRegion == RegionManager.shared.activeAppRegion }) else { return nil }
        let code = region.latestModelSoundingCode
        let templateURL = region.latestModelSoundingURL
        // Replace the placeholder (assumed to be "{code}" or just "code") with the actual code
        let finalURL = templateURL
            .replacingOccurrences(of: "{code}", with: code)
            .replacingOccurrences(of: "code", with: code)
        return finalURL
    }
    
    func getRegionLatestModelSoundingCode() -> String? {
        appRegions.first(where: { $0.appRegion == RegionManager.shared.activeAppRegion })?.latestModelSoundingCode
    }
    
}
