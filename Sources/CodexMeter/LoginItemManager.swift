import Foundation

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
            return .stale(savedPath: L.text("path.unknown"))
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
