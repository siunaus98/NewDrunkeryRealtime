extends Node2D

@export var radius: float = 72.0
@export var base_fill_color: Color = Color(0.36, 0.06, 0.02, 0.16)
@export var progress_fill_color: Color = Color(1.0, 0.18, 0.12, 0.44)
@export var outline_color: Color = Color(1.0, 0.88, 0.72, 1.0)
@export var point_count: int = 48

var is_active: bool = false
var progress_ratio: float = 0.0

func set_active(value: bool) -> void:
	if is_active == value:
		return

	is_active = value
	if value:
		progress_ratio = 0.0
	visible = value
	queue_redraw()

func set_radius(value: float) -> void:
	radius = maxf(value, 1.0)
	queue_redraw()

func set_progress_ratio(value: float) -> void:
	progress_ratio = clampf(value, 0.0, 1.0)
	queue_redraw()

func _draw() -> void:
	if not is_active:
		return

	draw_circle(Vector2.ZERO, radius, base_fill_color)
	draw_circle(Vector2.ZERO, radius * progress_ratio, progress_fill_color)
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, point_count, outline_color, 3.0, true)
	draw_arc(Vector2.ZERO, radius - 6, -PI * 0.5, -PI * 0.5 + TAU * progress_ratio, point_count, outline_color, 2.0, true)
	for index in range(8):
		var direction := Vector2.RIGHT.rotated(float(index) * TAU / 8)
		draw_line(direction * (radius - 12), direction * (radius - 3), Color(outline_color, 0.7), 2, true)
