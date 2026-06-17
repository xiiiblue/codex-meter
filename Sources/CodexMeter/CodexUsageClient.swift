import Foundation

@MainActor
final class CodexUsageClient {
    private let authPath: String
    private let usageURL = URL(string: "https://chatgpt.com/backend-api/wham/usage")!
    private let session = URLSession.shared

    init(authPath: String) {
        self.authPath = authPath
    }

    func fetchUsage() async throws -> MeterSnapshot {
        let auth = try loadAuth()
        return try await requestUsage(auth)
    }

    private func loadAuth() throws -> CodexAuthFile {
        guard FileManager.default.fileExists(atPath: authPath) else {
            throw MeterError.authFileMissing(authPath)
        }

        let data = try Data(contentsOf: URL(fileURLWithPath: authPath))
        let auth = try JSONDecoder().decode(CodexAuthFile.self, from: data)
        guard auth.authMode == "chatgpt" else {
            throw MeterError.chatGPTAuthRequired
        }
        return auth
    }

    private func requestUsage(_ auth: CodexAuthFile) async throws -> MeterSnapshot {
        var request = URLRequest(url: usageURL)
        request.httpMethod = "GET"
        request.setValue("Bearer \(auth.tokens.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("CodexMeter/0.1", forHTTPHeaderField: "User-Agent")
        if let accountId = auth.tokens.accountId {
            request.setValue(accountId, forHTTPHeaderField: "ChatGPT-Account-ID")
        }

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw MeterError.invalidResponse(-1)
        }
        if http.statusCode == 401 {
            throw MeterError.codexAuthExpired
        }
        guard (200..<300).contains(http.statusCode) else {
            throw MeterError.invalidResponse(http.statusCode)
        }

        let usage = try JSONDecoder().decode(UsageResponse.self, from: data)
        let primary = snapshot(titleKey: "limit.day", window: usage.rateLimit.primaryWindow)
        let secondary = snapshot(titleKey: "limit.week", window: usage.rateLimit.secondaryWindow)
        guard primary != nil || secondary != nil else {
            throw MeterError.noRateLimits
        }

        return MeterSnapshot(
            primary: primary,
            secondary: secondary,
            planType: usage.planType,
            refreshedAt: Date()
        )
    }

    private func snapshot(titleKey: String, window: UsageResponse.RateLimit.Window?) -> LimitSnapshot? {
        guard let window else {
            return nil
        }

        let remaining = max(0, min(100, Int((100 - window.usedPercent).rounded())))
        let resetAt = window.resetAt.map { Date(timeIntervalSince1970: $0) }
        return LimitSnapshot(titleKey: titleKey, remainingPercent: remaining, resetAt: resetAt)
    }
}
