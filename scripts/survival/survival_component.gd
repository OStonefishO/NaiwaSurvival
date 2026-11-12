class_name SurvivalComponent
extends Node

signal health_changed(current: float, maximum: float)
signal hunger_changed(current: float, maximum: float)
signal stamina_changed(current: float, maximum: float)
signal died

const MAX_HEALTH := 100.0
const MAX_HUNGER := 100.0
const MAX_STAMINA := 100.0

var health := MAX_HEALTH
var hunger := MAX_HUNGER
var stamina := MAX_STAMINA
var starving := false
var alive := true
var _starve_timer := 0.0

func _ready() -> void:
	set_process(true)

func _process(delta: float) -> void:
	if not alive:
		return
	if stamina < MAX_STAMINA:
		stamina = minf(MAX_STAMINA, stamina + delta * 9.0)
		stamina_changed.emit(stamina, MAX_STAMINA)
	if hunger <= 0.0:
		_starve_timer += delta
		if _starve_timer >= 6.0:
			_starve_timer = 0.0
			damage(2.0)
	elif hunger > 45.0 and health < MAX_HEALTH:
		health = minf(MAX_HEALTH, health + delta * 0.35)
		health_changed.emit(health, MAX_HEALTH)

func advance_time(game_minutes: float) -> void:
	if not alive:
		return
	hunger = maxf(0.0, hunger - game_minutes * 0.05)
	hunger_changed.emit(hunger, MAX_HUNGER)
	if hunger <= 0.0 and not starving:
		starving = true
	elif hunger > 10.0:
		starving = false

func damage(amount: float) -> void:
	if not alive or amount <= 0.0:
		return
	health = maxf(0.0, health - amount)
	health_changed.emit(health, MAX_HEALTH)
	if health <= 0.0:
		alive = false
		died.emit()

func heal(amount: float) -> void:
	if not alive:
		return
	health = minf(MAX_HEALTH, health + amount)
	health_changed.emit(health, MAX_HEALTH)

func eat(item: ItemData) -> bool:
	if item == null:
		return false
	var any := false
	if item.hunger_restore > 0.0:
		hunger = minf(MAX_HUNGER, hunger + item.hunger_restore)
		hunger_changed.emit(hunger, MAX_HUNGER)
		any = true
	if item.health_restore > 0.0:
		heal(item.health_restore)
		any = true
	if item.stamina_restore > 0.0:
		stamina = minf(MAX_STAMINA, stamina + item.stamina_restore)
		stamina_changed.emit(stamina, MAX_STAMINA)
		any = true
	return any

func spend_stamina(amount: float) -> bool:
	if stamina < amount:
		return false
	stamina -= amount
	stamina_changed.emit(stamina, MAX_STAMINA)
	return true

func restore_full() -> void:
	health = MAX_HEALTH
	hunger = MAX_HUNGER
	stamina = MAX_STAMINA
	alive = true
	health_changed.emit(health, MAX_HEALTH)
	hunger_changed.emit(hunger, MAX_HUNGER)
	stamina_changed.emit(stamina, MAX_STAMINA)

func to_save() -> Dictionary:
	return {"health": health, "hunger": hunger, "stamina": stamina}

func from_save(data: Dictionary) -> void:
	health = float(data.get("health", MAX_HEALTH))
	hunger = float(data.get("hunger", MAX_HUNGER))
	stamina = float(data.get("stamina", MAX_STAMINA))
	alive = health > 0.0
	health_changed.emit(health, MAX_HEALTH)
	hunger_changed.emit(hunger, MAX_HUNGER)
	stamina_changed.emit(stamina, MAX_STAMINA)
