# 奶蛙生存：海盗湾 / NaiwaSurvival

一只圆滚滚的奶蛙漂流到被诅咒的海盗湾。白天采集资源、搭建营地，黄昏准备防御，夜晚抵御海盗亡魂；活过一夜又一夜。三张藏宝图和山巅信号火是可选的逃离路线。

- 引擎：**Godot 4.7.2**（Compatibility 渲染器，Windows / Android / Web 同一套逻辑）
- 视角：3D 上帝视角 · 低多边形卡通
- 核心循环：采集 → 建造 → 夜晚战斗 → 天亮进入下一天
- 沙盒系统：木材 / 石头 / 纤维 / 椰子采集与再生；营火、木栅栏、草棚、磨刀石；死亡回最近营火重生
- 夜晚：亡魂成波出现，营火提供照明与安全区；草棚可以睡到天亮
- 可选目标：3 张藏宝图 → 5 木材 → 山巅信号火 → 骷髅船长

## 下载 / Releases

Windows、Android APK 和预览海报发布在 GitHub Releases：

https://github.com/OStonefishO/NaiwaSurvival/releases

## 操作

电脑：WASD / 方向键移动，鼠标左键或空格挥刀，Shift 冲刺，E 互动，B 建造，Esc 暂停。

手机：横屏；左侧虚拟摇杆移动，右下角挥刀 / 冲刺 / 互动，顶部「建造」打开制作菜单。网页版在手机上打开后轻触屏幕开始。

## 运行

用 Godot 4.7.2 打开本目录，主场景是 `scenes/main.tscn`。

无头冒烟测试：

```text
Godot_v4.7.2-stable_win64_console.exe --headless --path . -- --autotest
```

导出预设已包含 Windows / Web / Android；构建产物不提交到仓库，统一放在 Releases。

## 美术与 Blender

- 游戏主体是用 **Godot/GDScript** 做的：地形、水面、营地、海盗船、骷髅、UI 都是代码生成或 Godot 内搭建。
- 奶蛙角色用 Blender 建模，导出为 `assets/models/milkfrog.glb`，Godot 在 `scripts/player.gd` 中加载。
- `source_blend/milkfrog_source.blend` 是角色源文件；`source_blend/milkfrog_import_demo.blend` 是在 Blender 里重新导入 GLB 后保存的验证场景。
- `source_blend/.gdignore` 让 Godot 忽略这个目录，避免把 `.blend` 当成运行时资源导入。

Blender 能直接导入的是 GLB/FBX/OBJ 等模型资产；Godot 的 `.tscn` 场景和 GDScript 逻辑不能直接导入 Blender。整个岛是运行时程序化生成的，所以没有单一的“岛屿模型文件”可以导入。

## 目录

- `scripts/` 玩法、世界生成、UI、音频
- `scripts/ui/` HUD、触摸控制、建造菜单
- `assets/` 字体、奶蛙 GLB、程序化 WAV 音频
- `scenes/main.tscn` 主场景
- `source_blend/` Blender 角色源文件和导入验证场景
- `preview/` 预览图与实机截图

## 引擎说明

游戏用 **Godot 4.7.2** 制作，不是用 Blender 做整个游戏。Blender 只负责奶蛙角色的建模与源文件；Godot 负责场景、玩法、UI、音频和 Windows/Android/Web 导出。
