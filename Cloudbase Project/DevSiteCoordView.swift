import SwiftUI
import MapKit
import Foundation
import CoreLocation

struct DevSiteCoordView: View {
    @EnvironmentObject var siteViewModel: SiteViewModel
    @State private var selectedSite: Site?
    @State private var showMapSheet = false
    @State private var coordinateRegion: MKCoordinateRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 0.0, longitude: 0.0),
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    )

    var body: some View {
        NavigationView {
            List(siteViewModel.sites) { site in
                Button(action: {
                    let latitude = Double(site.siteLat) ?? 0.0
                    let longitude = Double(site.siteLon) ?? 0.0
                    selectedSite = site
                    coordinateRegion = MKCoordinateRegion(
                        center: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
                        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
                    )
                }) {
                    Text(site.siteName)
                        .font(.subheadline)
                        .foregroundColor(sectionHeaderColor)
                }
            }
            .onChange(of: selectedSite) {
                showMapSheet = true
            }
            .sheet(isPresented: $showMapSheet) {
                if let selectedSite = selectedSite {
                    SiteMapView(site: selectedSite, coordinateRegion: $coordinateRegion)
                        .setSheetConfig()
                } else {
                    Text("No selected site found")
                }
            }
        }
    }
}

struct IdentifiableCoordinate: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
}

struct SiteCoordMapViewRepresentable: UIViewRepresentable {
    @Binding var coordinateRegion: MKCoordinateRegion
    @Binding var markerCoordinate: CLLocationCoordinate2D?

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.mapType = .hybrid
        mapView.delegate = context.coordinator
        let tapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(context.coordinator.handleMapTap))
        mapView.addGestureRecognizer(tapGesture)
        return mapView
    }

    func updateUIView(_ uiView: MKMapView, context: Context) {
        uiView.setRegion(coordinateRegion, animated: true)
        uiView.removeAnnotations(uiView.annotations)
        if let markerCoordinate = markerCoordinate {
            let annotation = MKPointAnnotation()
            annotation.coordinate = markerCoordinate
            uiView.addAnnotation(annotation)
        }
    }

    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: SiteCoordMapViewRepresentable
        init(parent: SiteCoordMapViewRepresentable) { self.parent = parent }

        @objc func handleMapTap(sender: UITapGestureRecognizer) {
            let mapView = sender.view as! MKMapView
            let touchPoint = sender.location(in: mapView)
            let coordinate = mapView.convert(touchPoint, toCoordinateFrom: mapView)
            DispatchQueue.main.async {
                self.parent.markerCoordinate = coordinate
                self.parent.coordinateRegion.center = coordinate
            }
        }
    }
}

struct SiteMapView: View {
    var site: Site
    @Binding var coordinateRegion: MKCoordinateRegion
    @State private var markerCoordinate: CLLocationCoordinate2D?
    @EnvironmentObject var siteViewModel: SiteViewModel
    @Environment(\.presentationMode) var presentationMode

    init(site: Site, coordinateRegion: Binding<MKCoordinateRegion>) {
        self.site = site
        _coordinateRegion = coordinateRegion
        _markerCoordinate = State(initialValue: coordinateRegion.wrappedValue.center)
    }

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Button(action: { presentationMode.wrappedValue.dismiss() }) {
                    HStack {
                        Image(systemName: "chevron.left").foregroundColor(toolbarActiveImageColor)
                        Text("Back").foregroundColor(toolbarActiveFontColor)
                        Spacer()
                        Text(site.siteName).foregroundColor(sectionHeaderColor).bold()
                    }
                }
                .padding()
                Spacer()
            }
            .background(toolbarBackgroundColor)

            SiteCoordMapViewRepresentable(coordinateRegion: $coordinateRegion, markerCoordinate: $markerCoordinate)

            if let markerCoordinate = markerCoordinate {
                HStack {
                    Button(action: { UIPasteboard.general.string = String(format: "%.5f", markerCoordinate.latitude) }) {
                        Text("Lat: \(String(format: "%.5f", markerCoordinate.latitude))")
                    }
                    .padding()
                    .background(skewTButtonBackgroundColor)
                    .foregroundColor(skewTButtonTextColor)
                    .cornerRadius(8)

                    Button(action: { UIPasteboard.general.string = String(format: "%.5f", markerCoordinate.longitude) }) {
                        Text("Lon: \(String(format: "%.5f", markerCoordinate.longitude))")
                    }
                    .padding()
                    .background(skewTButtonBackgroundColor)
                    .foregroundColor(skewTButtonTextColor)
                    .cornerRadius(8)
                }
                .padding()
            }
        }
    }

    struct SiteCoordinatesUpdate: Encodable {
        let range: String
        let majorDimension = "ROWS"
        let values: [[String]]
    }

    func updateSiteCoordinates(siteName: String,
                               sheetRow: Int,
                               newCoordinate: CLLocationCoordinate2D,
                               token: String) async {
        let rangeName = "Sites!R\(sheetRow)C11:R\(sheetRow)C12"
        guard let regionSheetID = AppRegionManager.shared.getRegionGoogleSheet(),
              let url = URL(string: "https://sheets.googleapis.com/v4/spreadsheets/\(regionSheetID)/values/\(rangeName)?valueInputOption=RAW") else {
            print("Invalid URL for updating site coordinates")
            return
        }

        let body = SiteCoordinatesUpdate(
            range: rangeName,
            values: [["\(newCoordinate.latitude)", "\(newCoordinate.longitude)"]]
        )

        do {
            try await AppNetwork.shared.putJSON(url: url, token: token, body: body)
            print("Coordinates updated successfully.")
        } catch {
            print("Error updating coordinates: \(error)")
        }
    }
}
