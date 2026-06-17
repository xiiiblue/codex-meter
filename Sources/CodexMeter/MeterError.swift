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
            return "找不到认证文件: \(path)"
        case .chatGPTAuthRequired:
            return "需要ChatGPT登录认证"
        case .invalidResponse(let code):
            return "接口返回HTTP \(code)"
        case .codexAuthExpired:
            return "Codex登录态可能已过期"
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
        case .codexAuthExpired:
            return [
                "CodexMeter不会写入认证文件",
                "请在Codex中重新登录或刷新登录态",
                "完成后点“立即刷新”"
            ]
        case .invalidResponse, .noRateLimits:
            return nil
        }
    }
}
