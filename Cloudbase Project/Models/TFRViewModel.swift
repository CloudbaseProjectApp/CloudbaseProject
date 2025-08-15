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
        
        guard let urlString = AppURLManager.shared.getAppURL(URLName: "TFRAPI"),
              let url = URL(string: urlString) else {
            print("Error getting TFR API URL")
            isLoading = false
            return
        }
        
        AppNetwork.shared.fetchJSON(url: url, type: [TFR].self) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                switch result {
                case .success(let tfrList):
                    self.tfrs = tfrList.filter { $0.state == RegionManager.shared.activeAppRegion }
                    self.isLoading = false
                    
                case .failure(let error):
                    print("Error fetching TFRs: \(error)")
                    self.isLoading = false
                }
            }
        }
    }
}
