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
    private var cancellable: AnyCancellable?

    func fetchAFD(appRegion: String) {
        guard let regionURL = URL(string: AppRegionManager.shared.getRegionAreaForecastDiscussionURL(appRegion: appRegion) ?? "")
        else {
            print("Invalid AFD URL for appRegion: \(appRegion)")
            return
        }
        cancellable = URLSession.shared.dataTaskPublisher(for: regionURL)
            .map { $0.data }
            .compactMap { String(data: $0, encoding: .utf8) }
            .map { self.parseAFDData($0) }
            .replaceError(with: nil)
            .receive(on: DispatchQueue.main)
            .assign(to: \.AFDvar, on: self)
    }

    private func parseAFDData(_ data: String) -> AFD? {
        guard let startRange = data.range(of: "National Weather Service") else { return nil }
        let AFDData = data[startRange.upperBound...]
        
        // Date expected in a format like: "334 PM MDT Mon Mar 17 2025"
        guard let dateRange = AFDData.range(of: "\\d{3,4} [A-Za-z]{2} [A-Za-z]{3} [A-Za-z]{3} [A-Za-z]{3} \\d{1,2} \\d{4}", options: .regularExpression) else { return nil }
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
