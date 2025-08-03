import SwiftUI
import Combine

struct FlyingPotentialDetailView: View {
    var site: Site                  // Received from parent view
    var favoriteName: String?       // Override display name if site detail is for a user favorite
    var forecastData: ForecastData  // For a single hour for the site
    var forecastIndex: Int
    
    @Environment(\.presentationMode) var presentationMode

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
            }
            .padding()
            .background(toolbarBackgroundColor)
            
            List {
                
                Section(header: Text("Flying Potential Explained")
                    .font(.subheadline)
                    .foregroundColor(sectionHeaderColor)
                    .bold())
                {
                    VStack (alignment: .leading) {
                        Text("flying potential is based on....")
                            .font(.footnote)
                            .foregroundColor(infoFontColor)
                    }
                }
                
                Section(header: Text("Flying Potential Details")
                    .font(.subheadline)
                    .foregroundColor(sectionHeaderColor)
                    .bold())
                {
                    HStack {
/*                        Text(forecastData.formattedDay? ?? "")
                            .font(.caption)
                            .frame(width: dataWidth)
                            .padding(.top, 8)
                        // Display divider when date changes
                            .overlay ( Divider() .frame(width: dateChangeDividerSize, height: headingHeight) .background(getDividerColor(hourly.newDateFlag?[i] ?? true)), alignment: .leading )
                        Text(hourly.formattedDate?[i] ?? "")
                            .font(.caption)
                            .frame(width: dataWidth)
 */
                    }
                        Text("flying potential is based on....")
                            .font(.footnote)
                            .foregroundColor(infoFontColor)
                    }
                }

                
                
/*                var combinedColorValue: [Int]?
                var cloudCoverColorValue: [Int]?
                var precipColorValue: [Int]?
                var CAPEColorValue: [Int]?
                var windDirectionColorValue: [Int]?
                var surfaceWindColorValue: [Int]?
                var surfaceGustColorValue: [Int]?
                var gustFactorColorValue: [Int]?
                var windsAloftColorValue: [Int]?
                var thermalVelocityColorValue: [Int]?
 */

        }
    }
}
