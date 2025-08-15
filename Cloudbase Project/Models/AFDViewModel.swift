import SwiftUI
import Combine

// Area Forecast Discussion (AFD)
struct AFD: Identifiable {
    let id = UUID()
    let date: String
    let keyMessages: String?    // Used in Colorado, not Utah
    let synopsis: String?
    let discussion: String?     // Sometimes has "DISCUSSION" section
    let shortTerm: String?      // Sometimes has "SHORT TERM" / "LONG TERM" sections
    let longTerm: String?
    let aviation: String?
}

class AFDViewModel: ObservableObject {
    @Published var AFDvar: AFD?
    @Published var isLoading = false
    
    private var cancellable: AnyCancellable?
    
    func fetchAFD(airportCode: String) {
        isLoading = true
        
        // Get base URL
        guard let baseURL = AppURLManager.shared.getAppURL(URLName: "areaForecastDiscussionURL") else {
            print("Could not find AFD URL for appRegion: \(RegionManager.shared.activeAppRegion)")
            isLoading = false
            return
        }
        
        let updatedURL = updateURL(url: baseURL, parameter: "airportcode", value: airportCode)
        guard let url = URL(string: updatedURL) else {
            print("Invalid AFD URL for appRegion: \(RegionManager.shared.activeAppRegion)")
            isLoading = false
            return
        }
        
        // Fetch as text using centralized network wrapper
        AppNetwork.shared.fetchText(url: url) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                switch result {
                case .success(let text):
                    self.AFDvar = self.parseAFDData(text)
                case .failure(let error):
                    print("Failed to fetch AFD: \(error)")
                    self.AFDvar = nil
                }
                
                self.isLoading = false
            }
        }
    }
    
    private func parseAFDData(_ data: String) -> AFD? {
        guard let startRange = data.range(of: "National Weather Service") else {
            print("Could not parse AFD start range")
            return nil
        }
        
        let afdData = data[startRange.upperBound...]
        
        guard let dateRange = afdData.range(of: "\\d{3,4} [A-Za-z]{2} [A-Za-z]{3} [A-Za-z]{3} [A-Za-z]{3} \\d{1,2} \\d{4}",
                                           options: .regularExpression) else {
            print("Could not parse AFD date range")
            return nil
        }
        
        let date = String(afdData[dateRange])
        
        let keyMessages = collapseTextLines(extractSection(from: afdData, start: ".KEY MESSAGES", end: "&&"))
        let synopsis = collapseTextLines(extractSection(from: afdData, start: ".SYNOPSIS", end: "&&"))
        let discussion = collapseTextLines(extractSection(from: afdData, start: ".DISCUSSION", end: "&&"))
        let shortTerm = collapseTextLines(extractSection(from: afdData, start: ".SHORT TERM", end: ".LONG TERM"))
        let longTerm = collapseTextLines(extractSection(from: afdData, start: ".LONG TERM", end: "&&"))
        let aviation = collapseTextLines(extractSection(from: afdData, start: ".AVIATION", end: "&&"))
        
        return AFD(date: date,
                   keyMessages: keyMessages,
                   synopsis: synopsis,
                   discussion: discussion,
                   shortTerm: shortTerm,
                   longTerm: longTerm,
                   aviation: aviation)
    }
}
