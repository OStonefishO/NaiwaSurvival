class_name SignalBeacon
extends Node3D

var game: Node
var lit := false
var flame: CPUParticles3D
var light: OmniLight3D
var beam: MeshInstance3D
var glow: MeshInstance3D
var pyre: Node3D
var beacon_beam: MeshInstance3D

func setup(p_game: Node, pos: Vector3) -> void:
	game = p_game
	position = pos

func _ready() -> void:
	add_to_group("interactable")
	_build()

func _build() -> void:
	var stone := GameUtil.mat("rock", 0.95)
	var wood := GameUtil.mat("wood", 0.9)
	var wood_dark := GameUtil.mat("wood_dark", 0.92)
	# stone dais
	for i in 3:
		GameUtil.cylinder(self, 2.2 - i * 0.25, 0.18, stone, Vector3(0, i * 0.18, 0), Vector3.ZERO, 10, "Dais")
	# pyre of logs
	pyre = Node3D.new(); pyre.position = Vector3(0, 0.52, 0); add_child(pyre)
	for i in 7:
		var a := TAU * float(i) / 7.0
		GameUtil.cylinder(pyre, 0.11, 1.8, wood_dark if i % 2 == 0 else wood,
			Vector3(cos(a) * 0.38, 0.55, sin(a) * 0.38), Vector3(0, -a * 57.3, 55), 6, "PyreLog")
	GameUtil.cylinder(pyre, 0.6, 0.4, stone, Vector3(0, 0.05, 0), Vector3.ZERO, 10, "PyreBase")
	# tall carved totem / mast
	GameUtil.cylinder(self, 0.18, 4.7, wood_dark, Vector3(-1.5, 2.7, 0.4), Vector3.ZERO, 8, "SignalPole")
	GameUtil.box(self, Vector3(1.0, 0.5, 0.12), wood, Vector3(-1.5, 4.2, 0.48), Vector3.ZERO, "SignalBanner")
	var red := GameUtil.raw_mat(Color("#a8332b"), 0.9)
	GameUtil.box(self, Vector3(0.45, 1.8, 0.04), red, Vector3(-1.5, 3.35, 0.5), Vector3(0, 0, -6), "SignalFlag")
	# unlit pile
	glow = GameUtil.sphere(self, 0.35, GameUtil.mat("gold", 0.4, 0.2, 0.4), Vector3(0, 1.3, 0), Vector3(1.4, 0.4, 1.4), "EmberGlow")
	glow.visible = false
	light = OmniLight3D.new(); light.light_color = Color("#ffbb55"); light.light_energy = 0.0; light.omni_range = 8.0
	light.position = Vector3(0, 2.0, 0); add_child(light)
	# flame particles, disabled until lit
	flame = CPUParticles3D.new()
	flame.amount = 55
	flame.lifetime = 1.4
	flame.emitting = false
	flame.direction = Vector3(0, 1, 0)
	flame.spread = 15.0
	flame.initial_velocity_min = 1.6
	flame.initial_velocity_max = 4.2
	flame.gravity = Vector3(0, 1.3, 0)
	flame.scale_amount_min = 0.25
	flame.scale_amount_max = 0.75
	var quad := QuadMesh.new(); quad.size = Vector2.ONE
	flame.mesh = quad
	var fm := GameUtil.raw_mat(Color("#ff772f"), 0.2, 0.0, 2.0, true)
	fm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fm.albedo_texture = GameUtil.particle_texture()
	fm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	fm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	flame.material_override = fm
	flame.position = Vector3(0, 1.3, 0)
	add_child(flame)
	# transparent light beam visible from across the island
	beam = MeshInstance3D.new()
	var cyl := CylinderMesh.new(); cyl.top_radius = 3.5; cyl.bottom_radius = 1.8; cyl.height = 40.0; cyl.radial_segments = 16; cyl.rings = 1
	beam.mesh = cyl
	var bm := GameUtil.raw_mat(Color(1.0, 0.72, 0.32, 0.14), 0.3, 0.0, 1.0, true)
	bm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bm.cull_mode = BaseMaterial3D.CULL_DISABLED
	beam.material_override = bm
	beam.position = Vector3(0, 21.0, 0)
	beam.visible = false
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(beam)
	beacon_beam = beam

func _process(delta: float) -> void:
	if light and lit:
		light.light_energy = 3.5 + sin(Time.get_ticks_msec() * 0.013) * 0.7
	if beam and lit:
		beam.rotation.y += delta * 0.1
		beam.scale = Vector3(1.0 + sin(Time.get_ticks_msec() * 0.002) * 0.05, 1.0, 1.0 + sin(Time.get_ticks_msec() * 0.002) * 0.05)

func can_interact() -> bool:
	return not lit

func get_prompt() -> String:
	if game == null:
		return "点燃信号火"
	if game.maps < 3:
		return "信号火：还需要 %d 张藏宝图" % (3 - game.maps)
	if game.wood < 5:
		return "信号火：还需要 %d 捆木材" % (5 - game.wood)
	return "点燃信号火，召唤海盗船长"

func interact(_p: Node) -> void:
	if lit or game == null:
		return
	if game.maps < 3 or game.wood < 5:
		game.show_toast("信号火还没准备好：需要 3 张藏宝图与 5 捆木材", 2.4)
		game.play_sfx("deny")
		return
	lit = true
	remove_from_group("interactable")
	game.on_beacon_lit()
	game.play_sfx("ignite")
	game.shake_camera(0.35, 0.5)
	flame.emitting = true
	beam.visible = true
	glow.visible = true
	light.light_energy = 4.0
	var tw := create_tween()
	tw.tween_property(beam, "scale", Vector3(1.1, 1.0, 1.1), 1.2).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(glow, "scale", Vector3(3.0, 1.0, 3.0), 0.8)
