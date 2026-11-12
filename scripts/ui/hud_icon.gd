class_name HUDIcon
extends Control

enum Kind { HEART, COCONUT, WOOD, MAP, COIN, SKULL, SWORD, DASH, HAND, PAUSE, STAR, STONE, FIBER, HAMMER }

@export var kind: Kind = Kind.HEART:
	set(value):
		kind = value
		queue_redraw()
@export var tint: Color = Color.WHITE:
	set(value):
		tint = value
		queue_redraw()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(28, 28)
	queue_redraw()

func _draw() -> void:
	var r := minf(size.x, size.y) * 0.5
	var c := size * 0.5
	var col := tint
	match kind:
		Kind.HEART:
			draw_circle(c + Vector2(-r * 0.34, -r * 0.24), r * 0.42, col)
			draw_circle(c + Vector2(r * 0.34, -r * 0.24), r * 0.42, col)
			var pts := PackedVector2Array([
				c + Vector2(-r * 0.72, -r * 0.10),
				c + Vector2(r * 0.72, -r * 0.10),
				c + Vector2(0, r * 0.74)
			])
			draw_colored_polygon(pts, col)
			draw_circle(c + Vector2(-r * 0.32, -r * 0.34), r * 0.11, Color(1, 1, 1, 0.45))
		Kind.COCONUT:
			draw_circle(c + Vector2(0, r * 0.1), r * 0.62, Color("#6b4424"))
			draw_circle(c + Vector2(-r * 0.18, -r * 0.16), r * 0.07, Color("#2f1b0c"))
			draw_circle(c + Vector2(r * 0.18, -r * 0.16), r * 0.07, Color("#2f1b0c"))
			draw_circle(c + Vector2(0, r * 0.16), r * 0.06, Color("#2f1b0c"))
			var leaf := PackedVector2Array([
				c + Vector2(-r * 0.1, -r * 0.42),
				c + Vector2(r * 0.55, -r * 0.78),
				c + Vector2(r * 0.18, -r * 0.18)
			])
			draw_colored_polygon(leaf, Color("#6cbf58"))
		Kind.WOOD:
			var wood := PackedVector2Array()
			draw_set_transform(c, -0.3, Vector2.ONE)
			draw_rect(Rect2(-r * 0.7, -r * 0.45, r * 1.35, r * 0.32), Color("#8d5b2d"), true)
			draw_rect(Rect2(-r * 0.6, -r * 0.1, r * 1.35, r * 0.32), Color("#a86c38"), true)
			draw_circle(Vector2(r * 0.6, -r * 0.29), r * 0.16, Color("#d8b477"))
			draw_circle(Vector2(r * 0.68, r * 0.06), r * 0.16, Color("#d8b477"))
			draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
		Kind.MAP:
			var paper := Rect2(c.x - r * 0.6, c.y - r * 0.55, r * 1.2, r * 1.1)
			draw_rect(paper, Color("#f1dba8"), true)
			draw_rect(paper, Color("#b78a52"), false, 2.0)
			draw_line(c + Vector2(-r * 0.35, r * 0.3), c + Vector2(r * 0.36, -r * 0.35), Color("#b84535"), 3.0)
			draw_line(c + Vector2(-r * 0.35, -r * 0.3), c + Vector2(r * 0.36, r * 0.32), Color("#b84535"), 3.0)
			draw_circle(c + Vector2(0, 0), r * 0.1, Color("#b84535"))
		Kind.COIN:
			draw_circle(c, r * 0.72, Color("#f3c750"))
			draw_circle(c, r * 0.55, Color("#ffdf76"))
			draw_arc(c, r * 0.55, 0, TAU, 24, Color("#b98727"), 2.0)
			draw_circle(c + Vector2(-r * 0.16, -r * 0.16), r * 0.12, Color(1, 1, 1, 0.45))
		Kind.SKULL:
			draw_circle(c + Vector2(0, -r * 0.1), r * 0.55, Color("#f0e7d0"))
			draw_rect(Rect2(c.x - r * 0.32, c.y + r * 0.2, r * 0.64, r * 0.32), Color("#f0e7d0"), true)
			draw_circle(c + Vector2(-r * 0.2, -r * 0.12), r * 0.14, Color("#1a2420"))
			draw_circle(c + Vector2(r * 0.2, -r * 0.12), r * 0.14, Color("#1a2420"))
			draw_circle(c + Vector2(0, r * 0.12), r * 0.07, Color("#1a2420"))
		Kind.SWORD:
			draw_set_transform(c + Vector2(-r * 0.5, -r * 0.5), PI * 0.25, Vector2.ONE)
			draw_rect(Rect2(-r * 0.1, 0, r * 0.2, r * 1.2), Color("#e6e2ce"), true)
			draw_rect(Rect2(-r * 0.35, r * 0.9, r * 0.7, r * 0.16), Color("#f2c14e"), true)
			draw_rect(Rect2(-r * 0.09, r * 1.05, r * 0.18, r * 0.36), Color("#7b4a25"), true)
			draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
		Kind.DASH:
			for i in 3:
				var x := c.x - r * 0.45 + i * r * 0.36
				draw_line(Vector2(x, c.y - r * 0.5), Vector2(x + r * 0.35, c.y), Color("#8fe7e0"), 4.0)
				draw_line(Vector2(x + r * 0.35, c.y), Vector2(x, c.y + r * 0.5), Color("#8fe7e0"), 4.0)
		Kind.HAND:
			draw_circle(c + Vector2(0, r * 0.1), r * 0.42, Color("#f5d7a1"))
			for i in 4:
				var x := c.x - r * 0.45 + i * r * 0.28
				draw_line(Vector2(x, c.y - r * 0.1), Vector2(x, c.y - r * 0.7), Color("#f5d7a1"), r * 0.2)
		Kind.PAUSE:
			draw_rect(Rect2(c.x - r * 0.4, c.y - r * 0.55, r * 0.25, r * 1.1), col, true)
			draw_rect(Rect2(c.x + r * 0.15, c.y - r * 0.55, r * 0.25, r * 1.1), col, true)
		Kind.STAR:
			var pts := PackedVector2Array()
			for i in 10:
				var a := -PI * 0.5 + TAU * float(i) / 10.0
				var rr := r * (0.65 if i % 2 == 0 else 0.28)
				pts.append(c + Vector2(cos(a), sin(a)) * rr)
			draw_colored_polygon(pts, col)
		Kind.STONE:
			var p1 := PackedVector2Array([
				c + Vector2(-r * 0.62, r * 0.28), c + Vector2(-r * 0.42, -r * 0.38),
				c + Vector2(r * 0.12, -r * 0.55), c + Vector2(r * 0.62, -r * 0.12),
				c + Vector2(r * 0.48, r * 0.44), c + Vector2(-r * 0.18, r * 0.48)
			])
			draw_colored_polygon(p1, Color("#8e877b"))
			var p2 := PackedVector2Array([
				c + Vector2(-r * 0.1, -r * 0.55), c + Vector2(r * 0.62, -r * 0.12),
				c + Vector2(r * 0.1, r * 0.12), c + Vector2(-r * 0.2, -r * 0.2)
			])
			draw_colored_polygon(p2, Color("#b4ab9b"))
		Kind.FIBER:
			for i in 4:
				var ox := (float(i) - 1.5) * r * 0.28
				draw_line(c + Vector2(ox * 0.3, r * 0.6), c + Vector2(ox, -r * 0.65), Color("#6ea54d"), r * 0.1)
				draw_line(c + Vector2(ox, -r * 0.65), c + Vector2(ox + r * 0.16, -r * 0.9), Color("#9cc96d"), r * 0.12)
		Kind.HAMMER:
			draw_set_transform(c, -0.5, Vector2.ONE)
			draw_rect(Rect2(-r * 0.1, -r * 0.2, r * 0.2, r * 1.0), Color("#b07a45"), true)
			draw_rect(Rect2(-r * 0.55, -r * 0.62, r * 1.1, r * 0.42), Color("#d9b46f"), true)
			draw_circle(c + Vector2(0, 0), r * 0.12, Color("#8a5a33"))
			draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
