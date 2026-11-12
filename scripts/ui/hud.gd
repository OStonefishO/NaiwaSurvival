class_name GameHUD
extends CanvasLayer

signal start_game_requested
signal restart_requested
signal resume_requested
signal title_requested
signal quit_requested
signal pause_toggle_requested

var game: Node
var player: MilkFrog
var world: IslandWorld
var font: Font
var theme: Theme
var root: Control
var gameplay_root: Control
var menu_root: Control
var pause_root: Control
var end_root: Control
var touch: TouchControls

var health_bar: ProgressBar
var hunger_bar: ProgressBar
var health_value: Label
var hunger_value: Label
var wood_label: Label
var coin_label: Label
var map_label: Label
var stone_label: Label
var fiber_label: Label
var day_phase_label: Label
var build_button: Button
var craft_root: Control
var craft_panel: PanelContainer
var craft_status: Label
var craft_resource_label: Label
var craft_buttons: Dictionary = {}
var craft_open := false
var objective_title: Label
var objective_sub: Label
var prompt_panel: PanelContainer
var prompt_label: Label
var toast_label: Label
var toast_panel: PanelContainer
var minimap: MinimapView
var damage_rect: ColorRect
var damage_mat: ShaderMaterial
var damage_pulse := 0.0
var low_health := 0.0
var hint_label: Label
var title_controls: PanelContainer
var start_button: Button
var pause_button: Button
var is_paused := false
var end_title: Label
var end_sub: Label
var end_stats: Label
var touch_mode := false
var fade_rect: ColorRect
var boss_panel: PanelContainer
var boss_bar: ProgressBar
var boss_label: Label

const CREAM := Color("#f9e9c3")
const GOLD := Color("#f0c56a")
const INK := Color("#08292d")
const RED := Color("#e3654c")
const GREEN := Color("#8fdf7e")

func setup(p_game: Node, p_player: MilkFrog, p_world: IslandWorld) -> void:
	game = p_game
	player = p_player
	world = p_world

func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	font = load("res://assets/fonts/NotoSansSC-Regular.ttf")
	_build_theme()
	root = Control.new()
	root.name = "UIRoot"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.theme = theme
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_build_gameplay()
	_build_menu()
	_build_craft()
	_build_pause()
	_build_end()
	_build_vignette()
	_build_fade()
	_connect_player()
	show_title()

func _build_theme() -> void:
	theme = Theme.new()
	theme.default_font = font
	theme.default_font_size = 18
	theme.set_color("font_color", "Label", CREAM)
	theme.set_color("font_color", "Button", CREAM)
	theme.set_color("font_hover_color", "Button", Color("#fff6d8"))
	theme.set_color("font_pressed_color", "Button", Color("#ffe6a3"))
	theme.set_stylebox("normal", "Button", _btn_style(Color(0.03, 0.15, 0.16, 0.86), Color(0.95, 0.78, 0.45, 0.45), 14))
	theme.set_stylebox("hover", "Button", _btn_style(Color(0.07, 0.24, 0.23, 0.94), Color(1.0, 0.85, 0.55, 0.8), 14))
	theme.set_stylebox("pressed", "Button", _btn_style(Color(0.02, 0.1, 0.11, 0.96), Color(1.0, 0.9, 0.65, 0.95), 14))
	theme.set_stylebox("focus", "Button", _btn_style(Color(0, 0, 0, 0), Color(1.0, 0.86, 0.5, 0.9), 14, 2))
	theme.set_font_size("font_size", "Button", 22)

func _connect_player() -> void:
	if player:
		player.stats_changed.connect(set_player_stats)
		player.prompt_changed.connect(set_prompt)

func _btn_style(bg: Color, border: Color, radius: int, border_width := 1) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(border_width)
	s.set_corner_radius_all(radius)
	s.content_margin_left = 20
	s.content_margin_right = 20
	s.content_margin_top = 10
	s.content_margin_bottom = 10
	s.anti_aliasing = true
	return s

func _panel_style(bg := Color(0.025, 0.12, 0.13, 0.86), border := Color(0.91, 0.76, 0.46, 0.32), radius := 18) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(1)
	s.set_corner_radius_all(radius)
	s.content_margin_left = 16
	s.content_margin_right = 16
	s.content_margin_top = 12
	s.content_margin_bottom = 12
	s.shadow_color = Color(0, 0, 0, 0.35)
	s.shadow_size = 8
	s.anti_aliasing = true
	return s

func _label(text: String, size := 18, color := CREAM) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l

func _icon(kind: HUDIcon.Kind, size := 26, color := Color.WHITE) -> HUDIcon:
	var i := HUDIcon.new()
	i.kind = kind
	i.tint = color
	i.custom_minimum_size = Vector2(size, size)
	i.size = Vector2(size, size)
	return i

func _build_gameplay() -> void:
	gameplay_root = Control.new()
	gameplay_root.name = "GameplayHUD"
	gameplay_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	gameplay_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(gameplay_root)

	var stats := PanelContainer.new()
	stats.name = "StatsPanel"
	stats.add_theme_stylebox_override("panel", _panel_style(Color(0.025, 0.12, 0.13, 0.84), Color(0.91, 0.76, 0.46, 0.3)))
	stats.position = Vector2(26, 24)
	stats.custom_minimum_size = Vector2(342, 0)
	gameplay_root.add_child(stats)
	var sv := VBoxContainer.new()
	sv.add_theme_constant_override("separation", 8)
	stats.add_child(sv)
	var top := HBoxContainer.new()
	sv.add_child(top)
	top.add_child(_icon(HUDIcon.Kind.SKULL, 24, GOLD))
	var name_l := _label("奶蛙 · 生存状态", 18, CREAM)
	name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(name_l)
	day_phase_label = _label("海盗湾 · 黄昏", 14, Color(0.72, 0.78, 0.66, 0.8))
	top.add_child(day_phase_label)

	var health_row := HBoxContainer.new()
	health_row.add_theme_constant_override("separation", 8)
	sv.add_child(health_row)
	health_row.add_child(_icon(HUDIcon.Kind.HEART, 24, RED))
	var hb_wrap := VBoxContainer.new()
	hb_wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	health_row.add_child(hb_wrap)
	hb_wrap.add_child(_label("生命", 13, Color(0.82, 0.85, 0.73, 0.85)))
	health_bar = _make_bar(Color("#8fdf7e"), Color("#16332b"))
	hb_wrap.add_child(health_bar)
	health_value = _label("100", 17, CREAM)
	health_value.custom_minimum_size = Vector2(44, 0)
	health_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	health_row.add_child(health_value)

	var hunger_row := HBoxContainer.new()
	hunger_row.add_theme_constant_override("separation", 8)
	sv.add_child(hunger_row)
	hunger_row.add_child(_icon(HUDIcon.Kind.COCONUT, 24, Color("#ffd36b")))
	var ub_wrap := VBoxContainer.new()
	ub_wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hunger_row.add_child(ub_wrap)
	ub_wrap.add_child(_label("饱腹", 13, Color(0.82, 0.85, 0.73, 0.85)))
	hunger_bar = _make_bar(Color("#f3c750"), Color("#3b2f18"))
	ub_wrap.add_child(hunger_bar)
	hunger_value = _label("100", 17, CREAM)
	hunger_value.custom_minimum_size = Vector2(44, 0)
	hunger_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hunger_row.add_child(hunger_value)

	sv.add_child(HSeparator.new())
	var res := HBoxContainer.new()
	res.add_theme_constant_override("separation", 11)
	sv.add_child(res)
	var wood_group := HBoxContainer.new(); wood_group.add_theme_constant_override("separation", 4); res.add_child(wood_group)
	wood_group.add_child(_icon(HUDIcon.Kind.WOOD, 19, Color("#d8a363")))
	wood_label = _label("0", 15, CREAM); wood_group.add_child(wood_label)
	var stone_group := HBoxContainer.new(); stone_group.add_theme_constant_override("separation", 4); res.add_child(stone_group)
	stone_group.add_child(_icon(HUDIcon.Kind.STONE, 19, Color("#c1b8a6")))
	stone_label = _label("0", 15, CREAM); stone_group.add_child(stone_label)
	var fiber_group := HBoxContainer.new(); fiber_group.add_theme_constant_override("separation", 4); res.add_child(fiber_group)
	fiber_group.add_child(_icon(HUDIcon.Kind.FIBER, 19, Color("#9cc96d")))
	fiber_label = _label("0", 15, CREAM); fiber_group.add_child(fiber_label)
	var coin_group := HBoxContainer.new(); coin_group.add_theme_constant_override("separation", 4); res.add_child(coin_group)
	coin_group.add_child(_icon(HUDIcon.Kind.COIN, 19, Color("#ffd35c")))
	coin_label = _label("0", 15, CREAM); coin_group.add_child(coin_label)
	var map_group := HBoxContainer.new(); map_group.add_theme_constant_override("separation", 4); res.add_child(map_group)
	map_group.add_child(_icon(HUDIcon.Kind.MAP, 19, Color("#f4dfb0")))
	map_label = _label("0/3", 15, GOLD); map_group.add_child(map_label)

	var obj_panel := PanelContainer.new()
	obj_panel.name = "ObjectivePanel"
	obj_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.025, 0.12, 0.13, 0.78), Color(0.91, 0.76, 0.46, 0.25), 16))
	obj_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	obj_panel.position = Vector2(-260, 24)
	obj_panel.custom_minimum_size = Vector2(520, 0)
	gameplay_root.add_child(obj_panel)
	var ov := VBoxContainer.new()
	ov.add_theme_constant_override("separation", 2)
	obj_panel.add_child(ov)
	objective_title = _label("寻回 0/3 张藏宝图", 20, GOLD)
	objective_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ov.add_child(objective_title)
	objective_sub = _label("打开岛上的宝箱，然后登上山顶点燃信号火", 13, Color(0.8, 0.84, 0.73, 0.82))
	objective_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ov.add_child(objective_sub)

	var map_panel := PanelContainer.new()
	map_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.025, 0.12, 0.13, 0.8), Color(0.91, 0.76, 0.46, 0.3), 20))
	map_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	map_panel.position = Vector2(-224, 74)
	map_panel.custom_minimum_size = Vector2(198, 226)
	gameplay_root.add_child(map_panel)
	var mv := VBoxContainer.new()
	mv.add_theme_constant_override("separation", 2)
	map_panel.add_child(mv)
	var mh := HBoxContainer.new()
	mv.add_child(mh)
	var ml := _label("海盗湾", 15, GOLD)
	ml.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mh.add_child(ml)
	mh.add_child(_label("N", 12, Color(0.8, 0.85, 0.7, 0.6)))
	minimap = MinimapView.new()
	minimap.custom_minimum_size = Vector2(174, 174)
	minimap.setup(game, world, player)
	mv.add_child(minimap)
	var mfoot := _label("◆ 宝箱   ● 信号火 / 营地", 11, Color(0.75, 0.8, 0.68, 0.6))
	mfoot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mv.add_child(mfoot)

	pause_button = Button.new()
	pause_button.name = "PauseButton"
	pause_button.text = ""
	pause_button.tooltip_text = "暂停"
	pause_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	pause_button.position = Vector2(-74, 24)
	pause_button.custom_minimum_size = Vector2(48, 48)
	pause_button.add_theme_stylebox_override("normal", _btn_style(Color(0.03, 0.15, 0.16, 0.82), Color(0.91, 0.76, 0.46, 0.4), 14))
	pause_button.add_theme_stylebox_override("hover", _btn_style(Color(0.07, 0.24, 0.23, 0.95), Color(1.0, 0.85, 0.55, 0.8), 14))
	pause_button.add_theme_stylebox_override("pressed", _btn_style(Color(0.02, 0.1, 0.11, 0.96), Color(1, 0.9, 0.65, 0.95), 14))
	pause_button.pressed.connect(_on_pause_pressed)
	gameplay_root.add_child(pause_button)
	var pi := HUDIcon.new()
	pi.kind = HUDIcon.Kind.PAUSE
	pi.tint = CREAM
	pi.position = Vector2(11, 11)
	pi.size = Vector2(26, 26)
	pi.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pause_button.add_child(pi)

	build_button = Button.new()
	build_button.name = "BuildButton"
	build_button.text = "建造 B"
	build_button.tooltip_text = "建造与制作 (B)"
	build_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	build_button.position = Vector2(-192, 24)
	build_button.custom_minimum_size = Vector2(108, 48)
	build_button.add_theme_font_size_override("font_size", 17)
	build_button.add_theme_stylebox_override("normal", _btn_style(Color(0.03, 0.15, 0.16, 0.82), Color(0.91, 0.76, 0.46, 0.4), 14))
	build_button.add_theme_stylebox_override("hover", _btn_style(Color(0.07, 0.24, 0.23, 0.95), Color(1.0, 0.85, 0.55, 0.8), 14))
	build_button.add_theme_stylebox_override("pressed", _btn_style(Color(0.02, 0.1, 0.11, 0.96), Color(1, 0.9, 0.65, 0.95), 14))
	build_button.pressed.connect(_toggle_craft)
	gameplay_root.add_child(build_button)

	prompt_panel = PanelContainer.new()
	prompt_panel.name = "PromptPanel"
	prompt_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.02, 0.1, 0.11, 0.9), Color(0.95, 0.8, 0.5, 0.55), 16))
	prompt_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	prompt_panel.position = Vector2(-210, -104)
	prompt_panel.custom_minimum_size = Vector2(420, 0)
	prompt_panel.visible = false
	gameplay_root.add_child(prompt_panel)
	var ph := HBoxContainer.new()
	ph.alignment = BoxContainer.ALIGNMENT_CENTER
	prompt_panel.add_child(ph)
	var key := PanelContainer.new()
	key.add_theme_stylebox_override("panel", _btn_style(Color(0.92, 0.78, 0.48, 0.9), Color(0.55, 0.4, 0.2, 1), 7))
	key.custom_minimum_size = Vector2(30, 28)
	var kl := _label("E", 16, INK)
	kl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	kl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	key.add_child(kl)
	ph.add_child(key)
	prompt_label = _label("打开藏宝箱", 18, CREAM)
	prompt_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	ph.add_child(prompt_label)

	boss_panel = PanelContainer.new()
	boss_panel.name = "BossPanel"
	boss_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.08, 0.08, 0.07, 0.9), Color(0.85, 0.28, 0.2, 0.6), 14))
	boss_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	boss_panel.position = Vector2(-260, 104)
	boss_panel.custom_minimum_size = Vector2(520, 0)
	boss_panel.visible = false
	gameplay_root.add_child(boss_panel)
	var bv := VBoxContainer.new()
	bv.add_theme_constant_override("separation", 4)
	boss_panel.add_child(bv)
	boss_label = _label("骷髅船长 · 海盗湾的诅咒", 17, Color("#f2b28c"))
	boss_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bv.add_child(boss_label)
	boss_bar = _make_bar(Color("#d64c39"), Color("#31100f"))
	boss_bar.custom_minimum_size = Vector2(480, 12)
	boss_bar.value = 100
	bv.add_child(boss_bar)

	hint_label = _label("WASD 移动   ·   鼠标左键 挥刀   ·   Shift 冲刺   ·   E 互动   ·   B 建造", 14, Color(0.86, 0.88, 0.77, 0.7))
	hint_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	hint_label.position = Vector2(-380, -52)
	hint_label.custom_minimum_size = Vector2(760, 24)
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	gameplay_root.add_child(hint_label)

	toast_panel = PanelContainer.new()
	toast_panel.name = "ToastPanel"
	toast_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.02, 0.1, 0.11, 0.92), Color(0.95, 0.8, 0.5, 0.5), 16))
	toast_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	toast_panel.position = Vector2(-250, 120)
	toast_panel.custom_minimum_size = Vector2(500, 0)
	toast_panel.modulate.a = 0.0
	gameplay_root.add_child(toast_panel)
	toast_label = _label("", 18, CREAM)
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_panel.add_child(toast_label)

	touch = TouchControls.new()
	touch.setup(player)
	gameplay_root.add_child(touch)

	damage_rect = ColorRect.new()
	damage_rect.name = "DamageVignette"
	damage_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	damage_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	damage_mat = ShaderMaterial.new()
	damage_mat.shader = load("res://shaders/damage_vignette.gdshader")
	damage_rect.material = damage_mat
	gameplay_root.add_child(damage_rect)

	var corner := _label("▪ 海盗湾 · 诅咒之地", 12, Color(0.8, 0.82, 0.7, 0.4))
	corner.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	corner.position = Vector2(28, -28)
	gameplay_root.add_child(corner)

func _make_bar(fill: Color, bg: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(206, 14)
	bar.show_percentage = false
	bar.max_value = 100
	bar.value = 100
	var bg_s := StyleBoxFlat.new()
	bg_s.bg_color = bg
	bg_s.set_corner_radius_all(7)
	bar.add_theme_stylebox_override("background", bg_s)
	var fill_s := StyleBoxFlat.new()
	fill_s.bg_color = fill
	fill_s.set_corner_radius_all(7)
	bar.add_theme_stylebox_override("fill", fill_s)
	return bar

func _build_menu() -> void:
	menu_root = Control.new()
	menu_root.name = "Menu"
	menu_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu_root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(menu_root)

	var scrim := MenuScrim.new()
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu_root.add_child(scrim)

	var content := VBoxContainer.new()
	content.name = "TitleContent"
	content.position = Vector2(84, 156)
	content.custom_minimum_size = Vector2(620, 0)
	content.add_theme_constant_override("separation", 8)
	menu_root.add_child(content)

	var tag := _label("A  COZY  PIRATE  SURVIVAL", 15, Color(0.97, 0.81, 0.51, 0.9))
	tag.add_theme_constant_override("outline_size", 4)
	tag.add_theme_color_override("font_outline_color", Color(0.02, 0.1, 0.1, 0.8))
	content.add_child(tag)

	var title := _label("奶蛙生存", 92, CREAM)
	title.add_theme_constant_override("outline_size", 18)
	title.add_theme_color_override("font_outline_color", INK)
	title.add_theme_constant_override("shadow_offset_y", 7)
	title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.35))
	content.add_child(title)

	var subrow := HBoxContainer.new()
	subrow.add_theme_constant_override("separation", 14)
	content.add_child(subrow)
	var line := ColorRect.new()
	line.color = Color(0.94, 0.76, 0.44, 0.75)
	line.custom_minimum_size = Vector2(44, 2)
	line.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	subrow.add_child(line)
	var sub := _label("海  盗  湾", 42, GOLD)
	sub.add_theme_constant_override("outline_size", 9)
	sub.add_theme_color_override("font_outline_color", INK)
	subrow.add_child(sub)
	var subline := ColorRect.new()
	subline.color = Color(0.94, 0.76, 0.44, 0.4)
	subline.custom_minimum_size = Vector2(180, 1)
	subline.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	subrow.add_child(subline)

	var story := _label("收集木材、石头与纤维，在黄昏前搭起营火与栅栏，活过一个又一个夜晚。\n三张藏宝图和山巅的信号火，也许藏着离开这座岛的路。", 17, Color(0.87, 0.89, 0.79, 0.9))
	story.add_theme_constant_override("line_spacing", 7)
	story.custom_minimum_size = Vector2(560, 0)
	content.add_child(story)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 16)
	content.add_child(spacer)

	var button_row := HBoxContainer.new()
	button_row.add_theme_constant_override("separation", 14)
	content.add_child(button_row)
	start_button = Button.new()
	start_button.text = "开始冒险   →"
	start_button.custom_minimum_size = Vector2(248, 62)
	start_button.add_theme_font_size_override("font_size", 24)
	start_button.add_theme_stylebox_override("normal", _btn_style(Color(0.95, 0.73, 0.34, 0.96), Color(1.0, 0.9, 0.64, 1.0), 16, 2))
	start_button.add_theme_stylebox_override("hover", _btn_style(Color(1.0, 0.82, 0.46, 1.0), Color(1, 0.97, 0.8, 1), 16, 2))
	start_button.add_theme_stylebox_override("pressed", _btn_style(Color(0.83, 0.58, 0.22, 1.0), Color(1, 0.9, 0.6, 1), 16, 2))
	start_button.add_theme_color_override("font_color", INK)
	start_button.add_theme_color_override("font_hover_color", Color("#071f22"))
	start_button.add_theme_color_override("font_pressed_color", Color("#071f22"))
	start_button.pressed.connect(_on_start_pressed)
	button_row.add_child(start_button)
	var controls_btn := Button.new()
	controls_btn.text = "操作说明"
	controls_btn.custom_minimum_size = Vector2(150, 62)
	controls_btn.add_theme_font_size_override("font_size", 18)
	controls_btn.pressed.connect(_toggle_controls)
	button_row.add_child(controls_btn)

	title_controls = PanelContainer.new()
	title_controls.add_theme_stylebox_override("panel", _panel_style(Color(0.02, 0.1, 0.11, 0.92), Color(0.91, 0.76, 0.46, 0.25), 16))
	title_controls.custom_minimum_size = Vector2(620, 0)
	title_controls.visible = false
	content.add_child(title_controls)
	var cv := VBoxContainer.new()
	cv.add_theme_constant_override("separation", 4)
	title_controls.add_child(cv)
	cv.add_child(_label("电脑：WASD / 方向键移动 · 鼠标左键挥刀 · Shift 冲刺 · E 互动 · B 建造 · Esc 暂停", 14, CREAM))
	cv.add_child(_label("手机：左侧拖动移动 · 右下角挥刀 / 冲刺 / 互动 · 顶部「建造」打开制作菜单", 14, Color(0.82, 0.86, 0.74, 0.86)))
	cv.add_child(_label("生存：收集木材 / 石头 / 纤维，建营火与栅栏；撑过夜晚，活到下一日。", 14, GOLD))
	cv.add_child(_label("远方目标（可选）：开 3 只宝箱 → 带 5 捆木材 → 信号火 → 骷髅船长。", 14, Color(0.82, 0.86, 0.74, 0.7)))

	var foot := _label("WINDOWS  ·  ANDROID  ·  WEB        v1.0   ·   Godot 4.7 低多边形沙盒生存", 12, Color(0.8, 0.83, 0.7, 0.55))
	foot.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	foot.position = Vector2(86, -42)
	menu_root.add_child(foot)
	var tip := _label("建议横屏游玩 · 戴耳机体验更佳", 12, Color(0.8, 0.83, 0.7, 0.45))
	tip.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	tip.position = Vector2(-300, -42)
	tip.custom_minimum_size = Vector2(270, 0)
	tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	menu_root.add_child(tip)
	var scenic := _label("THE CURSED COVE  ·  黄昏  ·  32°N", 11, Color(0.95, 0.86, 0.64, 0.55))
	scenic.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	scenic.position = Vector2(-360, -78)
	scenic.custom_minimum_size = Vector2(330, 0)
	scenic.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	menu_root.add_child(scenic)

func _toggle_controls() -> void:
	title_controls.visible = not title_controls.visible
	if game:
		game.play_sfx("ui_click")

func _on_start_pressed() -> void:
	if game:
		game.play_sfx("ui_click")
	start_game_requested.emit()

func _build_pause() -> void:
	pause_root = Control.new()
	pause_root.name = "PauseOverlay"
	pause_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pause_root.mouse_filter = Control.MOUSE_FILTER_STOP
	pause_root.visible = false
	root.add_child(pause_root)
	var scrim := ColorRect.new()
	scrim.color = Color(0.01, 0.05, 0.06, 0.72)
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pause_root.add_child(scrim)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _panel_style(Color(0.03, 0.13, 0.14, 0.98), Color(0.93, 0.76, 0.45, 0.5), 24))
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-230, -240)
	panel.custom_minimum_size = Vector2(460, 0)
	pause_root.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	panel.add_child(v)
	var t := _label("暂 停", 44, GOLD)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var s := _label("海盗湾的风暂时停了。", 15, Color(0.83, 0.86, 0.76, 0.8))
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(s)
	v.add_child(HSeparator.new())
	var resume := Button.new(); resume.text = "继续冒险"; resume.custom_minimum_size = Vector2(0, 54); resume.pressed.connect(_on_resume_pressed); v.add_child(resume)
	var restart := Button.new(); restart.text = "重新开始"; restart.custom_minimum_size = Vector2(0, 54); restart.pressed.connect(_on_restart_pressed); v.add_child(restart)
	var to_title := Button.new(); to_title.text = "返回标题"; to_title.custom_minimum_size = Vector2(0, 54); to_title.pressed.connect(_on_title_pressed); v.add_child(to_title)
	if not OS.has_feature("web"):
		var quit := Button.new(); quit.text = "退出游戏"; quit.custom_minimum_size = Vector2(0, 54); quit.pressed.connect(func(): quit_requested.emit()); v.add_child(quit)
	var hint := _label("Esc 返回游戏", 12, Color(0.75, 0.8, 0.68, 0.5))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(hint)

func _on_pause_pressed() -> void:
	if game:
		game.toggle_pause()

func _on_resume_pressed() -> void:
	if game:
		game.play_sfx("ui_click")
	resume_requested.emit()

func _on_restart_pressed() -> void:
	if game:
		game.play_sfx("ui_click")
	restart_requested.emit()

func _on_title_pressed() -> void:
	if game:
		game.play_sfx("ui_click")
	title_requested.emit()

func _build_end() -> void:
	end_root = Control.new()
	end_root.name = "EndOverlay"
	end_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	end_root.mouse_filter = Control.MOUSE_FILTER_STOP
	end_root.visible = false
	root.add_child(end_root)
	var scrim := ColorRect.new()
	scrim.color = Color(0.01, 0.04, 0.05, 0.78)
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	end_root.add_child(scrim)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _panel_style(Color(0.03, 0.13, 0.14, 0.98), Color(0.93, 0.76, 0.45, 0.55), 26))
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-300, -260)
	panel.custom_minimum_size = Vector2(600, 0)
	end_root.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	panel.add_child(v)
	var tag := _label("THE END OF THE COVE", 12, Color(0.9, 0.8, 0.55, 0.6))
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(tag)
	end_title = _label("逃出生天！", 52, GOLD)
	end_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(end_title)
	end_sub = _label("奶蛙把信号火点燃，海盗湾的诅咒散去了。", 16, Color(0.86, 0.88, 0.78, 0.9))
	end_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(end_sub)
	v.add_child(HSeparator.new())
	end_stats = _label("", 16, CREAM)
	end_stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(end_stats)
	v.add_child(HSeparator.new())
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	v.add_child(row)
	var again := Button.new(); again.text = "再来一次"; again.custom_minimum_size = Vector2(220, 56); again.pressed.connect(_on_restart_pressed); row.add_child(again)
	var title_btn := Button.new(); title_btn.text = "返回标题"; title_btn.custom_minimum_size = Vector2(180, 56); title_btn.pressed.connect(_on_title_pressed); row.add_child(title_btn)

func _build_craft() -> void:
	craft_root = Control.new()
	craft_root.name = "CraftOverlay"
	craft_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	craft_root.mouse_filter = Control.MOUSE_FILTER_STOP
	craft_root.visible = false
	root.add_child(craft_root)
	var scrim := ColorRect.new()
	scrim.color = Color(0.012, 0.05, 0.06, 0.64)
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	craft_root.add_child(scrim)
	craft_panel = PanelContainer.new()
	craft_panel.name = "CraftPanel"
	craft_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.03, 0.13, 0.14, 0.98), Color(0.93, 0.76, 0.45, 0.55), 22))
	craft_panel.set_anchors_preset(Control.PRESET_CENTER)
	craft_panel.position = Vector2(-350, -292)
	craft_panel.custom_minimum_size = Vector2(700, 0)
	craft_root.add_child(craft_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 7)
	craft_panel.add_child(v)
	var head := HBoxContainer.new()
	v.add_child(head)
	var title := _label("建造 & 制作", 30, GOLD)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var close := Button.new()
	close.text = "×"
	close.custom_minimum_size = Vector2(42, 40)
	close.add_theme_font_size_override("font_size", 24)
	close.pressed.connect(close_craft)
	head.add_child(close)
	var sub := _label("在奶蛙面前直接建造 · 资源不足时无法制作 · B / Esc 关闭", 13, Color(0.8, 0.84, 0.73, 0.8))
	v.add_child(sub)
	craft_resource_label = _label("", 14, Color(0.9, 0.82, 0.62, 0.9))
	v.add_child(craft_resource_label)
	v.add_child(HSeparator.new())
	var recipes := [
		{"id": "campfire", "name": "营火", "cost": "5 木材 + 3 石头", "desc": "照明、回血，并把这里设为重生点"},
		{"id": "barricade", "name": "木栅栏", "cost": "4 木材", "desc": "一道结实的木墙，能挡住海盗的脚步"},
		{"id": "shelter", "name": "草棚", "cost": "8 木材 + 5 纤维", "desc": "夜间睡到天亮，并把这里设为重生点"},
		{"id": "whetstone", "name": "磨刀石", "cost": "4 石头", "desc": "磨利弯刀：永久提升 8 点攻击力"},
	]
	for data in recipes:
		var b := Button.new()
		var id: String = data["id"]
		b.name = "Craft_" + id
		b.text = "%s        %s\n%s" % [data["name"], data["cost"], data["desc"]]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(0, 62)
		b.add_theme_font_size_override("font_size", 16)
		b.add_theme_stylebox_override("normal", _btn_style(Color(0.025, 0.12, 0.13, 0.84), Color(0.91, 0.76, 0.46, 0.3), 13))
		b.add_theme_stylebox_override("hover", _btn_style(Color(0.07, 0.24, 0.23, 0.94), Color(1, 0.85, 0.55, 0.8), 13))
		b.pressed.connect(_on_craft_pressed.bind(id))
		v.add_child(b)
		craft_buttons[id] = b
	craft_status = _label("提示：建造会消耗资源；可以多建几处营火扩大安全区。", 13, Color(0.8, 0.84, 0.73, 0.65))
	v.add_child(craft_status)

func _toggle_craft() -> void:
	if craft_open:
		close_craft()
	else:
		open_craft()

func open_craft() -> void:
	if not gameplay_root.visible or pause_root.visible or end_root.visible or craft_open:
		return
	if game and not game.is_playing():
		return
	craft_open = true
	craft_root.visible = true
	touch.show_controls(false)
	get_tree().paused = true
	if game:
		game.play_sfx("ui_click")
	_refresh_craft()

func close_craft() -> void:
	if not craft_open:
		return
	craft_open = false
	craft_root.visible = false
	get_tree().paused = false
	if game:
		game.play_sfx("ui_click")
	if touch_mode and gameplay_root.visible and not is_paused and not end_root.visible:
		touch.show_controls(true)

func _on_craft_pressed(id: String) -> void:
	if game == null:
		return
	var ok: bool = game.try_craft(id)
	_refresh_craft()
	if ok:
		craft_status.text = "完成！继续收集材料，把营地扩展成能撑过夜晚的堡垒。"
	else:
		craft_status.text = "资源不足，或者奶蛙面前没有可以建造的空地。"

func _refresh_craft() -> void:
	if craft_resource_label == null or game == null:
		return
	craft_resource_label.text = "背包：木材 %d    石头 %d    纤维 %d    金币 %d" % [game.wood, game.stone, game.fiber, game.coins]
	for id in craft_buttons:
		var b := craft_buttons[id] as Button
		if b:
			var affordable: bool = game.can_afford(id)
			b.disabled = not affordable
			b.modulate = Color(1, 1, 1, 1) if affordable else Color(0.72, 0.76, 0.7, 0.62)

func set_day_phase(day: int, phase: String, night: bool) -> void:
	if day_phase_label == null:
		return
	day_phase_label.text = "第 %d 天 · %s" % [day, phase]
	day_phase_label.add_theme_color_override("font_color", Color("#ffb46a") if night else Color(0.72, 0.78, 0.66, 0.8))

func _build_vignette() -> void:
	var top := ColorRect.new()
	top.name = "Vignette"
	top.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/vignette.gdshader")
	mat.set_shader_parameter("strength", 0.65)
	top.material = mat
	root.add_child(top)

func _build_fade() -> void:
	fade_rect = ColorRect.new()
	fade_rect.name = "Fade"
	fade_rect.color = Color(0.02, 0.07, 0.08, 1.0)
	fade_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade_rect.modulate.a = 0.0
	root.add_child(fade_rect)

func fade_in(duration := 0.6) -> void:
	fade_rect.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_property(fade_rect, "modulate:a", 0.0, duration)

func fade_out(duration := 0.4) -> void:
	var tw := create_tween()
	tw.tween_property(fade_rect, "modulate:a", 1.0, duration)

func show_title() -> void:
	get_tree().paused = false
	craft_open = false
	if craft_root:
		craft_root.visible = false
	get_window().content_scale_factor = 1.0
	gameplay_root.visible = false
	menu_root.visible = true
	pause_root.visible = false
	end_root.visible = false
	fade_in(0.8)
	if start_button:
		start_button.grab_focus()

func begin_game() -> void:
	get_tree().paused = false
	craft_open = false
	if craft_root:
		craft_root.visible = false
	menu_root.visible = false
	gameplay_root.visible = true
	pause_root.visible = false
	end_root.visible = false
	boss_panel.visible = false
	if touch_mode:
		get_window().content_scale_factor = 1.4
	fade_in(0.7)
	set_player_stats(player.health if player else 100, MilkFrog.MAX_HEALTH if player else 100, player.hunger if player else 100)
	hint_label.visible = true
	hint_label.modulate.a = 0.75
	var tw := create_tween()
	tw.tween_interval(9.0)
	tw.tween_property(hint_label, "modulate:a", 0.0, 1.6)
	show_toast("漂流到海盗湾的第一天。收集资源、建造营地，撑过即将到来的夜晚。", 4.0)

func set_player_stats(health: float, max_health: float, hunger: float) -> void:
	if health_bar == null:
		return
	health_bar.max_value = max_health
	health_bar.value = health
	hunger_bar.value = hunger
	health_value.text = str(int(round(health)))
	hunger_value.text = str(int(round(hunger)))
	var ratio := health / maxf(max_health, 1.0)
	var fill := health_bar.get_theme_stylebox("fill") as StyleBoxFlat
	if fill:
		fill.bg_color = Color("#8fdf7e").lerp(Color("#e2614b"), clampf((0.55 - ratio) / 0.55, 0.0, 1.0))
	low_health = clampf((0.35 - ratio) / 0.35, 0.0, 1.0)

func set_resources(wood: int, stone: int, fiber: int, coins: int, maps: int, total_maps := 3) -> void:
	if wood_label:
		wood_label.text = str(wood)
		stone_label.text = str(stone)
		fiber_label.text = str(fiber)
		coin_label.text = str(coins)
		map_label.text = "%d/%d" % [maps, total_maps]
	if craft_open:
		_refresh_craft()

func set_objective(title: String, sub := "") -> void:
	if objective_title:
		objective_title.text = title
		objective_sub.text = sub

func set_prompt(text: String) -> void:
	if prompt_panel == null:
		return
	prompt_panel.visible = text != ""
	prompt_label.text = text

func show_toast(text: String, duration := 2.6) -> void:
	if toast_label == null:
		return
	toast_label.text = text
	toast_panel.modulate.a = 0.0
	toast_panel.visible = true
	var tw := create_tween()
	tw.tween_property(toast_panel, "modulate:a", 1.0, 0.22)
	tw.tween_interval(maxf(0.3, duration))
	tw.tween_property(toast_panel, "modulate:a", 0.0, 0.35)
	tw.tween_callback(func(): toast_panel.visible = false)

func damage_flash() -> void:
	damage_pulse = 1.0

func pause_changed(paused: bool) -> void:
	is_paused = paused
	pause_root.visible = paused
	if paused:
		touch.show_controls(false)
	elif gameplay_root.visible:
		touch.show_controls(touch_mode)
	if game:
		game.audio.set_music_muffled(paused)

func show_end(win: bool, stats: Dictionary) -> void:
	if craft_open:
		close_craft()
	end_root.visible = true
	menu_root.visible = false
	pause_root.visible = false
	gameplay_root.visible = true
	touch.show_controls(false)
	boss_panel.visible = false
	end_title.text = "逃出生天！" if win else "被海盗湾吞没了…"
	end_title.add_theme_color_override("font_color", GOLD if win else Color("#e3a07a"))
	end_sub.text = "信号火照亮了归途，奶蛙的海盗湾传奇开始了。" if win else "海浪卷走了脚印，但宝箱还在等你。"
	end_stats.text = "生存时间  %s      击败海盗  %d      金币  %d      藏宝图  %d/3" % [GameUtil.format_time(stats.get("time", 0.0)), stats.get("kills", 0), stats.get("coins", 0), stats.get("maps", 0)]
	fade_in(0.5)

func show_boss(name: String, max_hp: float) -> void:
	if boss_panel == null:
		return
	boss_panel.visible = true
	boss_label.text = name
	boss_bar.max_value = max_hp
	boss_bar.value = max_hp
	boss_panel.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(boss_panel, "modulate:a", 1.0, 0.4)

func update_boss(hp: float, max_hp: float) -> void:
	if boss_bar == null:
		return
	boss_bar.max_value = max_hp
	boss_bar.value = maxf(hp, 0.0)

func hide_boss() -> void:
	if boss_panel:
		boss_panel.visible = false

func set_touch_mode(enabled: bool) -> void:
	touch_mode = enabled
	if player:
		player.set_touch_mode(enabled)
	if gameplay_root and gameplay_root.visible and not is_paused and not end_root.visible:
		touch.show_controls(enabled and not craft_open)
	get_window().content_scale_factor = 1.4 if enabled and gameplay_root.visible else 1.0
	var hint := "左侧拖动移动 · 右侧按钮战斗 · 顶部建造" if enabled else "WASD 移动 · 鼠标左键挥刀 · Shift 冲刺 · E 互动 · B 建造"
	if hint_label:
		hint_label.text = hint

func _process(delta: float) -> void:
	if damage_mat:
		damage_pulse = maxf(0.0, damage_pulse - delta * 2.3)
		var target := maxf(damage_pulse * 0.9, low_health * 0.38)
		var current: Variant = damage_mat.get_shader_parameter("intensity")
		var cur := float(current) if current != null else 0.0
		damage_mat.set_shader_parameter("intensity", lerpf(cur, target, clampf(delta * 9.0, 0.0, 1.0)))

func _unhandled_input(event: InputEvent) -> void:
	if craft_open:
		if event.is_action_pressed("craft") or event.is_action_pressed("pause"):
			close_craft()
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("craft") and gameplay_root.visible and not pause_root.visible and not end_root.visible:
		open_craft()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("pause") and (gameplay_root.visible or pause_root.visible):
		pause_toggle_requested.emit()
		get_viewport().set_input_as_handled()
		return
	if menu_root.visible and touch_mode and event is InputEventScreenTouch:
		if (event as InputEventScreenTouch).pressed:
			start_game_requested.emit()
			get_viewport().set_input_as_handled()
