extends Control

## Compact daily schedule clock. The blue arc is preparation time and the
## amber arc is service time; a bright hand marks the current position.
@export var clock_radius: float = 42.0
@export var ring_width: float = 9.0
@export var prep_color := Color(0.28, 0.68, 0.96, 0.96)
@export var service_color := Color(1.0, 0.66, 0.24, 0.96)
@export var track_color := Color(0.08, 0.10, 0.14, 0.94)
@export var hand_color := Color(1.0, 0.94, 0.72, 1.0)

var total_duration: float = 180.0
var prepare_duration: float = 50.0
var progress_layer: Control

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(112.0, 112.0)
	progress_layer = load("res://Scripts/UI/DayClockProgress.gd").new()
	progress_layer.name = "Progress"
	add_child(progress_layer)
	progress_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	queue_redraw()

func set_schedule(new_remaining: float, new_total: float, new_prepare_duration: float, new_phase_text: String) -> void:
	var safe_total := maxf(new_total, 0.01)
	var safe_prepare := clampf(new_prepare_duration, 0.0, safe_total)
	if not is_equal_approx(total_duration, safe_total) or not is_equal_approx(prepare_duration, safe_prepare):
		total_duration = safe_total
		prepare_duration = safe_prepare
		queue_redraw()
	if progress_layer != null and progress_layer.has_method("set_progress"):
		progress_layer.set_progress(new_remaining, safe_total, new_phase_text)

func _draw() -> void:
	var center := size * 0.5
	var start_angle := -PI * 0.5
	var prep_ratio := clampf(prepare_duration / total_duration, 0.0, 1.0)
	var prep_end := start_angle + TAU * prep_ratio
	var radius := minf(clock_radius, minf(size.x, size.y) * 0.5 - ring_width)
	draw_circle(center, radius + ring_width * 0.5, track_color)
	draw_arc(center, radius + ring_width * 0.5 + 2, 0, TAU, 80, Color("cfb37b"), 2, true)
	for index in range(12):
		var direction := Vector2.RIGHT.rotated(float(index) * TAU / 12)
		draw_line(center + direction * (radius - 9), center + direction * (radius - 13), Color("b8ad91"), 1.5, true)
	if prep_ratio > 0.0:
		draw_arc(center, radius, start_angle, prep_end, 48, prep_color, ring_width, true)
	if prep_ratio < 1.0:
		draw_arc(center, radius, prep_end, start_angle + TAU, 72, service_color, ring_width, true)
