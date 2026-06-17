# CodexMeter项目说明

## 项目目标

构建macOS原生菜单栏应用，直接展示Codex日限额和周限额剩余百分比。

## 当前实现

- 技术栈：SwiftPM + AppKit。
- 入口：`Sources/CodexMeter/main.swift`，只保留命令行`--once`和App启动逻辑。
- 核心模块：`AppDelegate.swift`负责菜单栏UI，`CodexUsageClient.swift`负责只读认证和额度请求，`LoginItemManager.swift`负责LaunchAgent，`Preferences.swift`负责用户设置，`Models.swift`和`MeterError.swift`负责数据类型和错误提示，`Localizer.swift`负责本地化读取。
- 认证文件：默认读取`~/.codex/auth.json`。
- 额度接口：`https://chatgpt.com/backend-api/wham/usage`。
- 显示逻辑：`primary_window.used_percent`视为日限额已用百分比，`secondary_window.used_percent`视为周限额已用百分比，菜单栏显示`100-used_percent`。
- 刷新策略：启动立即刷新；菜单提供手动刷新和刷新频率选择，频率保存到`UserDefaults`，默认5分钟。
- 开机自启：菜单中的`开机自启`会创建或删除用户级LaunchAgent：`~/Library/LaunchAgents/local.codex-meter.plist`，ProgramArguments指向当前App可执行文件。
- 验证命令：`swift run CodexMeter --once`可无GUI拉取并打印剩余额度；`bash scripts/build-app.sh`可生成`.build/CodexMeter.app`。
- 分发打包：`bash scripts/build-app.sh --universal --sign-identity auto --dmg`会构建Universal Binary、自动选择签名身份并按`VERSION`生成`dist/CodexMeter-版本号.dmg`；没有`Developer ID Application`证书时会退回ad-hoc签名，不能替代Apple公证。
- 版本管理：版本号统一来自`VERSION`；发布新版本前用`scripts/bump-version.sh patch|minor|major`递增。
- 发布脚本：`bash scripts/release.sh`会串联Universal构建、DMG、SHA256和Release说明生成；加`--publish`时会创建GitHub Release；同版本Release已存在时默认拒绝覆盖，确认重发时使用`--force`。
- 发布递增：`bash scripts/release.sh --publish --bump patch`会先递增`VERSION`再发布；同版本重发才使用`--force`。
- 应用图标：源PNG为`Assets/AppIcon.png`，App包使用`Assets/AppIcon.icns`，打包脚本会复制到`Contents/Resources`并写入`CFBundleIconFile`。
- 国际化：应用UI文案使用`Sources/CodexMeter/Resources/en.lproj`和`zh-Hans.lproj`，打包脚本会复制`.lproj`目录到App资源目录。

## 后续交接注意

- 不要在日志、README、提交信息或错误输出中写入`access_token`、`refresh_token`、邮箱等敏感信息。
- CodexMeter只能读取`~/.codex/auth.json`，禁止对该文件做任何写操作；不要在应用内刷新`access_token`或使用`refresh_token`，登录态刷新由Codex自己负责。
- 如果Codex后端字段变化，优先用`codex app-server generate-ts`重新查看`GetAccountRateLimitsResponse`、`RateLimitSnapshot`和相关usage字段。
- 若要打包成`.app`，可在现有SwiftPM可执行产物外增加一个轻量bundle脚本，保持App启动入口仍在`Sources/CodexMeter/main.swift`。
- 正式给其他用户分发前，查看`RELEASE.md`中的Developer ID签名、公证、staple和spctl验证流程。
- 后续优化计划记录在`ROADMAP.md`；P3按用户决定暂缓，当前候选项优先考虑增加最小测试。
