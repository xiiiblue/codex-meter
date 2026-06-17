# CodexMeter后续优化路线图

本文档记录已完成能力和后续候选项。P3目前按用户决定暂缓，不作为当前执行目标。

## 已完成

### P0体验修复

1. 刷新失败时保留旧值
   - 状态栏继续显示上一次成功额度。
   - 错误信息仅显示在菜单里。

2. 启动未登录引导
   - 没有`~/.codex/auth.json`或不是ChatGPT登录态时，菜单中显示`codex login`引导。

3. 开机自启路径自修复
   - 启动时检测LaunchAgent路径。
   - 路径过期时提示并提供`修复开机自启路径`。

### P1状态与提醒

1. 刷新详情增强
   - 菜单显示`上次成功刷新`和`下次刷新`。
   - 刷新失败时保留成功时间，并显示失败时间和原因。

2. 低额度提醒
   - 日限额或周限额低于`20%`时显示偏低提醒。
   - 低于`10%`时显示告急提醒。

3. 额度重置倒计时
   - 菜单显示具体重置时间和相对倒计时。

### P2显示与分发

1. 菜单栏显示模式
   - 支持`日24% 周32%`、`D24 W32`、`Codex 24%`和仅日限额。
   - 选择保存到`UserDefaults`。

2. Release校验值
   - 发布DMG时生成SHA256。
   - Release说明附带校验值。

3. DMG视觉优化
   - 增加DMG背景图。
   - 固定窗口大小。
   - 摆放`CodexMeter.app`、`Applications`快捷方式和首次打开说明。

4. 发布脚本
   - `scripts/release.sh`串联构建、签名、DMG、校验、Release说明生成和上传。
   - 版本号统一来自`VERSION`。
   - 同版本Release默认拒绝覆盖，显式`--force`才允许重发。

## 当前收口项

1. 路线图状态更新
   - 已完成：本文档已把P0/P1/P2从待办改为已完成记录。

2. 发布脚本自动递增版本
   - 已完成：支持`scripts/release.sh --publish --bump patch`。
   - 同版本Release仍默认拒绝覆盖。

3. DMG打包失败清理
   - 已完成：`build-app.sh --dmg`异常退出时会自动卸载临时挂载卷并删除`-rw.dmg`。

## 暂缓

### P3新功能

1. 检查更新
   - 菜单中增加`检查更新`。
   - 查询GitHub最新Release。
   - 如果有新版，打开Release页面。

2. 多账号或工作区显示
   - 显示当前账号、plan或workspace。
   - 目标是避免用户误判正在看的额度归属。

## 候选优化

1. 拆分`Sources/CodexMeter/main.swift`
   - 可拆为`CodexUsageClient.swift`、`LoginItemManager.swift`、`Preferences.swift`、`Models.swift`和`AppDelegate.swift`。

2. 增加最小单元测试
   - 覆盖显示模式、刷新频率、剩余百分比边界和重置倒计时文案。

3. 认证文件写回保护
   - 刷新token写回前保留备份，降低极端情况下损坏`~/.codex/auth.json`的风险。
