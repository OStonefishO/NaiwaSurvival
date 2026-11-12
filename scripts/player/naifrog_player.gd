class_name NaifrogPlayer
extends CharacterBody3D

signal stats_changed
signal died

const WALK_SPEED := 4.5
const RUN_SPEED := 7.2
const ACCEL := 14.0
const GRAVITY := 24.0

var game: Node
var world: Node
var camera_rig: CameraRig
var inventory: Inventory
var survival: SurvivalComponent
var visual: Node3D
var model_root: Node3D
var animation_player: AnimationPlayer
var collision: CollisionShape3D
var torch_light: OmniLight3D
var facing_dir := Vector3(0, 0, -1)
var dead := false
var invulnerable := 0.0
var attack_cooldown := 0.0
var dodge_cooldown := 0.0
var dodge_time := 0.0
var dodge_dir := Vector3.ZERO
var hurt_flash := 0.0
var _current_anim := ""
var _procedural_anim_time := 0.0
var _attack_time := 0.0
var _last_moving := false

func setup(p_game: Node, p_world: Node, p_camera: CameraRig) -> void:
	game = p_game
	world = p_world
	camera_rig = p_camera

func _ready() -> void:
	add_to_group("player")
	collision = CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.38
	cap.height = 1.45
	collision.shape = cap
	collision.position.y = 0.78
	add_child(collision)
	visual = Node3D.new()
	visual.name = "Visual"
	add_child(visual)
	inventory = Inventory.new()
	survival = SurvivalComponent.new()
	add_child(survival)
	survival.died.connect(_on_survival_died)
	survival.health_changed.connect(func(_c, _m): stats_changed.emit())
	survival.hunger_changed.connect(func(_c, _m): stats_changed.emit())
	survival.stamina_changed.connect(func(_c, _m): stats_changed.emit())
	_build_visual()
	_build_torch_light()

func _build_visual() -> void:
	var glb := GameUtil.load_glb("res://assets/models/frog/naifrog.glb")
	if glb:
		model_root = glb
		model_root.name = "NaiFrogModel"
		model_root.scale = Vector3(0.95, 0.95, 0.95)
		model_root.position.y = 1.0
		model_root.rotation.y = PI
		visual.add_child(model_root)
		_apply_frog_materials()
		animation_player = _find_animation_player(model_root)
		if animation_player:
			animation_player.animation_finished.connect(_on_anim_finished)
			animation_player.play("Idle")
	else:
		_build_placeholder()
	GameUtil.add_blob_shadow(visual, Vector2(0.9, 0.9))

func _build_placeholder() -> void:
	model_root = Node3D.new()
	model_root.name = "PlaceholderFrog"
	visual.add_child(model_root)
	var yellow := GameUtil.mat("gold", 0.6)
	var cream := GameUtil.mat("cream", 0.8)
	var green := GameUtil.mat("leaf", 0.5)
	var dark := GameUtil.raw_mat(Color("#4a4636"), 0.8)
	GameUtil.sphere(model_root, 0.55, yellow, Vector3(0, 0.94, 0), Vector3(0.9, 1.25, 0.8), "Body")
	GameUtil.sphere(model_root, 0.42, cream, Vector3(0, 0.77, -0.31), Vector3(0.9, 0.85, 0.32), "Belly")
	for x in [-0.22, 0.22]:
		GameUtil.sphere(model_root, 0.17, green, Vector3(x, 1.37, -0.32), Vector3(0.9, 1, 0.5), "EyeRing")
		GameUtil.sphere(model_root, 0.09, GameUtil.raw_mat(Color("#172018"), 0.3), Vector3(x, 1.37, -0.43), Vector3.ONE, "Pupil")
	var mouth := Curve3D.new()
	# 用细长盒子近似嘴线
	GameUtil.box(model_root, Vector3(0.24, 0.025, 0.02), GameUtil.raw_mat(Color("#5d4c2f"), 0.7), Vector3(0, 1.18, -0.45), Vector3.ZERO, "Mouth")
	for x in [-0.38, 0.38]:
		GameUtil.cylinder(model_root, 0.09, 0.43, yellow, Vector3(x, 0.72, 0), Vector3(0, 0, 16.0 if x > 0 else -16.0), 8, "Arm")
		GameUtil.sphere(model_root, 0.11, dark, Vector3(x * 1.08, 0.49, 0), Vector3(0.9, 1, 0.9), "Hand")
	for x in [-0.2, 0.2]:
		GameUtil.cylinder(model_root, 0.12, 0.42, yellow, Vector3(x, 0.28, 0), Vector3.ZERO, 8, "Leg")
		GameUtil.sphere(model_root, 0.16, dark, Vector3(x, 0.07, -0.08), Vector3(1.2, 0.5, 1.6), "Foot")

func _find_animation_player(node: Node) -> AnimationPlayer:
	var ap := node.find_child("AnimationPlayer", true, false)
	return ap as AnimationPlayer

func _apply_frog_materials() -> void:
	var mi := model_root.find_child("NaiFrogMesh", true, false) as MeshInstance3D
	if mi == null:
		return
	var colors := {
		"FrogYellow": Color("#efb92f"),
		"BellyCream": Color("#f1e0b9"),
		"EyeGreen": Color("#3f8d4c"),
		"EyeBlack": Color("#11160f"),
		"HandOlive": Color("#4c4733"),
		"EyeSpark": Color("#fffaf0"),
		"MouthDark": Color("#3c2d1d"),
	}
	for i in mi.mesh.get_surface_count():
		var src := mi.mesh.surface_get_material(i)
		var key := src.resource_name if src else ""
		if not colors.has(key):
			# fallback by tint
			if src and src.albedo_color.g > src.albedo_color.r * 1.15:
				key = "EyeGreen"
			elif src and src.albedo_color.r > 0.9 and src.albedo_color.g > 0.75:
				key = "BellyCream"
			elif src and src.albedo_color.r > 0.8 and src.albedo_color.g > 0.5:
				key = "FrogYellow"
			else:
				key = "HandOlive"
		var m := StandardMaterial3D.new()
		m.albedo_color = colors.get(key, Color.WHITE)
		m.roughness = 0.62
		mi.set_surface_override_material(i, m)

func _build_torch_light() -> void:
	torch_light = OmniLight3D.new()
	torch_light.name = "TorchLight"
	torch_light.light_color = Color("#ffc477")
	torch_light.light_energy = 0.0
	torch_light.omni_range = 8.0
	torch_light.position = Vector3(0.45, 1.0, -0.2)
	torch_light.shadow_enabled = false
	add_child(torch_light)

func set_spawn(pos: Vector3) -> void:
	global_position = pos
	facing_dir = Vector3(0, 0, 1)
	rotation.y = PI

func _physics_process(delta: float) -> void:
	if dead or survival == null or not survival.alive:
		velocity = Vector3.ZERO
		move_and_slide()
		return
	if game and game.is_input_blocked():
		velocity.x = move_toward(velocity.x, 0.0, ACCEL * delta)
		velocity.z = move_toward(velocity.z, 0.0, ACCEL * delta)
	else:
		_handle_movement(delta)
	_handle_timers(delta)
	if invulnerable > 0.0:
		invulnerable -= delta
	if hurt_flash > 0.0:
		hurt_flash -= delta
		visual.scale = Vector3.ONE * (1.0 + sin(hurt_flash * 40.0) * 0.03)
	else:
		visual.scale = Vector3.ONE
	# keep on terrain
	if is_on_floor() and velocity.y < 0.0:
		velocity.y = -0.5
	velocity.y -= GRAVITY * delta
	move_and_slide()
	_update_visual_animation(delta)
	_update_torch()

func _handle_movement(delta: float) -> void:
	var input := Vector2(
		Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
		Input.get_action_strength("move_down") - Input.get_action_strength("move_up")
	)
	if input.length() > 1.0:
		input = input.normalized()
	var basis := camera_rig.global_transform.basis if camera_rig else Basis.IDENTITY
	var forward := -basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var right := basis.x
	right.y = 0.0
	right = right.normalized()
	var move_dir := (right * input.x + forward * -input.y).normalized()
	if dodge_time > 0.0:
		velocity.x = dodge_dir.x * 12.5
		velocity.z = dodge_dir.z * 12.5
		dodge_time -= delta
	else:
		var sprinting := Input.is_action_pressed("sprint") and input.length() > 0.1
		var speed := RUN_SPEED if sprinting and survival.stamina > 0.0 else WALK_SPEED
		if sprinting:
			survival.spend_stamina(delta * 16.0)
		var target := move_dir * speed
		velocity.x = move_toward(velocity.x, target.x, ACCEL * delta)
		velocity.z = move_toward(velocity.z, target.z, ACCEL * delta)
	if input.length() > 0.05:
		facing_dir = move_dir
	# idle keeps the current facing; attacks aim at the mouse in _attack()
	if facing_dir.length_squared() > 0.01:
		var target_yaw := atan2(-facing_dir.x, -facing_dir.z)
		rotation.y = lerp_angle(rotation.y, target_yaw, 1.0 - exp(-12.0 * delta))
	# dodge
	if Input.is_action_just_pressed("dodge") and dodge_cooldown <= 0.0 and survival.spend_stamina(22.0):
		dodge_dir = move_dir if move_dir.length() > 0.1 else facing_dir
		dodge_time = 0.24
		dodge_cooldown = 0.8
		invulnerable = maxf(invulnerable, 0.34)
		_play_anim("Dodge")
		if game:
			game.play_sfx("dash", 0.1)

func _handle_timers(delta: float) -> void:
	attack_cooldown = maxf(0.0, attack_cooldown - delta)
	dodge_cooldown = maxf(0.0, dodge_cooldown - delta)
	_attack_time = maxf(0.0, _attack_time - delta)
	if Input.is_action_pressed("attack") and attack_cooldown <= 0.0 and not (game and game.is_input_blocked()):
		_attack()
	if Input.is_action_just_pressed("interact") and not (game and game.is_input_blocked()):
		_interact()

func _mouse_direction() -> Vector3:
	if camera_rig == null:
		return Vector3.ZERO
	var p := camera_rig.mouse_ground_position(global_position.y)
	var d := p - global_position
	d.y = 0.0
	return d.normalized()

func _attack() -> void:
	attack_cooldown = 0.55
	var aim := _mouse_direction()
	if aim.length_squared() > 0.01:
		facing_dir = aim
	var item := inventory.selected_item()
	if item and item.category == "consumable":
		_use_consumable(item)
		return
	var damage := 6.0
	if item:
		damage = maxf(damage, item.damage)
	_play_anim("Attack")
	_attack_time = 0.28
	if game:
		game.spawn_attack_arc(global_position + Vector3(0, 0.9, 0), facing_dir)
		game.play_sfx("swing", 0.12)
		if item and item.id == "torch":
			game.play_sfx("ignite", 0.2)
	var hit_any := false
	# enemies
	for e in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(e):
			continue
		var ep: Vector3 = e.global_position
		var d := ep - global_position
		d.y = 0.0
		if d.length() <= 3.0 and d.normalized().dot(facing_dir) > 0.25:
			e.call("take_damage", damage, facing_dir, self)
			hit_any = true
	# resource nodes
	for r in get_tree().get_nodes_in_group("resource"):
		if not is_instance_valid(r):
			continue
		var rp: Vector3 = r.global_position
		var d := rp - global_position
		d.y = 0.0
		if d.length() <= 3.0 and d.normalized().dot(facing_dir) > 0.15:
			r.call("hit_resource", self, item, damage)
			hit_any = true
	if hit_any and game:
		game.play_sfx("hit", 0.1)
		game.hitstop(0.035)
		game.shake_camera(0.16, 0.16)

func _use_consumable(item: ItemData) -> void:
	if survival.eat(item):
		inventory.remove_item(item.id, 1)
		if game:
			game.play_sfx("eat", 0.08)
			game.show_toast("吃下了%s" % item.display_name, 1.4)
	_play_anim("Attack")

func _interact() -> void:
	var best: Node = null
	var best_dist := 3.0
	for n in get_tree().get_nodes_in_group("interactable"):
		if not is_instance_valid(n):
			continue
		var d: float = global_position.distance_to((n as Node3D).global_position)
		if d < best_dist:
			best_dist = d
			best = n
	if best and best.has_method("interact"):
		best.call("interact", self)
	elif inventory.selected_item() and inventory.selected_item().category == "consumable":
		_use_consumable(inventory.selected_item())

func _update_torch() -> void:
	if torch_light == null:
		return
	var item := inventory.selected_item()
	var on := item != null and item.id == "torch"
	torch_light.light_energy = 1.0 if on else 0.0

func _update_visual_animation(delta: float) -> void:
	_procedural_anim_time += delta
	var moving := Vector2(velocity.x, velocity.z).length() > 0.4
	if animation_player:
		if _attack_time > 0.0:
			return
		var want := "Idle"
		if moving:
			want = "Run" if velocity.length() > 5.5 else "Walk"
		if want != _current_anim:
			_play_anim(want)
	else:
		# 占位/兜底程序动画
		var bob := sin(_procedural_anim_time * (10.0 if moving else 3.0)) * (0.045 if moving else 0.015)
		model_root.position.y = bob
		model_root.scale = Vector3(1.0 + bob * 0.4, 1.0 - bob * 0.4, 1.0 + bob * 0.4)
		if moving:
			model_root.rotation.z = sin(_procedural_anim_time * 10.0) * 0.06

func _play_anim(name: String) -> void:
	if animation_player == null:
		_current_anim = name
		return
	if animation_player.has_animation(name):
		if _current_anim == name and name != "Attack" and name != "Dodge":
			return
		animation_player.play(name)
		_current_anim = name

func _on_anim_finished(_name: String) -> void:
	_attack_time = 0.0
	_current_anim = ""

func _on_survival_died() -> void:
	if dead:
		return
	dead = true
	_play_anim("Death")
	died.emit()

func take_damage(amount: float, from_dir := Vector3.ZERO) -> void:
	if dead or invulnerable > 0.0:
		return
	survival.damage(amount)
	invulnerable = 0.9
	hurt_flash = 0.28
	velocity += from_dir.normalized() * 4.0
	if game:
		game.play_sfx("hurt", 0.08)
		game.shake_camera(0.35, 0.25)
	stats_changed.emit()

func revive(pos: Vector3) -> void:
	dead = false
	survival.alive = true
	survival.health = 60.0
	survival.hunger = maxf(survival.hunger, 50.0)
	survival.stamina = 100.0
	survival.health_changed.emit(survival.health, SurvivalComponent.MAX_HEALTH)
	set_spawn(pos)
	invulnerable = 2.5
	_current_anim = ""
	_play_anim("Idle")

func to_save() -> Dictionary:
	return {
		"position": [global_position.x, global_position.y, global_position.z],
		"health": survival.health, "hunger": survival.hunger, "stamina": survival.stamina,
		"inventory": inventory.to_save(), "selected": inventory.selected_index,
	}

func from_save(data: Dictionary) -> void:
	var p = data.get("position", [0, 0, 0])
	global_position = Vector3(float(p[0]), float(p[1]), float(p[2]))
	survival.from_save(data)
	inventory.from_save(data.get("inventory", []))
	inventory.select(int(data.get("selected", 0)))
