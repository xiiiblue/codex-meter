# CodexMeter项目说明

## 项目目标

构建macOS原生菜单栏应用，直接展示Codex日限额和周限额剩余百分比。

## 当前实现

- 技术栈：SwiftPM + AppKit。
- 入口：`Sources/CodexMeter/main.swift`。
- 认证文件：默认读取`~/.codex/auth.json`。
- 额度接口：`https://chatgpt.com/backend-api/wham/usage`。
- 显示逻辑：`primary_window.used_percent`视为日限额已用百分比，`secondary_window.used_percent`视为周限额已用百分比，菜单栏显示`100-used_percent`。
- 刷新策略：启动立即刷新；菜单提供手动刷新和刷新频率选择，频率保存到`UserDefaults`，默认5分钟。
- 开机自启：菜单中的`开机自启`会创建或删除用户级LaunchAgent：`~/Library/LaunchAgents/local.codex-meter.plist`，ProgramArguments指向当前App可执行文件。
- 验证命令：`swift run CodexMeter --once`可无GUI拉取并打印剩余额度；`bash scripts/build-app.sh`可生成`.build/CodexMeter.app`。
- 应用图标：源PNG为`Assets/AppIcon.png`，App包使用`Assets/AppIcon.icns`，打包脚本会复制到`Contents/Resources`并写入`CFBundleIconFile`。

## 后续交接注意

- 不要在日志、README、提交信息或错误输出中写入`access_token`、`refresh_token`、邮箱等敏感信息。
- 如果Codex后端字段变化，优先用`codex app-server generate-ts`重新查看`GetAccountRateLimitsResponse`、`RateLimitSnapshot`和相关usage字段。
- 若要打包成`.app`，可在现有SwiftPM可执行产物外增加一个轻量bundle脚本，保持主逻辑仍在`Sources/CodexMeter/main.swift`。
