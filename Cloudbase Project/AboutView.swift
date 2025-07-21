import SwiftUI
import MapKit

struct AboutView: View {
    @Binding var refreshMetadata: Bool
    @EnvironmentObject var appRegionViewModel: AppRegionViewModel
    @EnvironmentObject var siteViewModel: SiteViewModel
    @EnvironmentObject var userSettingsViewModel: UserSettingsViewModel
    @EnvironmentObject var pilotViewModel: PilotViewModel
    @EnvironmentObject var pilotTrackViewModel: PilotTrackViewModel
    @Environment(\.presentationMode) var presentationMode
    
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
            }
            .padding()
            .background(toolbarBackgroundColor)
                
            List {
                
                Section(header: Text("Region Select")
                    .font(.subheadline)
                    .foregroundColor(sectionHeaderColor)
                    .bold())
                {
                    ForEach(appRegionViewModel.appRegions, id: \.appRegion) { region in
                        Button(action: {
                            RegionManager.shared.activeAppRegion = region.appRegion
                            userSettingsViewModel.mapRegion = MKCoordinateRegion(
                                center: CLLocationCoordinate2D(
                                    latitude: region.mapInitLatitude,
                                    longitude: region.mapInitLongitude
                                ),
                                span: MKCoordinateSpan(
                                    latitudeDelta: region.mapInitLatitudeSpan,
                                    longitudeDelta: region.mapInitLongitudeSpan
                                )
                            )
                            userSettingsViewModel.zoomLevel = region.mapDefaultZoomLevel
                            userSettingsViewModel.saveToStorage()
                            // Force app reload when region changes
                            refreshMetadata = true
                        }) {
                            HStack {
                                Text(region.appRegionName)
                                    .font(.subheadline)
                                    .foregroundColor(toolbarActiveFontColor)
                                Spacer()
                                if RegionManager.shared.activeAppRegion == region.appRegion {
                                    Image(systemName: "checkmark")
                                        .font(.subheadline)
                                        .foregroundColor(toolbarActiveImageColor)
                                }
                            }
                        }
                        .contentShape(Rectangle())
                    }
                }
                
                Section(header: Text("About Cloudbase Project")
                    .font(.subheadline)
                    .foregroundColor(sectionHeaderColor)
                    .bold())
                {
                    Text("Developed by Mike Brown")
                        .font(.subheadline)
                    
                    // Join Telegram group
                    Button(action: {
                        if let url = URL(string: cloudbaseProjectTelegramLink) {
                            UIApplication.shared.open(url)
                        }
                    }) {
                        Text("Telegram group")
                            .font(.subheadline)
                            .foregroundColor(rowHeaderColor)
                    }
                    
                    // Contact via email
                    Button(action: {
                        if let url = URL(string: "mailto:\(cloudbaseProjectEmail)") {
                            UIApplication.shared.open(url)
                        }
                    }) {
                        Text("Contact via email")
                            .font(.subheadline)
                            .foregroundColor(rowHeaderColor)
                    }
                    
                    // Submit issue via Github repo
/*                    Button(action: {
                        if let url = URL(string: cloudbaseProjectGitIssueLink) {
                            UIApplication.shared.open(url)
                        }
                    }) {
                        Text("Submit issue via Github")
                            .font(.subheadline)
                            .foregroundColor(rowHeaderColor)
                    }
 */
                    
                    // Github repo
                    Button(action: {
                        if let url = URL(string: cloudbaseProjectGitLink) {
                            UIApplication.shared.open(url)
                        }
                    }) {
                        Text("Github repository")
                            .font(.subheadline)
                            .foregroundColor(rowHeaderColor)
                    }
                }
                
                Section(header: Text("Application setup")
                    .font(.subheadline)
                    .foregroundColor(sectionHeaderColor)
                    .bold())
                {
                    
                    // Force reload app (e.g., metadata changes)
                    Button(action: {
                        // Trigger a change to appRefreshID to reload metadata by making BaseAppView reappear
                        refreshMetadata = true
                    }) {
                        Text("Reload metadata")
                            .font(.subheadline)
                            .foregroundColor(rowHeaderColor)
                    }
                    
                    // Reset to defaults (clear user settings)
                    Button(action: {
                        userSettingsViewModel.clearUserSettings() {
                            
                            // Reset active app region
                            RegionManager.shared.activeAppRegion = ""
                            
                            // Trigger a change to appRefreshID to reload metadata by making BaseAppView reappear
                            refreshMetadata = true
                        }
                    }) {
                        Text("Clear user settings (reset to defaults)")
                            .font(.subheadline)
                            .foregroundColor(rowHeaderColor)
                    }
                    
                }
                
                if devMenuAvailable {
                    
                    Section(header: Text("Development Tools")
                        .font(.subheadline)
                        .foregroundColor(sectionHeaderColor)
                        .bold())
                    {
                        
                        // Inactive pilots
                        NavigationLink(destination: DevInactivePilotsView()) {
                            Text("Manage inactive pilots")
                                .font(.subheadline)
                                .foregroundColor(rowHeaderColor)
                        }
                        
                        // Pilots and tracks
                        NavigationLink(destination: DevPilotTracksView()) {
                            Text("Pilots tracks")
                                .font(.subheadline)
                                .foregroundColor(rowHeaderColor)
                        }
                        
                        // Site coordinates map
                        NavigationLink(destination: DevSiteCoordView()) {
                            Text("Site coordinates updates")
                                .font(.subheadline)
                                .foregroundColor(rowHeaderColor)
                        }
                        
                        // UDOT camera map
                        NavigationLink(destination: UDOTCameraListView()) {
                            Text("UDOT cameras map")
                                .font(.subheadline)
                                .foregroundColor(rowHeaderColor)
                        }
                        
                    }
                }
            }
        }
    }
}
