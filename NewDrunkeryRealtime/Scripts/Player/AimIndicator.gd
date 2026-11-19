extends Node2D

@export var inner_radius: float = 48.0
@export var outer_radius: float = 60.0
@export var arc_angle_degrees: float = 54.0
@export var arc_color: Color = Color(0.96, 0.91, 0.67, 0.95)
@export var arrow_color: Color = Color(1.0, 0.76, 0.24, 1.0)
@export var outline_color: Color = Color(0.15, 0.1, 0.04, 0.95)
@export var outline_width: float = 2.0
@export var arrow_distance: float = 78.0
@export var arrow_size: Vector2 = Vector2(12.0, 16.0)
@export var y_offset: float = 0.0
@export var point_count: int = 28

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	var center := Vector2(0.0, y_offset)
	var half_angle := deg_to_rad(arc_angle_degrees * 0.5)
	var polygon := PackedVector2Array()

	for i in range(point_count + 1):
		var t: float = float(i) / float(point_count)
		var angle := -half_angle + t * half_angle * 2.0
		polygon.append(center + Vector2.RIGHT.rotated(angle) * outer_radius)

	for i in range(point_count, -1, -1):
		var t: float = float(i) / float(point_count)
		var angle := -half_angle + t * half_angle * 2.0
		polygon.append(center + Vector2.RIGHT.rotated(angle) * inner_radius)

	draw_colored_polygon(polygon, arc_color)
	_draw_outline(polygon)
	_draw_arrow(center)

func _draw_outline(polygon: PackedVector2Array) -> void:
	for i in range(polygon.size()):
		var next_index := (i + 1) % polygon.size()
		draw_line(polygon[i], polygon[next_index], outline_color, outline_width, true)

func _draw_arrow(center: Vector2) -> void:
	var tip := center + Vector2.RIGHT * arrow_distance
	var base_center := center + Vector2.RIGHT * (arrow_distance - arrow_size.x)
	var arrow_points := PackedVector2Array([
		tip,
		base_center + Vector2(0.0, -arrow_size.y * 0.5),
		base_center + Vector2(-arrow_size.x * 0.45, 0.0),
		base_center + Vector2(0.0, arrow_size.y * 0.5)
	])

	draw_colored_polygon(arrow_points, arrow_color)
	for i in range(arrow_points.size()):
		var next_index := (i + 1) % arrow_points.size()
		draw_line(arrow_points[i], arrow_points[next_index], outline_color, outline_width, true)
