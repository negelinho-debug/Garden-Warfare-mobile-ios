extends Control
# Visual joystick. The main game owns each finger to support true multitouch.
var direction := Vector2.ZERO

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)
	queue_redraw()

func set_direction(value: Vector2) -> void:
	direction = value.limit_length(1.0)
	queue_redraw()

func _draw() -> void:
	var center := size / 2.0
	var radius: float = minf(size.x, size.y) * 0.34
	var knob := center + direction * radius
	draw_circle(center, radius + 8.0, Color(0.06, 0.16, 0.08, 0.45))
	draw_arc(center, radius, 0.0, TAU, 64, Color(0.82, 1.0, 0.70, 0.8), 4.0, true)
	draw_circle(knob, radius * 0.42, Color(0.59, 0.86, 0.28, 0.92))
	draw_circle(knob, radius * 0.26, Color(0.22, 0.50, 0.15, 0.94))
