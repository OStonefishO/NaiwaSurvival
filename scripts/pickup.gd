class_name Pickup
extends Node3D

enum Kind { COCONUT, WOOD, COIN, MAP, HEART, STONE, FIBER }

var kind := Kind.COCONUT
var game: Node
var player: MilkFrog
var start_y := 0.0
var phase := 0.0
var collected := false
var speed := 0.0
var visual: Node3D
var magnet := false

func setup(p_game: Node, p_player: MilkFrog, p_kind: int, pos: Vector3) -> void:
	game = p_game
	player = p_player
	kind = p_kind
	position = pos
	phase = randf() * TAU

func _ready() -> void:
	add_to_group("pickup")
	start_y = global_position.y
	visual = Node3D.new()
	add_child(visual)
	match kind:
		Kind.COCONUT: _make_coconut()
		Kind.WOOD: _make_wood()
		Kind.COIN: _make_coin()
		Kind.MAP: _make_map()
		Kind.HEART: _make_heart()
		Kind.STONE: _make_stone()
		Kind.FIBER: _make_fiber()
	if kind == Kind.MAP:
		var light := OmniLight3D.new()
		light.light_color = Color("#ffd35c")
		light.light_energy = 1.2
		light.omni_range = 2.0
		light.position.y = 0.6
		add_child(light)

func _make_coconut() -> void:
	var brown := GameUtil.mat("wood_dark", 0.9)
	var green := GameUtil.mat("leaf", 0.8)
	GameUtil.sphere(visual, 0.17, brown, Vector3(0, 0.28, 0), Vector3(1.0, 1.05, 1.0), "Coconut")
	GameUtil.sphere(visual, 0.06, GameUtil.raw_mat(Color("#3d2416"), 0.9), Vector3(-0.06, 0.38, -0.12), Vector3.ONE, "CoconutEye1")
	GameUtil.sphere(visual, 0.055, GameUtil.raw_mat(Color("#3d2416"), 0.9), Vector3(0.07, 0.39, -0.11), Vector3.ONE, "CoconutEye2")
	GameUtil.sphere(visual, 0.045, GameUtil.raw_mat(Color("#3d2416"), 0.9), Vector3(0.01, 0.30, -0.16), Vector3.ONE, "CoconutEye3")
	GameUtil.sphere(visual, 0.24, green, Vector3(0, 0.18, 0.02), Vector3(1.25, 0.38, 1.25), "Leaf")

func _make_wood() -> void:
	var wood := GameUtil.mat("wood", 0.9)
	for i in 3:
		var log := GameUtil.cylinder(visual, 0.09, 0.65, wood, Vector3((i - 1) * 0.18, 0.13 + (i % 2) * 0.1, 0), Vector3(0, 0, 90), 7, "Log")
		GameUtil.cylinder(visual, 0.095, 0.1, GameUtil.raw_mat(Color("#d9b987"), 0.9), Vector3((i - 1) * 0.18, 0.13 + (i % 2) * 0.1, 0.33), Vector3(90, 0, 0), 7, "LogEnd")

func _make_coin() -> void:
	var gold := GameUtil.mat("gold", 0.25, 0.45, 0.35)
	GameUtil.cylinder(visual, 0.16, 0.035, gold, Vector3(0, 0.35, 0), Vector3(90, 0, 0), 16, "Coin")
	GameUtil.cylinder(visual, 0.09, 0.045, GameUtil.mat("gold_dark", 0.3, 0.5), Vector3(0, 0.35, -0.002), Vector3(90, 0, 0), 12, "CoinInner")

func _make_map() -> void:
	var paper := GameUtil.raw_mat(Color("#f4dfb0"), 0.9)
	var brown := GameUtil.mat("wood_dark", 0.9)
	var obj := Node3D.new()
	obj.position.y = 0.5
	obj.rotation_degrees = Vector3(60, 0, 20)
	visual.add_child(obj)
	GameUtil.box(obj, Vector3(0.55, 0.02, 0.42), paper, Vector3.ZERO, Vector3.ZERO, "MapPaper")
	GameUtil.box(obj, Vector3(0.02, 0.03, 0.36), GameUtil.raw_mat(Color("#b84f3a"), 0.9), Vector3(0.1, 0.02, 0), Vector3(0, 0, 0), "MapX")
	GameUtil.box(obj, Vector3(0.14, 0.035, 0.03), brown, Vector3(0.1, 0.02, 0), Vector3(0, 0, 45), "MapX2")
	GameUtil.sphere(visual, 0.10, GameUtil.mat("gold", 0.3, 0.4, 1.2), Vector3(0, 0.75, -0.02), Vector3(1.4, 1.4, 0.2), "MapGlow")

func _make_heart() -> void:
	var pink := GameUtil.raw_mat(Color("#ff7d78"), 0.5, 0.0, 0.5)
	for x in [-0.08, 0.08]:
		GameUtil.sphere(visual, 0.13, pink, Vector3(x, 0.45, 0), Vector3.ONE, "HeartLobe")
	GameUtil.cone(visual, 0.18, 0.3, pink, Vector3(0, 0.24, 0), Vector3(180, 0, 0), 12, "HeartTip")

func _make_stone() -> void:
	var stone_mat := GameUtil.mat("rock", 0.95)
	var dark := GameUtil.mat("rock_dark", 0.98)
	GameUtil.sphere(visual, 0.22, stone_mat, Vector3(-0.12, 0.16, 0.02), Vector3(1.1, 0.75, 0.9), "StoneA")
	GameUtil.sphere(visual, 0.17, dark, Vector3(0.16, 0.12, -0.06), Vector3(1.0, 0.65, 0.9), "StoneB")
	GameUtil.sphere(visual, 0.12, stone_mat, Vector3(0.02, 0.26, 0.16), Vector3(1.0, 0.8, 1.0), "StoneC")
	GameUtil.sphere(visual, 0.075, GameUtil.mat("gold", 0.5), Vector3(-0.14, 0.35, 0.05), Vector3.ONE, "StoneSpark")

func _make_fiber() -> void:
	var stem_mat := GameUtil.mat("leaf_dark", 0.9)
	var leaf_mat := GameUtil.mat("leaf_light", 0.8)
	for i in 5:
		var a := TAU * float(i) / 5.0
		var h := 0.45 + 0.12 * float(i % 3)
		var stem := GameUtil.cylinder(visual, 0.022, h, stem_mat, Vector3(cos(a) * 0.06, h * 0.5, sin(a) * 0.06), Vector3(5 * sin(a), 0, 4 * cos(a)), 4, "FiberStem")
		GameUtil.sphere(visual, 0.06, leaf_mat, Vector3(cos(a) * 0.18, h + 0.05, sin(a) * 0.18), Vector3(1.2, 0.45, 0.7), "FiberLeaf")
	GameUtil.sphere(visual, 0.14, leaf_mat, Vector3(0, 0.14, 0), Vector3(1.4, 0.55, 1.2), "FiberBase")

func _process(delta: float) -> void:
	if collected:
		return
	phase += delta
	visual.position.y = sin(phase * 2.4) * 0.07 + 0.03
	if kind == Kind.COIN:
		visual.rotation.y += delta * 2.6
	elif kind == Kind.MAP:
		visual.rotation.y += delta * 0.8
	if game != null and game.is_playing() and player != null and not player.dead:
		var d := global_position.distance_to(player.global_position)
		if d < 2.2:
			magnet = true
		if magnet:
			var target := player.global_position + Vector3(0, 0.55, 0)
			global_position = global_position.lerp(target, clampf(delta * 7.0, 0.0, 1.0))
			if d < 0.75:
				_collect()

func _collect() -> void:
	if collected:
		return
	collected = true
	if game:
		game.collect_pickup(self)
	if kind != Kind.MAP:
		var tw := create_tween()
		tw.tween_property(visual, "scale", Vector3.ONE * 1.5, 0.12)
		tw.tween_property(visual, "scale", Vector3.ZERO, 0.18)
		tw.tween_callback(queue_free)
	else:
		var tw := create_tween()
		tw.tween_property(self, "position:y", position.y + 0.8, 0.4)
		tw.parallel().tween_property(visual, "scale", Vector3.ZERO, 0.4)
		tw.tween_callback(queue_free)
