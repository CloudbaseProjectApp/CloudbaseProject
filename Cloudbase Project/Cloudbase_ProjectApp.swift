import SwiftUI
import MapKit
import UIKit

let timeChangeNotification = UIApplication.significantTimeChangeNotification

@main
struct Cloudbase_ProjectApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @State private var refreshMetadata: Bool = false
    @StateObject private var appRegionViewModel             = AppRegionViewModel()
    @StateObject private var appRegionCodesViewModel        = AppRegionCodesViewModel()
    @StateObject private var appURLViewModel                = AppURLViewModel()
    @StateObject private var liftParametersViewModel        = LiftParametersViewModel()
    @StateObject private var sunriseSunsetViewModel         = SunriseSunsetViewModel()
    @StateObject private var weatherCodesViewModel          = WeatherCodeViewModel()
    @StateObject private var siteViewModel                  = SiteViewModel()
    @StateObject private var pilotViewModel                 = PilotViewModel()
    @StateObject private var pilotTrackViewModel:             PilotTrackViewModel
    @StateObject private var stationLatestReadingViewModel:   StationLatestReadingViewModel
    @StateObject private var userSettingsViewModel          = UserSettingsViewModel(
        mapRegion: MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: mapDefaultLatitude, longitude: mapDefaultLongitude),
            span: MKCoordinateSpan(latitudeDelta: mapDefaultLatitudeSpan, longitudeDelta: mapDefaultLongitudeSpan)
        ),
        selectedMapType: defaultmapType,
        pilotTrackDays: defaultPilotTrackDays,
        mapDisplayMode: defaultmapDisplayMode,
        showSites: defaultShowSites,
        showStations: defaultShowStations
    )
    
    init() {
        
        // Configure picker to use different widths based on content text
        UISegmentedControl.appearance().apportionsSegmentWidthsByContent = true
        
        // Create each view‐model in the proper order, using locals
        // pilotTrackViewModel isn't created here; waiting for mapView to be accessed before creating
        let appRegionVM         = AppRegionViewModel()
        let appRegionCodesVM    = AppRegionCodesViewModel()
        let appURLVM            = AppURLViewModel()
        let liftVM              = LiftParametersViewModel()
        let sunVM               = SunriseSunsetViewModel()
        let weatherVM           = WeatherCodeViewModel()
        let siteVM              = SiteViewModel()
        let pilotVM             = PilotViewModel()
        let stationVM           = StationLatestReadingViewModel(siteViewModel: siteVM)
        let userSettingsVM      = UserSettingsViewModel(
            mapRegion: MKCoordinateRegion(
                center:     CLLocationCoordinate2D(
                    latitude:   mapDefaultLatitude,
                    longitude:  mapDefaultLongitude
                ),
                span: MKCoordinateSpan(
                    latitudeDelta:  mapDefaultLatitudeSpan,
                    longitudeDelta: mapDefaultLongitudeSpan
                )
            ),
            selectedMapType:    defaultmapType,
            pilotTrackDays:     defaultPilotTrackDays,
            mapDisplayMode:     defaultmapDisplayMode,
            showSites:          defaultShowSites,
            showStations:       defaultShowStations
        )
        
        // Populate app region view model (for user to select region and other metadata to load)
        appRegionVM.getAppRegions() {}
        
        // Populate app URLs and region codes
        appURLVM.getAppURLs() {}
        appRegionCodesVM.getAppRegionCodes() {}
        
        // Load user settings from storage
        userSettingsVM.loadFromStorage()
        _userSettingsViewModel = StateObject(wrappedValue: userSettingsVM)
        
        // Wire view models into their @StateObject wrappers:
        _appRegionViewModel             = StateObject(wrappedValue: appRegionVM)
        _appRegionCodesViewModel        = StateObject(wrappedValue: appRegionCodesVM)
        _appURLViewModel                = StateObject(wrappedValue: appURLVM)
        _liftParametersViewModel        = StateObject(wrappedValue: liftVM)
        _sunriseSunsetViewModel         = StateObject(wrappedValue: sunVM)
        _weatherCodesViewModel          = StateObject(wrappedValue: weatherVM)
        _siteViewModel                  = StateObject(wrappedValue: siteVM)
        _pilotViewModel                 = StateObject(wrappedValue: pilotVM)
        _stationLatestReadingViewModel  = StateObject(wrappedValue: stationVM)
        _userSettingsViewModel          = StateObject(wrappedValue: userSettingsVM)
        _pilotTrackViewModel            = StateObject(wrappedValue: PilotTrackViewModel(pilotViewModel: pilotVM))
    }
    
    var body: some Scene {
        WindowGroup {
            BaseAppView(refreshMetadata: $refreshMetadata)
                .environmentObject(appRegionViewModel)
                .environmentObject(appRegionCodesViewModel)
                .environmentObject(appURLViewModel)
                .environmentObject(liftParametersViewModel)
                .environmentObject(weatherCodesViewModel)
                .environmentObject(sunriseSunsetViewModel)
                .environmentObject(siteViewModel)
                .environmentObject(pilotViewModel)
                .environmentObject(pilotTrackViewModel)
                .environmentObject(stationLatestReadingViewModel)
                .environmentObject(userSettingsViewModel)
                .environment(\.colorScheme, .dark)
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)) { _ in
                    refreshMetadata = true
                }
                .onChange(of: scenePhase) { oldPhase, newPhase in
                    switch newPhase {
                    case .background, .inactive:
                        userSettingsViewModel.saveToStorage()
                    default:
                        break
                    }
                }
        }
    }
}

struct BaseAppView: View {
    @Binding var refreshMetadata: Bool
    @State private var isActive = false
    @State private var metadataLoaded = false
    @State private var showAppRegionSelector: Bool = false
    @EnvironmentObject var appRegionViewModel: AppRegionViewModel
    @EnvironmentObject var appURLViewModel: AppURLViewModel
    @EnvironmentObject var appRegionCodesViewModel: AppRegionCodesViewModel
    @EnvironmentObject var liftParametersViewModel: LiftParametersViewModel
    @EnvironmentObject var sunriseSunsetViewModel: SunriseSunsetViewModel
    @EnvironmentObject var weatherCodesViewModel: WeatherCodeViewModel
    @EnvironmentObject var pilotViewModel: PilotViewModel
    @EnvironmentObject var pilotTrackViewModel: PilotTrackViewModel
    @EnvironmentObject var siteViewModel: SiteViewModel
    @EnvironmentObject var stationLatestReadingViewModel: StationLatestReadingViewModel
    @EnvironmentObject var userSettingsViewModel: UserSettingsViewModel

    var body: some View {
        
        ZStack {
            backgroundColor.edgesIgnoringSafeArea(.all)
            VStack {
                if isActive && metadataLoaded {
                    
                    if RegionManager.shared.activeAppRegion.isEmpty {
                        // Empty view or placeholder while waiting for selection
                        Color.clear
                            .onAppear {
                                showAppRegionSelector = true
                            }
                    } else {
                        MainView(refreshMetadata: $refreshMetadata)
                    }
                    
                } else {
                    SplashScreenView()
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                checkIfReadyToTransition()
                            }
                        }
                }
            }
        }

        .onAppear {
            
            if !RegionManager.shared.activeAppRegion.isEmpty && !metadataLoaded {
                loadInitialMetadata()
            } else {
                showAppRegionSelector = true
            }
        }
        
        .onChange(of: RegionManager.shared.activeAppRegion) { _, newRegion in
            if !newRegion.isEmpty && !metadataLoaded {
                loadInitialMetadata()
            }
        }
        
        .onChange(of: refreshMetadata) { _, newValue in
            if newValue {
                isActive = false
                metadataLoaded = false
                if !RegionManager.shared.activeAppRegion.isEmpty {
                    loadInitialMetadata()
                }
                refreshMetadata = false
            }
        }
    
        .sheet(isPresented: $showAppRegionSelector) {
            AppRegionView()
                .interactiveDismissDisabled(true)
                .environmentObject(userSettingsViewModel)
        }
    
    }
    
    private func loadInitialMetadata() {
        let group = DispatchGroup()
        
        // Load app regions before loading all other metadata
        appRegionViewModel.getAppRegions() {
            
            group.enter()
            appURLViewModel.getAppURLs() {
                group.leave()
            }
            
            group.enter()
            appRegionCodesViewModel.getAppRegionCodes() {
                group.leave()
            }
            
            group.enter()
            liftParametersViewModel.getLiftParameters {
                group.leave()
            }
            
            group.enter()
            weatherCodesViewModel.getWeatherCodes {
                group.leave()
            }
            
            group.enter()
            sunriseSunsetViewModel.getSunriseSunset() {
                group.leave()
            }

            group.enter()
            pilotViewModel.getPilots() {
                group.leave()
            }
            
            // Don't enter `group` for siteViewModel – handle its completion separately
            group.enter()
            siteViewModel.getSites() {
                // Once site data is available, load stations using it
                stationLatestReadingViewModel.getLatestReadingsData(sitesOnly: true) {
                    group.leave()
                }
            }
            
        }

        initializeLoggingFile()
        
        group.notify(queue: .main) {
            metadataLoaded = true
            checkIfReadyToTransition()
        }
    }

    private func checkIfReadyToTransition() {
        if metadataLoaded {
            withAnimation {
                isActive = true
            }
        }
    }
}

struct SplashScreenView: View {
    var body: some View {
        ZStack {
            backgroundColor.edgesIgnoringSafeArea(.all)
            VStack {
                Image("CloudbaseProjectIcon")
                    .resizable()
                    .scaledToFit()
                Text("Cloudbase Project")
                    .bold()
                    .foregroundColor(titleFontColor)
                    .padding(.top, 2)
            }
        }
    }
}
