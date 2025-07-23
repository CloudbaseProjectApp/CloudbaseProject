import SwiftUI
import Combine

struct TFR: Identifiable, Codable {
    var id: String { notam_id }
    let notam_id: String
    let type: String
    let facility: String
    let state: String
    let description: String
    let creation_date: String
}

class TFRViewModel: ObservableObject {
    @Published var tfrs: [TFR] = []
    @Published var isLoading: Bool = false
    
    func fetchTFRs() {
        isLoading = true
        
        guard let url = URL(string: AppURLManager.shared.getAppURL(URLName: "TFRAPI") ?? "<Unknown TFR API URL>") else {
            print("Error getting TFR API URL")
            isLoading = false
            return
        }
        
        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            if let self = self, let data = data {
                do {
                    let tfrList = try JSONDecoder().decode([TFR].self, from: data)
                    DispatchQueue.main.async {
                        self.tfrs = tfrList.filter { $0.state == RegionManager.shared.activeAppRegion }
                        self.isLoading = false
                    }
                } catch {
                    print("Error decoding JSON: \(error)")
                    DispatchQueue.main.async { self.isLoading = false }
                }
            } else {
                print("Error processing TFRs: \(String(describing: error))")
                DispatchQueue.main.async {
                    self?.isLoading = false
                }
            }
        }.resume()
    }
}

