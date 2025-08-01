import SwiftUI
import Combine
import Charts

struct ReadingsHistoryBarChartView: View {
    var readingsHistoryData: ReadingsHistoryData
    var siteType: String

    var body: some View {
        let count = min(readingsHistoryData.times.count, 10)
        let dataRange = (readingsHistoryData.times.count - count)..<readingsHistoryData.times.count
        
        Chart {
            ForEach(dataRange, id: \.self) { index in
                let windSpeed = readingsHistoryData.windSpeed[index].rounded()
                let windGust = readingsHistoryData.windGust[index]?.rounded() ?? 0.0
                let windDirection = readingsHistoryData.windDirection[index]
                let time = readingsHistoryData.times[index]
                let windColor = windSpeedColor(windSpeed: Int(windSpeed.rounded()), siteType: siteType)
                let gustColor = windSpeedColor(windSpeed: Int(windGust.rounded()), siteType: siteType)
                
                BarMark(
                    x: .value("Time", time),
                    yStart: .value("Wind Speed", 0),
                    yEnd: .value("Wind Speed", windSpeed)
                )
                .foregroundStyle(windColor)
                .annotation(position: .bottom) {
                    VStack {
                        Text("\(Int(windSpeed))")
                            .font(.caption)
                            .foregroundColor(windColor)
                            .bold()
                        Image(systemName: windArrow)
                            .rotationEffect(.degrees(Double(windDirection + 180)))
                            .bold()
                            .font(.footnote)
                        // Replace x-axis values with hh:mm and strip the am/pm
                        Text(String(time).split(separator: " ", maxSplits: 1).first ?? "")
                            .font(.caption)
                    }
                }
                if windGust > 0 {
                    BarMark(
                        x: .value("Time", time),
                        yStart: .value("Wind Speed", windSpeed + 1), // Create a gap
                        yEnd: .value("Wind Gust", windSpeed + windGust + 1)
                    )
                    .foregroundStyle(gustColor)
                    .annotation(position: .top) {
                        HStack(spacing: 4) {
                            Text("g")
                                .font(.caption)
                            Text("\(Int(windGust))")
                                .font(.caption)
                                .foregroundColor(gustColor)
                                .bold()
                        }
                    }
                }
            }
        }
        .chartYAxis(.hidden) // Remove the y-axis values
        .chartXAxis(.hidden)
        .chartXAxis { AxisMarks(stroke: StrokeStyle(lineWidth: 0)) }  // Hide vertical column separators
        .frame(height: 90) // Reduce the chart height
    }
}

struct SiteDetailView: View {
    var site: Site              // Received from parent view
    var favoriteName: String?   // Override display name if site detail is for a user favorite
    
    @EnvironmentObject var liftParametersViewModel: LiftParametersViewModel
    @EnvironmentObject var sunriseSunsetViewModel: SunriseSunsetViewModel
    @EnvironmentObject var weatherCodesViewModel: WeatherCodeViewModel
    @EnvironmentObject var userSettingsViewModel: UserSettingsViewModel
    @StateObject var viewModel = StationReadingsHistoryDataModel()
    
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) var openURL     // Used to open URL links as an in-app sheet using Safari
    @State private var externalURL: URL?    // Used to open URL links as an in-app sheet using Safari
    @State private var showWebView = false  // Used to open URL links as an in-app sheet using Safari
    @State private var isActive = false
    @State private var historyIsLoading = true
    @State private var isFavorite: Bool = false
        
    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Button(action: {
                    presentationMode.wrappedValue.dismiss()
                }) {
                    HStack {
                        Image(systemName: "chevron.left")
                            .foregroundColor(toolbarActiveImageColor)
                        Text("Back")
                            .foregroundColor(toolbarActiveFontColor)
                    }
                }
                Spacer()
                Text(site.siteName)
                    .foregroundColor(sectionHeaderColor)
                    .bold()
                Button(action: {
                    if !isFavorite {
                        do {
                            let favoriteType = getFavoriteType(siteType: site.siteType)
                            let favoriteName = favoriteType == "station" ? site.siteName.capitalized : site.siteName
                            try userSettingsViewModel.addFavorite(
                                favoriteType:   favoriteType,
                                favoriteID:     site.siteName,
                                favoriteName:   favoriteName,
                                readingsSource: site.readingsSource,
                                stationID:      site.readingsStation,
                                readingsAlt:    site.readingsAlt,
                                siteLat:        site.siteLat,
                                siteLon:        site.siteLon,
                            )
                        } catch {
                            print("Failed to add favorite: \(error.localizedDescription)")
                        }
                    } else {
                        do {
                            try userSettingsViewModel.removeFavorite(
                                favoriteType: getFavoriteType(siteType: site.siteType),
                                favoriteID: site.siteName
                            )
                        } catch {
                            print("Failed to remove favorite: \(error.localizedDescription)")
                        }
                    }
                }) {
                    Image(systemName: isFavorite ? "star.fill" : "star")
                        .font(.title3)
                        .foregroundColor(isFavorite ? .yellow : .gray)
                }
            }
            .padding()
            .background(toolbarBackgroundColor)
            
            List {
                
                Section(header: Text("Wind Readings")
                    .font(.subheadline)
                    .foregroundColor(sectionHeaderColor)
                    .bold())
                {
                    VStack {
                        VStack (alignment: .leading) {
                            Text(buildReferenceNote(Alt: site.readingsAlt, Note: site.readingsNote))
                                .font(.footnote)
                                .foregroundColor(infoFontColor)
                            if historyIsLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle())
                                    .scaleEffect(0.75)
                                    .frame(width: 20, height: 20)
                            } else if let errorMessage = viewModel.readingsHistoryData.errorMessage {
                                Text("Error message:")
                                    .padding(.top, 8)
                                Text(errorMessage)
                            } else if viewModel.readingsHistoryData.times.isEmpty {
                                Text("Station down")
                                    .padding(.top, 8)
                                    .font(.caption)
                                    .foregroundColor(infoFontColor)
                            } else {
                                ReadingsHistoryBarChartView(readingsHistoryData: viewModel.readingsHistoryData, siteType: site.siteType)
                            }
                        }
                        VStack (alignment: .center) {
                            switch site.readingsSource {
                            case "Mesonet":
                                Text("Tap for 2 day readings history")
                                    .font(.caption)
                                    .foregroundColor(infoFontColor)
                                    .padding(.top, 4)
                            case "CUASA":
                                Text("Tap for CUASA live readings site")
                                    .font(.caption)
                                    .foregroundColor(infoFontColor)
                                    .padding(.top, 4)
                            case "RMHPA":
                                Text("Tap for RMHPA live readings site")
                                    .font(.caption)
                                    .foregroundColor(infoFontColor)
                                    .padding(.top, 4)
                            default:
                                Text("Invalid readings source; no history available")
                                    .font(.caption)
                                    .foregroundColor(infoFontColor)
                                    .padding(.top, 4)
                            }
                        }
                    }
                    .contentShape(Rectangle()) // Makes entire area tappable
                    .onTapGesture {
                        switch site.readingsSource {
                        case "Mesonet":
                            let readingsLink = AppURLManager.shared.getAppURL(URLName: "mesonetHistoryReadingsLink") ?? "<Unknown Mesonet readings history URL>"
                            let updatedReadingsLink = updateURL(url: readingsLink, parameter: "station", value: site.readingsStation)
                            if let url = URL(string: updatedReadingsLink) {
                                openLink(url)
                            }
                        case "CUASA":
                            let readingsLink = AppURLManager.shared.getAppURL(URLName: "CUASAHistoryReadingsLink") ?? "<Unknown CUASA readings history URL>"
                            let updatedReadingsLink = updateURL(url: readingsLink, parameter: "station", value: site.readingsStation)
                            if let url = URL(string: updatedReadingsLink) {
                                openLink(url)
                            }
                        case "RMHPA":
                            let readingsLink = AppURLManager.shared.getAppURL(URLName: "RMPHAHistoryReadingsLink") ?? "<Unknown RMPHA readings history URL>"
                            let updatedReadingsLink = updateURL(url: readingsLink, parameter: "station", value: site.readingsStation)
                            if let url = URL(string: updatedReadingsLink) {
                                openLink(url)
                            }

                        default:
                            print ("Invalid readings source")
                        }
                    }
                }
                
                Section(header: Text("Daily Forecast")
                    .font(.subheadline)
                    .foregroundColor(sectionHeaderColor)
                    .bold())
                {
                    SiteDailyForecastView (
                        weatherCodesViewModel: weatherCodesViewModel,
                        siteLat: site.siteLat,
                        siteLon: site.siteLon,
                        forecastNote: site.forecastNote,
                        siteName: site.siteName,
                        siteType: site.siteType )
                }
                
                Section(header: Text("Detailed Forecast")
                    .font(.subheadline)
                    .foregroundColor(sectionHeaderColor)
                    .bold())
                {
                    SiteForecastView (
                        liftParametersViewModel: liftParametersViewModel,
                        sunriseSunsetViewModel: sunriseSunsetViewModel,
                        weatherCodesViewModel: weatherCodesViewModel,
                        siteLat: site.siteLat,
                        siteLon: site.siteLon,
                        forecastNote: site.forecastNote,
                        siteName: site.siteName,
                        siteType: site.siteType )
                }
                
                VStack(alignment: .leading) {
                    if site.readingsSource == "Mesonet" {
                        Text("Readings data aggregated by Synoptic")
                            .font(.caption)
                            .foregroundColor(infoFontColor)
                        Text("https://synopticdata.com")
                            .font(.caption)
                            .foregroundColor(infoFontColor)
                            .padding(.bottom, 8)
                    }
                    if site.readingsSource == "CUASA" {
                        Text("Readings data aggregated by CUASA")
                            .font(.caption)
                            .foregroundColor(infoFontColor)
                        Text("https://sierragliding.us/cuasa")
                            .font(.caption)
                            .foregroundColor(infoFontColor)
                            .padding(.bottom, 8)
                    }
                    Text("Forecast data provided by Open-meteo")
                        .font(.caption)
                        .foregroundColor(infoFontColor)
                    Text("https://open-meteo.com")
                        .font(.caption)
                        .foregroundColor(infoFontColor)
                        .padding(.bottom, 8)
                    Text("Station ID: \(site.readingsStation) from \(site.readingsSource) at \(site.readingsAlt) ft")
                        .font(.caption)
                        .foregroundColor(infoFontColor)
                }
                .listRowBackground(attributionSheetBackgroundColor)
            }
            Spacer() // Push the content to the top of the sheet
        }
        .onAppear {
            updateIsFavorite()
            viewModel.GetReadingsHistoryData(stationID: site.readingsStation, readingsSource: site.readingsSource)
            isActive = true
            historyIsLoading = true
            startTimer()
        }
        .onReceive(viewModel.$readingsHistoryData) { newData in
            historyIsLoading = false
        }
        .onDisappear {
            isActive = false
        }
        .onChange(of: scenePhase) { oldValue, newValue in
            if newValue == .active {
                viewModel.GetReadingsHistoryData(stationID: site.readingsStation, readingsSource: site.readingsSource)
            } else {
                isActive = false
            }
        }
        .onChange(of: userSettingsViewModel.userFavoriteSites) {
            updateIsFavorite()
        }
        .sheet(isPresented: $showWebView) { if let url = externalURL { SafariView(url: url) } }
    }

    // Used to open URL links as an in-app sheet using Safari
    func openLink(_ url: URL) { externalURL = url; showWebView = true }
    
    // Reload readings data when page is active for a time interval
    private func startTimer() {
        DispatchQueue.main.asyncAfter(deadline: .now() + readingsRefreshInterval) {
            if isActive {
                viewModel.GetReadingsHistoryData(stationID: site.readingsStation, readingsSource: site.readingsSource)
                startTimer() // Continue the timer loop
            }
        }
    }
    
    // Check if site is in favorites
    private func updateIsFavorite() {
        isFavorite = userSettingsViewModel.userFavoriteSites.contains {
            $0.favoriteType == getFavoriteType(siteType: site.siteType) &&
            $0.favoriteID == site.siteName
        }
    }
    
    private func getFavoriteType (siteType: String) -> String {
        var favoriteType: String = "site"
        if siteType == "station" {
            favoriteType = "station"
        }
        return favoriteType
    }

}
