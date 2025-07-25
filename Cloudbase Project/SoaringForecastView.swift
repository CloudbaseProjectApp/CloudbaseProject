import SwiftUI

struct SoaringForecastView: View {
    @ObservedObject var richVM:                 SoaringForecastViewModel
    @ObservedObject var basicVM:                SoaringForecastBasicViewModel
    @ObservedObject var userSettingsViewModel:  UserSettingsViewModel
    let codeOptions: [(name: String, forecastType: String, code: String)]
    @Binding var selectedIndex: Int
    let openLink: (URL) -> Void
    
    // Rich forecast sections
    @State private var showForecast             = true
    @State private var showSounding             = true
    @State private var showModelData            = false
    
    // Basic forecast sections
    @State private var showBasicForecast        = true
    @State private var showBasicLiftData        = true
    @State private var showBasicSoundingData    = true
        
    var body: some View {
        Section(header: Text("Soaring Forecast")
            .font(.headline)
            .foregroundColor(sectionHeaderColor)
            .bold()) {

            // Loading
            if richVM.isLoading || basicVM.isLoading {
                ProgressView().scaleEffect(0.75)
            }
            else if codeOptions.isEmpty {
                Text("No soaring forecast found for region")
            }
            else {
                // Picker if multiple sites
                if codeOptions.count > 1 {
                    Picker("Select Location", selection: $selectedIndex) {
                        ForEach(0..<codeOptions.count, id: \.self) { idx in
                            Text(codeOptions[idx].name).tag(idx)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding(.vertical, 4)
                    .onChange(of: selectedIndex) { oldIndex, newIndex in
                        let code = codeOptions[newIndex].code
                        if codeOptions[newIndex].forecastType == "rich" {
                            richVM.fetchSoaringForecast(airportCode: code)
                        } else {
                            basicVM.fetchSoaringForecast(airportCode: code)
                        }
                        userSettingsViewModel.updatePickListSelection(pickListName: "soaringForecast", selectedIndex: newIndex)
                    }
                }
                
                if codeOptions[selectedIndex].forecastType == "rich" {

                    Text("Forecast Date: \(richVM.soaringForecast?.date ?? "")")
                        .font(.footnote)

                    // 1) Soaring Forecast content
                    DisclosureGroup(isExpanded: $showForecast) {
                        VStack(alignment: .leading, spacing: 5) {
                            if richVM.soaringForecast?.soaringForecastFormat == "rich" {
                                Text(richVM.soaringForecast?.triggerTempData ?? "")
                                    .font(.subheadline)
                            }
                            ForEach(richVM.soaringForecast?.soaringForecastData ?? []) { row in
                                HStack {
                                    Text(row.heading)
                                        .font(.footnote)
                                        .foregroundColor(infoFontColor)
                                        .multilineTextAlignment(.trailing)
                                        .frame(maxWidth: .infinity, alignment: .trailing)
                                        .padding(.vertical, 1)
                                    Text(row.value ?? "")
                                        .font(.subheadline)
                                        .multilineTextAlignment(.leading)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if let base = AppURLManager.shared.getAppURL(URLName: "soaringForecastRichSimple"),
                               let url = URL(string: updateURL(url: base,
                                                               parameter: "airportcode",
                                                               value: codeOptions[selectedIndex].code)) {
                                openLink(url)
                            }
                        }
                    } label: {
                        Text("Soaring Forecast").font(.headline).foregroundColor(rowHeaderColor)
                    }
                    
                    // 2) Sounding Data
                    DisclosureGroup(isExpanded: $showSounding) {
                        Group {
                            richSoundingGrid(data: richVM.soaringForecast?.richSoundingData ?? [])
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if let base = AppURLManager.shared.getAppURL(URLName: "soaringForecastRichSimple"),
                               let url = URL(string: updateURL(url: base,
                                                               parameter: "airportcode",
                                                               value: codeOptions[selectedIndex].code)) {
                                openLink(url)
                            }
                        }
                    } label: {
                        Text("Sounding Data").font(.headline).foregroundColor(rowHeaderColor)
                    }
                    
                    // 3) Numerical Model Data (rich only)
                    if richVM.soaringForecast?.soaringForecastFormat == "rich" {
                        DisclosureGroup(isExpanded: $showModelData) {
                            ScrollView(.horizontal) {
                                VStack(alignment: .leading) {
                                    ForEach(richVM.soaringForecast?.modelData ?? []) { row in
                                        Text(row.value)
                                            .font(.system(.subheadline, design: .monospaced))
                                    }
                                }
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                if let base = AppURLManager.shared.getAppURL(URLName: "soaringForecastRichSimple"),
                                   let url = URL(string: updateURL(url: base,
                                                                   parameter: "airportcode",
                                                                   value: codeOptions[selectedIndex].code)) {
                                    openLink(url)
                                }
                            }
                        } label: {
                            Text("Numerical Model Data")
                                .font(.headline)
                                .foregroundColor(rowHeaderColor)
                        }
                    }

                } else {
                    // Basic forecast

                    Text("Forecast Date: \(basicVM.soaringForecastBasic?.date ?? "")")
                        .font(.footnote)
                    
                    DisclosureGroup(isExpanded: $showBasicForecast) {
                        VStack(alignment: .leading, spacing: 5) {
                            ForEach(basicVM.soaringForecastBasic?.basicSoaringForecastData ?? []) { row in
                                HStack {
                                    Text(row.heading)
                                        .font(.footnote)
                                        .foregroundColor(infoFontColor)
                                        .multilineTextAlignment(.trailing)
                                        .frame(maxWidth: .infinity, alignment: .trailing)
                                        .padding(.vertical, 1)
                                    Text(row.value ?? "")
                                        .font(.subheadline)
                                        .multilineTextAlignment(.leading)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if let base = AppURLManager.shared.getAppURL(URLName: "soaringForecastBasic"),
                               let url = URL(string: updateURL(url: base,
                                                               parameter: "airportcode",
                                                               value: codeOptions[selectedIndex].code)) {
                                openLink(url)
                            }
                        }
                    } label: {
                        Text("Soaring Forecast").font(.headline).foregroundColor(rowHeaderColor)
                    }
                    
                    DisclosureGroup(isExpanded: $showBasicLiftData) {
                        Group {
                            basicLiftGrid(data: basicVM.soaringForecastBasic?.basicLiftData ?? [])
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if let base = AppURLManager.shared.getAppURL(URLName: "soaringForecastBasic"),
                               let url = URL(string: updateURL(url: base,
                                                               parameter: "airportcode",
                                                               value: codeOptions[selectedIndex].code)) {
                                openLink(url)
                            }
                        }
                    } label: {
                        Text("Lift Data")
                            .font(.headline)
                            .foregroundColor(rowHeaderColor)
                    }
                    
                    DisclosureGroup(isExpanded: $showBasicSoundingData) {
                        Group {
                            basicSoundingGrid(data: basicVM.soaringForecastBasic?.basicSoundingData ?? [])
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if let base = AppURLManager.shared.getAppURL(URLName: "soaringForecastBasic"),
                               let url = URL(string: updateURL(url: base,
                                                               parameter: "airportcode",
                                                               value: codeOptions[selectedIndex].code)) {
                                openLink(url)
                            }
                        }
                    } label: {
                        Text("Sounding Data")
                            .font(.headline)
                            .foregroundColor(rowHeaderColor)
                    }
                }
            }
        }
    }
    
    private func richSoundingGrid(data: [RichSoundingData]) -> some View {
        LazyVGrid(columns: [
            GridItem(.fixed(64), spacing: 5, alignment: .trailing),
            GridItem(.fixed(52), spacing: 5, alignment: .trailing),
            GridItem(.fixed(52), spacing: 5, alignment: .trailing),
            GridItem(.fixed(56), spacing: 5, alignment: .trailing),
            GridItem(.fixed(52), spacing: 5, alignment: .trailing),
        ], spacing: 6) {
            Text("Altitude").font(.footnote).foregroundColor(infoFontColor).multilineTextAlignment(.trailing)
            Text("Temp").font(.footnote).foregroundColor(infoFontColor).multilineTextAlignment(.trailing)
            Text("Wind (mph)").font(.footnote).foregroundColor(infoFontColor).multilineTextAlignment(.trailing)
            Text("Thermal Index").font(.footnote).foregroundColor(infoFontColor).multilineTextAlignment(.trailing)
            Text("Lift (m/s)").font(.footnote).foregroundColor(infoFontColor).multilineTextAlignment(.trailing)
            
            ForEach(data) { d in
                Text("\(d.altitude) ft")
                    .font(.footnote)
                HStack {
                    Text("\(String(Int(d.temperatureF)))")
                        .font(.caption)
                        .foregroundColor(tempColor(Int(d.temperatureF))) +
                    Text(" ° F")
                        .font(.footnote)
                }
                HStack {
                    Text("\(String(Int(d.windSpeedMph)))")
                        .font(.footnote)
                        .foregroundColor(windSpeedColor(windSpeed: Int(d.windSpeedMph), siteType: ""))
                    Image(systemName: windArrow)
                        .rotationEffect(Angle(degrees: Double(d.windDirection+180)))
                        .font(.caption)
                }
                Text(String(format: "%.1f", d.thermalIndex))
                    .font(.footnote)
                Text(String(format: "%.1f", d.liftRateMs))
                    .font(.footnote)
                    .foregroundStyle(thermalColor(d.liftRateMs))
            }
        }
    }
    
    private func basicLiftGrid(data: [BasicLiftData]) -> some View {
        LazyVGrid(columns: [
            GridItem(.fixed(65), spacing: 5, alignment: .trailing),
            GridItem(.fixed(70), spacing: 5, alignment: .trailing),
            GridItem(.fixed(52), spacing: 5, alignment: .trailing),
            GridItem(.fixed(56), spacing: 5, alignment: .trailing),
        ], spacing: 6) {
            Text("Altitude (ft)").font(.footnote).foregroundColor(infoFontColor).multilineTextAlignment(.trailing)
            Text("Thermal Index").font(.footnote).foregroundColor(infoFontColor).multilineTextAlignment(.trailing)
            Text("ToC (°F)").font(.footnote).foregroundColor(infoFontColor).multilineTextAlignment(.trailing)
            Text("Lift (m/s)").font(.footnote).foregroundColor(infoFontColor).multilineTextAlignment(.trailing)

            ForEach(data) { d in
                Text("\(d.altitude)")
                    .font(.footnote)
                Text(String(d.thermalIndex))
                    .font(.footnote)
                Text(String(d.tempOfConvection))
                    .font(.footnote)
                Text(String(d.liftRate))
                    .font(.footnote)
                    .foregroundColor(thermalColor(Double(d.liftRate)))
            }
        }
    }
    
    private func basicSoundingGrid(data: [BasicSoundingData]) -> some View {
        LazyVGrid(columns: [
            GridItem(.fixed(65), spacing: 5, alignment: .trailing),
            GridItem(.fixed(70), spacing: 5, alignment: .trailing),
            GridItem(.fixed(70), spacing: 5, alignment: .trailing),
        ], spacing: 6) {
            Text("Altitude (ft)").font(.footnote).foregroundColor(infoFontColor).multilineTextAlignment(.trailing)
            Text("am Wind (mph)").font(.footnote).foregroundColor(infoFontColor).multilineTextAlignment(.trailing)
            Text("pm Wind (mph)").font(.footnote).foregroundColor(infoFontColor).multilineTextAlignment(.trailing)

            ForEach(data) { d in
                Text("\(d.altitude)")
                    .font(.footnote)
                HStack {
                    Text("\(String(Int(d.amWindSpeed)))")
                        .font(.footnote)
                        .foregroundColor(windSpeedColor(windSpeed: Int(d.amWindSpeed), siteType: ""))
                    Image(systemName: windArrow)
                        .rotationEffect(Angle(degrees: Double(d.amWindDirection+180)))
                        .font(.caption)
                }
                HStack {
                    Text("\(String(Int(d.pmWindSpeed)))")
                        .font(.footnote)
                        .foregroundColor(windSpeedColor(windSpeed: Int(d.pmWindSpeed), siteType: ""))
                    Image(systemName: windArrow)
                        .rotationEffect(Angle(degrees: Double(d.pmWindDirection+180)))
                        .font(.caption)
                }
            }
        }
    }
}
