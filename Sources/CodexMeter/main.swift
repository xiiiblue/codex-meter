import AppKit
import Foundation

struct CodexAuthFile: Codable {
    struct Tokens: Codable {
        var idToken: String?
        var accessToken: String
        var refreshToken: String?
        var accountId: String?

        enum CodingKeys: String, CodingKey {
            case idToken = "id_token"
            case accessToken = "access_token"
            case refreshToken = "refresh_token"
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
    let title: String
    let remainingPercent: Int
    let resetAt: Date?
}

struct MeterSnapshot {
    let primary: LimitSnapshot?
    let secondary: LimitSnapshot?
    let planType: String?
    let refreshedAt: Date
}

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

enum MeterError: LocalizedError {
    case authFileMissing(String)
    case chatGPTAuthRequired
    case invalidResponse(Int)
    case noRateLimits

    var errorDescription: String? {
        switch self {
        case .authFileMissing(let path):
            return "找不到认证文件: \(path)"
        case .chatGPTAuthRequired:
            return "需要ChatGPT登录认证"
        case .invalidResponse(let code):
            return "接口返回HTTP \(code)"
        case .noRateLimits:
            return "接口没有返回额度窗口"
        }
    }

    var guidanceLines: [String]? {
        switch self {
        case .authFileMissing:
            return [
                "未检测到Codex登录认证",
                "请先运行: codex login",
                "完成登录后点“立即刷新”"
            ]
        case .chatGPTAuthRequired:
            return [
                "当前不是ChatGPT登录态",
                "请重新运行: codex login",
                "登录时选择ChatGPT账号"
            ]
        case .invalidResponse, .noRateLimits:
            return nil
        }
    }
}

@MainActor
final class LoginItemManager {
    enum Status {
        case disabled
        case enabled
        case stale(savedPath: String)
    }

    static let shared = LoginItemManager()

    private let label = "local.codex-meter"
    private let fileManager = FileManager.default

    private var launchAgentsDirectory: URL {
        fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("LaunchAgents", isDirectory: true)
    }

    private var plistURL: URL {
        launchAgentsDirectory.appendingPathComponent("\(label).plist")
    }

    var currentExecutablePath: String {
        Bundle.main.executableURL?.path ?? CommandLine.arguments[0]
    }

    var status: Status {
        guard fileManager.fileExists(atPath: plistURL.path) else {
            return .disabled
        }
        guard let plist = NSDictionary(contentsOf: plistURL) as? [String: Any],
              let programArguments = plist["ProgramArguments"] as? [String],
              let savedPath = programArguments.first else {
            return .stale(savedPath: "未知路径")
        }
        return savedPath == currentExecutablePath ? .enabled : .stale(savedPath: savedPath)
    }

    func setEnabled(_ enabled: Bool) throws {
        if enabled {
            try enable()
        } else {
            try disable()
        }
    }

    private func enable() throws {
        try fileManager.createDirectory(at: launchAgentsDirectory, withIntermediateDirectories: true)
        let plist: [String: Any] = [
            "Label": label,
            "ProgramArguments": [currentExecutablePath],
            "RunAtLoad": true,
            "KeepAlive": false,
            "StandardOutPath": "/tmp/CodexMeter.out.log",
            "StandardErrorPath": "/tmp/CodexMeter.err.log"
        ]
        let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        try data.write(to: plistURL, options: .atomic)
    }

    private func disable() throws {
        guard fileManager.fileExists(atPath: plistURL.path) else {
            return
        }
        try fileManager.removeItem(at: plistURL)
    }
}

@MainActor
final class CodexUsageClient {
    private let authPath: String
    private let usageURL = URL(string: "https://chatgpt.com/backend-api/wham/usage")!
    private let refreshURL = URL(string: "https://auth.openai.com/oauth/token")!
    private let codexClientID = "app_EMoamEEZ73f0CkXaXp7hrann"
    private let session = URLSession.shared

    init(authPath: String) {
        self.authPath = authPath
    }

    func fetchUsage() async throws -> MeterSnapshot {
        var auth = try loadAuth()
        if tokenExpiresSoon(auth.tokens.accessToken) {
            auth = try await refresh(auth)
        }

        do {
            return try await requestUsage(auth)
        } catch MeterError.invalidResponse(401) {
            auth = try await refresh(auth)
            return try await requestUsage(auth)
        }
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
        guard (200..<300).contains(http.statusCode) else {
            throw MeterError.invalidResponse(http.statusCode)
        }

        let usage = try JSONDecoder().decode(UsageResponse.self, from: data)
        let primary = snapshot(title: "日限额", window: usage.rateLimit.primaryWindow)
        let secondary = snapshot(title: "周限额", window: usage.rateLimit.secondaryWindow)
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

    private func snapshot(title: String, window: UsageResponse.RateLimit.Window?) -> LimitSnapshot? {
        guard let window else {
            return nil
        }

        let remaining = max(0, min(100, Int((100 - window.usedPercent).rounded())))
        let resetAt = window.resetAt.map { Date(timeIntervalSince1970: $0) }
        return LimitSnapshot(title: title, remainingPercent: remaining, resetAt: resetAt)
    }

    private func refresh(_ auth: CodexAuthFile) async throws -> CodexAuthFile {
        guard let refreshToken = auth.tokens.refreshToken, !refreshToken.isEmpty else {
            throw MeterError.invalidResponse(401)
        }

        var components = URLComponents()
        components.queryItems = [
            URLQueryItem(name: "grant_type", value: "refresh_token"),
            URLQueryItem(name: "refresh_token", value: refreshToken),
            URLQueryItem(name: "client_id", value: codexClientID)
        ]

        var request = URLRequest(url: refreshURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = components.percentEncodedQuery?.data(using: .utf8)

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw MeterError.invalidResponse(-1)
        }
        guard (200..<300).contains(http.statusCode) else {
            throw MeterError.invalidResponse(http.statusCode)
        }

        struct RefreshResponse: Decodable {
            let accessToken: String
            let idToken: String?
            let refreshToken: String?

            enum CodingKeys: String, CodingKey {
                case accessToken = "access_token"
                case idToken = "id_token"
                case refreshToken = "refresh_token"
            }
        }

        let refreshed = try JSONDecoder().decode(RefreshResponse.self, from: data)
        var next = auth
        next.tokens.accessToken = refreshed.accessToken
        next.tokens.idToken = refreshed.idToken ?? next.tokens.idToken
        next.tokens.refreshToken = refreshed.refreshToken ?? next.tokens.refreshToken
        next.lastRefresh = ISO8601DateFormatter().string(from: Date())
        try saveAuth(next)
        return next
    }

    private func saveAuth(_ auth: CodexAuthFile) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(auth)
        let url = URL(fileURLWithPath: authPath)
        let tmp = url.deletingLastPathComponent().appendingPathComponent(".auth.json.codex-meter.tmp")
        try data.write(to: tmp, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: tmp.path)
        _ = try FileManager.default.replaceItemAt(url, withItemAt: tmp)
    }

    private func tokenExpiresSoon(_ jwt: String) -> Bool {
        let parts = jwt.split(separator: ".")
        guard parts.count >= 2,
              let payload = decodeBase64URL(String(parts[1])),
              let object = try? JSONSerialization.jsonObject(with: payload) as? [String: Any],
              let exp = object["exp"] as? TimeInterval else {
            return false
        }

        return Date(timeIntervalSince1970: exp).timeIntervalSinceNow < 300
    }

    private func decodeBase64URL(_ value: String) -> Data? {
        var base64 = value.replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let padding = (4 - base64.count % 4) % 4
        base64 += String(repeating: "=", count: padding)
        return Data(base64Encoded: base64)
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var menu: NSMenu!
    private var timer: Timer?
    private var client: CodexUsageClient!
    private var latestSnapshot: MeterSnapshot?
    private var latestRefreshError: String?
    private var latestRefreshErrorAt: Date?
    private let authPath = NSString(string: "~/.codex/auth.json").expandingTildeInPath

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        client = CodexUsageClient(authPath: authPath)
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.font = NSFont.monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .semibold)
        statusItem.button?.title = "Codex ..."

        rebuildMenu(message: "正在刷新...")
        refresh()
        scheduleTimer()
    }

    private func scheduleTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: Preferences.refreshIntervalSeconds, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refresh()
            }
        }
    }

    private func refresh() {
        Task {
            do {
                let snapshot = try await client.fetchUsage()
                latestSnapshot = snapshot
                latestRefreshError = nil
                latestRefreshErrorAt = nil
                render(snapshot)
            } catch {
                render(error)
            }
        }
    }

    private func render(_ snapshot: MeterSnapshot) {
        statusItem.button?.title = statusTitle(for: snapshot)
        rebuildMenu(snapshot: snapshot, refreshError: latestRefreshError)
    }

    private func render(_ error: Error) {
        latestRefreshError = error.localizedDescription
        latestRefreshErrorAt = Date()
        if let latestSnapshot {
            rebuildMenu(snapshot: latestSnapshot, refreshError: latestRefreshError)
        } else {
            statusItem.button?.title = "Codex !"
            rebuildMenu(message: error.localizedDescription, guidance: guidanceLines(for: error))
        }
    }

    private func rebuildMenu(
        snapshot: MeterSnapshot? = nil,
        message: String? = nil,
        refreshError: String? = nil,
        guidance: [String]? = nil
    ) {
        menu = NSMenu()

        if let snapshot {
            addLimitItem(snapshot.primary)
            addLimitItem(snapshot.secondary)
            let warnings = lowQuotaWarnings(for: snapshot)
            if !warnings.isEmpty {
                menu.addItem(.separator())
                for warning in warnings {
                    menu.addItem(NSMenuItem(title: warning, action: nil, keyEquivalent: ""))
                }
            }
            menu.addItem(.separator())
            if let planType = snapshot.planType {
                menu.addItem(NSMenuItem(title: "订阅: \(planType)", action: nil, keyEquivalent: ""))
            }
            menu.addItem(NSMenuItem(title: "上次成功刷新: \(format(snapshot.refreshedAt))", action: nil, keyEquivalent: ""))
            if let nextRefreshAt = timer?.fireDate {
                menu.addItem(NSMenuItem(title: "下次刷新: \(format(nextRefreshAt))", action: nil, keyEquivalent: ""))
            }
            if let refreshError {
                menu.addItem(.separator())
                let failedAt = latestRefreshErrorAt.map(format) ?? "未知时间"
                menu.addItem(NSMenuItem(title: "上次刷新失败: \(failedAt)", action: nil, keyEquivalent: ""))
                menu.addItem(NSMenuItem(title: "失败原因: \(refreshError)", action: nil, keyEquivalent: ""))
            }
        } else if let message {
            menu.addItem(NSMenuItem(title: message, action: nil, keyEquivalent: ""))
            if let guidance, !guidance.isEmpty {
                menu.addItem(.separator())
                for line in guidance {
                    menu.addItem(NSMenuItem(title: line, action: nil, keyEquivalent: ""))
                }
            }
        }

        menu.addItem(.separator())
        let refreshItem = NSMenuItem(title: "立即刷新", action: #selector(refreshFromMenu), keyEquivalent: "r")
        refreshItem.target = self
        menu.addItem(refreshItem)
        addSettingsItems()
        menu.addItem(NSMenuItem(title: "认证文件: \(authPath)", action: nil, keyEquivalent: ""))
        menu.addItem(.separator())
        let quitItem = NSMenuItem(title: "退出", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    private func addSettingsItems() {
        let loginStatus = LoginItemManager.shared.status
        if case .stale = loginStatus {
            menu.addItem(NSMenuItem(title: "开机自启路径已过期", action: nil, keyEquivalent: ""))
        }

        let loginItem = NSMenuItem(title: "开机自启", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
        loginItem.target = self
        loginItem.state = isLaunchAtLoginEnabled(loginStatus) ? .on : .off
        menu.addItem(loginItem)

        if case .stale = loginStatus {
            let repairItem = NSMenuItem(title: "修复开机自启路径", action: #selector(repairLaunchAtLogin), keyEquivalent: "")
            repairItem.target = self
            menu.addItem(repairItem)
        }

        let currentInterval = Preferences.refreshIntervalSeconds
        let intervalItem = NSMenuItem(title: "刷新频率", action: nil, keyEquivalent: "")
        let intervalMenu = NSMenu()
        for option in RefreshInterval.allCases {
            let item = NSMenuItem(title: option.title, action: #selector(setRefreshInterval), keyEquivalent: "")
            item.target = self
            item.representedObject = option.seconds
            item.state = option.seconds == currentInterval ? .on : .off
            intervalMenu.addItem(item)
        }
        intervalItem.submenu = intervalMenu
        menu.addItem(intervalItem)

        let currentDisplayMode = Preferences.displayMode
        let displayModeItem = NSMenuItem(title: "显示模式", action: nil, keyEquivalent: "")
        let displayModeMenu = NSMenu()
        for mode in DisplayMode.allCases {
            let item = NSMenuItem(title: mode.title, action: #selector(setDisplayMode), keyEquivalent: "")
            item.target = self
            item.representedObject = mode.rawValue
            item.state = mode == currentDisplayMode ? .on : .off
            displayModeMenu.addItem(item)
        }
        displayModeItem.submenu = displayModeMenu
        menu.addItem(displayModeItem)
    }

    private func addLimitItem(_ limit: LimitSnapshot?) {
        guard let limit else {
            return
        }

        let reset = limit.resetAt.map { "，重置: \(format($0))（\(relativeTimeDescription(until: $0))）" } ?? ""
        menu.addItem(NSMenuItem(title: "\(limit.title): 剩余\(limit.remainingPercent)%\(reset)", action: nil, keyEquivalent: ""))
    }

    private func lowQuotaWarnings(for snapshot: MeterSnapshot) -> [String] {
        [snapshot.primary, snapshot.secondary].compactMap { limit in
            guard let limit else {
                return nil
            }
            if limit.remainingPercent <= 10 {
                return "\(limit.title)额度告急：仅剩\(limit.remainingPercent)%"
            }
            if limit.remainingPercent <= 20 {
                return "\(limit.title)额度偏低：剩余\(limit.remainingPercent)%"
            }
            return nil
        }
    }

    private func relativeTimeDescription(until date: Date) -> String {
        let interval = max(0, date.timeIntervalSinceNow)
        let minutes = Int(interval / 60)
        if minutes < 60 {
            return "约\(max(1, minutes))分钟后"
        }

        let hours = minutes / 60
        if hours < 48 {
            return "约\(hours)小时后"
        }

        let days = hours / 24
        return "约\(days)天后"
    }

    private func format(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    @objc private func refreshFromMenu() {
        refresh()
    }

    @objc private func toggleLaunchAtLogin() {
        do {
            let shouldEnable = !isLaunchAtLoginEnabled(LoginItemManager.shared.status)
            try LoginItemManager.shared.setEnabled(shouldEnable)
            rebuildCurrentMenu()
        } catch {
            showError("无法更新开机自启: \(error.localizedDescription)")
        }
    }

    @objc private func repairLaunchAtLogin() {
        do {
            try LoginItemManager.shared.setEnabled(true)
            rebuildCurrentMenu()
        } catch {
            showError("无法修复开机自启路径: \(error.localizedDescription)")
        }
    }

    @objc private func setRefreshInterval(_ sender: NSMenuItem) {
        guard let seconds = sender.representedObject as? TimeInterval else {
            return
        }
        Preferences.refreshIntervalSeconds = seconds
        scheduleTimer()
        rebuildCurrentMenu()
    }

    @objc private func setDisplayMode(_ sender: NSMenuItem) {
        guard let rawValue = sender.representedObject as? String,
              let mode = DisplayMode(rawValue: rawValue) else {
            return
        }
        Preferences.displayMode = mode
        if let latestSnapshot {
            render(latestSnapshot)
        } else {
            rebuildCurrentMenu()
        }
    }

    private func rebuildCurrentMenu() {
        if let latestSnapshot {
            rebuildMenu(snapshot: latestSnapshot, refreshError: latestRefreshError)
        } else {
            rebuildMenu(message: "正在刷新...")
        }
    }

    private func guidanceLines(for error: Error) -> [String]? {
        if let meterError = error as? MeterError {
            return meterError.guidanceLines
        }
        return nil
    }

    private func isLaunchAtLoginEnabled(_ status: LoginItemManager.Status) -> Bool {
        switch status {
        case .disabled:
            return false
        case .enabled, .stale:
            return true
        }
    }

    private func statusTitle(for snapshot: MeterSnapshot) -> String {
        let day = snapshot.primary?.remainingPercent
        let week = snapshot.secondary?.remainingPercent

        switch Preferences.displayMode {
        case .dayWeek:
            return "日\(percentText(day)) 周\(percentText(week))"
        case .compact:
            return "D\(percentText(day)) W\(percentText(week))"
        case .lowestOnly:
            let values = [day, week].compactMap { $0 }
            return "Codex \(percentText(values.min()))"
        case .dayOnly:
            return "日\(percentText(day))"
        }
    }

    private func percentText(_ value: Int?) -> String {
        guard let value else {
            return "--%"
        }
        return "\(value)%"
    }

    private func showError(_ message: String) {
        let alert = NSAlert()
        alert.messageText = "CodexMeter"
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.runModal()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}

let authPath = NSString(string: "~/.codex/auth.json").expandingTildeInPath

if CommandLine.arguments.contains("--once") {
    Task { @MainActor in
        do {
            let snapshot = try await CodexUsageClient(authPath: authPath).fetchUsage()
            let day = snapshot.primary?.remainingPercent
            let week = snapshot.secondary?.remainingPercent
            print("日\(day.map(String.init) ?? "--")% 周\(week.map(String.init) ?? "--")%")
            exit(0)
        } catch {
            fputs("\(error.localizedDescription)\n", stderr)
            exit(1)
        }
    }
    RunLoop.main.run()
} else {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.run()
}
