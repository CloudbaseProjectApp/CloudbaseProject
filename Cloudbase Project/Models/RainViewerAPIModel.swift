import SwiftUI
import MapKit
import Foundation

// RainViewer Overlay Model
struct RainViewerTileOverlay: Decodable, Identifiable {
    let id = UUID() // Generated locally, not from JSON
    let path: String
    let time: Int
    
    private enum CodingKeys: String, CodingKey {
        case path
        case time
    }
}

// RainViewer API Response
struct RainViewerAPIResponse: Decodable {
    let radar: Radar
    let satellite: Satellite
    
    struct Radar: Decodable {
        let past: [RainViewerTileOverlay]
        let nowcast: [RainViewerTileOverlay]
    }
    struct Satellite: Decodable {
        let infrared: [RainViewerTileOverlay]
    }
}

// Provider
final class RainViewerOverlayProvider {
    static let shared = RainViewerOverlayProvider()
    private init() {}
    
    private let baseURL = "https://tilecache.rainviewer.com"
    
    func fetchLatestOverlay(infrared: Bool = false) async throws -> MKTileOverlay? {
        
        // Get the API URL
        guard let apiURL = URL(string: AppURLManager.shared.getAppURL(URLName: "rainviewerAPI")!) else {
            print("Error: rainviewerAPI URL not found in AppURLManager")
            return nil
        }

        let response: RainViewerAPIResponse = try await AppNetwork.shared.fetchJSONAsync(
            url: apiURL,
            type: RainViewerAPIResponse.self
        )
        
        let overlayData: RainViewerTileOverlay?
        if infrared {
            overlayData = response.satellite.infrared.last
        } else {
            overlayData = response.radar.past.last // safest complete radar frame
        }
        
        guard let data = overlayData else {
            print("[RainViewer] No \(infrared ? "infrared" : "radar") frames available.")
            return nil
        }
        
        var cacheURLString: String
        if infrared {
            guard let baseURL = AppURLManager.shared.getAppURL(URLName: "rainviewerInfraredTileAPI") else {
                print("Error: rainviewerInfraredTileAPI URL not found in AppURLManager")
                return nil
            }
            cacheURLString = updateURL(url: baseURL, parameter: "datapath", value: data.path)
        } else {
            guard let baseURL = AppURLManager.shared.getAppURL(URLName: "rainviewerRadarTileAPI") else {
                print("Error: rainviewerRadarTileAPI URL not found in AppURLManager")
                return nil
            }
            cacheURLString = updateURL(url: baseURL, parameter: "datapath", value: data.path)
        }
        guard URL(string: cacheURLString) != nil else {
            print("Error: Invalid rainviewer cache URL after adding parameters; URL: \(cacheURLString), datapath: \(data.path)")
            return nil
        }
        
        let overlay = MKTileOverlay(urlTemplate: cacheURLString)
        overlay.canReplaceMapContent = false
        overlay.minimumZ = 0
        overlay.maximumZ = 12
        overlay.tileSize = CGSize(width: 256, height: 256)
        return overlay
    }
}

// ViewModel
@MainActor
final class RainViewerOverlayViewModel: ObservableObject {
    @Published var radarOverlay: MKTileOverlay?
    @Published var infraredOverlay: MKTileOverlay?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    func loadAllOverlays(showRadar: Bool, showInfrared: Bool) {
        Task {
            isLoading = true
            errorMessage = nil
            do {
                
                async let infraredTask: MKTileOverlay? = showInfrared
                    ? RainViewerOverlayProvider.shared.fetchLatestOverlay(infrared: true) : nil
                
                async let radarTask: MKTileOverlay? = showRadar
                    ? RainViewerOverlayProvider.shared.fetchLatestOverlay(infrared: false) : nil
                
                let (newRadar, newInfrared) = try await (radarTask, infraredTask)
                
                if let newInfrared = newInfrared {
                    if infraredOverlay?.urlTemplate != newInfrared.urlTemplate {
                        infraredOverlay = newInfrared
                    }
                }
                
                if let newRadar = newRadar {
                    if radarOverlay?.urlTemplate != newRadar.urlTemplate {
                        radarOverlay = newRadar
                    }
                }
                
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }
}
