class_name MenuScrim
extends ColorRect

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	color = Color.WHITE
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/menu_scrim.gdshader")
	material = mat
