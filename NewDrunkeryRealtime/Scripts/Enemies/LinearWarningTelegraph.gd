extends Node2D

@export var length: float = 240.0
@export var half_width: float = 30.0
@export var base_fill_color: Color = Color(0.28, 0.08, 0.04, 0.18)
@export var progress_fill_color: Color = Color(1.0, 0.18, 0.12, 0.52)
@export var outline_color: Color = Color(1.0, 0.9, 0.74, 1.0)
@export var center_line_color: Color = Color(1.0, 0.96, 0.82, 0.88)
@export var tip_color: Color = Color(1.0, 0.96, 0.86, 0.96)

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

func set_length(value: float) -> void:
	length = maxf(value, 1.0)
	queue_redraw()

func set_half_width(value: float) -> void:
	half_width = maxf(value, 1.0)
	queue_redraw()

func set_progress_ratio(value: float) -> void:
	progress_ratio = clampf(value, 0.0, 1.0)
	queue_redraw()

func _draw() -> void:
	if not is_active:
		return

	var body_rect := Rect2(Vector2.ZERO + Vector2(0.0, -half_width), Vector2(length, half_width * 2.0))
	draw_rect(body_rect, base_fill_color, true)

	var progress_length: float = length * progress_ratio
	if progress_length > 0.0:
		var progress_rect := Rect2(Vector2.ZERO + Vector2(0.0, -half_width), Vector2(progress_length, half_width * 2.0))
		draw_rect(progress_rect, progress_fill_color, true)

	draw_rect(body_rect, outline_color, false, 3.0)
	draw_line(Vector2.ZERO, Vector2(length, 0.0), center_line_color, 2.0, true)

	var tip_half_width: float = half_width * 0.94
	var tip_base_x: float = maxf(length - half_width * 1.3, 0.0)
	var tip_points := PackedVector2Array([
		Vector2(length, 0.0),
		Vector2(tip_base_x, -tip_half_width),
		Vector2(tip_base_x, tip_half_width)
	])
	draw_colored_polygon(tip_points, tip_color)

	var origin_radius: float = half_width * 0.54
	draw_circle(Vector2.ZERO, origin_radius, outline_color)
