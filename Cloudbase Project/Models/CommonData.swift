import SwiftUI
import Combine
import Foundation
import MapKit

// Set development build flags
let devMenuAvailable: Bool          = false
let logThermalCalcs: Bool           = false
let printPilotTracksTimings: Bool   = false
let printPilotTrackURLs: Bool       = false
let printURLRequest: Bool           = false
let printURLRawResponse: Bool       = false
let printFunctionCallSource: Bool   = false         /* Need to put logic at top of function being called to see output:
                                                    if printFunctionCallSource { Thread.callStackSymbols.forEach { print($0) } }
                                                    */

// Get API keys and tokens from .xcconfig file (need to be mapped in .plist)
let googleAPIKey        = Bundle.main.object(forInfoDictionaryKey:              "GoogleSheetsAPIKey") as? String ?? ""
let synopticsAPIToken   = "&token=\(Bundle.main.object(forInfoDictionaryKey:    "SynopticsAPIToken" ) as? String ?? "")"
let UDOTCamerasAPIKey   = Bundle.main.object(forInfoDictionaryKey:              "UDOTCamerasAPIKey" ) as? String ?? ""
let RMHPAAPIKey         = Bundle.main.object(forInfoDictionaryKey:              "RMHPAAPIKey"       ) as? String ?? ""

// Cloudbase Project link info
let cloudbaseProjectEmail: String           = "CloudbaseProjectApp@gmail.com"
let cloudbaseProjectGitLink: String         = "https://github.com/CloudbaseProjectApp/CloudbaseProject"
let cloudbaseProjectGitIssueLink: String    = "https://github.com/CloudbaseProjectApp/CloudbaseProject/issues/new"
let cloudbaseProjectTelegramLink: String    = "https://t.me/+bSHu5KTsRkU1M2Mx"

// HTTP links and APIs
let globalGoogleSheetID     = "18EU5k34_nhOa7Qv_SA5oMeEWpD00pWDHiAC0Nh7vUho"
let uDOTCamerasAPI: String  = "https://www.udottraffic.utah.gov/api/v2/get/cameras?key=\(UDOTCamerasAPIKey)&format=json"
let uDOTCamerasLink: String = "https://www.udottraffic.utah.gov"
let ipCamLink: String       = "https://apps.apple.com/us/app/ip-camera-viewer-ipcams/id1045600272"
let UHGPGAcamsLink: String  = "https://www.uhgpga.org/webcams"

// App parameters
let toolbarItemSize: CGFloat                    = 14        // Height and width of toolbar icon frames
let skewTButtonWidth: CGFloat                   = 100
let defaultTopOfLiftAltitude                    = 18000.0   // Use in lift area graph when top of lift isn't reached in calculations
let defaultMaxPressureReading: Int              = 1000      // Pressure to start displaying winds aloft (1000 hpa is sea level)
let readingsRefreshInterval: TimeInterval       = 120       // Time in seconds to refresh wind readings (300 for 5 min)
let pilotTrackRefreshInterval: TimeInterval     = 600       // Setting refresh to 10 min to prevent timeout errors on frequent refreshes
let forecastCacheInterval: TimeInterval         = 1800      // 30 minute refresh interval for each forecast calls
let pilotTrackSegmentThreshold: TimeInterval    = 7200      // 2 hour threshold to create separate pilot live track segments

// Map parameters
let mapDefaultLatitude: Double                  = 39.72     // Should not be displayed; will update based on region selected
let mapDefaultLongitude: Double                 = -111.45   // Should not be displayed; will update based on region selected
let mapDefaultLatitudeSpan: Double              = 7.2       // Should not be displayed; will update based on region selected
let mapDefaultLongitudeSpan: Double             = 5.2       // Should not be displayed; will update based on region selected
let mapDefaultZoomLevel: Double                 = 6.7       // Should not be displayed; will update based on region selected
let mapBatchProcessingInterval: Double          = 0.2
let mapScaleChangeTolerance: Double             = 0.01      // Don't refresh annotation filtering for minor scale changes
let mapEnableRotate: Bool                       = false
let mapEnablePitch: Bool                        = false

// Map annotation parameters
let mapShowAllMarkersZoomLevel: Double          = 10.0
let mapPilotArrowDefaultSize: Double            = 15
let mapPilotAnnotationZoomFactor: Double        = 0.9       // Drives sizing of pilot node annotation based on zoom level
let mapPilotTrackWidth: CGFloat                 = 2
let stationSpacingBaseThreshold: Double         = 0.01      // Larger number will reduce the number of stations displayed
let stationSpacingZoomFactor: Double            = 700       // Larger number will reduce number of stations displayed
let annotationDuplicateTolerance                = 0.0001
let mapClusterThresholdFactor                   = 0.1       // Initial value was 0.1
let annotationTextWidth: CGFloat                = 60
let annotationTextHeight: CGFloat               = 4
let stationAnnotationWidth: CGFloat             = 40
let stationAnnotationHeight: CGFloat            = 22
let defaultAnnotationImageWidth: CGFloat        = 50
let pilotNodeAnnotationImageWidth: CGFloat      = 20
let pilotLaunchAnnotationImageWidth: CGFloat    = 40
let pilotLatestAnnotationImageWidth: CGFloat    = 40
let pilotNodeLabelTextWidth: CGFloat            = 56
let pilotNodeLabelTextOneRowHeight: CGFloat     = 16
let pilotNodeLabelTextThreeRowHeight: CGFloat   = pilotNodeLabelTextOneRowHeight * 3
let pilotNodeLabelThreeRowSpan: CGFloat         = 0.2       // Map scale that determines when to display time/altitude for each node

// Map default settings
let defaultPilotTrackDays: Double               = 1.0       // Default days of live tracking to display
let defaultmapDisplayMode: MapDisplayMode       = .weather
let defaultmapType: CustomMapStyle              = .standard
let defaultShowSites: Bool                      = true
let defaultShowStations: Bool                   = true
let defaultShowRadar: Bool                      = true
let defaultShowInfrared: Bool                   = true

// Grid structure sizing parameters
let headingHeight: CGFloat                      = 16        // Day, date, time rows
let imageHeight: CGFloat                        = 38        // Weather skies image
let dataHeight: CGFloat                         = 22
let labelHeight: CGFloat                        = 22        // Wind, Lift label rows
let doubleHeight: CGFloat                       = dataHeight * 2    // Surface wind + gust combined
var areaChartHeight: CGFloat                    = 0         // ToL area chart height calculated below
let areaChartPaddingHeight: CGFloat             = 0         // Adjustment to reflect spacing between table rows
let imageScalingFactor: CGFloat                 = 0.5       // Weather skies image
let windArrowSpacing: CGFloat                   = 3         // Space between wind speed and direction arrow
let dateChangeDividerSize: CGFloat              = 1
let areaChartOpacity: CGFloat                   = 0.5
