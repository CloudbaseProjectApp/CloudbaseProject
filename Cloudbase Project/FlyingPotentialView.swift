import SwiftUI
import Combine
import Charts

enum FlyingPotentialRow: Identifiable {
    case header
    case sectionTitle(String)
    case site(SiteWithDisplayName)

    var id: String {
        switch self {
        case .header: return "header"
        case .sectionTitle(let title): return "section-\(title)"
        case .site(let site): return "site-\(site.id)"
        }
    }
}

struct FlyingPotentialView: View {
    @EnvironmentObject var liftParametersViewModel: LiftParametersViewModel
    @EnvironmentObject var sunriseSunsetViewModel: SunriseSunsetViewModel
    @EnvironmentObject var weatherCodesViewModel: WeatherCodeViewModel
    @EnvironmentObject var siteViewModel: SiteViewModel
    @EnvironmentObject var stationLatestReadingViewModel: StationLatestReadingViewModel
    @EnvironmentObject var userSettingsViewModel: UserSettingsViewModel
    @EnvironmentObject var siteDailyForecastViewModel: SiteDailyForecastViewModel
    @EnvironmentObject var siteForecastViewModel: SiteForecastViewModel
    
    @Environment(\.scenePhase) private var scenePhase
    
    @State private var selectedFlyingDetail: SelectedSiteDetail?
    @State private var forecastMap: [String: ForecastData] = [:] // keyed by siteName
    @State private var selectedSite: SiteSelection?
    @State private var favorites: [UserFavoriteSite] = []
    
    private var favoriteSites: [UserFavoriteSite] {
        userSettingsViewModel.userFavoriteSites
            .filter { $0.appRegion == RegionManager.shared.activeAppRegion }
            .sorted { $0.sortSequence < $1.sortSequence }
    }
    
    // Allows for limiting forecasts to reduce performance impact (network calls)
    var includeSites: Bool = true
    var includeFavorites: Bool = true
    
    private var combinedRows: [FlyingPotentialRow] {
        var result: [FlyingPotentialRow] = [.header]
        
        if includeFavorites {
            let favoriteSites: [SiteWithDisplayName] = favorites.compactMap { favorite in
                if let site = siteViewModel.sites.first(where: { $0.siteName == favorite.favoriteID }) {
                    return SiteWithDisplayName(site: site,
                                               displayName: favorite.favoriteName,
                                               customID: "favorite-\(site.id)")
                }
                return nil
            }
            
            if !favoriteSites.isEmpty {
                result.append(.sectionTitle("Favorites"))
                result.append(contentsOf: favoriteSites.map { .site($0) })
            }
        }

        if includeSites {
            let grouped = Dictionary(grouping: siteViewModel.sites.filter {
                $0.siteType == "Soaring" || $0.siteType == "Mountain"
            }) { $0.area }

            let sortedGrouped = siteViewModel.areaOrder.compactMap { area in
                grouped[area].map { (area, $0) }
            }

            for (area, sites) in sortedGrouped {
                let displaySites = sites.map {
                    SiteWithDisplayName(site: $0,
                                        displayName: $0.siteName,
                                        customID: "area-\($0.id)")
                }
                result.append(.sectionTitle(area))
                result.append(contentsOf: displaySites.map { .site($0) })
            }
        }

        return result
    }
    
    var body: some View {
        VStack {
            Text("Tap on a site for readings history and forecast")
                .font(.caption)
                .foregroundColor(infoFontColor)
                .padding(.top, 8)
            Text("Tap on a circle for details on the paragliding potential")
                .font(.caption)
                .foregroundColor(infoFontColor)
                .padding(.top, 8)

            List {
                SiteGridSectionUnified(
                    rows: combinedRows,
                    forecastMap: forecastMap,
                    onSelect: openSiteDetail,
                    onDetailTap: { selectedFlyingDetail = $0 }
                )

                // Attribution
                VStack(alignment: .leading) {
                    Text("Forecast data provided by Open-meteo")
                        .font(.caption)
                        .foregroundColor(infoFontColor)
                    Text("https://open-meteo.com")
                        .font(.caption)
                        .foregroundColor(infoFontColor)
                }
                .listRowBackground(attributionBackgroundColor)
                .padding(.top, 8)
            }
        }
        
        .onAppear {
            favorites = favoriteSites
            
            let allSites: [Site] = {
                var result: [Site] = []

                if includeFavorites {
                    let favoriteList = favoriteSites.compactMap {
                        if let (site, _) = siteFromFavorite($0) { return site }
                        return nil
                    }
                    result += favoriteList
                }

                if includeSites {
                    let siteList = siteViewModel.sites.filter {
                        $0.siteType == "Soaring" || $0.siteType == "Mountain"
                    }
                    result += siteList
                }

                return result
            }()

            for site in allSites {
                siteForecastViewModel.fetchForecast(id:                 site.id,
                                                    siteName:           site.siteName,
                                                    latitude:           site.siteLat,
                                                    longitude:          site.siteLon,
                                                    siteType:           site.siteType,
                                                    siteWindDirection:  site.windDirection) { forecast in

                    DispatchQueue.main.async {
                        if let forecast = forecast {
                            forecastMap[site.siteName] = forecast
                        }
                    }
 
                }
            }
        }
        
        .sheet(item: $selectedSite) { selection in
            SiteDetailView(site: selection.site, favoriteName: selection.favoriteName)
                .setSheetConfig()
        }
        
        .sheet(item: $selectedFlyingDetail) { detail in
            FlyingPotentialDetailView(
               site: detail.site,
               favoriteName: detail.displayName,
               forecastData: forecastMap[detail.site.siteName]!,
               forecastIndex: detail.forecastIndex
            )
            .setSheetConfig()
        }
        
        // Get external changes (e.g., adding/removing favorites from site detail sheet)
        .onChange(of: userSettingsViewModel.userFavoriteSites) { _, newValue in
            favorites = newValue
        }
    }
    
    private func openSiteDetail(_ site: Site) {
        let matchedFavorite = favorites.first {
            ($0.favoriteType == "site" && $0.favoriteID == site.siteName) ||
            ($0.favoriteType == "station" && $0.stationID == site.readingsStation)
        }

        let favoriteName = matchedFavorite?.favoriteName ?? site.siteName
        selectedSite = SiteSelection(site: site, favoriteName: favoriteName)
    }
    
    private func siteFromFavorite(_ fav: UserFavoriteSite) -> (Site, String)? {
        let display = fav.favoriteName.isEmpty ? fav.favoriteID : fav.favoriteName

        switch fav.favoriteType {
        case "site":
            if let match = siteViewModel.sites.first(where: { $0.siteName == fav.favoriteID }) {
                return (match, display)
            } else {
                return nil
            }
        case "station":
            let windDirection = SiteWindDirection( N:  "", NE: "", E:  "", SE: "", S:  "", SW: "", W:  "", NW: "" )
            
            return (Site(
                id:                 "favorite-\(fav.stationID)",
                area:               "Favorites",
                siteName:           fav.favoriteID,
                readingsNote:       "",
                forecastNote:       "",
                siteType:           "station",
                readingsAlt:        fav.readingsAlt,
                readingsSource:     fav.readingsSource,
                readingsStation:    fav.stationID,
                pressureZoneReadingTime: "",
                siteLat:            fav.siteLat,
                siteLon:            fav.siteLon,
                sheetRow:           0,
                windDirection:      windDirection
            ), display)
        default:
            return nil
        }
    }
}

struct SiteWithDisplayName: Identifiable, Equatable {
    let site: Site
    let displayName: String
    let customID: String
    var id: String { customID }
}

struct SelectedSiteDetail: Identifiable, Equatable {
    let site: Site
    let displayName: String
    let forecastIndex: Int
    var id: String { "\(site.siteName)-\(forecastIndex)" }
}

struct SiteGridSectionUnified: View {
    let rows: [FlyingPotentialRow]
    let forecastMap: [String: ForecastData]
    let onSelect: (Site) -> Void
    let onDetailTap: (SelectedSiteDetail) -> Void
    
    @State private var sectionTitleOffsets: [(title: String, yOffset: CGFloat)] = []

    private let dataWidth: CGFloat = 44
    private let rowHeight: CGFloat = 32
    private let headerRowHeight: CGFloat = 48

    var body: some View {
        let anyForecast = rows.compactMap {
            if case let .site(siteRow) = $0 {
                return forecastMap[siteRow.site.siteName]
            }
            return nil
        }.first

        if let anyForecast {
            let hourly = anyForecast.hourly
            let dateTimeCount = hourly.dateTime?.count ?? 0

            ZStack(alignment: .topLeading) {
                HStack(alignment: .top, spacing: 0) {
                    // Left column
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(rows) { row in
                            switch row {
                            case .header:
                                Text(" ")
                                    .font(.caption)
                                    .frame(width: 100, height: headerRowHeight)

                            case .sectionTitle(let title):
                                potentialChartBackgroundColor
                                    .frame(width: 100, height: rowHeight)
                                    .overlay(
                                        GeometryReader { geo in
                                            Color.clear
                                                .onAppear {
                                                    let offset = geo.frame(in: .named("grid")).origin.y
                                                    sectionTitleOffsets.append((title, offset))
                                                }
                                        }
                                    )

                            case .site(let siteRow):
                                Text(siteRow.displayName)
                                    .font(.caption)
                                    .foregroundColor(rowHeaderColor)
                                    .frame(width: 100, height: rowHeight, alignment: .leading)
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        onSelect(siteRow.site)
                                    }
                            }
                        }
                    }

                    // Right column
                    ScrollView(.horizontal, showsIndicators: true) {
                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(rows) { row in
                                switch row {
                                case .header:
                                    HStack(spacing: 0) {
                                        ForEach(0..<dateTimeCount, id: \.self) { i in
                                            let isNew = hourly.newDateFlag?[i] ?? true
                                            let day = hourly.formattedDay?[i] ?? ""
                                            let date = hourly.formattedDate?[i] ?? ""
                                            let time = hourly.formattedTime?[i] ?? ""
                                            
                                            ZStack(alignment: .leading) {
                                                if i > 0 {
                                                    dateDivider(isNew: hourly.newDateFlag?[i] == true)
                                                        .frame(height: headerRowHeight)
                                                        .alignmentGuide(.leading) { _ in 0 }
                                                }

                                                VStack(spacing: 0) {
                                                    Text(day)
                                                        .font(.caption)
                                                        .foregroundColor(isNew ? .primary : repeatDateTimeColor)
                                                    Text(date)
                                                        .font(.caption)
                                                        .foregroundColor(isNew ? .primary : repeatDateTimeColor)
                                                    Text(time)
                                                        .font(.caption)
                                                        .foregroundColor(.primary)
                                                }
                                                .frame(width: dataWidth, height: headerRowHeight)
                                            }
                                            .frame(width: dataWidth, height: headerRowHeight)
                                        }
                                    }
                                    .background(potentialChartBackgroundColor)
                                    .cornerRadius(10)
                                    .frame(height: headerRowHeight)

                                case .sectionTitle:
                                    HStack(spacing: 0) {
                                        ForEach(0..<dateTimeCount, id: \.self) { i in
                                            ZStack(alignment: .leading) {
                                                if i > 0 {
                                                    dateDivider(isNew: hourly.newDateFlag?[i] == true)
                                                        .frame(height: rowHeight)
                                                        .alignmentGuide(.leading) { _ in 0 }
                                                }

                                                // Empty cell, just taking up space
                                                Rectangle()
                                                    .fill(Color.clear)
                                                    .frame(width: dataWidth, height: rowHeight)
                                            }
                                            .frame(width: dataWidth, height: rowHeight)
                                        }
                                    }
                                    .background(potentialChartBackgroundColor)
                                    
                                case .site(let siteRow):
                                    if let forecast = forecastMap[siteRow.site.siteName],
                                       let values = forecast.hourly.combinedColorValue {
                                        HStack(spacing: 0) {
                                            ForEach(0..<dateTimeCount, id: \.self) { i in
                                                if i < values.count {
                                                    let color = FlyingPotentialColor.color(for: values[i])
                                                    let size = FlyingPotentialImageSize(color)
                                                    
                                                    ZStack(alignment: .leading) {
                                                        if i > 0 {
                                                            dateDivider(isNew: hourly.newDateFlag?[i] == true)
                                                                .frame(height: rowHeight)
                                                                .alignmentGuide(.leading) { _ in 0 }
                                                        }

                                                        Image(systemName: flyingPotentialImage)
                                                            .resizable()
                                                            .scaledToFit()
                                                            .frame(width: size, height: size)
                                                            .foregroundColor(Color(color))
                                                            .frame(width: dataWidth, height: rowHeight, alignment: .center)
                                                            .contentShape(Rectangle())
                                                            .onTapGesture {
                                                                let detail = SelectedSiteDetail(
                                                                    site: siteRow.site,
                                                                    displayName: siteRow.displayName,
                                                                    forecastIndex: i
                                                                )
                                                                onDetailTap(detail)
                                                            }
                                                    }
                                                    .frame(width: dataWidth, height: rowHeight)
                                                    
                                                } else {
                                                    Rectangle()
                                                        .fill(Color.gray.opacity(0.2))
                                                        .frame(width: dataWidth, height: rowHeight)
                                                }
                                            }
                                        }
                                        .background(potentialChartBackgroundColor)
                                        .cornerRadius(10)
                                        .frame(height: rowHeight)
                                    } else {
                                        HStack(spacing: 2) {
                                            ForEach(0..<dateTimeCount, id: \.self) { _ in
                                                Text("-")
                                                    .frame(width: dataWidth, height: rowHeight)
                                                    .font(.caption)
                                                    .overlay(
                                                        Divider()
                                                            .frame(width: dateChangeDividerSize)
                                                            .padding(.vertical, 6),
                                                        alignment: .trailing
                                                    )
                                            }
                                        }
                                        .background(potentialChartBackgroundColor)
                                        .cornerRadius(10)
                                        .frame(height: rowHeight)
                                    }
                                }
                            }
                        }
                    }
                }

                // Overlay floating section titles on the left
                ForEach(sectionTitleOffsets, id: \.title) { item in
                    Text(item.title.uppercased())
                        .font(.subheadline)
                        .bold()
                        .foregroundColor(sectionHeaderColor)
                        .padding(.leading, 4)
                        .background(potentialChartBackgroundColor)
                        .fixedSize() // <-- This ensures the text takes only as much space as needed
                        .frame(height: rowHeight - 4, alignment: .leading)
                        .offset(x: 0, y: item.yOffset)
                }
            }
            .coordinateSpace(name: "grid") // allows GeometryReader to report y-offsets
            .padding(.vertical, 4)

        } else {
            Text("No forecast data available.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

@ViewBuilder
func dateDivider(isNew: Bool) -> some View {
    ZStack(alignment: .leading) {
        Rectangle()
            .fill(getDividerColor(isNew))
            .frame(width: dateChangeDividerSize)
    }
}
