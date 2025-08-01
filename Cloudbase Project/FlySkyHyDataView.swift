import SwiftUI
import Combine
import Foundation

struct FlySkyHyDataView: View {
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.openURL) var openURL     // Used to open URL links as an in-app sheet using Safari
    @State private var externalURL: URL?    // Used to open URL links as an in-app sheet using Safari
    @State private var showWebView = false  // Used to open URL links as an in-app sheet using Safari

    var body: some View {
        
        let stepSpacing: CGFloat = 3
        
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
                        Spacer()
                        Text("FlySkyHy custom data")
                            .foregroundColor(sectionHeaderColor)
                            .bold()
                    }
                }
                .padding()
                Spacer()
            }
            .background(toolbarBackgroundColor)
        }
        
        List {
            Section(header:
                        Text("Custom data contents")
                .font(.subheadline)
                .foregroundColor(sectionHeaderColor)
                .bold()
            ) {
                VStack(alignment: .leading) {
                    Text("Utah")
                        .font(.subheadline)
                        .foregroundColor(rowHeaderColor)
                    Text("Various LZs, thermal hot spots")
                        .font(.subheadline)
                        .foregroundColor(rowTextColor)
                }
                VStack(alignment: .leading) {
                    Text("Oregon")
                        .font(.subheadline)
                        .foregroundColor(rowHeaderColor)
                    Text("Various LZs / No Land areas")
                        .font(.subheadline)
                        .foregroundColor(rowTextColor)
                }
                VStack(alignment: .leading) {
                    Text("Colorado")
                        .font(.subheadline)
                        .foregroundColor(rowHeaderColor)
                    Text("LZs, No Land areas, seasonal closures")
                        .font(.subheadline)
                        .foregroundColor(rowTextColor)
                }
                VStack(alignment: .leading) {
                    Text("California - Santa Barbara")
                        .font(.subheadline)
                        .foregroundColor(rowHeaderColor)
                    Text("No Land areas")
                        .font(.subheadline)
                        .foregroundColor(rowTextColor)
                }
                VStack(alignment: .leading) {
                    Text("Washington - Chelan")
                        .font(.subheadline)
                        .foregroundColor(rowHeaderColor)
                    Text("LZs, thermal hot spots")
                        .font(.subheadline)
                        .foregroundColor(rowTextColor)
                }
                VStack(alignment: .leading) {
                    Text("Mexico - Valle de Bravo")
                        .font(.subheadline)
                        .foregroundColor(rowHeaderColor)
                    Text("Thermal hot spots, airspaces")
                        .font(.subheadline)
                        .foregroundColor(rowTextColor)
                }
                .padding(.vertical, 2)
            }
            
            Section(header:
                        Text("Setup instructions")
                .font(.subheadline)
                .foregroundColor(sectionHeaderColor)
                .bold()
            ) {
                VStack(alignment: .leading) {
                    Text("Installation Steps")
                        .font(.subheadline)
                        .foregroundColor(rowHeaderColor)
                        .padding(.bottom, stepSpacing)
                    Text("1. Tap here to open file:")
                        .font(.subheadline)
                        .foregroundColor(rowTextColor)
                        .padding(.bottom, stepSpacing)
                    Button(action: {
                        let baseURL = AppURLManager.shared.getAppURL(URLName: "flyskyhyCustomAirspaceLink") ?? "<Unknown FlySkyHy data URL>"
                        if let url = URL(string: baseURL) {
                            externalURL = url
                            showWebView = true
                        }
                    }) {
                        Text("   FlySkyHy custom data file")
                            .font(.subheadline)
                            .bold()
                            .foregroundColor(infoFontColor)
                            .padding(.bottom, stepSpacing)
                    }
                    Text("2. Tap the download icon (and if Google drive is installed, select 'Open' and then 'Download' again")
                        .font(.subheadline)
                        .foregroundColor(rowTextColor)
                        .padding(.bottom, stepSpacing)
                    Text("3. Select 'Open in FlySkyHy'")
                        .font(.subheadline)
                        .foregroundColor(rowTextColor)
                        .padding(.bottom, stepSpacing)
                    Text("4. FlySkyHy will open and ask to import airspaces - tap 'OK'")
                        .font(.subheadline)
                        .foregroundColor(rowTextColor)
                        .padding(.bottom, stepSpacing)

                }
                
                VStack(alignment: .leading) {
                    Text("FlySkyHy Configuration Steps")
                        .font(.subheadline)
                        .foregroundColor(rowHeaderColor)
                        .padding(.bottom, stepSpacing)
                    Text("1. Tap on Settings in FlySkyHy")
                        .font(.subheadline)
                        .foregroundColor(rowTextColor)
                        .padding(.bottom, stepSpacing)
                    Text("2. Tap on Airspace under Settings (not under Extensions)")
                        .font(.subheadline)
                        .foregroundColor(rowTextColor)
                        .padding(.bottom, stepSpacing)
                    Text("2. Tap on Airspace sources and set to 'Both'")
                        .font(.subheadline)
                        .foregroundColor(rowTextColor)
                        .padding(.bottom, stepSpacing)
                    Text("3. Tap on Airspace classes and set to:")
                        .font(.subheadline)
                        .foregroundColor(rowTextColor)
                        .padding(.bottom, stepSpacing)
                    Text("  W - Green (LZs)")
                        .font(.subheadline)
                        .foregroundColor(infoFontColor)
                    Text("  R - Red (No land areas)")
                        .font(.subheadline)
                        .foregroundColor(infoFontColor)
                    Text("  SRZ - Yellow (seasonal raptor closures)")
                        .font(.subheadline)
                        .foregroundColor(infoFontColor)
                    Text("  AWY - Med Orange (high % thermal hot spot)")
                        .font(.subheadline)
                        .foregroundColor(infoFontColor)
                    Text("  TMZ - Light Orange (med % thermal hot spot)")
                        .font(.subheadline)
                        .foregroundColor(infoFontColor)
                        .padding(.bottom, stepSpacing)
                    Text("4. Turn off alerts, warnings, alarms, and warnings for each of these airspaces")
                        .font(.subheadline)
                        .foregroundColor(rowTextColor)
                        .padding(.bottom, stepSpacing)
                }
                .padding(.vertical, 2)
            }
        }
        .sheet(isPresented: $showWebView) {
            if let url = externalURL { SafariView(url: url) }
        }
    }

    // Open URL in in-app Safari view
    func openLink(_ url: URL) {
        externalURL = url
        showWebView = true
    }
}
