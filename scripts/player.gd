class_name MilkFrog
extends CharacterBody3D

signal stats_changed(health: float, max_health: float, hunger: float)
signal prompt_changed(text: String)
signal died

const MAX_HEALTH := 100.0
const MAX_HUNGER := 100.0

var game: Node
var camera_rig: Node
var world: IslandWorld

var health := MAX_HEALTH
var hunger := MAX_HUNGER
var invulnerable := 0.0
var dead := false

var speed := 6.2
var acceleration := 34.0
var friction := 26.0
var gravity := 24.0
var dash_speed := 17.5
var dash_time := 0.0
var dash_cooldown := 0.0
var dash_dir := Vector3.ZERO
var attack_timer := 0.0
var attack_cooldown := 0.0
var combo := 0
var facing_dir := Vector3(0, 0, -1)
var aim_dir := Vector3(0, 0, -1)
var is_touch := false
var touch_move := Vector2.ZERO
var touch_attack_queued := false
var touch_dash_queued := false
var touch_interact_queued := false
var hurt_timer := 0.0
var walk_phase := 0.0
var knockback := Vector3.ZERO
var current_prompt := ""
var nearest_interactable: Node = null

var visual: Node3D
var model_root: Node3D
var arm_l: Node3D
var arm_r: Node3D
var weapon_pivot: Node3D
var sword: Node3D
var shadow: MeshInstance3D
var slash: MeshInstance3D
var hunger_tick := 0.0
var bubble: Label3D
var audio: Node

func setup(p_game: Node, p_camera_rig: Node, p_world: IslandWorld) -> void:
	game = p_game
	camera_rig = p_camera_rig
	world = p_world

func _ready() -> void:
	add_to_group("player")
	collision_layer = 2
	collision_mask = 1
	floor_snap_length = 0.5
	floor_max_angle = deg_to_rad(50.0)
	_build_collision()
	_build_visual()
	_build_shadow()
	_build_sword()
	_build_slash()
	_build_bubble()
	stats_changed.emit(health, MAX_HEALTH, hunger)

func _build_collision() -> void:
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.42
	capsule.height = 1.15
	shape.shape = capsule
	shape.position.y = 0.62
	add_child(shape)

func _build_visual() -> void:
	visual = Node3D.new()
	visual.name = "Visual"
	add_child(visual)
	var lantern := OmniLight3D.new()
	lantern.name = "FrogLantern"
	lantern.light_color = Color("#ffd9a2")
	lantern.light_energy = 1.1
	lantern.omni_range = 9.5
	lantern.position = Vector3(0, 1.15, 0)
	lantern.shadow_enabled = false
	add_child(lantern)
	var glb := "res://assets/models/milkfrog.glb"
	if ResourceLoader.exists(glb):
		var scene: PackedScene = load(glb)
		model_root = scene.instantiate() as Node3D
		model_root.name = "MilkFrogModel"
		# Blender character faces +Z after glTF conversion; Godot forward is -Z.
		model_root.rotation.y = PI
		model_root.scale = Vector3.ONE * 1.02
		visual.add_child(model_root)
		_apply_toy_material_touches(model_root)
		arm_l = model_root.find_child("ArmPivotL", true, false) as Node3D
		arm_r = model_root.find_child("ArmPivotR", true, false) as Node3D
	else:
		_build_fallback_visual()

func _apply_toy_material_touches(root: Node) -> void:
	var seen: Dictionary = {}
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		if mi.mesh == null:
			continue
		for i in mi.mesh.get_surface_count():
			var mat := mi.mesh.surface_get_material(i)
			if mat is StandardMaterial3D:
				var key := str(mat)
				if not seen.has(key):
					var m := mat as StandardMaterial3D
					m.rim_enabled = true
					m.rim = 0.18
					m.rim_tint = 0.55
					if m.albedo_color.a > 0.5:
						m.roughness = maxf(0.55, m.roughness)
					seen[key] = true

func _build_fallback_visual() -> void:
	var body := GameUtil.sphere(visual, 0.55, GameUtil.mat("yellow", 0.7), Vector3(0, 0.82, 0), Vector3(0.9, 1.3, 0.8), "Body")
	GameUtil.sphere(visual, 0.42, GameUtil.mat("cream", 0.9), Vector3(0, 0.58, -0.35), Vector3(1.0, 1.0, 0.2), "Belly")
	for x in [-0.2, 0.2]:
		GameUtil.sphere(visual, 0.11, GameUtil.mat("green", 0.6), Vector3(x, 1.35, -0.36), Vector3.ONE, "Eye")
		GameUtil.sphere(visual, 0.055, GameUtil.mat("black", 0.6), Vector3(x, 1.35, -0.44), Vector3.ONE, "Pupil")
	arm_l = Node3D.new(); visual.add_child(arm_l)
	arm_r = Node3D.new(); visual.add_child(arm_r)

func _build_shadow() -> void:
	shadow = MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(1.6, 1.15)
	shadow.mesh = quad
	shadow.rotation_degrees.x = -90
	shadow.position.y = 0.035
	var m := StandardMaterial3D.new()
	m.albedo_texture = GameUtil.make_soft_circle_texture()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.no_depth_test = false
	m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	shadow.material_override = m
	shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(shadow)

func _build_sword() -> void:
	weapon_pivot = Node3D.new()
	weapon_pivot.name = "WeaponPivot"
	weapon_pivot.position = Vector3(0.56, 0.52, -0.02)
	visual.add_child(weapon_pivot)
	sword = Node3D.new()
	sword.name = "Cutlass"
	weapon_pivot.add_child(sword)
	var blade := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.10, 0.035, 1.05)
	blade.mesh = bm
	blade.material_override = GameUtil.raw_mat(Color("#e7e1c9"), 0.25, 0.6)
	blade.position = Vector3(0, 0.0, -0.45)
	sword.add_child(blade)
	var tip := MeshInstance3D.new()
	var tm := BoxMesh.new()
	tm.size = Vector3(0.09, 0.03, 0.22)
	tip.mesh = tm
	tip.material_override = blade.material_override
	tip.position = Vector3(0, 0.0, -0.98)
	tip.rotation_degrees.y = 8
	sword.add_child(tip)
	var guard := MeshInstance3D.new()
	var gm := BoxMesh.new()
	gm.size = Vector3(0.36, 0.055, 0.09)
	guard.mesh = gm
	guard.material_override = GameUtil.mat("gold", 0.35, 0.55)
	guard.position = Vector3(0, 0.0, 0.05)
	sword.add_child(guard)
	var grip := MeshInstance3D.new()
	var hg := CylinderMesh.new()
	hg.top_radius = 0.045
	hg.bottom_radius = 0.045
	hg.height = 0.26
	hg.radial_segments = 8
	grip.mesh = hg
	grip.material_override = GameUtil.mat("wood_dark", 0.8)
	grip.rotation_degrees.x = 90
	grip.position = Vector3(0, 0.0, 0.16)
	sword.add_child(grip)
	var pommel := GameUtil.sphere(sword, 0.06, GameUtil.mat("gold", 0.35, 0.55), Vector3(0, 0, 0.30), Vector3.ONE, "Pommel")
	sword.rotation_degrees = Vector3(0, 0, -6)

func _build_slash() -> void:
	slash = MeshInstance3D.new()
	slash.name = "SlashArc"
	slash.mesh = _arc_mesh()
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(1.0, 0.86, 0.42, 0.0)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	slash.material_override = m
	slash.position = Vector3(0, 0.6, 0)
	slash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	slash.visible = false
	visual.add_child(slash)

func _arc_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segments := 16
	for i in segments:
		var a0 := lerpf(-1.15, 1.15, float(i) / float(segments))
		var a1 := lerpf(-1.15, 1.15, float(i + 1) / float(segments))
		var r := 2.5
		var p0 := Vector3(sin(a0) * r, 0, -cos(a0) * r)
		var p1 := Vector3(sin(a1) * r, 0, -cos(a1) * r)
		var q0 := Vector3(sin(a0) * (r * 0.55), 0.15 * cos(a0), -cos(a0) * (r * 0.55))
		var q1 := Vector3(sin(a1) * (r * 0.55), 0.15 * cos(a1), -cos(a1) * (r * 0.55))
		st.set_color(Color(1, 1, 1, 1)); st.add_vertex(q0)
		st.set_color(Color(1, 1, 1, 1)); st.add_vertex(p0)
		st.set_color(Color(1, 1, 1, 1)); st.add_vertex(p1)
		st.set_color(Color(1, 1, 1, 1)); st.add_vertex(q0)
		st.set_color(Color(1, 1, 1, 1)); st.add_vertex(p1)
		st.set_color(Color(1, 1, 1, 1)); st.add_vertex(q1)
	return st.commit()

func _build_bubble() -> void:
	bubble = Label3D.new()
	bubble.name = "Bubble"
	bubble.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	bubble.font_size = 40
	bubble.pixel_size = 0.0038
	bubble.outline_size = 10
	bubble.modulate = Color(1.0, 0.98, 0.88)
	bubble.outline_modulate = Color(0.05, 0.12, 0.1, 0.9)
	bubble.position = Vector3(0, 1.9, 0)
	bubble.no_depth_test = false
	bubble.visible = false
	add_child(bubble)
	var font := load("res://assets/fonts/NotoSansSC-Regular.ttf")
	if font:
		bubble.font = font

func _physics_process(delta: float) -> void:
	if game == null:
		return
	attack_cooldown = maxf(0.0, attack_cooldown - delta)
	dash_cooldown = maxf(0.0, dash_cooldown - delta)
	invulnerable = maxf(0.0, invulnerable - delta)
	hurt_timer = maxf(0.0, hurt_timer - delta)
	attack_timer = maxf(0.0, attack_timer - delta)
	_update_prompt()
	_update_animation(delta)

	if not game.is_playing() or dead:
		_apply_gravity(delta)
		move_and_slide()
		_update_shadow()
		return

	_update_needs(delta)
	_handle_input(delta)

func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = 0.0

func _handle_input(delta: float) -> void:
	var input_vec := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if input_vec.length_squared() < 0.04 and touch_move.length() > 0.12:
		input_vec = touch_move
	var move_dir := Vector3(input_vec.x, 0.0, input_vec.y)
	if move_dir.length_squared() > 0.02:
		move_dir = move_dir.normalized()

	if touch_attack_queued:
		touch_attack_queued = false
		_try_attack()
	if Input.is_action_just_pressed("attack") and not is_touch:
		_try_attack()
	if touch_dash_queued:
		touch_dash_queued = false
		_try_dash(move_dir)
	if Input.is_action_just_pressed("dash") and not is_touch:
		_try_dash(move_dir)
	if touch_interact_queued:
		touch_interact_queued = false
		_interact()
	if Input.is_action_just_pressed("interact") and not is_touch:
		_interact()

	if not is_touch:
		_update_mouse_aim()

	if attack_timer > 0.16 and attack_timer < 0.34:
		# short forward lunge during the swing
		var swing_dir := aim_dir if aim_dir != Vector3.ZERO else facing_dir
		velocity.x = swing_dir.x * 2.0
		velocity.z = swing_dir.z * 2.0
	elif dash_time > 0.0:
		dash_time -= delta
		velocity.x = dash_dir.x * dash_speed
		velocity.z = dash_dir.z * dash_speed
		invulnerable = maxf(invulnerable, 0.07)
	else:
		var target_vel := move_dir * speed * (0.72 if attack_timer > 0.0 else 1.0)
		var accel := acceleration if move_dir.length_squared() > 0.01 else friction
		velocity.x = move_toward(velocity.x + knockback.x, target_vel.x, accel * delta)
		velocity.z = move_toward(velocity.z + knockback.z, target_vel.z, accel * delta)
		knockback = knockback.move_toward(Vector3.ZERO, delta * 18.0)
	_apply_gravity(delta)

	var old_pos := global_position
	move_and_slide()

	# Keep the frog on the beach and out of the deep water.
	if world != null and (not world.is_walkable(global_position) or global_position.y < -1.0):
		global_position = old_pos
		velocity.x = 0.0
		velocity.z = 0.0
	if global_position.x * global_position.x + global_position.z * global_position.z > 37.4 * 37.4:
		var p := Vector3(global_position.x, global_position.y, global_position.z).normalized()
		global_position.x = p.x * 37.4
		global_position.z = p.z * 37.4

	if move_dir.length_squared() > 0.01:
		facing_dir = move_dir
		var target_yaw := GameUtil.yaw_to(move_dir)
		rotation.y = lerp_angle(rotation.y, target_yaw, clampf(delta * 13.0, 0.0, 1.0))
		walk_phase += delta * 11.0
		if is_on_floor() and randf() < delta * 0.15:
			game.spawn_dust(global_position)
	elif aim_dir != Vector3.ZERO and attack_timer > 0.0:
		var target_yaw := GameUtil.yaw_to(aim_dir)
		rotation.y = lerp_angle(rotation.y, target_yaw, clampf(delta * 18.0, 0.0, 1.0))
	_update_shadow()

func _update_mouse_aim() -> void:
	if camera_rig == null or not camera_rig.has_method("mouse_world_point"):
		return
	var mp := get_viewport().get_mouse_position()
	if mp.x < 0 or mp.y < 0:
		return
	var p: Variant = camera_rig.mouse_world_point(mp, global_position.y + 0.4)
	if p is Vector3:
		var d: Vector3 = p - global_position
		d.y = 0
		if d.length_squared() > 0.3:
			aim_dir = d.normalized()

func _try_attack() -> void:
	if attack_cooldown > 0.0 or dash_time > 0.0:
		return
	attack_cooldown = 0.43
	attack_timer = 0.34
	combo = (combo + 1) % 3
	var dir := aim_dir if not is_touch else facing_dir
	if dir.length_squared() < 0.01:
		dir = facing_dir
	facing_dir = dir
	rotation.y = GameUtil.yaw_to(dir)
	# Cutlass arc
	slash.visible = true
	slash.rotation.y = 0
	var mat := slash.material_override as StandardMaterial3D
	mat.albedo_color.a = 0.9
	slash.scale = Vector3(0.65, 0.75, 0.65)
	slash.rotation_degrees.z = -40.0 if combo % 2 == 0 else 40.0
	var tw := create_tween().set_parallel(true)
	tw.tween_property(slash, "scale", Vector3(1.15, 1.0, 1.15), 0.22).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(slash, "rotation_degrees:z", 42.0 if combo % 2 == 0 else -42.0, 0.22)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.24)
	tw.chain().tween_callback(func(): slash.visible = false)
	# Sword swing
	var base_rot := weapon_pivot.rotation_degrees
	var target_z := -76.0 if combo % 2 == 0 else 54.0
	var tw2 := create_tween().set_parallel(true)
	tw2.tween_property(weapon_pivot, "rotation_degrees:z", target_z, 0.13).set_ease(Tween.EASE_OUT)
	tw2.tween_property(weapon_pivot, "rotation_degrees:x", -12.0, 0.13)
	tw2.chain().tween_property(weapon_pivot, "rotation_degrees", base_rot, 0.2).set_ease(Tween.EASE_IN_OUT)
	if game:
		game.play_sfx("swing")
		game.shake_camera(0.12, 0.12)
	# Hit detection as a horizontal cone.
	var hits := 0
	for node in get_tree().get_nodes_in_group("enemy"):
		var e := node as Node3D
		if not e or not e.has_method("take_damage") or e.get("dead") == true:
			continue
		var to := e.global_position - global_position
		to.y = 0.0
		var dist := to.length()
		if dist > 2.85 or dist < 0.05:
			continue
		var angle := dir.angle_to(to.normalized())
		if angle < deg_to_rad(78.0):
			var extra := 0.0
			if game and game.has_method("get_attack_bonus"):
				extra = game.get_attack_bonus()
			var dmg := 34.0 + extra + (8.0 if combo == 2 else 0.0)
			e.call("take_damage", dmg, dir, self)
			hits += 1
	if hits > 0 and game:
		game.hitstop(0.045)
		game.shake_camera(0.22, 0.16)

func _try_dash(move_dir: Vector3) -> void:
	if dash_cooldown > 0.0 or dash_time > 0.0:
		return
	dash_cooldown = 1.1
	dash_time = 0.18
	var dir := move_dir if move_dir.length_squared() > 0.01 else facing_dir
	dash_dir = dir.normalized()
	facing_dir = dash_dir
	rotation.y = GameUtil.yaw_to(dash_dir)
	invulnerable = maxf(invulnerable, 0.28)
	if game:
		game.play_sfx("dash")
		game.spawn_dash_trail(global_position, global_position + Vector3(0, 1, 0))
		game.shake_camera(0.08, 0.08)

func _interact() -> void:
	if nearest_interactable != null and is_instance_valid(nearest_interactable):
		if nearest_interactable.has_method("interact"):
			nearest_interactable.call("interact", self)
	else:
		if game:
			game.show_toast("附近没有可以互动的东西", 1.2)

func take_damage(amount: float, from_dir := Vector3.ZERO) -> void:
	if invulnerable > 0.0 or dead or game == null or not game.is_playing():
		return
	health = maxf(0.0, health - amount)
	invulnerable = 0.75
	hurt_timer = 0.45
	knockback = from_dir.normalized() * 8.0
	if game:
		game.play_sfx("hurt")
		game.damage_flash()
		game.shake_camera(0.38, 0.28)
		game.spawn_damage_number(global_position + Vector3(0, 1.5, 0), int(amount), Color("#ff6b4a"))
	stats_changed.emit(health, MAX_HEALTH, hunger)
	if health <= 0.0:
		_die()

func revive_at(pos: Vector3) -> void:
	dead = false
	health = 55.0
	hunger = maxf(hunger, 55.0)
	invulnerable = 3.0
	knockback = Vector3.ZERO
	global_position = pos
	velocity = Vector3.ZERO
	rotation.y = PI
	visual.rotation_degrees = Vector3.ZERO
	visual.position = Vector3.ZERO
	if bubble:
		bubble.visible = false
	stats_changed.emit(health, MAX_HEALTH, hunger)

func heal(amount: float) -> void:
	if dead:
		return
	health = minf(MAX_HEALTH, health + amount)
	if game:
		game.play_sfx("heal")
		game.spawn_damage_number(global_position + Vector3(0, 1.7, 0), int(amount), Color("#8ff09a"), "+")
	stats_changed.emit(health, MAX_HEALTH, hunger)

func feed(amount: float) -> void:
	hunger = minf(MAX_HUNGER, hunger + amount)
	if game:
		game.play_sfx("eat")
		game.spawn_damage_number(global_position + Vector3(0, 1.7, 0), int(amount), Color("#ffd36b"), "+")
	stats_changed.emit(health, MAX_HEALTH, hunger)

func _die() -> void:
	dead = true
	bubble.visible = false
	if game:
		game.play_sfx("die")
		game.on_player_died()
	died.emit()
	var tw := create_tween()
	tw.tween_property(visual, "rotation_degrees:z", 80.0, 0.5).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(visual, "position:y", -0.35, 0.5)

func _update_needs(delta: float) -> void:
	hunger = maxf(0.0, hunger - delta * 0.26)
	hunger_tick += delta
	if hunger <= 0.0:
		health = maxf(0.0, health - delta * 2.4)
		stats_changed.emit(health, MAX_HEALTH, hunger)
		if health <= 0.0:
			_die()
	elif hunger > 55.0 and health < MAX_HEALTH:
		health = minf(MAX_HEALTH, health + delta * 0.18)
		stats_changed.emit(health, MAX_HEALTH, hunger)
	if hunger_tick >= 1.0:
		hunger_tick = 0.0
		stats_changed.emit(health, MAX_HEALTH, hunger)

func _update_animation(delta: float) -> void:
	if visual == null:
		return
	var moving := velocity.length() > 0.6 and is_on_floor() and not dead
	if moving:
		var bob := absf(sin(walk_phase)) * 0.065
		visual.position.y = lerpf(visual.position.y, bob, delta * 16.0)
		visual.rotation.z = lerpf(visual.rotation.z, sin(walk_phase) * 0.035, delta * 10.0)
		visual.rotation.x = lerpf(visual.rotation.x, -0.05, delta * 8.0)
		if arm_l:
			arm_l.rotation.x = sin(walk_phase) * 0.45
		if arm_r:
			arm_r.rotation.x = -sin(walk_phase) * 0.45
	else:
		var breathe := sin(Time.get_ticks_msec() * 0.0022) * 0.015
		visual.position.y = lerpf(visual.position.y, breathe, delta * 6.0)
		visual.rotation.z = lerpf(visual.rotation.z, sin(Time.get_ticks_msec() * 0.001) * 0.012, delta * 5.0)
		visual.rotation.x = lerpf(visual.rotation.x, 0.0, delta * 6.0)
		if arm_l:
			arm_l.rotation.x = lerpf(arm_l.rotation.x, 0.0, delta * 8.0)
		if arm_r:
			arm_r.rotation.x = lerpf(arm_r.rotation.x, 0.0, delta * 8.0)
	if hurt_timer > 0.0:
		visual.rotation.z += sin(hurt_timer * 40.0) * 0.08
	# gentle weapon idle
	if attack_timer <= 0.0 and sword:
		weapon_pivot.rotation_degrees.z = lerpf(weapon_pivot.rotation_degrees.z, -8.0, delta * 8.0)
		weapon_pivot.rotation_degrees.x = lerpf(weapon_pivot.rotation_degrees.x, 3.0, delta * 8.0)

func _update_shadow() -> void:
	if shadow == null or world == null:
		return
	var ground := world.height_at(global_position.x, global_position.z)
	shadow.global_position = Vector3(global_position.x, ground + 0.04, global_position.z)
	shadow.rotation_degrees = Vector3(-90, rotation_degrees.y, 0)

func _update_prompt() -> void:
	var best: Node = null
	var best_d := 2.85
	for node in get_tree().get_nodes_in_group("interactable"):
		if not is_instance_valid(node) or not node.has_method("can_interact"):
			continue
		if not bool(node.call("can_interact")):
			continue
		var d: float = global_position.distance_to((node as Node3D).global_position)
		if d < best_d:
			best_d = d
			best = node
	nearest_interactable = best
	var prompt := ""
	if best != null and best.has_method("get_prompt"):
		prompt = str(best.call("get_prompt"))
	if prompt != current_prompt:
		current_prompt = prompt
		prompt_changed.emit(prompt)
		bubble.visible = prompt != ""
		if prompt != "":
			bubble.text = "[E] " + prompt if not is_touch else prompt

func set_touch_mode(enabled: bool) -> void:
	is_touch = enabled
	_update_prompt()

