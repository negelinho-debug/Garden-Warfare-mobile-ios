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
	content.add_child(_label("🌻  GARDEN PROJECT",35,Color("dbf8a1")))
	content.add_child(_label("3D GARDEN PROTOTYPE  •  VERSION 0.3",16,Color("b9d4ab")))
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
	var top := HBoxContainer.new()
	top.anchor_right = 1.0
	top.offset_left = 28
	top.offset_top = 18
	top.offset_right = -24
	top.offset_bottom = 79
	top.add_theme_constant_override("separation",16)
	hud.add_child(top)
	score_label = _label("🎯  ПОПАДАНИЯ: 0",23,Color("f8f1cc"))
	top.add_child(score_label)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(spacer)
	var pause := _btn("Ⅱ  МЕНЮ")
	pause.custom_minimum_size = Vector2(150,54)
	pause.pressed.connect(_return_to_menu)
	top.add_child(pause)

	var look := Control.new()
	look.set_script(LOOK)
	look.anchor_left = 0.40
	look.anchor_right = 1.0
	look.anchor_top = 0.12
	look.anchor_bottom = 0.96
	hud.add_child(look)
	look.connect("look_dragged",func(delta: Vector2): garden.change_look(delta))

	var joy_control := Control.new()
	joy_control.set_script(STICK)
	joy_control.anchor_left = 0.0
	joy_control.anchor_right = 0.0
	joy_control.anchor_top = 1.0
	joy_control.anchor_bottom = 1.0
	joy_control.offset_left = 34
	joy_control.offset_top = -235
	joy_control.offset_right = 244
	joy_control.offset_bottom = -25
	hud.add_child(joy_control)
	joy_control.connect("direction_changed",func(v: Vector2): garden.joy = v)

	var fire := _btn("●  ОГОНЬ")
	fire.anchor_left = 1.0
	fire.anchor_right = 1.0
	fire.anchor_top = 1.0
	fire.anchor_bottom = 1.0
	fire.offset_left = -230
	fire.offset_top = -162
	fire.offset_right = -26
	fire.offset_bottom = -50
	fire.button_down.connect(_on_fire_down)
	fire.button_up.connect(_on_fire_up)
	hud.add_child(fire)

	var jump := _btn("↑  ПРЫЖОК")
	jump.anchor_left = 1.0
	jump.anchor_right = 1.0
	jump.anchor_top = 1.0
	jump.anchor_bottom = 1.0
	jump.offset_left = -240
	jump.offset_top = -252
	jump.offset_right = -48
	jump.offset_bottom = -183
	jump.pressed.connect(func(): garden.request_jump())
	hud.add_child(jump)

	var crosshair := _label("+",35,Color("fff8dc"))
	crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	crosshair.anchor_left = 0.5
	crosshair.anchor_right = 0.5
	crosshair.anchor_top = 0.5
	crosshair.anchor_bottom = 0.5
	crosshair.offset_left = -20
	crosshair.offset_top = -24
	crosshair.offset_right = 20
	crosshair.offset_bottom = 24
	hud.add_child(crosshair)

func _change_screen(which: String) -> void:
	main_menu.visible = which == "menu"
	help_menu.visible = which == "tutorial"
	settings_menu.visible = which == "settings"
	hud.visible = which == "game"

func _start_game() -> void:
	garden.set_playing(true)
	_change_screen("game")

func _on_hit(total: int) -> void:
	score_label.text = "🎯  ПОПАДАНИЯ: %d" % total

func _return_to_menu() -> void:
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
