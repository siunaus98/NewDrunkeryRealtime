extends Control

## Static desert ornament, kept behind all interactive title controls.
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)
	queue_redraw()

func _draw() -> void:
	var gold := Color(0.78, 0.65, 0.4, 0.22)
	draw_rect(Rect2(Vector2(26, 26), size - Vector2(52, 52)), gold, false, 1, true)
	draw_rect(Rect2(Vector2(34, 34), size - Vector2(68, 68)), Color(gold, 0.1), false, 1, true)
	var center := Vector2(size.x * 0.84, size.y * 0.3)
	for radius in [118.0, 133.0, 156.0]:
		draw_arc(center, radius, -0.8, 4.3, 100, Color(gold, 0.13), 1.5, true)
	for index in range(16):
		var direction := Vector2.RIGHT.rotated(float(index) * TAU / 16)
		draw_line(center + direction * 142, center + direction * 152, gold, 1.5, true)
	for layer in range(3):
		var points := PackedVector2Array([Vector2(0, size.y)])
		for index in range(65):
			var t := float(index) / 64
			points.append(Vector2(t * size.x, size.y * (0.83 + float(layer) * 0.055) + sin(t * TAU * 1.2 + layer * 0.9) * 40))
		points.append(size)
		draw_colored_polygon(points, Color(0.56, 0.4, 0.23, 0.08 + float(layer) * 0.03))
	for index in range(24):
		var at := Vector2(fposmod(float(index * 173), size.x), fposmod(float(index * 97), size.y))
		draw_circle(at, 1.2 if index % 3 else 2, Color(0.85, 0.77, 0.53, 0.17))
