import SwiftUI
import Combine

struct SiteSelection: Identifiable, Equatable {
    var id = UUID()
    var site: Site
    var favoriteName: String
}

struct SiteView: View {
    @EnvironmentObject var liftParametersViewModel: LiftParametersViewModel
    @EnvironmentObject var sunriseSunsetViewModel: SunriseSunsetViewModel
    @EnvironmentObject var weatherCodesViewModel: WeatherCodeViewModel
    @EnvironmentObject var siteViewModel: SiteViewModel
    @EnvironmentObject var stationLatestReadingViewModel: StationLatestReadingViewModel
    @EnvironmentObject var userSettingsViewModel: UserSettingsViewModel
    @EnvironmentObject var siteDailyForecastViewModel: SiteDailyForecastViewModel
    @EnvironmentObject var siteForecastViewModel: SiteForecastViewModel
    
    @Environment(\.scenePhase) private var scenePhase
    @State private var selectedSite: SiteSelection?
    @State private var isActive = false
    @State private var isEditingFavorites = false
    @State private var editableFavorites: [UserFavoriteSite] = []
    
    private var favoriteSites: [UserFavoriteSite] {
        userSettingsViewModel.userFavoriteSites
            .filter { $0.appRegion == RegionManager.shared.activeAppRegion }
            .sorted { $0.sortSequence < $1.sortSequence }
    }
    
    var body: some View {
        VStack {
            Text("Tap on a site for readings history and forecast")
                .font(.caption)
                .foregroundColor(infoFontColor)
                .padding(.top, 8)
            
            List {
                // Show any favorites first
                if !editableFavorites.isEmpty || isEditingFavorites {
                    FavoritesSection(
                        favorites: $editableFavorites,
                        isEditingFavorites: $isEditingFavorites,
                        siteViewModel: siteViewModel,
                        onSelect: openSiteDetail
                    )
                }
                
                // Show standard sites
                let groupedSites = Dictionary(grouping: siteViewModel.sites) { $0.area }
                let sortedGroupedSites: [(String, [Site])] = siteViewModel.areaOrder.compactMap { areaName in
                    guard let sitesInArea = groupedSites[areaName] else { return nil }
                    return (areaName, sitesInArea)
                }
                ForEach(sortedGroupedSites, id: \.0) { pair in
                    let area = pair.0
                    let areaSites = pair.1

                    Section(header:
                        Text(area)
                            .font(.subheadline)
                            .foregroundColor(sectionHeaderColor)
                            .bold()
                    ) {
                        ForEach(areaSites) { site in
                            SiteRow(site: site, onSelect: openSiteDetail)
                        }
                    }
                }
                VStack (alignment: .leading) {
                    Text("Readings data aggregated by Synoptic")
                        .font(.caption)
                        .foregroundColor(infoFontColor)
                    Text("https://synopticdata.com")
                        .font(.caption)
                        .foregroundColor(infoFontColor)
                }
                .listRowBackground(attributionBackgroundColor)
            }
            .environment(\.editMode, .constant(isEditingFavorites ? .active : .inactive))
        }
        
        .onAppear {
            isActive = true
            editableFavorites = favoriteSites
            startTimer()
            guard !siteViewModel.sites.isEmpty else { return }
            stationLatestReadingViewModel.getLatestReadingsData(sitesOnly: true) {}
        }
        
        .onDisappear {
            isActive = false
            
            // Save reordered favorites back to user settings
            persistFavoriteReordering()
        }
        
        .sheet(
            item: $selectedSite,
            onDismiss: {
                guard !siteViewModel.sites.isEmpty else { return }
                // Skipping getLatestReadingsData - sites not yet loaded
                stationLatestReadingViewModel.getLatestReadingsData(sitesOnly: true) {}
            }
        ) { selection in
            SiteDetailView(site: selection.site, favoriteName: selection.favoriteName)
                .setSheetConfig()
        }
        
        .onChange(of: scenePhase) { oldValue, newValue in
            if newValue == .active {
                isActive = true
                startTimer()
                guard !siteViewModel.sites.isEmpty else {
                    // Skipping getLatestReadingsData - sites not yet loaded
                    return
                }
                stationLatestReadingViewModel.getLatestReadingsData(sitesOnly: true) {}
            } else {
                isActive = false
            }
            
        }
        
        .onChange(of: isEditingFavorites) { _, newValue in
            if newValue == false {
                persistFavoriteReordering()
            }
        }
        
        // Get external changes (e.g., adding/removing favorites from site detail sheet)
        .onChange(of: userSettingsViewModel.userFavoriteSites) { oldValue, newValue in
            editableFavorites = favoriteSites
        }
        
        .onChange(of: RegionManager.shared.activeAppRegion) { _, _ in
            editableFavorites = favoriteSites
        }
    }
    
    private func persistFavoriteReordering() {
        let currentRegion = RegionManager.shared.activeAppRegion
        var updatedFavorites = userSettingsViewModel.userFavoriteSites.filter { $0.appRegion != currentRegion }
        updatedFavorites.append(contentsOf: editableFavorites)
        userSettingsViewModel.userFavoriteSites = updatedFavorites
        userSettingsViewModel.saveToStorage()
    }
    
    private func openSiteDetail(_ site: Site) {
        let matchedFavorite = editableFavorites.first {
            ($0.favoriteType == "site" && $0.favoriteID == site.siteName) ||
            ($0.favoriteType == "station" && $0.stationID == site.readingsStation)
        }

        let favoriteName = matchedFavorite?.favoriteName ?? site.siteName
        selectedSite = SiteSelection(site: site, favoriteName: favoriteName)
    }
    
    private func startTimer() {
        DispatchQueue.main.asyncAfter(deadline: .now() + readingsRefreshInterval) {
            if isActive {
                startTimer()
                guard !siteViewModel.sites.isEmpty else {
                    // Skipping getLatestReadingsData - sites not yet loaded
                    return
                }
                stationLatestReadingViewModel.getLatestReadingsData(sitesOnly: true) {}
            }
        }
    }
}

struct FavoritesSection: View {
    @Binding var favorites: [UserFavoriteSite]
    @Binding var isEditingFavorites: Bool
    @State private var renamingFavoriteID: String?

    let siteViewModel: SiteViewModel
    let onSelect: (Site) -> Void

    var body: some View {
        Section(
            header:
                HStack {
                    Text("Favorites")
                        .font(.subheadline)
                        .foregroundColor(sectionHeaderColor)
                        .bold()
                    Spacer()
                    Button {
                        isEditingFavorites.toggle()
                    } label: {
                        if isEditingFavorites {
                            Image(systemName: checkmarkImage)
                                .imageScale(.medium)
                                .foregroundStyle(toolbarActiveImageColor)
                        } else {
                            Image(systemName: sortImage)
                                .imageScale(.medium)
                                .foregroundStyle(toolbarImageColor)
                        }
                    }
                    .buttonStyle(BorderlessButtonStyle())
                }
        ) {
            ForEach(favorites, id: \.id) { favorite in
                let binding = bindingForFavorite(favorite)
                if let (site, displayName) = siteFromFavorite(favorite) {
                    FavoriteRow(
                        favorite: binding,
                        site: site,
                        displayName: displayName,
                        onSelect: onSelect,
                        renamingFavoriteID: $renamingFavoriteID,
                        myID: favorite.id
                    )
                } else {
                    EmptyView()
                }
            }
            .onMove { from, to in
                withTransaction(Transaction(animation: nil)) {
                    moveFavorite(from: from, to: to)
                }
            }
        }
    }

    private func siteFromFavorite(_ fav: UserFavoriteSite) -> (Site, String)? {
        let display = fav.favoriteName.isEmpty ? fav.favoriteID : fav.favoriteName
        switch fav.favoriteType {
        case "site":
            if let match = siteViewModel.sites.first(where: { $0.siteName == fav.favoriteID }) {
                return (match, display)
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
        return nil
    }

    private func bindingForFavorite(_ favorite: UserFavoriteSite) -> Binding<UserFavoriteSite> {
        guard let idx = favorites.firstIndex(where: { $0.id == favorite.id }) else {
            fatalError("Favorite not found")
        }
        return $favorites[idx]
    }

    private func moveFavorite(from source: IndexSet, to destination: Int) {
        // 1. Reorder the array in-place:
        favorites.move(fromOffsets: source, toOffset: destination)
        
        // 2. Update sortSequence to match the new order:
        for (newIndex, _) in favorites.enumerated() {
            favorites[newIndex].sortSequence = newIndex
        }
    }
}

struct SiteRow: View {
    @EnvironmentObject var stationLatestReadingViewModel: StationLatestReadingViewModel
    var site: Site
    var displayName: String? = nil
    var onSelect: (Site) -> Void

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text(displayName ?? site.siteName) // Use (favorite) display name if present
                    .font(.subheadline)
                    .foregroundColor(rowHeaderColor)
                if site.readingsAlt != "" {
                    Text(formatAltitude(site.readingsAlt))
                        .font(.caption)
                        .foregroundColor(infoFontColor)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                }
                Spacer()
                
                if stationLatestReadingViewModel.isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .scaleEffect(0.75)
                        .frame(width: 20, height: 20)
                }
                else if let latestReading = stationLatestReadingViewModel.latestSiteReadings.first (where: { $0.stationID == site.readingsStation }) {
                    if let windTime = latestReading.windTime {
                        // Split keeps hh:mm and strips the trailing "  %p" the JSON parser is creating
                        let windTimeParts = windTime.split(separator: " ", maxSplits: 1)
                        let windTimeText = windTimeParts.first.map(String.init) ?? windTime
                        Text(windTimeText)
                            .font(.caption)
                            .foregroundColor(infoFontColor)
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                    }
                    
                    if let windSpeed = latestReading.windSpeed {
                        if windSpeed == 0 {
                            Text("calm")
                                .font(.subheadline)
                                .lineLimit(1)
                                .fixedSize(horizontal: true, vertical: false)
                        } else {
                            Text(String(Int(windSpeed.rounded())))
                                .font(.subheadline)
                                .foregroundColor(windSpeedColor(windSpeed: Int(windSpeed.rounded()), siteType: site.siteType))
                                .lineLimit(1)
                                .fixedSize(horizontal: true, vertical: false)
                        }
                    } else {
                        Text ("Station down")
                            .font(.caption)
                            .foregroundColor(infoFontColor)
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                    }
                    
                    if let windGust = latestReading.windGust {
                        if windGust > 0 {
                            HStack {
                                Text("g")
                                    .font(.subheadline)
                                    .foregroundColor(infoFontColor)
                                    .lineLimit(1)
                                    .fixedSize(horizontal: true, vertical: false)
                                Text(String(Int(windGust.rounded())))
                                    .font(.subheadline)
                                    .foregroundColor(windSpeedColor(windSpeed: Int(windGust.rounded()), siteType: site.siteType))
                                    .lineLimit(1)
                                    .fixedSize(horizontal: true, vertical: false)
                            }
                        }
                    }
                    
                    if let windDirection = latestReading.windDirection {
                        Image(systemName: windArrow)
                            .rotationEffect(.degrees(windDirection - 180))
                            .font(.footnote)
                    }
                    
                } else {
                    Text ("Station down")
                        .font(.caption)
                        .foregroundColor(infoFontColor)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                }
            }
            .contentShape(Rectangle()) // Makes entire area tappable
            .onTapGesture {
                onSelect(site)
            }
        }
    }
}

struct FavoriteRow: View {
    @EnvironmentObject var userSettingsViewModel: UserSettingsViewModel
    @Binding var favorite: UserFavoriteSite
    var site: Site?
    var displayName: String?
    var onSelect: (Site) -> Void

    @Binding var renamingFavoriteID: String?
    let myID: String

    @FocusState private var isTextFieldFocused: Bool
    private var isRenaming: Bool { renamingFavoriteID == myID }

    var body: some View {
        Group {
            if isRenaming {
                HStack {
                    TextField("Favorite Name", text: $favorite.favoriteName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .font(.subheadline)
                        .focused($isTextFieldFocused)
                        .onSubmit { endRenaming() }
                    Spacer()
                }
                .padding(.vertical, 4)
            } else {
                if let site = site {
                    SiteRow(site: site, displayName: displayName, onSelect: onSelect)
                        .contextMenu {
                            Button("Rename") {
                                renamingFavoriteID = myID
                            }
                            .font(.caption)
                            .buttonStyle(BorderlessButtonStyle())
                        }
                        .onLongPressGesture {
                            renamingFavoriteID = myID
                        }
                } else {
                    EmptyView()
                }
            }
        }
        .onChange(of: isRenaming) {oldValue, newValue in
            if newValue {
                // small delay so the field is actually in the hierarchy
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    isTextFieldFocused = true
                }
            }
        }
    }

    private func endRenaming() {
        favorite.favoriteName = favorite.favoriteName.trimmingCharacters(in: .whitespacesAndNewlines)
        if favorite.favoriteName.isEmpty {
            favorite.favoriteName = ""
        }
        userSettingsViewModel.saveToStorage()
        renamingFavoriteID = nil
    }

}

// Extension to rename a Site without mutating the original
private extension Site {
    func renamed(to newName: String) -> Site {
        var copy = self
        copy.siteName = newName
        return copy
    }
}
