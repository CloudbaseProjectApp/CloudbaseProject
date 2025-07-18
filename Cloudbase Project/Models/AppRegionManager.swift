import Foundation

// Make app region functions available globally (without injecting view model each time)
// To call, use this format:
//      AppRegionManager.shared.getRegionCountry(appRegion: appRegion)

final class AppRegionManager {
    static let shared = AppRegionManager()
    
    private init() {}
    
    private(set) var appRegions: [AppRegion] = []

    func setAppRegions(_ regions: [AppRegion]) {
        self.appRegions = regions
    }

    func getRegionName(appRegion: String) -> String? {
        appRegions.first(where: { $0.appRegion == appRegion })?.appRegionName
    }

    func getRegionGoogleSheet(appRegion: String) -> String? {
        appRegions.first(where: { $0.appRegion == appRegion })?.appRegionGoogleSheetID
    }

    func getRegionCountry(appRegion: String) -> String? {
        appRegions.first(where: { $0.appRegion == appRegion })?.appCountry
    }

    func getRegionEncodedTimezone(appRegion: String) -> String? {
        guard let timezone = appRegions.first(where: { $0.appRegion == appRegion })?.timezone else { return nil }
        var allowed = CharacterSet.urlQueryAllowed
        allowed.remove(charactersIn: "/")
        return timezone.addingPercentEncoding(withAllowedCharacters: allowed)
    }

    func getRegionForecastMapURL(appRegion: String) -> String? {
        appRegions.first(where: { $0.appRegion == appRegion })?.forecastMapURL
    }

    func getRegionWeatherAlertsLink(appRegion: String) -> String? {
        appRegions.first(where: { $0.appRegion == appRegion })?.weatherAlertsLink
    }
    
    func getRegionAreaForecastDiscussionURL(appRegion: String) -> String? {
        appRegions.first(where: { $0.appRegion == appRegion })?.areaForecastDiscussionURL
    }
    
    func getRegionSoaringForecastURL(appRegion: String) -> String? {
        appRegions.first(where: { $0.appRegion == appRegion })?.soaringForecastURL
    }

    func getRegionWindsAloftURL(appRegion: String) -> String? {
        appRegions.first(where: { $0.appRegion == appRegion })?.windsAloftForecastURL
    }

    func getRegionWindsAloftCode(appRegion: String) -> String? {
        appRegions.first(where: { $0.appRegion == appRegion })?.windsAloftCode
    }
    
    func getRegionLatestModelSoundingURL(appRegion: String) -> String? {
        guard let region = appRegions.first(where: { $0.appRegion == appRegion }) else { return nil }
        let code = region.latestModelSoundingCode
        let templateURL = region.latestModelSoundingURL
        // Replace the placeholder (assumed to be "{code}" or just "code") with the actual code
        let finalURL = templateURL
                          .replacingOccurrences(of: "{code}", with: code)
                          .replacingOccurrences(of: "code", with: code)
        return finalURL
    }
    
    func getRegionLatestModelSoundingCode(appRegion: String) -> String? {
        appRegions.first(where: { $0.appRegion == appRegion })?.latestModelSoundingCode
    }

    func getRegionSunriseCoordinates(appRegion: String) -> (latitude: Double, longitude: Double)? {
        guard let region = appRegions.first(where: { $0.appRegion == appRegion }) else { return nil }
        return (region.sunriseLatitude, region.sunriseLongitude)
    }

    func getRegionMapDefaults(appRegion: String) -> (mapInitLatitude: Double,
                                                     mapInitLongitude: Double,
                                                     mapInitLatitudeSpan: Double,
                                                     mapInitLongitudeSpan: Double,
                                                     mapDefaultZoomLevel: Double)? {
        guard let region = appRegions.first(where: { $0.appRegion == appRegion }) else { return nil }
        return (region.mapInitLatitude,
                region.mapInitLongitude,
                region.mapInitLatitudeSpan,
                region.mapInitLongitudeSpan,
                region.mapDefaultZoomLevel)
    }
}
