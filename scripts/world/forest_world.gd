class_name ForestWorld
extends Node3D

const WORLD_SIZE := 180.0
const SEGMENTS := 96
const CELL_SIZE := WORLD_SIZE / SEGMENTS
const CAMP_CENTER := Vector3(0, 0, 0)
const SPAWN_POS := Vector3(0, 0, 14)
const GROVE_CENTER := Vector3(0, 0, -58)
const BOSS_POS := Vector3(0, 0, -66)

var game: Node
var player: NaifrogPlayer
var world_size := WORLD_SIZE
var heightmap := PackedFloat32Array()
var resource_nodes: Array[ResourceNode] = []
var enemy_spawns: Array[Vector3] = []
var resource_root: Node3D
var building_root: Node3D
var prop_root: Node3D
var terrain_body: StaticBody3D
var _noise: FastNoiseLite
var _rng := RandomNumberGenerator.new()
var _initialized := false

func setup(p_game: Node, p_player: NaifrogPlayer) -> void:
	game = p_game
	player = p_player

func build() -> void:
	_rng.seed = 20261112
	_noise = FastNoiseLite.new()
	_noise.seed = 20261112
	_noise.frequency = 0.018
	_noise.fractal_octaves = 3
	_generate_heightmap()
	_build_terrain()
	resource_root = Node3D.new(); resource_root.name = "Resources"; add_child(resource_root)
	building_root = Node3D.new(); building_root.name = "Buildings"; add_child(building_root)
	prop_root = Node3D.new(); prop_root.name = "Props"; add_child(prop_root)
	_build_grass()
	_build_undergrowth()
	_build_camp()
	_build_giant_grove()
	_scatter_resources()
	_build_enemy_spawns()
	_initialized = true

func _generate_heightmap() -> void:
	var n := SEGMENTS + 1
	heightmap.resize(n * n)
	for j in n:
		for i in n:
			var x := -WORLD_SIZE * 0.5 + i * CELL_SIZE
			var z := -WORLD_SIZE * 0.5 + j * CELL_SIZE
			var h := _noise.get_noise_2d(x, z) * 4.5
			var d := Vector2(x, z).length()
			h *= smoothstep(8.0, 22.0, d)
			var g := Vector2(x - GROVE_CENTER.x, z - GROVE_CENTER.z).length()
			h *= smoothstep(13.0, 30.0, g)
			# gentle ridge at the edge; no invisible walls
			var edge := maxf(absf(x), absf(z))
			if edge > WORLD_SIZE * 0.40:
				h += smoothstep(WORLD_SIZE * 0.40, WORLD_SIZE * 0.50, edge) * 5.5
			heightmap[j * n + i] = h

func _build_terrain() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for j in SEGMENTS:
		for i in SEGMENTS:
			var p00 := _vertex(i, j)
			var p10 := _vertex(i + 1, j)
			var p01 := _vertex(i, j + 1)
			var p11 := _vertex(i + 1, j + 1)
			_add_tri(st, p00, p01, p10)
			_add_tri(st, p10, p01, p11)
	st.generate_normals()
	var mesh := st.commit()
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.96
	mat.metallic = 0.0
	mesh.surface_set_material(0, mat)
	var mi := MeshInstance3D.new()
	mi.name = "Terrain"
	mi.mesh = mesh
	add_child(mi)
	terrain_body = StaticBody3D.new()
	terrain_body.name = "TerrainCollision"
	terrain_body.collision_layer = 1
	var shape := CollisionShape3D.new()
	var concave := mesh.create_trimesh_shape()
	concave.backface_collision = true
	shape.shape = concave
	terrain_body.add_child(shape)
	add_child(terrain_body)

func _vertex(i: int, j: int) -> Vector3:
	var x := -WORLD_SIZE * 0.5 + i * CELL_SIZE
	var z := -WORLD_SIZE * 0.5 + j * CELL_SIZE
	return Vector3(x, heightmap[j * (SEGMENTS + 1) + i], z)

func _add_tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	for p in [a, b, c]:
		st.set_color(_ground_color(p))
		st.add_vertex(p)

func _ground_color(p: Vector3) -> Color:
	var base := Color("#5d8b49").lerp(Color("#3f6d3f"), 0.45 + 0.3 * sin(p.x * 0.12 + p.z * 0.08))
	var d_camp := Vector2(p.x, p.z).length()
	if d_camp < 8.0:
		base = base.lerp(Color("#a4875a"), 0.70)
	elif d_camp < 14.0:
		base = base.lerp(Color("#8d7b50"), 0.25)
	# worn path from the camp toward the mushroom grove
	if absf(p.x) < 2.2 and p.z < 10.0:
		base = base.lerp(Color("#9a8154"), 0.6)
	var d_grove := Vector2(p.x - GROVE_CENTER.x, p.z - GROVE_CENTER.z).length()
	if d_grove < 26.0:
		base = base.lerp(Color("#435f50"), 0.25)
	if p.z < -72.0 or p.z > 76.0 or absf(p.x) > 76.0:
		base = base.lerp(Color("#335b3e"), 0.35)
	return base

func _build_grass() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# a small crossed grass clump, cheap and readable from the top-down camera
	for angle in [0.0, PI * 0.5]:
		var dx := cos(angle) * 0.055
		var dz := sin(angle) * 0.055
		var a := Vector3(-dx, 0, -dz)
		var b := Vector3(dx, 0, dz)
		var c := Vector3(dx, 0.36, dz)
		var d := Vector3(-dx, 0.36, -dz)
		st.set_color(Color("#6b9b4c"))
		st.add_vertex(a); st.add_vertex(b); st.add_vertex(c)
		st.set_color(Color("#8abf64"))
		st.add_vertex(a); st.add_vertex(c); st.add_vertex(d)
	st.generate_normals()
	var mesh := st.commit()
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.roughness = 1.0
	mesh.surface_set_material(0, mat)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = 2400
	var count := 0
	var rng := RandomNumberGenerator.new(); rng.seed = 7788
	for i in 4000:
		if count >= 2400:
			break
		var x := rng.randf_range(-65, 65)
		var z := rng.randf_range(-65, 65)
		if Vector2(x, z).length() < 5.0:
			continue
		if Vector2(x - GROVE_CENTER.x, z - GROVE_CENTER.z).length() < 8.0:
			continue
		var y := height_at(x, z)
		var basis := Basis(Vector3.UP, rng.randf_range(0, TAU)).scaled(Vector3.ONE * rng.randf_range(0.6, 1.2))
		mm.set_instance_transform(count, Transform3D(basis, Vector3(x, y, z)))
		mm.set_instance_color(count, Color("#7fb05b").lerp(Color("#4f8044"), rng.randf()))
		count += 1
	mm.visible_instance_count = count
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "Grass"
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)

func _build_undergrowth() -> void:
	var rng := RandomNumberGenerator.new(); rng.seed = 9137
	# ferns: a few tapered blades radiating from a base
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in 7:
		var a := TAU * float(k) / 7.0
		var bend := 0.18 + 0.08 * (k % 3)
		var tip := Vector3(cos(a) * 0.34, 0.38, sin(a) * 0.34)
		var side := Vector3(-sin(a), 0, cos(a)) * 0.055
		st.set_color(Color("#477a3b")); st.add_vertex(Vector3(0, 0, 0))
		st.set_color(Color("#659b48")); st.add_vertex(side + Vector3(0, 0.05, 0))
		st.set_color(Color("#78a957")); st.add_vertex(tip)
		st.set_color(Color("#477a3b")); st.add_vertex(Vector3(0, 0, 0))
		st.set_color(Color("#78a957")); st.add_vertex(tip)
		st.set_color(Color("#659b48")); st.add_vertex(-side + Vector3(0, 0.05, 0))
		# a second shorter frond leaning outward
		var tip2 := Vector3(cos(a + 0.2) * 0.24, 0.20, sin(a + 0.2) * 0.24)
		st.set_color(Color("#5c8f40")); st.add_vertex(Vector3(0, 0, 0))
		st.set_color(Color("#7dad57")); st.add_vertex(side * 0.7)
		st.set_color(Color("#8fbe65")); st.add_vertex(tip2)
	st.generate_normals()
	var fern_mesh := st.commit()
	var fern_mat := StandardMaterial3D.new()
	fern_mat.vertex_color_use_as_albedo = true
	fern_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	fern_mat.roughness = 1.0
	fern_mesh.surface_set_material(0, fern_mat)
	var fmm := MultiMesh.new()
	fmm.transform_format = MultiMesh.TRANSFORM_3D
	fmm.use_colors = true
	fmm.mesh = fern_mesh
	fmm.instance_count = 700
	var fcount := 0
	for i in 1600:
		if fcount >= 700:
			break
		var x := rng.randf_range(-52, 52)
		var z := rng.randf_range(-52, 52)
		if Vector2(x, z).length() < 5.0:
			continue
		if absf(x) < 2.5 and z < 10.0:
			continue
		if Vector2(x - GROVE_CENTER.x, z - GROVE_CENTER.z).length() < 8.0:
			continue
		var y := height_at(x, z)
		var basis := Basis(Vector3.UP, rng.randf_range(0, TAU)).scaled(Vector3.ONE * rng.randf_range(0.6, 1.4))
		fmm.set_instance_transform(fcount, Transform3D(basis, Vector3(x, y, z)))
		fmm.set_instance_color(fcount, Color("#7ea85b").lerp(Color("#4b7d3e"), rng.randf()))
		fcount += 1
	fmm.visible_instance_count = fcount
	var fmi := MultiMeshInstance3D.new()
	fmi.name = "Ferns"
	fmi.multimesh = fmm
	fmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(fmi)

	# wildflowers: tiny stems with colored heads
	var fs := SurfaceTool.new()
	fs.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in 5:
		var a := TAU * float(k) / 5.0
		var c := Vector3(cos(a) * 0.055, 0.24, sin(a) * 0.055)
		fs.set_color(Color("#f4e7b0")); fs.add_vertex(Vector3(0, 0.20, 0))
		fs.set_color(Color("#fff3c8")); fs.add_vertex(c + Vector3(-0.02, -0.02, 0))
		fs.set_color(Color("#e8d58b")); fs.add_vertex(Vector3(cos(a + 0.55) * 0.055, 0.24, sin(a + 0.55) * 0.055))
	fs.set_color(Color("#4e7a3b")); fs.add_vertex(Vector3(-0.012, 0, 0))
	fs.set_color(Color("#4e7a3b")); fs.add_vertex(Vector3(0.012, 0, 0))
	fs.set_color(Color("#659b48")); fs.add_vertex(Vector3(0, 0.22, 0))
	fs.generate_normals()
	var flower_mesh := fs.commit()
	var flower_mat := StandardMaterial3D.new()
	flower_mat.vertex_color_use_as_albedo = true
	flower_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	flower_mat.roughness = 0.85
	flower_mesh.surface_set_material(0, flower_mat)
	var wmm := MultiMesh.new()
	wmm.transform_format = MultiMesh.TRANSFORM_3D
	wmm.use_colors = true
	wmm.mesh = flower_mesh
	wmm.instance_count = 300
	var wcount := 0
	for i in 800:
		if wcount >= 300:
			break
		var x := rng.randf_range(-45, 45)
		var z := rng.randf_range(-45, 45)
		if Vector2(x, z).length() < 4.0:
			continue
		if absf(x) < 2.2 and z < 10.0:
			continue
		var y := height_at(x, z)
		var basis := Basis(Vector3.UP, rng.randf_range(0, TAU)).scaled(Vector3.ONE * rng.randf_range(0.7, 1.25))
		wmm.set_instance_transform(wcount, Transform3D(basis, Vector3(x, y, z)))
		wmm.set_instance_color(wcount, [Color("#f4e7b0"), Color("#f3bbd0"), Color("#b8d9f2"), Color("#f6d16a")][wcount % 4])
		wcount += 1
	wmm.visible_instance_count = wcount
	var wmi := MultiMeshInstance3D.new()
	wmi.name = "Wildflowers"
	wmi.multimesh = wmm
	wmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(wmi)

func height_at(x: float, z: float) -> float:
	if heightmap.is_empty():
		return 0.0
	var fx := clampf((x + WORLD_SIZE * 0.5) / CELL_SIZE, 0.0, SEGMENTS)
	var fz := clampf((z + WORLD_SIZE * 0.5) / CELL_SIZE, 0.0, SEGMENTS)
	var i := mini(SEGMENTS - 1, int(fx))
	var j := mini(SEGMENTS - 1, int(fz))
	var tx := fx - i
	var tz := fz - j
	var n := SEGMENTS + 1
	var h00 := heightmap[j * n + i]
	var h10 := heightmap[j * n + i + 1]
	var h01 := heightmap[(j + 1) * n + i]
	var h11 := heightmap[(j + 1) * n + i + 1]
	return lerpf(lerpf(h00, h10, tx), lerpf(h01, h11, tx), tz)

func is_walkable(pos: Vector3) -> bool:
	return absf(pos.x) < WORLD_SIZE * 0.47 and absf(pos.z) < WORLD_SIZE * 0.47

func _build_camp() -> void:
	var camp := Node3D.new(); camp.name = "AbandonedCamp"; prop_root.add_child(camp)
	var wood := GameUtil.mat("wood"); var dark := GameUtil.mat("wood_dark")
	# broken cart
	GameUtil.box(camp, Vector3(2.4, 0.18, 0.9), wood, Vector3(4.8, 0.75, 4.2), Vector3(0, 0.2, 0), "CartBed")
	GameUtil.box(camp, Vector3(0.12, 1.0, 0.9), dark, Vector3(3.6, 1.15, 4.2), Vector3.ZERO, "CartSide")
	GameUtil.box(camp, Vector3(0.12, 1.0, 0.9), dark, Vector3(6.0, 1.15, 4.2), Vector3.ZERO, "CartSide")
	for x in [4.0, 5.6]:
		var wheel := GameUtil.cylinder(camp, 0.45, 0.16, dark, Vector3(x, 0.47, 3.7), Vector3(90, 0, 0), 12, "Wheel")
	# crates
	for i in 3:
		GameUtil.box(camp, Vector3(0.65, 0.65, 0.65), wood if i % 2 == 0 else dark, Vector3(2.7 + i * 0.75, 0.35, 2.0 + i * 0.1), Vector3(0, 15 * i, 0), "Crate")
	# sign: a small hook for the first goal
	GameUtil.cylinder(camp, 0.08, 1.7, dark, Vector3(-3.0, 0.85, 5.2), Vector3.ZERO, 6, "SignPost")
	GameUtil.box(camp, Vector3(1.8, 0.7, 0.1), wood, Vector3(-3.0, 1.35, 5.2), Vector3(0, -12, 0), "SignBoard")
	# old tent tarp
	GameUtil.box(camp, Vector3(2.8, 0.08, 2.0), GameUtil.raw_mat(Color("#c4b48a"), 0.96), Vector3(-4.2, 1.1, 3.2), Vector3(-18, 0, 0), "Tarp")
	for x in [-5.5, -2.9]:
		GameUtil.cylinder(camp, 0.06, 1.4, dark, Vector3(x, 0.7, 3.2), Vector3.ZERO, 5, "Pole")
	GameUtil.add_blob_shadow(camp, Vector2(8, 6))

func _build_giant_grove() -> void:
	var grove := Node3D.new(); grove.name = "MushroomGrove"; prop_root.add_child(grove)
	for i in 9:
		var a := TAU * float(i) / 9.0 + 0.4
		var p := GROVE_CENTER + Vector3(cos(a) * 17.0, 0, sin(a) * 15.0)
		p.y = height_at(p.x, p.z)
		_build_giant_mushroom(grove, p, 2.6 + (i % 3) * 0.6)
	# ancient tree landmark behind the grove
	var tree_pos := BOSS_POS + Vector3(0, 0, -5)
	tree_pos.y = height_at(tree_pos.x, tree_pos.z)
	GameUtil.cylinder(grove, 2.0, 12.0, GameUtil.mat("bark_dark"), tree_pos + Vector3(0, 6.0, 0), Vector3.ZERO, 10, "AncientTrunk")
	GameUtil.sphere(grove, 5.2, GameUtil.mat("leaf_dark"), tree_pos + Vector3(0, 12.0, 0), Vector3(1.3, 0.75, 1.1), "AncientCrown")
	GameUtil.sphere(grove, 3.8, GameUtil.mat("leaf"), tree_pos + Vector3(-3.0, 10.5, 1.0), Vector3(1.0, 0.7, 0.9), "AncientCrown2")
	# a ring of stones around the future boss arena
	for i in 10:
		var a := TAU * float(i) / 10.0
		var p := GROVE_CENTER + Vector3(cos(a) * 10.0, 0, sin(a) * 10.0)
		p.y = height_at(p.x, p.z)
		GameUtil.sphere(grove, 0.55, GameUtil.mat("rock"), p + Vector3(0, 0.25, 0), Vector3(1.4, 0.7, 1.0), "RitualStone")

func _build_giant_mushroom(parent: Node3D, pos: Vector3, scale: float) -> void:
	var root := Node3D.new()
	root.position = pos
	parent.add_child(root)
	var stem_mat := GameUtil.mat("cream")
	var cap_mat := GameUtil.mat("mushroom")
	GameUtil.cylinder(root, 0.35 * scale * 0.5, 2.2 * scale, stem_mat, Vector3(0, 1.1 * scale, 0), Vector3.ZERO, 10, "Stem")
	GameUtil.sphere(root, 1.0 * scale, cap_mat, Vector3(0, 2.6 * scale, 0), Vector3(1.5, 0.55, 1.4), "Cap")
	for i in 5:
		var a := TAU * float(i) / 5.0
		GameUtil.sphere(root, 0.24 * scale, GameUtil.mat("mushroom_spot"), Vector3(cos(a) * 0.75 * scale, 2.7 * scale, sin(a) * 0.65 * scale), Vector3(1.0, 0.4, 1.0), "Spot")
	GameUtil.add_blob_shadow(root, Vector2(3.5, 3.5) * scale)

func _scatter_resources() -> void:
	var spots: Array[Vector3] = []
	var branch_spots := [
		Vector3(4, 0, 11), Vector3(-3, 0, 9), Vector3(6, 0, 8), Vector3(-6, 0, 13),
		Vector3(10, 0, 6), Vector3(-9, 0, 5), Vector3(2, 0, 17), Vector3(-2, 0, 3),
		Vector3(8, 0, -4), Vector3(-7, 0, -7), Vector3(13, 0, 11), Vector3(-12, 0, 14),
		Vector3(0, 0, 11.4), Vector3(1.5, 0, 12.2)
	]
	for p in branch_spots:
		_add_resource("branch_pile", p)
	for p in [Vector3(1.5, 0, 7.5), Vector3(-2.5, 0, 8.0), Vector3(4.0, 0, 10.0), Vector3(-5.0, 0, 4.0), Vector3(7.0, 0, 2.0), Vector3(0.0, 0, 2.0)]:
		_add_resource("loose_stone", p)
	# trees close enough to frame the clearing and give the first axe some targets
	for p in [Vector3(-14, 0, 5), Vector3(14, 0, 7), Vector3(-17, 0, -8), Vector3(18, 0, -6), Vector3(-11, 0, 19), Vector3(12, 0, 20), Vector3(-19, 0, 12), Vector3(20, 0, 14), Vector3(-8, 0, -14), Vector3(9, 0, -16), Vector3(-6, 0, 7), Vector3(7, 0, 4), Vector3(-9, 0, 13), Vector3(10, 0, 12), Vector3(-5, 0, -6), Vector3(6, 0, -8), Vector3(-4, 0, 7), Vector3(4, 0, 7), Vector3(-5, 0, 12), Vector3(5, 0, 12)]:
		_add_resource("tree", p)
	var tree_targets := 42
	var tries := 0
	while tree_targets > 0 and tries < 500:
		tries += 1
		var x := _rng.randf_range(-72, 72)
		var z := _rng.randf_range(-72, 72)
		if Vector2(x, z).length() < 18.0:
			continue
		if Vector2(x - GROVE_CENTER.x, z - GROVE_CENTER.z).length() < 16.0:
			continue
		if absf(x) > 74 or absf(z) > 74:
			continue
		if x*x + (z-14)*(z-14) < 9.0:
			continue
		_add_resource("tree", Vector3(x, 0, z), true)
		tree_targets -= 1
	var rock_targets := 24
	tries = 0
	while rock_targets > 0 and tries < 400:
		tries += 1
		var x := _rng.randf_range(-70, 70)
		var z := _rng.randf_range(-70, 70)
		if Vector2(x, z).length() < 14.0:
			continue
		if x*x + (z-14)*(z-14) < 9.0:
			continue
		_add_resource("rock", Vector3(x, 0, z), true)
		rock_targets -= 1
	var bush_targets := 16
	tries = 0
	while bush_targets > 0 and tries < 300:
		tries += 1
		var x := _rng.randf_range(-68, 68)
		var z := _rng.randf_range(-68, 68)
		if Vector2(x, z).length() < 12.0:
			continue
		_add_resource("berry_bush", Vector3(x, 0, z), true)
		bush_targets -= 1
	var mushroom_targets := 18
	tries = 0
	while mushroom_targets > 0 and tries < 400:
		tries += 1
		var near_grove := mushroom_targets > 8
		var x: float
		var z: float
		if near_grove:
			x = _rng.randf_range(-26, 26)
			z = _rng.randf_range(-72, -38)
		else:
			x = _rng.randf_range(-60, 60)
			z = _rng.randf_range(-55, 55)
		_add_resource("mushroom_patch", Vector3(x, 0, z), true)
		mushroom_targets -= 1
	# a few guaranteed early resources within sight of the spawn
	_add_resource("berry_bush", Vector3(9, 0, 12))
	_add_resource("mushroom_patch", Vector3(-10, 0, 10))
	_add_resource("rock", Vector3(-4, 0, 17))

func _add_resource(id: String, p: Vector3, avoid_overlap := false) -> void:
	var pos := Vector3(p.x, height_at(p.x, p.z) + 0.05, p.z)
	if avoid_overlap:
		for n in resource_nodes:
			if is_instance_valid(n) and n.global_position.distance_to(pos) < 3.0:
				return
	var n := ResourceNode.new()
	n.setup(game, self, id, pos)
	resource_root.add_child(n)
	resource_nodes.append(n)

func _build_enemy_spawns() -> void:
	enemy_spawns = [
		Vector3(18, 0, -24), Vector3(-22, 0, -20), Vector3(26, 0, 18),
		Vector3(-30, 0, 8), Vector3(8, 0, -46), Vector3(-12, 0, -50),
		Vector3(24, 0, -55), Vector3(-24, 0, -58), Vector3(0, 0, -42),
	]
	for i in enemy_spawns.size():
		enemy_spawns[i].y = height_at(enemy_spawns[i].x, enemy_spawns[i].z) + 0.2

func random_enemy_spawn() -> Vector3:
	var base := enemy_spawns[_rng.randi_range(0, enemy_spawns.size() - 1)]
	base += Vector3(_rng.randf_range(-3, 3), 0, _rng.randf_range(-3, 3))
	base.y = height_at(base.x, base.z) + 0.2
	return base

func to_save() -> Dictionary:
	var nodes: Array = []
	for n in resource_nodes:
		if is_instance_valid(n):
			nodes.append(n.to_save())
	return {"seed": 20261112, "resources": nodes}

func from_save(data: Dictionary) -> void:
	var nodes = data.get("resources", [])
	if typeof(nodes) != TYPE_ARRAY:
		return
	for i in mini(nodes.size(), resource_nodes.size()):
		if is_instance_valid(resource_nodes[i]):
			resource_nodes[i].from_save(nodes[i])

func set_night_visual(night: bool, fireflies: Node3D = null) -> void:
	if fireflies:
		fireflies.visible = night
