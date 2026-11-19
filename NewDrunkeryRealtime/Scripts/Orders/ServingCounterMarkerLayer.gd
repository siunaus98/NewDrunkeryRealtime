@tool
extends Node2D

var marker_positions: Array[Vector2] = []
var target_slot_index: int = -1
var delivered_slot_index: int = -1
var marker_radius: float = 28.0
var marker_fill_color: Color = Color(0.88, 0.68, 0.14, 0.98)
var marker_outline_color: Color = Color(1.0, 0.88, 0.42, 1.0)
var marker_text_color: Color = Color(0.25, 0.16, 0.02, 1.0)
var marker_font_size: int = 26
var marker_font: Font
var slot_number_offset: int = 0

func configure(
	new_positions: Array[Vector2],
	new_target_slot_index: int,
	new_delivered_slot_index: int,
	new_marker_radius: float,
	new_marker_fill_color: Color,
	new_marker_outline_color: Color,
	new_marker_text_color: Color,
	new_marker_font_size: int,
	new_slot_number_offset: int = 0
) -> void:
	marker_positions = new_positions.duplicate()
	target_slot_index = new_target_slot_index
	delivered_slot_index = new_delivered_slot_index
	marker_radius = new_marker_radius
	marker_fill_color = new_marker_fill_color
	marker_outline_color = new_marker_outline_color
	marker_text_color = new_marker_text_color
	marker_font_size = new_marker_font_size
	slot_number_offset = new_slot_number_offset
	queue_redraw()

func _draw() -> void:
	if marker_font == null:
		marker_font = ThemeDB.fallback_font

	for i in range(marker_positions.size()):
		var marker_center: Vector2 = marker_positions[i]
		var fill_color: Color = marker_fill_color
		var outline_color: Color = marker_outline_color
		var is_target: bool = i == target_slot_index
		var radius: float = marker_radius
		if is_target:
			radius *= 1.22
			fill_color = Color(1.0, 0.82, 0.18, 1.0)
			outline_color = Color(1.0, 0.97, 0.48, 1.0)
			draw_circle(marker_center, radius + 14.0, Color(1.0, 0.72, 0.12, 0.24))
			draw_arc(marker_center, radius + 14.0, 0.0, TAU, 48, Color(1.0, 0.86, 0.28, 0.72), 5.0, true)

		draw_circle(marker_center, radius + 5.0, Color(0.03, 0.02, 0.01, 0.76))
		draw_circle(marker_center, radius, fill_color)
		draw_arc(marker_center, radius, 0.0, TAU, 40, outline_color, 4.0, true)

		var marker_text: String = "#%d" % (i + slot_number_offset + 1)
		var text_size: Vector2 = marker_font.get_string_size(marker_text, HORIZONTAL_ALIGNMENT_CENTER, -1, marker_font_size)
		var text_position := marker_center + Vector2(-text_size.x * 0.5, text_size.y * 0.36)
		draw_string(marker_font, text_position, marker_text, HORIZONTAL_ALIGNMENT_LEFT, -1, marker_font_size, marker_text_color)
