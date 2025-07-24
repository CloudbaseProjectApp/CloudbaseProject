import SwiftUI
import Combine

struct SiteView: View {
    @EnvironmentObject var liftParametersViewModel: LiftParametersViewModel
    @EnvironmentObject var sunriseSunsetViewModel: SunriseSunsetViewModel
    @EnvironmentObject var weatherCodesViewModel: WeatherCodeViewModel
    @EnvironmentObject var siteViewModel: SiteViewModel
    @EnvironmentObject var stationLatestReadingViewModel: StationLatestReadingViewModel
    @EnvironmentObject var userSettingsViewModel: UserSettingsViewModel
    
    @Environment(\.scenePhase) private var scenePhase
    @State private var selectedSite: Site?
    @State private var isActive = false
    @State private var isEditingFavorites = false
    @State private var editableFavorites: [UserFavoriteSite] = []
    
    // Build an array of dummy “Sites” from user favorites
    private var favoriteSites: [Site] {
        userSettingsViewModel
            .userFavoriteSites
            .sorted { $0.sortSequence < $1.sortSequence }
            .compactMap { fav -> Site? in
                switch fav.favoriteType {
                case "Site":
                    // if favorite is a site, find the real site by name
                    return siteViewModel.sites
                        .first { $0.siteName == fav.favoriteID }
                case "Station":
                    // build a dummy site for a station favorite
                    return Site(
                        area:                   "Favorites",
                        siteName:               fav.favoriteName,
                        readingsNote:           "",
                        forecastNote:           "",
                        siteType:               "Station",
                        readingsAlt:            fav.readingsAlt,
                        readingsSource:         fav.readingsSource,
                        readingsStation:        fav.stationID,
                        pressureZoneReadingTime: "",
                        siteLat:                fav.siteLat,
                        siteLon:                fav.siteLon,
                        sheetRow:               0
                    )
                default:
                    return nil
                }
            }
    }

    var body: some View {
        VStack {
            Text("Tap on a site for forecast and readings history")
                .font(.caption)
                .foregroundColor(infoFontColor)
                .padding(.top, 8)
            
            List {
                // Show any favorites first
                if !favoriteSites.isEmpty {
                    Section(
                        header: HStack {
                            Text("Favorites")
                                .font(.subheadline)
                                .foregroundColor(sectionHeaderColor)
                                .bold()
                            Spacer()
                            Button(action: {
                                isEditingFavorites.toggle()
                            }) {
                                if isEditingFavorites {
                                    Image(systemName: "arrow.up.arrow.down")
                                        .imageScale(.small)
                                        .foregroundColor(toolbarActiveImageColor)
                                } else {
                                    Image(systemName: "arrow.up.arrow.down")
                                        .imageScale(.small)
                                        .foregroundColor(toolbarImageColor)
                                }
                            }
                        }
                    ) {
                        ForEach(editableFavorites.indices, id: \.self) { index in
                            let favorite = editableFavorites[index]
                            if let site = siteFromFavorite(favorite) {
                                FavoriteRow(
                                    favorite: $editableFavorites[index],
                                    site: site,
                                    onSelect: openSiteDetail
                                )
                            }
                        }
                        .onMove(perform: moveFavorite)                    }
                }
                
                let groupedSites = Dictionary(grouping: siteViewModel.sites) { $0.area }
                     let sortedGroupedSites = groupedSites.sorted(by: { $0.key < $1.key })

                ForEach(sortedGroupedSites, id: \.key) { area, areaSites in
                    let areaName = area
                        .split(separator: " ", maxSplits: 1)
                        .dropFirst()
                        .joined(separator: " ")
                    
                    Section(header:
                                Text(areaName)
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
            }
            .environment(\.editMode, .constant(isEditingFavorites ? .active : .inactive))
         }
        .onAppear {

            editableFavorites = userSettingsViewModel.userFavoriteSites
                .sorted { $0.sortSequence < $1.sortSequence }

            isActive = true
            startTimer()
            guard !siteViewModel.sites.isEmpty else {
                // Skipping getLatestReadingsData - sites not yet loaded
                return
            }
            stationLatestReadingViewModel.getLatestReadingsData(sitesOnly: true) {}

        }
        
        .onDisappear {
            isActive = false

            for fav in editableFavorites {
                if let i = userSettingsViewModel.userFavoriteSites.firstIndex(where: { $0.id == fav.id }) {
                    userSettingsViewModel.userFavoriteSites[i] = fav
                }
            }
        }

        
        .sheet(
          item: $selectedSite,
          onDismiss: {
            // refresh when they close it
              guard !siteViewModel.sites.isEmpty else {
                  // Skipping getLatestReadingsData - sites not yet loaded
                  return
              }
              stationLatestReadingViewModel.getLatestReadingsData(sitesOnly: true) {}
          }
        ) { site in
            SiteDetailView(site: site)
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
    }
    
    private func openSiteDetail(_ site: Site) {
        selectedSite = site
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
    
    private func siteFromFavorite(_ favorite: UserFavoriteSite) -> Site? {
        let displayName = favorite.favoriteName.isEmpty ? favorite.favoriteID : favorite.favoriteName

        switch favorite.favoriteType {
        case "Site":
            return siteViewModel.sites.first { $0.siteName == favorite.favoriteID }?.renamed(to: displayName)
        case "Station":
            return Site(
                area: "Favorites",
                siteName: displayName,
                readingsNote: "",
                forecastNote: "",
                siteType: "Station",
                readingsAlt: favorite.readingsAlt,
                readingsSource: favorite.readingsSource,
                readingsStation: favorite.stationID,
                pressureZoneReadingTime: "",
                siteLat: favorite.siteLat,
                siteLon: favorite.siteLon,
                sheetRow: 0
            )
        default:
            return nil
        }
    }
    
    private func moveFavorite(from source: IndexSet, to destination: Int) {
        editableFavorites.move(fromOffsets: source, toOffset: destination)
        
        for (index, var item) in editableFavorites.enumerated() {
            item.sortSequence = index
            if let i = userSettingsViewModel.userFavoriteSites.firstIndex(where: { $0.id == item.id }) {
                userSettingsViewModel.userFavoriteSites[i] = item
            }
        }
    }}

struct SiteRow: View {
    @EnvironmentObject var stationLatestReadingViewModel: StationLatestReadingViewModel
    var site: Site
    var onSelect: (Site) -> Void
    
    var body: some View {
        
        VStack(alignment: .leading) {
            HStack {
                Text(site.siteName)
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
                        let windTimeText = windTime.split(separator: " ", maxSplits: 1)[0]
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
    @Binding var favorite: UserFavoriteSite
    var site: Site
    var onSelect: (Site) -> Void

    @State private var isRenaming = false
    @FocusState private var isTextFieldFocused: Bool

    var body: some View {
        Group {
            if isRenaming {
                HStack {
                    TextField("Favorite Name", text: $favorite.favoriteName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .focused($isTextFieldFocused)
                        .onSubmit {
                            isRenaming = false
                        }
                    Spacer()
                }
                .onAppear {
                    isTextFieldFocused = true
                }
            } else {
                SiteRow(site: site, onSelect: onSelect)
                    .contextMenu {
                        Button("Rename") {
                            isRenaming = true
                        }
                    }
                    .swipeActions(edge: .trailing) {
                        Button("Rename") {
                            isRenaming = true
                        }
                        .tint(.blue)
                    }
                    .onLongPressGesture {
                        isRenaming = true
                    }
            }
        }
    }
}
