import SwiftUI
import MapKit

// Allows initial select of global variable appRegion on app load
// (appRegion can also be changed in AboutView).

struct AppRegionView: View {
    @EnvironmentObject var appRegionViewModel: AppRegionViewModel
    @EnvironmentObject var userSettingsViewModel: UserSettingsViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack {
                
                Text("Cloudbase")
                    .bold()
                    .foregroundColor(titleFontColor)
                    .padding()

                List {
                    Section(header: Text("Select a region")
                        .font(.subheadline)
                        .foregroundColor(sectionHeaderColor)
                        .bold())
                    {
                        ForEach(appRegionViewModel.appRegions.filter {
                            $0.appRegionStatus.isEmpty
                        }, id: \.appRegion) { region in
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
                                dismiss()
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
                }
            }
        }
    }
}
