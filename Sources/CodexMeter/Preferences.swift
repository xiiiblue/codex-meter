import Foundation

struct RefreshInterval: CaseIterable {
    let titleKey: String
    let seconds: TimeInterval

    static let allCases: [RefreshInterval] = [
        RefreshInterval(titleKey: "refreshInterval.1m", seconds: 60),
        RefreshInterval(titleKey: "refreshInterval.5m", seconds: 300),
        RefreshInterval(titleKey: "refreshInterval.15m", seconds: 900),
        RefreshInterval(titleKey: "refreshInterval.30m", seconds: 1_800),
        RefreshInterval(titleKey: "refreshInterval.60m", seconds: 3_600)
    ]

    static let defaultSeconds: TimeInterval = 300

    var title: String {
        L.text(titleKey)
    }

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
            return L.text("displayMode.dayWeek")
        case .compact:
            return "D24 W32"
        case .lowestOnly:
            return "Codex 24%"
        case .dayOnly:
            return L.text("displayMode.dayOnly")
        }
    }
}

enum AppLanguage: String, CaseIterable {
    case system
    case zhHans = "zh-Hans"
    case en

    var title: String {
        switch self {
        case .system:
            return L.text("language.system")
        case .zhHans:
            return L.text("language.zhHans")
        case .en:
            return L.text("language.english")
        }
    }
}

enum Preferences {
    private static let refreshIntervalKey = "refreshIntervalSeconds"
    private static let displayModeKey = "displayMode"
    private static let appLanguageKey = "appLanguage"

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

    static var appLanguage: AppLanguage {
        get {
            guard let rawValue = UserDefaults.standard.string(forKey: appLanguageKey),
                  let language = AppLanguage(rawValue: rawValue) else {
                return .system
            }
            return language
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: appLanguageKey)
        }
    }
}
