extends Node3D

const GARDEN = preload("res://scripts/garden.gd")
const STICK = preload("res://scripts/touch_stick.gd")
const LOOK = preload("res://scripts/look_zone.gd")

var garden
var interface: Control
var main_menu: Control
var help_menu: Control
var settings_menu: Control
var hud: Control
var score_label: Label
var sensitivity := 0.38

# Touches belong to the GAME, not to oversized overlapping GUI buttons.
var joy_finger := -1
var look_finger := -1
var fire_fingers: Dictionary = {}
var joystick_visual: Control
var fire_visual: Button
var jump_visual: Button

func _ready() -> void:
	garden = GARDEN.new()
	add_child(garden)
	garden.hit_callback = Callable(self,"_on_hit")
	var layer := CanvasLayer.new()
	add_child(layer)
	interface = Control.new()
	interface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(interface)
	_build_main_menu()
	_build_tutorial()
	_build_settings()
	_build_hud()
	_change_screen("menu")

func _panel(parent: Control) -> PanelContainer:
	var p := PanelContainer.new()
	p.set_anchors_preset(Control.PRESET_CENTER)
	p.offset_left = -255
	p.offset_top = -224
	p.offset_right = 255
	p.offset_bottom = 224
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.11,0.22,0.16,0.90)
	style.border_color = Color(0.69,0.87,0.39,0.8)
	style.set_border_width_all(3)
	style.set_corner_radius_all(21)
	style.content_margin_left = 26
	style.content_margin_right = 26
	style.content_margin_top = 22
	style.content_margin_bottom = 22
	p.add_theme_stylebox_override("panel",style)
	parent.add_child(p)
	return p

func _label(txt: String, font_size: int, color: Color = Color.WHITE) -> Label:
	var l := Label.new()
	l.text = txt
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size",font_size)
	l.add_theme_color_override("font_color",color)
	return l

func _btn(txt: String) -> Button:
	var b := Button.new()
	b.text = txt
	b.custom_minimum_size = Vector2(240,58)
	b.add_theme_font_size_override("font_size",23)
	b.add_theme_color_override("font_color",Color("f9fff0"))
	var style := StyleBoxFlat.new()
	style.bg_color = Color("4b8d44")
	style.set_corner_radius_all(15)
	style.set_content_margin_all(10)
	b.add_theme_stylebox_override("normal",style)
	var hover := style.duplicate() as StyleBoxFlat
	hover.bg_color = Color("75b656")
	b.add_theme_stylebox_override("hover",hover)
	b.add_theme_stylebox_override("pressed",hover)
	return b

func _screen() -> Control:
	var s := Control.new()
	s.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	interface.add_child(s)
	return s

func _build_main_menu() -> void:
	main_menu = _screen()
	var shade := ColorRect.new()
	shade.color = Color(0.02,0.12,0.06,0.25)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	main_menu.add_child(shade)
	var panel := _panel(main_menu)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation",15)
	panel.add_child(content)
	content.add_child(_label("🌻  GARDEN MOBILE",35,Color("dbf8a1")))
	content.add_child(_label("ANIMATED PEASHOOTER  •  VERSION 0.5.1",16,Color("b9d4ab")))
	content.add_child(_label("Первый сад · спокойная тренировка",19))
	var play := _btn("▶  ИГРАТЬ")
	play.pressed.connect(_start_game)
	content.add_child(play)
	var tutorial := _btn("?  ОБУЧЕНИЕ")
	tutorial.pressed.connect(func(): _change_screen("tutorial"))
	content.add_child(tutorial)
	var settings := _btn("⚙  НАСТРОЙКИ")
	settings.pressed.connect(func(): _change_screen("settings"))
	content.add_child(settings)
	content.add_child(_label("Неофициальный фанатский прототип",14,Color("a6bda4")))

func _build_tutorial() -> void:
	help_menu = _screen()
	var panel := _panel(help_menu)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation",10)
	panel.add_child(content)
	content.add_child(_label("КАК ИГРАТЬ",33,Color("dbf8a1")))
	content.add_child(_label("ЛЕВАЯ КРУГЛАЯ КНОПКА — движение\nПРОВЕДИ ПАЛЬЦЕМ СПРАВА — камера\nОГОНЬ — стрельба горошинами\nПРЫЖОК — перепрыгивать препятствия\nПОПАДАЙ В МИШЕНИ — счётчик попаданий\nПАУЗА — вернуться в меню",20))
	content.add_child(_label("На ПК: WASD, мышь справа, F — огонь, пробел — прыжок",16,Color("b9d4ab")))
	var start := _btn("▶  В САД")
	start.pressed.connect(_start_game)
	content.add_child(start)
	var back := _btn("←  В МЕНЮ")
	back.pressed.connect(func(): _change_screen("menu"))
	content.add_child(back)

func _build_settings() -> void:
	settings_menu = _screen()
	var panel := _panel(settings_menu)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation",15)
	panel.add_child(content)
	content.add_child(_label("НАСТРОЙКИ",35,Color("dbf8a1")))
	content.add_child(_label("Чувствительность камеры",22))
	var slider := HSlider.new()
	slider.min_value = 0.15
	slider.max_value = 0.8
	slider.step = 0.05
	slider.value = sensitivity
	slider.custom_minimum_size = Vector2(380,38)
	slider.value_changed.connect(_on_sensitivity_changed)
	content.add_child(slider)
	content.add_child(_label("Графика: мобильный режим (OpenGL Compatibility)",17))
	content.add_child(_label("Сеть и мультиплеер появятся в будущих версиях",17,Color("bbd0b7")))
	var back := _btn("←  В МЕНЮ")
	back.pressed.connect(func(): _change_screen("menu"))
	content.add_child(back)

func _build_hud() -> void:
	hud = _screen()
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Fixed-width score panel: no more vertical letters on wide iPhones.
	var scoreboard := PanelContainer.new()
	scoreboard.anchor_left = 0.0
	scoreboard.anchor_top = 0.0
	scoreboard.offset_left = 18
	scoreboard.offset_top = 18
	scoreboard.offset_right = 275
	scoreboard.offset_bottom = 72
	scoreboard.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var scoreboard_style := StyleBoxFlat.new()
	scoreboard_style.bg_color = Color(0.06, 0.18, 0.10, 0.80)
	scoreboard_style.set_corner_radius_all(14)
	scoreboard_style.set_content_margin_all(12)
	scoreboard.add_theme_stylebox_override("panel", scoreboard_style)
	hud.add_child(scoreboard)
	score_label = _label("ПОПАДАНИЯ: 0", 20, Color("f8f1cc"))
	score_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	score_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scoreboard.add_child(score_label)

	var pause := _btn("Ⅱ  МЕНЮ")
	pause.add_theme_font_size_override("font_size", 20)
	pause.custom_minimum_size = Vector2(0, 0)
	pause.anchor_left = 1.0
	pause.anchor_right = 1.0
	pause.offset_left = -171
	pause.offset_top = 18
	pause.offset_right = -18
	pause.offset_bottom = 73
	pause.pressed.connect(_return_to_menu)
	hud.add_child(pause)

	joystick_visual = Control.new()
	joystick_visual.set_script(STICK)
	joystick_visual.anchor_left = 0.0
	joystick_visual.anchor_right = 0.0
	joystick_visual.anchor_top = 1.0
	joystick_visual.anchor_bottom = 1.0
	joystick_visual.offset_left = 20
	joystick_visual.offset_right = 210
	joystick_visual.offset_top = -210
	joystick_visual.offset_bottom = -20
	joystick_visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(joystick_visual)

	jump_visual = _hud_action("↑  ПРЫЖОК", -178, -152, -42, -89)
	fire_visual = _hud_action("●  ОГОНЬ", -186, -250, -24, -170)

	var crosshair := _label("+", 29, Color("fff8dc"))
	crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	crosshair.anchor_left = 0.5
	crosshair.anchor_right = 0.5
	crosshair.anchor_top = 0.5
	crosshair.anchor_bottom = 0.5
	crosshair.offset_left = -16
	crosshair.offset_top = -20
	crosshair.offset_right = 16
	crosshair.offset_bottom = 20
	hud.add_child(crosshair)

func _hud_action(title: String, left: float, top: float, right: float, bottom: float) -> Button:
	var button := _btn(title)
	button.custom_minimum_size = Vector2.ZERO
	button.add_theme_font_size_override("font_size", 21)
	button.focus_mode = Control.FOCUS_NONE
	# Visual only; independent multitouch handled by _input below.
	button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.anchor_left = 1.0
	button.anchor_right = 1.0
	button.anchor_top = 1.0
	button.anchor_bottom = 1.0
	button.offset_left = left
	button.offset_right = right
	button.offset_top = top
	button.offset_bottom = bottom
	hud.add_child(button)
	return button

func _input(event: InputEvent) -> void:
	if hud == null or not hud.visible:
		return
	if event is InputEventScreenTouch:
		_handle_touch(event.index, event.position, event.pressed)
	elif event is InputEventScreenDrag:
		if event.index == joy_finger:
			_move_joystick(event.position)
		elif event.index == look_finger:
			# Keep the original camera behavior and sensitivity.
			garden.change_look(event.relative)

func _handle_touch(finger: int, position: Vector2, pressed: bool) -> void:
	if pressed:
		# The pause button keeps its normal Godot GUI interaction.
		if position.y < 95.0:
			return
		if fire_visual.get_global_rect().has_point(position):
			fire_fingers[finger] = true
			garden.firing = true
			garden.shoot()
			fire_visual.modulate = Color("c8ffa4")
			return
		if jump_visual.get_global_rect().has_point(position):
			garden.request_jump()
			jump_visual.modulate = Color("c8ffa4")
			return
		if joy_finger == -1 and joystick_visual.get_global_rect().grow(36).has_point(position):
			joy_finger = finger
			_move_joystick(position)
			return
		if look_finger == -1 and position.x > get_viewport().get_visible_rect().size.x * 0.30:
			look_finger = finger
	else:
		if fire_fingers.has(finger):
			fire_fingers.erase(finger)
			garden.firing = not fire_fingers.is_empty()
			fire_visual.modulate = Color.WHITE
		if finger == joy_finger:
			joy_finger = -1
			garden.joy = Vector2.ZERO
			joystick_visual.call("set_direction", Vector2.ZERO)
		if finger == look_finger:
			look_finger = -1
		jump_visual.modulate = Color.WHITE

func _move_joystick(position: Vector2) -> void:
	var rect: Rect2 = joystick_visual.get_global_rect()
	var center: Vector2 = rect.get_center()
	var radius: float = minf(rect.size.x, rect.size.y) * 0.34
	var d: Vector2 = (position - center) / radius
	if d.length() < 0.12:
		d = Vector2.ZERO
	d = d.limit_length(1.0)
	garden.joy = d
	joystick_visual.call("set_direction", d)

func _change_screen(which: String) -> void:
	main_menu.visible = which == "menu"
	help_menu.visible = which == "tutorial"
	settings_menu.visible = which == "settings"
	hud.visible = which == "game"

func _start_game() -> void:
	_clear_touches()
	garden.set_playing(true)
	_change_screen("game")

func _on_hit(total: int) -> void:
	score_label.text = "ПОПАДАНИЯ: %d" % total

func _return_to_menu() -> void:
	_clear_touches()
	garden.set_playing(false)
	_change_screen("menu")

func _on_fire_down() -> void:
	garden.firing = true
	garden.shoot()

func _on_fire_up() -> void:
	garden.firing = false

func _on_sensitivity_changed(value: float) -> void:
	sensitivity = value
	garden.sensitivity = value / 100.0

func _clear_touches() -> void:
	joy_finger = -1
	look_finger = -1
	fire_fingers.clear()
	if garden != null:
		garden.joy = Vector2.ZERO
		garden.firing = false
	if joystick_visual != null:
		joystick_visual.call("set_direction", Vector2.ZERO)
	if fire_visual != null:
		fire_visual.modulate = Color.WHITE
	if jump_visual != null:
		jump_visual.modulate = Color.WHITE
