class_name ForestHUD
extends CanvasLayer

signal new_game_requested
signal continue_requested
signal resume_requested
signal save_requested
signal title_requested
signal quit_requested
signal death_respawn_requested
signal recipe_craft_requested(recipe_id: String)
signal building_selected(building_id: String)
signal inventory_changed(index: int)
signal panels_closed

const CREAM := Color("#f5ecd2")
const GOLD := Color("#e2bd72")
const MINT := Color("#9dd7b0")
const INK := Color("#10251c")
const PANEL := Color(0.045, 0.13, 0.105, 0.94)
const PANEL_SOFT := Color(0.055, 0.16, 0.125, 0.78)
const RED := Color("#e47766")

var game: Node
var player: NaifrogPlayer
var world: Node
var root: Control
var font: Font

var gameplay_root: Control
var title_root: Control
var pause_root: Control
var death_root: Control
var inventory_root: Control
var craft_root: Control
var build_root: Control
var chest_root: Control
var fade_rect: ColorRect

var health_bar: ProgressBar
var hunger_bar: ProgressBar
var stamina_bar: ProgressBar
var health_value: Label
var hunger_value: Label
var stamina_value: Label
var time_label: Label
var day_label: Label
var weather_label: Label
var quest_title: Label
var quest_desc: Label
var quest_step_label: Label
var boss_panel: PanelContainer
var boss_name_label: Label
var boss_value_label: Label
var boss_bar: ProgressBar
var hotbar_slots: Array[Button] = []
var inventory_slots: Array[Button] = []
var inventory_hotbar_slots: Array[Button] = []
var inventory_info: Label
var toast_panel: PanelContainer
var toast_label: Label
var prompt_panel: PanelContainer
var prompt_label: Label
var build_hint: Label
var craft_title: Label
var craft_resource_label: Label
var craft_rows: Array[Dictionary] = []
var build_rows: Array[Button] = []
var chest_slots: Array[Button] = []
var chest_deposit_slots: Array[Button] = []
var current_chest: PlacedBuilding
var continue_button: Button

var inventory_open := false
var craft_open := false
var build_open := false
var chest_open := false
var death_open := false
var pause_open := false
var _current_station := "hand"
var _selected_inventory_index := -1
var _toast_tween: Tween

func setup(p_game: Node, p_player: NaifrogPlayer, p_world: Node) -> void:
	game = p_game
	player = p_player
	world = p_world

func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	var theme := Theme.new()
	font = load("res://assets/fonts/NotoSansSC-Regular.ttf")
	if font:
		theme.default_font = font
	theme.default_font_size = 16
	root.theme = theme
	_build_gameplay()
	_build_title()
	_build_pause()
	_build_death()
	_build_inventory()
	_build_craft()
	_build_build_panel()
	_build_chest()
	_build_toast()
	_build_fade()

func _panel_style(bg := PANEL, border := Color(0.85, 0.75, 0.5, 0.35), radius := 16) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(1)
	s.set_corner_radius_all(radius)
	s.content_margin_left = 18
	s.content_margin_right = 18
	s.content_margin_top = 14
	s.content_margin_bottom = 14
	s.shadow_color = Color(0, 0, 0, 0.18)
	s.shadow_size = 8
	return s

func _btn_style(bg: Color, border: Color, radius := 12) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(1)
	s.set_corner_radius_all(radius)
	s.content_margin_left = 14
	s.content_margin_right = 14
	s.content_margin_top = 8
	s.content_margin_bottom = 8
	return s

func _label(text: String, size := 16, color := CREAM) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l

func _button(text: String, size := 16, callback: Callable = Callable()) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", size)
	b.add_theme_color_override("font_color", CREAM)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_stylebox_override("normal", _btn_style(Color(0.04, 0.14, 0.11, 0.9), Color(0.8, 0.7, 0.45, 0.4)))
	b.add_theme_stylebox_override("hover", _btn_style(Color(0.08, 0.23, 0.16, 0.98), Color(0.95, 0.8, 0.5, 0.9)))
	b.add_theme_stylebox_override("pressed", _btn_style(Color(0.025, 0.1, 0.08, 1), Color(1, 0.9, 0.6, 1)))
	b.add_theme_stylebox_override("disabled", _btn_style(Color(0.04, 0.1, 0.08, 0.55), Color(0.4, 0.4, 0.32, 0.3)))
	if callback.is_valid():
		b.pressed.connect(callback)
	return b

func _bar(fill: Color, bg: Color) -> ProgressBar:
	var b := ProgressBar.new()
	b.show_percentage = false
	b.custom_minimum_size = Vector2(0, 12)
	b.add_theme_stylebox_override("background", _btn_style(bg, Color(0, 0, 0, 0), 6))
	b.add_theme_stylebox_override("fill", _btn_style(fill, Color(0, 0, 0, 0), 6))
	return b

func _build_gameplay() -> void:
	gameplay_root = Control.new()
	gameplay_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	gameplay_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(gameplay_root)
	# stats
	var stats := PanelContainer.new()
	stats.add_theme_stylebox_override("panel", _panel_style())
	stats.position = Vector2(24, 24)
	stats.custom_minimum_size = Vector2(330, 0)
	gameplay_root.add_child(stats)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 7)
	stats.add_child(v)
	var h := HBoxContainer.new()
	v.add_child(h)
	var name_l := _label("奶蛙 · 林间状态", 19, CREAM)
	name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(name_l)
	day_label = _label("第 1 天", 13, Color(0.76, 0.84, 0.7, 0.8))
	h.add_child(day_label)
	_add_stat_row(v, "生命", "heart", Color("#8bd77a"), true)
	_add_stat_row(v, "饥饿", "berry", Color("#e3bb5b"), true)
	_add_stat_row(v, "体力", "leaf", Color("#7cc7b2"), true)
	# time/weather
	var tw := PanelContainer.new()
	tw.add_theme_stylebox_override("panel", _panel_style(PANEL_SOFT, Color(0.85, 0.75, 0.5, 0.25), 14))
	tw.set_anchors_preset(Control.PRESET_CENTER_TOP)
	tw.position = Vector2(-185, 24)
	tw.custom_minimum_size = Vector2(370, 0)
	gameplay_root.add_child(tw)
	var tv := VBoxContainer.new()
	tv.add_theme_constant_override("separation", 2)
	tw.add_child(tv)
	var th := HBoxContainer.new()
	th.alignment = BoxContainer.ALIGNMENT_CENTER
	th.add_theme_constant_override("separation", 12)
	tv.add_child(th)
	time_label = _label("08:00", 22, CREAM)
	th.add_child(time_label)
	weather_label = _label("晴朗", 14, MINT)
	th.add_child(weather_label)
	var clock_sub := _label("森林 · 第 1 天", 12, Color(0.8, 0.85, 0.74, 0.6))
	clock_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tv.add_child(clock_sub)
	day_label.text = "第 1 天"
	# quest
	var qp := PanelContainer.new()
	qp.add_theme_stylebox_override("panel", _panel_style(PANEL_SOFT, Color(0.85, 0.75, 0.5, 0.25), 14))
	qp.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	qp.position = Vector2(-350, 24)
	qp.custom_minimum_size = Vector2(326, 0)
	gameplay_root.add_child(qp)
	var qv := VBoxContainer.new()
	qv.add_theme_constant_override("separation", 4)
	qp.add_child(qv)
	var qh := HBoxContainer.new()
	qv.add_child(qh)
	qh.add_child(_label("当前目标", 13, GOLD))
	quest_step_label = _label("1 / 7", 12, Color(0.8, 0.85, 0.74, 0.6))
	quest_step_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	quest_step_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	qh.add_child(quest_step_label)
	quest_title = _label("在森林里醒来", 18, CREAM)
	qv.add_child(quest_title)
	quest_desc = _label("收集 5 根树枝。", 13, Color(0.78, 0.86, 0.75, 0.8))
	quest_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	quest_desc.custom_minimum_size = Vector2(290, 0)
	qv.add_child(quest_desc)
	# hotbar
	var hb := HBoxContainer.new()
	hb.name = "Hotbar"
	hb.add_theme_constant_override("separation", 6)
	hb.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	hb.position = Vector2(-250, -82)
	hb.custom_minimum_size = Vector2(500, 64)
	gameplay_root.add_child(hb)
	for i in 8:
		var b := Button.new()
		b.custom_minimum_size = Vector2(58, 58)
		b.add_theme_font_size_override("font_size", 12)
		b.pressed.connect(_on_hotbar_pressed.bind(i))
		hb.add_child(b)
		hotbar_slots.append(b)
	# prompt
	prompt_panel = PanelContainer.new()
	prompt_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.025, 0.08, 0.06, 0.92), Color(0.9, 0.78, 0.5, 0.6), 14))
	prompt_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	prompt_panel.position = Vector2(-260, -146)
	prompt_panel.custom_minimum_size = Vector2(520, 0)
	prompt_panel.visible = false
	gameplay_root.add_child(prompt_panel)
	prompt_label = _label("按 E 采集", 15, CREAM)
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_panel.add_child(prompt_label)
	build_hint = _label("建造模式：左键放置 · R 旋转 · X 拆除 · 右键取消", 14, GOLD)
	build_hint.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	build_hint.position = Vector2(-300, -172)
	build_hint.custom_minimum_size = Vector2(600, 24)
	build_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	build_hint.visible = false
	gameplay_root.add_child(build_hint)
	# boss bar sits above the prompt so it does not fight the quest card
	boss_panel = PanelContainer.new()
	boss_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.07, 0.06, 0.045, 0.94), Color(0.9, 0.65, 0.35, 0.7), 12))
	boss_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	boss_panel.position = Vector2(-235, -238)
	boss_panel.custom_minimum_size = Vector2(470, 0)
	boss_panel.visible = false
	gameplay_root.add_child(boss_panel)
	var bv := VBoxContainer.new()
	bv.add_theme_constant_override("separation", 4)
	boss_panel.add_child(bv)
	var bh := HBoxContainer.new()
	bv.add_child(bh)
	boss_name_label = _label("古树守护者", 15, GOLD)
	boss_name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bh.add_child(boss_name_label)
	boss_value_label = _label("", 13, CREAM)
	bh.add_child(boss_value_label)
	boss_bar = _bar(Color("#d77a4f"), Color(0.03, 0.07, 0.05, 0.95))
	boss_bar.max_value = 100
	boss_bar.value = 100
	bv.add_child(boss_bar)

func _add_stat_row(parent: VBoxContainer, name: String, _kind: String, color: Color, value: bool) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)
	var l := _label(name, 12, Color(0.8, 0.86, 0.76, 0.85))
	l.custom_minimum_size = Vector2(34, 0)
	row.add_child(l)
	var bar := _bar(color, Color(0.03, 0.09, 0.07, 0.9))
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(bar)
	var val := _label("100", 14, CREAM)
	val.custom_minimum_size = Vector2(38, 0)
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(val)
	if name == "生命": health_bar = bar; health_value = val
	elif name == "饥饿": hunger_bar = bar; hunger_value = val
	else: stamina_bar = bar; stamina_value = val

func _build_title() -> void:
	title_root = Control.new()
	title_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	title_root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(title_root)
	var scrim := ColorRect.new()
	scrim.color = Color(0.015, 0.05, 0.04, 0.58)
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	title_root.add_child(scrim)
	var panel := VBoxContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	panel.position = Vector2(110, -230)
	panel.custom_minimum_size = Vector2(520, 0)
	title_root.add_child(panel)
	var tag := _label("A FOREST SANDBOX SURVIVAL", 13, GOLD)
	panel.add_child(tag)
	var title := _label("奶蛙", 74, CREAM)
	title.add_theme_constant_override("outline_size", 3)
	panel.add_child(title)
	var sub := _label("林间新生", 35, GOLD)
	panel.add_child(sub)
	var line := HSeparator.new()
	line.custom_minimum_size = Vector2(0, 16)
	panel.add_child(line)
	var desc := _label("一场风暴后，奶蛙在陌生的森林里醒来。\n采集、制作、建造，和这片森林一起生活下去。", 17, Color(0.85, 0.9, 0.8, 0.92))
	panel.add_child(desc)
	var gap := Control.new(); gap.custom_minimum_size = Vector2(0, 16); panel.add_child(gap)
	var new_b := _button("新游戏", 18, func(): new_game_requested.emit())
	new_b.custom_minimum_size = Vector2(220, 50)
	panel.add_child(new_b)
	continue_button = _button("继续游戏", 18, func(): continue_requested.emit())
	continue_button.custom_minimum_size = Vector2(220, 50)
	panel.add_child(continue_button)
	var quit_b := _button("退出", 16, func(): quit_requested.emit())
	quit_b.custom_minimum_size = Vector2(220, 44)
	panel.add_child(quit_b)
	var info := _label("WASD 移动 · 鼠标左键 使用工具/攻击 · E 互动 · C 制作 · B 建造 · Tab 背包", 13, Color(0.8, 0.86, 0.75, 0.7))
	panel.add_child(info)
	var ver := _label("Godot 4.7.2 · v2.0 Forest Rebuild", 11, Color(0.7, 0.78, 0.68, 0.5))
	panel.add_child(ver)
	title_root.visible = false

func _build_pause() -> void:
	pause_root = Control.new()
	pause_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pause_root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(pause_root)
	var scrim := ColorRect.new(); scrim.color = Color(0.01, 0.04, 0.03, 0.68)
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pause_root.add_child(scrim)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _panel_style())
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-200, -180)
	panel.custom_minimum_size = Vector2(400, 0)
	pause_root.add_child(panel)
	var v := VBoxContainer.new(); v.add_theme_constant_override("separation", 12)
	panel.add_child(v)
	v.add_child(_label("暂停", 34, GOLD))
	var resume_b := _button("继续", 18, func(): resume_requested.emit()); v.add_child(resume_b)
	var save_b := _button("保存游戏", 18, func(): save_requested.emit()); v.add_child(save_b)
	var title_b := _button("返回标题", 16, func(): title_requested.emit()); v.add_child(title_b)
	var quit_b := _button("退出", 16, func(): quit_requested.emit()); v.add_child(quit_b)
	pause_root.visible = false

func _build_death() -> void:
	death_root = Control.new()
	death_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	death_root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(death_root)
	var scrim := ColorRect.new(); scrim.color = Color(0.15, 0.04, 0.03, 0.58)
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	death_root.add_child(scrim)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _panel_style(Color(0.16, 0.06, 0.05, 0.95), Color(0.85, 0.45, 0.35, 0.6), 18))
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-230, -130)
	panel.custom_minimum_size = Vector2(460, 0)
	death_root.add_child(panel)
	var v := VBoxContainer.new(); v.add_theme_constant_override("separation", 14)
	panel.add_child(v)
	v.add_child(_label("奶蛙倒下了", 34, Color("#ffb18e")))
	var d := _label("森林会记住你的位置。部分物资会掉在倒下的地方。", 14, CREAM)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(d)
	var b := _button("在营地醒来", 18, func(): death_respawn_requested.emit())
	b.custom_minimum_size = Vector2(220, 50)
	v.add_child(b)
	death_root.visible = false

func _build_inventory() -> void:
	inventory_root = Control.new()
	inventory_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	inventory_root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(inventory_root)
	var scrim := ColorRect.new(); scrim.color = Color(0.01, 0.04, 0.03, 0.7)
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	inventory_root.add_child(scrim)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _panel_style())
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-370, -270)
	panel.custom_minimum_size = Vector2(740, 0)
	inventory_root.add_child(panel)
	var v := VBoxContainer.new(); v.add_theme_constant_override("separation", 10)
	panel.add_child(v)
	var h := HBoxContainer.new(); v.add_child(h)
	var title := _label("背包", 30, GOLD)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(title)
	var close := _button("×", 24, func(): close_all_panels())
	close.custom_minimum_size = Vector2(42, 38)
	h.add_child(close)
	var grid := GridContainer.new()
	grid.columns = 6
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	v.add_child(grid)
	for i in 24:
		var b := Button.new()
		b.custom_minimum_size = Vector2(78, 66)
		b.add_theme_font_size_override("font_size", 12)
		b.pressed.connect(_on_inventory_slot_pressed.bind(i))
		grid.add_child(b)
		inventory_slots.append(b)
	v.add_child(HSeparator.new())
	var hb := HBoxContainer.new(); hb.add_theme_constant_override("separation", 6)
	v.add_child(hb)
	for i in 8:
		var b := Button.new()
		b.custom_minimum_size = Vector2(58, 52)
		b.add_theme_font_size_override("font_size", 11)
		b.pressed.connect(_on_hotbar_pressed.bind(i))
		hb.add_child(b)
		inventory_hotbar_slots.append(b)
	inventory_info = _label("点击槽位：装备到快捷栏。点击快捷栏选择当前工具。", 13, Color(0.8, 0.86, 0.75, 0.7))
	v.add_child(inventory_info)
	inventory_root.visible = false

func _build_craft() -> void:
	craft_root = Control.new()
	craft_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	craft_root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(craft_root)
	var scrim := ColorRect.new(); scrim.color = Color(0.01, 0.04, 0.03, 0.7)
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	craft_root.add_child(scrim)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _panel_style())
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-370, -300)
	panel.custom_minimum_size = Vector2(740, 0)
	craft_root.add_child(panel)
	var v := VBoxContainer.new(); v.add_theme_constant_override("separation", 7)
	panel.add_child(v)
	var h := HBoxContainer.new(); v.add_child(h)
	craft_title = _label("制作 · 手工", 28, GOLD)
	craft_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(craft_title)
	var close := _button("×", 24, func(): close_all_panels())
	close.custom_minimum_size = Vector2(42, 38)
	h.add_child(close)
	craft_resource_label = _label("", 13, Color(0.82, 0.88, 0.76, 0.8))
	v.add_child(craft_resource_label)
	v.add_child(HSeparator.new())
	for id in GameDB.recipe_order:
		var recipe: RecipeData = GameDB.recipe(id)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		v.add_child(row)
		var name := _label("%s  ×%d" % [recipe.display_name, recipe.output_count], 16, CREAM)
		name.custom_minimum_size = Vector2(150, 0)
		row.add_child(name)
		var cost := _label(_cost_text(recipe.costs), 12, Color(0.78, 0.84, 0.72, 0.78))
		cost.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(cost)
		var b := _button("制作", 14, func(): recipe_craft_requested.emit(id))
		b.custom_minimum_size = Vector2(84, 36)
		row.add_child(b)
		craft_rows.append({"id": id, "button": b, "recipe": recipe})
	craft_root.visible = false

func _build_build_panel() -> void:
	build_root = Control.new()
	build_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	build_root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(build_root)
	var scrim := ColorRect.new(); scrim.color = Color(0.01, 0.04, 0.03, 0.7)
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	build_root.add_child(scrim)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _panel_style())
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-370, -285)
	panel.custom_minimum_size = Vector2(740, 0)
	build_root.add_child(panel)
	var v := VBoxContainer.new(); v.add_theme_constant_override("separation", 9)
	panel.add_child(v)
	var h := HBoxContainer.new(); v.add_child(h)
	var title := _label("建造", 30, GOLD)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(title)
	var close := _button("×", 24, func(): close_all_panels())
	close.custom_minimum_size = Vector2(42, 38)
	h.add_child(close)
	v.add_child(_label("选择建筑件，然后在地面上放置。需要足够的材料。", 13, Color(0.82, 0.88, 0.78, 0.8)))
	var grid := GridContainer.new(); grid.columns = 3
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 10)
	v.add_child(grid)
	for id in GameDB.building_order:
		var data: BuildingData = GameDB.building(id)
		var b := _button("%s\n%s" % [data.display_name, _cost_text(data.cost)], 14, func(): building_selected.emit(id))
		b.custom_minimum_size = Vector2(210, 64)
		grid.add_child(b)
		build_rows.append(b)
	build_root.visible = false

func _build_toast() -> void:
	toast_panel = PanelContainer.new()
	toast_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.025, 0.1, 0.08, 0.94), Color(0.9, 0.78, 0.5, 0.45), 14))
	toast_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	toast_panel.position = Vector2(-320, 126)
	toast_panel.custom_minimum_size = Vector2(640, 0)
	toast_panel.modulate.a = 0.0
	gameplay_root.add_child(toast_panel)
	toast_label = _label("", 17, CREAM)
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	toast_panel.add_child(toast_label)

func _build_chest() -> void:
	chest_root = Control.new()
	chest_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	chest_root.mouse_filter = Control.MOUSE_FILTER_STOP
	chest_root.visible = false
	root.add_child(chest_root)
	var scrim := ColorRect.new()
	scrim.color = Color(0.01, 0.025, 0.018, 0.55)
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	chest_root.add_child(scrim)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _panel_style(PANEL, Color(0.85, 0.75, 0.5, 0.5), 18))
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-385, -340)
	panel.custom_minimum_size = Vector2(770, 0)
	chest_root.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 9)
	panel.add_child(v)
	var top := HBoxContainer.new()
	v.add_child(top)
	var title := _label("储物箱", 28, GOLD)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)
	var close := _button("×", 22, close_all_panels)
	close.custom_minimum_size = Vector2(48, 42)
	top.add_child(close)
	v.add_child(_label("箱内物品（点击取出）", 13, Color(0.8, 0.86, 0.76, 0.8)))
	var cg := GridContainer.new()
	cg.columns = 6
	cg.add_theme_constant_override("h_separation", 7)
	cg.add_theme_constant_override("v_separation", 7)
	v.add_child(cg)
	for i in 12:
		var b := _button("", 12, _on_chest_slot_pressed.bind(i))
		b.custom_minimum_size = Vector2(72, 56)
		cg.add_child(b)
		chest_slots.append(b)
	v.add_child(_label("背包（点击整格存入）", 13, Color(0.8, 0.86, 0.76, 0.8)))
	var dg := GridContainer.new()
	dg.columns = 6
	dg.add_theme_constant_override("h_separation", 7)
	dg.add_theme_constant_override("v_separation", 7)
	v.add_child(dg)
	for i in 24:
		var b := _button("", 12, _on_chest_deposit_pressed.bind(i))
		b.custom_minimum_size = Vector2(72, 52)
		dg.add_child(b)
		chest_deposit_slots.append(b)
	var hint := _label("箱子 12 格；点击背包整格存入，点击箱内物品取出。", 12, MINT)
	v.add_child(hint)

func _refresh_chest() -> void:
	if current_chest == null or player == null:
		return
	for i in 12:
		var s = current_chest.storage[i] if i < current_chest.storage.size() else null
		_style_slot(chest_slots[i], s, false, i)
		chest_slots[i].disabled = s == null
	for i in 24:
		var s = player.inventory.slots[i]
		_style_slot(chest_deposit_slots[i], s, false, i)
		chest_deposit_slots[i].disabled = s == null

func _on_chest_slot_pressed(i: int) -> void:
	if current_chest == null or i >= current_chest.storage.size():
		return
	var s = current_chest.storage[i]
	var left := player.inventory.add_item(str(s["id"]), int(s["amount"]))
	if left <= 0:
		current_chest.storage.remove_at(i)
	else:
		s["amount"] = left
	_refresh_chest()
	player.inventory.changed.emit()

func _on_chest_deposit_pressed(i: int) -> void:
	if current_chest == null or player == null:
		return
	var s = player.inventory.slots[i]
	if s == null:
		return
	var left := current_chest.add_to_storage(str(s["id"]), int(s["amount"]))
	var put := int(s["amount"]) - left
	if put > 0:
		player.inventory.remove_item(str(s["id"]), put)
	_refresh_chest()

func _build_fade() -> void:
	fade_rect = ColorRect.new()
	fade_rect.color = Color(0.01, 0.02, 0.015, 0.0)
	fade_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(fade_rect)

# ---------------- public API ----------------

func show_title() -> void:
	get_tree().paused = false
	title_root.visible = true
	gameplay_root.visible = false
	pause_root.visible = false
	death_root.visible = false
	inventory_root.visible = false
	craft_root.visible = false
	build_root.visible = false
	if chest_root: chest_root.visible = false
	inventory_open = false; craft_open = false; build_open = false; chest_open = false; death_open = false; pause_open = false
	if boss_panel: boss_panel.visible = false
	continue_button.disabled = not SaveManager.has_save()
	fade_rect.color.a = 0.0

func begin_game() -> void:
	title_root.visible = false
	gameplay_root.visible = true
	pause_root.visible = false
	death_root.visible = false
	inventory_root.visible = false
	craft_root.visible = false
	build_root.visible = false
	if chest_root: chest_root.visible = false
	_fade_in()
	hide_boss()
	_reconnect_inventory()
	refresh_inventory()
	update_stats()
	update_world_info(game.day, game.hour, game.weather)
	set_quest(game.quest_step, "探索森林", "先看看周围有什么。", game.quest_step)
	show_toast("WASD 移动，靠近树枝按 E 采集。", 3.4)

func show_pause() -> void:
	pause_root.visible = true
	pause_open = true
func hide_pause() -> void:
	pause_root.visible = false
	pause_open = false

func show_death(reason := "") -> void:
	death_open = true
	chest_open = false
	if chest_root: chest_root.visible = false
	hide_boss()
	death_root.visible = true
	gameplay_root.visible = false
	if reason != "":
		var label := death_root.find_child("Reason", true, false)
		if label == null:
			pass

func hide_death() -> void:
	death_open = false
	death_root.visible = false
	gameplay_root.visible = true

func update_stats() -> void:
	if player == null or player.survival == null:
		return
	var s := player.survival
	health_bar.value = s.health
	hunger_bar.value = s.hunger
	stamina_bar.value = s.stamina
	health_value.text = str(int(round(s.health)))
	hunger_value.text = str(int(round(s.hunger)))
	stamina_value.text = str(int(round(s.stamina)))

func update_world_info(day: int, hour: float, weather: String) -> void:
	time_label.text = GameUtil.format_time(hour)
	day_label.text = "第 %d 天" % day
	var names := {"clear": "晴朗", "rain": "降雨", "fog": "浓雾"}
	weather_label.text = names.get(weather, weather)
	weather_label.add_theme_color_override("font_color", Color("#a9d2e2") if weather == "rain" else (Color("#c7ccc0") if weather == "fog" else MINT))

func set_quest(step: int, title: String, desc: String, total_step := 0) -> void:
	if quest_title == null:
		return
	quest_title.text = title
	quest_desc.text = desc
	quest_step_label.text = "%d / 7" % mini(step + 1, 7)

func show_toast(text: String, duration := 2.6) -> void:
	if toast_label == null:
		return
	toast_label.text = text
	toast_panel.modulate.a = 1.0
	if _toast_tween and _toast_tween.is_valid():
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_interval(maxf(1.0, duration))
	_toast_tween.tween_property(toast_panel, "modulate:a", 0.0, 0.5)

func set_prompt(text: String) -> void:
	if prompt_panel == null:
		return
	prompt_panel.visible = text != ""
	prompt_label.text = text

func set_build_hint(active: bool, text := "") -> void:
	build_hint.visible = active
	if active and text != "":
		build_hint.text = text

func show_boss(name_text: String) -> void:
	if boss_panel:
		boss_name_label.text = name_text
		boss_panel.visible = true

func update_boss(health: float, max_health: float) -> void:
	if boss_panel == null:
		return
	boss_bar.max_value = maxf(1.0, max_health)
	boss_bar.value = clampf(health, 0.0, max_health)
	boss_value_label.text = "%d / %d" % [int(round(health)), int(round(max_health))]

func hide_boss() -> void:
	if boss_panel:
		boss_panel.visible = false

func any_panel_open() -> bool:
	return inventory_open or craft_open or build_open or chest_open or pause_open

func toggle_inventory() -> void:
	if inventory_open:
		close_all_panels()
		return
	close_all_panels()
	set_prompt("")
	inventory_open = true
	inventory_root.visible = true
	gameplay_root.visible = true
	refresh_inventory()

func open_craft(station := "hand") -> void:
	close_all_panels()
	set_prompt("")
	_current_station = station
	craft_open = true
	craft_root.visible = true
	gameplay_root.visible = true
	craft_title.text = "制作 · %s" % {"hand": "手工", "campfire": "营火", "workbench": "木工台"}.get(station, station)
	refresh_craft()

func open_build() -> void:
	close_all_panels()
	set_prompt("")
	build_open = true
	build_root.visible = true
	gameplay_root.visible = true
	_refresh_build_buttons()

func open_chest(chest: PlacedBuilding) -> void:
	close_all_panels()
	set_prompt("")
	current_chest = chest
	chest_open = true
	chest_root.visible = true
	gameplay_root.visible = true
	_refresh_chest()

func close_all_panels() -> void:
	inventory_open = false; craft_open = false; build_open = false; chest_open = false
	if inventory_root: inventory_root.visible = false
	if craft_root: craft_root.visible = false
	if build_root: build_root.visible = false
	if chest_root: chest_root.visible = false
	if chest_root: chest_root.visible = false
	current_chest = null
	if pause_root: pause_root.visible = false
	pause_open = false
	set_build_hint(false)
	if gameplay_root:
		gameplay_root.visible = game != null and game.state != 0 and not death_open
	panels_closed.emit()

func refresh_inventory() -> void:
	_reconnect_inventory()
	_update_slots()
	_update_craft_buttons()

func refresh_craft() -> void:
	_update_craft_buttons()
	if craft_resource_label:
		craft_resource_label.text = "背包：%s" % _resource_summary()

func update_build_station_hint() -> void:
	if craft_open:
		refresh_craft()

func _reconnect_inventory() -> void:
	if player == null or player.inventory == null:
		return
	if not player.inventory.changed.is_connected(_on_inventory_signal):
		player.inventory.changed.connect(_on_inventory_signal)
	if not player.inventory.selection_changed.is_connected(_on_selection_signal):
		player.inventory.selection_changed.connect(_on_selection_signal)

func _on_inventory_signal() -> void:
	_update_slots()
	_update_craft_buttons()
func _on_selection_signal(_i: int) -> void:
	_update_slots()

func _update_slots() -> void:
	if player == null or player.inventory == null:
		return
	for i in mini(hotbar_slots.size(), 8):
		_style_slot(hotbar_slots[i], player.inventory.slots[i], player.inventory.selected_index == i, i)
	for i in mini(inventory_slots.size(), 24):
		_style_slot(inventory_slots[i], player.inventory.slots[i], player.inventory.selected_index == i, i)
	for i in mini(inventory_hotbar_slots.size(), 8):
		_style_slot(inventory_hotbar_slots[i], player.inventory.slots[i], player.inventory.selected_index == i, i)

func _style_slot(b: Button, stack, selected: bool, index: int) -> void:
	var bg := Color(0.035, 0.1, 0.075, 0.95)
	var border := GOLD if selected else Color(0.8, 0.72, 0.48, 0.28)
	b.text = ""
	b.tooltip_text = "空"
	if stack != null:
		var item: ItemData = GameDB.item(stack["id"])
		if item:
			b.text = "%s\n%d" % [item.icon_glyph, int(stack["amount"])]
			b.tooltip_text = "%s\n%s" % [item.display_name, item.description]
			bg = item.icon_color.darkened(0.55)
	b.add_theme_color_override("font_color", CREAM)
	b.add_theme_stylebox_override("normal", _btn_style(bg, border, 8))
	b.add_theme_stylebox_override("hover", _btn_style(bg.lightened(0.1), GOLD, 8))
	b.add_theme_stylebox_override("pressed", _btn_style(bg.darkened(0.1), GOLD, 8))

func _update_craft_buttons() -> void:
	if craft_rows.is_empty():
		return
	for entry in craft_rows:
		var r: RecipeData = entry["recipe"]
		var b: Button = entry["button"]
		var can_station: bool = game != null and bool(game._can_use_station(r.station))
		var can_cost: bool = player != null and player.inventory.has_costs(r.costs)
		b.disabled = not (can_station and can_cost)
		b.text = "制作" if can_station and can_cost else ("缺材料" if not can_cost else "需要站点")
	if craft_resource_label:
		craft_resource_label.text = "背包：%s" % _resource_summary()

func _refresh_build_buttons() -> void:
	for i in mini(build_rows.size(), GameDB.building_order.size()):
		var id: String = GameDB.building_order[i]
		var data: BuildingData = GameDB.building(id)
		var b := build_rows[i]
		var afford := player != null and player.inventory.has_costs(data.cost)
		b.disabled = not afford
		b.text = "%s\n%s" % [data.display_name, _cost_text(data.cost)]
		b.modulate = Color.WHITE if afford else Color(0.65, 0.68, 0.62, 0.65)

func _on_hotbar_pressed(i: int) -> void:
	if player:
		player.inventory.select(i)
		inventory_changed.emit(i)

func _on_inventory_slot_pressed(i: int) -> void:
	if player == null:
		return
	if i < 8:
		player.inventory.select(i)
		inventory_changed.emit(i)
	elif i < 24:
		var sel := player.inventory.selected_index
		var tmp = player.inventory.slots[sel]
		player.inventory.slots[sel] = player.inventory.slots[i]
		player.inventory.slots[i] = tmp
		player.inventory.changed.emit()
		player.inventory.select(sel)

func _cost_text(costs: Dictionary) -> String:
	var parts: Array[String] = []
	for id in costs:
		parts.append("%s ×%d" % [GameDB.item_name(id), int(costs[id])])
	return " · ".join(parts)

func _resource_summary() -> String:
	if player == null:
		return ""
	var ids := ["wood", "stone", "fiber", "branch", "berry", "mushroom"]
	var parts: Array[String] = []
	for id in ids:
		parts.append("%s %d" % [GameDB.item_name(id), player.inventory.count_item(id)])
	return "   ".join(parts)

func _fade_in() -> void:
	fade_rect.color.a = 0.6
	var tw := create_tween()
	tw.tween_property(fade_rect, "color:a", 0.0, 0.65)

func _fade_out() -> void:
	var tw := create_tween()
	tw.tween_property(fade_rect, "color:a", 1.0, 0.5)

func _unhandled_input(_event: InputEvent) -> void:
	if not get_tree().paused:
		return
	if _event.is_action_pressed("pause"):
		if pause_open and game:
			game.resume_game()
			get_viewport().set_input_as_handled()
		elif any_panel_open():
			close_all_panels()
			get_viewport().set_input_as_handled()
		return
	if inventory_open and _event.is_action_pressed("inventory"):
		close_all_panels()
		get_viewport().set_input_as_handled()
	elif craft_open and _event.is_action_pressed("craft"):
		close_all_panels()
		get_viewport().set_input_as_handled()
	elif build_open and _event.is_action_pressed("build"):
		close_all_panels()
		get_viewport().set_input_as_handled()
