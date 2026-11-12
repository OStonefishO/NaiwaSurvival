class_name TreasureChest
extends Node3D

var game: Node
var opened := false
var lid: Node3D
var glow_light: OmniLight3D
var glow: MeshInstance3D
var sparkle: CPUParticles3D
var index := 0
var chest_color := Color("#8d5b2d")

func setup(p_game: Node, p_index: int, pos: Vector3) -> void:
	game = p_game
	index = p_index
	position = pos

func _ready() -> void:
	add_to_group("interactable")
	_build_chest()

func _build_chest() -> void:
	var root := Node3D.new()
	add_child(root)
	var wood := GameUtil.raw_mat(chest_color, 0.82)
	var dark := GameUtil.mat("wood_dark", 0.9)
	var gold := GameUtil.mat("gold", 0.3, 0.45, 0.15)
	GameUtil.box(root, Vector3(1.25, 0.7, 0.8), wood, Vector3(0, 0.35, 0), Vector3.ZERO, "ChestBase")
	GameUtil.box(root, Vector3(1.3, 0.11, 0.86), dark, Vector3(0, 0.07, 0), Vector3.ZERO, "ChestFoot")
	for x in [-0.48, 0.48]:
		GameUtil.box(root, Vector3(0.08, 0.75, 0.84), gold, Vector3(x, 0.38, 0), Vector3.ZERO, "ChestBand")
	GameUtil.box(root, Vector3(0.18, 0.22, 0.06), gold, Vector3(0, 0.42, -0.42), Vector3.ZERO, "Lock")
	GameUtil.box(root, Vector3(0.08, 0.08, 0.08), dark, Vector3(0, 0.42, -0.46), Vector3.ZERO, "Keyhole")
	lid = Node3D.new()
	lid.position = Vector3(0, 0.7, 0.4)
	root.add_child(lid)
	GameUtil.box(lid, Vector3(1.25, 0.28, 0.8), wood, Vector3(0, 0.14, -0.4), Vector3.ZERO, "ChestLid")
	GameUtil.box(lid, Vector3(1.31, 0.09, 0.86), dark, Vector3(0, 0.3, -0.4), Vector3.ZERO, "ChestLidTop")
	for x in [-0.48, 0.48]:
		GameUtil.box(lid, Vector3(0.08, 0.3, 0.84), gold, Vector3(x, 0.15, -0.4), Vector3.ZERO, "LidBand")
	glow = GameUtil.sphere(root, 0.18, GameUtil.mat("gold", 0.3, 0.4, 1.4), Vector3(0, 0.58, 0), Vector3(0.8, 0.5, 0.8), "ChestGlow")
	glow.visible = false
	glow_light = OmniLight3D.new()
	glow_light.light_color = Color("#ffcc6c")
	glow_light.light_energy = 0.0
	glow_light.omni_range = 2.6
	glow_light.position = Vector3(0, 0.8, 0)
	add_child(glow_light)
	sparkle = CPUParticles3D.new()
	sparkle.amount = 18
	sparkle.lifetime = 1.4
	sparkle.one_shot = true
	sparkle.emitting = false
	sparkle.explosiveness = 0.85
	sparkle.direction = Vector3(0, 1, 0)
	sparkle.spread = 45.0
	sparkle.initial_velocity_min = 1.0
	sparkle.initial_velocity_max = 3.0
	sparkle.gravity = Vector3(0, -3.5, 0)
	sparkle.scale_amount_min = 0.035
	sparkle.scale_amount_max = 0.09
	var quad := QuadMesh.new(); quad.size = Vector2.ONE
	sparkle.mesh = quad
	var sm := GameUtil.raw_mat(Color("#ffe38b"), 0.3, 0.0, 1.0, true)
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	sparkle.material_override = sm
	sparkle.position = Vector3(0, 0.8, 0)
	add_child(sparkle)
	# faint idle sparkle so chests read as points of interest
	var idle := CPUParticles3D.new()
	idle.amount = 7
	idle.lifetime = 2.0
	idle.emitting = true
	idle.direction = Vector3(0, 1, 0)
	idle.spread = 35.0
	idle.initial_velocity_min = 0.1
	idle.initial_velocity_max = 0.35
	idle.gravity = Vector3(0, 0.1, 0)
	idle.scale_amount_min = 0.02
	idle.scale_amount_max = 0.05
	idle.mesh = quad
	idle.material_override = sm
	idle.position = Vector3(0, 0.6, 0)
	add_child(idle)

func can_interact() -> bool:
	return not opened

func get_prompt() -> String:
	return "打开藏宝箱"

func interact(_player: Node) -> void:
	if opened:
		return
	opened = true
	glow.visible = true
	sparkle.restart()
	if game:
		game.play_sfx("chest")
		game.on_chest_opened(self)
	var tw := create_tween()
	tw.tween_property(lid, "rotation_degrees:x", -102.0, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(glow_light, "light_energy", 2.4, 0.25)
	tw.parallel().tween_property(glow, "scale", Vector3(1.8, 1.2, 1.8), 0.4)
	tw.tween_interval(0.5)
	tw.tween_property(glow_light, "light_energy", 0.7, 1.0)
	remove_from_group("interactable")
