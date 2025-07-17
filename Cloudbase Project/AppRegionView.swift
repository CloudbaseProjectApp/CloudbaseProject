import SwiftUI
import MapKit

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
                        
                        ForEach(appRegionViewModel.appRegions, id: \.appRegion) { region in
                            Button(action: {
                                userSettingsViewModel.appRegion = region.appRegion
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
                                    if userSettingsViewModel.appRegion == region.appRegion {
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
