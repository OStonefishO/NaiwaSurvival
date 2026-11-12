# 测试报告

日期：2026-11-12  
引擎：Godot 4.7.2 stable  
Blender：5.1.0  
项目：`D:\Godot project\NaiwaForest`

## 无头集成测试

命令：

```powershell
Godot_v4.7.2-stable_win64_console.exe --headless --path . -- --autotest
```

结果：`AUTOTEST RESULT: PASS`，退出码 0。

覆盖内容：

- 地形碰撞与 WASD 动作输入（移动距离 > 0.25m）
- 用 E/交互路径采集真实树枝堆，获得 2 根树枝
- 24 格背包加物品
- 制作石斧
- 任务从步骤 0 推进到步骤 3（树枝 → 石斧 → 木材/石头）
- 放置营火、木工台、简易床、储物箱
- 任务推进到步骤 6
- 睡到第二天 07:00，重生点更新
- 进入蘑菇林，任务到步骤 7，古树守护者触发
- 玩家攻击对史莱姆造成伤害（35 → 29）
- 敌人死亡
- 背包面板打开/关闭与暂停恢复
- 玩家死亡 → 掉落 → 在床位重生
- 储物箱存入/取出、关闭后解除暂停
- 存档写入并读回

## 读档测试

命令：

```powershell
Godot_v4.7.2-stable_win64_console.exe --headless --path . -- --loadtest
```

结果：`LOADTEST RESULT: PASS`，退出码 0。

读回状态：`state=PLAYING`、`quest=7`、`buildings=4`、`day=2`、`hour=7.04`、`branch=10`、`stone_axe=1`、`boss=true`。

## Windows 构建

```powershell
Godot_v4.7.2-stable_win64_console.exe --headless --path . --export-release "Windows Desktop" "build/windows/NaiwaForest.exe"
```

- 退出码 0
- `build/windows/NaiwaForest.exe` 约 118.6 MB
- 实际启动并截图验证：`preview/exported_game.png`
- 窗口标题：`奶蛙：林间新生`

## Web 构建

```powershell
Godot_v4.7.2-stable_win64_console.exe --headless --path . --export-release "Web" "build/web/index.html"
```

- 退出码 0
- 生成 `index.html`、`index.js`、`index.wasm`、`index.pck`、`index.png`、worklet JS
- 本地 HTTP 200，页面与 PCK/WASM 可访问
- 使用带 COOP/COEP 头的 `tools/serve_web.py` 重新测试，所有资源 200
- 无头 Edge 通过 SwiftShader 截图只捕获到 Godot 启动画面（`preview/web_game.png` 已清理），未能在无头环境确认完整进入标题画面；需要在真实浏览器做最终手动验收

## 已知风险 / 未覆盖

- Web 的最终交互与音频需要真实浏览器确认。
- Android 预设未构建、未测试。
- Boss 血条 UI 使用 HUD 的独立 Boss 条，并保留敌人头顶血条。
- 储物箱为 12 格物品搬运箱，点击整格存入/取出。
- 天气系统没有温度/湿度/农业联动。
- `ERROR: N resources still in use at exit` 在无头退出时偶发，来自退出时粒子/补间清理，不影响运行。
