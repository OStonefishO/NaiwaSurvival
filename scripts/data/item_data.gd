class_name ItemData
extends Resource

@export var id := ""
@export var display_name := ""
@export_multiline var description := ""
@export_enum("material", "tool", "weapon", "consumable", "key") var category := "material"
@export var max_stack := 20
@export var icon_color := Color("#d8c18a")
@export var icon_glyph := ""
@export var tool_type := ""
@export var tool_level := 0
@export var damage := 0.0
@export var hunger_restore := 0.0
@export var health_restore := 0.0
@export var stamina_restore := 0.0
