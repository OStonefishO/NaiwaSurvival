class_name Barricade
extends StaticBody3D

var game: Node
var yaw := 0.0

func setup(p_game: Node, pos: Vector3, p_yaw: float) -> void:
	game = p_game
	position = pos
	yaw = p_yaw

func _ready() -> void:
	add_to_group("built_structure")
	collision_layer = 1
	collision_mask = 0
	rotation.y = yaw
	_build()

func _build() -> void:
	var wood := GameUtil.mat("wood", 0.9)
	var wood_dark := GameUtil.mat("wood_dark", 0.9)
	var rope := GameUtil.mat("cloth", 0.95)
	# main wall: 6 upright planks with a little irregularity
	for i in 6:
		var h := 1.35 + 0.14 * sin(float(i) * 1.9)
		GameUtil.box(self, Vector3(0.34, h, 0.13), wood if i % 2 == 0 else wood_dark,
			Vector3(-1.05 + i * 0.42, h * 0.5, 0.0), Vector3(0, 0, 1.5 * sin(float(i) * 2.1)), "Plank")
	# horizontal beams
	GameUtil.box(self, Vector3(2.45, 0.14, 0.16), wood_dark, Vector3(0, 0.45, 0.12), Vector3.ZERO, "BeamLow")
	GameUtil.box(self, Vector3(2.45, 0.14, 0.16), wood_dark, Vector3(0, 1.18, 0.12), Vector3.ZERO, "BeamHigh")
	# corner posts and rope lashings
	for x in [-1.18, 1.18]:
		GameUtil.cylinder(self, 0.1, 1.8, wood_dark, Vector3(x, 0.9, 0.0), Vector3.ZERO, 6, "Post")
		GameUtil.cylinder(self, 0.13, 0.18, rope, Vector3(x, 1.1, 0.12), Vector3(90, 0, 0), 8, "Lashing")
	# shield / pirate marker
	GameUtil.box(self, Vector3(0.5, 0.45, 0.05), GameUtil.raw_mat(Color("#8b2f28"), 0.9), Vector3(0.1, 0.9, -0.10), Vector3.ZERO, "Shield")
	GameUtil.sphere(self, 0.12, GameUtil.mat("bone", 0.8), Vector3(0.1, 0.95, -0.14), Vector3(1.0, 1.1, 0.2), "SkullBoss")
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2.45, 1.6, 0.32)
	shape.shape = box
	shape.position.y = 0.8
	add_child(shape)
	# contact shadow
	var quad := QuadMesh.new(); quad.size = Vector2(3.2, 1.1)
	var shadow := MeshInstance3D.new()
	shadow.mesh = quad
	shadow.rotation_degrees.x = -90
	shadow.position.y = 0.04
	shadow.material_override = GameUtil.blob_shadow_material()
	shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(shadow)
