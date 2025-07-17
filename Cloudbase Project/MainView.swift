import SwiftUI
import MapKit

struct MainView: View {
    @Binding var refreshMetadata: Bool
    @EnvironmentObject var liftParametersViewModel: LiftParametersViewModel
    @EnvironmentObject var weatherCodesViewModel: WeatherCodeViewModel
    @EnvironmentObject var sunriseSunsetViewModel: SunriseSunsetViewModel
    @EnvironmentObject var siteViewModel: SiteViewModel
    @EnvironmentObject var pilotViewModel: PilotViewModel
    @EnvironmentObject var userSettingsViewModel: UserSettingsViewModel
    @EnvironmentObject var stationLatestReadingViewModel: StationLatestReadingViewModel

    @State var selectedView:NavBarSelectedView = .site
    @State var siteViewActive =         true
    @State var weatherViewActive =      false
    @State var mapViewActive =          false
    @State var webcamViewActive =       false
    @State var linkViewActive =         false
    @State private var openAboutView =  false

    private var appRegionName: String {
        AppRegionManager.shared.getRegionName(appRegion: userSettingsViewModel.appRegion) ?? ""
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                
                // Call content based on selected navigation
                if selectedView == .site {
                    SiteView()
                        .environmentObject(siteViewModel)
                        .environmentObject(stationLatestReadingViewModel)
                }
                if selectedView == .weather {
                    WeatherView()
                }
                if selectedView == .map {
                    MapContainerView(
                        pilotViewModel: pilotViewModel,
                        siteViewModel: siteViewModel,
                        userSettingsViewModel: userSettingsViewModel
                    )
                    .environmentObject(siteViewModel)
                    .environmentObject(userSettingsViewModel)
                    .environmentObject(pilotViewModel)
                    .environmentObject(stationLatestReadingViewModel)
                }
                if selectedView == .webcam {
                    WeatherCamView()
                }
                if selectedView == .link {
                    LinkView()
                }
                Spacer()
                  
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    // Title bar (top of screen)
                    ToolbarItem(placement: .navigationBarLeading) {
                        HStack (spacing:3) {
                            Image(systemName: "sunrise")
                                .foregroundColor(sunImageColor)
                                .imageScale(.medium)
                            Text(sunriseSunsetViewModel.sunriseSunset?.sunrise ?? "")
                                .foregroundColor(sunFontColor)
                                .font(.caption)
                        }
                    }
                    ToolbarItem(placement: .principal) {
                        Button(action: { openAboutView.toggle() }) {
                            HStack {
                                Text("Cloudbase: \(appRegionName)")
                                    .font(.subheadline)
                                    .bold()
                                    .foregroundColor(titleFontColor)
                                Image(systemName: "chevron.down")
                                    .font(.subheadline)
                                    .foregroundColor(infoFontColor)
                                    .imageScale(.medium)

                            }
                        }
                        .sheet(isPresented: $openAboutView) {
                            AboutView(refreshMetadata: $refreshMetadata)
                                .interactiveDismissDisabled(true) // Disables swipe-to-dismiss (force use of back button)\
                                .environmentObject(userSettingsViewModel)
                        }

                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        HStack (spacing:3) {
                            Text(sunriseSunsetViewModel.sunriseSunset?.sunset ?? "")
                                .foregroundColor(sunFontColor)
                                .font(.caption)
                            Image(systemName: "sunset")
                                .foregroundColor(sunImageColor)
                                .imageScale(.medium)
                        }
                    }
                    // Navigation bar (bottom of screen)
                    ToolbarItemGroup(placement: .bottomBar) {
                        HStack {
                            Button {
                                selectedView = .site
                                siteViewActive = true
                                weatherViewActive = false
                                mapViewActive = false
                                webcamViewActive = false
                                linkViewActive = false
                            } label: {
                                VStack {
                                    Image(systemName: "cloud.sun")
                                        .foregroundColor(siteViewActive ? toolbarActiveImageColor : toolbarImageColor)
                                        .imageScale(.medium)
                                    Text("Sites")
                                        .foregroundColor(siteViewActive ? toolbarActiveFontColor : toolbarFontColor)
                                        .font(.caption)
                                        .padding(.top, 4)
                                }
                            }
                            Spacer()
                            Button {
                                selectedView = .weather
                                siteViewActive = false
                                weatherViewActive = true
                                mapViewActive = false
                                webcamViewActive = false
                                linkViewActive = false
                            } label: {
                                VStack {
                                    Image(systemName: "cloud.sun")
                                        .foregroundColor(weatherViewActive ? toolbarActiveImageColor : toolbarImageColor)
                                        .imageScale(.medium)
                                    Text("Weather")
                                        .foregroundColor(weatherViewActive ? toolbarActiveFontColor : toolbarFontColor)
                                        .font(.caption)
                                        .padding(.top, 4)
                                }
                            }
                            Spacer()
                            Button {
                                selectedView = .map
                                siteViewActive = false
                                weatherViewActive = false
                                mapViewActive = true
                                webcamViewActive = false
                                linkViewActive = false
                            } label: {
                                VStack {
                                    Image(systemName: "map")
                                        .foregroundColor(mapViewActive ? toolbarActiveImageColor : toolbarImageColor)
                                        .imageScale(.medium)
                                    Text("Map")
                                        .foregroundColor(mapViewActive ? toolbarActiveFontColor : toolbarFontColor)
                                        .font(.caption)
                                        .padding(.top, 4)
                                }
                            }
                            Spacer()
                            Button {
                                selectedView = .webcam
                                siteViewActive = false
                                weatherViewActive = false
                                mapViewActive = false
                                webcamViewActive = true
                                linkViewActive = false
                            } label: {
                                VStack {
                                    Image(systemName: "photo")
                                        .foregroundColor(webcamViewActive ? toolbarActiveImageColor : toolbarImageColor)
                                        .imageScale(.medium)
                                    Text("Cams")
                                        .foregroundColor(webcamViewActive ? toolbarActiveFontColor : toolbarFontColor)
                                        .font(.caption)
                                        .padding(.top, 4)
                                }
                            }

                            Spacer()
                            Button {
                                selectedView = .link
                                siteViewActive = false
                                weatherViewActive = false
                                mapViewActive = false
                                webcamViewActive = false
                                linkViewActive = true
                            } label: {
                                VStack {
                                    Image(systemName: "link")
                                        .foregroundColor(linkViewActive ? toolbarActiveImageColor : toolbarImageColor)
                                        .imageScale(.medium)
                                    Text("Links")
                                        .foregroundColor(linkViewActive ? toolbarActiveFontColor : toolbarFontColor)
                                        .font(.caption)
                                        .padding(.top, 4)
                                }
                            }
                        }

                    }
                }
                // Separator bar below title bar
                VStack {
                    Rectangle()
                        .fill(titlebarSeparatorColor)
                        .frame(height: 1)
                    Spacer()
                }
            }
        }
    }
}
