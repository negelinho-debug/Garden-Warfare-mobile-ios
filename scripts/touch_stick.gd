extends Control
signal direction_changed(direction: Vector2)

var touch_id := -1
var direction := Vector2.ZERO
var pointer := Vector2.ZERO
const DEAD_ZONE := 10.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	pointer = size / 2.0
	resized.connect(_on_resized)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and touch_id == -1:
			touch_id = event.index
			_set_pointer(event.position)
			accept_event()
		elif not event.pressed and event.index == touch_id:
			_reset()
			accept_event()
	elif event is InputEventScreenDrag and event.index == touch_id:
		_set_pointer(event.position)
		accept_event()
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				touch_id = -2
				_set_pointer(event.position)
			else:
				_reset()
			accept_event()
	elif event is InputEventMouseMotion and touch_id == -2:
		_set_pointer(event.position)
		accept_event()

func _set_pointer(pos: Vector2) -> void:
	var center := size / 2.0
	var radius: float = minf(size.x, size.y) * 0.32
	var raw := pos - center
	pointer = center + raw.limit_length(radius)
	direction = raw / radius if raw.length() > DEAD_ZONE else Vector2.ZERO
	direction = direction.limit_length(1.0)
	direction_changed.emit(direction)
	queue_redraw()

func _reset() -> void:
	touch_id = -1
	direction = Vector2.ZERO
	pointer = size / 2.0
	direction_changed.emit(direction)
	queue_redraw()

func _draw() -> void:
	var center := size / 2.0
	var radius: float = minf(size.x, size.y) * 0.32
	draw_circle(center, radius + 6.0, Color(0.05,0.14,0.06,0.42))
	draw_arc(center, radius, 0.0, TAU, 64, Color(0.76,0.99,0.57,0.70), 5.0, true)
	draw_circle(pointer, radius * 0.43, Color(0.65,0.93,0.32,0.78))
	draw_circle(pointer, radius * 0.30, Color(0.23,0.53,0.13,0.85))

func _on_resized() -> void:
	pointer = size / 2.0
	queue_redraw()
