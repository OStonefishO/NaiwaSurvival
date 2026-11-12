class_name CameraRig
extends Node3D

var camera: Camera3D
var target: Node3D
var follow_offset := Vector3(0.0, 11.5, 15.0)
var look_offset := Vector3(0.0, 0.9, 0.0)
var title_mode := true
var orbit_angle := 0.6
var orbit_radius := 42.0
var orbit_height := 25.0
var shake_time := 0.0
var shake_duration := 0.0
var shake_strength := 0.0
var base_position := Vector3.ZERO
var follow_pos := Vector3.ZERO
var menu_target := Vector3(0.0, 1.2, 0.0)

func _ready() -> void:
	camera = Camera3D.new()
	camera.name = "Camera3D"
	camera.fov = 40.0
	camera.near = 0.2
	camera.far = 300.0
	camera.current = true
	add_child(camera)
	camera.position = Vector3(0.0, 0.0, 0.0)

func set_target(p_target: Node3D) -> void:
	target = p_target
	follow_pos = target.global_position

func start_game() -> void:
	title_mode = false
	if target:
		follow_pos = target.global_position

func update_camera(delta: float) -> void:
	if title_mode:
		orbit_angle += delta * 0.055
		base_position = menu_target + Vector3(cos(orbit_angle) * orbit_radius, orbit_height, sin(orbit_angle) * orbit_radius)
		camera.global_position = camera.global_position.lerp(base_position, clampf(delta * 1.8, 0.0, 1.0))
		camera.look_at(menu_target, Vector3.UP)
	else:
		if target == null:
			return
		follow_pos = follow_pos.lerp(target.global_position, clampf(delta * 7.0, 0.0, 1.0))
		var desired := follow_pos + follow_offset
		desired.y = maxf(desired.y, follow_pos.y + 12.0)
		camera.global_position = camera.global_position.lerp(desired, clampf(delta * 6.5, 0.0, 1.0))
		var look_point := follow_pos + look_offset
		if camera.global_position.distance_to(look_point) > 0.1:
			camera.look_at(look_point, Vector3.UP)
	if shake_time > 0.0:
		shake_time -= delta
		var falloff := clampf(shake_time / maxf(shake_duration, 0.001), 0.0, 1.0)
		var amp := shake_strength * falloff
		camera.global_position += Vector3(sin(Time.get_ticks_msec() * 0.09) * amp, cos(Time.get_ticks_msec() * 0.075) * amp * 0.7, 0.0)

func _process(delta: float) -> void:
	update_camera(delta)

func shake(strength: float, duration: float) -> void:
	shake_strength = maxf(shake_strength, strength)
	shake_duration = maxf(shake_duration, duration)
	shake_time = maxf(shake_time, duration)

func mouse_world_point(screen_point: Vector2, plane_y := 0.0) -> Variant:
	if camera == null:
		return null
	var origin := camera.project_ray_origin(screen_point)
	var dir := camera.project_ray_normal(screen_point)
	if absf(dir.y) < 0.0001:
		return null
	var t := (plane_y - origin.y) / dir.y
	if t < 0.0:
		return null
	return origin + dir * t
