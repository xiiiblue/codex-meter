import AppKit
import Foundation

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
