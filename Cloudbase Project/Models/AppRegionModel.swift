import SwiftUI

let globalGoogleSheetID = "18EU5k34_nhOa7Qv_SA5oMeEWpD00pWDHiAC0Nh7vUho"

struct AppRegion {
    let appRegion: String                   // Two digit code for U.S. states (used in Synoptics station map call)
                                            // Code assumes appRegion is unique (without appCountry); so do not use US states for other regions
    let appCountry: String                  // Two or three digit country code (US, CA, MX, etc.) (used in Synoptics station map call)
    let appRegionName: String
    let appRegionGoogleSheetID: String
    let sunriseLatitude: Double
    let sunriseLongitude: Double
    let mapInitLatitude: Double             // Center point for map on initial opening
    let mapInitLongitude: Double
    let mapInitLatitudeSpan: Double         // Size of map on initial opening
    let mapInitLongitudeSpan: Double        // mapInitLatitudeSpan * 1.5
    let mapDefaultZoomLevel: Double
    let forecastMapURL: String
}

let appRegions: [AppRegion] = [
    
    AppRegion(appRegion:                    "UT",
              appCountry:                   "US",
              appRegionName:                "Utah",
              appRegionGoogleSheetID:       "1_dZ1-_vHgt43uoLBkUCY_KJWSP1d4lbI8JqOlKmAdtA",
              sunriseLatitude:              40.7862,     // SLC airport coordinates
              sunriseLongitude:             -111.9801,
              mapInitLatitude:              39.72,
              mapInitLongitude:             -111.45,
              mapInitLatitudeSpan:          7.2,
              mapInitLongitudeSpan:         5.2,
              mapDefaultZoomLevel:          6.7,
              forecastMapURL:               forecastUSMapLink
             ),
    
    AppRegion(appRegion:                    "MT",
              appCountry:                   "US",
              appRegionName:                "Montana",
              appRegionGoogleSheetID:       "17SZ6IpTbLOg9iSVLZv2CjLwvX1fiYunn2639_hYJYEI",
              sunriseLatitude:              46.919896,     // Missoula airport coordinates
              sunriseLongitude:             -114.08078,
              mapInitLatitude:              46.9199,
              mapInitLongitude:             -114.081,
              mapInitLatitudeSpan:          7.2,
              mapInitLongitudeSpan:         5.2,
              mapDefaultZoomLevel:          6.7,
              forecastMapURL:               forecastUSMapLink
             ),
    
    AppRegion(appRegion:                    "CO",
              appCountry:                   "US",
              appRegionName:                "Colorado",
              appRegionGoogleSheetID:       "13Ujy7Iupkm2gEZSkdOUEUHi32BfbsMqlNvByZt482TE",
              sunriseLatitude:              39.856414,     // Denver airport coordinates
              sunriseLongitude:             -104.679227,
              mapInitLatitude:              39.856,
              mapInitLongitude:             -104.679,
              mapInitLatitudeSpan:          7.2,
              mapInitLongitudeSpan:         5.2,
              mapDefaultZoomLevel:          6.7,
              forecastMapURL:               forecastUSMapLink
             ),
    
    AppRegion(appRegion:                    "NewZealand",
              appCountry:                   "US",
              appRegionName:                "New Zealand",
              appRegionGoogleSheetID:       "1633Vd2M2Kaila3EhsoWnZTPX1WLVoWJdGa9gYxtgSug",
              sunriseLatitude:              -41.327222,     // Wellington airport coordinates
              sunriseLongitude:             174.807554,
              mapInitLatitude:              -41.327,
              mapInitLongitude:             174.808,
              mapInitLatitudeSpan:          7.2,
              mapInitLongitudeSpan:         5.2,
              mapDefaultZoomLevel:          6.7,
              forecastMapURL:               ""
             )
    
]

func getRegionName(appRegion: String) -> String? {
    return appRegions.first(where: { $0.appRegion == appRegion })?.appRegionName
}

func getRegionGoogleSheet(appRegion: String) -> String? {
    return appRegions.first(where: { $0.appRegion == appRegion })?.appRegionGoogleSheetID
}

func getRegionCountry(appRegion: String) -> String? {
    return appRegions.first(where: { $0.appRegion == appRegion })?.appCountry
}

func getRegionForecastMapURL(appRegion: String) -> String? {
    return appRegions.first(where: { $0.appRegion == appRegion })?.forecastMapURL
}

func getRegionSunriseCoordinates(appRegion: String) -> (latitude: Double,
                                                        longitude: Double)? {
    guard let region = appRegions.first(where: { $0.appRegion == appRegion }) else {
        return nil
    }
    return (latitude:   region.sunriseLatitude,
            longitude:  region.sunriseLongitude)
}

func getRegionMapDefaults(appRegion: String) -> (mapInitLatitude: Double,
                                                 mapInitLongitude: Double,
                                                 mapInitLatitudeSpan: Double,
                                                 mapInitLongitudeSpan: Double,
                                                 mapDefaultZoomLevel: Double)? {
    guard let region = appRegions.first(where: { $0.appRegion == appRegion }) else {
        return nil
    }
    return (mapInitLatitude:        region.mapInitLatitude,
            mapInitLongitude:       region.mapInitLongitude,
            mapInitLatitudeSpan:    region.mapInitLatitudeSpan,
            mapInitLongitudeSpan:   region.mapInitLongitudeSpan,
            mapDefaultZoomLevel:    region.mapDefaultZoomLevel)
}
