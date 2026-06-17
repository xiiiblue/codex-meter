import AppKit
import Foundation

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
