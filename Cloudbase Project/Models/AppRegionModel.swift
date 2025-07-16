import SwiftUI

// OLD *********
let googleSpreadsheetID = "1s72R3YCHxNIJVLVa5nmsTphRpqRsfG2QR2koWxE19ls"

let globalGoogleSheetID = "18EU5k34_nhOa7Qv_SA5oMeEWpD00pWDHiAC0Nh7vUho"

struct AppRegion {
    let appRegion: String                   // Two digit code for U.S. states (used in Synoptics station map call)
                                            // Code assumes appRegion is unique (without appCountry); so do not use US states for other regions
    let appCountry: String                  // Two or three digit country code (US, CA, MX, etc.) (used in Synoptics station map call)
    let appRegionName: String
    let appRegionGoogleSheetID: String
    let appRegionSunriseLatitude: Double
    let appRegionSunriseLongitude: Double
}

let appRegions: [AppRegion] = [
    
    AppRegion(appRegion:                    "UT",
              appCountry:                   "US",
              appRegionName:                "Utah",
              appRegionGoogleSheetID:       "1_dZ1-_vHgt43uoLBkUCY_KJWSP1d4lbI8JqOlKmAdtA",
              appRegionSunriseLatitude:     40.7862,     // SLC airport coordinates
              appRegionSunriseLongitude:    -111.9801

             ),
    
    AppRegion(appRegion:                    "MT",
              appCountry:                   "US",
              appRegionName:                "Montana",
              appRegionGoogleSheetID:       "17SZ6IpTbLOg9iSVLZv2CjLwvX1fiYunn2639_hYJYEI",
              appRegionSunriseLatitude:     46.919896,     // Missoula airport coordinates
              appRegionSunriseLongitude:    -114.08078
             ),
    
    AppRegion(appRegion:                    "CO",
              appCountry:                   "US",
              appRegionName:                "Colorado",
              appRegionGoogleSheetID:       "13Ujy7Iupkm2gEZSkdOUEUHi32BfbsMqlNvByZt482TE",
              appRegionSunriseLatitude:     39.856414,     // Denver airport coordinates
              appRegionSunriseLongitude:    -104.679227
             ),
    
    AppRegion(appRegion:                    "NewZealand",
              appCountry:                   "US",
              appRegionName:                "New Zealand",
              appRegionGoogleSheetID:       "1633Vd2M2Kaila3EhsoWnZTPX1WLVoWJdGa9gYxtgSug",
              appRegionSunriseLatitude:     -41.327222,     // Wellington airport coordinates
              appRegionSunriseLongitude:    174.807554
             )
    
]

func getRegionGoogleSheet(appRegion: String) -> String? {
    return appRegions.first(where: { $0.appRegion == appRegion })?.appRegionGoogleSheetID
}

func getRegionCountry(appRegion: String) -> String? {
    return appRegions.first(where: { $0.appRegion == appRegion })?.appCountry
}

func getRegionSunriseCoordinates(appRegion: String) -> (latitude: Double, longitude: Double)? {
    guard let region = appRegions.first(where: { $0.appRegion == appRegion }) else {
        return nil
    }
    return (latitude: region.appRegionSunriseLatitude, longitude: region.appRegionSunriseLongitude)
}
