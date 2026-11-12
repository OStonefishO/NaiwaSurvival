class_name ForestEnemy
extends CharacterBody3D

enum State { IDLE, CHASE, WINDUP, ATTACK, RECOVER, RETURN, DEAD }

var game: Node
var world: ForestWorld
var data: EnemyData
var data_id := ""
var player: NaifrogPlayer
var state: int = State.IDLE
var health := 10.0
var model_root: Node3D
var visual: Node3D
var collision: CollisionShape3D
var spawn_point := Vector3.ZERO
var state_timer := 0.0
var attack_cooldown := 0.0
var _bob := 0.0
var _flash := 0.0
var _health_fill: MeshInstance3D
var _telegraph: MeshInstance3D
var _dead_timer := 0.0

func setup(p_game: Node, p_world: ForestWorld, p_id: String, pos: Vector3) -> void:
	game = p_game
	world = p_world
	data_id = p_id
	data = GameDB.enemy(p_id)
	position = pos
	spawn_point = pos

func _ready() -> void:
	add_to_group("enemy")
	collision_layer = 1
	collision_mask = 1
	player = game.player
	health = data.max_health
	_build_collision()
	_build_visual()
	_build_healthbar()
	_build_telegraph()

func _build_collision() -> void:
	collision = CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	var boss := data.is_boss
	cap.radius = 1.4 if boss else 0.55
	cap.height = 3.0 if boss else 1.1
	collision.shape = cap
	collision.position.y = 1.5 if boss else 0.55
	add_child(collision)

func _build_visual() -> void:
	visual = Node3D.new()
	add_child(visual)
	var glb := GameUtil.load_glb(data.model_path)
	if glb:
		model_root = glb
		visual.add_child(model_root)
		if data.is_boss:
			model_root.scale = Vector3.ONE * 1.4
	else:
		_build_fallback()
	GameUtil.add_blob_shadow(visual, Vector2(1.5, 1.5) if not data.is_boss else Vector2(5.0, 5.0))

func _build_fallback() -> void:
	model_root = Node3D.new()
	visual.add_child(model_root)
	match data_id:
		"slime":
			GameUtil.sphere(model_root, 0.58, GameUtil.raw_mat(Color("#7fc39a"), 0.35), Vector3(0, 0.55, 0), Vector3(1.0, 0.8, 1.0), "Slime")
			for x in [-0.18, 0.18]:
				GameUtil.sphere(model_root, 0.07, GameUtil.raw_mat(Color("#122016"), 0.3), Vector3(x, 0.75, -0.48), Vector3.ONE, "Eye")
		"mushroom_bug":
			GameUtil.sphere(model_root, 0.45, GameUtil.raw_mat(Color("#7b5a43"), 0.7), Vector3(0, 0.4, 0), Vector3(1.2, 0.75, 1.0), "Bug")
			GameUtil.cone(model_root, 0.56, 0.45, GameUtil.mat("mushroom"), Vector3(0, 0.9, 0), Vector3.ZERO, 10, "Cap")
			for i in 4:
				GameUtil.cylinder(model_root, 0.05, 0.35, GameUtil.mat("bark_dark"), Vector3(-0.4 + i * 0.26, 0.18, 0.2), Vector3(0, 0, 50 if i % 2 == 0 else -50), 5, "Leg")
		"spiky_beast":
			GameUtil.sphere(model_root, 0.65, GameUtil.mat("bark"), Vector3(0, 0.62, 0), Vector3(1.15, 0.9, 1.2), "Beast")
			for i in 7:
				var a := TAU * float(i) / 7.0
				GameUtil.cone(model_root, 0.13, 0.55, GameUtil.mat("rock_dark"), Vector3(cos(a) * 0.55, 0.9, sin(a) * 0.55), Vector3(0, 0, 0), 5, "Spike")
			for x in [-0.22, 0.22]:
				GameUtil.sphere(model_root, 0.09, GameUtil.raw_mat(Color("#e1b55a"), 0.3, 0.0, 1.0), Vector3(x, 0.72, -0.56), Vector3.ONE, "Eye")
		"ancient_guardian":
			GameUtil.cylinder(model_root, 1.0, 4.2, GameUtil.mat("bark_dark"), Vector3(0, 2.1, 0), Vector3.ZERO, 10, "Trunk")
			GameUtil.sphere(model_root, 1.3, GameUtil.mat("leaf_dark"), Vector3(0, 4.5, 0), Vector3(1.8, 0.75, 1.3), "Crown")
			GameUtil.sphere(model_root, 0.28, GameUtil.raw_mat(Color("#8ef0cf"), 0.2, 0.0, 3.0), Vector3(0, 3.0, -0.94), Vector3(1.0, 1.0, 0.35), "Heart")
			for x in [-0.4, 0.4]:
				GameUtil.sphere(model_root, 0.09, GameUtil.raw_mat(Color("#111"), 0.4), Vector3(x, 3.7, -0.8), Vector3.ONE, "Eye")
		_:
			GameUtil.sphere(model_root, 0.5, GameUtil.mat("slime"), Vector3(0, 0.5, 0), Vector3.ONE, "Body")

func _build_healthbar() -> void:
	var bg := MeshInstance3D.new()
	var bg_mesh := QuadMesh.new(); bg_mesh.size = Vector2(1.2, 0.13)
	bg.mesh = bg_mesh
	bg.position.y = 2.0 if not data.is_boss else 4.6
	var bm := StandardMaterial3D.new()
	bm.albedo_color = Color(0.04, 0.07, 0.04, 0.8)
	bm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	bm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bg.material_override = bm
	add_child(bg)
	_health_fill = MeshInstance3D.new()
	var fill_mesh := QuadMesh.new(); fill_mesh.size = Vector2(1.12, 0.08)
	_health_fill.mesh = fill_mesh
	_health_fill.position.y = 2.0 if not data.is_boss else 4.6
	_health_fill.position.x = -0.56
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color("#81d36b")
	fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	_health_fill.material_override = fm
	add_child(_health_fill)

func _build_telegraph() -> void:
	_telegraph = MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 1.2
	torus.outer_radius = 1.35
	_telegraph.mesh = torus
	_telegraph.rotation_degrees.x = 90
	_telegraph.position.y = 0.08
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(1.0, 0.35, 0.2, 0.7)
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_telegraph.material_override = m
	_telegraph.visible = false
	add_child(_telegraph)

func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		_dead_timer -= delta
		visual.scale = visual.scale.lerp(Vector3(0.1, 0.1, 0.1), 1.0 - exp(-8.0 * delta))
		if _dead_timer <= 0.0:
			queue_free()
		return
	if player == null or player.dead:
		_apply_gravity(delta, Vector3.ZERO)
		return
	attack_cooldown = maxf(0.0, attack_cooldown - delta)
	state_timer -= delta
	_bob += delta
	var dist := global_position.distance_to(player.global_position)
	if _flash > 0.0:
		_flash -= delta
		visual.scale = Vector3.ONE * (1.0 + sin(_flash * 40.0) * 0.06)
	else:
		visual.scale = Vector3.ONE
	match state:
		State.IDLE:
			visual.rotation.y += delta * 0.15
			_apply_gravity(delta, Vector3.ZERO)
			if dist < data.aggro_range:
				state = State.CHASE
		State.CHASE:
			_telegraph.visible = false
			var dir := (player.global_position - global_position)
			dir.y = 0.0
			if dir.length() > 0.05:
				dir = dir.normalized()
				visual.rotation.y = atan2(dir.x, dir.z)
			if dist < data.attack_range and attack_cooldown <= 0.0:
				state = State.WINDUP
				state_timer = 0.45
				_telegraph.visible = true
				if game:
					game.play_sfx("enemy_windup", 0.08)
			elif dist > data.aggro_range * 1.8:
				state = State.RETURN
			else:
				_apply_gravity(delta, dir * data.speed)
		State.WINDUP:
			_telegraph.visible = true
			_telegraph.scale = Vector3.ONE * (1.0 + sin(_bob * 18.0) * 0.05)
			_apply_gravity(delta, Vector3.ZERO)
			if state_timer <= 0.0:
				state = State.ATTACK
				state_timer = 0.18
				if dist <= data.attack_range + 0.7:
					player.take_damage(data.damage, (player.global_position - global_position).normalized())
					if game:
						game.play_sfx("enemy_swing", 0.08)
		State.ATTACK:
			_apply_gravity(delta, Vector3.ZERO)
			if state_timer <= 0.0:
				state = State.RECOVER
				state_timer = 0.38
		State.RECOVER:
			_telegraph.visible = false
			_apply_gravity(delta, Vector3.ZERO)
			if state_timer <= 0.0:
				attack_cooldown = data.attack_cooldown
				state = State.CHASE
		State.RETURN:
			_telegraph.visible = false
			var dir := (spawn_point - global_position)
			dir.y = 0.0
			if dir.length() < 1.0:
				state = State.IDLE
			else:
				_apply_gravity(delta, dir.normalized() * data.speed * 0.7)
	# bobbing does not affect collision
	visual.position.y = sin(_bob * 5.0) * 0.04

func _apply_gravity(delta: float, horiz: Vector3) -> void:
	velocity.x = horiz.x
	velocity.z = horiz.z
	if is_on_floor():
		velocity.y = -0.4
	else:
		velocity.y -= 24.0 * delta
	move_and_slide()

func take_damage(amount: float, dir: Vector3, _actor: Node) -> void:
	if state == State.DEAD:
		return
	health -= amount
	_flash = 0.18
	if game:
		game.spawn_hit_sparks(global_position + Vector3(0, 1.0, 0), dir)
		game.play_sfx("hit", 0.12)
	_update_healthbar()
	if health <= 0.0:
		_die()
	else:
		state = State.CHASE
		velocity += dir.normalized() * 2.0

func _update_healthbar() -> void:
	var ratio := clampf(health / data.max_health, 0.0, 1.0)
	_health_fill.scale.x = maxf(0.01, ratio)
	_health_fill.position.x = -0.56 * ratio

func _die() -> void:
	state = State.DEAD
	_dead_timer = 0.75
	collision.disabled = true
	_telegraph.visible = false
	for id in data.drops:
		game.spawn_item_pickup(id, int(data.drops[id]), global_position + Vector3(0, 0.6, 0))
	if game:
		game.play_sfx("enemy_die", 0.1)
		game.spawn_death_puff(global_position + Vector3(0, 0.6, 0))
		game.quest_event("kill", data_id)
		if data.is_boss:
			game.quest_event("boss", data_id)

func to_save() -> Dictionary:
	return {"id": data_id, "pos": [global_position.x, global_position.y, global_position.z], "health": health, "state": state}
