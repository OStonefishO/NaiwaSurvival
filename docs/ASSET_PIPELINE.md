# 资产管线

所有资产按 GDD 参考图 `docs/gdd_media/media_image1.jpg` 重建，源文件在 `source_blend/`，运行时资产在 `assets/models/`。

## 重建

```powershell
# 奶蛙：建模 + 骨骼 + 7 个动画 + GLB
blender --background --factory-startup --python tools/build_naifrog.py

# 森林资源、建筑、敌人 GLB
blender --background --factory-startup --python tools/build_forest_assets.py

# 48 秒森林主题循环
python tools/gen_music.py
```

导出后让 Godot 扫描一次：

```powershell
godot --headless --editor --path . --quit-after 20
```

## 奶蛙

- 文件：`assets/models/frog/naifrog.glb`
- 源：`source_blend/naifrog_rig.blend`
- 骨骼：root / hips / spine / head / arm.L / arm.R / leg.L / leg.R
- 动画：Idle、Walk、Run、Attack、Hit、Dodge、Death
- 顶点权重采用刚性分配（身体→spine，头/眼/嘴→head，四肢→对应骨骼），适合低多边形卡通角色
- 高约 1.85m；游戏内缩放 0.95，原点在脚底，根节点向上偏移 1.0 对齐碰撞体

## 森林资源

| 文件 | 用途 |
|---|---|
| `environment/tree.glb` | 可砍伐树木 |
| `environment/mushroom_patch.glb` | 蘑菇采集点 |
| `environment/rock.glb` | 石镐采集的岩石 |
| `environment/branch_pile.glb` | 徒手树枝 |
| `environment/berry_bush.glb` | 浆果/纤维 |

## 建筑

`buildings/`：floor、wall、door、roof、campfire、chest、workbench、bed。  
网格 2m；根原点在地面。门与屋顶不生成阻挡碰撞；屋顶需要地板支撑。

## 敌人

`enemies/`：slime、mushroom_bug、spiky_beast、ancient_guardian。  
古树守护者在玩家进入蘑菇林时生成。

## 材质

GLB 自带材质名，游戏侧 `GameUtil.apply_asset_materials` 按节点名重新覆盖为统一的低多边形森林色板，避免 glTF 颜色在 Godot 中偏白。奶蛙材质在 `naifrog_player.gd` 中单独覆盖。

## 入口

- 游戏入口：`scenes/main.tscn`
- 数据表：`scripts/core/game_db.gd`
- 世界：`scripts/world/forest_world.gd`
- 玩家：`scripts/player/naifrog_player.gd`
- 建造：`scripts/building/building_system.gd`
- 存档：`scripts/core/save_manager.gd`
