import Foundation

enum L {
    static var locale: Locale {
        switch Preferences.appLanguage {
        case .system:
            return Locale.current
        case .zhHans:
            return Locale(identifier: "zh_Hans")
        case .en:
            return Locale(identifier: "en")
        }
    }

    static func text(_ key: String) -> String {
        for bundle in localizedBundles() {
            let value = bundle.localizedString(forKey: key, value: key, table: nil)
            if value != key {
                return value
            }
        }
        return key
    }

    static func format(_ key: String, _ arguments: CVarArg...) -> String {
        String(format: text(key), locale: locale, arguments: arguments)
    }

    private static func localizedBundles() -> [Bundle] {
        let roots = [Bundle.main, Bundle.module]
        var bundles: [Bundle] = []
        for language in preferredLocalizations() {
            for root in roots {
                for resourceName in [language, language.lowercased()] {
                    if let path = root.path(forResource: resourceName, ofType: "lproj"),
                       let bundle = Bundle(path: path) {
                        bundles.append(bundle)
                    }
                }
            }
        }
        bundles.append(contentsOf: roots)
        return bundles
    }

    private static func preferredLocalizations() -> [String] {
        switch Preferences.appLanguage {
        case .system:
            break
        case .zhHans:
            return ["zh-Hans", "en"]
        case .en:
            return ["en"]
        }

        let preferences = UserDefaults.standard.stringArray(forKey: "AppleLanguages") ?? Locale.preferredLanguages
        var result: [String] = []
        for language in preferences {
            let normalized = language.replacingOccurrences(of: "_", with: "-").lowercased()
            if normalized.hasPrefix("zh") {
                result.append("zh-Hans")
            } else if normalized.hasPrefix("en") {
                result.append("en")
            }
        }
        result.append("en")
        return result.reduce(into: []) { unique, language in
            if !unique.contains(language) {
                unique.append(language)
            }
        }
    }
}
