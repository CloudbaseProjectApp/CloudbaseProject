import SwiftUI
import Combine

// Area Forecast Discussion (AFD)
struct AFD: Identifiable {
    let id = UUID()
    let date: String
    let keyMessages: String?    // Used in Colorado, not Utah
    let synopsis: String?
    let discussion: String?     // Sometimes, AFD has a "DISCUSSION" section
    let shortTerm: String?      // and somethines it has "SHORT TERM" and "LONG TERM" sections instead
    let longTerm: String?
    let aviation: String?
}
class AFDViewModel: ObservableObject {
    @Published var AFDvar: AFD?
    @Published var isLoading = false
    private var cancellable: AnyCancellable?
    
    func fetchAFD(airportCode: String) {
        isLoading = true

        // Get base URL, update parameters, and format into URL format
        guard let baseURL = AppURLManager.shared.getAppURL(URLName: "areaForecastDiscussionURL")
        else {
            print("Could not find AFD URL for appRegion: \(RegionManager.shared.activeAppRegion)")
            isLoading = false
            return
        }
        let updatedURL = updateURL(url: baseURL, parameter: "airportcode", value: airportCode)
        
        // Format URL
        guard let URL = URL(string: updatedURL)
        else {
            print("Invalid AFD URL for appRegion: \(RegionManager.shared.activeAppRegion)")
            isLoading = false
            return
        }

        // Process URL query
        cancellable = URLSession.shared.dataTaskPublisher(for: URL)
            .map { $0.data }
            .map { String(data: $0, encoding: .utf8) }
            .map { $0.flatMap(self.parseAFDData) }
            .replaceError(with: nil)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] afd in
                self?.AFDvar     = afd
                self?.isLoading  = false
            }
    }

    private func parseAFDData(_ data: String) -> AFD? {
        guard let startRange = data.range(of: "National Weather Service") else {
            print("Could not parse AFD start range")
            return nil
        }

        let AFDData = data[startRange.upperBound...]

        guard let dateRange = AFDData.range(of: "\\d{3,4} [A-Za-z]{2} [A-Za-z]{3} [A-Za-z]{3} [A-Za-z]{3} \\d{1,2} \\d{4}", options: .regularExpression) else {
            print("Could not parse AFD date range")
            return nil
        }

        let date = String(AFDData[dateRange])
        
        let keyMessages = collapseTextLines(extractSection(from: AFDData, start: ".KEY MESSAGES", end: "&&"))
        let synopsis = collapseTextLines(extractSection(from: AFDData, start: ".SYNOPSIS", end: "&&"))
        let discussion = collapseTextLines(extractSection(from: AFDData, start: ".DISCUSSION", end: "&&"))
        let shortTerm = collapseTextLines(extractSection(from: AFDData, start: ".SHORT TERM", end: ".LONG TERM"))
        let longTerm = collapseTextLines(extractSection(from: AFDData, start: ".LONG TERM", end: "&&"))
        let aviation = collapseTextLines(extractSection(from: AFDData, start: ".AVIATION", end: "&&"))
        
        return AFD(date: date,
                   keyMessages: keyMessages,
                   synopsis: synopsis,
                   discussion: discussion,
                   shortTerm: shortTerm,
                   longTerm: longTerm,
                   aviation: aviation)
    }
}
