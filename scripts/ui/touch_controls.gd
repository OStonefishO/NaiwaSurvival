class_name TouchControls
extends Control

var player: MilkFrog
var joystick: MilkJoystick
var attack_button: TouchActionButton
var dash_button: TouchActionButton
var interact_button: TouchActionButton
var hint_label: Label

func setup(p_player: MilkFrog) -> void:
	player = p_player

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()
	visible = false

func _build() -> void:
	var joy_area := Control.new()
	joy_area.name = "JoystickArea"
	joy_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	joy_area.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	joy_area.position = Vector2(18, -326)
	joy_area.size = Vector2(306, 300)
	add_child(joy_area)
	joystick = MilkJoystick.new()
	joystick.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	joy_area.add_child(joystick)
	joystick.vector_changed.connect(_on_joystick)

	attack_button = _make_button("挥刀", HUDIcon.Kind.SWORD, Color("#ffd36b"))
	attack_button.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	attack_button.position = Vector2(-172, -184)
	attack_button.size = Vector2(140, 140)
	attack_button.pressed.connect(_on_attack)
	add_child(attack_button)

	dash_button = _make_button("冲刺", HUDIcon.Kind.DASH, Color("#8fe7e0"))
	dash_button.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	dash_button.position = Vector2(-322, -150)
	dash_button.size = Vector2(112, 112)
	dash_button.pressed.connect(_on_dash)
	add_child(dash_button)

	interact_button = _make_button("互动", HUDIcon.Kind.HAND, Color("#f5d7a1"))
	interact_button.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	interact_button.position = Vector2(-136, -324)
	interact_button.size = Vector2(100, 100)
	interact_button.pressed.connect(_on_interact)
	add_child(interact_button)

	hint_label = Label.new()
	hint_label.text = "左侧拖动移动 · 右侧按钮战斗"
	hint_label.add_theme_font_size_override("font_size", 19)
	hint_label.add_theme_color_override("font_color", Color(1, 0.96, 0.85, 0.55))
	hint_label.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	hint_label.position = Vector2(100, -372)
	hint_label.size = Vector2(320, 26)
	add_child(hint_label)

func _make_button(text: String, icon: HUDIcon.Kind, accent: Color) -> TouchActionButton:
	var b := TouchActionButton.new()
	b.label = text
	b.icon_kind = icon
	b.accent = accent
	return b

func _on_joystick(v: Vector2) -> void:
	if player:
		player.touch_move = v

func _on_attack() -> void:
	if player:
		player.touch_attack_queued = true

func _on_dash() -> void:
	if player:
		player.touch_dash_queued = true

func _on_interact() -> void:
	if player:
		player.touch_interact_queued = true

func show_controls(show_it: bool) -> void:
	visible = show_it
	if not show_it and joystick:
		joystick._reset()
