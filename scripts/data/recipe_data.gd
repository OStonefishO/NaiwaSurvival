class_name RecipeData
extends Resource

@export var id := ""
@export var display_name := ""
@export var output_item := ""
@export var output_count := 1
@export var costs: Dictionary = {}
@export_enum("hand", "workbench", "campfire") var station := "hand"
@export var description := ""
