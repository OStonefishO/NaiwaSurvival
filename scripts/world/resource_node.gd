class_name ResourceNode
extends StaticBody3D

var game: Node
var world: Node
var data_id := ""
var data: ResourceData
var model_root: Node3D
var shape: CollisionShape3D
var current_health := 1.0
var alive := true
var respawn_at := -1.0
var _shake_tween: Tween

func setup(p_game: Node, p_world: Node, p_id: String, p_pos: Vector3) -> void:
	game = p_game
	world = p_world
	data_id = p_id
	data = GameDB.resource(p_id)
	position = p_pos

func _ready() -> void:
	add_to_group("resource")
	add_to_group("interactable")
	collision_layer = 1
	collision_mask = 0
	current_health = data.max_health
	_build_visual()
	_build_collision()

func _process(_delta: float) -> void:
	if not alive and respawn_at >= 0.0 and game and game.world_minutes >= respawn_at:
		_respawn()

func _build_visual() -> void:
	var glb := GameUtil.load_glb(data.model_path)
	if glb:
		model_root = glb
		model_root.scale = Vector3.ONE * data.model_scale
		model_root.rotation.y = randf_range(-PI, PI)
		add_child(model_root)
	else:
		_build_fallback()
	GameUtil.add_blob_shadow(self, Vector2(1.4, 1.4) * data.model_scale)

func _build_collision() -> void:
	shape = CollisionShape3D.new()
	var box := BoxShape3D.new()
	match data_id:
		"tree":
			box.size = Vector3(0.8, 2.7, 0.8)
			shape.position.y = 1.35
		"rock":
			box.size = Vector3(1.2, 0.9, 1.0)
			shape.position.y = 0.4
		"branch_pile":
			box.size = Vector3(1.1, 0.35, 0.8)
			shape.position.y = 0.2
		"berry_bush":
			box.size = Vector3(1.1, 0.9, 1.0)
			shape.position.y = 0.45
		_:
			box.size = Vector3(1.0, 0.7, 1.0)
			shape.position.y = 0.35
	shape.shape = box
	add_child(shape)

func _build_fallback() -> void:
	model_root = Node3D.new()
	model_root.name = "Fallback_" + data_id
	add_child(model_root)
	match data_id:
		"tree":
			GameUtil.cylinder(model_root, 0.22, 2.7, GameUtil.mat("bark"), Vector3(0, 1.35, 0), Vector3.ZERO, 7, "Trunk")
			GameUtil.sphere(model_root, 1.45, GameUtil.mat("leaf_dark"), Vector3(0, 2.5, 0), Vector3(1.0, 0.85, 1.0), "CanopyLow")
			GameUtil.sphere(model_root, 1.15, GameUtil.mat("leaf"), Vector3(0.35, 3.1, 0.15), Vector3(0.9, 0.8, 0.9), "CanopyHigh")
			GameUtil.sphere(model_root, 0.82, GameUtil.mat("leaf_light"), Vector3(-0.45, 2.9, -0.25), Vector3(0.9, 0.7, 0.9), "CanopyLight")
		"rock":
			GameUtil.sphere(model_root, 0.7, GameUtil.mat("rock"), Vector3(0, 0.45, 0), Vector3(1.3, 0.7, 1.0), "Rock")
			GameUtil.sphere(model_root, 0.4, GameUtil.mat("rock_dark"), Vector3(0.5, 0.28, 0.1), Vector3(1.1, 0.6, 0.9), "RockSmall")
		"branch_pile":
			for i in 4:
				GameUtil.cylinder(model_root, 0.07, 1.15, GameUtil.mat("bark"), Vector3(0, 0.12 + i * 0.05, 0), Vector3(90, 0, randf_range(-35, 35)), 6, "Branch")
		"loose_stone":
			for i in 3:
				var p := Vector3(cos(i * 2.2) * 0.28, 0.14, sin(i * 2.2) * 0.24)
				GameUtil.sphere(model_root, 0.18, GameUtil.mat("rock"), p, Vector3(1.2, 0.6, 0.9), "LooseStone")
			GameUtil.sphere(model_root, 0.12, GameUtil.mat("rock_dark"), Vector3(0.4, 0.1, 0.1), Vector3(1.0, 0.5, 0.8), "LooseStone2")
		"berry_bush":
			GameUtil.sphere(model_root, 0.62, GameUtil.mat("leaf_dark"), Vector3(0, 0.52, 0), Vector3(1.1, 0.8, 1.0), "Bush")
			for i in 7:
				var a := TAU * float(i) / 7.0
				GameUtil.sphere(model_root, 0.075, GameUtil.raw_mat(Color("#d95355"), 0.4), Vector3(cos(a) * 0.55, 0.55 + sin(a * 2.0) * 0.15, sin(a) * 0.5), Vector3.ONE, "Berry")
		"mushroom_patch":
			for i in 3:
				var p := Vector3(cos(i * 2.2) * 0.3, 0, sin(i * 2.2) * 0.3)
				GameUtil.cylinder(model_root, 0.12, 0.42, GameUtil.mat("cream"), p + Vector3(0, 0.21, 0), Vector3.ZERO, 8, "Stem")
				GameUtil.cone(model_root, 0.34, 0.24, GameUtil.mat("mushroom"), p + Vector3(0, 0.48, 0), Vector3(0, 0, 0), 10, "Cap")

func hit_resource(actor: Node, item: ItemData, _damage: float) -> void:
	if not alive:
		return
	var has_tool := true
	if data.required_tool != "":
		has_tool = item != null and item.tool_type == data.required_tool and item.tool_level >= data.required_tool_level
	if not has_tool:
		if game:
			game.show_toast("需要%s才能采集%s" % [_tool_name(data.required_tool), data.display_name], 1.8)
			game.play_sfx("deny", 0.05)
		return
	var amount := 1.6
	current_health -= amount
	if game:
		game.spawn_hit_sparks(global_position + Vector3(0, 0.7, 0), Vector3.UP)
		game.play_sfx("hit", 0.12)
	if current_health <= 0.0:
		_harvest(actor)
	else:
		_shake()

func interact(actor: Node) -> void:
	var item: ItemData = null
	if actor and actor.inventory:
		item = actor.inventory.selected_item()
	hit_resource(actor, item, 1.0)

func get_prompt() -> String:
	if not alive:
		return ""
	if data.required_tool != "":
		return "%s · 需要%s" % [data.display_name, _tool_name(data.required_tool)]
	return "%s · 按 E 采集" % data.display_name

func _harvest(actor: Node) -> void:
	alive = false
	current_health = 0.0
	for item_id in data.drops:
		var amount := int(data.drops[item_id])
		if amount > 0:
			game.spawn_item_pickup(item_id, amount, global_position + Vector3(randf_range(-0.5, 0.5), 0.4, randf_range(-0.5, 0.5)))
	if game:
		game.play_sfx("pickup", 0.1)
		game.spawn_death_puff(global_position + Vector3(0, 0.5, 0))
		game.quest_event("collect", data_id)
	visible = false
	if shape:
		shape.disabled = true
	respawn_at = game.world_minutes + data.respawn_minutes
	EventBus.toast_requested.emit("%s 采集完成" % data.display_name, 1.5)

func _respawn() -> void:
	alive = true
	current_health = data.max_health
	respawn_at = -1.0
	visible = true
	if shape:
		shape.disabled = false

func _shake() -> void:
	if _shake_tween and _shake_tween.is_valid():
		_shake_tween.kill()
	_shake_tween = create_tween()
	_shake_tween.tween_property(model_root, "rotation:z", 0.08, 0.05)
	_shake_tween.tween_property(model_root, "rotation:z", -0.06, 0.08)
	_shake_tween.tween_property(model_root, "rotation:z", 0.0, 0.06)

func _tool_name(tool: String) -> String:
	match tool:
		"axe": return "斧头"
		"pickaxe": return "镐"
		"torch": return "火把"
	return "工具"

func to_save() -> Dictionary:
	return {"id": data_id, "pos": [position.x, position.y, position.z], "alive": alive, "health": current_health, "respawn_at": respawn_at}

func from_save(d: Dictionary) -> void:
	alive = bool(d.get("alive", true))
	current_health = float(d.get("health", data.max_health))
	respawn_at = float(d.get("respawn_at", -1.0))
	visible = alive
	if shape:
		shape.disabled = not alive
