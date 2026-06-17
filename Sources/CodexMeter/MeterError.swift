import Foundation

enum MeterError: LocalizedError {
    case authFileMissing(String)
    case chatGPTAuthRequired
    case invalidResponse(Int)
    case codexAuthExpired
    case noRateLimits

    var errorDescription: String? {
        switch self {
        case .authFileMissing(let path):
            return L.format("error.authFileMissing", path)
        case .chatGPTAuthRequired:
            return L.text("error.chatGPTAuthRequired")
        case .invalidResponse(let code):
            return L.format("error.invalidResponse", code)
        case .codexAuthExpired:
            return L.text("error.codexAuthExpired")
        case .noRateLimits:
            return L.text("error.noRateLimits")
        }
    }

    var guidanceLines: [String]? {
        switch self {
        case .authFileMissing:
            return [
                L.text("guidance.authMissing.1"),
                L.text("guidance.authMissing.2"),
                L.text("guidance.authMissing.3")
            ]
        case .chatGPTAuthRequired:
            return [
                L.text("guidance.chatGPTRequired.1"),
                L.text("guidance.chatGPTRequired.2"),
                L.text("guidance.chatGPTRequired.3")
            ]
        case .codexAuthExpired:
            return [
                L.text("guidance.authExpired.1"),
                L.text("guidance.authExpired.2"),
                L.text("guidance.authExpired.3")
            ]
        case .invalidResponse, .noRateLimits:
            return nil
        }
    }
}
