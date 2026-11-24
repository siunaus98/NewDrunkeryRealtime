extends Control

# A dialogue portrait only: no world position, interaction target or body.
func _ready() -> void:
	custom_minimum_size = Vector2(148, 112)
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

func _draw() -> void:
	var center := size * .5 + Vector2(0, 6)
	var outline := Color("675b54")
	var cream := Color("fff3d9")
	# A small halo, round head and two detached round hands.
	draw_arc(center + Vector2(0, -43), 17, PI + .12, TAU - .12, 32, Color("f4d879"), 3, true)
	for side in [-1, 1]:
		var hand := center + Vector2(side * 57, 23)
		draw_circle(hand, 11, outline)
		draw_circle(hand, 9, cream)
	draw_circle(center, 41, outline)
	draw_circle(center, 38.5, cream)
	# Large stylized eyes and a tiny smile; keep the face readable at UI size.
	for side in [-1, 1]:
		var eye := center + Vector2(side * 15, -1)
		draw_circle(eye, 11, Color.WHITE)
		draw_circle(eye + Vector2(-1, 1), 7.5, Color("4b4c59"))
		draw_circle(eye + Vector2(-3, -2), 2.8, Color.WHITE)
		draw_circle(eye + Vector2(2, 4), 1.3, Color("e4deb9"))
		draw_circle(center + Vector2(side * 27, 15), 5, Color("efa9a3"))
	draw_arc(center + Vector2(0, 16), 5, .1, PI - .1, 16, Color("976569"), 2, true)
	draw_colored_polygon(PackedVector2Array([center + Vector2(-10, -35), center + Vector2(0, -44), center + Vector2(10, -35), center + Vector2(0, -29)]), Color("c4dacf"))
