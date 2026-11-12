extends Node3D

enum State { TITLE, PLAYING, PAUSED, DEAD }

const PlayerScript = preload("res://scripts/player/naifrog_player.gd")
const CameraScript = preload("res://scripts/player/camera_rig.gd")
const WorldScript = preload("res://scripts/world/forest_world.gd")
const BuildingSystemScript = preload("res://scripts/building/building_system.gd")
const ResourceNodeScript = preload("res://scripts/world/resource_node.gd")
const PickupScript = preload("res://scripts/world/item_pickup.gd")
const EnemyScript = preload("res://scripts/enemies/forest_enemy.gd")
const HUDScript = preload("res://scripts/ui/game_hud.gd")

static var start_after_reload := false
static var load_after_reload := false

var state: int = State.TITLE
var world: ForestWorld
var player: NaifrogPlayer
var camera_rig: CameraRig
var building_system: BuildingSystem
var hud: ForestHUD
var sun: DirectionalLight3D
var fill: DirectionalLight3D
var env: Environment
var sky_mat: ProceduralSkyMaterial
var rain: CPUParticles3D
var fireflies: CPUParticles3D

var day := 1
var hour := 8.0
var world_minutes := 8.0 * 60.0
var time_scale := 0.5
var weather := "clear"
var weather_timer := 240.0
var quest_step := 0
var respawn_point := Vector3.ZERO
var ui_blocked := false
var enemies: Array[ForestEnemy] = []
var boss: ForestEnemy
var boss_spawned := false
var _night_started := false
var _last_dawn_day := 0
var _night_spawn_timer := 0.0
var _autosave_timer := 0.0
var _hud_time_timer := 0.0
var _prompt_timer := 0.0
var _boss_hud_timer := 0.0
var _last_weather := ""
var _last_night := false

const QUEST_STEPS := [
	{"title": "在森林里醒来", "desc": "收集 5 根树枝，先弄清周围的环境。"},
	{"title": "第一把工具", "desc": "打开制作（C），做一把石斧。"},
	{"title": "准备过夜", "desc": "收集 10 木材和 5 石头。"},
	{"title": "点燃营火", "desc": "按 B 建造一座营火。"},
	{"title": "建立据点", "desc": "造一张木工台，让营地真正运转起来。"},
	{"title": "睡个安稳觉", "desc": "造一张简易床，把它设为重生点。"},
	{"title": "深入蘑菇林", "desc": "向北走到蘑菇林入口，看看林心裂缝的源头。"},
	{"title": "林间新生", "desc": "你已经在森林里活下来了。继续建造、探索，或挑战古树守护者。"},
]

func _ready() -> void:
	_setup_input()
	_setup_environment()
	world = WorldScript.new()
	world.name = "ForestWorld"
	world.setup(self, null)
	add_child(world)
	world.build()
	player = PlayerScript.new()
	player.name = "Naifrog"
	player.setup(self, world, null)
	add_child(player)
	player.set_spawn(Vector3(world.SPAWN_POS.x, world.height_at(world.SPAWN_POS.x, world.SPAWN_POS.z) + 0.1, world.SPAWN_POS.z))
	world.player = player
	camera_rig = CameraScript.new()
	camera_rig.name = "CameraRig"
	add_child(camera_rig)
	camera_rig.setup(player)
	player.camera_rig = camera_rig
	building_system = BuildingSystemScript.new()
	building_system.name = "BuildingSystem"
	add_child(building_system)
	building_system.setup(self, world, player)
	hud = HUDScript.new()
	hud.name = "HUD"
	add_child(hud)
	hud.setup(self, player, world)
	EventBus.toast_requested.connect(_on_toast_requested)
	player.stats_changed.connect(_on_player_stats)
	player.died.connect(_on_player_died)
	_connect_environment()
	_build_weather_particles()
	respawn_point = player.global_position
	_connect_buttons()
	if start_after_reload:
		start_after_reload = false
		var want_load := load_after_reload
		load_after_reload = false
		call_deferred("start_game", want_load)
	else:
		hud.show_title()
	_update_hud()
	_update_quest_ui()
	if "--play" in OS.get_cmdline_user_args():
		call_deferred("start_game")
	if "--autotest" in OS.get_cmdline_user_args():
		call_deferred("_run_autotest")
	if "--capture-title" in OS.get_cmdline_user_args():
		call_deferred("_capture_title")
	if "--capture" in OS.get_cmdline_user_args():
		call_deferred("_capture_game")
	if "--capture-ui" in OS.get_cmdline_user_args():
		call_deferred("_capture_ui")
	if "--loadtest" in OS.get_cmdline_user_args():
		call_deferred("_run_loadtest")
	if "--capture-chest" in OS.get_cmdline_user_args():
		call_deferred("_capture_chest")
	if "--capture-boss" in OS.get_cmdline_user_args():
		call_deferred("_capture_boss")

func _connect_buttons() -> void:
	hud.new_game_requested.connect(new_game)
	hud.continue_requested.connect(continue_game)
	hud.resume_requested.connect(resume_game)
	hud.save_requested.connect(save_game)
	hud.title_requested.connect(return_to_title)
	hud.quit_requested.connect(func(): get_tree().quit())
	hud.death_respawn_requested.connect(respawn_player)
	hud.recipe_craft_requested.connect(craft_recipe)
	hud.building_selected.connect(_on_building_selected)
	hud.inventory_changed.connect(_on_hud_inventory_changed)
	hud.panels_closed.connect(_on_panels_closed)

func _setup_input() -> void:
	_add_action("move_left", [KEY_A, KEY_LEFT])
	_add_action("move_right", [KEY_D, KEY_RIGHT])
	_add_action("move_up", [KEY_W, KEY_UP])
	_add_action("move_down", [KEY_S, KEY_DOWN])
	_add_action("sprint", [KEY_SHIFT])
	_add_action("dodge", [KEY_SPACE])
	_add_action("interact", [KEY_E])
	_add_action("attack", [KEY_J], [MOUSE_BUTTON_LEFT])
	_add_action("inventory", [KEY_TAB, KEY_I])
	_add_action("craft", [KEY_C])
	_add_action("build", [KEY_B])
	_add_action("pause", [KEY_ESCAPE])
	_add_action("build_place", [], [MOUSE_BUTTON_LEFT])
	_add_action("build_cancel", [], [MOUSE_BUTTON_RIGHT])
	_add_action("build_rotate", [KEY_R])
	_add_action("build_remove", [KEY_X])
	for i in 8:
		_add_action("hotbar_%d" % (i + 1), [KEY_1 + i])

func _add_action(name: String, keys: Array = [], mouse_buttons: Array = []) -> void:
	if not InputMap.has_action(name):
		InputMap.add_action(name)
	for k in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = k
		if not InputMap.action_has_event(name, ev):
			InputMap.action_add_event(name, ev)
	for b in mouse_buttons:
		var mb := InputEventMouseButton.new()
		mb.button_index = b
		if not InputMap.action_has_event(name, mb):
			InputMap.action_add_event(name, mb)

func _setup_environment() -> void:
	var we := WorldEnvironment.new()
	we.name = "WorldEnvironment"
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	sky_mat = ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color("#6ba5a0")
	sky_mat.sky_horizon_color = Color("#f1d9a8")
	sky_mat.sky_curve = 0.25
	sky_mat.ground_bottom_color = Color("#3b5a45")
	sky_mat.ground_horizon_color = Color("#a9a06b")
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.16
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 0.68
	env.glow_enabled = true
	env.glow_intensity = 0.12
	env.glow_bloom = 0.02
	env.fog_enabled = true
	env.fog_light_color = Color("#9caf83")
	env.fog_density = 0.0014
	env.fog_sky_affect = 0.15
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.16
	env.adjustment_saturation = 1.18
	we.environment = env
	add_child(we)
	sun = DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-52, -35, 0)
	sun.light_color = Color("#ffe2b5")
	sun.light_energy = 0.58
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 80.0
	sun.shadow_bias = 0.05
	add_child(sun)
	fill = DirectionalLight3D.new()
	fill.name = "Fill"
	fill.rotation_degrees = Vector3(28, 138, 0)
	fill.light_color = Color("#87b6b1")
	fill.light_energy = 0.22
	add_child(fill)
	_build_clouds()

func _build_clouds() -> void:
	var mat := GameUtil.raw_mat(Color(1.0, 0.96, 0.86, 0.25), 0.9, 0.0, 0.1, true)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_DISABLED
	var rng := RandomNumberGenerator.new(); rng.seed = 101
	for i in 6:
		var root := Node3D.new(); root.name = "Cloud"
		var a := rng.randf_range(0, TAU)
		root.position = Vector3(cos(a) * rng.randf_range(40, 85), rng.randf_range(28, 40), sin(a) * rng.randf_range(40, 85))
		add_child(root)
		for p in rng.randi_range(3, 5):
			var mi := MeshInstance3D.new()
			var sm := SphereMesh.new(); sm.radius = rng.randf_range(3, 6); sm.height = sm.radius * 2
			mi.mesh = sm; mi.material_override = mat
			mi.position = Vector3(rng.randf_range(-5, 5), rng.randf_range(-0.5, 0.5), rng.randf_range(-2, 2))
			mi.scale = Vector3(1, 0.25, 0.6)
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			root.add_child(mi)

func _connect_environment() -> void:
	_update_environment()
	_update_weather_label()

func _build_weather_particles() -> void:
	rain = CPUParticles3D.new()
	rain.name = "Rain"
	rain.amount = 140
	rain.lifetime = 1.2
	rain.preprocess = 1.0
	rain.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	rain.emission_box_extents = Vector3(18, 0.5, 18)
	rain.direction = Vector3(0.1, -1, 0)
	rain.spread = 4.0
	rain.initial_velocity_min = 10.0
	rain.initial_velocity_max = 16.0
	rain.gravity = Vector3(0, -8, 0)
	rain.scale_amount_min = 0.06
	rain.scale_amount_max = 0.12
	rain.visible = false
	var q := QuadMesh.new(); q.size = Vector2(0.06, 0.7)
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.7, 0.85, 0.95, 0.55)
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	q.material = m
	rain.mesh = q
	add_child(rain)
	fireflies = CPUParticles3D.new()
	fireflies.name = "Fireflies"
	fireflies.amount = 40
	fireflies.lifetime = 4.0
	fireflies.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	fireflies.emission_sphere_radius = 18.0
	fireflies.direction = Vector3.UP
	fireflies.spread = 180.0
	fireflies.initial_velocity_min = 0.1
	fireflies.initial_velocity_max = 0.5
	fireflies.gravity = Vector3.ZERO
	fireflies.scale_amount_min = 0.05
	fireflies.scale_amount_max = 0.12
	fireflies.visible = false
	var fq := QuadMesh.new(); fq.size = Vector2(0.12, 0.12)
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(1.0, 0.9, 0.35, 0.9)
	fm.emission_enabled = true
	fm.emission = Color(1.0, 0.85, 0.25)
	fm.emission_energy_multiplier = 2.0
	fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	fm.albedo_texture = GameUtil.particle_texture()
	fq.material = fm
	fireflies.mesh = fq
	add_child(fireflies)

func _process(delta: float) -> void:
	if state == State.PLAYING:
		_advance_time(delta)
		_autosave_timer += delta
		if _autosave_timer > 35.0:
			_autosave_timer = 0.0
			save_game(true)
		_hud_time_timer += delta
		if _hud_time_timer > 0.25:
			_hud_time_timer = 0.0
			EventBus.time_changed.emit(hour, day)
		_check_explore()
		_update_enemy_spawning(delta)
		_prompt_timer += delta
		if _prompt_timer > 0.12:
			_prompt_timer = 0.0
			_update_interaction_prompt()
		_boss_hud_timer += delta
		if _boss_hud_timer > 0.1:
			_boss_hud_timer = 0.0
			_update_boss_hud()
	if rain and player:
		rain.global_position = player.global_position + Vector3(0, 12, 0)
		fireflies.global_position = player.global_position + Vector3(0, 1.5, 0)
	for i in get_child_count():
		var c := get_child(i)
		if c is Node3D and c.name.begins_with("Cloud"):
			c.position.x += delta * 0.35
			if c.position.x > 85: c.position.x = -85
	if state == State.TITLE:
		camera_rig.global_position = camera_rig.global_position.lerp(player.global_position, 1.0 - exp(-2.0 * delta))

func _advance_time(delta: float) -> void:
	var minutes := delta / time_scale
	world_minutes += minutes
	var prev_hour := hour
	hour += minutes / 60.0
	while hour >= 24.0:
		hour -= 24.0
		day += 1
		_on_new_day()
	player.survival.advance_time(minutes)
	_update_environment()
	_update_weather(delta)
	var was_night := _is_night(prev_hour)
	var night := _is_night(hour)
	if night != was_night:
		_on_night_changed(night)
	EventBus.time_changed.emit(hour, day)
	_update_hud()
	if int(hour) != int(prev_hour):
		quest_event("time", "")

func _is_night(h := hour) -> bool:
	return h >= 20.0 or h < 6.0

func _on_new_day() -> void:
	toast("第 %d 天。森林又醒来了。" % day, 2.5)
	save_game(true)
	_last_dawn_day = day

func _on_night_changed(night: bool) -> void:
	if rain:
		rain.visible = weather == "rain"
	if fireflies:
		fireflies.visible = night and weather != "rain"
	_update_environment()
	if night:
		toast("夜幕降临。点亮火把，别在森林里迷路。", 3.2)
		_night_started = true
		_night_spawn_timer = 3.0
	else:
		toast("天亮了。夜里的东西退回了树影里。", 2.6)
		_night_started = false

func _update_environment() -> void:
	if env == null or sky_mat == null:
		return
	var n := 0.0
	if hour >= 20.0 or hour < 5.0:
		n = 1.0
	elif hour >= 18.0:
		n = smoothstep(18.0, 20.0, hour)
	elif hour < 7.0:
		n = 1.0 - smoothstep(5.0, 7.0, hour)
	else:
		n = 0.0
	var dusk := 0.0
	if hour >= 17.0 and hour < 20.0:
		dusk = sin(clampf((hour - 17.0) / 3.0, 0.0, 1.0) * PI)
	sun.light_energy = lerpf(0.58, 0.03, n)
	sun.light_color = Color("#ffe2b5").lerp(Color("#ff9b5e"), dusk * 0.55).lerp(Color("#8495c8"), n * 0.65)
	sun.rotation_degrees = Vector3(lerpf(-52.0, -10.0, n), lerpf(-35.0, 120.0, n), 0.0)
	fill.light_energy = lerpf(0.14, 0.5, n)
	fill.light_color = Color("#87b6b1").lerp(Color("#7e9ecb"), n)
	env.ambient_light_energy = lerpf(0.16, 0.11, n)
	env.tonemap_exposure = lerpf(0.68, 0.62, n)
	env.fog_light_color = Color("#b7c39a").lerp(Color("#1a2b2d"), n)
	env.fog_density = lerpf(0.0018, 0.0030, n)
	sky_mat.sky_top_color = Color("#6ba5a0").lerp(Color("#08171d"), n)
	sky_mat.sky_horizon_color = Color("#f1d9a8").lerp(Color("#ff9b5e"), dusk * 0.55).lerp(Color("#26373a"), n)
	sky_mat.ground_horizon_color = Color("#a9a06b").lerp(Color("#1d2b25"), n)
	sky_mat.ground_bottom_color = Color("#3b5a45").lerp(Color("#08120f"), n)
	if weather == "fog":
		env.fog_density = maxf(env.fog_density, 0.008)
		env.fog_light_color = Color("#c7c9b1").lerp(Color("#2f3c3b"), n)
	if weather == "rain":
		env.fog_density = maxf(env.fog_density, 0.0045)
		env.tonemap_exposure = minf(env.tonemap_exposure, 0.84)

func _update_weather(delta: float) -> void:
	weather_timer -= delta
	if weather_timer > 0.0:
		return
	weather_timer = randf_range(180.0, 420.0)
	var roll := randf()
	if roll < 0.55:
		weather = "clear"
	elif roll < 0.8:
		weather = "rain"
	else:
		weather = "fog"
	_update_weather_label()
	_update_environment()
	if weather != _last_weather:
		_last_weather = weather
		var label: String = str({"clear": "晴朗", "rain": "降雨", "fog": "浓雾"}.get(weather, weather))
		toast("天气转为：%s" % label, 2.5)
		if rain:
			rain.visible = weather == "rain"
		if fireflies:
			fireflies.visible = _is_night() and weather != "rain"

func _update_weather_label() -> void:
	EventBus.weather_changed.emit(weather)

func _update_enemy_spawning(delta: float) -> void:
	if not _night_started:
		return
	_night_spawn_timer -= delta
	if _night_spawn_timer > 0.0:
		return
	_night_spawn_timer = randf_range(18.0, 32.0)
	var alive := 0
	for e in enemies:
		if is_instance_valid(e) and e.state != ForestEnemy.State.DEAD:
			alive += 1
	if alive >= 7:
		return
	var ids := ["slime", "mushroom_bug", "spiky_beast"]
	var id: String = ids[randi() % ids.size()]
	var pos := world.random_enemy_spawn()
	if player and player.global_position.distance_to(pos) < 14.0:
		return
	spawn_enemy(id, pos)

func spawn_enemy(id: String, pos: Vector3) -> ForestEnemy:
	var e := EnemyScript.new()
	e.setup(self, world, id, pos)
	add_child(e)
	enemies.append(e)
	return e

func _check_explore() -> void:
	if quest_step == 6 and player.global_position.distance_to(world.GROVE_CENTER) < 20.0:
		if not boss_spawned:
			boss_spawned = true
			boss = spawn_enemy("ancient_guardian", world.BOSS_POS + Vector3(0, 0, 5))
			if hud:
				hud.show_boss("古树守护者")
			toast("林心深处传来低沉的震动。古树守护者醒了。", 4.0)
		_advance_quest()

func _update_boss_hud() -> void:
	if hud == null:
		return
	if boss != null and is_instance_valid(boss) and boss.state != ForestEnemy.State.DEAD:
		if not hud.boss_panel.visible:
			hud.show_boss("古树守护者")
		hud.update_boss(boss.health, boss.data.max_health)
	else:
		hud.hide_boss()

func quest_event(kind: String, id: String) -> void:
	match kind:
		"craft":
			if id == "stone_axe": _check_quest()
		"build":
			_check_quest()
		"kill":
			if id == "ancient_guardian":
				toast("古树守护者安静了下来。林心的裂痕似乎缓了一点。", 3.5)
		_:
			_check_quest()

func _check_quest() -> void:
	if quest_step >= 7:
		return
	while quest_step < 7 and _quest_condition(quest_step):
		_advance_quest()

func _quest_condition(step: int) -> bool:
	match step:
		0:
			return player.inventory.count_item("branch") >= 5
		1:
			return player.inventory.count_item("stone_axe") >= 1
		2:
			return player.inventory.count_item("wood") >= 10 and player.inventory.count_item("stone") >= 5
		3:
			return _has_building("campfire")
		4:
			return _has_building("workbench")
		5:
			return _has_building("bed")
	return false

func _advance_quest() -> void:
	if quest_step >= 7:
		return
	quest_step += 1
	_update_quest_ui()
	save_game(true)
	if quest_step >= 7:
		toast("你已经在林间站稳了脚跟。", 3.0)
	else:
		toast("目标更新：%s" % QUEST_STEPS[quest_step]["title"], 2.8)

func _has_building(id: String) -> bool:
	for b in building_system.placed:
		if is_instance_valid(b) and b.data.id == id:
			return true
	return false

func _update_quest_ui() -> void:
	if hud:
		var step := clampi(quest_step, 0, QUEST_STEPS.size() - 1)
		hud.set_quest(step, QUEST_STEPS[step]["title"], QUEST_STEPS[step]["desc"], quest_step)

func _on_building_selected(id: String) -> void:
	if building_system:
		building_system.enter_mode(id)
		hud.close_all_panels()
		ui_blocked = false
		get_tree().paused = false
		hud.set_build_hint(true)

func _update_interaction_prompt() -> void:
	if hud == null or player == null:
		return
	if ui_blocked or building_system.active or state != State.PLAYING:
		hud.set_prompt("")
		return
	var best: Node = null
	var best_dist := 3.2
	for n in get_tree().get_nodes_in_group("interactable"):
		if not is_instance_valid(n):
			continue
		if n is Node3D and not (n as Node3D).visible:
			continue
		var d: float = player.global_position.distance_to((n as Node3D).global_position)
		if d < best_dist:
			best_dist = d
			best = n
	if best and best.has_method("get_prompt"):
		hud.set_prompt(str(best.call("get_prompt")))
	else:
		hud.set_prompt("")

func _on_hud_inventory_changed(index: int) -> void:
	if player:
		player.inventory.select(index)

func _on_panels_closed() -> void:
	ui_blocked = false
	if state == State.PLAYING and not (building_system and building_system.active):
		get_tree().paused = false

func close_build_mode() -> void:
	if building_system:
		building_system.exit_mode()
	if hud:
		hud.set_build_hint(false)
		hud.close_all_panels()
	ui_blocked = false
	if state == State.PLAYING:
		get_tree().paused = false

func _on_player_stats() -> void:
	if hud:
		hud.update_stats()

func _on_player_died() -> void:
	if state != State.PLAYING:
		return
	state = State.DEAD
	ui_blocked = true
	var dropped := player.inventory.drop_percent(0.3)
	for d in dropped:
		spawn_item_pickup(d["id"], int(d["amount"]), player.global_position + Vector3(randf_range(-1.5, 1.5), 0.6, randf_range(-1.5, 1.5)))
	if hud:
		hud.show_death("饥饿、战斗或森林本身都会击倒奶蛙。")
	AudioManager.set_music_muffled(true)
	if building_system:
		building_system.exit_mode()

func respawn_player() -> void:
	if player == null:
		return
	var pos := respawn_point
	player.revive(pos)
	state = State.PLAYING
	ui_blocked = false
	AudioManager.set_music_muffled(false)
	if hud:
		hud.hide_death()
		hud.begin_game()
		hud.hide_boss()
		hud.update_stats()
	_update_hud()
	_update_quest_ui()
	toast("奶蛙在营地醒来。丢在森林里的东西还能捡回来。", 3.0)

func sleep_in_bed(_bed: Node) -> void:
	if state != State.PLAYING:
		return
	respawn_point = (_bed as Node3D).global_position + Vector3(0, 0.2, 0)
	var was_night := _is_night()
	hour = 7.0
	if was_night:
		day += 1
	player.survival.health = SurvivalComponent.MAX_HEALTH
	player.survival.hunger = maxf(player.survival.hunger, 70.0)
	player.survival.health_changed.emit(player.survival.health, SurvivalComponent.MAX_HEALTH)
	player.survival.hunger_changed.emit(player.survival.hunger, SurvivalComponent.MAX_HUNGER)
	_update_environment()
	_update_hud()
	_update_weather_label()
	save_game(true)
	toast("你在简易床上睡到天亮。重生点已更新。", 3.0)

func open_crafting(station := "hand") -> void:
	if hud:
		hud.open_craft(station)
		ui_blocked = true
		get_tree().paused = true

func open_chest(chest: PlacedBuilding) -> void:
	if hud:
		hud.open_chest(chest)
		ui_blocked = true
		get_tree().paused = true

func craft_recipe(id: String) -> void:
	var r: RecipeData = GameDB.recipe(id)
	if r == null:
		return
	if not _can_use_station(r.station):
		toast("需要靠近%s才能制作。" % _station_name(r.station), 2.0)
		return
	if not player.inventory.has_costs(r.costs):
		toast("材料不足。", 1.6)
		AudioManager.play_ui("deny")
		return
	if not player.inventory.consume_costs(r.costs):
		return
	player.inventory.add_item(r.output_item, r.output_count)
	AudioManager.play_ui("ui_click")
	EventBus.item_crafted.emit(r.output_item, r.output_count)
	toast("制作了%s ×%d" % [r.display_name, r.output_count], 1.8)
	quest_event("craft", id)
	if hud:
		hud.refresh_craft()
	save_game(true)

func _can_use_station(station: String) -> bool:
	if station == "hand":
		return true
	for b in building_system.placed:
		if not is_instance_valid(b):
			continue
		if b.data.id == station and player.global_position.distance_to(b.global_position) < 6.0:
			return true
	return false

func _station_name(station: String) -> String:
	return {"campfire": "营火", "workbench": "木工台"}.get(station, station)

func _on_building_placed(b: PlacedBuilding) -> void:
	quest_event("build", b.data.id)
	if b.data.id == "bed":
		respawn_point = b.global_position + Vector3(0, 0.2, 0)
	if hud:
		hud.update_build_station_hint()
	save_game(true)

func _on_toast_requested(text: String, duration: float) -> void:
	if hud:
		hud.show_toast(text, duration)

func toast(text: String, duration := 2.4) -> void:
	if hud:
		hud.show_toast(text, duration)

func show_toast(text: String, duration := 2.4) -> void:
	toast(text, duration)

func _update_hud() -> void:
	if hud and player:
		hud.update_stats()
		hud.update_world_info(day, hour, weather)

func play_sfx(key: String, variation := 0.08) -> void:
	AudioManager.play_sfx(key, variation)

func shake_camera(power: float, duration: float) -> void:
	if camera_rig:
		camera_rig.shake(power, duration)

func hitstop(duration := 0.04) -> void:
	Engine.time_scale = 0.18
	await get_tree().create_timer(duration, true, false, true).timeout
	Engine.time_scale = 1.0

func spawn_item_pickup(item_id: String, amount: int, pos: Vector3) -> void:
	var p := PickupScript.new()
	p.setup(self, item_id, amount, pos)
	add_child(p)
	p.global_position = pos

func spawn_attack_arc(pos: Vector3, dir: Vector3) -> void:
	var mi := MeshInstance3D.new()
	var mesh := TorusMesh.new()
	mesh.inner_radius = 0.45
	mesh.outer_radius = 0.75
	mesh.rings = 16
	mi.mesh = mesh
	mi.rotation_degrees.x = 90
	add_child(mi)
	mi.global_position = pos + dir * 0.8
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(1.0, 0.9, 0.55, 0.6)
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mi.material_override = m
	var tw := create_tween()
	tw.tween_property(mi, "scale", Vector3(1.6, 1.6, 1.6), 0.18)
	tw.parallel().tween_property(m, "albedo_color:a", 0.0, 0.18)
	tw.tween_callback(mi.queue_free)

func spawn_hit_sparks(pos: Vector3, _dir: Vector3) -> void:
	_burst(pos, Color("#ffe18a"), 8, 0.08, 0.18, 2.0, 5.0)

func spawn_death_puff(pos: Vector3) -> void:
	_burst(pos, Color("#d8c9a6"), 12, 0.12, 0.28, 1.0, 3.0)

func spawn_build_puff(pos: Vector3) -> void:
	_burst(pos, Color("#d8c49c"), 14, 0.1, 0.24, 1.0, 2.5)

func _burst(pos: Vector3, color: Color, count: int, size_min: float, size_max: float, speed_min: float, speed_max: float) -> void:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.amount = count
	p.lifetime = 0.7
	p.explosiveness = 0.85
	p.direction = Vector3.UP
	p.spread = 180.0
	p.initial_velocity_min = speed_min
	p.initial_velocity_max = speed_max
	p.gravity = Vector3(0, -4, 0)
	p.scale_amount_min = size_min
	p.scale_amount_max = size_max
	var q := QuadMesh.new(); q.size = Vector2(0.16, 0.16)
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.albedo_texture = GameUtil.particle_texture()
	q.material = m
	p.mesh = q
	add_child(p)
	p.global_position = pos
	p.emitting = true
	get_tree().create_timer(1.3).timeout.connect(p.queue_free)

func _unhandled_input(event: InputEvent) -> void:
	if state == State.TITLE:
		return
	if state == State.DEAD:
		return
	if event.is_action_pressed("pause"):
		if hud and hud.any_panel_open():
			hud.close_all_panels()
			ui_blocked = false
			get_tree().paused = false
		elif building_system and building_system.active:
			building_system.exit_mode()
			hud.close_all_panels()
			ui_blocked = false
			get_tree().paused = false
		elif state == State.PLAYING:
			pause_game()
		elif state == State.PAUSED:
			resume_game()
		get_viewport().set_input_as_handled()
		return
	if state != State.PLAYING:
		return
	if building_system and building_system.active:
		if event.is_action_pressed("build"):
			building_system.exit_mode()
			hud.close_all_panels()
			ui_blocked = false
			get_tree().paused = false
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("inventory"):
		hud.toggle_inventory()
		ui_blocked = hud.inventory_open
		get_tree().paused = ui_blocked
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("craft"):
		if hud.craft_open:
			hud.close_all_panels(); ui_blocked = false; get_tree().paused = false
		else:
			open_crafting("hand")
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("build"):
		hud.open_build()
		ui_blocked = true
		get_tree().paused = true
		get_viewport().set_input_as_handled()
	else:
		for i in 8:
			if event.is_action_pressed("hotbar_%d" % (i + 1)):
				player.inventory.select(i)
				get_viewport().set_input_as_handled()
				break

func pause_game() -> void:
	if state != State.PLAYING:
		return
	state = State.PAUSED
	get_tree().paused = true
	ui_blocked = true
	hud.show_pause()

func resume_game() -> void:
	if state != State.PAUSED:
		return
	state = State.PLAYING
	get_tree().paused = false
	ui_blocked = false
	hud.hide_pause()

func new_game() -> void:
	SaveManager.delete_save()
	start_after_reload = true
	load_after_reload = false
	get_tree().paused = false
	get_tree().reload_current_scene()

func continue_game() -> void:
	if not SaveManager.has_save():
		new_game()
		return
	start_after_reload = true
	load_after_reload = true
	get_tree().paused = false
	get_tree().reload_current_scene()

func return_to_title() -> void:
	get_tree().paused = false
	start_after_reload = false
	get_tree().reload_current_scene()

func start_game(want_load := false) -> void:
	state = State.PLAYING
	ui_blocked = false
	get_tree().paused = false
	if want_load:
		var data := SaveManager.load_game()
		if not data.is_empty():
			_apply_save(data)
	else:
		player.set_spawn(Vector3(world.SPAWN_POS.x, world.height_at(world.SPAWN_POS.x, world.SPAWN_POS.z) + 0.1, world.SPAWN_POS.z))
		respawn_point = player.global_position
		quest_step = 0
		day = 1
		hour = 8.0
		world_minutes = 8.0 * 60.0
		weather = "clear"
		weather_timer = 240.0
		player.inventory.from_save([])
		player.survival.restore_full()
		player.dead = false
		player.inventory.changed.connect(_on_inventory_changed)
		player.inventory.selection_changed.connect(func(_i): _on_inventory_changed())
		player.survival.health_changed.connect(func(_c, _m): _update_hud())
		player.survival.hunger_changed.connect(func(_c, _m): _update_hud())
		player.survival.stamina_changed.connect(func(_c, _m): _update_hud())
		_spawn_initial_enemies()
	hud.begin_game()
	hud.hide_boss()
	hud.update_stats()
	hud.update_world_info(day, hour, weather)
	_update_quest_ui()
	_update_hud()
	_update_environment()
	_update_weather_label()
	AudioManager.play_music("forest_theme")
	AudioManager.play_ambience("forest_crickets")
	camera_rig.global_position = player.global_position
	toast("奶蛙在一片陌生的森林里醒来。先收集树枝，做一把石斧吧。", 4.0)

func _spawn_initial_enemies() -> void:
	for e in enemies:
		if is_instance_valid(e): e.queue_free()
	enemies.clear()
	spawn_enemy("slime", world.GROVE_CENTER + Vector3(4, 0, 2))
	spawn_enemy("mushroom_bug", world.GROVE_CENTER + Vector3(-6, 0, -2))
	spawn_enemy("spiky_beast", world.GROVE_CENTER + Vector3(1, 0, -5))

func _apply_save(data: Dictionary) -> void:
	day = int(data.get("day", 1))
	hour = float(data.get("hour", 8.0))
	world_minutes = float(data.get("world_minutes", hour * 60.0))
	weather = str(data.get("weather", "clear"))
	quest_step = int(data.get("quest_step", 0))
	respawn_point = _vec3(data.get("respawn", [0, 0, 0]), Vector3(world.SPAWN_POS.x, 0, world.SPAWN_POS.z))
	player.from_save(data.get("player", {}))
	world.from_save(data.get("world", {}))
	building_system.from_save(data.get("buildings", []))
	player.inventory.changed.connect(_on_inventory_changed)
	player.inventory.selection_changed.connect(func(_i): _on_inventory_changed())
	for e in data.get("enemies", []):
		if typeof(e) == TYPE_DICTIONARY:
			var eid := str(e.get("id", "slime"))
			var loaded_enemy := spawn_enemy(eid, _vec3(e.get("pos", [0, 0, 0]), world.GROVE_CENTER))
			if eid == "ancient_guardian":
				boss = loaded_enemy
				boss_spawned = true
	if data.has("hour"):
		_update_environment()
	AudioManager.set_music_muffled(false)

func save_game(silent := false) -> void:
	if player == null or building_system == null:
		return
	var data := {
		"day": day,
		"hour": hour,
		"world_minutes": world_minutes,
		"weather": weather,
		"quest_step": quest_step,
		"respawn": [respawn_point.x, respawn_point.y, respawn_point.z],
		"player": player.to_save(),
		"world": world.to_save(),
		"buildings": building_system.to_save(),
		"enemies": _enemies_to_save(),
	}
	var ok := SaveManager.save_game(data)
	if not silent:
		toast("已保存到营地存档。" if ok else "保存失败。", 2.0)

func _enemies_to_save() -> Array:
	var out: Array = []
	for e in enemies:
		if is_instance_valid(e) and e.state != ForestEnemy.State.DEAD:
			out.append(e.to_save())
	return out

func _vec3(v, fallback: Vector3) -> Vector3:
	if typeof(v) == TYPE_ARRAY and v.size() >= 3:
		return Vector3(float(v[0]), float(v[1]), float(v[2]))
	return fallback

func _on_inventory_changed() -> void:
	if hud:
		hud.refresh_inventory()
	_check_quest()

func is_playing() -> bool:
	return state == State.PLAYING

func is_input_blocked() -> bool:
	return state != State.PLAYING or ui_blocked or (building_system != null and building_system.active)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		if state == State.PLAYING:
			save_game(true)

func _run_autotest() -> void:
	print("AUTOTEST: start")
	var failures := 0
	start_game(false)
	await get_tree().create_timer(0.35).timeout
	# movement through the actual action map
	var move_start: Vector3 = player.global_position
	Input.action_press("move_up")
	await get_tree().create_timer(0.35).timeout
	Input.action_release("move_up")
	await get_tree().process_frame
	var moved: float = player.global_position.distance_to(move_start)
	print("AUTOTEST: movement=", moved)
	if moved < 0.25:
		failures += 1
		print("AUTOTEST FAIL: movement")
	# harvest an actual branch pile through the player interaction path
	player.global_position = Vector3(0, player.global_position.y, 12.0)
	await get_tree().create_timer(0.15).timeout
	var before_branch := player.inventory.count_item("branch")
	player._interact()
	player._interact()
	await get_tree().create_timer(0.9).timeout
	var after_branch := player.inventory.count_item("branch")
	print("AUTOTEST: harvest branch ", before_branch, " -> ", after_branch)
	if after_branch < before_branch + 2:
		failures += 1
		print("AUTOTEST FAIL: harvest")
	# materials for the full loop
	player.inventory.add_item("branch", 10)
	player.inventory.add_item("stone", 24)
	player.inventory.add_item("fiber", 20)
	player.inventory.add_item("wood", 60)
	await get_tree().process_frame
	if player.inventory.count_item("branch") < 5:
		failures += 1
		print("AUTOTEST FAIL: inventory add")
	else:
		print("AUTOTEST: inventory ok")
	craft_recipe("stone_axe")
	await get_tree().process_frame
	if player.inventory.count_item("stone_axe") < 1:
		failures += 1
		print("AUTOTEST FAIL: craft stone axe")
	else:
		print("AUTOTEST: craft stone axe ok")
	_check_quest()
	print("AUTOTEST: quest after craft=", quest_step)
	if quest_step < 2:
		failures += 1
		print("AUTOTEST FAIL: quest did not reach step 2")
	building_system.enter_mode("campfire")
	var placed_ok := building_system.place_at(Vector2i(2, 2))
	await get_tree().process_frame
	building_system.enter_mode("workbench")
	var placed_wb := building_system.place_at(Vector2i(3, 2))
	building_system.enter_mode("bed")
	var placed_bed := building_system.place_at(Vector2i(4, 2))
	building_system.enter_mode("chest")
	var placed_chest := building_system.place_at(Vector2i(5, 2))
	building_system.exit_mode()
	await get_tree().process_frame
	print("AUTOTEST: builds=", building_system.placed.size(), " campfire=", placed_ok, " workbench=", placed_wb, " bed=", placed_bed, " chest=", placed_chest)
	if not (placed_ok and placed_wb and placed_bed and placed_chest):
		failures += 1
		print("AUTOTEST FAIL: building placement")
	var chest: PlacedBuilding = null
	for b in building_system.placed:
		if b.data.id == "chest":
			chest = b
	if chest:
		player.inventory.add_item("branch", 3)
		open_chest(chest)
		await get_tree().process_frame
		var branch_slot := -1
		for i in 24:
			if player.inventory.slots[i] != null and str(player.inventory.slots[i]["id"]) == "branch":
				branch_slot = i
				break
		if branch_slot >= 0:
			hud._on_chest_deposit_pressed(branch_slot)
		await get_tree().process_frame
		var chest_branches := 0
		for s in chest.storage:
			if s != null and str(s["id"]) == "branch":
				chest_branches += int(s["amount"])
		print("AUTOTEST: chest branches=", chest_branches, " chest_open=", hud.chest_open, " paused=", get_tree().paused)
		if chest_branches <= 0 or not hud.chest_open or not get_tree().paused:
			failures += 1
			print("AUTOTEST FAIL: chest deposit")
		hud._on_chest_slot_pressed(0)
		await get_tree().process_frame
		hud.close_all_panels()
		await get_tree().process_frame
		if get_tree().paused:
			failures += 1
			print("AUTOTEST FAIL: chest did not unpause")
	_check_quest()
	print("AUTOTEST: quest after builds=", quest_step)
	if quest_step < 6:
		failures += 1
		print("AUTOTEST FAIL: quest did not reach step 6")
	var bed: PlacedBuilding = null
	for b in building_system.placed:
		if b.data.id == "bed":
			bed = b
	hour = 22.0
	day = 1
	if bed:
		sleep_in_bed(bed)
	print("AUTOTEST: sleep hour=", hour, " day=", day)
	if hour != 7.0 or day != 2:
		failures += 1
		print("AUTOTEST FAIL: sleep")
	player.global_position = Vector3(world.GROVE_CENTER.x, world.height_at(world.GROVE_CENTER.x, world.GROVE_CENTER.z) + 0.2, world.GROVE_CENTER.z)
	_check_explore()
	print("AUTOTEST: quest at grove=", quest_step)
	if quest_step < 7:
		failures += 1
		print("AUTOTEST FAIL: explore quest")
	# enemy can be damaged and dies
	var enemy := spawn_enemy("slime", player.global_position + Vector3(2.2, 0.2, 0))
	await get_tree().create_timer(0.2).timeout
	var enemy_max := enemy.health
	player.facing_dir = (enemy.global_position - player.global_position).normalized()
	player.facing_dir.y = 0.0
	player.attack_cooldown = 0.0
	var saved_camera = player.camera_rig
	player.camera_rig = null
	player._attack()
	player.camera_rig = saved_camera
	await get_tree().create_timer(0.2).timeout
	print("AUTOTEST: enemy health=", enemy.health, "/", enemy_max)
	if enemy.health >= enemy_max:
		failures += 1
		print("AUTOTEST FAIL: player attack")
	enemy.take_damage(999.0, Vector3.UP, player)
	await get_tree().create_timer(0.2).timeout
	print("AUTOTEST: enemy state=", enemy.state)
	if enemy.state != ForestEnemy.State.DEAD:
		failures += 1
		print("AUTOTEST FAIL: enemy death")
	# UI panel pause/resume behavior
	hud.toggle_inventory()
	ui_blocked = true
	get_tree().paused = true
	await get_tree().process_frame
	if not hud.inventory_open:
		failures += 1
		print("AUTOTEST FAIL: inventory panel")
	hud.close_all_panels()
	await get_tree().process_frame
	if get_tree().paused:
		failures += 1
		print("AUTOTEST FAIL: panels did not unpause")
	# death and respawn
	player.invulnerable = 0.0
	player.survival.damage(9999.0)
	await get_tree().create_timer(0.2).timeout
	print("AUTOTEST: after death state=", state, " health=", player.survival.health)
	if state != State.DEAD:
		failures += 1
		print("AUTOTEST FAIL: death state")
	respawn_player()
	await get_tree().process_frame
	print("AUTOTEST: after respawn state=", state, " health=", player.survival.health)
	if state != State.PLAYING or player.survival.health <= 0.0:
		failures += 1
		print("AUTOTEST FAIL: respawn")
	save_game(true)
	var loaded := SaveManager.load_game()
	print("AUTOTEST: save/load keys=", loaded.keys())
	if loaded.is_empty() or not loaded.has("buildings"):
		failures += 1
		print("AUTOTEST FAIL: save/load")
	print("AUTOTEST RESULT: ", "PASS" if failures == 0 else "FAIL %d" % failures)
	get_tree().quit(0 if failures == 0 else 1)

func _capture_title() -> void:
	await get_tree().create_timer(1.0).timeout
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(ProjectSettings.globalize_path("res://preview/forest_title.png"))
	print("CAPTURED title")
	get_tree().quit(0)

func _capture_game() -> void:
	start_game(false)
	await get_tree().create_timer(2.0).timeout
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(ProjectSettings.globalize_path("res://preview/forest_game.png"))
	print("CAPTURED game")
	get_tree().quit(0)

func _run_loadtest() -> void:
	print("LOADTEST: start")
	start_game(true)
	await get_tree().create_timer(0.6).timeout
	print("LOADTEST: state=", state, " quest=", quest_step, " buildings=", building_system.placed.size(), " day=", day, " hour=", hour)
	print("LOADTEST: inventory branch=", player.inventory.count_item("branch"), " axe=", player.inventory.count_item("stone_axe"))
	print("LOADTEST: boss=", boss_spawned)
	print("LOADTEST RESULT: ", "PASS" if state == State.PLAYING and building_system.placed.size() >= 3 else "FAIL")
	get_tree().quit(0)

func _capture_chest() -> void:
	start_game(false)
	await get_tree().create_timer(0.4).timeout
	player.inventory.add_item("wood", 40)
	player.inventory.add_item("stone", 10)
	player.inventory.add_item("fiber", 10)
	player.inventory.add_item("branch", 12)
	player.inventory.add_item("berry", 6)
	building_system.enter_mode("chest")
	building_system.place_at(Vector2i(1, 1))
	building_system.exit_mode()
	await get_tree().process_frame
	for b in building_system.placed:
		if b.data.id == "chest":
			open_chest(b)
			hud._on_chest_deposit_pressed(0)
			hud._refresh_chest()
			break
	await get_tree().create_timer(0.4).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://preview/forest_chest.png"))
	print("CAPTURED chest")
	get_tree().quit(0)

func _capture_boss() -> void:
	start_game(false)
	await get_tree().create_timer(0.4).timeout
	quest_step = 6
	player.global_position = Vector3(world.GROVE_CENTER.x, world.height_at(world.GROVE_CENTER.x, world.GROVE_CENTER.z) + 0.3, world.GROVE_CENTER.z + 9)
	_check_explore()
	await get_tree().create_timer(1.2).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://preview/forest_boss.png"))
	print("CAPTURED boss spawned=", boss_spawned)
	get_tree().quit(0)

func _capture_ui() -> void:
	start_game(false)
	await get_tree().create_timer(0.5).timeout
	player.inventory.add_item("branch", 8)
	player.inventory.add_item("stone", 10)
	player.inventory.add_item("fiber", 8)
	player.inventory.add_item("wood", 20)
	player.inventory.add_item("berry", 4)
	hud.refresh_inventory()
	await get_tree().create_timer(0.3).timeout
	hud.toggle_inventory()
	ui_blocked = true
	get_tree().paused = true
	await get_tree().create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://preview/forest_inventory.png"))
	hud.close_all_panels()
	ui_blocked = false
	get_tree().paused = false
	open_crafting("hand")
	await get_tree().create_timer(0.4).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://preview/forest_craft.png"))
	hud.close_all_panels()
	ui_blocked = false
	get_tree().paused = false
	hud.open_build()
	ui_blocked = true
	get_tree().paused = true
	await get_tree().create_timer(0.4).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://preview/forest_build.png"))
	hud.close_all_panels()
	ui_blocked = false
	get_tree().paused = false
	_on_building_selected("campfire")
	await get_tree().create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://preview/forest_buildmode.png"))
	building_system.place_at(Vector2i(0, 5))
	await get_tree().create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://preview/forest_built.png"))
	print("CAPTURED ui")
	get_tree().quit(0)
