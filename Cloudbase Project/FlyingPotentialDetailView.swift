import SwiftUI
import Combine

struct FlyingPotentialDetailView: View {
    var site: Site                  // Received from parent view
    var favoriteName: String?       // Override display name if site detail is for a user favorite
    var forecastData: ForecastData  // Forecast by hour format
    var forecastIndex: Int          // Index to use for correct date/hour
    
    @Environment(\.presentationMode) var presentationMode
    @State private var currentForecastIndex: Int = 0

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
            
            HStack { //Arrows for navigating track nodes
                Button(action: {
                    currentForecastIndex -= 1
                }) {
                    HStack {
                        Image(systemName: "chevron.left")
                            .foregroundColor(toolbarActiveImageColor)
                        Text("Back")
                            .foregroundColor(toolbarActiveFontColor)
                    }
                    .padding(.horizontal, 8)
                }
                .id("backButton")
                // Hide and disable the button when it's not applicable
                .opacity(currentForecastIndex > 0 ? 1.0 : 0.0)
                .disabled(currentForecastIndex == 0)

                Spacer()
                
                HStack {
                    Text(forecastData.hourly.formattedDay?[currentForecastIndex] ?? "")
                    Text(forecastData.hourly.formattedDate?[currentForecastIndex] ?? "")
                    Text(forecastData.hourly.formattedTime?[currentForecastIndex] ?? "")
                }
                
                Spacer()

                Button(action: {
                    currentForecastIndex += 1
                }) {
                    HStack {
                        Text("Next")
                            .foregroundColor(toolbarActiveFontColor)
                        Image(systemName: "chevron.right")
                            .foregroundColor(toolbarActiveImageColor)
                    }
                    .padding(.horizontal, 8)
                }
                .id("nextButton")
                // Hide and disable the button when it's not applicable
                .opacity(currentForecastIndex < forecastData.hourly.formattedTime!.count - 1 ? 1.0 : 0.0)
                .disabled(currentForecastIndex >= forecastData.hourly.formattedTime!.count - 1)
            }
            .padding()
            .background(navigationBackgroundColor)

            
            List {
                
                // Combined
                Section()
                {
                    FlyingPotentialDetailRow(
                        label:              "Flying potential",
                        colorValue:         forecastData.hourly.combinedColorValue![currentForecastIndex],
                        valueText:          "",
                        windDirection:      nil,
                        siteWindDirection:  site.windDirection
                    )
                }
                
                // Wind
                Section()
                {
                    
                    FlyingPotentialDetailRow(
                        label:              "Wind direction",
                        colorValue:         forecastData.hourly.windDirectionColorValue![currentForecastIndex],
                        valueText:          "",
                        windDirection:      forecastData.hourly.winddirection_10m[currentForecastIndex],
                        siteWindDirection:  site.windDirection
                    )
                    
                    FlyingPotentialDetailRow(
                        label:              "Surface wind speed",
                        colorValue:         forecastData.hourly.surfaceWindColorValue![currentForecastIndex],
                        valueText:          "\(Int(forecastData.hourly.windspeed_10m[currentForecastIndex])) mph",
                        windDirection:      nil,
                        siteWindDirection:  site.windDirection
                    )
                    
                    FlyingPotentialDetailRow(
                        label:              "Surface gust speed",
                        colorValue:         forecastData.hourly.surfaceGustColorValue![currentForecastIndex],
                        valueText:          "\(Int(forecastData.hourly.windgusts_10m[currentForecastIndex])) mph",
                        windDirection:      nil,
                        siteWindDirection:  site.windDirection
                    )
                    
                    FlyingPotentialDetailRow(
                        label:              "Surface gust factor",
                        colorValue:         forecastData.hourly.gustFactorColorValue![currentForecastIndex],
                        valueText:          "\(Int(forecastData.hourly.gustFactor?[currentForecastIndex] ?? 0)) mph",
                        windDirection:      nil,
                        siteWindDirection:  site.windDirection
                    )

                    FlyingPotentialDetailRow(
                        label:              "Winds aloft speed",
                        colorValue:         forecastData.hourly.windsAloftColorValue![currentForecastIndex],
                        valueText:          "\(Int(forecastData.hourly.windsAloftMax?[currentForecastIndex] ?? 0)) mph",
                        windDirection:      nil,
                        siteWindDirection:  site.windDirection
                    )
                    
                }
                .padding(.vertical, 0)
                
                // Weather
                Section()
                {

                    FlyingPotentialDetailRow(
                        label:              "Cloud cover",
                        colorValue:         forecastData.hourly.cloudCoverColorValue![currentForecastIndex],
                        valueText:          "\(Int(forecastData.hourly.cloudcover[currentForecastIndex]))%",
                        windDirection:      nil,
                        siteWindDirection:  site.windDirection
                    )
                    
                    FlyingPotentialDetailRow(
                        label:              "Precipitation probability",
                        colorValue:         forecastData.hourly.precipColorValue![currentForecastIndex],
                        valueText:          "\(Int(forecastData.hourly.precipitation_probability[currentForecastIndex]))%",
                        windDirection:      nil,
                        siteWindDirection:  site.windDirection
                    )
                    
                    FlyingPotentialDetailRow(
                        label:              "CAPE",
                        colorValue:         forecastData.hourly.CAPEColorValue![currentForecastIndex],
                        valueText:          "\(Int(forecastData.hourly.cape[currentForecastIndex])) J/kg",
                        windDirection:      nil,
                        siteWindDirection:  site.windDirection
                    )
                    
                    FlyingPotentialDetailRow(
                        label:              "Thermal strength",
                        colorValue:         forecastData.hourly.thermalVelocityColorValue![currentForecastIndex],
                        valueText:          String(format: "%.1f m/s", forecastData.hourly.thermalVelocityMax?[currentForecastIndex] ?? 0),
                        windDirection:      nil,
                        siteWindDirection:  site.windDirection
                    )

                }
                .padding(.vertical, 0)

            }
            .listSectionSpacing(8)
            
            .onAppear {
                currentForecastIndex = forecastIndex
            }
        }
    }
}

struct FlyingPotentialDetailRow: View {
    let label:              String
    let colorValue:         Int
    let valueText:          String
    let windDirection:      Double?
    let siteWindDirection:  SiteWindDirection
    
    let dataWidth:  CGFloat = 44
    let rowHeight:  CGFloat = 32
    let labelWidth: CGFloat = 180

    var body: some View {
        let displayColor = FlyingPotentialColor.color(for: colorValue)
        let imageSize = FlyingPotentialImageSize(displayColor)
        HStack(alignment: .center, spacing: 8) {
            
            Text(label)
                .font(.subheadline)
                .foregroundColor(infoFontColor)
                .frame(width: labelWidth, alignment: .trailing)

            Image(systemName: flyingPotentialImage)
                .resizable()
                .scaledToFit()
                .frame(width: imageSize, height: imageSize)
                .foregroundColor(displayColor)
                .padding(8)
                .frame(width: dataWidth, height: rowHeight)

            if let windDirection {
                HStack {
                    Spacer()
                    WindDirectionIndicator(
                        currentDirection: windDirection,
                        siteWindDirection: siteWindDirection
                    )
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                Text(valueText)
                    .font(.subheadline)
                    .frame(maxWidth: .infinity)
            }
        }
    }
}

struct WindDirectionIndicator: View {
    let currentDirection: Double
    let siteWindDirection: SiteWindDirection

    let windDirectionIndicatorSize: CGFloat = 40
    let windDirectionColorWidth: CGFloat = 1

    // Computed properties that pull from siteWindDirection
    private var goodRanges: [(Double, Double)] {
        windDirectionRanges(from: siteWindDirection).goodRanges
    }

    private var marginalRanges: [(Double, Double)] {
        windDirectionRanges(from: siteWindDirection).marginalRanges
    }

    var body: some View {
        let ringRadius = (0.8 * windDirectionIndicatorSize) / 2

        ZStack {
            // Color ring
            ForEach(0..<360, id: \.self) { degree in
                let color = colorForDirection(degree)
                let colorDescription = color.description.lowercased()

                let extraLength: CGFloat = {
                    if colorDescription.contains("green") {
                        return 5
                    } else if colorDescription.contains("yellow") {
                        return 5
                    } else {
                        return 0
                    }
                }()

                let capsuleHeight = windDirectionColorWidth + extraLength
                let offset = -(ringRadius - (windDirectionColorWidth / 2)) + (extraLength / 2)

                Capsule()
                    .fill(color)
                    .frame(width: 2, height: capsuleHeight)
                    .offset(y: offset)
                    .rotationEffect(.degrees(Double(degree)))
            }

            // Triangle pointing inward from wind direction
            let correctedAngle = currentDirection - 90
            let radians = correctedAngle * .pi / 180
            let triangleDistance = ringRadius + 6
            let triangleX = cos(radians) * triangleDistance
            let triangleY = sin(radians) * triangleDistance

            Triangle()
                .fill(Color.white)
                .frame(width: 14, height: 12)
                .rotationEffect(.degrees(currentDirection))
                .offset(x: triangleX, y: triangleY)
        }
        .frame(width: windDirectionIndicatorSize, height: windDirectionIndicatorSize)
        .padding(.vertical, 4)
    }

    private func colorForDirection(_ degree: Int) -> Color {
        for (start, end) in goodRanges {
            if angleInRange(degree, start, end) {
                return .green
            }
        }
        for (start, end) in marginalRanges {
            if angleInRange(degree, start, end) {
                return .yellow
            }
        }
        return .red
    }

    private func angleInRange(_ angle: Int, _ start: Double, _ end: Double) -> Bool {
        if start <= end {
            return Double(angle) >= start && Double(angle) <= end
        } else {
            return Double(angle) >= start || Double(angle) <= end // wraps 360
        }
    }
}

struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.maxY))       // tip at bottom
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))    // top right
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))    // top left
        path.closeSubpath()
        return path
    }
}
