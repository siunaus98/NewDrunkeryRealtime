extends RefCounted

# Pure geometry: callers retain their interaction rules and live scene configuration.

static func grid_points(transform: Transform2D, interaction_area_center: Vector2, interaction_area_size: Vector2, interaction_area_columns: int, interaction_area_rows: int) -> Array[Vector2]:
	var positions: Array[Vector2] = []
	var columns: int = max(interaction_area_columns, 1)
	var rows: int = max(interaction_area_rows, 1)
	var top_left: Vector2 = interaction_area_center - interaction_area_size * 0.5

	for y in range(rows):
		var y_ratio: float = 0.5 if rows == 1 else float(y) / float(rows - 1)
		for x in range(columns):
			var x_ratio: float = 0.5 if columns == 1 else float(x) / float(columns - 1)
			var local_position := top_left + Vector2(interaction_area_size.x * x_ratio, interaction_area_size.y * y_ratio)
			positions.append(transform * local_position)

	return positions

static func world_rect(transform: Transform2D, interaction_area_center: Vector2, interaction_area_size: Vector2) -> Rect2:
	var local_rect := Rect2(interaction_area_center - interaction_area_size * 0.5, interaction_area_size)
	var top_left := transform * (local_rect.position)
	var top_right := transform * (local_rect.position + Vector2(local_rect.size.x, 0.0))
	var bottom_left := transform * (local_rect.position + Vector2(0.0, local_rect.size.y))
	var bottom_right := transform * (local_rect.position + local_rect.size)
	var min_x := minf(top_left.x, minf(top_right.x, minf(bottom_left.x, bottom_right.x)))
	var max_x := maxf(top_left.x, maxf(top_right.x, maxf(bottom_left.x, bottom_right.x)))
	var min_y := minf(top_left.y, minf(top_right.y, minf(bottom_left.y, bottom_right.y)))
	var max_y := maxf(top_left.y, maxf(top_right.y, maxf(bottom_left.y, bottom_right.y)))
	return Rect2(Vector2(min_x, min_y), Vector2(max_x - min_x, max_y - min_y))

static func closest_point_on_segment(point: Vector2, segment_start: Vector2, segment_end: Vector2) -> Vector2:
	var segment: Vector2 = segment_end - segment_start
	var segment_length_squared: float = segment.length_squared()
	if segment_length_squared <= 0.000001:
		return segment_start
	var projection: float = (point - segment_start).dot(segment) / segment_length_squared
	return segment_start + segment * clampf(projection, 0.0, 1.0)

