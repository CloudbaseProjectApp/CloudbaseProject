import SwiftUI
import Combine
import SDWebImage
import SDWebImageSwiftUI
import Foundation

struct WeatherAlert: Identifiable, Decodable {
    let id: String
    let areaDesc: String
    let event: String
    let headline: String

    private enum CodingKeys: String, CodingKey {
        case id = "@id"
        case areaDesc
        case event
        case headline
    }
}

struct WeatherAlertFeature: Decodable {
    let properties: WeatherAlert
}

struct WeatherAlertAPIResponse: Decodable {
    let features: [WeatherAlertFeature]
}

struct WeatherView: View {
    @EnvironmentObject var appRegionViewModel: AppRegionViewModel
    @EnvironmentObject var userSettingsViewModel: UserSettingsViewModel
    @StateObject private var AFDviewModel = AFDViewModel()
    @StateObject private var windAloftData = WindAloftData()
    @StateObject private var soaringForecastViewModel = SoaringForecastViewModel()
    @StateObject private var TFRviewModel = TFRViewModel()
    @Environment(\.openURL) var openURL     // Used to open URL links as an in-app sheet using Safari
    @State private var externalURL: URL?    // Used to open URL links as an in-app sheet using Safari
    @State private var showWebView = false  // Used to open URL links as an in-app sheet using Safari
    @State private var showKeyMessages = true
    @State private var showSynopsis = true
    @State private var showDiscussion = false
    @State private var showShortTerm = false
    @State private var showLongTerm = false
    @State private var showAviation = true
    @State private var showSoaringForecast = true
    @State private var showSoundingData = true
    @State private var showSoaringModelData = false
    
    @State private var weatherAlerts: [WeatherAlert] = []
    @State private var noWeatherAlerts = false
    @State private var isLoadingWeatherAlerts = true
    @State private var isLoadingTFRs = true

    func fetchWeatherAlerts(appRegion: String) {
        
        // Only for US states
        
        if AppRegionManager.shared.getRegionCountry(appRegion: appRegion) == "US" {
            
            let weatherAlertsURL = "\(weatherAlertsAPI)\(appRegion)"
            guard let url = URL(string: weatherAlertsURL) else {
                return
            }
            URLSession.shared.dataTask(with: url) { data, response, error in
                if let data = data {
                    do {
                        let decodedResponse = try JSONDecoder().decode(WeatherAlertAPIResponse.self, from: data)
                        DispatchQueue.main.async {
                            if !decodedResponse.features.isEmpty {
                                self.weatherAlerts = decodedResponse.features.map { $0.properties }
                            } else {
                                self.noWeatherAlerts = true
                            }
                            self.isLoadingWeatherAlerts = false
                        }
                    } catch {
                        print("Error decoding JSON: \(error)")
                        DispatchQueue.main.async {
                            self.noWeatherAlerts = true
                            self.isLoadingWeatherAlerts = false
                        }
                    }
                } else {
                    DispatchQueue.main.async {
                        self.noWeatherAlerts = true
                        self.isLoadingWeatherAlerts = false
                    }
                }
            }.resume()
        } else {
            // Not a US state
            self.noWeatherAlerts = true
            self.isLoadingWeatherAlerts = false
        }
    }

    var body: some View {
        List {
            
            // National forecast map
            Section(header: Text("Forecast (12 hour)")
                .font(.headline)
                .foregroundColor(sectionHeaderColor)
                .bold()) {
                    VStack {
                        let forecastMapURL = AppRegionManager.shared.getRegionForecastMapURL(appRegion: userSettingsViewModel.appRegion) ?? "<Unknown Region>"
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
                            let regionName = AppRegionManager.shared.getRegionName(appRegion: userSettingsViewModel.appRegion) ?? "<Unknown Region>"
                            Text("No forecast map available for \(regionName)")
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
                    let regionName = AppRegionManager.shared.getRegionName(appRegion: userSettingsViewModel.appRegion) ?? "<Unknown Region>"
                    Text("No active TFRs for \(regionName)")
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
                    if isLoadingWeatherAlerts {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                            .scaleEffect(0.75)
                            .frame(width: 20, height: 20)
                    } else if noWeatherAlerts {
                        let regionName = AppRegionManager.shared.getRegionName(appRegion: userSettingsViewModel.appRegion) ?? "<Unknown Region>"
                        Text("No active weather alerts for \(regionName)")
                            .font(.subheadline)
                            .foregroundColor(rowHeaderColor)
                    } else {
                        ForEach(weatherAlerts) { alert in
                            VStack(alignment: .leading) {
                                Text(alert.event)
                                    .font(.subheadline)
                                    .foregroundColor(warningFontColor)
                                Text(alert.headline)
                                    .font(.subheadline)
                                Text(alert.areaDesc)
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
                    if let url = URL(string: AppRegionManager.shared.getRegionWeatherAlertsLink(appRegion: userSettingsViewModel.appRegion) ?? "") {
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
                if let AFDdata = AFDviewModel.AFDvar {
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
                                            if let url = URL(string: AppRegionManager.shared.getRegionAreaForecastDiscussionURL(appRegion: userSettingsViewModel.appRegion) ?? "") {
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
                                            if let url = URL(string: AppRegionManager.shared.getRegionAreaForecastDiscussionURL(appRegion: userSettingsViewModel.appRegion) ?? "") {
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
                                            if let url = URL(string: AppRegionManager.shared.getRegionAreaForecastDiscussionURL(appRegion: userSettingsViewModel.appRegion) ?? "") {
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
                                            if let url = URL(string: AppRegionManager.shared.getRegionAreaForecastDiscussionURL(appRegion: userSettingsViewModel.appRegion) ?? "") {
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
                                            if let url = URL(string: AppRegionManager.shared.getRegionAreaForecastDiscussionURL(appRegion: userSettingsViewModel.appRegion) ?? "") {
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
                                            if let url = URL(string: AppRegionManager.shared.getRegionAreaForecastDiscussionURL(appRegion: userSettingsViewModel.appRegion) ?? "") {
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
            
            // Soaring forecast
            Section(header: Text("Soaring Forecast")
                .font(.headline)
                .foregroundColor(sectionHeaderColor)
                .bold())
            {
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
                        if let url = URL(string: AppRegionManager.shared.getRegionSoaringForecastURL(appRegion: userSettingsViewModel.appRegion) ?? "") {
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
                            if let url = URL(string: AppRegionManager.shared.getRegionSoaringForecastURL(appRegion: userSettingsViewModel.appRegion) ?? "") {
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
                            if let url = URL(string: AppRegionManager.shared.getRegionSoaringForecastURL(appRegion: userSettingsViewModel.appRegion) ?? "") {
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
                                if let url = URL(string: AppRegionManager.shared.getRegionSoaringForecastURL(appRegion: userSettingsViewModel.appRegion) ?? "") {
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
            
            // Winds aloft forecast
            Section(header: Text("Winds Aloft Forecast")
                .font(.headline)
                .foregroundColor(sectionHeaderColor)
                .bold())
            {
                Text("Forecast for \(String(AppRegionManager.shared.getRegionWindsAloftCode(appRegion: userSettingsViewModel.appRegion) ?? "<unknown>")) for the next \(windAloftData.cycle) hours")
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
                    ForEach(windAloftData.readings, id: \.altitude) { reading in
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
            
            // High res diagram from morning sounding (from Matt Hansen)
            // Only if region is Utah at this point
            if userSettingsViewModel.appRegion == "UT" {
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
                    WebImage (url: URL(string: AppRegionManager.shared.getRegionLatestModelSoundingURL(appRegion: userSettingsViewModel.appRegion) ?? "")) { image in image.resizable() }
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
                .onTapGesture { if let url = URL(string: AppRegionManager.shared.getRegionLatestModelSoundingURL(appRegion: userSettingsViewModel.appRegion) ?? "") { openLink(url) } }
            }
            
            // Attribute SLC morning sounding if displayed (for Utah region only)
            if userSettingsViewModel.appRegion == "UT" {
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
        .onAppear {
            fetchWeatherAlerts(appRegion: userSettingsViewModel.appRegion)
            TFRviewModel.fetchTFRs(appRegion: userSettingsViewModel.appRegion)
            AFDviewModel.fetchAFD(appRegion: userSettingsViewModel.appRegion)
            soaringForecastViewModel.fetchSoaringForecast(appRegion: userSettingsViewModel.appRegion)
            windAloftData.fetchWindAloftData(appRegion: userSettingsViewModel.appRegion)
        }
        // Used to open URL links as an in-app sheet using Safari
        .sheet(isPresented: $showWebView) { if let url = externalURL { SafariView(url: url) } }
    }
    // Used to open URL links as an in-app sheet using Safari
    func openLink(_ url: URL) { externalURL = url; showWebView = true }
}
