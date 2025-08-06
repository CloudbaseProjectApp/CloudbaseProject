import SwiftUI
import MapKit

// Page navigation values
enum NavBarSelectedView: Int {
    case site = 0
    case weather = 1
    case potential = 2
    case map = 3
    case webcam = 4
    case link = 5
}

struct MainView: View {
    @Binding var refreshMetadata: Bool
    @EnvironmentObject var liftParametersViewModel: LiftParametersViewModel
    @EnvironmentObject var weatherCodesViewModel: WeatherCodeViewModel
    @EnvironmentObject var sunriseSunsetViewModel: SunriseSunsetViewModel
    @EnvironmentObject var siteViewModel: SiteViewModel
    @EnvironmentObject var pilotViewModel: PilotViewModel
    @EnvironmentObject var userSettingsViewModel: UserSettingsViewModel
    @EnvironmentObject var stationLatestReadingViewModel: StationLatestReadingViewModel
    @EnvironmentObject var stationAnnotationViewModel: StationAnnotationViewModel
    @EnvironmentObject var siteDailyForecastViewModel: SiteDailyForecastViewModel
    @EnvironmentObject var siteForecastViewModel: SiteForecastViewModel
    @EnvironmentObject var weatherCamViewModel: WeatherCamViewModel

    @State var selectedView:NavBarSelectedView = .site
    @State var siteViewActive =         true
    @State var weatherViewActive =      false
    @State var potentialViewActive =    false
    @State var mapViewActive =          false
    @State var webcamViewActive =       false
    @State var linkViewActive =         false
    @State private var openAboutView =  false

    private var appRegionName: String {
        AppRegionManager.shared.getRegionName() ?? ""
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                
                // Call content based on selected navigation
                if selectedView == .site {
                    SiteView()
                }
                if selectedView == .weather {
                    WeatherView()
                }
                if selectedView == .potential {
                    FlyingPotentialView()
                }
                if selectedView == .map {
                    MapContainerView()
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
                                potentialViewActive = false
                                mapViewActive = false
                                webcamViewActive = false
                                linkViewActive = false
                            } label: {
                                VStack {
                                    Image(systemName: "cloud.sun")
                                        .foregroundColor(siteViewActive ? toolbarActiveImageColor : toolbarImageColor)
                                        .font(.system(size: toolbarItemSize))
                                        .frame(width: toolbarItemSize, height: toolbarItemSize)
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
                                potentialViewActive = false
                                mapViewActive = false
                                webcamViewActive = false
                                linkViewActive = false
                            } label: {
                                VStack {
                                    Image(systemName: "cloud.sun")
                                        .foregroundColor(weatherViewActive ? toolbarActiveImageColor : toolbarImageColor)
                                        .font(.system(size: toolbarItemSize))
                                        .frame(width: toolbarItemSize, height: toolbarItemSize)
                                    Text("Weather")
                                        .foregroundColor(weatherViewActive ? toolbarActiveFontColor : toolbarFontColor)
                                        .font(.caption)
                                        .padding(.top, 4)
                                }
                            }
                            Spacer()
                            Button {
                                selectedView = .potential
                                siteViewActive = false
                                weatherViewActive = false
                                potentialViewActive = true
                                mapViewActive = false
                                webcamViewActive = false
                                linkViewActive = false
                            } label: {
                                VStack {
                                    Image("PGIconSystemImage")
                                        .renderingMode(.template)
                                        .resizable()
                                        .scaledToFit()
                                        // Customizing frame dimensions as it seems dependent on original image size
                                        .frame(width: toolbarItemSize * 1.6, height: toolbarItemSize * 1.6)                                        //.offset(y: 1) // Adjust height relative to other toolbar icons
                                        .foregroundColor(potentialViewActive ? toolbarActiveImageColor : toolbarImageColor)
                                    Text("Potential")
                                        .foregroundColor(potentialViewActive ? toolbarActiveFontColor : toolbarFontColor)
                                        .font(.caption)
                                        .padding(.top, 0)
                                }
                            }
                            Spacer()
                            Button {
                                selectedView = .map
                                siteViewActive = false
                                weatherViewActive = false
                                potentialViewActive = false
                                mapViewActive = true
                                webcamViewActive = false
                                linkViewActive = false
                            } label: {
                                VStack {
                                    Image(systemName: "map")
                                        .foregroundColor(mapViewActive ? toolbarActiveImageColor : toolbarImageColor)
                                        .font(.system(size: toolbarItemSize))
                                        .frame(width: toolbarItemSize, height: toolbarItemSize)
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
                                potentialViewActive = false
                                mapViewActive = false
                                webcamViewActive = true
                                linkViewActive = false
                            } label: {
                                VStack {
                                    Image(systemName: "photo")
                                        .foregroundColor(webcamViewActive ? toolbarActiveImageColor : toolbarImageColor)
                                        .font(.system(size: toolbarItemSize))
                                        .frame(width: toolbarItemSize, height: toolbarItemSize)
                                    Text("Cams")
                                        .foregroundColor(webcamViewActive ? toolbarActiveFontColor : toolbarFontColor)
                                        .font(.caption)
                                        .padding(.top, 4)
                                }
                            }
                            Spacer()
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
