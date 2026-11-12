class_name EnemyData
extends Resource

@export var id := ""
@export var display_name := ""
@export var max_health := 40.0
@export var speed := 2.2
@export var damage := 8.0
@export var attack_range := 1.7
@export var aggro_range := 12.0
@export var attack_cooldown := 1.6
@export var model_path := ""
@export var drops: Dictionary = {}
@export var tint := Color("#7fae6a")
@export var is_boss := false
