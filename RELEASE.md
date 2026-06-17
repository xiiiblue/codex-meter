# CodexMeter发布说明

本文档记录把CodexMeter打包给其他Mac用户使用时需要做的步骤。

## 1.构建Universal Binary

```bash
bash scripts/build-app.sh --universal
lipo -info .build/CodexMeter.app/Contents/MacOS/CodexMeter
```

期望输出包含：

```text
x86_64 arm64
```

## 2.签名

自动选择签名身份：

```bash
bash scripts/build-app.sh --universal --sign-identity auto
```

行为：

- 如果钥匙串里存在`Developer ID Application`证书，会用它签名并开启hardened runtime。
- 如果没有`Developer ID Application`证书，会退回ad-hoc签名`-`。

检查当前可用证书：

```bash
security find-identity -v -p codesigning
```

当前机器只有`Apple Development`证书时，可以本机开发签名，但不适合对外分发。对外分发需要Apple Developer账号里的`Developer ID Application`证书。

## 3.生成DMG

```bash
bash scripts/build-app.sh --universal --sign-identity auto --dmg
```

输出：

```text
dist/CodexMeter-$(cat VERSION).dmg
dist/CodexMeter-$(cat VERSION).dmg.sha256
```

未公证分发时，DMG会包含：

- `CodexMeter.app`
- `Applications`快捷方式
- `First Open Guide.txt`
- 自定义背景图和固定图标布局

用户需要把App拖到Applications，并通过右键`打开`绕过首次Gatekeeper提示。

## 4.公证

公证需要：

- `Developer ID Application`证书。
- Apple Developer账号。
- App Store Connect APIKey，或已保存到Keychain的notarytool配置。

保存公证凭据：

```bash
xcrun notarytool store-credentials codex-meter-notary
```

提交DMG：

```bash
xcrun notarytool submit "dist/CodexMeter-$(cat VERSION).dmg" \
  --keychain-profile codex-meter-notary \
  --wait
```

公证成功后装订：

```bash
xcrun stapler staple "dist/CodexMeter-$(cat VERSION).dmg"
xcrun stapler validate "dist/CodexMeter-$(cat VERSION).dmg"
```

## 5.分发前验证

```bash
spctl --assess --type execute --verbose .build/CodexMeter.app
spctl --assess --type open --context context:primary-signature --verbose "dist/CodexMeter-$(cat VERSION).dmg"
cat "dist/CodexMeter-$(cat VERSION).dmg.sha256"
```

如果输出里出现`override=security disabled`，说明本机Gatekeeper处于关闭或覆盖状态，这个结果不能证明陌生机器会直接放行。正式结论应以Developer ID签名、公证、staple和一台Gatekeeper开启的干净Mac验证为准。

## 6.使用者机器要求

- macOS14或更高版本。
- 已安装并登录Codex，且存在`~/.codex/auth.json`。
- 网络可访问`chatgpt.com/backend-api/wham/usage`。
- 首次运行后，如果移动App位置，需要重新勾选`开机自启`，让LaunchAgent指向新的可执行文件路径。

## 7.Release脚本

版本号统一来自`VERSION`文件。发布新版本前先递增版本：

```bash
scripts/bump-version.sh patch
```

也可以让Release脚本自动递增版本后发布：

```bash
bash scripts/release.sh --publish --bump patch
```

生成产物和Release说明：

```bash
bash scripts/release.sh
```

创建GitHub Release：

```bash
bash scripts/release.sh --publish
```

如果同版本Release已经存在，默认会退出，避免覆盖已发布的DMG和SHA256。确认要重发同版本时才使用：

```bash
bash scripts/release.sh --publish --force
```
