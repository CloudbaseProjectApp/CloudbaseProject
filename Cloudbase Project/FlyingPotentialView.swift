import SwiftUI
import Combine
import Charts

struct FlyingPotentialView: View {
    @EnvironmentObject var liftParametersViewModel: LiftParametersViewModel
    @EnvironmentObject var sunriseSunsetViewModel: SunriseSunsetViewModel
    @EnvironmentObject var weatherCodesViewModel: WeatherCodeViewModel
    @EnvironmentObject var siteViewModel: SiteViewModel
    @EnvironmentObject var stationLatestReadingViewModel: StationLatestReadingViewModel
    @EnvironmentObject var userSettingsViewModel: UserSettingsViewModel
    @StateObject private var siteForecastViewModel: SiteForecastViewModel
    
    @State private var selectedFlyingDetail: SelectedSiteDetail?

    init(
        liftVM: LiftParametersViewModel,
        sunriseVM: SunriseSunsetViewModel,
        weatherVM: WeatherCodeViewModel
    ) {
        _siteForecastViewModel = StateObject(wrappedValue:
            SiteForecastViewModel(
                liftParametersViewModel: liftVM,
                sunriseSunsetViewModel: sunriseVM,
                weatherCodesViewModel: weatherVM
            )
        )
    }
    
    @Environment(\.scenePhase) private var scenePhase
    
    @State private var forecastMap: [String: ForecastData] = [:] // keyed by siteName
    @State private var selectedSite: SiteSelection?
    @State private var favorites: [UserFavoriteSite] = []
    
    private var favoriteSites: [UserFavoriteSite] {
        userSettingsViewModel.userFavoriteSites
            .filter { $0.appRegion == RegionManager.shared.activeAppRegion }
            .sorted { $0.sortSequence < $1.sortSequence }
    }
    
    // Currently only including favorites due to "too many concurrent request" errors
    // would need to revise logic for forecast calls to handle more sites
    var includeSites: Bool = true
    var includeFavorites: Bool = true
    
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
                if includeFavorites {
                    FavoritesPotentialSection(
                        onDetailTap: { detail in selectedFlyingDetail = detail }, favorites: $favorites,
                        siteViewModel: siteViewModel,
                        onSelect: openSiteDetail,
                        forecastMap: forecastMap,
                        siteFromFavorite: siteFromFavorite
                    )
                }

                if includeSites {
                    // Group sites by area, filtered for Soaring/Mountain
                    let groupedSites = Dictionary(grouping: siteViewModel.sites.filter {
                        $0.siteType == "Soaring" || $0.siteType == "Mountain"
                    }) { $0.area }
                    
                    // Sort areas by your predefined order and only include non-empty groups
                    let sortedGroupedSites: [(String, [Site])] = siteViewModel.areaOrder.compactMap { areaName in
                        guard let sitesInArea = groupedSites[areaName], !sitesInArea.isEmpty else {
                            return nil
                        }
                        return (areaName, sitesInArea)
                    }
                    
                    ForEach(sortedGroupedSites, id: \.0) { (area, sites) in
                        let displaySites = sites.map { SiteWithDisplayName(site: $0, displayName: $0.siteName) }
                        SiteGridSection(title:          area,
                                        sites:          displaySites,
                                        onSelect:       openSiteDetail,
                                        onDetailTap:    { detail in selectedFlyingDetail = detail },
                                        forecastMap:    forecastMap)
                    }
                }

                // Attribution footer
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
                siteForecastViewModel.fetchForecast(siteName:           site.siteName,
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
        }
        
        .sheet(item: $selectedFlyingDetail) { detail in
            FlyingPotentialDetailView(
               site: detail.site,
               favoriteName: detail.displayName,
               forecastData: forecastMap[detail.site.siteName]!,
               forecastIndex: detail.forecastIndex
            )
            .interactiveDismissDisabled(true)
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

        let favoriteName = matchedFavorite?.favoriteName ?? ""
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

struct FavoritesPotentialSection: View {
    let onDetailTap: (SelectedSiteDetail) -> Void
    @Binding var favorites: [UserFavoriteSite]
    let siteViewModel: SiteViewModel
    let onSelect: (Site) -> Void
    let forecastMap: [String: ForecastData]
    let siteFromFavorite: (UserFavoriteSite) -> (Site, String)?

    private let columns: [GridItem] = [
        GridItem(.flexible(), alignment: .leading),
        GridItem(.flexible(), alignment: .trailing)
    ]

    var body: some View {

        let filteredFavorites: [SiteWithDisplayName] = favorites.compactMap { favorite in
            guard let (site, displayName) = siteFromFavorite(favorite),
                  site.siteType == "Soaring" || site.siteType == "Mountain" else {
                return nil
            }
            return SiteWithDisplayName(site: site, displayName: displayName)
        }
        
        if !filteredFavorites.isEmpty {
            SiteGridSection(title:          "Favorites",
                            sites:          filteredFavorites,
                            onSelect:       onSelect,
                            onDetailTap:    onDetailTap,
                            forecastMap:    forecastMap)
            
        } else {
            Section(
                header: Text("Favorites")
                    .font(.subheadline)
                    .foregroundColor(sectionHeaderColor)
                    .bold()
            ) {
                VStack (alignment: .leading) {
                    Text("No favorites found; add favorites on Sites page")
                        .font(.subheadline)
                        .padding(.top, 8)
                    
                    Text("Note: Only Mountain/Soaring sites are displayed")
                        .font(.subheadline)
                        .foregroundColor(infoFontColor)
                        .padding(.vertical, 8)
                }
            }
        }
 
    }

}

struct SiteWithDisplayName: Identifiable, Equatable {
    let site: Site
    let displayName: String
    var id: String { site.siteName }
}

struct SelectedSiteDetail: Identifiable, Equatable {
    let site: Site
    let displayName: String
    let forecastIndex: Int
    var id: String { "\(site.siteName)-\(forecastIndex)" }
}

struct SiteGridSection: View {
    let title: String
    let sites: [SiteWithDisplayName]
    let onSelect: (Site) -> Void
    let onDetailTap: (SelectedSiteDetail) -> Void
    let forecastMap: [String: ForecastData]
    
    private let columns: [GridItem] = [
        GridItem(.flexible(), alignment: .leading),
        GridItem(.flexible(), alignment: .trailing)
    ]
    
    var body: some View {
        Section(
            header: Text(title)
                .font(.subheadline)
                .foregroundColor(sectionHeaderColor)
                .bold()
        ) {
            if let anyForecast = sites.compactMap({ forecastMap[$0.site.siteName] }).first {
                let hourly = anyForecast.hourly
                if let dateTimeCount = hourly.dateTime?.count {
                    
                    let dataWidth: CGFloat = 44
                    let rowHeight: CGFloat = 32
                    
                    HStack(alignment: .top, spacing: 0) {
                        // Non-scrolling first column (site names)
                        VStack(alignment: .leading, spacing: 0) {
                            // Header row that visually matches the forecast header (2 stacked labels)
                            VStack(spacing: 0) {
                                Text(" ")
                                    .font(.caption)
                                    .frame(width: 100, height: rowHeight / 2, alignment: .leading)
                                    .padding(.top, 8)
                                Text(" ")
                                    .font(.caption)
                                    .frame(width: 100, height: rowHeight / 2, alignment: .leading)
                                Text(" ")
                                    .font(.caption)
                                    .frame(width: 100, height: rowHeight / 2, alignment: .leading)
                                    .padding(.bottom, 4)
                            }
                            
                            // Data rows
                            ForEach(sites.indices, id: \.self) { index in
                                let siteInfo = sites[index]
                                Text(siteInfo.displayName != "" ? siteInfo.displayName : siteInfo.site.siteName)
                                    .font(.subheadline)
                                    .foregroundColor(rowHeaderColor)
                                    .frame(width: 100, height: rowHeight, alignment: .leading)
                                    .padding(1)
                                    .contentShape(Rectangle()) // Makes entire area tappable
                                    .onTapGesture {
                                        onSelect(siteInfo.site)
                                    }
                            }
                        }
                        .padding(4)
                        
                        // Scrollable forecast grid (header + rows)
                        ScrollView(.horizontal, showsIndicators: true) {
                            VStack(alignment: .leading, spacing: 0) {
                                // Header row
                                HStack(spacing: 4) {
                                    ForEach(hourly.dateTime?.indices ?? 0..<0, id: \.self) { i in
                                        VStack {
                                            if hourly.newDateFlag?[i] ?? true {
                                                Text(hourly.formattedDay?[i] ?? "")
                                                    .font(.caption)
                                                    .frame(width: dataWidth)
                                                    .padding(.top, 8)
                                                    .overlay(Divider().frame(width: dateChangeDividerSize, height: headingHeight)
                                                                .background(getDividerColor(hourly.newDateFlag?[i] ?? true)), alignment: .leading)
                                                
                                                Text(hourly.formattedDate?[i] ?? "")
                                                    .font(.caption)
                                                    .frame(width: dataWidth)
                                                    .overlay(Divider().frame(width: dateChangeDividerSize, height: headingHeight)
                                                                .background(getDividerColor(hourly.newDateFlag?[i] ?? true)), alignment: .leading)
                                            } else {
                                                Text(hourly.formattedDay?[i] ?? "")
                                                    .font(.caption)
                                                    .foregroundColor(repeatDateTimeColor)
                                                    .frame(width: dataWidth)
                                                    .padding(.top, 8)
                                                    .overlay(Divider().frame(width: dateChangeDividerSize, height: headingHeight)
                                                                .background(getDividerColor(hourly.newDateFlag?[i] ?? true)), alignment: .leading)
                                                
                                                Text(hourly.formattedDate?[i] ?? "")
                                                    .font(.caption)
                                                    .foregroundColor(repeatDateTimeColor)
                                                    .frame(width: dataWidth)
                                                    .overlay(Divider().frame(width: dateChangeDividerSize, height: headingHeight)
                                                                .background(getDividerColor(hourly.newDateFlag?[i] ?? true)), alignment: .leading)
                                            }
                                            
                                            Text(hourly.formattedTime?[i] ?? "")
                                                .font(.caption)
                                                .frame(width: dataWidth)
                                                .padding(.bottom, 4)
                                                .overlay(Divider().frame(width: dateChangeDividerSize, height: headingHeight)
                                                            .background(getDividerColor(hourly.newDateFlag?[i] ?? true)), alignment: .leading)
                                        }
                                    }
                                }
                                
                                // Forecast rows
                                ForEach(sites.indices, id: \.self) { index in
                                    let siteInfo = sites[index]
                                    let site = siteInfo.site
                                    
                                    if let forecast = forecastMap[site.siteName],
                                       let combinedColorValue = forecast.hourly.combinedColorValue {
                                        
                                        HStack(spacing: 4) {
                                            ForEach(0..<dateTimeCount, id: \.self) { i in
                                                if i < combinedColorValue.count {
                                                    let displayColor = FlyingPotentialColor.color(for: combinedColorValue[i])
                                                    let displaySize = FlyingPotentialImageSize(displayColor)
                                                    
                                                    Image(systemName: flyingPotentialImage)
                                                        .resizable()
                                                        .scaledToFit()
                                                        .font(.system(size: displaySize))
                                                        .frame(width: displaySize, height: displaySize)
                                                        .foregroundColor(Color(displayColor))
                                                        .padding(8)
                                                        .frame(width: dataWidth, height: rowHeight)
                                                        .contentShape(Rectangle())
                                                        .onTapGesture {
                                                            let detail = SelectedSiteDetail(
                                                                site:           site,
                                                                displayName:    siteInfo.displayName,
                                                                forecastIndex:  i)
                                                            onDetailTap(detail)
                                                        }
                                                } else {
                                                    Rectangle()
                                                        .fill(Color.gray.opacity(0.2))
                                                        .frame(width: dataWidth, height: rowHeight)
                                                }
                                            }
                                        }
                                        .padding(1)
                                    } else {
                                        // fallback if forecast missing
                                        HStack(spacing: 4) {
                                            ForEach(0..<dateTimeCount, id: \.self) { _ in
                                                Text("-")
                                                    .font(.caption)
                                                    .frame(width: dataWidth, height: rowHeight)
                                            }
                                        }
                                        .padding(1)
                                    }
                                }
                            }
                            .padding(4)
                            .background(potentialChartBackgroundColor)
                            .cornerRadius(10)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }
}
