extends Control

@export var clock_radius: float = 42.0
@export var ring_width: float = 9.0
@export var hand_color := Color(1.0, 0.94, 0.72, 1.0)

var total_duration: float = 180.0
var remaining: float = 180.0
var phase_text: String = "备菜"

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()

func set_progress(new_remaining: float, new_total: float, new_phase_text: String) -> void:
	remaining = clampf(new_remaining, 0.0, maxf(new_total, 0.01))
	total_duration = maxf(new_total, 0.01)
	phase_text = new_phase_text
	queue_redraw()

func _draw() -> void:
	var center := size * 0.5
	var radius := minf(clock_radius, minf(size.x, size.y) * 0.5 - ring_width)
	var elapsed_ratio := clampf(1.0 - remaining / total_duration, 0.0, 1.0)
	var hand_angle := -PI * 0.5 + TAU * elapsed_ratio
	var hand_end := center + Vector2(cos(hand_angle), sin(hand_angle)) * (radius - 3.0)
	draw_line(center, hand_end, hand_color, 3.0, true)
	draw_circle(center, 4.0, hand_color)

	var seconds := maxi(int(ceili(remaining)), 0)
	var time_label := "%d:%02d" % [seconds / 60, seconds % 60]
	draw_string(ThemeDB.fallback_font, center + Vector2(-24.0, 5.0), time_label, HORIZONTAL_ALIGNMENT_CENTER, 48.0, 14, Color(0.96, 0.97, 1.0, 0.96))
	draw_string(ThemeDB.fallback_font, center + Vector2(-30.0, 24.0), phase_text, HORIZONTAL_ALIGNMENT_CENTER, 60.0, 11, hand_color)
