class_name Shelter
extends Node3D

var game: Node
var player: MilkFrog
var lantern: OmniLight3D
var flame: MeshInstance3D
var phase := 0.0

func setup(p_game: Node, p_player: MilkFrog, pos: Vector3, yaw := 0.0) -> void:
	game = p_game
	player = p_player
	position = pos
	rotation.y = yaw

func _ready() -> void:
	add_to_group("interactable")
	add_to_group("built_structure")
	_build()

func _build() -> void:
	var wood := GameUtil.mat("wood", 0.9)
	var wood_dark := GameUtil.mat("wood_dark", 0.9)
	var cloth := GameUtil.raw_mat(Color("#d6c39a"), 0.95)
	var cloth_dark := GameUtil.raw_mat(Color("#b5a078"), 0.96)
	# lean-to roof
	var roof := GameUtil.box(self, Vector3(3.2, 0.12, 2.4), cloth, Vector3(0, 1.55, -0.1), Vector3(-18, 0, 0), "ShelterRoof")
	roof.material_override = cloth
	GameUtil.box(self, Vector3(3.3, 0.1, 0.3), cloth_dark, Vector3(0, 1.28, 1.05), Vector3.ZERO, "ShelterTrim")
	# poles
	for x in [-1.5, 1.5]:
		for z in [-1.0, 1.0]:
			GameUtil.cylinder(self, 0.075, 1.7, wood_dark, Vector3(x, 0.85, z), Vector3(0, 0, 4 if z > 0 else -4), 6, "ShelterPole")
	# back wall
	for i in 4:
		GameUtil.box(self, Vector3(0.42, 1.25, 0.1), wood if i % 2 else wood_dark, Vector3(-0.7 + i * 0.46, 0.63, -1.05), Vector3.ZERO, "ShelterPlank")
	# bedroll
	GameUtil.box(self, Vector3(1.3, 0.12, 1.8), GameUtil.raw_mat(Color("#a84a38"), 0.95), Vector3(0, 0.14, 0.2), Vector3.ZERO, "Bedroll")
	GameUtil.box(self, Vector3(0.7, 0.16, 0.38), GameUtil.mat("cream", 0.95), Vector3(0, 0.24, -0.45), Vector3.ZERO, "Pillow")
	# little lantern
	lantern = OmniLight3D.new()
	lantern.light_color = Color("#ffbe6b")
	lantern.light_energy = 1.0
	lantern.omni_range = 3.4
	lantern.position = Vector3(1.1, 1.2, 0.4)
	add_child(lantern)
	GameUtil.sphere(self, 0.11, GameUtil.mat("gold", 0.3, 0.4, 1.5), Vector3(1.1, 1.2, 0.4), Vector3.ONE, "ShelterLantern")
	var quad := QuadMesh.new(); quad.size = Vector2(4.2, 3.2)
	var shadow := MeshInstance3D.new()
	shadow.mesh = quad
	shadow.rotation_degrees.x = -90
	shadow.position.y = 0.04
	shadow.material_override = GameUtil.blob_shadow_material()
	shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(shadow)

func _process(delta: float) -> void:
	phase += delta
	if lantern:
		lantern.light_energy = 0.9 + sin(phase * 3.2) * 0.12

func can_interact() -> bool:
	return true

func get_prompt() -> String:
	if game and game.is_night:
		return "在草棚里睡到天亮"
	return "在草棚里休息"

func interact(_p: Node) -> void:
	if game == null:
		return
	game.set_respawn(global_position + Vector3(0, 0.1, 0))
	if player:
		player.heal(20.0)
	if game.is_night:
		game.sleep_until_dawn()
	else:
		game.show_toast("草棚已经搭好。等夜幕降临再来睡一觉吧。", 2.0)
