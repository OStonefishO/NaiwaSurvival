extends Node

const SAVE_PATH := "user://naifrog_world.json"
const BACKUP_PATH := "user://naifrog_world.backup.json"

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

func load_game() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		return {}
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return {}
	var text := file.get_as_text()
	file.close()
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	if int(parsed.get("save_version", 0)) > 2:
		return {}
	return _migrate(parsed)

func save_game(data: Dictionary) -> bool:
	var payload := data.duplicate(true)
	payload["save_version"] = 2
	payload["saved_at"] = Time.get_datetime_string_from_system()
	if FileAccess.file_exists(SAVE_PATH):
		var old := FileAccess.open(SAVE_PATH, FileAccess.READ)
		if old:
			var old_text := old.get_as_text()
			old.close()
			var backup := FileAccess.open(BACKUP_PATH, FileAccess.WRITE)
			if backup:
				backup.store_string(old_text)
				backup.close()
	var temp_path := SAVE_PATH + ".tmp"
	var temp := FileAccess.open(temp_path, FileAccess.WRITE)
	if temp == null:
		return false
	temp.store_string(JSON.stringify(payload, "\t"))
	temp.close()
	# FileAccess 没有跨平台 rename，这里用临时文件覆盖正式文件。
	var final := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if final == null:
		return false
	final.store_string(JSON.stringify(payload, "\t"))
	final.close()
	if FileAccess.file_exists(temp_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(temp_path))
	EventBus.game_saved.emit()
	return true

func delete_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	if FileAccess.file_exists(BACKUP_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(BACKUP_PATH))

func _migrate(data: Dictionary) -> Dictionary:
	var v := int(data.get("save_version", 1))
	if v < 2:
		data["save_version"] = 2
		data["quest"] = data.get("quest", {"step": 0})
	return data
