extends RefCounted

## Static canvas decoration. Tile and collision geometry remain in PrototypeMap.
## Local deterministic variation never consumes the run's gameplay RNG.
static func floor_region(canvas: Node2D, bounds: Rect2, base: Color, kitchen: bool, tile: Vector2) -> void:
	canvas.draw_rect(bounds, base)
	var start := Vector2i(floori(bounds.position.x / tile.x), floori(bounds.position.y / tile.y))
	var end := Vector2i(ceili(bounds.end.x / tile.x), ceili(bounds.end.y / tile.y))
	for y in range(start.y, end.y):
		for x in range(start.x, end.x):
			var seed_value: int = absi(x * 7381 + y * 1931 + x * y * 17)
			var at := Vector2(x, y) * tile
			var variation: float = float(seed_value % 7) / 6.0
			if kitchen:
				# Actual placement cells remain readable as sandstone flagstones.
				var stone := Rect2(at + Vector2(2, 2), tile - Vector2(4, 4))
				if not bounds.encloses(stone):
					continue
				var fill := base.lightened(0.035 + variation * 0.055)
				canvas.draw_rect(stone, fill)
				canvas.draw_line(stone.position + Vector2(3, 2), Vector2(stone.end.x - 3, stone.position.y + 2), Color("dbe2d5"), 1.5, true)
				canvas.draw_line(Vector2(stone.position.x + 2, stone.end.y - 2), stone.end - Vector2(2, 2), base.darkened(0.07), 1.5, true)
				if seed_value % 5 == 0:
					var chip := at + Vector2(14 + seed_value % 38, 22 + seed_value % 65)
					canvas.draw_line(chip, chip + Vector2(9, -2), Color(0.93, 0.86, 0.67, 0.26), 1.2, true)
			else:
				# Sand ripples and small grains replace the outdoor checkerboard.
				var center := at + Vector2(18 + seed_value % 89, 16 + (seed_value / 7) % 94)
				if not bounds.has_point(center):
					continue
				if seed_value % 3 == 0:
					var points := PackedVector2Array()
					for index in range(9):
						var t := float(index) / 8.0
						points.append(center + Vector2((t - 0.5) * 48.0, sin(t * PI) * 5.0))
					canvas.draw_polyline(points, base.lightened(0.14), 1.8, true)
					canvas.draw_polyline(points * Transform2D(0.0, Vector2(0, 5)), base.darkened(0.045), 1.0, true)
				canvas.draw_circle(center + Vector2(14, 19), 1.2 + variation, base.darkened(0.12))
				if seed_value % 4 == 0:
					canvas.draw_circle(center + Vector2(-9, 24), 1.2, base.lightened(0.25))
	if kitchen:
		# A quiet perimeter inlay gives the hall an authored boundary.
		canvas.draw_rect(bounds.grow(-9), Color("839b92"), false, 3.0)
		canvas.draw_rect(bounds.grow(-15), Color("d8dfd0"), false, 1.5)

static func dune(canvas: Node2D, bounds: Rect2) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("b58954")
	style.set_corner_radius_all(20)
	style.border_color = Color("9b744c")
	style.set_border_width_all(2)
	canvas.draw_style_box(style, bounds.grow(-1))
	var crest := bounds.grow(-8)
	style = StyleBoxFlat.new()
	style.bg_color = Color("d8b374")
	style.set_corner_radius_all(24)
	canvas.draw_style_box(style, crest)
	var vertical: bool = bounds.size.y > bounds.size.x
	var length: float = bounds.size.y if vertical else bounds.size.x
	var count := maxi(ceili(length / 110.0), 1)
	for index in range(count):
		var t := (float(index) + 0.5) / float(count)
		var center := Vector2(bounds.get_center().x, lerpf(crest.position.y + 12, crest.end.y - 12, t)) if vertical else Vector2(lerpf(crest.position.x + 12, crest.end.x - 12, t), bounds.get_center().y)
		var points := PackedVector2Array()
		for point in range(13):
			var p := float(point) / 12.0
			var along := (p - 0.5) * minf(82, (bounds.size.x if vertical else bounds.size.y) - 30)
			points.append(center + (Vector2(along, -12 + sin(p * PI) * 13) if vertical else Vector2(-12 + sin(p * PI) * 13, along)))
		canvas.draw_polyline(points, Color("edcf94"), 3.0, true)
		canvas.draw_polyline(points * Transform2D(0.0, Vector2(4, 7)), Color("c79c60"), 1.5, true)
		canvas.draw_circle(center + Vector2(19, 19), 2, Color("bd9259"))

static func portal(canvas: Node2D, center: Vector2, radius: float) -> void:
	canvas.draw_circle(center + Vector2(0, 4), radius + 5, Color(0.22, 0.16, 0.14, 0.2))
	canvas.draw_circle(center, radius, Color("756a73"))
	canvas.draw_circle(center, radius * 0.73, Color("a7c2bc"))
	canvas.draw_circle(center, radius * 0.47, Color("4b6873"))
	canvas.draw_arc(center, radius * 0.87, 0, TAU, 40, Color("e4d0a5"), 2, true)
	canvas.draw_arc(center, radius * 0.58, -0.4, 3.9, 32, Color("d4ebcf"), 2, true)
	for index in range(4):
		var direction := Vector2.RIGHT.rotated(index * PI * 0.5)
		canvas.draw_line(center + direction * radius * 0.72, center + direction * radius, Color("f4df9f"), 3, true)
