class_name PirateFoe
extends CharacterBody3D

enum Kind { SKELETON, CRAB, BOSS }
enum State { IDLE, CHASE, WINDUP, RECOVER, STAGGER, DEAD }

var game: Node
var player: MilkFrog
var world: IslandWorld
var kind := Kind.SKELETON
var state := State.IDLE
var health := 60.0
var max_health := 60.0
var speed := 3.1
var damage := 13.0
var aggro := 15.0
var attack_range := 2.2
var home := Vector3.ZERO
var wander_target := Vector3.ZERO
var wander_timer := 0.0
var attack_timer := 0.0
var attack_cooldown := 0.0
var stagger_timer := 0.0
var dead := false
var active := true
var visual: Node3D
var health_bar: Node3D
var health_fill: MeshInstance3D
var telegraph: MeshInstance3D
var bar_timer := 0.0
var walk_phase := 0.0
var arm_r: Node3D
var spawn_scale := 1.0
var flash_material: StandardMaterial3D
var attack_flash := 0.0
var is_boss := false
var special_timer := 6.0
var shadow: MeshInstance3D

func setup(p_game: Node, p_player: MilkFrog, p_world: IslandWorld, p_kind: int, pos: Vector3) -> void:
	game = p_game
	player = p_player
	world = p_world
	kind = p_kind
	position = pos

func _ready() -> void:
	add_to_group("enemy")
	collision_layer = 4
	collision_mask = 1
	floor_snap_length = 0.4
	home = global_position
	wander_target = home
	_configure_stats()
	_build_collision()
	_build_visual()
	_build_health_bar()
	_build_shadow()
	_configure_telegraph()
	spawn_scale = 0.0
	visual.scale = Vector3.ONE * 0.05
	var tw := create_tween()
	tw.tween_property(visual, "scale", Vector3.ONE * (1.35 if is_boss else 1.0), 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	bar_timer = 0.0

func _configure_stats() -> void:
	match kind:
		Kind.SKELETON:
			max_health = 68.0
			speed = 3.0
			damage = 12.0
			aggro = 15.0
		Kind.CRAB:
			max_health = 92.0
			speed = 2.2
			damage = 9.0
			aggro = 10.0
			attack_range = 1.9
		Kind.BOSS:
			max_health = 420.0
			speed = 2.7
			damage = 20.0
			aggro = 30.0
			attack_range = 3.0
			is_boss = true
	health = max_health

func _build_collision() -> void:
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	if kind == Kind.CRAB:
		capsule.radius = 0.65
		capsule.height = 0.7
		shape.position.y = 0.4
	else:
		capsule.radius = 0.4
		capsule.height = 1.5
		shape.position.y = 0.8
	shape.shape = capsule
	add_child(shape)

func _build_shadow() -> void:
	shadow = MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(1.5 if kind != Kind.CRAB else 2.0, 1.1 if kind != Kind.CRAB else 1.4)
	shadow.mesh = quad
	shadow.rotation_degrees.x = -90
	var m := StandardMaterial3D.new()
	m.albedo_texture = GameUtil.make_soft_circle_texture(Color(0, 0, 0, 0.35), Color(0, 0, 0, 0))
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	shadow.material_override = m
	shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(shadow)
	shadow.position.y = 0.06

func _build_visual() -> void:
	visual = Node3D.new()
	visual.name = "Visual"
	add_child(visual)
	match kind:
		Kind.SKELETON:
			_build_skeleton(1.0, false)
		Kind.CRAB:
			_build_crab()
		Kind.BOSS:
			_build_skeleton(1.28, true)

func _build_skeleton(s: float, boss: bool) -> void:
	var bone := GameUtil.mat("bone", 0.82)
	var bone_dark := GameUtil.mat("bone_dark", 0.88)
	var coat := GameUtil.raw_mat(Color("#5b2c2d") if not boss else Color("#2d1b21"), 0.9)
	var coat_trim := GameUtil.raw_mat(Color("#b78345") if not boss else Color("#d8a342"), 0.6, 0.25)
	var black := GameUtil.mat("black", 0.7)
	var green := GameUtil.raw_mat(Color("#8df0a4"), 0.4, 0.0, 2.2)
	visual.scale = Vector3.ONE * 0.95
	# legs and boots
	for x in [-0.16, 0.16]:
		GameUtil.capsule(visual, 0.075, 0.55, bone, Vector3(x, 0.38, 0), Vector3.ZERO, "BoneLeg")
		GameUtil.box(visual, Vector3(0.2, 0.12, 0.34), black, Vector3(x, 0.08, -0.06), Vector3.ZERO, "Boot")
	# tattered coat body
	GameUtil.capsule(visual, 0.34, 1.05, coat, Vector3(0, 0.92, 0), Vector3.ZERO, "Coat")
	# ribcage
	for i in 3:
		GameUtil.box(visual, Vector3(0.38 - i * 0.04, 0.045, 0.08), bone, Vector3(0, 0.96 + i * 0.11, -0.33), Vector3(0, 0, 0), "Rib")
	GameUtil.box(visual, Vector3(0.07, 0.4, 0.07), bone_dark, Vector3(0, 1.0, -0.35), Vector3.ZERO, "Sternum")
	# belt
	GameUtil.box(visual, Vector3(0.7, 0.09, 0.45), black, Vector3(0, 0.66, 0), Vector3.ZERO, "Belt")
	GameUtil.box(visual, Vector3(0.15, 0.14, 0.08), GameUtil.mat("gold", 0.3, 0.5), Vector3(0, 0.66, -0.25), Vector3.ZERO, "Buckle")
	# skull
	GameUtil.sphere(visual, 0.23, bone, Vector3(0, 1.56, 0), Vector3(1.0, 1.05, 0.92), "Skull")
	GameUtil.box(visual, Vector3(0.26, 0.12, 0.18), bone_dark, Vector3(0, 1.44, -0.12), Vector3(0, 0, 0), "Jaw")
	for x in [-0.085, 0.085]:
		GameUtil.sphere(visual, 0.07, black, Vector3(x, 1.58, -0.19), Vector3(1.0, 1.15, 0.5), "EyeSocket")
		GameUtil.sphere(visual, 0.035, green, Vector3(x, 1.58, -0.225), Vector3.ONE, "EyeGlow")
	GameUtil.box(visual, Vector3(0.05, 0.04, 0.04), black, Vector3(0, 1.5, -0.225), Vector3.ZERO, "Nose")
	# tricorn hat
	var hat := Node3D.new()
	hat.position = Vector3(0, 1.73, 0.02)
	visual.add_child(hat)
	GameUtil.cylinder(hat, 0.34 if not boss else 0.44, 0.045, black, Vector3.ZERO, Vector3.ZERO, 12, "HatBrim")
	GameUtil.sphere(hat, 0.24 if not boss else 0.3, black, Vector3(0, 0.07, 0), Vector3(1.0, 0.45, 0.9), "HatCrown")
	GameUtil.box(hat, Vector3(0.12, 0.1, 0.02), GameUtil.mat("gold", 0.3, 0.5), Vector3(0, 0.03, -0.27), Vector3.ZERO, "HatBuckle")
	if boss:
		GameUtil.sphere(hat, 0.06, green, Vector3(0, 0.11, -0.24), Vector3.ONE, "HatGem")
	# arms
	for side in [-1, 1]:
		var pivot := Node3D.new()
		pivot.position = Vector3(0.35 * side, 1.18, 0)
		visual.add_child(pivot)
		pivot.rotation_degrees.z = -8.0 * side
		GameUtil.capsule(pivot, 0.07, 0.58, bone, Vector3(0, -0.27, 0), Vector3.ZERO, "BoneArm")
		GameUtil.sphere(pivot, 0.1, bone, Vector3(0, -0.56, 0), Vector3.ONE, "Hand")
		if side == 1:
			arm_r = pivot
			_build_enemy_cutlass(pivot, boss)
	# boss coat tails / aura
	if boss:
		GameUtil.cylinder(visual, 0.6, 0.16, coat_trim, Vector3(0, 0.45, 0), Vector3.ZERO, 12, "CoatHem")
		var light := OmniLight3D.new()
		light.light_color = Color("#73ff9a")
		light.light_energy = 0.8
		light.omni_range = 3.2
		light.position = Vector3(0, 1.2, 0)
		visual.add_child(light)

func _build_enemy_cutlass(parent: Node3D, boss: bool) -> void:
	var blade := GameUtil.box(parent, Vector3(0.08, 0.1, 0.85), GameUtil.raw_mat(Color("#b9b6a5"), 0.35, 0.5), Vector3(0, -0.58, -0.38), Vector3.ZERO, "EnemyBlade")
	GameUtil.box(parent, Vector3(0.30, 0.05, 0.06), GameUtil.mat("gold", 0.35, 0.5), Vector3(0, -0.58, 0.06), Vector3.ZERO, "EnemyGuard")
	GameUtil.cylinder(parent, 0.035, 0.2, GameUtil.mat("wood_dark", 0.8), Vector3(0, -0.58, 0.16), Vector3(90, 0, 0), 6, "EnemyGrip")
	if boss:
		blade.scale.x = 1.5

func _build_crab() -> void:
	var shell := GameUtil.raw_mat(Color("#d4513c"), 0.6)
	var shell_dark := GameUtil.raw_mat(Color("#9d2f28"), 0.65)
	var cream := GameUtil.mat("cream", 0.7)
	var black := GameUtil.mat("black", 0.6)
	visual.scale = Vector3.ONE
	GameUtil.sphere(visual, 0.62, shell, Vector3(0, 0.52, 0), Vector3(1.15, 0.55, 0.9), "CrabShell")
	GameUtil.sphere(visual, 0.42, shell_dark, Vector3(0, 0.7, 0.06), Vector3(1.1, 0.3, 0.9), "CrabShellTop")
	# eyes
	for x in [-0.24, 0.24]:
		GameUtil.cylinder(visual, 0.035, 0.32, shell_dark, Vector3(x, 0.9, -0.35), Vector3(-16, 0, 0), 6, "EyeStalk")
		GameUtil.sphere(visual, 0.11, cream, Vector3(x, 1.05, -0.38), Vector3.ONE, "CrabEye")
		GameUtil.sphere(visual, 0.055, black, Vector3(x, 1.05, -0.47), Vector3.ONE, "CrabPupil")
	# claws
	for side in [-1, 1]:
		var arm := Node3D.new()
		arm.position = Vector3(0.58 * side, 0.52, -0.05)
		visual.add_child(arm)
		GameUtil.cylinder_between(arm, Vector3.ZERO, Vector3(0.32 * side, -0.08, -0.35), 0.09, shell_dark, 6, "ClawArm")
		var claw := GameUtil.sphere(arm, 0.19, shell, Vector3(0.42 * side, 0.0, -0.55), Vector3(1.2, 0.65, 0.9), "Claw")
		GameUtil.sphere(arm, 0.13, shell_dark, Vector3(0.32 * side, 0.12, -0.72), Vector3(1.3, 0.4, 0.7), "ClawTip")
		if side == 1:
			arm_r = arm
	# legs
	for side in [-1, 1]:
		for i in 3:
			var a := (i - 1) * 0.55
			var leg := GameUtil.cylinder_between(visual, Vector3(0.45 * side, 0.36, -0.2 + i * 0.22), Vector3(0.85 * side, 0.08, -0.3 + i * 0.3), 0.05, shell_dark, 5, "CrabLeg")
	# little pirate bandana
	GameUtil.box(visual, Vector3(0.85, 0.09, 0.8), GameUtil.mat("red", 0.8), Vector3(0, 0.83, 0), Vector3(0, 0, 0), "CrabBandana")

func _build_health_bar() -> void:
	health_bar = Node3D.new()
	health_bar.position = Vector3(0, 2.15 if kind != Kind.CRAB else 1.5, 0)
	if is_boss:
		health_bar.position.y = 2.75
	add_child(health_bar)
	var bg := MeshInstance3D.new()
	var q := QuadMesh.new(); q.size = Vector2(1.25, 0.12)
	bg.mesh = q
	var bm := StandardMaterial3D.new()
	bm.albedo_color = Color(0.04, 0.07, 0.06, 0.82)
	bm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	bm.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	bg.material_override = bm
	bg.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	health_bar.add_child(bg)
	health_fill = MeshInstance3D.new()
	var q2 := QuadMesh.new(); q2.size = Vector2(1.17, 0.075)
	health_fill.mesh = q2
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color("#85d861")
	fm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	fm.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	health_fill.material_override = fm
	health_fill.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	health_fill.position.z = 0.01
	health_bar.add_child(health_fill)
	health_bar.visible = false

func _configure_telegraph() -> void:
	telegraph = MeshInstance3D.new()
	var q := QuadMesh.new(); q.size = Vector2(2.4, 2.4)
	telegraph.mesh = q
	telegraph.rotation_degrees.x = -90
	var m := StandardMaterial3D.new()
	m.albedo_texture = GameUtil.make_soft_circle_texture(Color(0.9, 0.06, 0.02, 0.55), Color(0.9, 0.06, 0.02, 0.0))
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	telegraph.material_override = m
	telegraph.position.y = 0.065
	telegraph.visible = false
	add_child(telegraph)

func _physics_process(delta: float) -> void:
	if dead or game == null or not game.is_playing():
		if not dead:
			_apply_gravity(delta)
			move_and_slide()
		return
	attack_cooldown = maxf(0.0, attack_cooldown - delta)
	stagger_timer = maxf(0.0, stagger_timer - delta)
	bar_timer = maxf(0.0, bar_timer - delta)
	health_bar.visible = bar_timer > 0.0
	attack_flash = maxf(0.0, attack_flash - delta)
	if player == null or player.dead:
		_state_idle(delta)
		return

	var to_player := player.global_position - global_position
	to_player.y = 0.0
	var dist := to_player.length()
	match state:
		State.IDLE:
			_state_idle(delta)
			if dist < aggro and active:
				state = State.CHASE
			if is_boss and dist < 30.0:
				state = State.CHASE
		State.CHASE:
			if dist > aggro * 1.8:
				state = State.IDLE
				wander_target = home
			if dist <= attack_range and attack_cooldown <= 0.0:
				_begin_attack()
			else:
				var dir := to_player.normalized() if dist > 0.01 else facing_dir()
				var sep := _separation()
				velocity.x = (dir.x + sep.x) * speed
				velocity.z = (dir.z + sep.z) * speed
				if dist < attack_range * 0.9:
					velocity.x *= 0.2
					velocity.z *= 0.2
				_face_dir(dir, delta)
				walk_phase += delta * 8.0
		State.WINDUP:
			velocity.x = move_toward(velocity.x, 0.0, 24.0 * delta)
			velocity.z = move_toward(velocity.z, 0.0, 24.0 * delta)
			attack_timer -= delta
			telegraph.visible = true
			var pulse := 0.8 + 0.25 * sin(attack_timer * 35.0)
			telegraph.scale = Vector3.ONE * pulse
			if attack_timer <= 0.0:
				telegraph.visible = false
				_do_attack(dist)
				state = State.RECOVER
				attack_timer = 0.45
		State.RECOVER:
			velocity.x = move_toward(velocity.x, 0.0, 18.0 * delta)
			velocity.z = move_toward(velocity.z, 0.0, 18.0 * delta)
			attack_timer -= delta
			if attack_timer <= 0.0:
				state = State.CHASE
		State.STAGGER:
			velocity.x = move_toward(velocity.x, 0.0, 12.0 * delta)
			velocity.z = move_toward(velocity.z, 0.0, 12.0 * delta)
			if stagger_timer <= 0.0:
				state = State.CHASE
	_apply_gravity(delta)
	move_and_slide()
	if global_position.x * global_position.x + global_position.z * global_position.z > 36.0 * 36.0:
		var p := Vector3(global_position.x, 0.0, global_position.z).normalized()
		global_position.x = p.x * 36.0
		global_position.z = p.z * 36.0
	if world != null and global_position.y < -1.0:
		global_position = home
	# boss special: ground slam ring
	if is_boss:
		special_timer -= delta
		if special_timer <= 0.0 and dist < 16.0 and state != State.WINDUP:
			special_timer = 7.0
			_boss_slam()
	_update_visual(delta)
	_update_bar()

func _state_idle(delta: float) -> void:
	wander_timer -= delta
	if wander_timer <= 0.0:
		wander_timer = randf_range(2.6, 5.5)
		var a := randf() * TAU
		var r := randf_range(1.5, 5.5)
		wander_target = home + Vector3(cos(a) * r, 0.0, sin(a) * r)
		wander_target.y = world.height_at(wander_target.x, wander_target.z) if world else global_position.y
	var to := wander_target - global_position
	to.y = 0.0
	if to.length() > 0.7:
		var dir := to.normalized()
		velocity.x = move_toward(velocity.x, dir.x * speed * 0.32, 12.0 * delta)
		velocity.z = move_toward(velocity.z, dir.z * speed * 0.32, 12.0 * delta)
		_face_dir(dir, delta)
		walk_phase += delta * 4.0
	else:
		velocity.x = move_toward(velocity.x, 0.0, 12.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 12.0 * delta)

func _separation() -> Vector3:
	var sum := Vector3.ZERO
	for node in get_tree().get_nodes_in_group("enemy"):
		if node == self or not is_instance_valid(node):
			continue
		var other := node as Node3D
		var d := global_position - other.global_position
		d.y = 0.0
		var l := d.length()
		if l > 0.01 and l < 1.3:
			sum += d.normalized() * (1.3 - l) * 0.8
	return sum

func _face_dir(dir: Vector3, delta: float) -> void:
	if dir.length_squared() < 0.001:
		return
	var target_yaw := GameUtil.yaw_to(dir)
	rotation.y = lerp_angle(rotation.y, target_yaw, clampf(delta * 9.0, 0.0, 1.0))

func facing_dir() -> Vector3:
	return Vector3(-sin(rotation.y), 0, -cos(rotation.y))

func _begin_attack() -> void:
	state = State.WINDUP
	attack_timer = 0.55 if not is_boss else 0.7
	telegraph.scale = Vector3.ONE
	telegraph.visible = true
	if game:
		game.play_sfx("enemy_windup")
	if arm_r:
		var tw := create_tween()
		tw.tween_property(arm_r, "rotation_degrees:x", -95.0, 0.25).set_ease(Tween.EASE_OUT)

func _do_attack(dist: float) -> void:
	var reach := 2.9 if is_boss else 2.35
	if dist <= reach and player:
		player.take_damage(damage, (player.global_position - global_position).normalized())
	attack_cooldown = 1.25 if not is_boss else 1.6
	if game:
		game.play_sfx("enemy_swing")
		game.shake_camera(0.18, 0.13)
	if arm_r:
		var tw := create_tween()
		tw.tween_property(arm_r, "rotation_degrees:x", 35.0, 0.11).set_ease(Tween.EASE_IN)
		tw.tween_property(arm_r, "rotation_degrees:x", 0.0, 0.35)

func _boss_slam() -> void:
	if game == null:
		return
	game.show_toast("船长震碎了甲板！快躲开！", 1.4)
	game.play_sfx("slam")
	game.shake_camera(0.45, 0.4)
	var dist := global_position.distance_to(player.global_position)
	if dist < 4.5:
		player.take_damage(18.0, (player.global_position - global_position).normalized())
	game.spawn_shockwave(global_position)

func take_damage(amount: float, from_dir := Vector3.ZERO, source: Node = null) -> void:
	if dead:
		return
	health = maxf(0.0, health - amount)
	bar_timer = 4.0
	state = State.STAGGER
	stagger_timer = 0.18 if not is_boss else 0.12
	knockback_tween(from_dir)
	if game:
		game.spawn_damage_number(global_position + Vector3(0, 1.8 if kind != Kind.CRAB else 1.3, 0), int(amount), Color("#ffe68a"))
		game.play_sfx("hit")
		game.spawn_hit_sparks(global_position + Vector3(0, 1.0, 0), from_dir)
		game.add_hit()
	if health <= 0.0:
		_die()

func knockback_tween(dir: Vector3) -> void:
	if dir.length_squared() < 0.001:
		return
	var tw := create_tween()
	tw.tween_property(self, "velocity", dir.normalized() * 4.0, 0.06)
	# velocity is overwritten next physics frame; visual feedback only

func _die() -> void:
	dead = true
	state = State.DEAD
	telegraph.visible = false
	health_bar.visible = false
	collision_layer = 0
	collision_mask = 0
	if game:
		game.on_enemy_killed(self)
		game.play_sfx("enemy_die")
		game.spawn_death_puff(global_position + Vector3(0, 0.8, 0))
	var tw := create_tween()
	tw.tween_property(visual, "scale", Vector3(0.05, 0.03, 0.05), 0.55).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(visual, "rotation_degrees:z", 65.0, 0.55)
	tw.parallel().tween_property(self, "position:y", position.y - 0.2, 0.55)
	tw.tween_interval(0.1)
	tw.tween_callback(queue_free)

func _update_visual(delta: float) -> void:
	if visual == null:
		return
	var moving := velocity.length() > 0.25
	if kind == Kind.CRAB:
		visual.position.y = absf(sin(walk_phase * 1.8)) * 0.035
		visual.rotation.z = sin(walk_phase * 1.3) * 0.035
	else:
		visual.position.y = absf(sin(walk_phase)) * 0.045
		visual.rotation.z = sin(walk_phase * 0.5) * 0.025 if moving else 0.0
	if stagger_timer > 0.0:
		visual.rotation.z += sin(stagger_timer * 70.0) * 0.12
	if attack_flash > 0.0 and arm_r:
		arm_r.rotation_degrees.x = -80.0

func _update_bar() -> void:
	if health_fill == null:
		return
	var ratio := clampf(health / maxf(max_health, 0.001), 0.0, 1.0)
	health_fill.scale.x = maxf(ratio, 0.001)
	health_fill.position.x = -(1.0 - ratio) * 0.585
	var mat := health_fill.material_override as StandardMaterial3D
	if mat:
		mat.albedo_color = Color("#85d861").lerp(Color("#e65948"), 1.0 - ratio)

func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= 22.0 * delta
	else:
		velocity.y = 0.0
	if shadow != null and world != null:
		var ground := world.height_at(global_position.x, global_position.z)
		shadow.global_position = Vector3(global_position.x, ground + 0.06, global_position.z)

