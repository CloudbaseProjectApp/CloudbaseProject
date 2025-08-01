import SwiftUI
import Combine
import MapKit

enum MapDisplayMode: String, Codable {
    case weather
    case tracking
}

// Custom Map Style
enum CustomMapStyle: String, Codable, CaseIterable {
    case standard, hybrid

    // Conversion to Maptype (for MKMapView)
    func toMapType() -> MKMapType {
        switch self {
        case .standard:
            return .standard
        case .hybrid:
            return .hybrid
        }
    }
}

struct UserFavoriteSite: Identifiable, Codable, Equatable {
    var id = UUID()
    let appRegion: String
    let favoriteType: String    // "station" or "site"
    let favoriteID: String      // site name or station name
    var favoriteName: String    // User specified
    let readingsSource: String  // for stations only (used to build mock site for favorites)
    let stationID: String       // for stations only
    let readingsAlt: String     // for stations only
    let siteLat: String         // for stations only
    let siteLon: String         // for stations only
    var sortSequence: Int       // allows user to re-sort favorites
}

struct UserPickListSelection: Identifiable, Codable, Equatable {
    var id = UUID()
    var appRegion: String
    var pickListName: String
    var selectedIndex: Int?
}

class UserSettingsViewModel: ObservableObject {
    @Published var mapRegion: MKCoordinateRegion
    @Published var zoomLevel: Double
    @Published var selectedMapType: CustomMapStyle
    @Published var pilotTrackDays: Double
    @Published var mapDisplayMode: MapDisplayMode
    @Published var showSites: Bool
    @Published var showStations: Bool
    @Published var showRadar: Bool
    @Published var showInfrared: Bool
    @Published var radarColorScheme: Int
    @Published var selectedPilots: [Pilot]
    @Published var userFavoriteSites: [UserFavoriteSite]
    @Published var userPickListSelections: [UserPickListSelection]
    
    init(mapRegion:                 MKCoordinateRegion,
         zoomLevel:                 Double = 6,
         selectedMapType:           CustomMapStyle = defaultmapType,
         pilotTrackDays:            Double = defaultPilotTrackDays,
         mapDisplayMode:            MapDisplayMode = defaultmapDisplayMode,
         showSites:                 Bool = defaultShowSites,
         showStations:              Bool = defaultShowStations,
         showRadar:                 Bool = defaultShowRadar,
         showInfrared:              Bool = defaultShowInfrared,
         radarColorSchme:           Int = defaultRadarColorScheme,
         selectedPilots:            [Pilot] = [],
         userFavoriteSites:         [UserFavoriteSite] = [],
         userPickListSelections:    [UserPickListSelection] = []
    ) {
        self.mapRegion              = mapRegion
        self.zoomLevel              = zoomLevel
        self.selectedMapType        = selectedMapType
        self.pilotTrackDays         = pilotTrackDays
        self.mapDisplayMode         = mapDisplayMode
        self.showSites              = showSites
        self.showStations           = showStations
        self.showRadar              = showRadar
        self.showInfrared           = showInfrared
        self.radarColorScheme       = radarColorSchme
        self.selectedPilots         = selectedPilots
        self.userFavoriteSites      = userFavoriteSites
        self.userPickListSelections = userPickListSelections
    }
    
    var isMapWeatherMode:           Bool { mapDisplayMode == .weather }
    var isMapTrackingMode:          Bool { mapDisplayMode == .tracking }
    var isMapDisplayingSites:       Bool { mapDisplayMode == .weather && showSites }
    var isMapDisplayingStations:    Bool { mapDisplayMode == .weather && showStations }
    var isMapDisplayingRadar:       Bool { mapDisplayMode == .weather && showRadar }
    var isMapDisplayingInfrared:    Bool { mapDisplayMode == .weather && showInfrared }
    
    // Persistent storage
    private let storageKey = "UserSettings"
    private struct PersistedSettings: Codable {
        let centerLatitude:         Double
        let centerLongitude:        Double
        let spanLatitude:           Double
        let spanLongitude:          Double
        let zoomLevel:              Double
        let selectedMapType:        CustomMapStyle.RawValue
        let pilotTrackDays:         Double
        let mapDisplayMode:         MapDisplayMode.RawValue
        let showSites:              Bool
        let showStations:           Bool
        let showRadar:              Bool
        let showInfrared:           Bool
        let radarColorScheme:       Int
        let selectedPilots:         [Pilot]
        let userFavoriteSites:      [UserFavoriteSite]
        let userPickListSelections: [UserPickListSelection]
    }
    
    // Functions to manage favorites
    enum FavoriteSiteError: Error, LocalizedError {
        case alreadyExists
        case notFound
        
        var errorDescription: String? {
            switch self {
            case .alreadyExists: return "Favorite already exists."
            case .notFound: return "Favorite not found."
            }
        }
    }
    
    func addFavorite(
        favoriteType: String,
        favoriteID: String,
        favoriteName: String,
        readingsSource: String,
        stationID: String,
        readingsAlt: String,
        siteLat: String,
        siteLon: String
    ) throws {
        // Check for duplicates
        if userFavoriteSites.contains(where: {
            $0.favoriteType == favoriteType && $0.favoriteID == favoriteID
        }) {
            throw FavoriteSiteError.alreadyExists
        }
        
        // Compute the next sortSequence
        let nextSequence = (userFavoriteSites.map { $0.sortSequence }.max() ?? 0) + 1
        
        // Build and append the new favorite
        let newFavorite = UserFavoriteSite(
            appRegion:      RegionManager.shared.activeAppRegion,
            favoriteType:   favoriteType,
            favoriteID:     favoriteID,
            favoriteName:   favoriteName,
            readingsSource: readingsSource,
            stationID:      stationID,
            readingsAlt:    readingsAlt,
            siteLat:        siteLat,
            siteLon:        siteLon,
            sortSequence:   nextSequence
        )
        userFavoriteSites.append(newFavorite)
    }
    
    func removeFavorite(favoriteType: String, favoriteID: String) throws {
        guard let index = userFavoriteSites.firstIndex(where: {
            $0.favoriteType == favoriteType && $0.favoriteID == favoriteID
        }) else {
            throw FavoriteSiteError.notFound
        }
        
        userFavoriteSites.remove(at: index)
    }
    
    func updatePickListSelection(pickListName: String, selectedIndex: Int) {
        let currentRegion = RegionManager.shared.activeAppRegion

        if let index = userPickListSelections.firstIndex(where: {
            $0.appRegion == currentRegion && $0.pickListName == pickListName
        }) {
            // Update existing selection
            userPickListSelections[index].selectedIndex = selectedIndex
        } else {
            // Create and append a new selection
            let newSelection = UserPickListSelection(
                appRegion: currentRegion,
                pickListName: pickListName,
                selectedIndex: selectedIndex
            )
            userPickListSelections.append(newSelection)
        }
    }
    
    func getPickListSelection(pickListName: String) -> Int {
        let currentRegion = RegionManager.shared.activeAppRegion
        if let selection = userPickListSelections.first(where: {
            $0.appRegion == currentRegion && $0.pickListName == pickListName
        }), let index = selection.selectedIndex {
            return index
        }
        return 0
    }
}

// Composite structure to check for all map settings and view changes together
// and only rebuild annotations once if there are multiple changes
struct MapSettingsState: Equatable {
    let pilotTrackDays: Double
    let mapDisplayMode: MapDisplayMode
    let showSites: Bool
    let showStations: Bool
    let showRadar: Bool
    let showInfrared: Bool
    let radarColorScheme: Int
    let scenePhase: ScenePhase
    let selectedPilots: [Pilot]
}

// Functions to handle persistent storage
extension UserSettingsViewModel {
    
    // Call this once on launch
    func loadFromStorage() {
        let defaults = UserDefaults.standard
        guard
            let data = defaults.data(forKey: storageKey),
            let stored = try? JSONDecoder().decode(PersistedSettings.self, from: data)
        else {
            return
        }
        
        // Apply loaded values back into @Published properties
        mapRegion = MKCoordinateRegion(
            center: CLLocationCoordinate2D(
                latitude: stored.centerLatitude,
                longitude: stored.centerLongitude
            ),
            span: MKCoordinateSpan(
                latitudeDelta: stored.spanLatitude,
                longitudeDelta: stored.spanLongitude
            )
        )
        zoomLevel               = stored.zoomLevel
        selectedMapType         = CustomMapStyle(rawValue: stored.selectedMapType) ?? selectedMapType
        pilotTrackDays          = stored.pilotTrackDays
        mapDisplayMode          = MapDisplayMode(rawValue: stored.mapDisplayMode) ?? mapDisplayMode
        showSites               = stored.showSites
        showStations            = stored.showStations
        showRadar               = stored.showRadar
        showInfrared            = stored.showInfrared
        radarColorScheme        = stored.radarColorScheme
        selectedPilots          = stored.selectedPilots
        userFavoriteSites       = stored.userFavoriteSites
        userPickListSelections  = stored.userPickListSelections
    }
    
    // Call this to store persistence (e.g. on background/inactive)
    func saveToStorage() {
        let settings = PersistedSettings(
            centerLatitude:         mapRegion.center.latitude,
            centerLongitude:        mapRegion.center.longitude,
            spanLatitude:           mapRegion.span.latitudeDelta,
            spanLongitude:          mapRegion.span.longitudeDelta,
            zoomLevel:              zoomLevel,
            selectedMapType:        selectedMapType.rawValue,
            pilotTrackDays:         pilotTrackDays,
            mapDisplayMode:         mapDisplayMode.rawValue,
            showSites:              showSites,
            showStations:           showStations,
            showRadar:              showRadar,
            showInfrared:           showInfrared,
            radarColorScheme:       radarColorScheme,
            selectedPilots:         selectedPilots,
            userFavoriteSites:      userFavoriteSites,
            userPickListSelections: userPickListSelections
        )
        
        if let data = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }
    
    // Reset to app defaults (clear local storage and in-memory settings)
    func clearUserSettings(completion: @escaping () -> Void) {

        // Remove from local storage
        UserDefaults.standard.removeObject(forKey: storageKey)

        // Remove from memory
        mapRegion          = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: mapDefaultLatitude, longitude: mapDefaultLongitude),
            span: MKCoordinateSpan(latitudeDelta: mapDefaultLatitudeSpan, longitudeDelta: mapDefaultLongitudeSpan)
        )
        zoomLevel               = mapDefaultZoomLevel
        selectedMapType         = defaultmapType
        pilotTrackDays          = defaultPilotTrackDays
        mapDisplayMode          = defaultmapDisplayMode
        showSites               = defaultShowSites
        showStations            = defaultShowStations
        showRadar               = defaultShowRadar
        showInfrared            = defaultShowInfrared
        radarColorScheme        = defaultRadarColorScheme
        selectedPilots          = []
        userFavoriteSites       = []
        userPickListSelections  = []
        
        completion()
    }
}
