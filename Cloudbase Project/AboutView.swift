import SwiftUI

struct AboutView: View {
    @Binding var refreshMetadata: Bool
    @EnvironmentObject var siteViewModel: SiteViewModel
    @EnvironmentObject var userSettingsViewModel: UserSettingsViewModel
    @EnvironmentObject var pilotViewModel: PilotViewModel
    @EnvironmentObject var pilotTrackViewModel: PilotTrackViewModel
    
    var body: some View {
        backgroundColor.edgesIgnoringSafeArea(.all)
        
        List {
            
            Section(header: Text("Region Select")
                .font(.subheadline)
                .foregroundColor(sectionHeaderColor)
                .bold())
            {
                ForEach(appRegions, id: \.appRegion) { region in
                    Button(action: {
                        userSettingsViewModel.appRegion = region.appRegion
                        userSettingsViewModel.saveToStorage()
                    }) {
                        HStack {
                            Text(region.appRegionName)
                            Spacer()
                            if userSettingsViewModel.appRegion == region.appRegion {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                    .contentShape(Rectangle())
                }
            }
            
            Section(header: Text("About Cloudbase Utah")
                .font(.subheadline)
                .foregroundColor(sectionHeaderColor)
                .bold())
            {
                    Text("Developed by Mike Brown")
                        .font(.subheadline)
                
                //Submit issue via email
                Button(action: {
                    if let url = URL(string: "mailto:\(cloudbaseUtahEmail)") {
                        UIApplication.shared.open(url)
                    }
                }) {
                    Text("Email feedback or issues")
                        .font(.subheadline)
                        .foregroundColor(rowHeaderColor)
                }

                //Submit issue via Github repo
                Button(action: {
                    if let url = URL(string: cloudbaseUtahGitIssueLink) {
                        UIApplication.shared.open(url)
                    }
                }) {
                    Text("Submit issue via Github")
                        .font(.subheadline)
                        .foregroundColor(rowHeaderColor)
                }
                    
                //Github repo
                Button(action: {
                    if let url = URL(string: cloudbaseUtahGitLink) {
                        UIApplication.shared.open(url)
                    }
                }) {
                    Text("Cloudbase Utah Github repository")
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
                    
                    // Metadata
                    Button(action: {
                        if let url = URL(string: cloudbaseUtahGoogleSheetLink) {
                            UIApplication.shared.open(url)
                        }
                    }) {
                        Text("Cloudbase Utah metadata")
                            .font(.subheadline)
                            .foregroundColor(rowHeaderColor)
                    }
                    
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
