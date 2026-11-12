class_name MinimapView
extends Control

var game: Node
var world: IslandWorld
var player: MilkFrog
var _sand_poly := PackedVector2Array()
var _grass_poly := PackedVector2Array()
var _cache_radius := -1.0
var refresh := 0.0

func setup(p_game: Node, p_world: IslandWorld, p_player: MilkFrog) -> void:
	game = p_game
	world = p_world
	player = p_player
	queue_redraw()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(176, 176)
	set_process(true)

func _process(delta: float) -> void:
	refresh += delta
	if refresh > 0.1:
		refresh = 0.0
		queue_redraw()

func _ensure_polygons() -> void:
	if world == null:
		return
	var r := minf(size.x, size.y) * 0.43
	if absf(_cache_radius - r) < 0.5 and _sand_poly.size() > 0:
		return
	_cache_radius = r
	_sand_poly = PackedVector2Array()
	_grass_poly = PackedVector2Array()
	var segments := 48
	for i in segments:
		var a := TAU * float(i) / segments
		var dir := Vector2(cos(a), sin(a))
		var edge := 0.0
		for step in 46:
			var radius := 44.0 - step * 0.7
			var h := world.height_at(dir.x * radius, dir.y * radius)
			if h > 0.05:
				edge = radius
				break
		if edge <= 0.0:
			edge = 34.0
		_sand_poly.append(size * 0.5 + dir * (edge / 40.0) * r)
		var inner := 1.0
		for step in 40:
			var radius := 36.0 - step * 0.6
			var h := world.height_at(dir.x * radius, dir.y * radius)
			if h > 1.25:
				inner = radius
				break
		_grass_poly.append(size * 0.5 + dir * (inner / 40.0) * r)

func _draw() -> void:
	_ensure_polygons()
	var c := size * 0.5
	var r := minf(size.x, size.y) * 0.43
	# frame and water
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.025, 0.12, 0.14, 0.92)
	bg.border_color = Color(0.92, 0.76, 0.43, 0.5)
	bg.set_border_width_all(2)
	bg.set_corner_radius_all(int(size.x * 0.5))
	draw_style_box(bg, Rect2(Vector2.ZERO, size))
	draw_circle(c, r + 2.0, Color("#1a7f88"))
	draw_circle(c, r - 4.0, Color("#11606d"))
	# grid rings
	for i in 3:
		draw_arc(c, r * (0.3 + i * 0.22), 0, TAU, 40, Color(1, 1, 1, 0.06), 1.0)
	# island
	if _sand_poly.size() > 2:
		draw_colored_polygon(_sand_poly, Color("#e5ca8b"))
		# inner grass scaled a touch
		var gp := PackedVector2Array()
		for p in _grass_poly:
			gp.append(c + (p - c) * 0.92)
		draw_colored_polygon(gp, Color("#6fa552"))
		# path
		var path := PackedVector2Array([
			_to_map(Vector2(1.0, 25.0), r),
			_to_map(Vector2(-1.0, 15.0), r),
			_to_map(Vector2(1.0, 3.0), r),
			_to_map(Vector2(8.0, -10.0), r),
			_to_map(Vector2(10.0, -18.0), r)
		])
		draw_polyline(path, Color(0.96, 0.88, 0.64, 0.45), 2.0, true)
	# markers
	if game:
		for chest in game.chests:
			if not is_instance_valid(chest):
				continue
			var p := _to_map(Vector2(chest.position.x, chest.position.z), r)
			var col := Color("#ffd35c") if not chest.opened else Color(0.5, 0.45, 0.35, 0.5)
			_draw_diamond(p, 4.5, col)
		if game.beacon_node and is_instance_valid(game.beacon_node):
			var bp := _to_map(Vector2(game.beacon_node.position.x, game.beacon_node.position.z), r)
			draw_circle(bp, 5.5, Color("#ff8a42"))
			draw_circle(bp, 2.6, Color("#ffe09a"))
		if game.campfire_node and is_instance_valid(game.campfire_node):
			var cp := _to_map(Vector2(game.campfire_node.position.x, game.campfire_node.position.z), r)
			draw_circle(cp, 4.2, Color("#6ee0b0"))
			draw_circle(cp, 1.8, Color("#fff2c9"))
	# enemies
	for node in get_tree().get_nodes_in_group("enemy"):
		var e := node as Node3D
		if not is_instance_valid(e):
			continue
		if e.get("dead") == true:
			continue
		var ep := _to_map(Vector2(e.global_position.x, e.global_position.z), r)
		draw_circle(ep, 2.3, Color(0.92, 0.25, 0.18, 0.9))
	# player marker triangle
	if player:
		var pp := _to_map(Vector2(player.global_position.x, player.global_position.z), r)
		var forward := Vector2(-sin(player.rotation.y), -cos(player.rotation.y))
		var side := Vector2(-forward.y, forward.x)
		var tri := PackedVector2Array([
			pp + forward * 7.5,
			pp - forward * 3.2 + side * 4.5,
			pp - forward * 3.2 - side * 4.5
		])
		draw_colored_polygon(tri, Color("#fff3c4"))
		draw_polyline(PackedVector2Array([tri[0], tri[1], tri[2], tri[0]]), Color("#193b36"), 1.5)
	# compass
	var n := PackedVector2Array([
		c + Vector2(0, -r + 12),
		c + Vector2(-5, -r + 21),
		c + Vector2(5, -r + 21)
	])
	draw_colored_polygon(n, Color("#f6e3b3"))
	var f := ThemeDB.fallback_font
	draw_string(f, c + Vector2(-4, -r + 34), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1, 1, 1, 0.7))
	draw_arc(c, r + 2.0, 0, TAU, 64, Color(1, 0.85, 0.55, 0.3), 2.0)

func _to_map(p: Vector2, r: float) -> Vector2:
	return size * 0.5 + (p / 40.0) * r

func _draw_diamond(p: Vector2, s: float, col: Color) -> void:
	var pts := PackedVector2Array([
		p + Vector2(0, -s), p + Vector2(s, 0), p + Vector2(0, s), p + Vector2(-s, 0)
	])
	draw_colored_polygon(pts, col)
	draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[3], pts[0]]), Color(0, 0, 0, 0.35), 1.0)
