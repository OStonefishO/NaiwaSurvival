class_name BuildingData
extends Resource

@export var id := ""
@export var display_name := ""
@export var category := ""
@export var cost: Dictionary = {}
@export var size := Vector2(2.0, 2.0)
@export var height := 0.0
@export var model_path := ""
@export var description := ""
@export var collision_size := Vector3(2.0, 2.0, 2.0)
@export var needs_floor := false
@export var is_walkable := false
