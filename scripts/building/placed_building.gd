class_name PlacedBuilding
extends StaticBody3D

var game: Node
var data: BuildingData
var cell := Vector2i.ZERO
var rotation_index := 0
var preview := false
var storage: Array = []
var model_root: Node3D
var shape: CollisionShape3D
var light: OmniLight3D
var _ghost_mat: StandardMaterial3D

func setup(p_game: Node, p_data: BuildingData, p_cell: Vector2i, p_rot: int, p_preview := false) -> void:
	game = p_game
	data = p_data
	cell = p_cell
	rotation_index = p_rot
	preview = p_preview

func _ready() -> void:
	name = "%s_%d_%d" % [data.id, cell.x, cell.y]
	rotation.y = rotation_index * PI * 0.5
	if not preview:
		add_to_group("building")
		if data.id in ["campfire", "chest", "workbench", "bed"]:
			add_to_group("interactable")
	_build_visual()
	if not preview:
		_build_collision()
	_build_extra()

func _build_visual() -> void:
	var glb := GameUtil.load_glb(data.model_path)
	if glb:
		model_root = glb
		add_child(model_root)
	else:
		_build_fallback()
	GameUtil.add_blob_shadow(self, data.size * 1.1)

func _build_fallback() -> void:
	model_root = Node3D.new()
	add_child(model_root)
	var wood := GameUtil.mat("wood")
	var dark := GameUtil.mat("wood_dark")
	match data.id:
		"floor":
			for i in 4:
				GameUtil.box(model_root, Vector3(2.0, 0.1, 0.48), wood if i % 2 == 0 else dark, Vector3(0, 0.06, -0.75 + i * 0.5), Vector3.ZERO, "Plank")
		"wall":
			for i in 5:
				GameUtil.box(model_root, Vector3(0.38, 2.0, 0.14), wood if i % 2 == 0 else dark, Vector3(-0.8 + i * 0.4, 1.0, 0), Vector3.ZERO, "Plank")
			GameUtil.box(model_root, Vector3(2.0, 0.15, 0.18), dark, Vector3(0, 1.95, 0), Vector3.ZERO, "Beam")
		"door":
			GameUtil.box(model_root, Vector3(0.15, 2.15, 0.18), dark, Vector3(-0.9, 1.08, 0), Vector3.ZERO, "Frame")
			GameUtil.box(model_root, Vector3(0.15, 2.15, 0.18), dark, Vector3(0.9, 1.08, 0), Vector3.ZERO, "Frame")
			GameUtil.box(model_root, Vector3(1.65, 2.0, 0.12), wood, Vector3(0, 1.0, 0), Vector3.ZERO, "Door")
			GameUtil.sphere(model_root, 0.06, GameUtil.mat("gold"), Vector3(0.58, 1.0, -0.1), Vector3.ONE, "Knob")
		"roof":
			for i in 8:
				GameUtil.box(model_root, Vector3(0.3, 0.12, 2.4), wood if i % 2 == 0 else dark, Vector3(-1.05 + i * 0.3, 0, 0), Vector3(0, 0, 18 if i < 4 else -18), "RoofPlank")
		"campfire":
			for i in 8:
				var a := TAU * float(i) / 8.0
				GameUtil.sphere(model_root, 0.16, GameUtil.mat("rock"), Vector3(cos(a) * 0.62, 0.08, sin(a) * 0.62), Vector3(1.0, 0.6, 1.0), "Stone")
			for i in 3:
				GameUtil.cylinder(model_root, 0.09, 1.0, dark, Vector3(0, 0.2 + i * 0.08, 0), Vector3(90, i * 60.0, 0), 6, "Log")
			var flame := GameUtil.cone(model_root, 0.26, 0.75, GameUtil.raw_mat(Color("#ff9c4b"), 0.2, 0.0, 2.5, true), Vector3(0, 0.65, 0), Vector3.ZERO, 8, "Flame")
			flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		"chest":
			GameUtil.box(model_root, Vector3(0.95, 0.58, 0.62), wood, Vector3(0, 0.34, 0), Vector3.ZERO, "ChestBase")
			GameUtil.box(model_root, Vector3(1.0, 0.22, 0.66), dark, Vector3(0, 0.72, 0), Vector3.ZERO, "ChestLid")
			GameUtil.box(model_root, Vector3(0.1, 0.9, 0.7), GameUtil.mat("gold"), Vector3(0, 0.4, 0), Vector3.ZERO, "Band")
		"workbench":
			for x in [-0.7, 0.7]:
				for z in [-0.4, 0.4]:
					GameUtil.box(model_root, Vector3(0.12, 0.85, 0.12), dark, Vector3(x, 0.43, z), Vector3.ZERO, "Leg")
			GameUtil.box(model_root, Vector3(1.7, 0.14, 0.9), wood, Vector3(0, 0.9, 0), Vector3.ZERO, "Top")
			GameUtil.box(model_root, Vector3(0.4, 0.05, 0.2), GameUtil.mat("rock"), Vector3(0.35, 0.98, 0.1), Vector3(0, 20, 0), "Tool")
		"bed":
			GameUtil.box(model_root, Vector3(1.35, 0.22, 2.0), dark, Vector3(0, 0.18, 0), Vector3.ZERO, "Frame")
			GameUtil.box(model_root, Vector3(1.2, 0.22, 1.8), GameUtil.raw_mat(Color("#c7b18a"), 0.9), Vector3(0, 0.35, 0), Vector3.ZERO, "Mattress")
			GameUtil.box(model_root, Vector3(0.7, 0.15, 0.35), GameUtil.mat("cream"), Vector3(0, 0.48, -0.7), Vector3.ZERO, "Pillow")
		_:
			GameUtil.box(model_root, Vector3(1.2, 1.0, 1.2), wood, Vector3(0, 0.5, 0), Vector3.ZERO, "Block")

func _build_collision() -> void:
	if data.id == "roof" or data.id == "door":
		return
	shape = CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = data.collision_size
	shape.shape = box
	shape.position.y = data.collision_size.y * 0.5
	add_child(shape)

func _build_extra() -> void:
	if data.id == "campfire" and not preview:
		light = OmniLight3D.new()
		light.light_color = Color("#ffb15c")
		light.light_energy = 2.0
		light.omni_range = 8.0
		light.position = Vector3(0, 1.0, 0)
		add_child(light)

func set_preview_valid(valid: bool) -> void:
	if _ghost_mat == null:
		_ghost_mat = StandardMaterial3D.new()
		_ghost_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_ghost_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_ghost_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_ghost_mat.albedo_color = Color(0.35, 1.0, 0.55, 0.35) if valid else Color(1.0, 0.25, 0.2, 0.35)
	for c in find_children("*", "MeshInstance3D", true, false):
		(c as MeshInstance3D).material_override = _ghost_mat

func interact(actor: Node) -> void:
	match data.id:
		"bed":
			game.sleep_in_bed(self)
		"campfire":
			game.open_crafting("campfire")
		"workbench":
			game.open_crafting("workbench")
		"chest":
			game.open_chest(self)

func get_prompt() -> String:
	match data.id:
		"bed": return "在简易床上睡到天亮"
		"campfire": return "在营火边制作食物"
		"workbench": return "使用木工台制作"
		"chest": return "打开储物箱"
	return data.display_name

func to_save() -> Dictionary:
	var saved_storage: Array = []
	for s in storage:
		if s != null:
			saved_storage.append(s.duplicate(true))
	return {"id": data.id, "cell": [cell.x, cell.y], "rotation": rotation_index, "storage": saved_storage}

func add_to_storage(item_id: String, amount: int) -> int:
	var data_item: ItemData = GameDB.item(item_id)
	if data_item == null:
		return amount
	var left := amount
	for s in storage:
		if left <= 0:
			break
		if s != null and s["id"] == item_id and int(s["amount"]) < data_item.max_stack:
			var put := mini(data_item.max_stack - int(s["amount"]), left)
			s["amount"] = int(s["amount"]) + put
			left -= put
	while left > 0 and storage.size() < 12:
		var put := mini(data_item.max_stack, left)
		storage.append({"id": item_id, "amount": put})
		left -= put
	return left
