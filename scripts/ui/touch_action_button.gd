class_name TouchActionButton
extends Control

signal pressed

@export var label := ""
@export var icon_kind: HUDIcon.Kind = HUDIcon.Kind.SWORD
@export var accent := Color("#f0c56a")

var touch_index := -1
var is_down := false
var pulse := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(86, 86)
	queue_redraw()

func _process(delta: float) -> void:
	if pulse > 0.0:
		pulse = maxf(0.0, pulse - delta * 3.0)
		queue_redraw()

func _input(event: InputEvent) -> void:
	if not visible or not is_visible_in_tree():
		return
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		if t.pressed and touch_index == -1 and _inside(t.position):
			touch_index = t.index
			_down()
			get_viewport().set_input_as_handled()
		elif not t.pressed and t.index == touch_index:
			_up()
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed and touch_index == -1 and _inside(mb.position):
				touch_index = -2
				_down()
			elif not mb.pressed and touch_index == -2:
				_up()

func _inside(global_pos: Vector2) -> bool:
	var local := get_global_transform().affine_inverse() * global_pos
	return local.x >= 0 and local.y >= 0 and local.x <= size.x and local.y <= size.y

func _down() -> void:
	is_down = true
	pulse = 1.0
	pressed.emit()
	queue_redraw()

func _up() -> void:
	is_down = false
	touch_index = -1
	queue_redraw()

func _draw() -> void:
	var c := size * 0.5
	var r := minf(size.x, size.y) * 0.46
	if is_down:
		r *= 0.93
	draw_circle(c + Vector2(0, 4), r + 2.0, Color(0.02, 0.08, 0.08, 0.35))
	draw_circle(c, r, Color(0.04, 0.17, 0.17, 0.68) if not is_down else Color(0.12, 0.35, 0.30, 0.8))
	draw_arc(c, r, 0, TAU, 40, accent, 2.4 if not is_down else 4.0)
	draw_arc(c, r - 5.0, 0, TAU, 40, Color(1, 1, 1, 0.12), 1.0)
	_draw_glyph(c, r)
	if pulse > 0.0:
		draw_arc(c, r + 6.0 * (1.0 - pulse), 0, TAU, 40, Color(1, 1, 1, pulse * 0.5), 2.0)

func _draw_glyph(c: Vector2, r: float) -> void:
	match icon_kind:
		HUDIcon.Kind.SWORD:
			draw_line(c + Vector2(-r * 0.35, r * 0.35), c + Vector2(r * 0.35, -r * 0.4), Color(1, 0.96, 0.8), 4.0)
			draw_line(c + Vector2(-r * 0.45, r * 0.12), c + Vector2(-r * 0.05, r * 0.46), Color(1, 0.85, 0.45), 3.0)
		HUDIcon.Kind.DASH:
			for i in 3:
				var x := c.x - r * 0.35 + i * r * 0.24
				draw_line(Vector2(x, c.y - r * 0.3), Vector2(x + r * 0.2, c.y), Color(0.72, 0.95, 0.95), 3.0)
				draw_line(Vector2(x + r * 0.2, c.y), Vector2(x, c.y + r * 0.3), Color(0.72, 0.95, 0.95), 3.0)
		HUDIcon.Kind.HAND:
			draw_circle(c, r * 0.28, Color(1, 0.9, 0.7))
			for i in 3:
				var x := c.x - r * 0.22 + i * r * 0.2
				draw_line(Vector2(x, c.y - r * 0.1), Vector2(x, c.y - r * 0.42), Color(1, 0.9, 0.7), r * 0.13)
