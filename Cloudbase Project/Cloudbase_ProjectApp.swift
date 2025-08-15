import SwiftUI
import MapKit
import UIKit

let timeChangeNotification = UIApplication.significantTimeChangeNotification

@main
struct Cloudbase_ProjectApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @State private var refreshMetadata: Bool = false
    private var liftParametersViewModel                     = LiftParametersViewModel.shared
    @StateObject private var appRegionViewModel             = AppRegionViewModel()
    @StateObject private var appRegionCodesViewModel        = AppRegionCodesViewModel()
    @StateObject private var appURLViewModel                = AppURLViewModel()
    @StateObject private var sunriseSunsetViewModel         = SunriseSunsetViewModel()
    @StateObject private var weatherCodesViewModel          = WeatherCodeViewModel()
    @StateObject private var siteViewModel                  = SiteViewModel()
    @StateObject private var pilotViewModel                 = PilotViewModel()
    @StateObject private var weatherCamViewModel:             WeatherCamViewModel
    @StateObject private var pilotTrackViewModel:             PilotTrackViewModel
    @StateObject private var siteDailyForecastViewModel:      SiteDailyForecastViewModel
    @StateObject private var siteForecastViewModel:           SiteForecastViewModel
    @StateObject private var stationLatestReadingViewModel:   StationLatestReadingViewModel
    @StateObject private var stationAnnotationViewModel:      StationAnnotationViewModel
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
        let sunVM               = SunriseSunsetViewModel()
        let weatherVM           = WeatherCodeViewModel()
        let siteVM              = SiteViewModel()
        let pilotVM             = PilotViewModel()
        let dailyForecastVM     = SiteDailyForecastViewModel(
            weatherCodesViewModel: weatherVM
        )
        let forecastVM          = SiteForecastViewModel(
            sunriseSunsetViewModel: sunVM,
            weatherCodesViewModel: weatherVM
        )
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
        let stationVM           = StationLatestReadingViewModel(siteViewModel: siteVM, userSettingsViewModel: userSettingsVM)
        let annotationVM        = StationAnnotationViewModel(
            userSettingsViewModel: userSettingsVM,
            siteViewModel: siteVM,
            stationLatestReadingViewModel: stationVM
        )
        let weatherCamVM        = WeatherCamViewModel()
        
        // Populate app region view model (for user to select region and other metadata to load)
        Task { await appRegionVM.getAppRegions() }
        
        // Populate (in parallel) app URLs and region codes
        Task {
            async let _: Void = appURLVM.getAppURLs()
            async let _: Void = appRegionCodesVM.getAppRegionCodes()

            // Wait for both to finish
            await appURLVM.getAppURLs()
            await appRegionCodesVM.getAppRegionCodes()
        }

        // Load user settings from storage
        userSettingsVM.loadFromStorage()
        _userSettingsViewModel = StateObject(wrappedValue: userSettingsVM)
        
        // Wire view models into their @StateObject wrappers:
        _appRegionViewModel             = StateObject(wrappedValue: appRegionVM)
        _appRegionCodesViewModel        = StateObject(wrappedValue: appRegionCodesVM)
        _appURLViewModel                = StateObject(wrappedValue: appURLVM)
        _sunriseSunsetViewModel         = StateObject(wrappedValue: sunVM)
        _weatherCodesViewModel          = StateObject(wrappedValue: weatherVM)
        _siteViewModel                  = StateObject(wrappedValue: siteVM)
        _pilotViewModel                 = StateObject(wrappedValue: pilotVM)
        _stationLatestReadingViewModel  = StateObject(wrappedValue: stationVM)
        _stationAnnotationViewModel     = StateObject(wrappedValue: annotationVM)
        _siteDailyForecastViewModel     = StateObject(wrappedValue: dailyForecastVM)
        _siteForecastViewModel          = StateObject(wrappedValue: forecastVM)
        _userSettingsViewModel          = StateObject(wrappedValue: userSettingsVM)
        _pilotTrackViewModel            = StateObject(wrappedValue: PilotTrackViewModel(pilotViewModel: pilotVM))
        _weatherCamViewModel            = StateObject(wrappedValue: weatherCamVM)
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
                .environmentObject(siteDailyForecastViewModel)
                .environmentObject(siteForecastViewModel)
                .environmentObject(stationLatestReadingViewModel)
                .environmentObject(stationAnnotationViewModel)
                .environmentObject(weatherCamViewModel)
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
    @EnvironmentObject var sunriseSunsetViewModel: SunriseSunsetViewModel
    @EnvironmentObject var weatherCodesViewModel: WeatherCodeViewModel
    @EnvironmentObject var pilotViewModel: PilotViewModel
    @EnvironmentObject var pilotTrackViewModel: PilotTrackViewModel
    @EnvironmentObject var siteViewModel: SiteViewModel
    @EnvironmentObject var siteDailyForecastViewModel: SiteDailyForecastViewModel
    @EnvironmentObject var siteForecastViewModel: SiteForecastViewModel
    @EnvironmentObject var stationLatestReadingViewModel: StationLatestReadingViewModel
    @EnvironmentObject var stationAnnotationViewModel: StationAnnotationViewModel
    @EnvironmentObject var userSettingsViewModel: UserSettingsViewModel
    @EnvironmentObject var weatherCamViewModel: WeatherCamViewModel
    
    @ObservedObject var regionManager = RegionManager.shared

    var body: some View {
        ZStack {
            backgroundColor.edgesIgnoringSafeArea(.all)
            VStack {
                if isActive && metadataLoaded {
                    if RegionManager.shared.activeAppRegion.isEmpty {
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
        .onChange(of: regionManager.activeAppRegion) { _, newRegion in
            if !newRegion.isEmpty && !metadataLoaded {
                loadInitialMetadata()
            }
        }
        .onChange(of: refreshMetadata) { _, newValue in
            if newValue {
                stationLatestReadingViewModel.resetLastFetchTimes()
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
                .setSheetConfig()
                .environmentObject(userSettingsViewModel)
        }
    }
    
    private func loadInitialMetadata() {
        Task {
            // Step 1 – Load app regions and app URLs first
            await withTaskGroup(of: Void.self) { group in
                group.addTask { await appRegionViewModel.getAppRegions() }
                group.addTask { await appURLViewModel.getAppURLs() }
            }
            
            // Step 2 – Load everything else in parallel
            await withTaskGroup(of: Void.self) { group in
                group.addTask { await appRegionCodesViewModel.getAppRegionCodes() }
                group.addTask { await LiftParametersViewModel.shared.getLiftParameters() }
                group.addTask { await weatherCodesViewModel.getWeatherCodes() }
                group.addTask { await sunriseSunsetViewModel.getSunriseSunset() }
                group.addTask { await pilotViewModel.getPilots() }
                group.addTask { await siteViewModel.getSites() }
                await group.waitForAll()
            }
            
            // Fire-and-forget latest readings call after all of the above are complete (particularly getSites)
            Task {
                await stationLatestReadingViewModel.getLatestReadingsData(sitesOnly: true)
            }
            metadataLoaded = true
            checkIfReadyToTransition()
            initializeLoggingFile()
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
