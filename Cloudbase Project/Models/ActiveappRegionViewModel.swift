import Foundation

// activeAppRegion is a globally available variable for the user selected appRegion
//
// Usage:   RegionManager.shared.activeAppRegion
// (except in BaseAppView, which is set to observe the RegionManager, so doesn't need .shared.

import Combine
import Foundation

class RegionManager: ObservableObject {
    static let shared = RegionManager()
    private init() {
        // Initialize from UserDefaults if available
        self.activeAppRegion = UserDefaults.standard.string(forKey: key) ?? ""
    }

    private let key = "activeAppRegion"

    @Published var activeAppRegion: String {
        didSet {
            UserDefaults.standard.set(activeAppRegion, forKey: key)
        }
    }
}
