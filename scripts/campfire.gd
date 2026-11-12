class_name CampfireSite
extends Node3D

var game: Node
var player: MilkFrog
var cooldown := 0.0
var light: OmniLight3D
var flames: CPUParticles3D
var embers: CPUParticles3D
var pot: Node3D
var flame_meshes: Node3D
var flame_phase := 0.0

func setup(p_game: Node, p_player: MilkFrog, pos: Vector3) -> void:
	game = p_game
	player = p_player
	position = pos

func _ready() -> void:
	add_to_group("interactable")
	_build()

func _build() -> void:
	var stone := GameUtil.mat("rock", 0.95)
	for i in 9:
		var a := TAU * float(i) / 9.0
		GameUtil.sphere(self, 0.20, stone, Vector3(cos(a) * 1.15, 0.12, sin(a) * 1.15), Vector3(1.25, 0.55, 1.0), "FireRing")
	for i in 4:
		var a := TAU * float(i) / 4.0 + 0.25
		GameUtil.cylinder(self, 0.11, 1.45, GameUtil.mat("wood_dark", 0.9), Vector3(cos(a) * 0.38, 0.36, sin(a) * 0.38), Vector3(0, -a * 57.3, 72), 6, "FireLog")
	# A little pot sits beside the fire, not on top of it.
	GameUtil.sphere(self, 0.28, GameUtil.mat("iron", 0.5, 0.35), Vector3(1.55, 0.32, 0.55), Vector3(1.0, 0.65, 1.0), "StewPot")
	GameUtil.sphere(self, 0.19, GameUtil.raw_mat(Color("#d8a14f"), 0.7, 0.0, 0.3), Vector3(1.55, 0.42, 0.55), Vector3(1.0, 0.12, 1.0), "Stew")
	# stylized flame sculpture layered with particles so the campfire reads from
	# above even on low-end mobile GPUs where point particles can be tiny.
	flame_meshes = Node3D.new()
	flame_meshes.position = Vector3(0, 0.22, 0)
	add_child(flame_meshes)
	var flame_mat := StandardMaterial3D.new()
	flame_mat.albedo_color = Color("#ff7b2e")
	flame_mat.emission_enabled = true
	flame_mat.emission = Color("#ff9b3e")
	flame_mat.emission_energy_multiplier = 2.4
	flame_mat.roughness = 0.5
	flame_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var inner_mat := StandardMaterial3D.new()
	inner_mat.albedo_color = Color("#ffe07a")
	inner_mat.emission_enabled = true
	inner_mat.emission = Color("#ffe9a3")
	inner_mat.emission_energy_multiplier = 3.0
	inner_mat.roughness = 0.4
	inner_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var flame_outer := GameUtil.cone(flame_meshes, 0.36, 1.15, flame_mat, Vector3(0, 0.58, 0), Vector3(0, 20, 0), 7, "FlameOuter")
	var flame_inner := GameUtil.cone(flame_meshes, 0.20, 0.72, inner_mat, Vector3(0, 0.40, 0.02), Vector3(0, -20, 0), 6, "FlameInner")
	flame_outer.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	flame_inner.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# sparks / embers
	embers = CPUParticles3D.new()
	embers.amount = 12
	embers.lifetime = 2.4
	embers.emitting = true
	embers.direction = Vector3(0, 1, 0)
	embers.spread = 26.0
	embers.initial_velocity_min = 0.35
	embers.initial_velocity_max = 1.0
	embers.gravity = Vector3(0.1, 0.3, 0.0)
	embers.scale_amount_min = 0.025
	embers.scale_amount_max = 0.06
	var quad := QuadMesh.new(); quad.size = Vector2.ONE
	embers.mesh = quad
	var em := GameUtil.raw_mat(Color("#ffd76b"), 0.3, 0.0, 1.5, true)
	em.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	em.albedo_texture = GameUtil.particle_texture()
	em.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	embers.material_override = em
	embers.position = Vector3(0, 0.9, 0)
	add_child(embers)
	light = OmniLight3D.new()
	light.light_color = Color("#ff9b4a")
	light.light_energy = 2.2
	light.omni_range = 5.5
	light.position = Vector3(0, 1.0, 0)
	light.shadow_enabled = false
	add_child(light)

func _process(delta: float) -> void:
	cooldown = maxf(0.0, cooldown - delta)
	flame_phase += delta
	if light:
		light.light_energy = 2.0 + sin(Time.get_ticks_msec() * 0.011) * 0.35 + sin(Time.get_ticks_msec() * 0.027) * 0.15
	if flame_meshes:
		var pulse := 1.0 + 0.10 * sin(flame_phase * 7.0)
		flame_meshes.scale = Vector3(0.92 + 0.1 * sin(flame_phase * 5.0), pulse, 0.92 + 0.1 * cos(flame_phase * 6.0))
		flame_meshes.rotation.y += delta * 0.8

func can_interact() -> bool:
	return cooldown <= 0.0

func get_prompt() -> String:
	return "在篝火边休息"

func interact(_p: Node) -> void:
	cooldown = 14.0
	if player:
		player.heal(35.0)
		player.feed(10.0)
	if game:
		game.set_respawn(global_position + Vector3(0, 0.1, 0))
		game.play_sfx("campfire")
		game.show_toast("热汤下肚，奶蛙恢复了精神 +35 HP；营火已设为重生点", 2.2)
