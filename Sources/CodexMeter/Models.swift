import Foundation

struct CodexAuthFile: Codable {
    struct Tokens: Codable {
        var idToken: String?
        var accessToken: String
        var accountId: String?

        enum CodingKeys: String, CodingKey {
            case idToken = "id_token"
            case accessToken = "access_token"
            case accountId = "account_id"
        }
    }

    var authMode: String
    var apiKey: String?
    var tokens: Tokens
    var lastRefresh: String?

    enum CodingKeys: String, CodingKey {
        case authMode = "auth_mode"
        case apiKey = "OPENAI_API_KEY"
        case tokens
        case lastRefresh = "last_refresh"
    }
}

struct UsageResponse: Decodable {
    struct RateLimit: Decodable {
        struct Window: Decodable {
            let usedPercent: Double
            let limitWindowSeconds: Int?
            let resetAt: TimeInterval?

            enum CodingKeys: String, CodingKey {
                case usedPercent = "used_percent"
                case limitWindowSeconds = "limit_window_seconds"
                case resetAt = "reset_at"
            }
        }

        let primaryWindow: Window?
        let secondaryWindow: Window?

        enum CodingKeys: String, CodingKey {
            case primaryWindow = "primary_window"
            case secondaryWindow = "secondary_window"
        }
    }

    let planType: String?
    let rateLimit: RateLimit

    enum CodingKeys: String, CodingKey {
        case planType = "plan_type"
        case rateLimit = "rate_limit"
    }
}

struct LimitSnapshot {
    let titleKey: String
    let remainingPercent: Int
    let resetAt: Date?
}

struct MeterSnapshot {
    let primary: LimitSnapshot?
    let secondary: LimitSnapshot?
    let planType: String?
    let refreshedAt: Date
}
