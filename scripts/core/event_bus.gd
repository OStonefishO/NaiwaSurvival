extends Node

# 跨系统事件总线：UI 只订阅事件，不直接抓取游戏节点。
signal toast_requested(text: String, duration: float)
signal inventory_changed
signal health_changed(current: float, maximum: float)
signal hunger_changed(current: float, maximum: float)
signal stamina_changed(current: float, maximum: float)
signal time_changed(hour: float, day: int)
signal weather_changed(weather: String)
signal quest_changed(step: int, title: String, description: String)
signal building_placed(building_id: String, world_position: Vector3)
signal player_died
signal game_saved
signal item_crafted(item_id: String, amount: int)
