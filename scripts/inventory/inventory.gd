class_name Inventory
extends RefCounted

signal changed
signal selection_changed(index: int)

const SIZE := 24
const HOTBAR_SIZE := 8

var slots: Array = []
var selected_index := 0

func _init() -> void:
	slots.resize(SIZE)
	for i in SIZE:
		slots[i] = null

func add_item(item_id: String, amount: int) -> int:
	if amount <= 0:
		return 0
	var data: ItemData = GameDB.item(item_id)
	if data == null:
		return amount
	var remaining := amount
	# fill existing stacks first
	for i in SIZE:
		if remaining <= 0:
			break
		var s = slots[i]
		if s != null and s["id"] == item_id and s["amount"] < data.max_stack:
			var space := data.max_stack - int(s["amount"])
			var put := mini(space, remaining)
			s["amount"] += put
			remaining -= put
	for i in SIZE:
		if remaining <= 0:
			break
		if slots[i] == null:
			var put := mini(data.max_stack, remaining)
			slots[i] = {"id": item_id, "amount": put}
			remaining -= put
	if remaining != amount:
		changed.emit()
	return remaining

func remove_item(item_id: String, amount: int) -> bool:
	if count_item(item_id) < amount:
		return false
	var left := amount
	for i in SIZE:
		if left <= 0:
			break
		var s = slots[i]
		if s != null and s["id"] == item_id:
			var take := mini(int(s["amount"]), left)
			s["amount"] -= take
			left -= take
			if s["amount"] <= 0:
				slots[i] = null
	changed.emit()
	return true

func count_item(item_id: String) -> int:
	var total := 0
	for s in slots:
		if s != null and s["id"] == item_id:
			total += int(s["amount"])
	return total

func has_costs(costs: Dictionary) -> bool:
	for id in costs:
		if count_item(id) < int(costs[id]):
			return false
	return true

func consume_costs(costs: Dictionary) -> bool:
	if not has_costs(costs):
		return false
	for id in costs:
		remove_item(id, int(costs[id]))
	return true

func selected_stack():
	if selected_index < 0 or selected_index >= SIZE:
		return null
	return slots[selected_index]

func selected_item() -> ItemData:
	var s = selected_stack()
	if s == null:
		return null
	return GameDB.item(s["id"])

func select(index: int) -> void:
	if index < 0 or index >= HOTBAR_SIZE:
		return
	selected_index = index
	selection_changed.emit(index)

func first_empty() -> int:
	for i in SIZE:
		if slots[i] == null:
			return i
	return -1

func drop_percent(percent: float) -> Array:
	var dropped: Array = []
	for i in SIZE:
		var s = slots[i]
		if s == null:
			continue
		if randf() < percent:
			dropped.append(s.duplicate(true))
			slots[i] = null
	if not dropped.is_empty():
		changed.emit()
	return dropped

func to_save() -> Array:
	var out: Array = []
	for s in slots:
		out.append(s.duplicate(true) if s != null else null)
	return out

func from_save(data) -> void:
	for i in SIZE:
		slots[i] = null
	if typeof(data) == TYPE_ARRAY:
		for i in mini(data.size(), SIZE):
			var s = data[i]
			if typeof(s) == TYPE_DICTIONARY and s.has("id") and s.has("amount"):
				slots[i] = {"id": str(s["id"]), "amount": int(s["amount"])}
	changed.emit()
