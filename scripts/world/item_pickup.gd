class_name ItemPickup
extends Node3D

var game: Node
var item_id := ""
var amount := 1
var item_data: ItemData
var visual: Node3D
var collected := false
var _t := 0.0
var _base_y := 0.0

func setup(p_game: Node, p_item: String, p_amount: int, pos: Vector3) -> void:
	game = p_game
	item_id = p_item
	amount = p_amount
	position = pos

func _ready() -> void:
	add_to_group("pickup")
	item_data = GameDB.item(item_id)
	visual = Node3D.new()
	add_child(visual)
	_build_visual()
	_base_y = position.y
	_t = randf() * TAU

func _build_visual() -> void:
	var color := item_data.icon_color if item_data else Color.WHITE
	var m := GameUtil.raw_mat(color, 0.4, 0.0, 0.3)
	GameUtil.sphere(visual, 0.16, m, Vector3.ZERO, Vector3(1.0, 0.85, 1.0), "Orb")
	var ring := TorusMesh.new()
	ring.inner_radius = 0.18
	ring.outer_radius = 0.23
	var mi := MeshInstance3D.new()
	mi.mesh = ring
	mi.rotation_degrees.x = 90
	mi.material_override = GameUtil.raw_mat(Color(1, 0.94, 0.7, 0.5), 0.3, 0.0, 0.8, true)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	visual.add_child(mi)

func _process(delta: float) -> void:
	if collected or game == null or game.player == null:
		return
	_t += delta
	visual.position.y = 0.45 + sin(_t * 3.0) * 0.12
	visual.rotation.y += delta * 1.4
	var p: Vector3 = game.player.global_position + Vector3(0, 0.8, 0)
	var dist := global_position.distance_to(p)
	if dist < 2.2:
		global_position = global_position.lerp(p, 1.0 - exp(-8.0 * delta))
	if dist < 0.9:
		_collect()

func _collect() -> void:
	collected = true
	var leftover: int = game.player.inventory.add_item(item_id, amount)
	if game:
		game.play_sfx("pickup", 0.08)
		if leftover < amount:
			EventBus.toast_requested.emit("%s +%d" % [item_data.display_name if item_data else item_id, amount - leftover], 1.2)
			game.quest_event("collect_item", item_id)
	if leftover > 0:
		collected = false
		amount = leftover
		return
	queue_free()
