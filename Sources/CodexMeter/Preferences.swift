import Foundation

struct RefreshInterval: CaseIterable {
    let title: String
    let seconds: TimeInterval

    static let allCases: [RefreshInterval] = [
        RefreshInterval(title: "1分钟", seconds: 60),
        RefreshInterval(title: "5分钟", seconds: 300),
        RefreshInterval(title: "15分钟", seconds: 900),
        RefreshInterval(title: "30分钟", seconds: 1_800),
        RefreshInterval(title: "60分钟", seconds: 3_600)
    ]

    static let defaultSeconds: TimeInterval = 300

    static func nearest(to seconds: TimeInterval) -> RefreshInterval {
        allCases.min { abs($0.seconds - seconds) < abs($1.seconds - seconds) } ?? allCases[1]
    }
}

enum DisplayMode: String, CaseIterable {
    case dayWeek = "day_week"
    case compact = "compact"
    case lowestOnly = "lowest_only"
    case dayOnly = "day_only"

    var title: String {
        switch self {
        case .dayWeek:
            return "日24% 周32%"
        case .compact:
            return "D24 W32"
        case .lowestOnly:
            return "Codex 24%"
        case .dayOnly:
            return "仅日限额"
        }
    }
}

enum Preferences {
    private static let refreshIntervalKey = "refreshIntervalSeconds"
    private static let displayModeKey = "displayMode"

    static var refreshIntervalSeconds: TimeInterval {
        get {
            let stored = UserDefaults.standard.double(forKey: refreshIntervalKey)
            guard stored > 0 else {
                return RefreshInterval.defaultSeconds
            }
            return RefreshInterval.nearest(to: stored).seconds
        }
        set {
            UserDefaults.standard.set(newValue, forKey: refreshIntervalKey)
        }
    }

    static var displayMode: DisplayMode {
        get {
            guard let rawValue = UserDefaults.standard.string(forKey: displayModeKey),
                  let mode = DisplayMode(rawValue: rawValue) else {
                return .dayWeek
            }
            return mode
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: displayModeKey)
        }
    }
}
