extends Node3D

enum State { TITLE, PLAYING, PAUSED, DEAD, WON }

const PlayerScript = preload("res://scripts/player.gd")
const WorldScript = preload("res://scripts/world_builder.gd")
const CameraScript = preload("res://scripts/camera_rig.gd")
const EnemyScript = preload("res://scripts/enemy.gd")
const PickupScript = preload("res://scripts/pickup.gd")
const ChestScript = preload("res://scripts/chest.gd")
const CampfireScript = preload("res://scripts/campfire.gd")
const BeaconScript = preload("res://scripts/beacon.gd")
const HUDScript = preload("res://scripts/ui/hud.gd")
const AudioScript = preload("res://scripts/audio_manager.gd")
const BarricadeScript = preload("res://scripts/barricade.gd")
const ShelterScript = preload("res://scripts/shelter.gd")

const DAY_LENGTH := 120.0
const NIGHT_START := 0.66
const DAWN_START := 0.98
const RECIPE_COSTS := {
	"campfire": {"wood": 5, "stone": 3},
	"barricade": {"wood": 4},
	"shelter": {"wood": 8, "fiber": 5},
	"whetstone": {"stone": 4},
}

static var start_after_reload := false

var state: int = State.TITLE
var world: IslandWorld
var player: MilkFrog
var camera_rig: CameraRig
var hud: GameHUD
var audio: AudioManager
var chests: Array[TreasureChest] = []
var campfire_node: CampfireSite
var beacon_node: SignalBeacon
var boss: PirateFoe
var enemies: Array[PirateFoe] = []

var maps := 0
var wood := 0
var stone := 0
var fiber := 0
var coins := 0
var kills := 0
var hits_landed := 0
var chests_opened := 0
var play_time := 0.0
var boss_spawned := false
var boss_defeated := false
var beacon_lit := false
var start_position := Vector3.ZERO
var cutlass_bonus := 0.0
var day_number := 1
var day_time := 0.1
var is_night := false
var day_phase := "白天"
var respawn_point := Vector3.ZERO
var built_structures: Array[Node3D] = []
var _last_phase := ""
var _death_handling := false
var env: Environment
var sky_mat: ProceduralSkyMaterial
var night_ambience: CPUParticles3D

var sun: DirectionalLight3D
var fill_light: DirectionalLight3D
var clouds: Array[Node3D] = []
var birds: Array[Node3D] = []
var _hitstop_active := false
var _capture_done := false
var _end_timer := 0.0
var _end_pending := false
var _end_win := false

func _ready() -> void:
	_setup_input()
	_setup_environment()
	_build_world()
	_build_player()
	_build_camera()
	audio = AudioScript.new()
	audio.name = "Audio"
	add_child(audio)
	_build_gameplay_objects()
	_build_hud()
	_setup_touch_detection()
	var auto_start := _web_autostart_requested()
	if start_after_reload or auto_start:
		start_after_reload = false
		call_deferred("start_game")
	else:
		hud.show_title()
		_set_title_camera()
	_capture_if_requested()

func _web_autostart_requested() -> bool:
	if not OS.has_feature("web"):
		return false
	var bridge := Engine.get_singleton("JavaScriptBridge")
	if bridge == null:
		return false
	var search := str(bridge.call("eval", "window.location.search"))
	return "autostart=1" in search

func is_playing() -> bool:
	return state == State.PLAYING

func _setup_input() -> void:
	var actions := {
		"move_left": [KEY_A, KEY_LEFT],
		"move_right": [KEY_D, KEY_RIGHT],
		"move_up": [KEY_W, KEY_UP],
		"move_down": [KEY_S, KEY_DOWN],
		"dash": [KEY_SHIFT],
		"interact": [KEY_E],
		"pause": [KEY_ESCAPE],
		"craft": [KEY_B],
		"attack": [KEY_SPACE],
	}
	for action_name in actions:
		if not InputMap.has_action(action_name):
			InputMap.add_action(action_name)
		for key in actions[action_name]:
			var ev := InputEventKey.new()
			ev.physical_keycode = key
			InputMap.action_add_event(action_name, ev)
	# Mouse attack
	if not InputMap.has_action("attack"):
		InputMap.add_action("attack")
	var mb := InputEventMouseButton.new()
	mb.button_index = MOUSE_BUTTON_LEFT
	InputMap.action_add_event("attack", mb)

func _setup_environment() -> void:
	var we := WorldEnvironment.new()
	we.name = "WorldEnvironment"
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color("#356f8f")
	sky_mat.sky_horizon_color = Color("#ffd29a")
	sky_mat.sky_curve = 0.22
	sky_mat.ground_bottom_color = Color("#2a5452")
	sky_mat.ground_horizon_color = Color("#d0a264")
	sky_mat.sun_angle_max = 18.0
	sky_mat.sun_curve = 0.08
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.32
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 0.85
	env.tonemap_white = 1.0
	env.glow_enabled = true
	env.glow_intensity = 0.22
	env.glow_bloom = 0.04
	env.glow_hdr_threshold = 1.4
	env.fog_enabled = true
	env.fog_light_color = Color("#b58d66")
	env.fog_light_energy = 0.65
	env.fog_density = 0.0015
	env.fog_sky_affect = 0.15
	env.fog_aerial_perspective = 0.22
	env.adjustment_enabled = true
	env.adjustment_brightness = 0.98
	env.adjustment_contrast = 1.16
	env.adjustment_saturation = 1.14
	we.environment = env
	add_child(we)
	self.env = env
	self.sky_mat = sky_mat

	sun = DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-52.0, -38.0, 0.0)
	sun.light_color = Color("#ffe0b2")
	sun.light_energy = 0.98
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 90.0
	sun.directional_shadow_split_1 = 0.08
	sun.directional_shadow_split_2 = 0.22
	sun.directional_shadow_split_3 = 0.5
	sun.shadow_bias = 0.06
	add_child(sun)

	fill_light = DirectionalLight3D.new()
	fill_light.name = "Fill"
	fill_light.rotation_degrees = Vector3(25.0, 142.0, 0.0)
	fill_light.light_color = Color("#6fb6c9")
	fill_light.light_energy = 0.22
	fill_light.shadow_enabled = false
	add_child(fill_light)

	_build_clouds()
	_build_birds()

func _build_clouds() -> void:
	var cloud_mat := GameUtil.raw_mat(Color(1.0, 0.95, 0.85, 0.34), 0.9, 0.0, 0.1, true)
	cloud_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	cloud_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	cloud_mat.billboard_mode = BaseMaterial3D.BILLBOARD_DISABLED
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	for i in 7:
		var root := Node3D.new()
		root.name = "Cloud_%d" % i
		var angle := rng.randf_range(0.0, TAU)
		var dist := rng.randf_range(38.0, 90.0)
		root.position = Vector3(cos(angle) * dist, rng.randf_range(24.0, 36.0), sin(angle) * dist)
		add_child(root)
		var puffs := rng.randi_range(3, 5)
		for p in puffs:
			var sphere := SphereMesh.new()
			sphere.radial_segments = 10
			sphere.rings = 5
			sphere.radius = rng.randf_range(2.5, 5.5)
			sphere.height = sphere.radius * 2.0
			var mi := MeshInstance3D.new()
			mi.mesh = sphere
			mi.material_override = cloud_mat
			mi.position = Vector3(rng.randf_range(-5, 5), rng.randf_range(-0.8, 0.8), rng.randf_range(-2.5, 2.5))
			mi.scale = Vector3(1.0, 0.28, 0.65)
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			root.add_child(mi)
		clouds.append(root)

func _build_birds() -> void:
	var bird_mat := GameUtil.raw_mat(Color("#233f43"), 0.8)
	for i in 3:
		var root := Node3D.new()
		root.name = "Bird_%d" % i
		var body := MeshInstance3D.new()
		var bm := BoxMesh.new(); bm.size = Vector3(0.16, 0.12, 0.55)
		body.mesh = bm; body.material_override = bird_mat
		root.add_child(body)
		for side in [-1, 1]:
			var wing := MeshInstance3D.new()
			var wm := BoxMesh.new(); wm.size = Vector3(1.1, 0.045, 0.24)
			wing.mesh = wm; wing.material_override = bird_mat
			wing.position = Vector3(0.55 * side, 0.06, 0.0)
			wing.rotation_degrees.z = 18.0 * side
			root.add_child(wing)
		root.position = Vector3(-24 + i * 18, 22 + i * 3, -18 + i * 11)
		add_child(root)
		birds.append(root)

func _build_world() -> void:
	world = WorldScript.new()
	world.name = "IslandWorld"
	add_child(world)
	world.build(20261109)
	start_position = Vector3(4.0, world.height_at(4.0, 30.0) + 0.2, 30.0)

func _build_player() -> void:
	player = PlayerScript.new()
	player.name = "MilkFrog"
	player.position = start_position
	player.rotation.y = PI
	player.setup(self, null, world)
	add_child(player)
	player.stats_changed.emit(player.health, player.MAX_HEALTH, player.hunger)

func _build_camera() -> void:
	camera_rig = CameraScript.new()
	camera_rig.name = "CameraRig"
	add_child(camera_rig)
	camera_rig.set_target(player)
	player.camera_rig = camera_rig
	camera_rig.camera.fov = 40.0

func _set_title_camera() -> void:
	camera_rig.title_mode = true
	camera_rig.menu_target = player.global_position + Vector3(0, 1.15, 0)
	camera_rig.orbit_radius = 6.4
	camera_rig.orbit_height = 3.0
	camera_rig.orbit_angle = 1.82
	var cam_pos := camera_rig.menu_target + Vector3(cos(camera_rig.orbit_angle) * camera_rig.orbit_radius, camera_rig.orbit_height, sin(camera_rig.orbit_angle) * camera_rig.orbit_radius)
	camera_rig.camera.global_position = cam_pos
	camera_rig.camera.look_at(camera_rig.menu_target, Vector3.UP)

func _build_gameplay_objects() -> void:
	# Chests
	for i in world.chest_positions.size():
		var chest := ChestScript.new()
		chest.name = "Chest_%d" % i
		chest.setup(self, i, world.chest_positions[i] + Vector3(0, 0.12, 0))
		add_child(chest)
		chests.append(chest)
	# Campfire at the camp ring
	campfire_node = CampfireScript.new()
	campfire_node.name = "Campfire"
	campfire_node.setup(self, player, world.camp_pos + Vector3(3.4, 0.1, -1.2))
	add_child(campfire_node)
	# Beacon at the summit
	beacon_node = BeaconScript.new()
	beacon_node.name = "SignalBeacon"
	beacon_node.setup(self, world.beacon_pos + Vector3(0, 0.15, 0))
	add_child(beacon_node)
	# Loot in the world
	_spawn_initial_loot()

func _build_hud() -> void:
	hud = HUDScript.new()
	hud.name = "HUD"
	hud.setup(self, player, world)
	add_child(hud)
	hud.start_game_requested.connect(start_game)
	hud.restart_requested.connect(restart_game)
	hud.resume_requested.connect(_resume_game)
	hud.title_requested.connect(return_to_title)
	hud.quit_requested.connect(func(): get_tree().quit())
	hud.pause_toggle_requested.connect(_on_pause_toggle)
	_update_hud()

func _setup_touch_detection() -> void:
	var touch := DisplayServer.is_touchscreen_available() or OS.has_feature("mobile") or OS.has_feature("web_android") or OS.has_feature("web_ios")
	if "--touch" in OS.get_cmdline_user_args():
		touch = true
	if hud:
		hud.set_touch_mode(touch)

func start_game() -> void:
	if state == State.PLAYING:
		return
	state = State.PLAYING
	get_tree().paused = false
	beacon_lit = false
	maps = 0
	wood = 0
	stone = 0
	fiber = 0
	coins = 0
	kills = 0
	hits_landed = 0
	chests_opened = 0
	play_time = 0.0
	cutlass_bonus = 0.0
	day_number = 1
	day_time = 0.10
	is_night = false
	_last_phase = ""
	_death_handling = false
	boss_spawned = false
	boss_defeated = false
	boss = null
	# reset player
	player.dead = false
	player.health = MilkFrog.MAX_HEALTH
	player.hunger = MilkFrog.MAX_HUNGER
	player.global_position = start_position
	player.rotation.y = PI
	player.velocity = Vector3.ZERO
	player.visual.rotation_degrees = Vector3.ZERO
	player.visual.position = Vector3.ZERO
	player.camera_rig = camera_rig
	# reset dynamic objects
	for e in enemies:
		if is_instance_valid(e):
			e.queue_free()
	enemies.clear()
	for c in chests:
		if is_instance_valid(c):
			c.queue_free()
	chests.clear()
	for n in get_tree().get_nodes_in_group("pickup"):
		if is_instance_valid(n):
			n.queue_free()
	for b in get_tree().get_nodes_in_group("built_structure"):
		if is_instance_valid(b):
			b.queue_free()
	built_structures.clear()
	if campfire_node and is_instance_valid(campfire_node):
		campfire_node.queue_free()
	if beacon_node and is_instance_valid(beacon_node):
		beacon_node.queue_free()
	# rebuild
	for i in world.chest_positions.size():
		var chest := ChestScript.new()
		chest.name = "Chest_%d" % i
		chest.setup(self, i, world.chest_positions[i] + Vector3(0, 0.12, 0))
		add_child(chest)
		chests.append(chest)
	campfire_node = CampfireScript.new()
	campfire_node.name = "Campfire"
	campfire_node.setup(self, player, world.camp_pos + Vector3(3.4, 0.1, -1.2))
	add_child(campfire_node)
	respawn_point = campfire_node.global_position + Vector3(0, 0.3, 0)
	beacon_node = BeaconScript.new()
	beacon_node.name = "SignalBeacon"
	beacon_node.setup(self, world.beacon_pos + Vector3(0, 0.15, 0))
	add_child(beacon_node)
	_spawn_initial_loot()
	_spawn_initial_enemies()
	_update_day_phase()
	_update_environment_time(day_time)
	hud.begin_game()
	hud.set_touch_mode(hud.touch_mode)
	camera_rig.start_game()
	audio.start_music()
	_update_hud()
	_update_objective()
	hud.set_day_phase(day_number, day_phase, is_night)
	hud.show_toast("第 1 天。收集木材、石头与纤维，在夜晚来临前搭好营地。", 4.0)

func _spawn_initial_loot() -> void:
	var coconut_spots := [
		Vector3(-11.6, 0, 29.8), Vector3(-16.2, 0, 26.2), Vector3(19.2, 0, 21.2),
		Vector3(26.4, 0, 14.3), Vector3(29.0, 0, -0.8), Vector3(-27.8, 0, 9.1),
		Vector3(-30.2, 0, -11.2), Vector3(-12.7, 0, -23.4), Vector3(3.4, 0, -27.6),
		Vector3(16.5, 0, -24.5), Vector3(25.2, 0, -17.0), Vector3(-3.2, 0, 31.0)
	]
	for p in coconut_spots:
		_spawn_pickup(Pickup.Kind.COCONUT, Vector3(p.x, world.height_at(p.x, p.z) + 0.1, p.z))
	var wood_spots := [
		Vector3(7.0, 0, 14.5), Vector3(12.5, 0, 14.2), Vector3(8.0, 0, 21.0),
		Vector3(-2.6, 0, 21.0), Vector3(1.7, 0, 19.8), Vector3(4.0, 0, 15.0),
		Vector3(-21.5, 0, -2.0), Vector3(-24.8, 0, -8.0), Vector3(7.4, 0, -0.5),
		Vector3(10.2, 0, -7.5), Vector3(18.6, 0, -10.5), Vector3(24.0, 0, 8.0)
	]
	for p in wood_spots:
		_spawn_pickup(Pickup.Kind.WOOD, Vector3(p.x, world.height_at(p.x, p.z) + 0.1, p.z))
	var coin_spots := [
		Vector3(12.0, 0, 20.5), Vector3(8.0, 0, 14.0), Vector3(14.0, 0, 16.0),
		Vector3(-25.3, 0, -11.5), Vector3(-22.0, 0, -2.5), Vector3(21.0, 0, 7.0),
		Vector3(27.4, 0, 11.4), Vector3(6.0, 0, -25.0), Vector3(12.0, 0, -21.5)
	]
	for p in coin_spots:
		_spawn_pickup(Pickup.Kind.COIN, Vector3(p.x, world.height_at(p.x, p.z) + 0.2, p.z))
	var stone_spots := [
		Vector3(-20.0, 0, 3.8), Vector3(-25.0, 0, -9.5), Vector3(5.5, 0, -8.5),
		Vector3(16.5, 0, -14.5), Vector3(1.5, 0, 10.5), Vector3(22.0, 0, 2.5),
		Vector3(-9.0, 0, 20.0), Vector3(18.0, 0, 22.0), Vector3(-2.0, 0, -21.0),
		Vector3(11.0, 0, 4.0), Vector3(28.0, 0, -7.0), Vector3(-16.0, 0, -18.0)
	]
	for p in stone_spots:
		_spawn_pickup(Pickup.Kind.STONE, Vector3(p.x, world.height_at(p.x, p.z) + 0.1, p.z))
	var fiber_spots := [
		Vector3(3.0, 0, 18.0), Vector3(-8.0, 0, 12.0), Vector3(12.0, 0, 8.0),
		Vector3(-18.0, 0, 10.0), Vector3(20.0, 0, -4.0), Vector3(-6.0, 0, -18.0),
		Vector3(14.0, 0, -22.0), Vector3(26.0, 0, -8.0), Vector3(-26.0, 0, 16.0),
		Vector3(-14.0, 0, -14.0), Vector3(6.0, 0, 26.0), Vector3(2.0, 0, -3.0)
	]
	for p in fiber_spots:
		_spawn_pickup(Pickup.Kind.FIBER, Vector3(p.x, world.height_at(p.x, p.z) + 0.1, p.z))

func _spawn_initial_enemies() -> void:
	var initial := [
		[0, world.enemy_spawns[0]],
		[0, world.enemy_spawns[1]],
		[1, world.enemy_spawns[2]],
		[0, world.enemy_spawns[3]],
	]
	for entry in initial:
		var kind: int = entry[0]
		var pos: Vector3 = entry[1]
		spawn_enemy(kind, pos)

func _spawn_pickup(kind: int, pos: Vector3) -> void:
	var p := PickupScript.new()
	p.setup(self, player, kind, pos)
	add_child(p)

func spawn_enemy(kind: int, pos: Vector3) -> void:
	var e := EnemyScript.new()
	e.setup(self, player, world, kind, pos)
	add_child(e)
	enemies.append(e)

func _spawn_boss() -> void:
	if boss_spawned:
		return
	boss_spawned = true
	var pos := world.beacon_pos + Vector3(0, 0.3, 4.5)
	boss = EnemyScript.new()
	boss.setup(self, player, world, PirateFoe.Kind.BOSS, pos)
	add_child(boss)
	enemies.append(boss)
	hud.show_boss("骷髅船长 · 海盗湾的诅咒", boss.max_health)
	show_toast("海面传来低沉的笑声……骷髅船长出现了！", 3.0)
	shake_camera(0.5, 0.6)
	play_sfx("slam")

func _on_pause_toggle() -> void:
	if state == State.PLAYING:
		_pause_game()
	elif state == State.PAUSED:
		_resume_game()

func _pause_game() -> void:
	if state != State.PLAYING:
		return
	state = State.PAUSED
	get_tree().paused = true
	hud.pause_changed(true)

func _resume_game() -> void:
	if state != State.PAUSED:
		return
	get_tree().paused = false
	state = State.PLAYING
	hud.pause_changed(false)

func toggle_pause() -> void:
	_on_pause_toggle()

func restart_game() -> void:
	get_tree().paused = false
	start_after_reload = true
	get_tree().reload_current_scene()

func return_to_title() -> void:
	get_tree().paused = false
	start_after_reload = false
	get_tree().reload_current_scene()

func _process(delta: float) -> void:
	if state == State.PLAYING:
		play_time += delta
		if not _end_pending:
			_advance_day(delta)
		if boss != null and is_instance_valid(boss):
			hud.update_boss(boss.health, boss.max_health)
		if _end_pending:
			_end_timer -= delta
			if _end_timer <= 0.0:
				_end_pending = false
				_end_game(_end_win)
	# ambient motion
	for i in clouds.size():
		var c := clouds[i]
		if c:
			c.position.x += delta * (0.4 + 0.12 * i)
			if c.position.x > 95.0:
				c.position.x = -95.0
	for i in birds.size():
		var b := birds[i]
		if b:
			var t := Time.get_ticks_msec() * 0.0001 + i * 1.2
			b.position = Vector3(cos(t * 2.3 + i) * 32.0, 22.0 + sin(t * 1.7 + i) * 2.0, sin(t * 1.3 + i) * 30.0)
			b.rotation.y = t * 2.3 + PI * 0.5
			b.rotation.z = sin(Time.get_ticks_msec() * 0.006 + i) * 0.18

func _phase_for(t: float) -> String:
	if t >= NIGHT_START:
		return "夜晚"
	elif t >= 0.53:
		return "黄昏"
	return "白天"

func _update_day_phase() -> void:
	day_phase = _phase_for(day_time)
	if hud:
		hud.set_day_phase(day_number, day_phase, is_night)

func _advance_day(delta: float) -> void:
	var old_phase := day_phase
	day_time += delta / DAY_LENGTH
	if day_time >= 1.0:
		day_time -= 1.0
		day_number += 1
		var was_night := is_night
		is_night = false
		_on_dawn(was_night)
	elif day_time >= NIGHT_START and not is_night:
		is_night = true
		_on_nightfall()
	_update_day_phase()
	if day_phase != old_phase:
		_update_objective()
	_update_environment_time(day_time)

func _on_nightfall() -> void:
	is_night = true
	show_toast("夜幕降临。海盗的亡魂开始游荡，点燃营火，守住营地。", 3.6)
	play_sfx("enemy_windup", 0.12)
	for c in clouds:
		if c:
			c.visible = false
	for b in birds:
		if b:
			b.visible = false
	_spawn_night_wave()
	_update_objective()

func _on_dawn(was_night := true) -> void:
	is_night = false
	day_phase = "白天"
	player.heal(16.0)
	for c in clouds:
		if c:
			c.visible = true
	for b in birds:
		if b:
			b.visible = true
	if was_night:
		show_toast("第 %d 天，你活下来了。白天适合收集和建造。" % day_number, 3.2)
		play_sfx("heal", 0.04)
		_trim_night_enemies()
	_update_day_phase()
	_update_environment_time(day_time)
	_update_objective()

func _trim_night_enemies() -> void:
	var living: Array[PirateFoe] = []
	for e in enemies:
		if is_instance_valid(e) and not e.dead:
			living.append(e)
	while living.size() > 8:
		var e: PirateFoe = living.pop_back()
		if e == boss:
			continue
		enemies.erase(e)
		e.queue_free()

func _spawn_night_wave() -> void:
	if not is_playing():
		return
	var wave := mini(2 + day_number, 7)
	var spawned := 0
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for i in wave:
		if enemies.size() >= 12:
			break
		var a := rng.randf() * TAU
		var dist := rng.randf_range(12.0, 24.0)
		var pos := player.global_position + Vector3(cos(a) * dist, 0.0, sin(a) * dist)
		if not world.is_walkable(pos):
			pos = player.global_position + Vector3(cos(a) * 12.0, 0.0, sin(a) * 12.0)
		if not world.is_walkable(pos):
			continue
		pos.y = world.height_at(pos.x, pos.z) + 0.2
		var kind := PirateFoe.Kind.SKELETON if rng.randf() < 0.72 else PirateFoe.Kind.CRAB
		spawn_enemy(kind, pos)
		spawned += 1
	if spawned > 0:
		play_sfx("slam", 0.3)
		shake_camera(0.15, 0.25)

func _update_environment_time(t: float) -> void:
	if env == null or sky_mat == null:
		return
	var n := 0.0
	if t >= 0.53 and t < NIGHT_START:
		n = smoothstep(0.53, NIGHT_START, t)
	elif t >= NIGHT_START and t < DAWN_START:
		n = 1.0
	elif t >= DAWN_START:
		n = 1.0 - smoothstep(DAWN_START, 1.0, t)
	var night_amount := clampf(n, 0.0, 1.0)
	sun.light_energy = lerpf(0.98, 0.05, night_amount)
	sun.light_color = Color("#ffe0b2").lerp(Color("#ff9a5a"), clampf(night_amount * 1.8, 0.0, 1.0)).lerp(Color("#7786ad"), clampf(night_amount - 0.5, 0.0, 1.0) * 0.6)
	sun.rotation_degrees = Vector3(lerpf(-52.0, -8.0, night_amount), lerpf(-38.0, 118.0, night_amount), 0.0)
	fill_light.light_energy = lerpf(0.22, 1.35, night_amount)
	fill_light.light_color = Color("#6fb6c9").lerp(Color("#a8c2ee"), night_amount)
	if night_amount > 0.58:
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.ambient_light_color = Color("#526a86")
		env.ambient_light_energy = lerpf(0.45, 0.7, night_amount)
	else:
		env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
		env.ambient_light_energy = lerpf(0.32, 0.45, night_amount)
	env.tonemap_exposure = lerpf(0.85, 0.80, night_amount)
	env.fog_light_color = Color("#b58d66").lerp(Color("#22364d"), night_amount)
	env.fog_density = lerpf(0.0015, 0.0021, night_amount)
	env.glow_intensity = lerpf(0.22, 0.42, night_amount)
	var dusk := sin(night_amount * PI)
	var top := Color("#356f8f").lerp(Color("#061426"), night_amount)
	var horizon := Color("#ffd29a").lerp(Color("#e16f3f"), dusk * 0.65).lerp(Color("#18283c"), night_amount)
	sky_mat.sky_top_color = top
	sky_mat.sky_horizon_color = horizon
	sky_mat.ground_horizon_color = Color("#d0a264").lerp(Color("#213444"), night_amount)
	sky_mat.ground_bottom_color = Color("#2a5452").lerp(Color("#08131d"), night_amount)

func get_attack_bonus() -> float:
	return cutlass_bonus

func can_afford(id: String) -> bool:
	if not RECIPE_COSTS.has(id):
		return false
	var cost: Dictionary = RECIPE_COSTS[id]
	for k in cost:
		match k:
			"wood":
				if wood < int(cost[k]): return false
			"stone":
				if stone < int(cost[k]): return false
			"fiber":
				if fiber < int(cost[k]): return false
	return true

func try_craft(id: String) -> bool:
	if not is_playing() or not RECIPE_COSTS.has(id):
		return false
	if not can_afford(id):
		show_toast("材料不够。去岛上砍木材、敲石头、割纤维吧。", 2.2)
		return false
	var target := Vector3.ZERO
	if id != "whetstone":
		target = _build_target_position()
		if target == Vector3.ZERO:
			show_toast("奶蛙面前没有合适的空地。换个方向再试。", 2.0)
			return false
		if built_structures.size() >= 24:
			show_toast("营地已经相当拥挤了。", 2.0)
			return false
	var yaw := player.rotation.y
	match id:
		"campfire":
			var c := CampfireScript.new()
			c.setup(self, player, target)
			add_child(c)
			c.name = "BuiltCampfire_%d" % built_structures.size()
			built_structures.append(c)
			set_respawn(target)
			play_sfx("campfire")
			show_toast("营火建好了。它照亮营地，也成为了重生点。", 2.4)
		"barricade":
			var dir := player.facing_dir
			if dir.length_squared() < 0.01:
				dir = Vector3(0, 0, -1)
			var b := BarricadeScript.new()
			b.setup(self, target, atan2(dir.x, dir.z))
			add_child(b)
			b.name = "Barricade_%d" % built_structures.size()
			built_structures.append(b)
			play_sfx("chest", 0.15)
			show_toast("木栅栏立起来了。海盗得绕路，或者把怒火发泄在木板上。", 2.2)
		"shelter":
			var s := ShelterScript.new()
			s.setup(self, player, target, yaw)
			add_child(s)
			s.name = "Shelter_%d" % built_structures.size()
			built_structures.append(s)
			set_respawn(target)
			play_sfx("chest", 0.1)
			show_toast("草棚搭好了。夜晚可以睡到天亮，也会记录重生点。", 2.4)
		"whetstone":
			cutlass_bonus += 8.0
			play_sfx("hit", 0.2)
			show_toast("磨刀石让弯刀更锋利了：攻击 +8。", 2.0)
	var cost: Dictionary = RECIPE_COSTS[id]
	for k in cost:
		match k:
			"wood": wood -= int(cost[k])
			"stone": stone -= int(cost[k])
			"fiber": fiber -= int(cost[k])
	update_hud_and_objective()
	spawn_hit_sparks(player.global_position + player.facing_dir * 2.0 + Vector3(0, 0.4, 0), Vector3.UP)
	return true

func _build_target_position() -> Vector3:
	var dir := player.facing_dir
	if dir.length_squared() < 0.01:
		dir = Vector3(0, 0, -1)
	var target := player.global_position + dir.normalized() * 2.5
	target.y = world.height_at(target.x, target.z) + 0.08
	if not world.is_walkable(target):
		return Vector3.ZERO
	for s in built_structures:
		if is_instance_valid(s) and s.global_position.distance_to(target) < 2.2:
			return Vector3.ZERO
	for chest in chests:
		if is_instance_valid(chest) and chest.global_position.distance_to(target) < 1.8:
			return Vector3.ZERO
	return target

func set_respawn(pos: Vector3) -> void:
	respawn_point = pos + Vector3(0, 0.35, 0)

func sleep_until_dawn() -> void:
	if not is_night or state != State.PLAYING:
		return
	player.invulnerable = 3.0
	hud.fade_out(0.55)
	await get_tree().create_timer(0.65).timeout
	if state != State.PLAYING:
		return
	day_number += 1
	day_time = 0.05
	is_night = false
	day_phase = "白天"
	player.heal(35.0)
	player.hunger = maxf(player.hunger, 65.0)
	_update_day_phase()
	_update_environment_time(day_time)
	for c in clouds:
		if c:
			c.visible = true
	for b in birds:
		if b:
			b.visible = true
	_trim_night_enemies()
	_update_hud()
	_update_objective()
	hud.fade_in(0.8)
	show_toast("在草棚里睡到了第 %d 天。奶蛙恢复了精神。" % day_number, 3.0)

func on_player_died() -> void:
	if state != State.PLAYING or _death_handling:
		return
	_death_handling = true
	state = State.DEAD
	touch_off()
	audio.set_music_muffled(true)
	hud.fade_out(0.7)
	show_toast("奶蛙被击倒了……营地里的篝火还在燃烧。", 2.4)
	await get_tree().create_timer(2.2).timeout
	if state == State.WON:
		_death_handling = false
		return
	wood = int(wood * 0.75)
	stone = int(stone * 0.75)
	fiber = int(fiber * 0.75)
	coins = int(coins * 0.75)
	var target := respawn_point if respawn_point != Vector3.ZERO else start_position
	player.revive_at(target)
	player.hunger = maxf(player.hunger, 55.0)
	state = State.PLAYING
	_death_handling = false
	audio.set_music_muffled(false)
	camera_rig.follow_pos = target
	camera_rig.camera.global_position = target + camera_rig.follow_offset
	camera_rig.camera.look_at(target + camera_rig.look_offset, Vector3.UP)
	_update_hud()
	_update_objective()
	hud.set_touch_mode(hud.touch_mode)
	hud.fade_in(0.9)
	show_toast("奶蛙在营火边醒来，失去了部分物资。天还没亮，继续撑下去。", 3.4)
	play_sfx("heal", 0.02)

func on_enemy_killed(enemy: Node) -> void:
	kills += 1
	coins += 2
	_update_hud()
	var pos := (enemy as Node3D).global_position
	_spawn_coin_drop(pos + Vector3(randf_range(-0.4, 0.4), 0.2, randf_range(-0.4, 0.4)))
	if randf() < 0.28:
		_spawn_pickup(Pickup.Kind.COCONUT, pos + Vector3(randf_range(-0.6, 0.6), 0.1, randf_range(-0.6, 0.6)))
	if randf() < 0.18:
		_spawn_pickup(Pickup.Kind.STONE, pos + Vector3(randf_range(-0.7, 0.7), 0.1, randf_range(-0.7, 0.7)))
	if enemy == boss or (boss != null and enemy == boss):
		boss_defeated = true
		boss = null
		hud.hide_boss()
		play_sfx("victory")
		show_toast("船长倒下了！海盗湾的诅咒解除了。", 3.0)
		_end_pending = true
		_end_timer = 1.8
		_end_win = true
		shake_camera(0.55, 0.5)

func _spawn_coin_drop(pos: Vector3) -> void:
	var p := PickupScript.new()
	p.setup(self, player, Pickup.Kind.COIN, pos)
	add_child(p)
	p.visual.scale = Vector3.ONE * 0.7

func add_hit() -> void:
	hits_landed += 1

func collect_pickup(pickup: Pickup) -> void:
	var pickup_pos := pickup.global_position
	match pickup.kind:
		Pickup.Kind.COCONUT:
			player.feed(26.0)
			player.heal(7.0)
			play_sfx("pickup")
			_schedule_resource_respawn(Pickup.Kind.COCONUT, pickup_pos)
		Pickup.Kind.WOOD:
			wood += 1
			play_sfx("pickup")
			_schedule_resource_respawn(Pickup.Kind.WOOD, pickup_pos)
		Pickup.Kind.STONE:
			stone += 1
			play_sfx("pickup")
			_schedule_resource_respawn(Pickup.Kind.STONE, pickup_pos)
		Pickup.Kind.FIBER:
			fiber += 1
			play_sfx("pickup")
			_schedule_resource_respawn(Pickup.Kind.FIBER, pickup_pos)
		Pickup.Kind.COIN:
			coins += 1
			play_sfx("coin")
		Pickup.Kind.MAP:
			maps = mini(3, maps + 1)
			play_sfx("map")
		Pickup.Kind.HEART:
			player.heal(20.0)
	update_hud_and_objective()
	spawn_hit_sparks(pickup_pos + Vector3(0, 0.4, 0), Vector3.UP)

func _schedule_resource_respawn(kind: int, pos: Vector3) -> void:
	var delay := randf_range(38.0, 58.0)
	var timer := get_tree().create_timer(delay)
	timer.timeout.connect(func():
		if not is_inside_tree():
			return
		if state == State.PLAYING or state == State.PAUSED:
			_spawn_pickup(kind, Vector3(pos.x, world.height_at(pos.x, pos.z) + 0.1, pos.z))
	)

func on_chest_opened(chest: TreasureChest) -> void:
	chests_opened += 1
	maps = mini(3, maps + 1)
	coins += 20
	wood += 1
	stone += 2
	fiber += 1
	play_sfx("map")
	show_toast("找到藏宝图碎片！  %d / 3" % maps, 2.4)
	spawn_hit_sparks(chest.global_position + Vector3(0, 1.0, 0), Vector3.UP)
	for i in 6:
		_spawn_coin_drop(chest.global_position + Vector3(randf_range(-0.8, 0.8), 0.4, randf_range(-0.8, 0.8)))
	# a skeleton guard is awakened by the treasure
	_spawn_chest_guard(chest.global_position + Vector3(randf_range(-2.5, 2.5), 0, randf_range(-2.5, 2.5)))
	update_hud_and_objective()
	if maps >= 3:
		show_toast("三张藏宝图集齐了！带着 5 捆木材登上山巅点燃信号火。", 4.0)
		play_sfx("victory")

func _spawn_chest_guard(pos: Vector3) -> void:
	var ground := world.height_at(pos.x, pos.z)
	var kind := PirateFoe.Kind.SKELETON if randf() < 0.7 else PirateFoe.Kind.CRAB
	spawn_enemy(kind, Vector3(pos.x, ground + 0.2, pos.z))

func on_beacon_lit() -> void:
	beacon_lit = true
	wood = maxi(0, wood - 5)
	update_hud_and_objective()
	show_toast("信号火燃起来了。海面不再平静……", 3.0)
	await get_tree().create_timer(2.0).timeout
	if state == State.PLAYING:
		_spawn_boss()

func update_hud() -> void:
	if hud:
		hud.set_resources(wood, stone, fiber, coins, maps, 3)

func update_hud_and_objective() -> void:
	update_hud()
	_update_objective()

func _update_hud() -> void:
	if hud:
		hud.set_resources(wood, stone, fiber, coins, maps, 3)
		hud.set_player_stats(player.health, MilkFrog.MAX_HEALTH, player.hunger)
		hud.set_day_phase(day_number, day_phase, is_night)

func _update_objective() -> void:
	if hud == null:
		return
	if boss_spawned:
		hud.set_objective("击败骷髅船长", "击碎海盗湾的诅咒，为奶蛙打开归途")
	elif maps >= 3 and not beacon_lit:
		if wood >= 5:
			hud.set_objective("点燃山巅的信号火（可选逃离）", "藏宝图 3/3 · 木材 %d/5 · 前往北侧山顶" % wood)
		else:
			hud.set_objective("收集木材  %d/5" % wood, "藏宝图已集齐，再找些木材就能点燃信号火")
	elif is_night:
		hud.set_objective("第 %d 天 · 夜晚 · 活到天亮" % day_number, "海盗的亡魂正在游荡 · 藏宝图 %d/3 · 木材 %d/5" % [maps, wood])
	else:
		hud.set_objective("第 %d 天 · %s" % [day_number, day_phase], "收集资源，建造营地 · 藏宝图 %d/3 · 木材 %d/5" % [maps, wood])

func _end_game(win: bool) -> void:
	if state == State.WON or state == State.DEAD:
		return
	state = State.WON if win else State.DEAD
	get_tree().paused = false
	hud.show_end(win, {"time": play_time, "kills": kills, "coins": coins, "maps": maps})
	if win:
		play_sfx("victory")
	audio.set_music_muffled(true)
	touch_off()

func touch_off() -> void:
	if hud:
		hud.touch.show_controls(false)

func show_toast(text: String, duration := 2.6) -> void:
	if hud:
		hud.show_toast(text, duration)

func play_sfx(key: String, variation := 0.08) -> void:
	if audio:
		audio.play_sfx(key, variation)

func shake_camera(strength: float, duration: float) -> void:
	if camera_rig:
		camera_rig.shake(strength, duration)

func damage_flash() -> void:
	if hud:
		hud.damage_flash()

func hitstop(duration := 0.04) -> void:
	if _hitstop_active:
		return
	_hitstop_active = true
	Engine.time_scale = 0.16
	await get_tree().create_timer(duration, true, false, true).timeout
	Engine.time_scale = 1.0
	_hitstop_active = false

func spawn_dust(pos: Vector3) -> void:
	_spawn_burst(pos + Vector3(0, 0.05, 0), Color("#d9c295"), 4, 0.3, 1.2, 0.04, 0.12, -1.5)

func spawn_hit_sparks(pos: Vector3, dir: Vector3) -> void:
	_spawn_burst(pos, Color("#ffd36b"), 10, 2.5, 5.0, 0.04, 0.09, -8.0)

func spawn_death_puff(pos: Vector3) -> void:
	_spawn_burst(pos, Color("#dbcfb4"), 14, 1.2, 3.4, 0.08, 0.18, -2.0)
	_spawn_burst(pos, Color("#355d50"), 8, 0.8, 2.2, 0.1, 0.2, 0.4)

func spawn_dash_trail(a: Vector3, b: Vector3) -> void:
	_spawn_burst(a, Color("#9eeae4"), 6, 0.5, 1.5, 0.06, 0.12, 0.0)

func spawn_shockwave(pos: Vector3) -> void:
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.7
	torus.outer_radius = 1.0
	torus.rings = 32
	torus.ring_segments = 8
	ring.mesh = torus
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(1.0, 0.55, 0.25, 0.7)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	ring.material_override = m
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ring)
	ring.global_position = pos + Vector3(0, 0.25, 0)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(ring, "scale", Vector3(6.5, 0.5, 6.5), 0.55).set_ease(Tween.EASE_OUT)
	tw.tween_property(m, "albedo_color:a", 0.0, 0.6)
	tw.chain().tween_callback(ring.queue_free)

func spawn_damage_number(pos: Vector3, amount: int, color: Color, prefix := "") -> void:
	var label := Label3D.new()
	label.text = "%s%d" % [prefix, amount]
	label.font = load("res://assets/fonts/NotoSansSC-Regular.ttf")
	label.font_size = 64
	label.pixel_size = 0.004
	label.modulate = color
	label.outline_modulate = Color(0.02, 0.05, 0.05, 0.9)
	label.outline_size = 14
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	add_child(label)
	label.global_position = pos
	var tw := create_tween().set_parallel(true)
	tw.tween_property(label, "global_position:y", pos.y + 1.2, 0.8).set_ease(Tween.EASE_OUT)
	tw.tween_property(label, "modulate:a", 0.0, 0.8).set_delay(0.25)
	tw.chain().tween_callback(label.queue_free)

func _spawn_burst(pos: Vector3, color: Color, amount: int, vel_min: float, vel_max: float, size_min: float, size_max: float, gravity_y: float) -> void:
	var p := CPUParticles3D.new()
	p.amount = amount
	p.lifetime = 0.9
	p.one_shot = true
	p.explosiveness = 0.9
	p.direction = Vector3(0, 1, 0)
	p.spread = 60.0
	p.initial_velocity_min = vel_min
	p.initial_velocity_max = vel_max
	p.gravity = Vector3(0, gravity_y, 0)
	p.scale_amount_min = size_min
	p.scale_amount_max = size_max
	p.color = color
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	p.mesh = quad
	var m := GameUtil.raw_mat(color, 0.4, 0.0, 1.0, true)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_texture = GameUtil.particle_texture()
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	p.material_override = m
	add_child(p)
	p.global_position = pos
	p.emitting = true
	var timer := get_tree().create_timer(1.2)
	timer.timeout.connect(p.queue_free)

# ---------------- capture / debug ----------------

func _capture_if_requested() -> void:
	var args := OS.get_cmdline_user_args()
	if "--capture-title" in args:
		_run_capture_title()
	elif "--capture" in args:
		_run_capture_game()
	elif "--capture-touch" in args:
		_run_capture_touch()
	elif "--capture-sandbox" in args:
		_run_capture_sandbox()
	elif "--autotest" in args:
		_run_autotest()

func _wait_frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw

func _save_shot(name: String) -> void:
	var dir := ProjectSettings.globalize_path("res://preview")
	DirAccess.make_dir_recursive_absolute(dir)
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(dir.path_join(name))
	print("CAPTURED ", dir.path_join(name), " ", img.get_width(), "x", img.get_height())

func _run_capture_title() -> void:
	await _wait_frames(20)
	await _save_shot("title_screen.png")
	get_tree().quit()

func _run_capture_game() -> void:
	start_game()
	await _wait_frames(30)
	await _save_shot("gameplay_camp.png")
	# Show off the shipwreck
	player.global_position = Vector3(4.0, world.height_at(4.0, 14.0) + 0.5, 14.0)
	camera_rig.follow_pos = player.global_position
	await _wait_frames(30)
	await _save_shot("gameplay_shipwreck.png")
	# Ruins and chest
	player.global_position = Vector3(-18.0, world.height_at(-18.0, -2.0) + 0.5, -2.0)
	camera_rig.follow_pos = player.global_position
	await _wait_frames(30)
	await _save_shot("gameplay_ruins.png")
	get_tree().quit()

func _run_capture_touch() -> void:
	hud.set_touch_mode(true)
	start_game()
	await _wait_frames(30)
	await _save_shot("gameplay_touch.png")
	get_tree().quit()

func _run_capture_sandbox() -> void:
	start_game()
	await _wait_frames(30)
	await _save_shot("sandbox_day.png")
	wood = 14
	stone = 10
	fiber = 9
	_update_hud()
	hud.open_craft()
	await _wait_frames(6)
	await _save_shot("sandbox_craft.png")
	hud.close_craft()
	player.facing_dir = Vector3(0, 0, 1)
	try_craft("campfire")
	try_craft("barricade")
	player.rotation.y = PI * 0.35
	player.facing_dir = Vector3(0.3, 0, 0.95).normalized()
	try_craft("shelter")
	await _wait_frames(20)
	await _save_shot("sandbox_base.png")
	day_time = NIGHT_START + 0.01
	_advance_day(0.0)
	await _wait_frames(30)
	await _save_shot("sandbox_night.png")
	get_tree().quit()

func _run_autotest() -> void:
	print("AUTOTEST: starting")
	var watchdog := get_tree().create_timer(14.0)
	watchdog.timeout.connect(func():
		print("AUTOTEST TIMEOUT")
		get_tree().quit(2)
	)
	start_game()
	print("AUTOTEST: game started")
	await _wait_frames(5)
	print("AUTOTEST: frames waited, state=", state)
	var failures: Array[String] = []
	if state != State.PLAYING:
		failures.append("start_game did not enter PLAYING")
	if player == null or player.health <= 0:
		failures.append("player missing or dead after start")
	if chests.size() != 3:
		failures.append("expected 3 chests, got %d" % chests.size())
	if maps != 0:
		failures.append("maps should start at 0")
	# Crafting and respawn smoke tests
	wood = 10
	stone = 10
	fiber = 10
	_update_hud()
	var built_campfire := try_craft("campfire")
	await get_tree().process_frame
	if not built_campfire or built_structures.is_empty():
		failures.append("campfire craft failed")
	if not can_afford("whetstone"):
		failures.append("whetstone should be affordable")
	var bonus_before := cutlass_bonus
	try_craft("whetstone")
	if cutlass_bonus <= bonus_before:
		failures.append("whetstone did not add attack bonus")
	print("AUTOTEST: crafting checked, structures=", built_structures.size())
	player.invulnerable = 0.0
	player.take_damage(999.0, Vector3.FORWARD)
	await get_tree().create_timer(2.8).timeout
	if state != State.PLAYING or player.dead or player.health <= 0.0:
		failures.append("death/respawn loop failed")
	print("AUTOTEST: respawn checked, health=", player.health, " state=", state)
	# Open all chests.
	for chest in chests:
		if is_instance_valid(chest):
			chest.interact(player)
			await get_tree().process_frame
	print("AUTOTEST: chests opened, maps=", maps)
	if maps != 3:
		failures.append("expected maps=3 after chests, got %d" % maps)
	if chests_opened != 3:
		failures.append("expected chests_opened=3, got %d" % chests_opened)
	# Prepare beacon requirements and light it.
	wood = 5
	_update_hud()
	if beacon_node == null or not is_instance_valid(beacon_node):
		failures.append("beacon missing")
	else:
		print("AUTOTEST: lighting beacon")
		beacon_node.interact(player)
		await get_tree().create_timer(2.5).timeout
		print("AUTOTEST: beacon wait done, lit=", beacon_lit, " boss=", boss)
		if not beacon_lit:
			failures.append("beacon did not light")
		if boss == null or not is_instance_valid(boss):
			failures.append("boss did not spawn after beacon")
			print("AUTOTEST FAIL: ", failures)
			get_tree().quit(1)
			return
		boss.take_damage(99999.0, Vector3.FORWARD, player)
		print("AUTOTEST: boss damaged")
		await get_tree().create_timer(2.2).timeout
		print("AUTOTEST: after boss death, state=", state)
		if state != State.WON:
			failures.append("state should be WON, got %d" % state)
		if not boss_defeated:
			failures.append("boss_defeated flag not set")
	# death path test is separate so it doesn't fight the win overlay
	if failures.is_empty():
		print("AUTOTEST PASS: start, chests, maps, beacon, boss, victory")
		get_tree().quit(0)
	else:
		print("AUTOTEST FAIL: ", failures)
		get_tree().quit(1)
