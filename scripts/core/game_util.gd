class_name GameUtil
extends RefCounted

const CREAM := Color("#f7edcf")
const FOREST_GREEN := Color("#3f6b4a")
const MOSS := Color("#6e9b5d")
const BARK := Color("#735238")
const GOLD := Color("#e3b85b")
const INK := Color("#13251c")

static var _materials: Dictionary = {}
static var _shadow_tex: ImageTexture
static var _particle_tex: ImageTexture

static func raw_mat(color: Color, roughness := 0.85, metallic := 0.0, emission := 0.0, unshaded := false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	m.metallic = metallic
	if emission > 0.0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = emission
	if unshaded:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m

static func mat(key: String, roughness := 0.9) -> StandardMaterial3D:
	if _materials.has(key):
		return _materials[key]
	var colors := {
		"bark": Color("#67492f"), "bark_dark": Color("#4b3526"), "leaf": Color("#477a42"),
		"leaf_dark": Color("#2e5837"), "leaf_light": Color("#78a954"), "grass": Color("#638c4d"),
		"rock": Color("#3f3e35"), "rock_dark": Color("#2c2b25"), "cream": Color("#c9b790"),
		"gold": Color("#d8ab4f"), "wood": Color("#8a633c"), "wood_dark": Color("#5f432b"),
		"mushroom": Color("#7d3a2e"), "mushroom_spot": Color("#efdab5"), "slime": Color("#68a97f"),
		"fiber": Color("#7da552"), "clay": Color("#a66f4f"), "pollution": Color("#7b518f"),
	}
	var m := raw_mat(colors.get(key, Color.WHITE), roughness)
	_materials[key] = m
	return m

static func box(parent: Node, size: Vector3, material: Material, pos: Vector3, rot := Vector3.ZERO, name := "Box") -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var mi := MeshInstance3D.new()
	mi.name = name
	mi.mesh = mesh
	mi.material_override = material
	mi.position = pos
	mi.rotation_degrees = rot
	parent.add_child(mi)
	return mi

static func sphere(parent: Node, radius: float, material: Material, pos: Vector3, scale := Vector3.ONE, name := "Sphere") -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 12
	mesh.rings = 6
	var mi := MeshInstance3D.new()
	mi.name = name
	mi.mesh = mesh
	mi.material_override = material
	mi.position = pos
	mi.scale = scale
	parent.add_child(mi)
	return mi

static func cylinder(parent: Node, radius: float, height: float, material: Material, pos: Vector3, rot := Vector3.ZERO, segments := 8, name := "Cylinder") -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = segments
	var mi := MeshInstance3D.new()
	mi.name = name
	mi.mesh = mesh
	mi.material_override = material
	mi.position = pos
	mi.rotation_degrees = rot
	parent.add_child(mi)
	return mi

static func cone(parent: Node, radius: float, height: float, material: Material, pos: Vector3, rot := Vector3.ZERO, segments := 8, name := "Cone") -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.0
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = segments
	var mi := MeshInstance3D.new()
	mi.name = name
	mi.mesh = mesh
	mi.material_override = material
	mi.position = pos
	mi.rotation_degrees = rot
	parent.add_child(mi)
	return mi

static func load_glb(path: String) -> Node3D:
	if not ResourceLoader.exists(path):
		return null
	var packed := load(path)
	if packed is PackedScene:
		var inst = packed.instantiate()
		if inst is Node3D:
			apply_asset_materials(inst, path)
			return inst
		inst.queue_free()
	return null

static func apply_asset_materials(root: Node, path: String) -> void:
	if path.contains("frog"):
		return
	var asset := path.get_file().get_basename()
	var palette := {
		"bark": Color("#3e2a18"), "bark_dark": Color("#2b1c10"),
		"leaf": Color("#2f5d2c"), "leaf_dark": Color("#1e4224"), "leaf_light": Color("#4f7f38"),
		"rock": Color("#39382f"), "rock_dark": Color("#2a2923"),
		"mushroom": Color("#6f2b22"), "spot": Color("#d8c49e"),
		"berry": Color("#8c2424"), "wood": Color("#5a3a1e"), "wood_dark": Color("#322012"),
		"cloth": Color("#b09b77"), "blanket": Color("#3b5236"),
		"gold": Color("#a6792f"), "slime": Color("#3d7d57"),
		"bug": Color("#3e2b1c"), "spike": Color("#5c513c"), "dark": Color("#0b0d08"),
		"cream": Color("#b9a57d"), "flame": Color("#ff8a2a"), "glow": Color("#6dffb4"),
	}
	for n in root.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		var node_name := str(mi.name)
		var key := ""
		if node_name.begins_with("Canopy"):
			key = "leaf_light" if node_name.contains("High") else ("leaf_dark" if node_name.contains("Low") else "leaf")
		elif node_name in ["Trunk", "Branch", "Branch0", "Branch1", "Branch2", "Branch3", "Branch4", "Log0", "Log1", "Log2", "Handle", "ToolHandle", "Pole", "Post", "Beam", "Plank", "Panel", "Frame", "FrameL", "FrameR", "Top", "Base", "Lid", "Leg", "Legs", "Tool", "PanelL", "PanelR"]:
			if node_name in ["Frame", "FrameL", "FrameR", "Top", "Lid", "Leg", "Legs", "Beam", "Tool"]:
				key = "wood_dark"
			elif node_name.begins_with("Branch"):
				key = "bark" if node_name in ["Branch1", "Branch3"] else "wood"
			else:
				key = "wood"
		elif node_name in ["Rock", "RockA", "RockB", "RockC", "Stone0", "Stone1", "Stone2", "Stone3", "Stone4", "Stone5", "Stone6", "Stone7"]:
			key = "rock_dark" if node_name == "RockB" else "rock"
		elif node_name.begins_with("Stem"):
			key = "cream"
		elif node_name.begins_with("Cap"):
			key = "mushroom"
		elif node_name.begins_with("Spot"):
			key = "spot"
		elif node_name.begins_with("Berry"):
			key = "berry"
		elif node_name == "Bush" or node_name.begins_with("Bush"):
			key = "leaf_dark"
		elif node_name == "Flame":
			key = "flame"
		elif node_name == "Mattress" or node_name == "Pillow":
			key = "cloth" if node_name == "Mattress" else "cream"
		elif node_name == "Blanket":
			key = "blanket"
		elif node_name == "Band" or node_name == "Latch" or node_name == "Knob":
			key = "gold"
		elif node_name == "Vice":
			key = "rock"
		elif node_name == "Heart":
			key = "glow"
		elif node_name == "Crown":
			key = "leaf_dark" if asset == "ancient_guardian" else "leaf"
		elif node_name == "Eye":
			if asset == "spiky_beast" or asset == "ancient_guardian":
				key = "gold" if asset == "spiky_beast" else "glow"
			else:
				key = "dark"
		elif node_name == "EyeSpark" or node_name == "Spot":
			key = "cream"
		elif node_name == "Body":
			if asset == "slime":
				key = "slime"
			elif asset == "mushroom_bug":
				key = "bug"
			elif asset == "spiky_beast":
				key = "bark"
			elif asset == "ancient_guardian":
				key = "bark_dark"
			else:
				key = "wood"
		elif node_name == "Cap" and asset == "mushroom_bug":
			key = "mushroom"
		elif node_name.begins_with("Spike"):
			key = "spike"
		elif node_name == "NaiFrogMesh":
			return
		if key == "":
			continue
		var m := StandardMaterial3D.new()
		m.albedo_color = palette.get(key, Color.WHITE)
		m.roughness = 0.78
		if key in ["mushroom", "berry", "gold"]:
			m.roughness = 0.52
		if key in ["flame", "glow"]:
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			m.albedo_color = palette[key]
			m.emission_enabled = true
			m.emission = palette[key]
			m.emission_energy_multiplier = 2.0
		mi.material_override = m

static func model_size(node: Node3D) -> Vector3:
	var aabb := AABB()
	var first := true
	for c in node.find_children("*", "MeshInstance3D", true, false):
		var mi := c as MeshInstance3D
		var bb := mi.global_transform * mi.get_aabb()
		if first:
			aabb = bb
			first = false
		else:
			aabb = aabb.merge(bb)
	return aabb.size

static func add_blob_shadow(parent: Node3D, size: Vector2) -> void:
	var quad := QuadMesh.new()
	quad.size = size
	var mi := MeshInstance3D.new()
	mi.name = "BlobShadow"
	mi.mesh = quad
	mi.rotation_degrees.x = -90
	mi.position.y = 0.03
	mi.material_override = blob_shadow_material()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)

static func blob_shadow_material() -> StandardMaterial3D:
	if _shadow_tex == null:
		var size := 64
		var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
		var center := Vector2(size * 0.5, size * 0.5)
		for y in size:
			for x in size:
				var d := Vector2(x, y).distance_to(center) / (size * 0.5)
				var a := pow(clampf(1.0 - d, 0.0, 1.0), 1.7) * 0.38
				img.set_pixel(x, y, Color(0.04, 0.06, 0.04, a))
		_shadow_tex = ImageTexture.create_from_image(img)
	var m := StandardMaterial3D.new()
	m.albedo_texture = _shadow_tex
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m

static func particle_texture() -> ImageTexture:
	if _particle_tex == null:
		var size := 64
		var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
		var center := Vector2(size * 0.5, size * 0.5)
		for y in size:
			for x in size:
				var d := Vector2(x, y).distance_to(center) / (size * 0.5)
				var a := pow(clampf(1.0 - d, 0.0, 1.0), 1.7)
				img.set_pixel(x, y, Color(1, 1, 1, a))
		_particle_tex = ImageTexture.create_from_image(img)
	return _particle_tex

static func format_time(hour: float) -> String:
	var h := int(hour) % 24
	var m := int((hour - floor(hour)) * 60.0)
	return "%02d:%02d" % [h, m]
