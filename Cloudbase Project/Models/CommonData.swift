import SwiftUI
import Combine
import Foundation
import MapKit

// Set development build flags
let devMenuAvailable: Bool = false
let logThermalCalcs: Bool = false
let printReadingsURL: Bool = false
let printForecastURL: Bool = false
let printPilotTracksTimings: Bool = false
let printPilotTrackURLs: Bool = false

// Get API keys and tokens from .xcconfig file (need to be mapped in .plist)
let googleAPIKey = Bundle.main.object(forInfoDictionaryKey: "GoogleSheetsAPIKey") as? String ?? ""
let synopticsAPIToken = "&token=\(Bundle.main.object(forInfoDictionaryKey: "SynopticsAPIToken") as? String ?? "")"
let UDOTCamerasAPIKey = Bundle.main.object(forInfoDictionaryKey: "UDOTCamerasAPIKey") as? String ?? ""

// Cloudbase Project link info
let cloudbaseProjectEmail: String = "CloudbaseProjectApp@gmail.com"
let cloudbaseProjectGitLink: String = "https://github.com/CloudbaseProjectApp/CloudbaseProject"
let cloudbaseProjectGitIssueLink: String = "https://github.com/CloudbaseProjectApp/CloudbaseProject/issues/new"
let cloudbaseProjectTelegramLink: String = "https://t.me/+bSHu5KTsRkU1M2Mx"

// HTTP links and APIs
let globalGoogleSheetID =       "18EU5k34_nhOa7Qv_SA5oMeEWpD00pWDHiAC0Nh7vUho"
let weatherAlertsAPI: String =  "https://api.weather.gov/alerts/active?area=" // Append state code to end
let uDOTCamerasAPI: String = "https://www.udottraffic.utah.gov/api/v2/get/cameras?key=\(UDOTCamerasAPIKey)&format=json"
let uDOTCamerasLink: String = "https://www.udottraffic.utah.gov"
let ipCamLink: String = "https://apps.apple.com/us/app/ip-camera-viewer-ipcams/id1045600272"
let UHGPGAcamsLink: String = "https://www.uhgpga.org/webcams"
let rainviewerAPI: String = "https://api.rainviewer.com/public/weather-maps.json"

// Build APIs for Mesowest weather readings
// latestReadings API is header + parameters (stations; can be blank) + trailer + token
let latestReadingsAPIHeader = "https://api.mesowest.net/v2/station/latest?"
let latestReadingsAPITrailer =  "&recent=420&vars=air_temp,altimeter,wind_direction,wind_gust,wind_speed&units=english,speed|mph,temp|F&within=120&obtimezone=local&timeformat=%-I:%M%20%p"
// historyReadings API is header + parameters (station) + trailer + token
let historyReadingsAPIHeader = "https://api.mesowest.net/v2/station/timeseries?"
let historyReadingsAPITrailer = "&recent=420&vars=air_temp,wind_direction,wind_gust,wind_speed&units=english,speed|mph,temp|F&within=120&obtimezone=local&timeformat=%-I:%M %p"

// Page navigation values
enum NavBarSelectedView: Int {
    case site = 0
    case weather = 1
    case map = 2
    case webcam = 3
    case link = 4
}

// App parameters
let skewTButtonWidth: CGFloat = 100
let defaultTopOfLiftAltitude = 18000.0                  // Use in lift area graph when top of lift isn't reached in calculations
let readingsRefreshInterval: TimeInterval = 120         // Time in seconds to refresh wind readings (300 for 5 min)
let pilotTrackRefreshInterval: TimeInterval = 600      // Setting refresh to 10 min to prevent timeout errors on frequent refreshes

// Map parameters
let mapDefaultLatitude: Double = 39.72                  // Should not be displayed; will update based on region selected
let mapDefaultLongitude: Double = -111.45               // Should not be displayed; will update based on region selected
let mapDefaultLatitudeSpan: Double = 7.2                // Should not be displayed; will update based on region selected
let mapDefaultLongitudeSpan: Double = 5.2               // Should not be displayed; will update based on region selected
let mapDefaultZoomLevel: Double = 6.7                   // Should not be displayed; will update based on region selected
let mapBatchProcessingInterval: Double = 0.2
let mapScaleChangeTolerance: Double = 0.01              // Don't refresh annotation filtering for minor scale changes
let mapEnableRotate: Bool = false
let mapEnablePitch: Bool = false

// Map annotation parameters
let mapShowAllMarkersZoomLevel: Double = 10.0
let mapPilotArrowDefaultSize: Double = 15
let mapPilotAnnotationZoomScaleFactor: Double = 0.9     // Drives sizing of pilot node annotation based on zoom level
let mapPilotTrackWidth: CGFloat = 2
let stationSpacingBaseThreshold: Double = 0.01          // Larger number will reduce the number of stations displayed
let stationSpacingZoomFactor: Double = 700              // Larger number will reduce number of stations displayed
let annotationDuplicateTolerance = 0.0001
let mapClusterThresholdFactor = 0.1                     // Initial value was 0.1
let annotationTextWidth: CGFloat = 60
let annotationTextHeight: CGFloat = 4
let stationAnnotationWidth: CGFloat = 40
let stationAnnotationHeight: CGFloat = 22
let defaultAnnotationImageWidth: CGFloat = 50
let pilotNodeAnnotationImageWidth: CGFloat = 20
let pilotLaunchAnnotationImageWidth: CGFloat = 40
let pilotLatestAnnotationImageWidth: CGFloat = 40
let pilotNodeAnnotationTextWidth: CGFloat = 56
let pilotNodeAnnotationTextOneRowHeight: CGFloat = 16
let pilotNodeAnnotationTextThreeRowHeight: CGFloat = pilotNodeAnnotationTextOneRowHeight * 3
let pilotNodeLabelThreeRowSpan: CGFloat = 0.2           // Map scale that determines when to display time/altitude for each node

// Map default settings
let defaultPilotTrackDays: Double = 1.0                 // Default days of live tracking to display
let defaultmapDisplayMode: MapDisplayMode = .weather
let defaultmapType: CustomMapStyle = .standard
let defaultShowSites: Bool = false
let defaultShowStations: Bool = true
let defaultShowRadar: Bool = true
let defaultShowInfrared: Bool = true
let defaultRadarColorScheme: Int = 3
    /* Rainviewer radar color scheme options are:
    0        BW Black and White: dBZ values
    1        Original (green -> blue)  for increasing precip)
    2        Universal Blue (blue -> yellow -> red for increasing precip)  **
    3        TITAN (green -> blue -> purple -> magenta -> orange -> yellow for increasing precip)  **
    4        The Weather Channel (TWC) (green -> yellow for increasing precip) *
    5        Meteored (blue -> green -> yellow for increasing precip) *
    6        NEXRAD Level III (blue -> green -> yellow -> red for increasing precip) *
    7        Rainbow @ SELEX-IS (green -> yellow -> red for increasing precip)  **
    8        Dark Sky ((deep blue -> red -> yellow for increasing precip)  **
    */

// Grid structure sizing parameters
let headingHeight: CGFloat = 16               // Day, date, time rows
let imageHeight: CGFloat = 38                 // Weather skies image
let dataHeight: CGFloat = 22
let labelHeight: CGFloat = 22                 // Wind, Lift label rows
let doubleHeight: CGFloat = dataHeight * 2    // Surface wind + gust combined
var areaChartHeight: CGFloat = 0              // ToL area chart height calculated below
let areaChartPaddingHeight: CGFloat = 0       // Adjustment to reflect spacing between table rows
let imageScalingFactor: CGFloat = 0.5         // Weather skies image
let windArrowSpacing: CGFloat = 3             // Space between wind speed and direction arrow
let dateChangeDividerSize: CGFloat = 1
let areaChartOpacity: CGFloat = 0.5
