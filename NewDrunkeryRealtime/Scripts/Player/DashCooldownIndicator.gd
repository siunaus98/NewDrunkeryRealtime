extends Node2D

@export var radius: float = 22.0
@export var line_width: float = 5.0
@export var ready_color: Color = Color(0.45, 0.92, 1.0, 0.95)
@export var cooldown_color: Color = Color(1.0, 0.73, 0.22, 0.95)
@export var background_color: Color = Color(0.12, 0.11, 0.09, 0.72)
@export var pulse_duration: float = 0.18
@export var point_count: int = 48

var progress: float = 1.0
var was_ready: bool = true
var pulse_time: float = 0.0

func _process(delta: float) -> void:
	if pulse_time > 0.0:
		pulse_time = maxf(pulse_time - delta, 0.0)
	queue_redraw()

func set_dash_progress(new_progress: float) -> void:
	progress = clampf(new_progress, 0.0, 1.0)
	var is_ready := progress >= 1.0
	if is_ready and not was_ready:
		pulse_time = pulse_duration
	was_ready = is_ready
	queue_redraw()

func _draw() -> void:
	var pulse_scale := 1.0
	if pulse_time > 0.0:
		pulse_scale = 1.0 + 0.28 * (pulse_time / pulse_duration)

	var draw_radius := radius * pulse_scale
	draw_arc(Vector2.ZERO, draw_radius, 0.0, TAU, point_count, background_color, line_width, true)

	if progress >= 1.0:
		draw_arc(Vector2.ZERO, draw_radius, 0.0, TAU, point_count, ready_color, line_width, true)
		return

	var start_angle := -PI * 0.5
	var end_angle := start_angle + TAU * progress
	draw_arc(Vector2.ZERO, draw_radius, start_angle, end_angle, point_count, cooldown_color, line_width, true)
