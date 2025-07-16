import SwiftUI

struct AppRegionView: View {
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
                        
                        ForEach(appRegions, id: \.appRegion) { region in
                            Button(action: {
                                userSettingsViewModel.appRegion = region.appRegion
                                userSettingsViewModel.saveToStorage()
                                dismiss()
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
                }
            }
        }
    }
}
