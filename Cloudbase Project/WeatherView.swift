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
    @StateObject private var TFRviewModel = TFRViewModel()
    
    // Used to open URL links as an in-app sheet using Safari
    @Environment(\.openURL) var openURL
    @State private var externalURL: URL?
    @State private var showWebView = false
    
    // Weather alerts
    @State private var selectedWeatherAlertIndex: Int = 0
    @State private var weatherAlertCodeOptions: [(name: String, code: String)] = []
    
    // AFD
    @State private var selectedAFDIndex: Int = 0
    @State private var afdCodeOptions: [(name: String, code: String)] = []
    @State private var showKeyMessages = true
    @State private var showSynopsis = true
    @State private var showDiscussion = false
    @State private var showShortTerm = false
    @State private var showLongTerm = false
    @State private var showAviation = true
    
    // Soaring forecast
    @State private var selectedSoaringForecastIndex: Int = 0
    @State private var soaringForecastCodeOptions: [(name: String, forecastType: String, code: String)] = []
    @State private var showSoaringForecast = true
    @State private var showSoundingData = true
    @State private var showSoaringModelData = false

    // Winds aloft forecast
    @State private var selectedWindsAloftIndex: Int = 0
    @State private var windsAloftCodeOptions: [(name: String, code: String)] = []

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
                                if let url = URL(string: "https://tfr.faa.gov/tfr3/?page=detail_\(tfr.notam_id.replacingOccurrences(of: "/", with: "_"))") {
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
                Section(header: Text("Area Forecast Discussion")
                    .font(.headline)
                    .foregroundColor(sectionHeaderColor)
                    .bold())
                {
                    if afdViewModel.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                            .scaleEffect(0.75)
                            .frame(width: 20, height: 20)
                    } else if afdCodeOptions.count == 0 {
                        Text("No area forecast discussion found for region")
                    } else {
                        if afdCodeOptions.count > 1 {
                            Picker("Select Location", selection: $selectedAFDIndex) {
                                ForEach(0..<afdCodeOptions.count, id: \.self) { index in
                                    Text(afdCodeOptions[index].name).tag(index)
                                }
                            }
                            .pickerStyle(SegmentedPickerStyle())
                            .padding(.vertical, 4)
                            
                            .onChange(of: selectedAFDIndex) { oldIndex, newIndex in
                                let selectedCode = afdCodeOptions[newIndex].code
                                afdViewModel.fetchAFD(airportCode: selectedCode)
                            }
                        }
                        if let AFDdata = afdViewModel.AFDvar {
                            Text("Forecast Date: \(AFDdata.date)")
                                .font(.footnote)
                            if let keyMessages = AFDdata.keyMessages, !keyMessages.isEmpty {
                                DisclosureGroup(
                                    isExpanded: $showKeyMessages,
                                    content: {
                                        Text(keyMessages)
                                            .font(.subheadline)
                                            .contentShape(Rectangle())      // Makes entire area tappable
                                            .onTapGesture {
                                                let baseURL = AppURLManager.shared.getAppURL(URLName: "areaForecastDiscussionURL")
                                                let updatedURL = updateURL(url: baseURL ?? "", parameter: "airportcode", value: "SLC")
                                                if let url = URL(string: updatedURL) {
                                                    openLink(url)
                                                }
                                            }
                                    }, label: {
                                        Text("Key Messages")
                                            .font(.headline)
                                            .foregroundColor(rowHeaderColor)
                                    }
                                )
                            }
                            if let synopsis = AFDdata.synopsis, !synopsis.isEmpty {
                                DisclosureGroup(
                                    isExpanded: $showSynopsis,
                                    content: {
                                        Text(synopsis)
                                            .font(.subheadline)
                                            .contentShape(Rectangle())      // Makes entire area tappable
                                            .onTapGesture {
                                                let baseURL = AppURLManager.shared.getAppURL(URLName: "areaForecastDiscussionURL")
                                                let updatedURL = updateURL(url: baseURL ?? "", parameter: "airportcode", value: "SLC")
                                                if let url = URL(string: updatedURL) {
                                                    openLink(url)
                                                }
                                            }
                                    }, label: {
                                        Text("Synopsis")
                                            .font(.headline)
                                            .foregroundColor(rowHeaderColor)
                                    }
                                )
                            }
                            if let discussion = AFDdata.discussion, !discussion.isEmpty {
                                DisclosureGroup(
                                    isExpanded: $showDiscussion,
                                    content: {
                                        Text(discussion)
                                            .font(.subheadline)
                                            .contentShape(Rectangle())      // Makes entire area tappable
                                            .onTapGesture {
                                                let baseURL = AppURLManager.shared.getAppURL(URLName: "areaForecastDiscussionURL")
                                                let updatedURL = updateURL(url: baseURL ?? "", parameter: "airportcode", value: "SLC")
                                                if let url = URL(string: updatedURL) {
                                                    openLink(url)
                                                }
                                            }
                                    }, label: {
                                        Text("Discussion")
                                            .font(.headline)
                                            .foregroundColor(rowHeaderColor)
                                    }
                                )
                            }
                            if let shortTerm = AFDdata.shortTerm, !shortTerm.isEmpty {
                                DisclosureGroup(
                                    isExpanded: $showShortTerm,
                                    content: {
                                        Text(shortTerm)
                                            .font(.subheadline)
                                            .contentShape(Rectangle())      // Makes entire area tappable
                                            .onTapGesture {
                                                let baseURL = AppURLManager.shared.getAppURL(URLName: "areaForecastDiscussionURL")
                                                let updatedURL = updateURL(url: baseURL ?? "", parameter: "airportcode", value: "SLC")
                                                if let url = URL(string: updatedURL) {
                                                    openLink(url)
                                                }
                                            }
                                    }, label: {
                                        Text("Short Term Forecast")
                                            .font(.headline)
                                            .foregroundColor(rowHeaderColor)
                                    }
                                )
                            }
                            if let longTerm = AFDdata.longTerm, !longTerm.isEmpty  {
                                DisclosureGroup(
                                    isExpanded: $showLongTerm,
                                    content: {
                                        Text(longTerm)
                                            .font(.subheadline)
                                            .contentShape(Rectangle())      // Makes entire area tappable
                                            .onTapGesture {
                                                let baseURL = AppURLManager.shared.getAppURL(URLName: "areaForecastDiscussionURL")
                                                let updatedURL = updateURL(url: baseURL ?? "", parameter: "airportcode", value: "SLC")
                                                if let url = URL(string: updatedURL) {
                                                    openLink(url)
                                                }
                                            }
                                    }, label: {
                                        Text("Long Term Forecast")
                                            .font(.headline)
                                            .foregroundColor(rowHeaderColor)
                                    }
                                )
                            }
                            if let aviation = AFDdata.aviation, !aviation.isEmpty {
                                DisclosureGroup(
                                    isExpanded: $showAviation,
                                    content: {
                                        Text(aviation)
                                            .font(.subheadline)
                                            .contentShape(Rectangle())      // Makes entire area tappable
                                            .onTapGesture {
                                                let baseURL = AppURLManager.shared.getAppURL(URLName: "areaForecastDiscussionURL")
                                                let updatedURL = updateURL(url: baseURL ?? "", parameter: "airportcode", value: "SLC")
                                                if let url = URL(string: updatedURL) {
                                                    openLink(url)
                                                }
                                            }
                                    }, label: {
                                        Text("Aviation Forecast")
                                            .font(.headline)
                                            .foregroundColor(rowHeaderColor)
                                    }
                                )
                            }
                        } else {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                                .scaleEffect(0.75)
                                .frame(width: 20, height: 20)
                        }
                    }
                }
                
                // Soaring forecast
                Section(header: Text("Soaring Forecast")
                    .font(.headline)
                    .foregroundColor(sectionHeaderColor)
                    .bold())
                {
                    if soaringForecastViewModel.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                            .scaleEffect(0.75)
                            .frame(width: 20, height: 20)
                    } else if soaringForecastCodeOptions.count == 0 {
                        Text("No soaring forecast found for region")
                    }
                    else {
                        if soaringForecastCodeOptions.count > 1 {
                            Picker("Select Location", selection: $selectedSoaringForecastIndex) {
                                ForEach(0..<soaringForecastCodeOptions.count, id: \.self) { index in
                                    Text(soaringForecastCodeOptions[index].name).tag(index)
                                }
                            }
                            .pickerStyle(SegmentedPickerStyle())
                            .padding(.vertical, 4)
                            
                            .onChange(of: selectedSoaringForecastIndex) { oldIndex, newIndex in
                                let selectedCode = soaringForecastCodeOptions[newIndex].code
                                let selectedForecastType = soaringForecastCodeOptions[newIndex].forecastType
                                soaringForecastViewModel.fetchSoaringForecast(airportCode: selectedCode, forecastType: selectedForecastType)
                            }
                        }
                        
                        Text("Forecast Date: \(soaringForecastViewModel.soaringForecast?.date ?? "")")
                            .font(.footnote)
                        DisclosureGroup(isExpanded: $showSoaringForecast) {
                            VStack(alignment: .leading) {
                                if ((soaringForecastViewModel.soaringForecast?.soaringForecastFormat) == "Rich") {
                                    Text(soaringForecastViewModel.soaringForecast?.triggerTempData ?? "")
                                        .font(.subheadline)
                                        .padding(.bottom, 5)
                                }
                                ForEach(soaringForecastViewModel.soaringForecast?.soaringForecastData ?? []) { data in
                                    HStack {
                                        Text(data.heading)
                                            .multilineTextAlignment(.trailing)
                                            .font(.caption)
                                            .padding(.trailing, 2)
                                            .foregroundColor(infoFontColor)
                                            .frame(maxWidth: .infinity, alignment: .trailing)
                                        Text(data.value ?? "")
                                            .font(.caption)
                                            .padding(.leading, 2)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                    .padding(.bottom, 5)
                                }
                                .padding(.bottom, 1)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                            .contentShape(Rectangle())      // Makes entire area tappable
                            .onTapGesture {
                                let baseURL = AppURLManager.shared.getAppURL(URLName: "soaringForecastRichSimple")
                                let updatedURL = updateURL(url: baseURL ?? "", parameter: "airportcode", value: "SLC")
                                if let url = URL(string: updatedURL) {
                                    openLink(url)
                                }
                            }
                        } label: {
                            Text("Soaring Forecast")
                                .font(.headline)
                                .foregroundColor(rowHeaderColor)
                        }
                        DisclosureGroup(isExpanded: $showSoundingData) {
                            // Process rich format sounding data
                            if ((soaringForecastViewModel.soaringForecast?.soaringForecastFormat) == "Rich") {
                                LazyVGrid(columns: [
                                    GridItem(.fixed(64), spacing: 5, alignment: .trailing),
                                    GridItem(.fixed(52), spacing: 5, alignment: .trailing),
                                    GridItem(.fixed(52), spacing: 5, alignment: .trailing),
                                    GridItem(.fixed(56), spacing: 5, alignment: .trailing),
                                    GridItem(.fixed(52), spacing: 5, alignment: .trailing)
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
                                    Text("Thermal Index")
                                        .font(.footnote)
                                        .foregroundColor(infoFontColor)
                                        .multilineTextAlignment(.trailing)
                                    Text("Lift (m/s)")
                                        .font(.footnote)
                                        .foregroundColor(infoFontColor)
                                        .multilineTextAlignment(.trailing)
                                    ForEach(soaringForecastViewModel.soaringForecast?.richSoundingData ?? []) { data in
                                        Text("\(data.altitude) ft")
                                            .font(.footnote)
                                        HStack {
                                            Text("\(String(Int(data.temperatureF)))")
                                                .font(.caption)
                                                .foregroundColor(tempColor(Int(data.temperatureF))) +
                                            Text(" ° F")
                                                .font(.footnote)
                                        }
                                        HStack {
                                            Text("\(String(Int(data.windSpeedMph)))")
                                                .font(.footnote)
                                                .foregroundColor(windSpeedColor(windSpeed: Int(data.windSpeedMph), siteType: ""))
                                            Image(systemName: windArrow)
                                                .rotationEffect(Angle(degrees: Double(data.windDirection+180)))
                                                .font(.caption)
                                        }
                                        Text(String(format: "%.1f", data.thermalIndex))
                                            .font(.footnote)
                                        Text(String(format: "%.1f", data.liftRateMs))
                                            .font(.footnote)
                                            .foregroundStyle(thermalColor(data.liftRateMs))
                                    }
                                }
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                                .contentShape(Rectangle())      // Makes entire area tappable
                                .onTapGesture {
                                    let baseURL = AppURLManager.shared.getAppURL(URLName: "soaringForecastRichSimple")
                                    let updatedURL = updateURL(url: baseURL ?? "", parameter: "airportcode", value: "SLC")
                                    if let url = URL(string: updatedURL) {
                                        openLink(url)
                                    }
                                }
                            }
                            // Process simple/basic format sounding data
                            else {
                                VStack(alignment: .leading) {
                                    ForEach(soaringForecastViewModel.soaringForecast?.soundingData ?? []) { data in
                                        HStack {
                                            Text(data.altitude.lowercased())
                                                .frame(maxWidth: .infinity, alignment: .trailing)
                                                .font(.subheadline)
                                            Spacer()
                                            Group {
                                                Text("\(data.windSpeed)")
                                                    .font(.subheadline)
                                                    .foregroundColor(windSpeedColor(windSpeed: Int(data.windSpeed), siteType: "")) +
                                                Text(" mph")
                                                    .font(.subheadline)
                                                Image(systemName: windArrow)
                                                    .rotationEffect(.degrees(Double(data.windDirection+180)))
                                                    .font(.footnote)
                                            }
                                            .frame(maxWidth: .infinity, alignment: .trailing)
                                            Spacer()
                                        }
                                    }
                                }
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                                .contentShape(Rectangle())      // Makes entire area tappable
                                .onTapGesture {
                                    let baseURL = AppURLManager.shared.getAppURL(URLName: "soaringForecastRichSimple")
                                    let updatedURL = updateURL(url: baseURL ?? "", parameter: "airportcode", value: "SLC")
                                    if let url = URL(string: updatedURL) {
                                        openLink(url)
                                    }
                                }
                            }
                        } label: {
                            Text("Sounding Data")
                                .font(.headline)
                                .foregroundColor(rowHeaderColor)
                        }
                        // Process rich format numerical model data
                        if ((soaringForecastViewModel.soaringForecast?.soaringForecastFormat) == "Rich") {
                            DisclosureGroup(isExpanded: $showSoaringModelData) {
                                ScrollView(.horizontal) {
                                    VStack(alignment: .leading) {
                                        ForEach(soaringForecastViewModel.soaringForecast?.modelData ?? []) { data in
                                            Text(data.value)
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                                .font(.system(.subheadline, design: .monospaced))
                                        }
                                        .padding(.vertical, 0)
                                    }
                                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                                    .contentShape(Rectangle())      // Makes entire area tappable
                                    .onTapGesture {
                                        let baseURL = AppURLManager.shared.getAppURL(URLName: "soaringForecastRichSimple")
                                        let updatedURL = updateURL(url: baseURL ?? "", parameter: "airportcode", value: "SLC")
                                        if let url = URL(string: updatedURL) {
                                            openLink(url)
                                        }
                                    }
                                }
                            } label: {
                                Text("Numerical Model Data")
                                    .font(.headline)
                                    .foregroundColor(rowHeaderColor)
                            }
                        }
                    }
                }
                
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
                            Picker("Select Location", selection: $selectedWindsAloftIndex) {
                                ForEach(0..<windsAloftCodeOptions.count, id: \.self) { index in
                                    Text(windsAloftCodeOptions[index].name).tag(index)
                                }
                            }
                            .pickerStyle(SegmentedPickerStyle())
                            .padding(.vertical, 4)
                            
                            .onChange(of: selectedWindsAloftIndex) { oldIndex, newIndex in
                                let selectedCode = windsAloftCodeOptions[newIndex].code
                                windsAloftViewModel.getWindsAloftData(airportCode: selectedCode)
                            }
                        }
                        
                        Text("Forecast for \(String(windsAloftCodeOptions[selectedWindsAloftIndex].name)) for the next \(windsAloftViewModel.cycle) hours")
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
                                    Text("\(reading.temperature)")
                                        .font(.footnote)
                                        .foregroundColor(tempColor(reading.temperature)) +
                                    Text(" ° F")
                                        .font(.footnote)
                                }
                                if reading.windDirection == 990 {
                                    Text("Light and variable")
                                        .font(.footnote)
                                } else {
                                    HStack {
                                        Text("\(reading.windSpeed)")
                                            .font(.footnote)
                                            .foregroundColor(windSpeedColor(windSpeed: reading.windSpeed, siteType: ""))
                                        Image(systemName: windArrow)
                                            .rotationEffect(Angle(degrees: Double(reading.windDirection)))
                                            .font(.caption)
                                    }
                                }
                            }
                        }
                    }
                }
                
                // High res diagram from morning sounding (from Matt Hansen)
                // Only if region is Utah at this point
                if RegionManager.shared.activeAppRegion == "UT" {
                    Section(header: Text("SLC Morning Sounding")
                        .font(.headline)
                        .foregroundColor(sectionHeaderColor)
                        .bold()) {
                            VStack {
                                SkewTChartView()
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                        }
                }
                
                // Link to sounding from latest forecast model
                Section(header: Text("Latest Model Sounding")
                    .font(.headline)
                    .foregroundColor(sectionHeaderColor)
                    .bold()) {
                        VStack {
                            WebImage (url: URL(string: AppRegionManager.shared.getRegionLatestModelSoundingURL() ?? "")) { image in image.resizable() }
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
                        .onTapGesture { if let url = URL(string: AppRegionManager.shared.getRegionLatestModelSoundingURL() ?? "") { openLink(url) } }
                    }
                
                // Attribute SLC morning sounding if displayed (for Utah region only)
                if RegionManager.shared.activeAppRegion == "UT" {
                    VStack (alignment: .leading) {
                        Text("SLC Morning Sounding data served by Matt Hansen")
                            .font(.caption)
                            .foregroundColor(infoFontColor)
                            .padding(.top, 2)
                        Text("https://wasatchwind.github.io/")
                            .font(.caption)
                            .foregroundColor(infoFontColor)
                            .padding(.bottom, 4)
                    }
                }
                
            }
        }
        .onAppear {
            
            // TFRs
            TFRviewModel.fetchTFRs()

            // Weather Alerts
            weatherAlertCodeOptions = AppRegionCodesManager.shared.getWeatherAlertCodes()
            if !weatherAlertCodeOptions.isEmpty {
                selectedWeatherAlertIndex = 0
                weatherAlertViewModel.getWeatherAlerts()
            }
            
            // AFD
            afdCodeOptions = AppRegionCodesManager.shared.getAFDCodes()
            if !afdCodeOptions.isEmpty {
                selectedAFDIndex = 0
                afdViewModel.fetchAFD(airportCode: afdCodeOptions[0].code)
            }
            
            // Soaring forecast (rich/simple and basic)
            soaringForecastCodeOptions = AppRegionCodesManager.shared.getSoaringForecastCodes()
            if !soaringForecastCodeOptions.isEmpty {
                selectedSoaringForecastIndex = 0
                soaringForecastViewModel.fetchSoaringForecast(airportCode: soaringForecastCodeOptions[0].code,
                                                              forecastType: soaringForecastCodeOptions[0].forecastType)
            }
            
            // Winds aloft forecast
            windsAloftCodeOptions = AppRegionCodesManager.shared.getWindsAloftCodes()
            if !windsAloftCodeOptions.isEmpty {
                selectedWindsAloftIndex = 0
                windsAloftViewModel.getWindsAloftData(airportCode: windsAloftCodeOptions[0].code)
            }
 

        }
        // Used to open URL links as an in-app sheet using Safari
        .sheet(isPresented: $showWebView) { if let url = externalURL { SafariView(url: url) } }
    }
    // Used to open URL links as an in-app sheet using Safari
    func openLink(_ url: URL) { externalURL = url; showWebView = true }
}
