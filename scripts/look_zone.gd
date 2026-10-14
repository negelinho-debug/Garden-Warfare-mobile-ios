extends Control
signal look_dragged(delta: Vector2)
var touch_id := -1

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP

func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and touch_id == -1:
			touch_id = event.index
			accept_event()
		elif not event.pressed and touch_id == event.index:
			touch_id = -1
			accept_event()
	elif event is InputEventScreenDrag and event.index == touch_id:
		look_dragged.emit(event.relative)
		accept_event()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		touch_id = -2 if event.pressed else -1
		accept_event()
	elif event is InputEventMouseMotion and touch_id == -2:
		look_dragged.emit(event.relative)
		accept_event()
