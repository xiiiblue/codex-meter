# CodexMeter

CodexMeter是一个macOS原生菜单栏小工具，用当前机器的Codex登录态读取ChatGPT账号的Codex额度，并在菜单栏显示日限额和周限额剩余百分比。

## 功能

- 菜单栏直接显示`日xx% 周xx%`。
- 支持菜单栏显示模式切换：标准、紧凑、仅最低额度、仅日限额。
- 下拉菜单显示日限额、周限额、重置时间、订阅类型和最近刷新时间。
- 支持手动刷新。
- 支持开机自启。
- 支持刷新频率配置：`1分钟`、`5分钟`、`15分钟`、`30分钟`、`60分钟`。
- 支持无GUI验证模式：`swift run CodexMeter --once`。

## 环境要求

- macOS14或更高版本。
- 已安装Xcode或Swift工具链。
- 已在本机Codex中通过ChatGPT登录，默认需要存在`~/.codex/auth.json`。

## 运行

```bash
swift run CodexMeter
```

菜单栏会显示：

```text
日45% 周35%
```

下拉菜单包含手动刷新、开机自启、刷新频率、订阅类型、刷新时间和额度重置时间。

也可以先做一次无GUI验证：

```bash
swift run CodexMeter --once
```

## 打包成App

```bash
bash scripts/build-app.sh
open .build/CodexMeter.app
```

应用图标源文件位于`Assets/AppIcon.png`，打包使用`Assets/AppIcon.icns`。
DMG背景图位于`Assets/Installer/DmgBackground.png`。

生成可分发的Universal Binary和DMG：

```bash
bash scripts/build-app.sh --universal --sign-identity auto --dmg
```

输出文件：

```text
.build/CodexMeter.app
dist/CodexMeter-0.1.0.dmg
dist/CodexMeter-0.1.0.dmg.sha256
```

如果本机没有`Developer ID Application`证书，`--sign-identity auto`会退回ad-hoc签名。ad-hoc签名不等于Apple公证，陌生机器首次打开仍可能被Gatekeeper拦截。正式分发请参考[RELEASE.md](./RELEASE.md)。

## 未公证DMG安装

不付费使用Apple Developer Program时，可以分发未公证DMG。用户安装步骤：

1. 打开`CodexMeter-0.1.0.dmg`。
2. 将`CodexMeter.app`拖到`Applications`。
3. 第一次按住Control点击或右键点击`CodexMeter.app`，选择`打开`。
4. 如果macOS提示无法验证开发者，继续选择`打开`；如果仍被阻止，到`系统设置 > 隐私与安全性`中允许打开。

DMG里也包含`首次打开说明.txt`。

## 选项

- 开机自启：在菜单里勾选`开机自启`后，会写入用户级LaunchAgent：`~/Library/LaunchAgents/local.codex-meter.plist`。
- 刷新频率：菜单里可选`1分钟`、`5分钟`、`15分钟`、`30分钟`、`60分钟`，选择会保存到`UserDefaults`并立即重建刷新计时器。
- 显示模式：菜单里可切换`日24% 周32%`、`D24 W32`、`Codex 24%`、`仅日限额`。

## 项目结构

```text
.
├── Assets/
│   ├── AppIcon.icns
│   ├── AppIcon.png
│   └── Installer/DmgBackground.png
├── Sources/CodexMeter/main.swift
├── scripts/build-app.sh
├── scripts/release.sh
├── Package.swift
├── README.md
└── AGENTS.md
```

## 数据来源

- 默认读取`~/.codex/auth.json`。
- 需要`auth_mode`为`chatgpt`，也就是已经通过Codex登录ChatGPT账号。
- 请求`https://chatgpt.com/backend-api/wham/usage`，使用`access_token`和`ChatGPT-Account-ID`请求头。
- `primary_window.used_percent`按日限额显示，`secondary_window.used_percent`按周限额显示；剩余百分比为`100-used_percent`。

## 安全说明

- 应用只在本机读取`~/.codex/auth.json`，不会把令牌写入日志、README或菜单。
- 当访问令牌即将过期或接口返回401时，会尝试使用`refresh_token`刷新认证文件。
- 认证文件刷新后仍使用`0600`权限写回。
- 开机自启只写入当前用户的LaunchAgent，不需要管理员权限。

## 开发验证

```bash
swift build
swift run CodexMeter --once
bash scripts/build-app.sh
bash scripts/build-app.sh --universal --sign-identity auto --dmg
bash scripts/release.sh
plutil -lint .build/CodexMeter.app/Contents/Info.plist
lipo -info .build/CodexMeter.app/Contents/MacOS/CodexMeter
codesign --verify --deep --strict --verbose=2 .build/CodexMeter.app
cat dist/CodexMeter-0.1.0.dmg.sha256
```

## 注意

Codex额度接口属于Codex当前客户端使用的ChatGPT后端接口，不是公开稳定API。如果后端字段变化，优先用当前Codex版本生成的app-server协议类型重新核对字段。
