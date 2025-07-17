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
