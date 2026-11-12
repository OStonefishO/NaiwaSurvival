class_name GameUtil
extends RefCounted

# Shared materials are cached so hundreds of props keep the draw-call/material
# count low on mobile and web.
static var _materials: Dictionary = {}
static var _shadow_tex: ImageTexture
static var _particle_tex: ImageTexture
static var _palette := {
	"sand": Color("#d9b46f"),
	"sand_dark": Color("#b98d4d"),
	"wet_sand": Color("#9e7949"),
	"grass": Color("#527d38"),
	"grass_dark": Color("#395f27"),
	"grass_light": Color("#6e9b48"),
	"rock": Color("#837663"),
	"rock_dark": Color("#5b5347"),
	"wood": Color("#8a5a33"),
	"wood_light": Color("#b07a45"),
	"wood_dark": Color("#5c3b22"),
	"leaf": Color("#3f8b3b"),
	"leaf_light": Color("#62ad4d"),
	"leaf_dark": Color("#2b6130"),
	"yellow": Color("#ffd23f"),
	"cream": Color("#fff0cf"),
	"red": Color("#b93a2e"),
	"green": Color("#4f9b54"),
	"olive": Color("#6f6a2f"),
	"black": Color("#151817"),
	"bone": Color("#e9dfc6"),
	"bone_dark": Color("#b8aa8c"),
	"gold": Color("#f2c14e"),
	"gold_dark": Color("#c58b2a"),
	"iron": Color("#5e6d72"),
	"cloth": Color("#d7b46d"),
	"water_deep": Color("#0d5a73"),
	"water_shallow": Color("#2fb3a5"),
	"fire": Color("#ff8a2b"),
}

static func color(name: String) -> Color:
	return _palette.get(name, Color.MAGENTA)

static func mat(name: String, rough := 0.82, metallic := 0.0, emission := 0.0) -> StandardMaterial3D:
	var key := "%s_%.2f_%.2f_%.2f" % [name, rough, metallic, emission]
	if _materials.has(key):
		return _materials[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color(name)
	m.roughness = rough
	m.metallic = metallic
	m.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	if emission > 0.0:
		m.emission_enabled = true
		m.emission = color(name)
		m.emission_energy_multiplier = emission
	_materials[key] = m
	return m

static func raw_mat(albedo: Color, rough := 0.82, metallic := 0.0, emission := 0.0, unshaded := false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = albedo
	m.roughness = rough
	m.metallic = metallic
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	if unshaded:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if emission > 0.0:
		m.emission_enabled = true
		m.emission = albedo
		m.emission_energy_multiplier = emission
	return m

static func transparent_mat(albedo: Color) -> StandardMaterial3D:
	var m := raw_mat(albedo, 0.6)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.no_depth_test = false
	return m

static func add_mesh(parent: Node, mesh: Mesh, material: Material, pos := Vector3.ZERO, rot := Vector3.ZERO, scale := Vector3.ONE, name := "Mesh") -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = name
	mi.mesh = mesh
	mi.material_override = material
	mi.position = pos
	mi.rotation_degrees = rot
	mi.scale = scale
	parent.add_child(mi)
	return mi

static func box(parent: Node, size: Vector3, material: Material, pos := Vector3.ZERO, rot := Vector3.ZERO, name := "Box") -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return add_mesh(parent, mesh, material, pos, rot, Vector3.ONE, name)

static func sphere(parent: Node, radius: float, material: Material, pos := Vector3.ZERO, scale := Vector3.ONE, name := "Sphere") -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 20
	mesh.rings = 10
	return add_mesh(parent, mesh, material, pos, Vector3.ZERO, scale, name)

static func capsule(parent: Node, radius: float, height: float, material: Material, pos := Vector3.ZERO, rot := Vector3.ZERO, name := "Capsule") -> MeshInstance3D:
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = height
	mesh.radial_segments = 16
	mesh.rings = 6
	return add_mesh(parent, mesh, material, pos, rot, Vector3.ONE, name)

static func cylinder(parent: Node, radius: float, height: float, material: Material, pos := Vector3.ZERO, rot := Vector3.ZERO, sides := 12, name := "Cylinder") -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = sides
	mesh.rings = 1
	return add_mesh(parent, mesh, material, pos, rot, Vector3.ONE, name)

static func cone(parent: Node, radius: float, height: float, material: Material, pos := Vector3.ZERO, rot := Vector3.ZERO, sides := 12, name := "Cone") -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.0
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = sides
	mesh.rings = 1
	return add_mesh(parent, mesh, material, pos, rot, Vector3.ONE, name)

static func cylinder_between(parent: Node, a: Vector3, b: Vector3, radius: float, material: Material, sides := 8, name := "Limb") -> MeshInstance3D:
	var dir := b - a
	var length := dir.length()
	var mi := cylinder(parent, radius, length, material, (a + b) * 0.5, Vector3.ZERO, sides, name)
	if dir.length_squared() > 0.0001:
		var up := dir.normalized()
		var basis := Basis()
		var ref := Vector3.RIGHT if absf(up.dot(Vector3.UP)) > 0.95 else Vector3.UP
		var right := ref.cross(up).normalized()
		var forward := up.cross(right).normalized()
		basis = Basis(right, up, forward)
		mi.global_transform.basis = basis
		mi.global_position = (a + b) * 0.5
	return mi

static func quad(parent: Node, size: Vector2, material: Material, pos := Vector3.ZERO, rot := Vector3.ZERO, name := "Quad") -> MeshInstance3D:
	var mesh := QuadMesh.new()
	mesh.size = size
	return add_mesh(parent, mesh, material, pos, rot, Vector3.ONE, name)

static func yaw_to(dir: Vector3) -> float:
	if dir.length_squared() < 0.0001:
		return 0.0
	return atan2(-dir.x, -dir.z)

static func flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)

static func approach(current: float, target: float, delta: float) -> float:
	return move_toward(current, target, delta)

static func format_time(seconds: float) -> String:
	var s := int(maxf(0.0, seconds))
	return "%02d:%02d" % [s / 60, s % 60]

static func make_soft_circle_texture(inner := Color(0, 0, 0, 0.42), outer := Color(0, 0, 0, 0.0), size := 128) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var c := Vector2(size * 0.5, size * 0.5)
	for y in size:
		for x in size:
			var d := Vector2(x, y).distance_to(c) / (size * 0.5)
			var a := smoothstep(1.0, 0.55, d)
			img.set_pixel(x, y, inner.lerp(outer, 1.0 - a))
	return ImageTexture.create_from_image(img)

static func shadow_texture() -> ImageTexture:
	if _shadow_tex == null:
		_shadow_tex = make_soft_circle_texture(Color(0.005, 0.02, 0.018, 0.52), Color(0.005, 0.02, 0.018, 0.0), 96)
	return _shadow_tex

static func particle_texture() -> ImageTexture:
	if _particle_tex == null:
		var size := 64
		var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
		var c := Vector2(size * 0.5, size * 0.5)
		for y in size:
			for x in size:
				var d := Vector2(x, y).distance_to(c) / (size * 0.5)
				var a := pow(clampf(1.0 - d, 0.0, 1.0), 1.7)
				img.set_pixel(x, y, Color(1, 1, 1, a))
		_particle_tex = ImageTexture.create_from_image(img)
	return _particle_tex

static func blob_shadow_material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = shadow_texture()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m

static func make_radial_vignette() -> ImageTexture:
	var size := 64
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var c := Vector2(size * 0.5, size * 0.5)
	for y in size:
		for x in size:
			var d := Vector2(x, y).distance_to(c) / (size * 0.5)
			var a := clampf((d - 0.35) / 0.65, 0.0, 1.0)
			img.set_pixel(x, y, Color(0.02, 0.1, 0.1, a * a))
	return ImageTexture.create_from_image(img)
