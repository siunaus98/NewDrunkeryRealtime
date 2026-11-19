extends Node2D

@export var fill_color: Color = Color(1.0, 0.44, 0.22, 0.10)
@export var outline_color: Color = Color(1.0, 0.62, 0.36, 0.88)

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	var player := get_parent()
	if player == null or not player.has_method("is_item_push_debug_enabled"):
		return
	if not player.is_item_push_debug_enabled():
		return

	var collision_shape: CollisionShape2D = player.get_node_or_null("ItemPushArea/CollisionShape2D")
	if collision_shape == null:
		return

	var shape := collision_shape.shape as CapsuleShape2D
	if shape == null:
		return

	var local_center: Vector2 = collision_shape.position
	var radius: float = shape.radius
	var segment_half_length: float = maxf(shape.height * 0.5 - radius, 0.0)
	var top_center: Vector2 = local_center + Vector2(0.0, -segment_half_length)
	var bottom_center: Vector2 = local_center + Vector2(0.0, segment_half_length)

	draw_circle(top_center, radius, fill_color)
	draw_circle(bottom_center, radius, fill_color)
	draw_rect(Rect2(Vector2(local_center.x - radius, top_center.y), Vector2(radius * 2.0, bottom_center.y - top_center.y)), fill_color, true)
	draw_arc(top_center, radius, 0.0, TAU, 28, outline_color, 2.0, true)
	draw_arc(bottom_center, radius, 0.0, TAU, 28, outline_color, 2.0, true)
	draw_line(top_center + Vector2(-radius, 0.0), bottom_center + Vector2(-radius, 0.0), outline_color, 2.0, true)
	draw_line(top_center + Vector2(radius, 0.0), bottom_center + Vector2(radius, 0.0), outline_color, 2.0, true)
