class_name ActorHealthBar
extends Control

var health_ratio: float = 1.0

static func color_for_ratio(ratio: float) -> Color:
	var value := clampf(ratio, 0.0, 1.0)
	var red := Color("ed4949")
	var orange := Color("f39436")
	var yellow := Color("efdc4f")
	var green := Color("65d67b")
	if value < 0.35:
		return red.lerp(orange, value / 0.35)
	if value < 0.65:
		return orange.lerp(yellow, (value - 0.35) / 0.3)
	return yellow.lerp(green, (value - 0.65) / 0.35)

static func update_overhead(label: Label, current: int, maximum: int, is_player: bool = false) -> void:
	if not is_instance_valid(label):
		return
	label.hide()
	var actor := label.get_parent()
	var bar := actor.get_node_or_null("OverheadHealthBar") as ActorHealthBar
	if bar == null:
		bar = ActorHealthBar.new()
		bar.name = "OverheadHealthBar"
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.size = Vector2(96, 12) if is_player else Vector2(80, 10)
		bar.z_index = 20
		var top := label.position.y
		var sprite := actor.get_node_or_null("Sprite2D") as Sprite2D
		if sprite != null:
			top = minf(top, sprite.position.y + sprite.get_rect().position.y * sprite.scale.y - 18.0)
		bar.position = Vector2(-bar.size.x * 0.5, top)
		actor.add_child(bar)
	bar.set_health(current, maximum)

func set_health(current: int, maximum: int) -> void:
	health_ratio = clampf(float(current) / float(maxi(maximum, 1)), 0.0, 1.0)
	queue_redraw()

func _draw() -> void:
	var frame := StyleBoxFlat.new()
	frame.bg_color = Color("243632")
	frame.border_color = Color("d6c397")
	frame.set_border_width_all(1)
	frame.set_corner_radius_all(3)
	frame.shadow_color = Color(0.12, 0.09, 0.06, 0.25)
	frame.shadow_size = 2
	draw_style_box(frame, Rect2(Vector2.ZERO, size))
	var inner := Rect2(Vector2(2, 2), Vector2(maxf(size.x - 4.0, 0.0) * health_ratio, maxf(size.y - 4.0, 0.0)))
	if inner.size.x > 0.0:
		draw_rect(inner, color_for_ratio(health_ratio))
		draw_line(inner.position + Vector2(0, 1), Vector2(inner.end.x, inner.position.y + 1), color_for_ratio(health_ratio).lightened(0.3), 1, true)
