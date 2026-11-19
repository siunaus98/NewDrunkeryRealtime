extends Node2D

@export var radius: float = 74.0
@export var ready_color: Color = Color(1.0, 0.32, 0.18, 0.23)
@export var cooldown_color: Color = Color(0.4, 0.34, 0.28, 0.16)
@export var windup_color: Color = Color(1.0, 0.9, 0.2, 0.3)
@export var outline_color: Color = Color(0.18, 0.05, 0.03, 0.45)
@export var point_count: int = 48

var attack_ready: bool = true
var is_windup: bool = false
var flash_time: float = 0.0

func set_attack_ready(value: bool) -> void:
	if attack_ready == value:
		return

	attack_ready = value
	queue_redraw()

func set_windup(value: bool) -> void:
	if is_windup == value:
		return

	is_windup = value
	if value:
		flash_time = 0.0
	queue_redraw()

func _process(delta: float) -> void:
	if not is_windup:
		return

	flash_time += delta * 14.0
	queue_redraw()

func _draw() -> void:
	var fill_color: Color
	if is_windup:
		var pulse := 0.75 + 0.25 * sin(flash_time)
		fill_color = windup_color
		fill_color.a *= pulse
	elif attack_ready:
		fill_color = ready_color
	else:
		fill_color = cooldown_color

	draw_circle(Vector2.ZERO, radius, fill_color)
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, point_count, outline_color, 2.0, true)
