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
        case .ja:
            return Locale(identifier: "ja")
        case .ko:
            return Locale(identifier: "ko")
        case .es:
            return Locale(identifier: "es")
        case .fr:
            return Locale(identifier: "fr")
        case .de:
            return Locale(identifier: "de")
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
        let roots = resourceRoots()
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

    private static func resourceRoots() -> [Bundle] {
        if Bundle.main.bundleURL.pathExtension == "app" {
            return [Bundle.main]
        }
        return [Bundle.main, Bundle.module]
    }

    private static func preferredLocalizations() -> [String] {
        switch Preferences.appLanguage {
        case .system:
            break
        case .zhHans:
            return ["zh-Hans", "en"]
        case .en:
            return ["en"]
        case .ja:
            return ["ja", "en"]
        case .ko:
            return ["ko", "en"]
        case .es:
            return ["es", "en"]
        case .fr:
            return ["fr", "en"]
        case .de:
            return ["de", "en"]
        }

        let preferences = UserDefaults.standard.stringArray(forKey: "AppleLanguages") ?? Locale.preferredLanguages
        var result: [String] = []
        for language in preferences {
            let normalized = language.replacingOccurrences(of: "_", with: "-").lowercased()
            if normalized.hasPrefix("zh") {
                result.append("zh-Hans")
            } else if normalized.hasPrefix("en") {
                result.append("en")
            } else if normalized.hasPrefix("ja") {
                result.append("ja")
            } else if normalized.hasPrefix("ko") {
                result.append("ko")
            } else if normalized.hasPrefix("es") {
                result.append("es")
            } else if normalized.hasPrefix("fr") {
                result.append("fr")
            } else if normalized.hasPrefix("de") {
                result.append("de")
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
