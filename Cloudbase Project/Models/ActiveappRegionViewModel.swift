import Foundation

// activeAppRegion is a globally available variable for the user selected appRegion
//
// Usage:   RegionManager.shared.activeAppRegion

class RegionManager {
    static let shared = RegionManager()
    private init() {}

    private let key = "activeAppRegion"

    var activeAppRegion: String {
        get {
            UserDefaults.standard.string(forKey: key) ?? ""
        }
        set {
            UserDefaults.standard.set(newValue, forKey: key)
        }
    }
}
