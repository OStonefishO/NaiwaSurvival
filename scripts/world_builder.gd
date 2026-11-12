class_name IslandWorld
extends Node3D

const SIZE := 110.0
const SEGMENTS := 96
const STEP := SIZE / float(SEGMENTS)

var heights := PackedFloat32Array()
var heights_ready := false
var noise := FastNoiseLite.new()
var prop_noise := FastNoiseLite.new()
var camp_pos := Vector3(1.0, 0.0, 24.0)
var campfire_pos := Vector3(2.0, 0.0, 21.5)
var beacon_pos := Vector3(10.0, 0.0, -18.0)
var dock_pos := Vector3(13.0, 0.0, 31.0)
var shipwreck_pos := Vector3(10.0, 0.0, 17.0)
var ruins_pos := Vector3(-24.0, 0.0, -6.0)
var chest_positions: Array[Vector3] = [
	Vector3(-24.0, 0.0, -4.0),
	Vector3(25.0, 0.0, 6.0),
	Vector3(18.0, 0.0, -13.0),
]
var enemy_spawns: Array[Vector3] = [
	Vector3(-19.0, 0.0, 0.0),
	Vector3(-28.0, 0.0, -8.0),
	Vector3(-17.0, 0.0, -12.0),
	Vector3(23.0, 0.0, 3.0),
	Vector3(28.0, 0.0, 10.0),
	Vector3(15.0, 0.0, -8.0),
	Vector3(5.0, 0.0, 13.0),
	Vector3(-7.0, 0.0, 10.0),
]
var palm_positions: Array[Vector3] = []
var grass_positions: Array[Vector3] = []
var _path_points := [
	Vector2(1.0, 29.0), Vector2(1.0, 22.0), Vector2(-2.0, 14.0),
	Vector2(-4.0, 5.0), Vector2(2.0, -4.0), Vector2(8.0, -11.0),
	Vector2(10.0, -18.0)
]

var _mat_ground: StandardMaterial3D
var _mat_trunk: StandardMaterial3D
var _mat_leaf: StandardMaterial3D
var _mat_leaf_light: StandardMaterial3D
var _mat_wood: StandardMaterial3D
var _mat_wood_dark: StandardMaterial3D
var _mat_stone: StandardMaterial3D
var _mat_cloth: StandardMaterial3D
var _mat_red: StandardMaterial3D
var _mat_bone: StandardMaterial3D
var _mat_blob_shadow: StandardMaterial3D

func build(world_seed: int = 20261109) -> void:
	noise.seed = world_seed
	noise.frequency = 0.052
	noise.fractal_octaves = 3
	noise.fractal_gain = 0.5
	prop_noise.seed = world_seed + 37
	prop_noise.frequency = 0.11
	_mat_ground = StandardMaterial3D.new()
	_mat_ground.vertex_color_use_as_albedo = true
	_mat_ground.vertex_color_is_srgb = true
	_mat_ground.roughness = 0.94
	_mat_ground.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	_mat_ground.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mat_trunk = GameUtil.mat("wood", 0.9)
	_mat_leaf = GameUtil.mat("leaf", 0.88)
	_mat_leaf_light = GameUtil.mat("leaf_light", 0.86)
	_mat_wood = GameUtil.mat("wood", 0.86)
	_mat_wood_dark = GameUtil.mat("wood_dark", 0.9)
	_mat_stone = GameUtil.mat("rock", 0.95)
	_mat_cloth = GameUtil.mat("cloth", 0.95)
	_mat_red = GameUtil.mat("red", 0.9)
	_mat_bone = GameUtil.mat("bone", 0.85)
	_mat_blob_shadow = GameUtil.blob_shadow_material()

	_build_heights()
	_build_terrain()
	_build_water()
	_build_palms()
	_build_shipwreck()
	_build_camp()
	_build_ruins()
	_build_dock()
	_build_rocks_and_shells()
	_build_distant_scenery()
	_build_particles()

func height_at(x: float, z: float) -> float:
	if not heights_ready:
		return 0.0
	var gx := (x + SIZE * 0.5) / STEP
	var gz := (z + SIZE * 0.5) / STEP
	gx = clampf(gx, 0.0, SEGMENTS - 0.001)
	gz = clampf(gz, 0.0, SEGMENTS - 0.001)
	var x0 := int(floor(gx))
	var z0 := int(floor(gz))
	var tx := gx - x0
	var tz := gz - z0
	var h00 := heights[z0 * (SEGMENTS + 1) + x0]
	var h10 := heights[z0 * (SEGMENTS + 1) + x0 + 1]
	var h01 := heights[(z0 + 1) * (SEGMENTS + 1) + x0]
	var h11 := heights[(z0 + 1) * (SEGMENTS + 1) + x0 + 1]
	return lerpf(lerpf(h00, h10, tx), lerpf(h01, h11, tx), tz)

func ground_position(x: float, z: float, offset := 0.0) -> Vector3:
	return Vector3(x, height_at(x, z) + offset, z)

func is_walkable(pos: Vector3) -> bool:
	if pos.x * pos.x + pos.z * pos.z > 37.8 * 37.8:
		return false
	return height_at(pos.x, pos.z) > -0.15

func _raw_height(x: float, z: float) -> float:
	var warp := noise.get_noise_2d(x * 0.75 + 91.0, z * 0.75 - 33.0) * 3.0
	var r := Vector2(x, z).length() + warp
	var shore := 1.0 - smoothstep(31.0, 41.0, r)
	var inland := 1.0 - smoothstep(27.0, 36.0, r)
	var h := -3.1 + 4.7 * shore + 1.05 * inland
	h += noise.get_noise_2d(x * 1.55, z * 1.55) * 0.42 * inland
	h += noise.get_noise_2d(x * 3.7 + 9.0, z * 3.7) * 0.13 * inland
	var hill := 4.15 * exp(-pow(Vector2(x - 10.0, z + 18.0).length() / 8.7, 2.0))
	var ridge := 1.25 * exp(-pow(Vector2(x + 24.0, z + 5.0).length() / 7.0, 2.0))
	var low_dune := 0.55 * exp(-pow(Vector2(x - 24.0, z - 7.0).length() / 6.0, 2.0))
	h += hill + ridge + low_dune
	# gently flatten the starting beach and the boss plateau
	var camp_blend := 1.0 - smoothstep(4.0, 9.0, Vector2(x, z).distance_to(Vector2(2.0, 24.0)))
	h = lerpf(h, 1.08, camp_blend * 0.78)
	var cove_blend := 1.0 - smoothstep(4.0, 11.0, Vector2(x, z).distance_to(Vector2(2.0, 30.0)))
	h = lerpf(h, 0.86, cove_blend * 0.72)
	var top_blend := 1.0 - smoothstep(1.5, 4.2, Vector2(x, z).distance_to(Vector2(10.0, -18.0)))
	h = lerpf(h, 6.42, top_blend * 0.86)
	return h

func _build_heights() -> void:
	heights.resize((SEGMENTS + 1) * (SEGMENTS + 1))
	for z in SEGMENTS + 1:
		for x in SEGMENTS + 1:
			var wx := -SIZE * 0.5 + x * STEP
			var wz := -SIZE * 0.5 + z * STEP
			heights[z * (SEGMENTS + 1) + x] = _raw_height(wx, wz)
	heights_ready = true
	campfire_pos.y = height_at(campfire_pos.x, campfire_pos.z)
	camp_pos.y = height_at(camp_pos.x, camp_pos.z)
	beacon_pos.y = height_at(beacon_pos.x, beacon_pos.z)
	dock_pos.y = height_at(dock_pos.x, dock_pos.z)
	shipwreck_pos.y = height_at(shipwreck_pos.x, shipwreck_pos.z)
	ruins_pos.y = height_at(ruins_pos.x, ruins_pos.z)
	for i in chest_positions.size():
		chest_positions[i].y = height_at(chest_positions[i].x, chest_positions[i].z)
	for i in enemy_spawns.size():
		enemy_spawns[i].y = height_at(enemy_spawns[i].x, enemy_spawns[i].z)

func _face_color(cx: float, cz: float, h: float, slope: float) -> Color:
	var r := Vector2(cx, cz).length()
	var sand := GameUtil.color("sand")
	var grass := GameUtil.color("grass")
	var underwater := h < -0.2
	if underwater:
		return GameUtil.color("wet_sand").darkened(0.22)
	var n1 := noise.get_noise_2d(cx * 2.1, cz * 2.1)
	var n2 := noise.get_noise_2d(cx * 5.3 + 12.0, cz * 5.3)
	var inland := 1.0 - smoothstep(26.0, 34.0, r)
	var grass_t := smoothstep(0.9, 1.8, h) * 0.8 + inland * 0.35 + n1 * 0.12
	grass_t = clampf(grass_t, 0.0, 1.0)
	var base := sand.lerp(grass, grass_t)
	if grass_t > 0.3:
		base = base.lerp(GameUtil.color("grass_dark"), clampf(n2 * 0.4 + 0.4, 0.0, 1.0) * 0.28 * grass_t)
		base = base.lerp(GameUtil.color("grass_light"), clampf(-n1, 0.0, 1.0) * 0.2 * grass_t)
	if slope > 0.85 or h > 4.6:
		base = base.lerp(GameUtil.color("rock"), clampf((slope - 0.7) * 2.4 + (h - 4.6) * 0.35, 0.0, 0.85))
	if h < 0.35:
		base = base.lerp(GameUtil.color("wet_sand"), 0.55)
	# a warm sandy cove around the starting camp
	var cove_d := Vector2(cx - 2.0, cz - 28.0).length()
	var cove := 1.0 - smoothstep(5.5, 12.5, cove_d)
	base = base.lerp(GameUtil.color("sand"), cove * 0.9)
	var wreck_d := Vector2(cx - 10.0, cz - 17.0).length()
	base = base.lerp(GameUtil.color("sand"), (1.0 - smoothstep(5.0, 10.0, wreck_d)) * 0.7)
	var path_d := _distance_to_path(cx, cz)
	if path_d < 2.1 and h > 0.4:
		base = base.lerp(GameUtil.color("sand"), clampf(1.0 - path_d / 2.1, 0.0, 0.85) * 0.72)
	var jitter := noise.get_noise_2d(cx * 11.0, cz * 11.0) * 0.035
	return base.lightened(jitter) if jitter > 0.0 else base.darkened(-jitter)

func _distance_to_path(x: float, z: float) -> float:
	var p := Vector2(x, z)
	var best := 999.0
	for i in _path_points.size() - 1:
		var a: Vector2 = _path_points[i]
		var b: Vector2 = _path_points[i + 1]
		var ab := b - a
		var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.001), 0.0, 1.0)
		best = minf(best, p.distance_to(a + ab * t))
	return best

func _build_terrain() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for z in SEGMENTS:
		for x in SEGMENTS:
			var x0 := -SIZE * 0.5 + x * STEP
			var z0 := -SIZE * 0.5 + z * STEP
			var x1 := x0 + STEP
			var z1 := z0 + STEP
			var h00 := heights[z * (SEGMENTS + 1) + x]
			var h10 := heights[z * (SEGMENTS + 1) + x + 1]
			var h01 := heights[(z + 1) * (SEGMENTS + 1) + x]
			var h11 := heights[(z + 1) * (SEGMENTS + 1) + x + 1]
			var p00 := Vector3(x0, h00, z0)
			var p10 := Vector3(x1, h10, z0)
			var p01 := Vector3(x0, h01, z1)
			var p11 := Vector3(x1, h11, z1)
			var cx := (x0 + x1) * 0.5
			var cz := (z0 + z1) * 0.5
			var h := (h00 + h10 + h01 + h11) * 0.25
			var slope := absf(h10 - h00) / STEP + absf(h01 - h00) / STEP
			var c := _face_color(cx, cz, h, slope)
			# triangles, wound for +Y-facing normals
			_add_tri(st, p00, p01, p11, c)
			_add_tri(st, p00, p11, p10, c)
	st.generate_normals()
	var mesh := st.commit()
	var terrain := MeshInstance3D.new()
	terrain.name = "Terrain"
	terrain.mesh = mesh
	terrain.material_override = _mat_ground
	add_child(terrain)

	var body := StaticBody3D.new()
	body.name = "TerrainBody"
	var col := CollisionShape3D.new()
	var shape := HeightMapShape3D.new()
	shape.map_width = SEGMENTS + 1
	shape.map_depth = SEGMENTS + 1
	shape.map_data = heights
	col.shape = shape
	col.scale = Vector3(STEP, 1.0, STEP)
	body.add_child(col)
	add_child(body)

func _add_tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, color: Color) -> void:
	var n := (b - a).cross(c - a)
	if n.y < 0.0:
		var tmp := b
		b = c
		c = tmp
		n = -n
	n = n.normalized()
	st.set_normal(n); st.set_color(color); st.add_vertex(a)
	st.set_normal(n); st.set_color(color); st.add_vertex(b)
	st.set_normal(n); st.set_color(color); st.add_vertex(c)

func _build_water() -> void:
	var water := MeshInstance3D.new()
	water.name = "Ocean"
	var plane := PlaneMesh.new()
	plane.size = Vector2(320.0, 320.0)
	water.mesh = plane
	water.position.y = -0.28
	var shader := load("res://shaders/water.gdshader")
	var sm := ShaderMaterial.new()
	sm.shader = shader
	sm.set_shader_parameter("shallow_color", Color("#4ed6c1"))
	sm.set_shader_parameter("deep_color", Color("#0a4f68"))
	sm.set_shader_parameter("foam_color", Color("#fff8df"))
	water.material_override = sm
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(water)

# ---------------- vegetation ----------------

func _build_palms() -> void:
	var spots := [
		Vector3(-12, 0, 29), Vector3(-17, 0, 25), Vector3(20, 0, 20),
		Vector3(27, 0, 13), Vector3(30, 0, -2), Vector3(-29, 0, 8),
		Vector3(-31, 0, -12), Vector3(-14, 0, -24), Vector3(2, 0, -29),
		Vector3(17, 0, -26), Vector3(26, 0, -18), Vector3(-4, 0, 32),
		Vector3(-25, 0, 26), Vector3(31, 0, 22), Vector3(-30, 0, -24),
	]
	for i in spots.size():
		var p: Vector3 = spots[i]
		if height_at(p.x, p.z) < 0.6:
			continue
		p.y = height_at(p.x, p.z)
		_make_palm(p, i)
		palm_positions.append(p)

func _make_palm(p: Vector3, variant: int) -> void:
	var root := Node3D.new()
	root.name = "Palm_%d" % variant
	root.position = p
	root.rotation.y = float(variant) * 1.73 + prop_noise.get_noise_2d(p.x, p.z) * 0.8
	var s := 0.86 + fmod(float(variant) * 0.37, 0.35)
	root.scale = Vector3.ONE * s
	add_child(root)
	_add_blob_shadow(root, Vector3(0, 0.04, 0), Vector2(2.7, 2.1))

	var trunk := MeshInstance3D.new()
	trunk.mesh = _palm_trunk_mesh(variant)
	trunk.material_override = _mat_trunk
	root.add_child(trunk)

	var leaves := MeshInstance3D.new()
	leaves.mesh = _palm_leaf_mesh(variant)
	leaves.material_override = _mat_leaf
	root.add_child(leaves)

	var leaves2 := MeshInstance3D.new()
	leaves2.mesh = _palm_leaf_mesh(variant + 4)
	leaves2.material_override = _mat_leaf_light
	leaves2.rotation.y = 0.5
	leaves2.scale = Vector3(0.86, 0.9, 0.86)
	root.add_child(leaves2)

	var coconut_mat := GameUtil.mat("wood_dark", 0.9)
	for j in 3:
		var a := TAU * float(j) / 3.0 + 0.4
		GameUtil.sphere(root, 0.11, coconut_mat, Vector3(cos(a) * 0.18, 2.95, sin(a) * 0.18), Vector3.ONE, "Coconut")

func _palm_trunk_mesh(variant: int) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var seg := 9
	var height := 3.15
	var radius := 0.15
	var bend := 0.28 + 0.1 * sin(float(variant))
	for i in seg:
		var t0 := float(i) / float(seg)
		var t1 := float(i + 1) / float(seg)
		var c0 := Vector3(sin(t0 * 2.3) * bend * t0, t0 * height, cos(t0 * 1.7) * bend * 0.4 * t0)
		var c1 := Vector3(sin(t1 * 2.3) * bend * t1, t1 * height, cos(t1 * 1.7) * bend * 0.4 * t1)
		var r0 := radius * (1.0 - t0 * 0.38)
		var r1 := radius * (1.0 - t1 * 0.38)
		for k in 6:
			var a0 := TAU * float(k) / 6.0
			var a1 := TAU * float(k + 1) / 6.0
			var p00 := c0 + Vector3(cos(a0) * r0, 0, sin(a0) * r0)
			var p01 := c0 + Vector3(cos(a1) * r0, 0, sin(a1) * r0)
			var p10 := c1 + Vector3(cos(a0) * r1, 0, sin(a0) * r1)
			var p11 := c1 + Vector3(cos(a1) * r1, 0, sin(a1) * r1)
			var col := GameUtil.color("wood").lerp(GameUtil.color("wood_light"), fmod(float(i + k) * 0.17, 1.0) * 0.2)
			_add_tri(st, p00, p10, p11, col)
			_add_tri(st, p00, p11, p01, col)
	st.generate_normals()
	return st.commit()

func _palm_leaf_mesh(variant: int) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var fronds := 7
	for f in fronds:
		var base_angle := TAU * float(f) / float(fronds) + 0.24 * float(variant)
		var length := 2.25 + 0.35 * sin(float(f) * 1.9 + float(variant))
		var start := Vector3(sin(base_angle) * 0.18, 3.05 + 0.24 * cos(float(f) * 1.3), cos(base_angle) * 0.18)
		var dir := Vector3(sin(base_angle), 0, cos(base_angle))
		var side := Vector3(dir.z, 0, -dir.x)
		var segments := 4
		for s in segments:
			var t0 := float(s) / float(segments)
			var t1 := float(s + 1) / float(segments)
			var p0 := start + dir * (length * t0) + Vector3(0, -0.95 * t0 * t0 + 0.1 * sin(t0 * PI), 0)
			var p1 := start + dir * (length * t1) + Vector3(0, -0.95 * t1 * t1 + 0.1 * sin(t1 * PI), 0)
			var w0 := 0.24 * (1.0 - t0) + 0.035
			var w1 := 0.24 * (1.0 - t1) + 0.035
			var a := p0 - side * w0
			var b := p0 + side * w0
			var c := p1 + side * w1
			var d := p1 - side * w1
			var col := GameUtil.color("leaf").lerp(GameUtil.color("leaf_light"), 0.25 + 0.3 * t0)
			_add_tri(st, a, d, c, col)
			_add_tri(st, a, c, b, col)
	st.generate_normals()
	return st.commit()

# ---------------- props ----------------

func _add_blob_shadow(parent: Node, pos: Vector3, size: Vector2) -> void:
	var quad := QuadMesh.new()
	quad.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = quad
	mi.rotation_degrees.x = -90
	mi.position = pos
	mi.material_override = _mat_blob_shadow
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)

func _build_shipwreck() -> void:
	var root := Node3D.new()
	root.name = "Shipwreck"
	root.position = shipwreck_pos
	root.rotation.y = deg_to_rad(-28.0)
	add_child(root)
	_add_blob_shadow(root, Vector3(0, 0.08, 0.6), Vector2(13.0, 10.0))
	var wood_mats := [_mat_wood, _mat_wood_dark, GameUtil.mat("wood_light", 0.86)]
	for i in range(-4, 5):
		if i == -1 or i == 3:
			continue
		var t := absf(float(i)) / 4.0
		var w := 4.6 * sqrt(maxf(0.0, 1.0 - t * t)) + 0.8
		var p := Vector3(float(i) * 0.12, 0.61 + 0.06 * sin(float(i) * 1.3), float(i) * 1.02)
		GameUtil.box(root, Vector3(w, 0.22, 0.98), wood_mats[absi(i) % 3], p, Vector3(3.0 * sin(float(i) * 0.8), 2.0 * i, 2.0 * sin(float(i))), "WreckPlank")
	for i in range(-4, 5):
		var t := absf(float(i)) / 4.0
		var w := 2.3 * sqrt(maxf(0.0, 1.0 - t * t)) + 0.4
		for side in [-1, 1]:
			GameUtil.box(root, Vector3(0.18, 1.15, 0.14), _mat_wood_dark, Vector3(w * side, 0.95, float(i) * 1.02 - 0.2), Vector3(0, 0, 26.0 * side), "WreckRib")
	for side in [-1, 1]:
		for i in range(3):
			GameUtil.box(root, Vector3(0.12, 0.9, 3.6), _mat_wood, Vector3(side * (1.3 + i * 0.45), 0.5, 1.0), Vector3(0, 0, 30.0 * side), "WreckSide")
	GameUtil.box(root, Vector3(0.16, 1.2, 2.2), _mat_wood, Vector3(0.7, 0.85, 4.2), Vector3(-8, 0, 38), "BowPlank")
	GameUtil.box(root, Vector3(0.16, 1.2, 2.2), _mat_wood, Vector3(-0.7, 0.85, 4.2), Vector3(-8, 0, -38), "BowPlank")
	GameUtil.box(root, Vector3(1.5, 0.3, 1.0), _mat_wood_dark, Vector3(0, 0.8, 5.2), Vector3.ZERO, "BowTip")
	GameUtil.box(root, Vector3(0.18, 1.3, 1.7), _mat_wood, Vector3(1.5, 1.0, -4.5), Vector3(0, 0, -48), "SternBroken")
	GameUtil.cylinder(root, 0.16, 8.0, _mat_wood_dark, Vector3(0.5, 3.8, -0.6), Vector3(0, 0, 12), 8, "Mast")
	GameUtil.cylinder(root, 0.10, 5.2, _mat_wood, Vector3(0.2, 6.4, -0.6), Vector3(90, 0, 12), 8, "Yard")
	var sail := MeshInstance3D.new()
	sail.mesh = _wreck_sail_mesh()
	sail.position = Vector3(0.0, 1.55, -0.8)
	sail.rotation_degrees = Vector3(0, 8, 0)
	var sail_mat := StandardMaterial3D.new()
	sail_mat.albedo_color = Color("#b9a67d")
	sail_mat.roughness = 1.0
	sail_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	sail.material_override = sail_mat
	root.add_child(sail)
	var rope_mat := GameUtil.mat("wood_dark", 0.95)
	GameUtil.cylinder_between(root, Vector3(0.5, 7.4, -0.6), Vector3(2.5, 1.2, 2.0), 0.025, rope_mat, 5, "RopeA")
	GameUtil.cylinder_between(root, Vector3(0.5, 7.4, -0.6), Vector3(-2.0, 1.0, -2.0), 0.025, rope_mat, 5, "RopeB")
	for i in 2:
		GameUtil.cylinder(root, 0.18, 1.4, GameUtil.mat("iron", 0.4, 0.5), Vector3(-2.6, 0.7, -0.6 + i * 1.8), Vector3(0, 0, 90), 10, "Cannon")
		GameUtil.cylinder(root, 0.22, 0.25, GameUtil.mat("black", 0.6), Vector3(-3.3, 0.7, -0.6 + i * 1.8), Vector3(0, 0, 90), 10, "CannonMouth")
	var wheel := Node3D.new()
	wheel.position = Vector3(1.8, 1.1, 1.0)
	wheel.rotation_degrees = Vector3(18, 0, 16)
	root.add_child(wheel)
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.35
	torus.outer_radius = 0.47
	torus.rings = 20
	torus.ring_segments = 6
	ring.mesh = torus
	ring.material_override = _mat_wood_dark
	wheel.add_child(ring)
	for i in 6:
		GameUtil.cylinder(wheel, 0.03, 0.9, _mat_wood, Vector3.ZERO, Vector3(0, 0, i * 30.0), 5, "Spoke")
	GameUtil.sphere(root, 0.3, _mat_bone, Vector3(0.9, 1.25, 4.8), Vector3(1.0, 1.1, 0.8), "Figurehead")
	_make_crate(root, Vector3(2.8, 0.0, 2.2), 0.72)
	_make_crate(root, Vector3(3.6, 0.0, 1.1), 0.5)
	_make_barrel(root, Vector3(-3.2, 0.0, 2.2), 0.58)
	_make_barrel(root, Vector3(2.6, 0.2, 3.6), 0.44)
	var gold := GameUtil.mat("gold", 0.3, 0.7, 0.2)
	for i in 8:
		GameUtil.cylinder(root, 0.08, 0.03, gold, Vector3(1.2 + float(i % 4) * 0.18, 0.06, 1.0 + float(i / 4) * 0.22), Vector3.ZERO, 10, "Coin")

func _wreck_sail_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var cols := 6
	var rows := 7
	var grid := []
	for r in rows:
		var row := []
		for c in cols:
			var x := (float(c) / float(cols - 1) - 0.5) * 4.6
			var z := (float(r) / float(rows - 1) - 0.5) * 5.4
			var y := -0.35 * absf(x) * 0.3 + sin(float(r) * 1.2 + float(c) * 0.8) * 0.12
			row.append(Vector3(x, y, z))
		grid.append(row)
	for r in rows - 1:
		for c in cols - 1:
			if (r == 2 and c == 3) or (r == 4 and c == 1) or (r == 5 and c == 4):
				continue
			var a: Vector3 = grid[r][c]
			var b: Vector3 = grid[r][c + 1]
			var cc: Vector3 = grid[r + 1][c + 1]
			var d: Vector3 = grid[r + 1][c]
			var col := Color("#d9c6a0").lerp(Color("#b8a47f"), fmod(float(r + c) * 0.13, 0.25))
			_add_tri(st, a, d, cc, col)
			_add_tri(st, a, cc, b, col)
	st.generate_normals()
	return st.commit()

func _build_camp() -> void:
	var root := Node3D.new()
	root.name = "PirateCamp"
	root.position = camp_pos
	add_child(root)
	# two canvas tents
	_make_tent(root, Vector3(-4.0, 0.0, 1.2), deg_to_rad(10), Color("#d9c49a"))
	_make_tent(root, Vector3(-1.8, 0.0, 3.8), deg_to_rad(-24), Color("#cbb284"))
	# crates, barrels, chests and a banner
	_make_crate(root, Vector3(-1.0, 0.0, -1.0), 0.65)
	_make_crate(root, Vector3(-1.5, 0.0, -0.2), 0.48)
	_make_barrel(root, Vector3(-2.7, 0.0, -1.4), 0.6)
	_make_barrel(root, Vector3(3.6, 0.0, -0.8), 0.48)
	_make_pallet(root, Vector3(4.3, 0.0, 1.4))
	# campfire stones/logs are provided by CampfireSite
	# banner pole with skull flag
	GameUtil.cylinder(root, 0.06, 4.1, _mat_wood_dark, Vector3(5.6, 2.05, -3.2), Vector3.ZERO, 6, "BannerPole")
	var flag := GameUtil.quad(root, Vector2(1.5, 1.0), _mat_red, Vector3(6.4, 3.45, -3.2), Vector3(0, 0, 0), "Flag")
	flag.material_override = GameUtil.transparent_mat(Color("#9f2f28"))
	var skull := GameUtil.sphere(root, 0.19, _mat_bone, Vector3(6.4, 3.55, -3.12), Vector3(1.0, 1.2, 0.1), "Skull")
	skull.rotation_degrees.y = 0
	GameUtil.sphere(root, 0.05, GameUtil.mat("black", 0.8), Vector3(6.32, 3.58, -3.04), Vector3.ONE, "SkullEye1")
	GameUtil.sphere(root, 0.05, GameUtil.mat("black", 0.8), Vector3(6.48, 3.58, -3.04), Vector3.ONE, "SkullEye2")
	# lantern
	GameUtil.sphere(root, 0.14, GameUtil.mat("gold", 0.3, 0.4, 1.5), Vector3(0.2, 1.2, -2.4), Vector3.ONE, "Lantern")
	# hammock between palms
	GameUtil.cylinder_between(root, Vector3(-7.0, 1.8, -2.0), Vector3(-4.0, 1.5, -4.0), 0.05, _mat_cloth, 6, "HammockRope")
	_make_camp_sign(root, Vector3(-6.8, 0.0, 3.2))

func _make_camp_sign(root: Node, pos: Vector3) -> void:
	var sign_root := Node3D.new()
	sign_root.position = pos
	sign_root.rotation.y = deg_to_rad(-12)
	root.add_child(sign_root)
	GameUtil.cylinder(sign_root, 0.08, 2.3, _mat_wood_dark, Vector3(-0.85, 1.15, 0), Vector3.ZERO, 6, "SignPost")
	GameUtil.cylinder(sign_root, 0.08, 2.3, _mat_wood_dark, Vector3(0.85, 1.15, 0), Vector3.ZERO, 6, "SignPost2")
	GameUtil.box(sign_root, Vector3(2.3, 0.85, 0.14), _mat_wood, Vector3(0, 1.75, 0), Vector3(0, 0, 2.0), "SignBoard")
	GameUtil.box(sign_root, Vector3(2.05, 0.65, 0.05), GameUtil.raw_mat(Color("#c39b62"), 0.9), Vector3(0, 1.75, 0.10), Vector3(0, 0, 2.0), "SignFace")
	var label := Label3D.new()
	label.text = "诅 咒 海 盗 湾"
	label.font = load("res://assets/fonts/NotoSansSC-Regular.ttf")
	label.font_size = 58
	label.pixel_size = 0.0034
	label.modulate = Color("#4b2e18")
	label.outline_modulate = Color("#4b2e18")
	label.outline_size = 0
	label.position = Vector3(0, 1.78, 0.14)
	label.rotation_degrees = Vector3(0, 0, 2.0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sign_root.add_child(label)
	var sub := Label3D.new()
	sub.text = "营地  ·  信号火 ↑"
	sub.font = load("res://assets/fonts/NotoSansSC-Regular.ttf")
	sub.font_size = 30
	sub.pixel_size = 0.0028
	sub.modulate = Color("#6c4b2b")
	sub.outline_size = 0
	sub.position = Vector3(0, 1.38, 0.14)
	sub.rotation_degrees = Vector3(0, 0, 2.0)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sign_root.add_child(sub)

func _make_tent(parent: Node, pos: Vector3, yaw: float, cloth_color: Color) -> void:
	var root := Node3D.new()
	root.position = pos
	root.rotation.y = yaw
	parent.add_child(root)
	_add_blob_shadow(root, Vector3(0, 0.05, 0), Vector2(4.4, 3.5))
	var cloth := GameUtil.raw_mat(cloth_color, 0.96)
	# pyramid roof from a low-poly cone with 4 sides gives a tent-like silhouette
	var roof := GameUtil.cone(root, 1.7, 1.3, cloth, Vector3(0, 1.3, 0), Vector3.ZERO, 4, "TentRoof")
	roof.rotation_degrees.y = 45
	# lower skirt
	GameUtil.box(root, Vector3(2.2, 0.8, 0.08), cloth, Vector3(0, 0.45, 1.25), Vector3(-18, 0, 0), "TentBack")
	for x in [-1.18, 1.18]:
		GameUtil.cylinder(root, 0.05, 2.1, _mat_wood_dark, Vector3(x, 1.05, 1.35), Vector3.ZERO, 5, "TentPole")
	var entrance := GameUtil.quad(root, Vector2(1.2, 1.2), GameUtil.raw_mat(Color(0.09, 0.07, 0.05), 0.95), Vector3(0, 0.6, 1.21), Vector3.ZERO, "TentEntrance")
	entrance.material_override = GameUtil.raw_mat(Color(0.09, 0.07, 0.05), 0.95)
	# little pirate pennant
	GameUtil.cylinder(root, 0.025, 1.5, _mat_wood_dark, Vector3(0, 2.3, 0), Vector3.ZERO, 5, "TentFlagPole")
	var flag := GameUtil.quad(root, Vector2(0.75, 0.42), GameUtil.raw_mat(Color("#a3332b"), 0.85), Vector3(0.38, 2.78, 0), Vector3(0, 0, 0), "TentFlag")
	var skull := GameUtil.sphere(root, 0.09, _mat_bone, Vector3(0.38, 2.78, 0.03), Vector3(1.0, 1.1, 0.15), "TentSkull")
	skull.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func _make_crate(parent: Node, pos: Vector3, s: float) -> void:
	var root := Node3D.new()
	root.position = pos
	parent.add_child(root)
	_add_blob_shadow(root, Vector3(0, 0.04, 0), Vector2(s * 2.0, s * 1.6))
	GameUtil.box(root, Vector3(s, s, s), _mat_wood, Vector3(0, s * 0.5, 0), Vector3.ZERO, "Crate")
	GameUtil.box(root, Vector3(s * 1.02, 0.07, s * 0.16), _mat_wood_dark, Vector3(0, s * 0.52, s * 0.5), Vector3.ZERO, "CrateBand")
	GameUtil.box(root, Vector3(s * 0.16, 0.07, s * 1.02), _mat_wood_dark, Vector3(s * 0.5, s * 0.52, 0), Vector3.ZERO, "CrateBand2")

func _make_barrel(parent: Node, pos: Vector3, s: float) -> void:
	var root := Node3D.new()
	root.position = pos
	parent.add_child(root)
	_add_blob_shadow(root, Vector3(0, 0.04, 0), Vector2(s * 1.8, s * 1.5))
	GameUtil.cylinder(root, s * 0.5, s, _mat_wood, Vector3(0, s * 0.5, 0), Vector3.ZERO, 12, "Barrel")
	GameUtil.cylinder(root, s * 0.54, 0.08, _mat_wood_dark, Vector3(0, s * 0.28, 0), Vector3.ZERO, 12, "Hoop1")
	GameUtil.cylinder(root, s * 0.54, 0.08, _mat_wood_dark, Vector3(0, s * 0.72, 0), Vector3.ZERO, 12, "Hoop2")

func _make_pallet(parent: Node, pos: Vector3) -> void:
	for i in 4:
		GameUtil.box(parent, Vector3(1.7, 0.09, 0.24), _mat_wood, pos + Vector3(0, 0.05 + i * 0.1, i * 0.05), Vector3(0, i * 3.0, 0), "PalletPlank")

func _build_ruins() -> void:
	var root := Node3D.new()
	root.name = "SunkenRuins"
	root.position = ruins_pos
	root.rotation.y = deg_to_rad(18)
	add_child(root)
	# circular stone platform
	for i in 8:
		var a := TAU * float(i) / 8.0
		GameUtil.box(root, Vector3(2.2, 0.32, 0.9), _mat_stone, Vector3(cos(a) * 4.2, 0.16, sin(a) * 4.2), Vector3(0, -a * 57.3, 0), "RuinStep")
	# broken pillars
	for i in 6:
		var a := TAU * float(i) / 6.0 + 0.3
		var h := 3.2 if i % 2 == 0 else 1.8
		var p := Vector3(cos(a) * 3.3, 0, sin(a) * 3.3)
		GameUtil.cylinder(root, 0.45, h, _mat_stone, p + Vector3(0, h * 0.5, 0), Vector3(0, -a * 57.3, 3 if i % 3 == 0 else 0), 8, "Pillar")
		GameUtil.box(root, Vector3(1.0, 0.25, 1.0), _mat_stone, p + Vector3(0, h + 0.1, 0), Vector3(0, i * 20, 0), "Cap")
	# fallen lintel
	GameUtil.box(root, Vector3(4.0, 0.55, 0.8), _mat_stone, Vector3(0, 0.35, -4.6), Vector3(0, 23, 8), "Lintel")
	# moss
	for i in 10:
		var a := TAU * float(i) / 10.0
		GameUtil.sphere(root, 0.18, GameUtil.mat("grass_dark", 0.95), Vector3(cos(a) * 3.3, 0.35, sin(a) * 3.3), Vector3(1.4, 0.45, 1.2), "Moss")

func _build_dock() -> void:
	var root := Node3D.new()
	root.name = "OldDock"
	root.position = Vector3(dock_pos.x, 0.0, dock_pos.z)
	root.rotation.y = deg_to_rad(-12)
	add_child(root)
	_add_blob_shadow(root, Vector3(0, 0.07, -1.4), Vector2(4.0, 10.0))
	var deck_y := 0.85
	for i in 9:
		GameUtil.box(root, Vector3(2.4, 0.16, 0.7), _mat_wood, Vector3(0, deck_y, -i * 0.8 + 2.0), Vector3(0, 0, 0), "DockPlank")
	for i in 4:
		GameUtil.cylinder(root, 0.12, 2.4, _mat_wood_dark, Vector3(-1.2 if i % 2 == 0 else 1.2, -0.3, -i * 2.4 + 1.0), Vector3.ZERO, 6, "DockPost")
	# rowboat
	var boat := Node3D.new()
	boat.position = Vector3(3.5, -0.1, -4.0)
	boat.rotation.y = 0.3
	root.add_child(boat)
	var hull := MeshInstance3D.new()
	hull.mesh = _boat_mesh()
	hull.material_override = _mat_wood
	boat.add_child(hull)
	GameUtil.box(boat, Vector3(1.0, 0.08, 0.28), _mat_wood_dark, Vector3(0, 0.2, 0), Vector3.ZERO, "BoatSeat")
	GameUtil.cylinder_between(boat, Vector3(0.4, 0.3, -0.8), Vector3(1.2, 0.45, -1.3), 0.04, _mat_wood_dark, 5, "Oar")

func _boat_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var sections := [Vector3(0.0, 0.05, -1.9), Vector3(0.55, 0.3, -1.2), Vector3(0.8, 0.35, 0.0),
		Vector3(0.55, 0.3, 1.2), Vector3(0.0, 0.05, 1.9)]
	for i in sections.size() - 1:
		var a: Vector3 = sections[i]
		var b: Vector3 = sections[i + 1]
		for k in 5:
			var a0 := lerpf(-PI * 0.5, PI * 0.5, float(k) / 5.0)
			var a1 := lerpf(-PI * 0.5, PI * 0.5, float(k + 1) / 5.0)
			var p00 := a + Vector3(sin(a0) * a.x, cos(a0) * 0.3, 0)
			var p01 := a + Vector3(sin(a1) * a.x, cos(a1) * 0.3, 0)
			var p10 := b + Vector3(sin(a0) * b.x, cos(a0) * 0.3, 0)
			var p11 := b + Vector3(sin(a1) * b.x, cos(a1) * 0.3, 0)
			var col := GameUtil.color("wood").lerp(GameUtil.color("wood_dark"), 0.2)
			_add_tri(st, p00, p10, p11, col)
			_add_tri(st, p00, p11, p01, col)
	st.generate_normals()
	return st.commit()

func _build_rocks_and_shells() -> void:
	var rock_mesh := SphereMesh.new()
	rock_mesh.radial_segments = 7
	rock_mesh.rings = 4
	rock_mesh.radius = 1.0
	rock_mesh.height = 1.5
	for i in 28:
		var a := fmod(float(i) * 2.399, TAU)
		var r := 12.0 + fmod(float(i) * 7.3, 23.0)
		var x := cos(a) * r
		var z := sin(a) * r
		var y := height_at(x, z)
		if y < -0.2:
			continue
		var s := 0.25 + fmod(float(i) * 0.37, 0.85)
		var mi := MeshInstance3D.new()
		mi.mesh = rock_mesh
		mi.material_override = _mat_stone if i % 4 != 0 else GameUtil.mat("rock_dark", 0.95)
		mi.position = Vector3(x, y + s * 0.2, z)
		mi.scale = Vector3(s * (0.8 + fmod(float(i), 3.0) * 0.2), s * 0.65, s)
		mi.rotation.y = a * 2.0
		mi.rotation.z = 0.1 * sin(float(i))
		add_child(mi)
		_add_blob_shadow(self, Vector3(x, y + 0.05, z), Vector2(s * 2.2, s * 1.7))
	# shells and starfish along the beach
	var shell_mat := GameUtil.raw_mat(Color("#f2d5c0"), 0.65)
	var pink_mat := GameUtil.raw_mat(Color("#e8a58e"), 0.7)
	for i in 24:
		var a := fmod(float(i) * 2.17 + 0.4, TAU)
		var r := 29.0 + fmod(float(i) * 2.3, 7.0)
		var x := cos(a) * r
		var z := sin(a) * r
		var y := height_at(x, z)
		if y < 0.1:
			continue
		if i % 4 == 0:
			# starfish
			for k in 5:
				var ba := TAU * float(k) / 5.0
				GameUtil.box(self, Vector3(0.30, 0.035, 0.10), pink_mat, Vector3(x + cos(ba) * 0.12, y + 0.04, z + sin(ba) * 0.12), Vector3(0, -ba * 57.3, 0), "StarfishArm")
		else:
			GameUtil.sphere(self, 0.10 + 0.04 * (i % 3), shell_mat, Vector3(x, y + 0.06, z), Vector3(1.2, 0.35, 1.0), "Shell")
	# grass tufts in the interior
	var blade_mesh := _blade_mesh()
	for i in 120:
		var a := fmod(float(i) * 2.819, TAU)
		var r := 7.0 + fmod(float(i) * 5.1, 23.0)
		var x := cos(a) * r
		var z := sin(a) * r
		var y := height_at(x, z)
		if y < 1.0:
			continue
		var mi := MeshInstance3D.new()
		mi.mesh = blade_mesh
		mi.material_override = GameUtil.mat("grass_light", 0.95) if i % 2 == 0 else GameUtil.mat("grass_dark", 0.95)
		mi.position = Vector3(x, y, z)
		mi.rotation.y = a * 3.0
		mi.scale = Vector3.ONE * (0.8 + fmod(float(i) * 0.37, 0.75))
		add_child(mi)
	# tiny tropical flowers
	var petal_colors := [Color("#f4a6a0"), Color("#f6d46b"), Color("#c49ddb"), Color("#f7efe0")]
	for i in 24:
		var a := fmod(float(i) * 2.399 + 0.7, TAU)
		var r := 10.0 + fmod(float(i) * 4.7, 19.0)
		var x := cos(a) * r
		var z := sin(a) * r
		var y := height_at(x, z)
		if y < 1.2:
			continue
		var stem := GameUtil.cylinder(self, 0.015, 0.34, GameUtil.mat("grass_dark", 0.9), Vector3(x, y + 0.17, z), Vector3.ZERO, 4, "FlowerStem")
		stem.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var col: Color = petal_colors[i % petal_colors.size()]
		GameUtil.sphere(self, 0.07, GameUtil.raw_mat(col, 0.7), Vector3(x, y + 0.36, z), Vector3(1.1, 0.35, 1.1), "Flower")
		GameUtil.sphere(self, 0.03, GameUtil.mat("gold", 0.5), Vector3(x, y + 0.39, z), Vector3.ONE, "FlowerHeart")
	# driftwood along the tide line
	for i in 7:
		var a := fmod(float(i) * 2.01 + 1.2, TAU)
		var r := 31.0 + fmod(float(i) * 2.2, 5.0)
		var x := cos(a) * r
		var z := sin(a) * r
		var y := height_at(x, z)
		if y < 0.1:
			continue
		var drift := GameUtil.cylinder(self, 0.09, 1.3, _mat_wood_dark, Vector3(x, y + 0.12, z), Vector3(0, a * 57.3, 90), 5, "Driftwood")
		drift.rotation.z = 0.15

func _blade_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 4:
		var a := TAU * float(i) / 4.0
		var dir := Vector3(cos(a), 0, sin(a))
		var side := Vector3(-dir.z, 0, dir.x)
		var base := dir * 0.06
		var tip := dir * (0.18 + 0.08 * float(i % 2)) + Vector3(0, 0.5 + 0.12 * float(i % 3), 0)
		_add_tri(st, base - side * 0.05, base + side * 0.05, tip, Color("#5f9644"))
	st.generate_normals()
	return st.commit()

func _build_distant_scenery() -> void:
	# distant islands, deliberately simple silhouettes in the haze
	for i in 4:
		var a := 0.7 + i * 1.55
		var r := 115.0 + i * 17.0
		var island := Node3D.new()
		island.position = Vector3(cos(a) * r, -2.0, sin(a) * r)
		add_child(island)
		var mesh := SphereMesh.new()
		mesh.radius = 1.0
		mesh.radial_segments = 8
		mesh.rings = 4
		mesh.height = 2.0
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.scale = Vector3(18.0 + i * 3.0, 3.0 + i, 10.0 + i * 2.0)
		mi.material_override = GameUtil.raw_mat(Color("#386c59"), 0.95)
		island.add_child(mi)
		for j in 2:
			var rock := MeshInstance3D.new()
			rock.mesh = mesh
			rock.scale = Vector3(3.0, 5.0 + j, 3.0)
			rock.position = Vector3(-6.0 + j * 12.0, 3.0, 0.0)
			rock.material_override = GameUtil.raw_mat(Color("#2e5b4b"), 0.95)
			island.add_child(rock)
	# a distant galleon silhouette on the horizon
	var ship := Node3D.new()
	ship.position = Vector3(-52.0, -0.3, -66.0)
	ship.rotation.y = 0.5
	add_child(ship)
	var dark := GameUtil.raw_mat(Color("#1c3b43"), 0.9)
	GameUtil.box(ship, Vector3(10.0, 2.3, 3.5), dark, Vector3(0, 1.1, 0), Vector3.ZERO, "DistantHull")
	GameUtil.cylinder(ship, 0.12, 9.0, dark, Vector3(-2.0, 5.0, 0), Vector3.ZERO, 5, "DistantMast")
	GameUtil.cylinder(ship, 0.12, 7.0, dark, Vector3(2.5, 4.2, 0), Vector3.ZERO, 5, "DistantMast2")
	GameUtil.quad(ship, Vector2(6.0, 3.2), dark, Vector3(-2.0, 6.2, 0), Vector3.ZERO, "DistantSail")

func _build_particles() -> void:
	var pollen := CPUParticles3D.new()
	pollen.name = "Pollen"
	pollen.amount = 36
	pollen.lifetime = 14.0
	pollen.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	pollen.emission_box_extents = Vector3(30.0, 6.0, 30.0)
	pollen.position = Vector3(0.0, 5.0, 0.0)
	pollen.direction = Vector3(0.3, 1.0, 0.1)
	pollen.spread = 45.0
	pollen.gravity = Vector3(0.03, -0.02, 0.02)
	pollen.initial_velocity_min = 0.08
	pollen.initial_velocity_max = 0.25
	pollen.scale_amount_min = 0.025
	pollen.scale_amount_max = 0.06
	pollen.color = Color("#ffe9a8")
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	pollen.mesh = quad
	var pmat := GameUtil.raw_mat(Color("#ffe9a8"), 0.5, 0.0, 0.8, true)
	pmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	pmat.albedo_texture = GameUtil.particle_texture()
	pmat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	pollen.material_override = pmat
	add_child(pollen)
