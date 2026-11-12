extends Node

# 数据注册表：把物品、配方、建筑、资源节点和敌人集中定义为 Resource。
# 内容用稳定 ID 查询，存档只保存 ID 与数量。

var items: Dictionary = {}
var recipes: Dictionary = {}
var recipe_order: Array[String] = []
var buildings: Dictionary = {}
var building_order: Array[String] = []
var resources: Dictionary = {}
var enemies: Dictionary = {}

func _ready() -> void:
	_build_items()
	_build_recipes()
	_build_buildings()
	_build_resources()
	_build_enemies()

func item(id: String) -> ItemData:
	return items.get(id)

func recipe(id: String) -> RecipeData:
	return recipes.get(id)

func building(id: String) -> BuildingData:
	return buildings.get(id)

func resource(id: String) -> ResourceData:
	return resources.get(id)

func enemy(id: String) -> EnemyData:
	return enemies.get(id)

func item_name(id: String) -> String:
	var it := item(id)
	return it.display_name if it else id

func _item(id: String, name: String, category: String, color: Color, glyph: String, desc := "", stack := 40, tool := "", tier := 0, damage := 0.0, hunger := 0.0, health := 0.0) -> void:
	var it := ItemData.new()
	it.id = id
	it.display_name = name
	it.description = desc
	it.category = category
	it.icon_color = color
	it.icon_glyph = glyph
	it.max_stack = stack
	it.tool_type = tool
	it.tool_level = tier
	it.damage = damage
	it.hunger_restore = hunger
	it.health_restore = health
	items[id] = it

func _build_items() -> void:
	_item("branch", "树枝", "material", Color("#b88952"), "枝", "弯弯的细树枝，制作工具的基础材料。", 50)
	_item("wood", "木材", "material", Color("#9a6b3f"), "木", "砍树得到的木料，用于建造与制作。", 50)
	_item("stone", "石头", "material", Color("#9b9a8f"), "石", "结实的石块，能敲出工具与营火。", 50)
	_item("fiber", "纤维", "material", Color("#8fbd63"), "纤", "柔软坚韧的草纤维，可以绑东西。", 50)
	_item("berry", "浆果", "consumable", Color("#d95b58"), "莓", "酸甜的森林浆果，饥饿 +12。", 20, "", 0, 0.0, 12.0)
	_item("mushroom", "蘑菇", "consumable", Color("#d7a56e"), "菇", "林间蘑菇，饥饿 +8。", 20, "", 0, 0.0, 8.0)
	_item("resin", "树脂", "material", Color("#e0aa4c"), "脂", "从树上收集的黏稠树脂，火把的燃料。", 20)
	_item("hide", "兽皮", "material", Color("#9f6f4e"), "皮", "从刺球兽身上取得的厚皮。", 20)
	_item("slime_gel", "黏液", "material", Color("#80c9a0"), "黏", "软泥怪留下的清凉凝胶。", 20)
	_item("heart_shard", "林心碎片", "key", Color("#8ef0cf"), "心", "古树守护者守护的翠绿碎片。", 5)
	_item("stone_axe", "石斧", "tool", Color("#a8a699"), "斧", "砍树效率高，也能防身。", 1, "axe", 1, 8.0)
	_item("stone_pickaxe", "石镐", "tool", Color("#a8a699"), "镐", "可以开采石块与矿脉。", 1, "pickaxe", 1, 5.0)
	_item("club", "木棒", "weapon", Color("#a57643"), "棒", "朴素的近战武器，伤害 12。", 1, "", 0, 12.0)
	_item("stone_spear", "石矛", "weapon", Color("#a7a18e"), "矛", "攻击距离更长的石制长矛，伤害 18。", 1, "", 0, 18.0)
	_item("torch", "火把", "tool", Color("#ffb45c"), "火", "照亮夜路，也能驱赶惧光的生物。", 1, "torch", 1, 4.0)
	_item("bandage", "草编绷带", "consumable", Color("#d8d1a8"), "绷", "止血草药，生命 +20。", 10, "", 0, 0.0, 0.0, 20.0)
	_item("berry_snack", "烤浆果", "consumable", Color("#e47a55"), "烤", "营火烤过的浆果，饥饿 +20。", 10, "", 0, 0.0, 20.0)
	_item("mushroom_skewer", "蘑菇串", "consumable", Color("#c9945c"), "串", "热乎乎的蘑菇串，饥饿 +25、生命 +5。", 10, "", 0, 0.0, 25.0, 5.0)

func _recipe(id: String, name: String, output: String, count: int, costs: Dictionary, station := "hand", desc := "") -> void:
	var r := RecipeData.new()
	r.id = id
	r.display_name = name
	r.output_item = output
	r.output_count = count
	r.costs = costs
	r.station = station
	r.description = desc
	recipes[id] = r
	recipe_order.append(id)

func _build_recipes() -> void:
	_recipe("stone_axe", "石斧", "stone_axe", 1, {"branch": 2, "stone": 3, "fiber": 2}, "hand", "第一把趁手的斧头。")
	_recipe("stone_pickaxe", "石镐", "stone_pickaxe", 1, {"branch": 2, "stone": 4, "fiber": 2}, "hand", "敲开石块与矿脉。")
	_recipe("club", "木棒", "club", 1, {"wood": 5}, "hand", "简单但可靠的防身武器。")
	_recipe("stone_spear", "石矛", "stone_spear", 1, {"wood": 4, "stone": 2, "fiber": 2}, "hand", "更长的攻击距离。")
	_recipe("torch", "火把", "torch", 1, {"branch": 2, "resin": 1, "fiber": 1}, "hand", "夜晚探索的第一束光。")
	_recipe("bandage", "草编绷带", "bandage", 1, {"fiber": 3}, "hand", "用纤维编成的简易绷带。")
	_recipe("berry_snack", "烤浆果", "berry_snack", 1, {"berry": 3}, "campfire", "需要靠近营火。")
	_recipe("mushroom_skewer", "蘑菇串", "mushroom_skewer", 1, {"mushroom": 2, "berry": 1}, "campfire", "需要靠近营火。")

func _building(id: String, name: String, category: String, cost: Dictionary, size: Vector2, height: float, model: String, desc: String, collision: Vector3, needs_floor := false) -> void:
	var b := BuildingData.new()
	b.id = id
	b.display_name = name
	b.category = category
	b.cost = cost
	b.size = size
	b.height = height
	b.model_path = model
	b.description = desc
	b.collision_size = collision
	b.needs_floor = needs_floor
	buildings[id] = b
	building_order.append(id)

func _build_buildings() -> void:
	_building("floor", "木地板", "结构", {"wood": 2}, Vector2(2, 2), 0.0, "res://assets/models/buildings/floor.glb", "铺在网格上的木地板。", Vector3(2, 0.18, 2))
	_building("wall", "木墙", "结构", {"wood": 3}, Vector2(2, 2), 0.0, "res://assets/models/buildings/wall.glb", "挡住风雨和危险的木墙。", Vector3(2, 2.2, 0.22))
	_building("door", "木门", "结构", {"wood": 2}, Vector2(2, 2), 0.0, "res://assets/models/buildings/door.glb", "可以进出的木门。", Vector3(1.3, 2.1, 0.18))
	_building("roof", "斜屋顶", "结构", {"wood": 4}, Vector2(2.2, 2.2), 2.2, "res://assets/models/buildings/roof.glb", "需要一格地板作为支撑。", Vector3(2.2, 0.35, 2.2), true)
	_building("campfire", "营火", "照明", {"wood": 6, "stone": 4}, Vector2(2, 2), 0.0, "res://assets/models/buildings/campfire.glb", "照明、烹饪和休息的地方。", Vector3(1.0, 0.6, 1.0))
	_building("chest", "储物箱", "储存", {"wood": 12}, Vector2(2, 2), 0.0, "res://assets/models/buildings/chest.glb", "存放多余的材料。", Vector3(1.0, 0.8, 0.65))
	_building("workbench", "木工台", "生产", {"wood": 12, "stone": 4}, Vector2(2, 2), 0.0, "res://assets/models/buildings/workbench.glb", "制作更高级的工具和设施。", Vector3(1.5, 0.9, 0.8))
	_building("bed", "简易床", "生活", {"wood": 10, "fiber": 4}, Vector2(2, 2), 0.0, "res://assets/models/buildings/bed.glb", "睡到天亮，并把这里设为重生点。", Vector3(1.2, 0.5, 2.0))

func _resource(id: String, name: String, hp: float, tool: String, tier: int, drops: Dictionary, respawn: float, model: String, desc := "") -> void:
	var r := ResourceData.new()
	r.id = id
	r.display_name = name
	r.max_health = hp
	r.required_tool = tool
	r.required_tool_level = tier
	r.drops = drops
	r.respawn_minutes = respawn
	r.model_path = model
	r.description = desc
	resources[id] = r

func _build_resources() -> void:
	_resource("branch_pile", "树枝堆", 3.0, "", 0, {"branch": 2}, 20.0, "res://assets/models/environment/branch_pile.glb", "散落在地上的细树枝。")
	_resource("loose_stone", "散落石块", 2.0, "", 0, {"stone": 2}, 120.0, "", "营地附近散落的小石块，徒手就能捡。")
	_resource("tree", "小树", 6.0, "axe", 1, {"wood": 3, "branch": 1, "resin": 1}, 180.0, "res://assets/models/environment/tree.glb", "需要石斧才能砍倒。")
	_resource("rock", "石块", 5.0, "pickaxe", 1, {"stone": 3}, 180.0, "res://assets/models/environment/rock.glb", "需要石镐才能开采。")
	_resource("berry_bush", "浆果灌木", 2.0, "", 0, {"berry": 2, "fiber": 1}, 80.0, "res://assets/models/environment/berry_bush.glb", "徒手就能摘的浆果。")
	_resource("mushroom_patch", "蘑菇簇", 2.0, "", 0, {"mushroom": 2}, 80.0, "res://assets/models/environment/mushroom_patch.glb", "潮湿处生长的蘑菇。")

func _enemy(id: String, name: String, hp: float, speed: float, damage: float, model: String, drops: Dictionary, tint: Color, boss := false) -> void:
	var e := EnemyData.new()
	e.id = id
	e.display_name = name
	e.max_health = hp
	e.speed = speed
	e.damage = damage
	e.model_path = model
	e.drops = drops
	e.tint = tint
	e.is_boss = boss
	enemies[id] = e

func _build_enemies() -> void:
	_enemy("slime", "软泥怪", 35, 1.6, 7, "res://assets/models/enemies/slime.glb", {"slime_gel": 1, "fiber": 1}, Color("#7fbd8b"))
	_enemy("mushroom_bug", "蘑菇虫", 45, 2.2, 9, "res://assets/models/enemies/mushroom_bug.glb", {"mushroom": 1, "fiber": 1}, Color("#c58a5d"))
	_enemy("spiky_beast", "刺球兽", 70, 3.0, 13, "res://assets/models/enemies/spiky_beast.glb", {"hide": 1, "stone": 1}, Color("#8b7754"))
	_enemy("ancient_guardian", "古树守护者", 520, 1.2, 22, "res://assets/models/enemies/ancient_guardian.glb", {"heart_shard": 1}, Color("#6da76f"), true)
