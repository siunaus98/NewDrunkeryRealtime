extends Node2D

@export var inner_radius: float = 42.0
@export var outer_radius: float = 145.0
@export var arc_angle_degrees: float = 82.0
@export var duration: float = 0.12
@export var fill_color: Color = Color(1.0, 0.72, 0.23, 0.34)
@export var edge_color: Color = Color(1.0, 0.88, 0.42, 0.85)
@export var charge_fill_color: Color = Color(1.0, 0.45, 0.14, 0.42)
@export var charge_edge_color: Color = Color(1.0, 0.96, 0.32, 0.96)
@export var full_charge_fill_color: Color = Color(1.0, 0.18, 0.08, 0.52)
@export var full_charge_edge_color: Color = Color(1.0, 1.0, 0.55, 1.0)
@export var outline_width: float = 3.0
@export var point_count: int = 24

var remaining_time: float = 0.0
var previewing_charge: bool = false
var charge_ratio: float = 0.0
var full_charge_preview: bool = false
var draw_inner_radius: float = 42.0
var draw_outer_radius: float = 145.0
var draw_arc_angle_degrees: float = 82.0
var follow_local_position: Vector2 = Vector2.ZERO

func _ready() -> void:
	follow_local_position = position
	visible = false
	_reset_attack_shape()

func _process(delta: float) -> void:
	if previewing_charge:
		queue_redraw()
		return
	if remaining_time <= 0.0:
		return

	remaining_time -= delta
	if remaining_time <= 0.0:
		visible = false
		_follow_parent_origin()
	queue_redraw()

func play(angle: float) -> void:
	play_attack_shape(angle, inner_radius, outer_radius, arc_angle_degrees)

func play_attack_shape(angle: float, new_inner_radius: float, new_outer_radius: float, new_arc_angle_degrees: float) -> void:
	previewing_charge = false
	_set_attack_shape(new_inner_radius, new_outer_radius, new_arc_angle_degrees)
	_freeze_at_current_origin(angle)
	remaining_time = duration
	visible = true
	queue_redraw()

func play_charged(angle: float, new_charge_ratio: float, is_full_charge: bool) -> void:
	play_charged_shape(angle, new_charge_ratio, is_full_charge, inner_radius, outer_radius * (1.0 + clampf(new_charge_ratio, 0.0, 1.0) * 0.18), arc_angle_degrees)

func play_charged_shape(angle: float, new_charge_ratio: float, is_full_charge: bool, new_inner_radius: float, new_outer_radius: float, new_arc_angle_degrees: float) -> void:
	previewing_charge = false
	charge_ratio = clampf(new_charge_ratio, 0.0, 1.0)
	full_charge_preview = is_full_charge
	_set_attack_shape(new_inner_radius, new_outer_radius, new_arc_angle_degrees)
	_freeze_at_current_origin(angle)
	remaining_time = duration * 1.45
	visible = true
	queue_redraw()

func preview_charge(direction: Vector2, new_charge_ratio: float, is_full_charge: bool) -> void:
	preview_charge_shape(direction, new_charge_ratio, is_full_charge, inner_radius, outer_radius * (1.0 + clampf(new_charge_ratio, 0.0, 1.0) * 0.18), arc_angle_degrees)

func preview_charge_shape(direction: Vector2, new_charge_ratio: float, is_full_charge: bool, new_inner_radius: float, new_outer_radius: float, new_arc_angle_degrees: float) -> void:
	_follow_parent_origin()
	if direction.length_squared() > 0.001:
		rotation = direction.angle()
	charge_ratio = clampf(new_charge_ratio, 0.0, 1.0)
	full_charge_preview = is_full_charge
	_set_attack_shape(new_inner_radius, new_outer_radius, new_arc_angle_degrees)
	previewing_charge = true
	visible = true
	queue_redraw()

func stop_charge_preview() -> void:
	if not previewing_charge:
		return
	previewing_charge = false
	charge_ratio = 0.0
	full_charge_preview = false
	_reset_attack_shape()
	_follow_parent_origin()
	if remaining_time <= 0.0:
		visible = false
	queue_redraw()

func _draw() -> void:
	if remaining_time <= 0.0 and not previewing_charge:
		return

	var alpha_scale := 1.0 if previewing_charge else clampf(remaining_time / duration, 0.0, 1.0)
	var current_fill := full_charge_fill_color if full_charge_preview else charge_fill_color if charge_ratio > 0.0 else fill_color
	var current_edge := full_charge_edge_color if full_charge_preview else charge_edge_color if charge_ratio > 0.0 else edge_color
	current_fill.a *= alpha_scale
	if previewing_charge:
		current_fill.a *= 0.38
	current_edge.a *= alpha_scale

	var half_angle := deg_to_rad(draw_arc_angle_degrees * 0.5)
	var polygon := PackedVector2Array()

	for i in range(point_count + 1):
		var t := float(i) / float(point_count)
		var angle := -half_angle + t * half_angle * 2.0
		polygon.append(Vector2.RIGHT.rotated(angle) * draw_outer_radius)

	for i in range(point_count, -1, -1):
		var t := float(i) / float(point_count)
		var angle := -half_angle + t * half_angle * 2.0
		polygon.append(Vector2.RIGHT.rotated(angle) * draw_inner_radius)

	draw_colored_polygon(polygon, current_fill)
	for i in range(polygon.size()):
		var next_index := (i + 1) % polygon.size()
		draw_line(polygon[i], polygon[next_index], current_edge, outline_width + charge_ratio * 2.0, true)
	# A tapered blade of light gives the strike a direction and decay. The
	# complete original sector remains visible as the authoritative hit area.
	var phase: float = 0.45 if previewing_charge else 1.0 - clampf(remaining_time / (duration * (1.45 if charge_ratio > 0 else 1.0)), 0, 1)
	var sweep: float = lerpf(-half_angle, half_angle, phase)
	var ribbon := PackedVector2Array()
	for index in range(25):
		var t := float(index) / 24.0
		var angle := lerpf(-half_angle, sweep, t)
		ribbon.append(Vector2.RIGHT.rotated(angle) * draw_outer_radius * (0.92 + 0.08 * sin(t * PI)))
	for index in range(24, -1, -1):
		var t := float(index) / 24.0
		var angle := lerpf(-half_angle, sweep, t)
		ribbon.append(Vector2.RIGHT.rotated(angle) * draw_outer_radius * (0.92 - 0.19 * sin(t * PI)))
	var light := current_edge.lightened(0.6)
	light.a = alpha_scale * (0.35 if previewing_charge else 0.85)
	draw_colored_polygon(ribbon, light)
	draw_arc(Vector2.ZERO, draw_outer_radius * 0.78, -half_angle, sweep, 32, Color(current_edge, alpha_scale * 0.65), 2, true)
	for index in range(5):
		var angle := lerpf(-half_angle, sweep, float(index + 1) / 6.0)
		var at := Vector2.RIGHT.rotated(angle) * draw_outer_radius * (0.58 + float(index % 3) * 0.13)
		draw_line(at, at + Vector2.RIGHT.rotated(angle + PI * 0.5) * (6 + 4 * charge_ratio), light, 1.7, true)

func _set_attack_shape(new_inner_radius: float, new_outer_radius: float, new_arc_angle_degrees: float) -> void:
	draw_inner_radius = maxf(new_inner_radius, 0.0)
	draw_outer_radius = maxf(new_outer_radius, draw_inner_radius)
	draw_arc_angle_degrees = clampf(new_arc_angle_degrees, 1.0, 360.0)

func _reset_attack_shape() -> void:
	_set_attack_shape(inner_radius, outer_radius, arc_angle_degrees)

func _freeze_at_current_origin(angle: float) -> void:
	_follow_parent_origin()
	var frozen_global_position := global_position
	set_as_top_level(true)
	global_position = frozen_global_position
	global_rotation = angle

func _follow_parent_origin() -> void:
	if not is_set_as_top_level():
		return
	set_as_top_level(false)
	position = follow_local_position
