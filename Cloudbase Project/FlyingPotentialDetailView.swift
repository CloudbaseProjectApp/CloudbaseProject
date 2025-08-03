import SwiftUI
import Combine

struct FlyingPotentialDetailView: View {
    var site: Site                  // Received from parent view
    var favoriteName: String?       // Override display name if site detail is for a user favorite
    var forecastData: ForecastData  // Forecast by hour format
    var forecastIndex: Int          // Index to use for correct date/hour
    
    @Environment(\.presentationMode) var presentationMode

    let dataWidth: CGFloat = 44
    let rowHeight: CGFloat = 32

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
                        Text("Details for: ")
                            .font(.caption)
                        Text(forecastData.hourly.formattedDay?[forecastIndex] ?? "")
                            .font(.caption)
                        Text(forecastData.hourly.formattedDate?[forecastIndex] ?? "")
                            .font(.caption)
                        Text(forecastData.hourly.formattedTime?[forecastIndex] ?? "")
                            .font(.caption)
                    }
                    HStack {
                        Text("Combined flying potential")
                            .font(.caption)
                        let displayColor = FlyingPotentialColor.color(for: forecastData.hourly.combinedColorValue![forecastIndex])
                        let displaySize = FlyingPotentialImageSize(displayColor)
                        Image(systemName: flyingPotentialImage)
                            .resizable()
                            .scaledToFit()
                            .font(.system(size: displaySize))
                            .frame(width: displaySize, height: displaySize)
                            .foregroundColor(Color(displayColor))
                            .padding(8)
                            .frame(width: dataWidth, height: rowHeight)
                    }
                    HStack {
                        Text("Cloud cover")
                            .font(.caption)
                        let displayColor = FlyingPotentialColor.color(for: forecastData.hourly.cloudCoverColorValue![forecastIndex])
                        let displaySize = FlyingPotentialImageSize(displayColor)
                        Image(systemName: flyingPotentialImage)
                            .resizable()
                            .scaledToFit()
                            .font(.system(size: displaySize))
                            .frame(width: displaySize, height: displaySize)
                            .foregroundColor(Color(displayColor))
                            .padding(8)
                            .frame(width: dataWidth, height: rowHeight)
                    }
                    HStack {
                        Text("Precipitation probability")
                            .font(.caption)
                        let displayColor = FlyingPotentialColor.color(for: forecastData.hourly.precipColorValue![forecastIndex])
                        let displaySize = FlyingPotentialImageSize(displayColor)
                        Image(systemName: flyingPotentialImage)
                            .resizable()
                            .scaledToFit()
                            .font(.system(size: displaySize))
                            .frame(width: displaySize, height: displaySize)
                            .foregroundColor(Color(displayColor))
                            .padding(8)
                            .frame(width: dataWidth, height: rowHeight)
                    }
                    HStack {
                        Text("CAPE")
                            .font(.caption)
                        let displayColor = FlyingPotentialColor.color(for: forecastData.hourly.CAPEColorValue![forecastIndex])
                        let displaySize = FlyingPotentialImageSize(displayColor)
                        Image(systemName: flyingPotentialImage)
                            .resizable()
                            .scaledToFit()
                            .font(.system(size: displaySize))
                            .frame(width: displaySize, height: displaySize)
                            .foregroundColor(Color(displayColor))
                            .padding(8)
                            .frame(width: dataWidth, height: rowHeight)
                    }
                    HStack {
                        Text("Wind Direction")
                            .font(.caption)
                        let displayColor = FlyingPotentialColor.color(for: forecastData.hourly.windDirectionColorValue![forecastIndex])
                        let displaySize = FlyingPotentialImageSize(displayColor)
                        Image(systemName: flyingPotentialImage)
                            .resizable()
                            .scaledToFit()
                            .font(.system(size: displaySize))
                            .frame(width: displaySize, height: displaySize)
                            .foregroundColor(Color(displayColor))
                            .padding(8)
                            .frame(width: dataWidth, height: rowHeight)
                    }
                    HStack {
                        Text("Surface wind speed")
                            .font(.caption)
                        let displayColor = FlyingPotentialColor.color(for: forecastData.hourly.surfaceWindColorValue![forecastIndex])
                        let displaySize = FlyingPotentialImageSize(displayColor)
                        Image(systemName: flyingPotentialImage)
                            .resizable()
                            .scaledToFit()
                            .font(.system(size: displaySize))
                            .frame(width: displaySize, height: displaySize)
                            .foregroundColor(Color(displayColor))
                            .padding(8)
                            .frame(width: dataWidth, height: rowHeight)
                    }
                    HStack {
                        Text("Surface gust speed")
                            .font(.caption)
                        let displayColor = FlyingPotentialColor.color(for: forecastData.hourly.surfaceGustColorValue![forecastIndex])
                        let displaySize = FlyingPotentialImageSize(displayColor)
                        Image(systemName: flyingPotentialImage)
                            .resizable()
                            .scaledToFit()
                            .font(.system(size: displaySize))
                            .frame(width: displaySize, height: displaySize)
                            .foregroundColor(Color(displayColor))
                            .padding(8)
                            .frame(width: dataWidth, height: rowHeight)
                    }
                    HStack {
                        Text("Gust factor")
                            .font(.caption)
                        let displayColor = FlyingPotentialColor.color(for: forecastData.hourly.gustFactorColorValue![forecastIndex])
                        let displaySize = FlyingPotentialImageSize(displayColor)
                        Image(systemName: flyingPotentialImage)
                            .resizable()
                            .scaledToFit()
                            .font(.system(size: displaySize))
                            .frame(width: displaySize, height: displaySize)
                            .foregroundColor(Color(displayColor))
                            .padding(8)
                            .frame(width: dataWidth, height: rowHeight)
                    }
                    HStack {
                        Text("Winds aloft speed")
                            .font(.caption)
                        let displayColor = FlyingPotentialColor.color(for: forecastData.hourly.windsAloftColorValue![forecastIndex])
                        let displaySize = FlyingPotentialImageSize(displayColor)
                        Image(systemName: flyingPotentialImage)
                            .resizable()
                            .scaledToFit()
                            .font(.system(size: displaySize))
                            .frame(width: displaySize, height: displaySize)
                            .foregroundColor(Color(displayColor))
                            .padding(8)
                            .frame(width: dataWidth, height: rowHeight)
                    }
                    HStack {
                        Text("Winds aloft speed")
                            .font(.caption)
                        let displayColor = FlyingPotentialColor.color(for: forecastData.hourly.thermalVelocityColorValue![forecastIndex])
                        let displaySize = FlyingPotentialImageSize(displayColor)
                        Image(systemName: flyingPotentialImage)
                            .resizable()
                            .scaledToFit()
                            .font(.system(size: displaySize))
                            .frame(width: displaySize, height: displaySize)
                            .foregroundColor(Color(displayColor))
                            .padding(8)
                            .frame(width: dataWidth, height: rowHeight)
                    }
                }
            }
        }
    }
}
