class_name BuildingSystem
extends Node

const CELL := 2.0

var game: Node
var world: Node
var player: NaifrogPlayer
var active := false
var selected_id := "floor"
var rotation_index := 0
var ghost: PlacedBuilding
var placed: Array[PlacedBuilding] = []
var occupancy: Dictionary = {}
var _last_cell := Vector2i(999999, 999999)
var _last_valid := false

func setup(p_game: Node, p_world: Node, p_player: NaifrogPlayer) -> void:
	game = p_game
	world = p_world
	player = p_player

func enter_mode(id := "floor") -> void:
	active = true
	selected_id = id
	rotation_index = 0
	_make_ghost()
	if game:
		game.show_toast("建造模式：鼠标选择位置，左键放置，R 旋转，X 拆除，右键取消。", 3.0)
		if game.hud:
			game.hud.set_build_hint(true)

func exit_mode() -> void:
	active = false
	if ghost and is_instance_valid(ghost):
		ghost.queue_free()
	ghost = null
	if game and game.hud:
		game.hud.set_build_hint(false)

func select_building(id: String) -> void:
	selected_id = id
	rotation_index = 0
	if active:
		_make_ghost()

func rotate_building() -> void:
	rotation_index = (rotation_index + 1) % 4
	if ghost and is_instance_valid(ghost):
		ghost.rotation.y = rotation_index * PI * 0.5
	if game:
		game.play_sfx("ui_click", 0.0)

func _make_ghost() -> void:
	if ghost and is_instance_valid(ghost):
		ghost.queue_free()
	ghost = null
	var data: BuildingData = GameDB.building(selected_id)
	if data == null:
		return
	ghost = PlacedBuilding.new()
	ghost.game = game
	ghost.data = data
	ghost.preview = true
	add_child(ghost)
	ghost.position = Vector3(0, -100, 0)

func _process(_delta: float) -> void:
	if not active or ghost == null or player == null:
		return
	if game == null or game.ui_blocked or not game.is_playing():
		return
	var cell := cell_under_mouse()
	var data: BuildingData = GameDB.building(selected_id)
	if data == null:
		return
	var pos := cell_to_world(cell, data)
	ghost.global_position = pos
	ghost.rotation.y = rotation_index * PI * 0.5
	if cell != _last_cell:
		_last_cell = cell
		_last_valid = can_place(data, cell).get("valid", false)
		ghost.set_preview_valid(_last_valid)
	# building input is handled by the game to avoid attacking while placing
	if Input.is_action_just_pressed("build_rotate"):
		rotate_building()
	if Input.is_action_just_pressed("build_remove"):
		remove_at(cell)
	if Input.is_action_just_pressed("build_place"):
		place_at(cell)
	if Input.is_action_just_pressed("build_cancel"):
		exit_mode()
		if game:
			game.close_build_mode()

func cell_under_mouse() -> Vector2i:
	var p: Vector3 = game.camera_rig.mouse_ground_position(player.global_position.y) if game and game.camera_rig else player.global_position
	return Vector2i(roundi(p.x / CELL), roundi(p.z / CELL))

func cell_to_world(cell: Vector2i, data: BuildingData) -> Vector3:
	var y: float = world.height_at(cell.x * CELL, cell.y * CELL) + 0.02
	if data.id == "roof":
		y += 2.20
	return Vector3(cell.x * CELL, y, cell.y * CELL)

func can_place(data: BuildingData, cell: Vector2i) -> Dictionary:
	if player == null:
		return {"valid": false, "reason": "玩家未就绪"}
	if not player.inventory.has_costs(data.cost):
		return {"valid": false, "reason": "材料不足"}
	var center := Vector3(cell.x * CELL, 0, cell.y * CELL)
	if absf(center.x) > world.world_size * 0.5 - 2.0 or absf(center.z) > world.world_size * 0.5 - 2.0:
		return {"valid": false, "reason": "超出可建造区域"}
	# ground slope
	var base: float = world.height_at(center.x, center.z)
	for dx in [-0.7, 0.7]:
		for dz in [-0.7, 0.7]:
			if absf(world.height_at(center.x + dx, center.z + dz) - base) > 0.75:
				return {"valid": false, "reason": "地面太陡"}
	var key := _key(cell)
	var here: Array = occupancy.get(key, [])
	if data.id == "roof":
		if not here.has("floor"):
			return {"valid": false, "reason": "需要地板支撑"}
		if here.has("roof"):
			return {"valid": false, "reason": "这里已经有屋顶"}
		return {"valid": true, "reason": ""}
	if data.id in ["wall", "door"]:
		if here.has("wall") or here.has("door"):
			return {"valid": false, "reason": "墙/门位置已被占用"}
		return {"valid": true, "reason": ""}
	if not here.is_empty():
		return {"valid": false, "reason": "这块格子已被占用"}
	return {"valid": true, "reason": ""}

func place_at(cell: Vector2i) -> bool:
	if not active:
		return false
	var data: BuildingData = GameDB.building(selected_id)
	if data == null:
		return false
	var check := can_place(data, cell)
	if not check.get("valid", false):
		if game:
			game.show_toast(str(check.get("reason", "无法放置")), 1.6)
			game.play_sfx("deny", 0.05)
		return false
	if not player.inventory.consume_costs(data.cost):
		return false
	var b := PlacedBuilding.new()
	b.setup(game, data, cell, rotation_index, false)
	b.position = cell_to_world(cell, data)
	world.building_root.add_child(b)
	placed.append(b)
	var key := _key(cell)
	var arr: Array = occupancy.get(key, [])
	arr.append(data.id)
	occupancy[key] = arr
	if game:
		game.play_sfx("ui_click", 0.0)
		game.spawn_build_puff(b.global_position + Vector3(0, 0.4, 0))
		game.quest_event("build", data.id)
		game._on_building_placed(b)
	return true

func remove_at(cell: Vector2i) -> bool:
	var key := _key(cell)
	var arr: Array = occupancy.get(key, [])
	if arr.is_empty():
		return false
	var target: PlacedBuilding = null
	for b in placed:
		if is_instance_valid(b) and b.cell == cell:
			target = b
	if target == null:
		return false
	var data := target.data
	for id in data.cost:
		var refund := maxi(1, int(ceil(float(data.cost[id]) * 0.5)))
		player.inventory.add_item(id, refund)
	placed.erase(target)
	arr.pop_back()
	if arr.is_empty():
		occupancy.erase(key)
	else:
		occupancy[key] = arr
	target.queue_free()
	if game:
		game.play_sfx("ui_click", 0.0)
		game.show_toast("已拆除%s，返还一半材料。" % data.display_name, 1.8)
	return true

func _key(cell: Vector2i) -> String:
	return "%d:%d" % [cell.x, cell.y]

func to_save() -> Array:
	var out: Array = []
	for b in placed:
		if is_instance_valid(b):
			out.append(b.to_save())
	return out

func from_save(data) -> void:
	for b in placed:
		if is_instance_valid(b):
			b.queue_free()
	placed.clear()
	occupancy.clear()
	if typeof(data) != TYPE_ARRAY:
		return
	for entry in data:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var id := str(entry.get("id", ""))
		var data_b: BuildingData = GameDB.building(id)
		if data_b == null:
			continue
		var c = entry.get("cell", [0, 0])
		var cell := Vector2i(int(c[0]), int(c[1]))
		var rot := int(entry.get("rotation", 0))
		var b := PlacedBuilding.new()
		b.setup(game, data_b, cell, rot, false)
		b.position = cell_to_world(cell, data_b)
		if entry.has("storage") and typeof(entry["storage"]) == TYPE_ARRAY:
			b.storage = entry["storage"].duplicate(true)
		world.building_root.add_child(b)
		placed.append(b)
		var key := _key(cell)
		var arr: Array = occupancy.get(key, [])
		arr.append(id)
		occupancy[key] = arr
