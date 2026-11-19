extends Node2D

@export var length: float = 220.0
@export var half_width: float = 24.0
@export var fill_color: Color = Color(1.0, 0.84, 0.18, 0.34)
@export var outline_color: Color = Color(1.0, 0.98, 0.78, 1.0)
@export var tip_color: Color = Color(1.0, 0.96, 0.82, 0.96)
@export var center_line_color: Color = Color(0.42, 0.18, 0.02, 0.72)

var is_active: bool = false
var flash_time: float = 0.0

func set_active(value: bool) -> void:
	if is_active == value:
		return

	is_active = value
	if value:
		flash_time = 0.0
	visible = value
	queue_redraw()

func set_length(value: float) -> void:
	length = maxf(value, 0.0)
	queue_redraw()

func set_half_width(value: float) -> void:
	half_width = maxf(value, 1.0)
	queue_redraw()

func _process(delta: float) -> void:
	if not is_active:
		return

	flash_time += delta * 12.0
	queue_redraw()

func _draw() -> void:
	if not is_active:
		return

	var pulse: float = 0.68 + 0.32 * sin(flash_time)
	var current_fill: Color = fill_color
	current_fill.a *= pulse
	var rect := Rect2(Vector2(0.0, -half_width), Vector2(length, half_width * 2.0))
	draw_rect(rect, current_fill, true)
	draw_rect(rect, outline_color, false, 3.0)
	draw_line(Vector2(0.0, 0.0), Vector2(length, 0.0), center_line_color, 2.0, true)

	var tip_width: float = half_width * 1.12
	var tip_points := PackedVector2Array([
		Vector2(length, 0.0),
		Vector2(length - half_width * 1.45, -tip_width),
		Vector2(length - half_width * 1.45, tip_width)
	])
	draw_colored_polygon(tip_points, tip_color)

	var origin_radius: float = half_width * 0.7
	var origin_color: Color = outline_color
	origin_color.a *= 0.9
	draw_circle(Vector2.ZERO, origin_radius, origin_color)
