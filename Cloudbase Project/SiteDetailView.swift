import SwiftUI
import Combine
import Charts

struct SiteDetailView: View {
    var site: Site              // Received from parent view
    var favoriteName: String?   // Override display name if site detail is for a user favorite
    
    @EnvironmentObject var sunriseSunsetViewModel: SunriseSunsetViewModel
    @EnvironmentObject var weatherCodesViewModel: WeatherCodeViewModel
    @EnvironmentObject var userSettingsViewModel: UserSettingsViewModel
    @EnvironmentObject var siteDailyForecastViewModel: SiteDailyForecastViewModel
    @EnvironmentObject var siteForecastViewModel: SiteForecastViewModel
    @StateObject       var stationReadingsHistoryViewModel = StationReadingsHistoryViewModel()
    
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) var openURL     // Used to open URL links as an in-app sheet using Safari
    @State private var externalURL: URL?    // Used to open URL links as an in-app sheet using Safari
    @State private var showWebView = false  // Used to open URL links as an in-app sheet using Safari
    @State private var isActive = false
    @State private var historyIsLoading = true
    @State private var isFavorite: Bool = false
        
    var body: some View {
        let displayName = favoriteName ?? site.siteName
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
                    Text(displayName)
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
                            } else if let errorMessage = stationReadingsHistoryViewModel.readingsHistoryData.errorMessage {
                                Text("Error message: \(errorMessage)")
                                    .font(.subheadline)
                                    .foregroundColor(infoFontColor)
                                    .padding(.top, 8)
                            } else if stationReadingsHistoryViewModel.readingsHistoryData.times.isEmpty {
                                Text("Station down")
                                    .padding(.top, 8)
                                    .font(.caption)
                                    .foregroundColor(infoFontColor)
                            } else {
                                ReadingsHistoryBarChartView(readingsHistoryData: stationReadingsHistoryViewModel.readingsHistoryData, siteType: site.siteType)
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
                            // Allow for different links based on Ecowitt and Holfuy stations based on length of station name
                            let urlName: String = site.readingsStation.count < 10 ? "RMHPAHolfuyReadingsLink" : "RMHPAEcowittReadingsLink"
                            let readingsLink = AppURLManager.shared.getAppURL(URLName: urlName) ?? "<Unknown RMHPA readings history URL>"
                            let updatedReadingsLink = updateURL(url: readingsLink, parameter: "station", value: site.readingsStation)
                            if let url = URL(string: updatedReadingsLink) {
                                openLink(url)
                            }

                        default:
                            print ("Invalid readings source")
                        }
                    }
                }
                
                Section (header: Text("Forecast Accuracy")
                    .font(.subheadline)
                    .foregroundColor(sectionHeaderColor)
                    .bold())
                {
                    VStack (alignment: .leading) {
                        Text("Forecast vs. actual readings for past 6 hours")
                            .font(.footnote)
                            .foregroundColor(infoFontColor)
                        
                        SiteForecastActualCompareView(siteForecastViewModel: siteForecastViewModel,
                                                      stationReadingsHistoryViewModel: stationReadingsHistoryViewModel)
                    }
                }
                
                Section(header: Text("Daily Forecast")
                    .font(.subheadline)
                    .foregroundColor(sectionHeaderColor)
                    .bold())
                {
                    SiteDailyForecastView (
                        siteLat:                site.siteLat,
                        siteLon:                site.siteLon,
                        forecastNote:           site.forecastNote,
                        siteName:               site.siteName,
                        siteType:               site.siteType )
                }
                
                Section(header: Text("Detailed Forecast")
                    .font(.subheadline)
                    .foregroundColor(sectionHeaderColor)
                    .bold())
                {
                    SiteForecastView(siteForecastViewModel: siteForecastViewModel,
                                     id: site.id,
                                     siteName: site.siteName,
                                     siteType: site.siteType,
                                     siteLat: site.siteLat,
                                     siteLon: site.siteLon,
                                     forecastNote: site.forecastNote,
                                     siteWindDirection: site.windDirection)
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
                        .padding(.bottom, 0)
                    Text("Station coordinates:  \(site.siteLat), \(site.siteLon)")
                        .font(.caption)
                        .foregroundColor(infoFontColor)
                        .padding(.top, 0)
                }
                .listRowBackground(attributionSheetBackgroundColor)
            }
            Spacer() // Push the content to the top of the sheet
        }

        .onAppear {
            updateIsFavorite()
            isActive = true
            historyIsLoading = true
            startTimer()
            Task {
                await stationReadingsHistoryViewModel.GetReadingsHistoryData(
                    stationID: site.readingsStation,
                    readingsSource: site.readingsSource
                )
                historyIsLoading = false
            }
            Task {
                await siteForecastViewModel.fetchForecast(
                    id: site.id,
                    siteName: site.siteName,
                    latitude: site.siteLat,
                    longitude: site.siteLon,
                    siteType: site.siteType,
                    siteWindDirection: site.windDirection
                )
            }
        }
        
        .onReceive(stationReadingsHistoryViewModel.$readingsHistoryData) { newData in
            historyIsLoading = false
        }
        .onDisappear {
            isActive = false
        }
        .onChange(of: scenePhase) { oldValue, newValue in
            if newValue == .active {
                Task {
                    await stationReadingsHistoryViewModel.GetReadingsHistoryData(
                        stationID: site.readingsStation,
                        readingsSource: site.readingsSource
                    )
                    historyIsLoading = false
                }
            } else {
                isActive = false
            }
        }
        .onChange(of: userSettingsViewModel.userFavoriteSites) {
            updateIsFavorite()
        }
        .sheet(isPresented: $showWebView) {
            if let url = externalURL {
                SafariView(url: url)
                    .setSheetConfig()
            }
        }
    }

    // Used to open URL links as an in-app sheet using Safari
    func openLink(_ url: URL) { externalURL = url; showWebView = true }
    
    // Reload readings data when page is active for a time interval
    private func startTimer() {
        DispatchQueue.main.asyncAfter(deadline: .now() + readingsRefreshInterval) {
            if isActive {
                startTimer()
                Task {
                    await stationReadingsHistoryViewModel.GetReadingsHistoryData(
                        stationID: site.readingsStation,
                        readingsSource: site.readingsSource
                    )
                    historyIsLoading = false
                }
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

struct ReadingsHistoryBarChartView: View {
    var readingsHistoryData: ReadingsHistoryData
    let siteType: String

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
                        yEnd: .value("Wind Gust", windGust + 1)
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
        .frame(height: 100)
    }
}

// Data wrapper so all lines live in the same dataset for forecast/actual comparison chart
struct WindSeriesPoint: Identifiable {
    let id = UUID()
    let time: Date
    let value: Double?
    let series: String
}

struct SiteForecastActualCompareView: View {
    @ObservedObject var siteForecastViewModel: SiteForecastViewModel
    @ObservedObject var stationReadingsHistoryViewModel: StationReadingsHistoryViewModel

    var body: some View {
        VStack {
            if let chart = buildChart() {
                chart
            } else {
                Text("No data available")
                    .font(.subheadline)
                    .foregroundColor(infoFontColor)

            }
        }
        .onDisappear {
            // Clear old data when the view appears
            stationReadingsHistoryViewModel.pastReadingsData = PastReadingsData(
                timestamp: [],
                windSpeed: [],
                windGust: [],
                windDirection: []
            )
        }
    }

    private func buildChart() -> AnyView? {
        let actual = stationReadingsHistoryViewModel.pastReadingsData
        guard !actual.timestamp.isEmpty else {
            return nil
        }

        let forecast = siteForecastViewModel.forecastData?.pastHourly

        // Build typed points for Actuals
        // Build typed points for Actuals
        var points: [WindSeriesPoint] = []
        for (i, t) in actual.timestamp.enumerated() {
            if i < actual.windSpeed.count {
                points.append(WindSeriesPoint(time: t,
                                              value: actual.windSpeed[i],
                                              series: "Actual Wind"))
            }
            if i < actual.windGust.count {
                let gust = actual.windGust[i]
                points.append(WindSeriesPoint(time: t,
                                              value: gust == 0 ? nil : gust,
                                              series: "Actual Gust"))
            }
        }
        
        // X domain = actual min/max
        let actualMin = actual.timestamp.min() ?? Date()
        let actualMax = actual.timestamp.max() ?? Date()

        if let f = forecast {
            // Pairwise clipper: emits points that are guaranteed to form visible segments
            func clipSegments(times: [Date], values: [Double], series: String,
                              domainMin: Date, domainMax: Date) -> [WindSeriesPoint] {
                guard times.count == values.count, times.count >= 2 else { return [] }

                var out: [WindSeriesPoint] = []

                for i in 1 ..< times.count {
                    let t0 = times[i - 1]
                    let t1 = times[i]
                    var v0: Double? = values[i - 1] == 0 ? nil : values[i - 1]
                    var v1: Double? = values[i] == 0 ? nil : values[i]

                    // Skip degenerate segments
                    let dt = t1.timeIntervalSince(t0)
                    if dt == 0 { continue }

                    // If both ends are nil (no data), skip
                    if v0 == nil && v1 == nil { continue }

                    // Replace nils with neighbor for interpolation if possible
                    if v0 == nil { v0 = v1 }
                    if v1 == nil { v1 = v0 }

                    guard let v0u = v0, let v1u = v1 else { continue }

                    // If segment ends before domain, keep scanning
                    if t1 <= domainMin { continue }
                    if t0 >= domainMax { break }

                    func interp(at boundary: Date) -> Double {
                        let r = boundary.timeIntervalSince(t0) / dt
                        return v0u + r * (v1u - v0u)
                    }

                    if t0 < domainMin && t1 > domainMax {
                        out.append(WindSeriesPoint(time: domainMin, value: interp(at: domainMin), series: series))
                        out.append(WindSeriesPoint(time: domainMax, value: interp(at: domainMax), series: series))
                    } else if t0 < domainMin && t1 >= domainMin && t1 <= domainMax {
                        out.append(WindSeriesPoint(time: domainMin, value: interp(at: domainMin), series: series))
                        out.append(WindSeriesPoint(time: t1, value: v1u, series: series))
                    } else if t0 >= domainMin && t0 <= domainMax && t1 > domainMax {
                        out.append(WindSeriesPoint(time: t0, value: v0u, series: series))
                        out.append(WindSeriesPoint(time: domainMax, value: interp(at: domainMax), series: series))
                    } else if t0 >= domainMin && t1 <= domainMax {
                        out.append(WindSeriesPoint(time: t0, value: v0u, series: series))
                        out.append(WindSeriesPoint(time: t1, value: v1u, series: series))
                    }
                }

                // Dedup consecutive duplicates
                var dedup: [WindSeriesPoint] = []
                for p in out {
                    if let last = dedup.last, last.time == p.time && last.series == p.series {
                        dedup[dedup.count - 1] = p
                    } else {
                        dedup.append(p)
                    }
                }
                return dedup
            }
            
            // Clip forecast wind + gust and merge
            points.append(contentsOf: clipSegments(
                times: f.timestamp,
                values: f.windSpeed,
                series: "Forecast Wind",
                domainMin: actualMin,
                domainMax: actualMax
            ))
            points.append(contentsOf: clipSegments(
                times: f.timestamp,
                values: f.windGust,
                series: "Forecast Gust",
                domainMin: actualMin,
                domainMax: actualMax
            ))

            // Keep chronological order for all series
            points.sort { $0.time < $1.time }
        }

        // Shared Y domain with padding (actual + forecast)
        let yDomain: ClosedRange<Double>? = {
            var allValues: [Double] = []
            allValues.append(contentsOf: actual.windSpeed)
            allValues.append(contentsOf: actual.windGust)
            if let f = forecast {
                allValues.append(contentsOf: f.windSpeed)
                allValues.append(contentsOf: f.windGust)
            }
            guard let minV = allValues.min(), let maxV = allValues.max() else { return nil }
            let range = maxV - minV
            let padding = (range == 0) ? max(1, maxV) * 0.1 : range * 0.1
            return (minV - padding) ... (maxV + padding)
        }()

        let timeFormatter: DateFormatter = {
            let df = DateFormatter()
            df.dateFormat = "ha"
            return df
        }()

        // Small legend circle size
        let imageScale: CGFloat = 10

        // Build base Chart
        let baseChart = Chart {
            ForEach(points) { p in
                if let v = p.value {
                    LineMark(
                        x: .value("Time", p.time),
                        y: .value("Speed", v)
                    )
                    .foregroundStyle(by: .value("Series", p.series))
                    .interpolationMethod(.monotone)
                }
            }
        }
        .chartForegroundStyleScale([
            "Actual Wind": Color.white,
            "Actual Gust": Color.gray,
            "Forecast Wind": Color.blue,
            "Forecast Gust": Color.blue.opacity(0.5)
        ])
        .chartLegend(.hidden)   // using custom legend below
        .chartXScale(domain: actualMin ... actualMax)
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 6)) { value in
                if let date = value.as(Date.self) {
                    AxisValueLabel { Text(timeFormatter.string(from: date)) }
                }
            }
        }
        .chartYAxis { AxisMarks(position: .leading) }
        .frame(height: 200)

        var chartView: AnyView = AnyView(baseChart)
        if let domain = yDomain {
            chartView = AnyView(chartView.chartYScale(domain: domain))
        }

        // Custom legend
        let legend = HStack(spacing: 20) {
            Spacer()
            VStack(spacing: 6) {
                legendRow(color: .gray, title: "Actual gust", imageScale: imageScale)
                legendRow(color: .white, title: "Actual wind", imageScale: imageScale)
            }
            Spacer()
            VStack(spacing: 6) {
                legendRow(color: Color.blue.opacity(0.5), title: "Forecast gust", imageScale: imageScale)
                legendRow(color: .blue, title: "Forecast wind", imageScale: imageScale)
            }
            Spacer()
        }
        .padding(.top, 6)
        .font(.caption)

        let container = VStack(alignment: .leading, spacing: 4) {
            chartView
            legend
        }

        return AnyView(container)
    }
    
    private func legendRow(color: Color, title: String, imageScale: CGFloat) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "circle.fill")
                .resizable()
                .scaledToFit()
                .frame(width: imageScale, height: imageScale)
                .foregroundColor(color)
            Text(title)
                .foregroundColor(.white)
                .font(.caption2)
        }
    }
}
