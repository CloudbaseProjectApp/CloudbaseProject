import SwiftUI
import Combine
import SDWebImage
import SDWebImageSwiftUI
import Foundation

struct WeatherView: View {
    @EnvironmentObject var userSettingsViewModel: UserSettingsViewModel
    @StateObject private var weatherAlertViewModel = WeatherAlertViewModel()
    @StateObject private var afdViewModel = AFDViewModel()
    @StateObject private var windsAloftViewModel = WindsAloftViewModel()
    @StateObject private var soaringForecastViewModel = SoaringForecastViewModel()
    @StateObject private var soaringForecastBasicViewModel = SoaringForecastBasicViewModel()
    @StateObject private var TFRviewModel = TFRViewModel()
    
    // Used to open URL links as an in-app sheet using Safari
    @Environment(\.openURL) var openURL
    @State private var externalURL: URL?
    @State private var showWebView = false
    
    // AFD
    @State private var afdSelectedIndex: Int = 0
    @State private var afdCodeOptions: [(name: String, code: String)] = []
    
    // Soaring forecast
    @State private var soaringForecastSelectedIndex: Int = 0
    @State private var soaringForecastCodeOptions: [(name: String, forecastType: String, code: String)] = []
    
    // Winds aloft forecast
    @State private var windsAloftSelectedIndex: Int = 0
    @State private var windsAloftCodeOptions: [(name: String, code: String)] = []
    
    // Latest sounding model
    @State private var soundingModelSelectedIndex: Int = 0
    @State private var soundingModelCodeOptions: [(name: String, code: String)] = []

    
    var body: some View {
        VStack {
            List {
                
                // National forecast map
                Section(header: Text("Forecast (12 hour)")
                    .font(.headline)
                    .foregroundColor(sectionHeaderColor)
                    .bold()) {
                        VStack {
                            let forecastMapURL = AppURLManager.shared.getAppURL(URLName: "forecastMapURL") ?? "<Unknown forecast map URL>"
                            if !forecastMapURL.isEmpty {
                                WebImage (url: URL(string: forecastMapURL)) { image in image.resizable() }
                                placeholder: {
                                    Text("Tap to view")
                                        .foregroundColor(infoFontColor)
                                        .multilineTextAlignment(.center)
                                        .frame(maxWidth: .infinity, alignment: .trailing)
                                }
                                .onSuccess { image, data, cacheType in }
                                .indicator(.activity) // Activity Indicator
                                .transition(.fade(duration: 0.5)) // Fade Transition with duration
                                .scaledToFit()
                                .onTapGesture { if let url = URL(string: forecastMapURL) { openLink(url) } }
                            } else {
                                Text("No forecast map available for \(RegionManager.shared.activeAppRegion)")
                                    .font(.subheadline)
                                    .foregroundColor(rowHeaderColor)
                            }
                        }
                    }
                
                // TFRs
                Section(header: Text("Temporary Flight Restrictions")
                    .font(.headline)
                    .foregroundColor(sectionHeaderColor)
                    .bold())
                {
                    if TFRviewModel.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                            .scaleEffect(0.75)
                            .frame(width: 20, height: 20)
                    } else if TFRviewModel.tfrs.isEmpty {
                        Text("No active TFRs for \(RegionManager.shared.activeAppRegion)")
                            .font(.subheadline)
                            .foregroundColor(rowHeaderColor)
                    } else {
                        ForEach(TFRviewModel.tfrs) { tfr in
                            VStack(alignment: .leading) {
                                Text(tfr.type.capitalized)
                                    .font(.subheadline)
                                    .foregroundColor(warningFontColor)
                                Text(tfr.description)
                                    .font(.subheadline)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                            .contentShape(Rectangle())      // Makes entire area tappable
                            .onTapGesture {
                                let tfrLink = AppURLManager.shared.getAppURL(URLName: "TFRLink") ?? "<Unknown TFR link URL>"
                                let updatedTFRLinkURL = updateURL(url: tfrLink, parameter: "notamID", value: tfr.notam_id.replacingOccurrences(of: "/", with: "_"))
                                if let url = URL(string: updatedTFRLinkURL) {
                                    openLink(url)
                                }
                            }
                        }
                    }
                }
                
                // Weather alerts
                Section(header: Text("Weather Alerts")
                    .font(.headline)
                    .foregroundColor(sectionHeaderColor)
                    .bold())
                {
                    VStack {
                        if weatherAlertViewModel.isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                                .scaleEffect(0.75)
                                .frame(width: 20, height: 20)
                        } else if weatherAlertViewModel.weatherAlerts.count == 0 {
                            Text("No active weather alerts for \(AppRegionManager.shared.getRegionName() ?? "")")
                                .font(.subheadline)
                                .foregroundColor(rowHeaderColor)
                        } else {
                            ForEach(weatherAlertViewModel.weatherAlerts) { alert in
                                VStack(alignment: .leading) {
                                    Text(alert.event ?? "")
                                        .font(.subheadline)
                                        .foregroundColor(warningFontColor)
                                    Text(alert.headline ?? "")
                                        .font(.subheadline)
                                    Text(alert.areaDescription ?? "")
                                        .font(.footnote)
                                        .foregroundColor(infoFontColor)
                                }
                                .padding(.vertical, 2)
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                            }
                        }
                    }
                    .contentShape(Rectangle())      // Makes entire area tappable
                    .onTapGesture {
                        let baseURL = AppURLManager.shared.getAppURL(URLName: "weatherAlertsLink") ?? ""
                        if let url = URL(string: baseURL) {
                            openLink(url)
                        }
                    }
                }
                
                // Area Forecast Discussion (AFD)
                AreaForecastDiscussionView(
                    viewModel:                afdViewModel,
                    userSettingsViewModel:    userSettingsViewModel,
                    codeOptions:              afdCodeOptions,
                    selectedIndex:            $afdSelectedIndex,
                    openLink:                 openLink(_:)
                )
                
                // Soaring forecast
                SoaringForecastView(
                    richVM:                   soaringForecastViewModel,
                    basicVM:                  soaringForecastBasicViewModel,
                    userSettingsViewModel:    userSettingsViewModel,
                    codeOptions:              soaringForecastCodeOptions,
                    selectedIndex:            $soaringForecastSelectedIndex,
                    openLink:                 openLink(_:)
                )

                // Winds aloft forecast
                Section(header: Text("Winds Aloft Forecast")
                    .font(.headline)
                    .foregroundColor(sectionHeaderColor)
                    .bold())
                {
                    if windsAloftViewModel.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                            .scaleEffect(0.75)
                            .frame(width: 20, height: 20)
                    } else if windsAloftCodeOptions.count == 0 {
                        Text("No winds aloft forecast found for region")
                    } else {
                        if windsAloftCodeOptions.count > 1 {
                            Picker("Select Location", selection: $windsAloftSelectedIndex) {
                                ForEach(0..<windsAloftCodeOptions.count, id: \.self) { index in
                                    Text(windsAloftCodeOptions[index].name).tag(index)
                                }
                            }
                            .pickerStyle(SegmentedPickerStyle())
                            .padding(.vertical, 4)
                            
                            .onChange(of: windsAloftSelectedIndex) { oldIndex, newIndex in
                                let selectedCode = windsAloftCodeOptions[newIndex].code
                                windsAloftViewModel.getWindsAloftData(airportCode: selectedCode)
                                userSettingsViewModel.updatePickListSelection(pickListName: "windsAloft", selectedIndex: newIndex)
                            }
                        }
                        
                        Text("Forecast for \(String(windsAloftCodeOptions[windsAloftSelectedIndex].name)) for the next \(windsAloftViewModel.cycle) hours")
                            .font(.footnote)
                        LazyVGrid(columns: [
                            GridItem(.fixed(64), spacing: 5, alignment: .trailing),
                            GridItem(.fixed(64), spacing: 5, alignment: .trailing),
                            GridItem(.fixed(64), spacing: 5, alignment: .trailing),
                        ], spacing: 6) {
                            Text("Altitude")
                                .font(.footnote)
                                .foregroundColor(infoFontColor)
                            Text("Temp")
                                .font(.footnote)
                                .foregroundColor(infoFontColor)
                            Text("Wind (mph)")
                                .font(.footnote)
                                .foregroundColor(infoFontColor)
                            ForEach(windsAloftViewModel.readings, id: \.altitude) { reading in
                                Text("\(reading.altitude) ft")
                                    .font(.footnote)
                                HStack {
                                    if reading.temperature != nil {
                                        Text("\(reading.temperature ?? 0)")
                                            .font(.footnote)
                                            .foregroundColor(tempColor(reading.temperature)) +
                                        Text(" ° F")
                                            .font(.footnote)
                                    } else {
                                        Text("")
                                            .font(.footnote)
                                    }
                                }
                                if reading.windDirection == 990 {
                                    Text("Light and variable")
                                        .font(.footnote)
                                } else {
                                    HStack {
                                        if reading.windSpeed != nil {
                                            Text("\(reading.windSpeed ?? 0)")
                                                .font(.footnote)
                                                .foregroundColor(windSpeedColor(windSpeed: reading.windSpeed, siteType: ""))
                                            Image(systemName: windArrow)
                                                .rotationEffect(Angle(degrees: Double(reading.windDirection ?? 0)))
                                                .font(.caption)
                                        } else {
                                            Text("")
                                                .font(.footnote)
                                        }
                                    }
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                        .contentShape(Rectangle())      // Makes entire area tappable
                        .onTapGesture {
                            let windsAloftLink = AppURLManager.shared.getAppURL(URLName: "windsAloftURL") ?? "<Unknown winds aloft link URL>"
                            let updatedWindsAloftLink = updateURL(url: windsAloftLink, parameter: "cycle", value: windsAloftCycle())
                            if let url = URL(string: updatedWindsAloftLink) {
                                openLink(url)
                            }
                        }
                    }
                }
                
                // High res diagram from morning sounding (from Matt Hansen)
                // Only if region is Utah at this point
                if RegionManager.shared.activeAppRegion == "UT" && soaringForecastViewModel.soaringForecast?.forecastMaxTemp ?? 0 > 0 {
                    Section(header: Text("SLC Morning Sounding")
                        .font(.headline)
                        .foregroundColor(sectionHeaderColor)
                        .bold()) {
                            VStack {
                                SkewTChartView(forecastMaxTemp: soaringForecastViewModel.soaringForecast?.forecastMaxTemp ?? 0)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                        }
                }
                
                // Link to sounding from latest forecast model
                Section(header: Text("Latest Model Sounding")
                    .font(.headline)
                    .foregroundColor(sectionHeaderColor)
                    .bold()) {
                        
                        if windsAloftCodeOptions.count == 0 {
                            Text ("No latest model soundings available for region")
                        } else {
                            if soundingModelCodeOptions.count > 1 {
                                Picker("Select Location", selection: $soundingModelSelectedIndex) {
                                    ForEach(0..<soundingModelCodeOptions.count, id: \.self) { index in
                                        Text(soundingModelCodeOptions[index].name).tag(index)
                                    }
                                }
                                .pickerStyle(SegmentedPickerStyle())
                                .padding(.vertical, 4)
                                .onChange(of: soundingModelSelectedIndex) { oldIndex, newIndex in
                                    userSettingsViewModel.updatePickListSelection(pickListName: "soundingModel", selectedIndex: newIndex)
                                }
                            }
                            
                            let soundingModelURL = AppURLManager.shared.getAppURL(URLName: "latestModelSoundingURL") ?? "<Unknown forecast map URL>"
                            let updatedSoundingModelURL = updateURL(url: soundingModelURL, parameter: "stationcode", value: soundingModelCodeOptions[soundingModelSelectedIndex].code)
                            
                            VStack {
                                WebImage (url: URL(string: updatedSoundingModelURL)) { image in image.resizable() }
                                placeholder: {
                                    Text("Tap to view")
                                        .foregroundColor(infoFontColor)
                                }
                                .onSuccess { image, data, cacheType in }
                                .indicator(.activity) // Activity Indicator
                                .transition(.fade(duration: 0.5)) // Fade Transition with duration
                                .scaledToFit()
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                            .contentShape(Rectangle())      // Makes entire area tappable
                            .onTapGesture { if let url = URL(string: updatedSoundingModelURL) { openLink(url) } }
                        }
                    }
                
                // Attribute SLC morning sounding if displayed (for Utah region only)
                if RegionManager.shared.activeAppRegion == "UT" {
                    VStack (alignment: .leading) {
                        Text("SLC Morning Sounding data served by Matt Hansen")
                            .font(.caption)
                            .foregroundColor(infoFontColor)
                        Text("https://wasatchwind.github.io/")
                            .font(.caption)
                            .foregroundColor(infoFontColor)
                    }
                    .listRowBackground(attributionBackgroundColor)
                }
            }
        }
        .onAppear {
            
            // TFRs
            TFRviewModel.fetchTFRs()
            
            // Weather Alerts
            weatherAlertViewModel.getWeatherAlerts()
            
            // AFD
            afdCodeOptions = AppRegionCodesManager.shared.getAFDCodes()
            if !afdCodeOptions.isEmpty {
                afdSelectedIndex = userSettingsViewModel.getPickListSelection(pickListName: "afd")
                afdViewModel.fetchAFD(airportCode: afdCodeOptions[0].code)
            }
            
            // Soaring forecast (rich/simple and basic)
            soaringForecastCodeOptions = AppRegionCodesManager.shared.getSoaringForecastCodes()
            if !soaringForecastCodeOptions.isEmpty {
                soaringForecastSelectedIndex = userSettingsViewModel.getPickListSelection(pickListName: "soaringForecast")
                if soaringForecastCodeOptions[0].forecastType == "rich" {
                    soaringForecastViewModel.fetchSoaringForecast(airportCode: soaringForecastCodeOptions[0].code)
                } else {
                    soaringForecastBasicViewModel.fetchSoaringForecast(airportCode: soaringForecastCodeOptions[0].code)
                }
            }
            
            // Winds aloft forecast
            windsAloftCodeOptions = AppRegionCodesManager.shared.getWindsAloftCodes()
            if !windsAloftCodeOptions.isEmpty {
                windsAloftSelectedIndex = userSettingsViewModel.getPickListSelection(pickListName: "windsAloft")
                windsAloftViewModel.getWindsAloftData(airportCode: windsAloftCodeOptions[0].code)
            }
            
            // Latest sounding model
            soundingModelCodeOptions = AppRegionCodesManager.shared.getSoundingModelCodes()
            if !soundingModelCodeOptions.isEmpty {
                soundingModelSelectedIndex = userSettingsViewModel.getPickListSelection(pickListName: "soundingModel")
            }

        }
        
        // Used to open URL links as an in-app sheet using Safari
        .sheet(isPresented: $showWebView) {
            if let url = externalURL {
                SafariView(url: url)
                    .setSheetConfig()
            }
        }
    }
    // Used to open URL links as an in-app sheet using Safari
    func openLink(_ url: URL) { externalURL = url; showWebView = true }
}
