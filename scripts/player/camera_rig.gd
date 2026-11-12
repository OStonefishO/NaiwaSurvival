class_name CameraRig
extends Node3D

var target: Node3D
var camera: Camera3D
var follow_offset := Vector3(0, 9.2, 7.4)
var look_offset := Vector3(0, 0.9, 0)
var smooth := 5.0
var zoom := 1.0
var shake_time := 0.0
var shake_power := 0.0

func setup(p_target: Node3D) -> void:
	target = p_target
	camera = Camera3D.new()
	camera.name = "Camera3D"
	camera.fov = 38.0
	camera.near = 0.1
	camera.far = 300.0
	add_child(camera)
	camera.position = follow_offset
	global_position = target.global_position
	camera.look_at(target.global_position + look_offset, Vector3.UP)

func _process(delta: float) -> void:
	if target == null:
		return
	var desired := target.global_position
	global_position = global_position.lerp(desired, 1.0 - exp(-smooth * delta))
	var off := follow_offset * zoom
	if shake_time > 0.0:
		shake_time -= delta
		var s := shake_power * (shake_time / maxf(0.001, shake_time + delta))
		off += Vector3(randf_range(-s, s), randf_range(-s * 0.6, s * 0.6), randf_range(-s, s))
	camera.position = camera.position.lerp(off, 1.0 - exp(-8.0 * delta))
	camera.look_at(global_position + look_offset, Vector3.UP)

func shake(power: float, duration: float) -> void:
	shake_power = power
	shake_time = maxf(shake_time, duration)

func mouse_ground_position(y: float) -> Vector3:
	if camera == null:
		return Vector3.ZERO
	var mouse := get_viewport().get_mouse_position()
	var origin := camera.project_ray_origin(mouse)
	var dir := camera.project_ray_normal(mouse)
	if absf(dir.y) < 0.0001:
		return origin
	var t := (y - origin.y) / dir.y
	if t < 0.0:
		return origin
	return origin + dir * t
