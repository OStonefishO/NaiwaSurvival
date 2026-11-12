class_name MilkJoystick
extends Control

signal vector_changed(value: Vector2)

var touch_index := -1
var base_center := Vector2.ZERO
var knob := Vector2.ZERO
var radius := 78.0
var active := false
var deadzone := 0.12

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		base_center = size * Vector2(0.5, 0.55)
		radius = minf(size.x, size.y) * 0.34
		queue_redraw()

func _input(event: InputEvent) -> void:
	if not visible or not is_visible_in_tree():
		return
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed and touch_index == -1 and _inside(touch.position):
			touch_index = touch.index
			active = true
			_update_knob(touch.position)
			get_viewport().set_input_as_handled()
		elif not touch.pressed and touch.index == touch_index:
			_reset()
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if drag.index == touch_index:
			_update_knob(drag.position)
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed and touch_index == -1 and _inside(mb.position):
				touch_index = -2
				active = true
				_update_knob(mb.position)
			elif not mb.pressed and touch_index == -2:
				_reset()
	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if touch_index == -2 and active:
			_update_knob(mm.position)

func _inside(p: Vector2) -> bool:
	var local := get_global_transform().affine_inverse() * p
	return local.x >= 0 and local.y >= 0 and local.x <= size.x and local.y <= size.y

func _update_knob(global_pos: Vector2) -> void:
	var local := get_global_transform().affine_inverse() * global_pos
	var delta := local - base_center
	if delta.length() > radius:
		delta = delta.normalized() * radius
	knob = delta
	var v := delta / radius
	if v.length() < deadzone:
		v = Vector2.ZERO
	vector_changed.emit(v)
	queue_redraw()

func _reset() -> void:
	touch_index = -1
	active = false
	knob = Vector2.ZERO
	vector_changed.emit(Vector2.ZERO)
	queue_redraw()

func _draw() -> void:
	base_center = size * Vector2(0.5, 0.55)
	radius = minf(size.x, size.y) * 0.34
	draw_circle(base_center, radius + 16.0, Color(0.03, 0.12, 0.12, 0.25))
	draw_circle(base_center, radius, Color(0.03, 0.16, 0.16, 0.32))
	draw_arc(base_center, radius, 0, TAU, 48, Color(1.0, 0.88, 0.62, 0.28), 3.0)
	draw_circle(base_center + knob, radius * 0.42, Color(0.86, 0.98, 0.82, 0.38))
	draw_circle(base_center + knob, radius * 0.36, Color(0.96, 0.99, 0.8, 0.55))
	draw_arc(base_center + knob, radius * 0.42, 0, TAU, 32, Color(1, 1, 1, 0.35), 2.0)
