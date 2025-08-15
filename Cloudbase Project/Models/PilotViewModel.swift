import SwiftUI
import SwiftJWT

struct Pilot: Codable, Identifiable, Equatable {
    var id = UUID()
    var pilotName: String
    var inactive: Bool
    var trackingShareURL: String
    var trackingFeedURL: String
}

struct PilotsResponse: Codable {
    let values: [[String]]
}

class PilotViewModel: ObservableObject {
    @Published var pilots: [Pilot] = []

    func getPilots() async {
        let rangeName = "Pilots"
        
        guard let regionGoogleSheetID = AppRegionManager.shared.getRegionGoogleSheet(),
              let regionURL = URL(string: "https://sheets.googleapis.com/v4/spreadsheets/\(regionGoogleSheetID)/values/\(rangeName)?alt=json&key=\(googleAPIKey)")
        else {
            print("Invalid or missing region Google Sheet ID")
            return
        }
        
        do {
            let response: PilotsResponse = try await AppNetwork.shared.fetchJSONAsync(url: regionURL, type: PilotsResponse.self)
            
            let pilots = response.values.dropFirst().compactMap { row -> Pilot? in
                guard row.count >= 2 else {
                    print("Skipping malformed pilot row: \(row)")
                    return nil
                }
                let pilotName = row[0]
                let trackingShareURL = row[1]
                let inactive = (row.count > 2 && row[2].lowercased() == "yes")
                guard trackingShareURL.contains("https://share.garmin.com/") else {
                    print("Skipping malformed InReach share URL for row: \(row)")
                    return nil
                }
                let pilotNameFromURL = trackingShareURL.components(separatedBy: "/").last ?? ""
                let trackingFeedURL = "https://share.garmin.com/Feed/Share/\(pilotNameFromURL)"
                return Pilot(
                    pilotName: pilotName,
                    inactive: inactive,
                    trackingShareURL: trackingShareURL,
                    trackingFeedURL: trackingFeedURL
                )
            }
            
            await MainActor.run { self.pilots = pilots }
            
        } catch {
            print("Failed to fetch pilots: \(error)")
        }
    }
    
    @MainActor
    func addPilot(pilotName: String, trackingShareURL: String) async throws {
        // Get OAuth token
        let token = try await fetchAccessTokenAsync()
        
        guard let regionGoogleSheetID = AppRegionManager.shared.getRegionGoogleSheet(),
              let url = URL(string: "https://sheets.googleapis.com/v4/spreadsheets/\(regionGoogleSheetID)/values/Pilots:append?valueInputOption=RAW")
        else {
            print("Invalid or missing Google Sheet ID")
            return
        }

        let body: [String: Any] = ["values": [[pilotName, trackingShareURL]]]

        // Post pilot data
        try await AppNetwork.shared.postJSON(url: url, token: token, body: body)
        
        // Refresh pilots list
        await getPilots()
    }

    @MainActor
    func setPilotActiveStatus(pilot: Pilot, isInactive: Bool) async throws {
        // Get OAuth token
        let token = try await fetchAccessTokenAsync()
        
        guard let regionGoogleSheetID = AppRegionManager.shared.getRegionGoogleSheet(),
              let readURL = URL(string: "https://sheets.googleapis.com/v4/spreadsheets/\(regionGoogleSheetID)/values/Pilots")
        else {
            print("Invalid or missing Google Sheet ID")
            return
        }

        // Fetch sheet values
        struct ValuesResponse: Decodable { let values: [[String]] }
        let sheet: ValuesResponse = try await AppNetwork.shared.fetchJSONAsync(url: readURL, type: ValuesResponse.self)

        guard let rowIndex = sheet.values.firstIndex(where: { $0.first == pilot.pilotName }) else {
            print("Pilot \(pilot.pilotName) not found")
            return
        }

        let sheetRow = rowIndex + 1  // Sheets rows are 1-based
        let updateRange = "Pilots!C\(sheetRow)"  // Column C = Inactive

        guard let updateURL = URL(string: "https://sheets.googleapis.com/v4/spreadsheets/\(regionGoogleSheetID)/values/\(updateRange)?valueInputOption=RAW")
        else { return }

        let body: [String: Any] = ["values": [[isInactive ? "Yes" : ""]]]

        try await AppNetwork.shared.putJSON(url: updateURL, token: token, body: body)

        // Refresh pilots list
        await getPilots()
    }
    
    func trackingShareURL(for pilotName: String) -> String? {
        return pilots.first(where: { $0.pilotName == pilotName })?.trackingShareURL
    }
    
    // OAuth2 via service account using SwiftJWT
    func fetchAccessToken() async -> String? {
        guard let sa = loadServiceAccount(),
              let jwt = makeJWT(serviceAccount: sa),
              let url = URL(string: sa.token_uri)
        else { return nil }
        
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        let bodyString = "grant_type=urn%3Aietf%3Aparams%3Aoauth%3Agrant-type%3Ajwt-bearer&assertion=\(jwt)"
        req.httpBody = bodyString.data(using: .utf8)
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        do {
            let text = try await AppNetwork.shared.fetchTextAsync(request: req)
            guard let data = text.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let token = json["access_token"] as? String
            else { return nil }
            return token
        } catch {
            print("Failed to fetch access token: \(error)")
            return nil
        }
    }
    
    enum tokenError: Error {
        case noAccessToken
    }
    func fetchAccessTokenAsync() async throws -> String {
        if let token = await fetchAccessToken() {
            return token
        } else {
            throw tokenError.noAccessToken
        }
    }
    
    func makeJWT(serviceAccount sa: ServiceAccount) -> String? {
        struct GoogleClaims: Claims {
            let iss: String
            let scope: String
            let aud: String
            let iat: Date
            let exp: Date
        }
        
        let now = Date()
        let claims = GoogleClaims(
            iss: sa.client_email,
            scope: "https://www.googleapis.com/auth/spreadsheets",
            aud: sa.token_uri,
            iat: now,
            exp: now.addingTimeInterval(3600)
        )
        
        var jwt = JWT(header: Header(), claims: claims)
        let pemData = Data(sa.private_key.utf8)
        let signer = JWTSigner.rs256(privateKey: pemData)
        return try? jwt.sign(using: signer)
    }
    
    func loadServiceAccount() -> ServiceAccount? {
        guard let url = Bundle.main.url(forResource: "service-account", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let sa = try? JSONDecoder().decode(ServiceAccount.self, from: data)
        else { return nil }
        return sa
    }
}

struct ServiceAccount: Decodable {
    let client_email: String
    let private_key: String
    let token_uri: String
}
