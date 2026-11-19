extends Node2D

@export var icon_size: float = 28.0
@export var icon_gap: float = 8.0
@export var ring_width: float = 3.0
@export var background_color: Color = Color(0.06, 0.07, 0.09, 0.86)
@export var move_buff_color: Color = Color(0.35, 0.92, 1.0, 0.95)
@export var cook_buff_color: Color = Color(0.98, 0.76, 0.34, 0.95)
@export var big_buff_color: Color = Color(1.0, 0.58, 0.24, 0.95)

var move_buff_visible: bool = false
var move_buff_progress: float = 1.0
var cook_buff_visible: bool = false
var cook_buff_progress: float = 1.0
var big_buff_visible: bool = false
var big_buff_progress: float = 1.0

func set_buff_state(
	new_move_visible: bool,
	new_move_progress: float,
	new_cook_visible: bool,
	new_cook_progress: float,
	new_big_visible: bool,
	new_big_progress: float
) -> void:
	move_buff_visible = new_move_visible
	move_buff_progress = clampf(new_move_progress, 0.0, 1.0)
	cook_buff_visible = new_cook_visible
	cook_buff_progress = clampf(new_cook_progress, 0.0, 1.0)
	big_buff_visible = new_big_visible
	big_buff_progress = clampf(new_big_progress, 0.0, 1.0)
	visible = move_buff_visible or cook_buff_visible or big_buff_visible
	queue_redraw()

func _draw() -> void:
	var active_count: int = int(move_buff_visible) + int(cook_buff_visible) + int(big_buff_visible)
	if active_count <= 0:
		return

	var total_width: float = float(active_count) * icon_size + float(active_count - 1) * icon_gap
	var start_x: float = -total_width * 0.5 + icon_size * 0.5
	var slot_index: int = 0
	if move_buff_visible:
		_draw_buff_icon(Vector2(start_x + float(slot_index) * (icon_size + icon_gap), 0.0), move_buff_progress, move_buff_color, "move")
		slot_index += 1
	if cook_buff_visible:
		_draw_buff_icon(Vector2(start_x + float(slot_index) * (icon_size + icon_gap), 0.0), cook_buff_progress, cook_buff_color, "cook")
		slot_index += 1
	if big_buff_visible:
		_draw_buff_icon(Vector2(start_x + float(slot_index) * (icon_size + icon_gap), 0.0), big_buff_progress, big_buff_color, "big")

func _draw_buff_icon(center: Vector2, progress: float, color: Color, buff_type: String) -> void:
	var radius: float = icon_size * 0.5
	draw_circle(center, radius, background_color)
	draw_arc(center, radius, 0.0, TAU, 36, Color(0.0, 0.0, 0.0, 0.38), ring_width, true)

	var start_angle: float = -PI * 0.5
	var end_angle: float = start_angle + TAU * progress
	draw_arc(center, radius + 1.5, start_angle, end_angle, 36, color, ring_width, true)

	match buff_type:
		"move":
			_draw_move_glyph(center, color)
		"cook":
			_draw_cook_glyph(center, color)
		_:
			_draw_big_glyph(center, color)

func _draw_move_glyph(center: Vector2, color: Color) -> void:
	draw_line(center + Vector2(-8.0, 0.0), center + Vector2(7.0, 0.0), color, 3.0, true)
	draw_line(center + Vector2(1.0, -7.0), center + Vector2(7.0, 0.0), color, 3.0, true)
	draw_line(center + Vector2(1.0, 7.0), center + Vector2(7.0, 0.0), color, 3.0, true)

func _draw_cook_glyph(center: Vector2, color: Color) -> void:
	draw_circle(center + Vector2(-2.0, -1.0), 6.0, Color(0.0, 0.0, 0.0, 0.12))
	draw_arc(center + Vector2(-2.0, -1.0), 6.0, PI * 0.1, PI * 1.7, 18, color, 2.4, true)
	draw_line(center + Vector2(3.0, 4.0), center + Vector2(8.0, 9.0), color, 2.2, true)
	draw_line(center + Vector2(5.0, -7.0), center + Vector2(5.0, -10.0), color, 2.0, true)
	draw_line(center + Vector2(1.0, -8.0), center + Vector2(0.0, -11.0), color, 2.0, true)
	draw_line(center + Vector2(7.0, -8.0), center + Vector2(8.0, -11.0), color, 2.0, true)

func _draw_big_glyph(center: Vector2, color: Color) -> void:
	var palm_points := PackedVector2Array([
		center + Vector2(-6.0, 5.0),
		center + Vector2(-4.0, -8.0),
		center + Vector2(-1.0, -9.0),
		center + Vector2(0.0, 2.0),
		center + Vector2(3.0, -8.0),
		center + Vector2(6.0, -6.0),
		center + Vector2(5.0, 7.0),
		center + Vector2(0.0, 10.0),
	])
	draw_colored_polygon(palm_points, color)
	draw_arc(center + Vector2(0.0, 2.0), 9.0, 0.15, PI - 0.15, 16, Color(1.0, 0.96, 0.72, 0.85), 1.6, true)
