extends Node2D

const TestItemDefs = preload("res://Scripts/Kitchen/TestItemDefs.gd")

var source_kind: StringName = &"forage"
var forage_item_ids: Array[StringName] = []
var battle_entries: Array[Dictionary] = []
var board_size := Vector2(400.0, 220.0)
## Direction from this board toward its associated battle zone, in board-local
## coordinates. It is set by ForageRegion after the board is rotated.
var region_direction: Vector2 = Vector2.DOWN
var arrow_centers: Array[Vector2] = []

const ENEMY_TEXTURES := {
	&"chaser": preload("res://ArtResource/Generated/Enemy/desert_bird_enemy.svg"),
	&"sprinter": preload("res://ArtResource/Generated/Enemy/sand_hare_enemy.svg"),
	&"ranged": preload("res://ArtResource/Generated/Enemy/cactus_beetle_enemy.svg"),
	&"sniper": preload("res://ArtResource/Generated/Enemy/sand_scarab_enemy.svg"),
	&"slammer": preload("res://ArtResource/Generated/Enemy/red_lamb_enemy.svg"),
	&"bruiser": preload("res://ArtResource/Generated/Enemy/camel_enemy.svg"),
	&"bullet_fan": preload("res://ArtResource/Generated/Enemy/sun_moth_enemy.svg"),
	&"orbiter": preload("res://ArtResource/Generated/Enemy/sun_guardian_enemy.svg"),
	&"splitter": preload("res://ArtResource/Generated/Enemy/thorn_splitter_enemy.svg")
}

func _ready() -> void:
	z_index = 8
	_build_icons()
	queue_redraw()

func get_visual_bounds() -> Rect2:
	# The board includes every drawn stroke; icons are fitted inside its padding.
	return Rect2(-board_size * 0.5, board_size)

func _build_icons() -> void:
	var content := get_visual_bounds().grow(-14.0)
	content.position.y += 28.0
	content.size.y -= 28.0
	if source_kind == &"forage":
		var ids: Array[StringName] = []
		for item_id in forage_item_ids:
			if item_id not in ids:
				ids.append(item_id)
		if ids.is_empty():
			return
		var points := _spread_points(ids.size(), content)
		for i in range(ids.size()):
			var center: Vector2 = points[i]
			# Collection icons use most of the board's available area. Three
			# ingredients form a readable triangle instead of a tiny row.
			_add_icon(TestItemDefs.get_item_texture(ids[i]), center, Vector2.ONE * minf(content.size.x, content.size.y) * 0.44)
	else:
		if battle_entries.is_empty():
			return
		# Keep combat sources in two rows on every regular battle board. This is
		# especially important for the second and third areas, whose wide dune
		# mounts previously compressed every pair into one long line.
		var columns := maxi(ceili(float(battle_entries.size()) / 2.0), 1)
		var rows := ceili(float(battle_entries.size()) / float(columns))
		var cell_size := content.size / Vector2(columns, rows)
		for i in range(battle_entries.size()):
			var center := content.position + cell_size * (Vector2(i % columns, floori(float(i) / columns)) + Vector2.ONE * 0.5)
			var entry: Dictionary = battle_entries[i]
			var icon_size := minf((cell_size.x - 26.0) * 0.5, cell_size.y - 8.0)
			var offset := icon_size * 0.5 + 16.0
			_add_icon(ENEMY_TEXTURES.get(StringName(entry.get("enemy_id", &""))), center - Vector2(offset, 0), Vector2.ONE * icon_size)
			_add_icon(TestItemDefs.get_item_texture(StringName(entry.get("item_id", &""))), center + Vector2(offset, 0), Vector2.ONE * icon_size)
			arrow_centers.append(center)

func _spread_points(count: int, area: Rect2) -> Array[Vector2]:
	var points: Array[Vector2] = []
	var center := area.get_center()
	if count <= 0:
		return points
	if count == 1:
		points.append(center)
	elif count == 2:
		points.append(Vector2(area.position.x + area.size.x * 0.30, center.y))
		points.append(Vector2(area.position.x + area.size.x * 0.70, center.y))
	elif count == 3:
		# A triangle reads more clearly than three icons squeezed into one row.
		points.append(Vector2(center.x, area.position.y + area.size.y * 0.27))
		points.append(Vector2(area.position.x + area.size.x * 0.28, area.position.y + area.size.y * 0.72))
		points.append(Vector2(area.position.x + area.size.x * 0.72, area.position.y + area.size.y * 0.72))
	elif count == 4:
		for y in [0.30, 0.70]:
			for x in [0.30, 0.70]:
				points.append(area.position + area.size * Vector2(x, y))
	else:
		var columns := ceili(sqrt(float(count)))
		var rows := ceili(float(count) / float(columns))
		for i in range(count):
			var x_ratio := (float(i % columns) + 0.5) / float(columns)
			var y_ratio := (float(i / columns) + 0.5) / float(rows)
			points.append(area.position + area.size * Vector2(x_ratio, y_ratio))
	return points

func _add_icon(texture: Texture2D, center: Vector2, max_size: Vector2) -> void:
	if texture == null:
		return
	var icon := Sprite2D.new()
	icon.texture = texture
	icon.position = center
	icon.scale = Vector2.ONE * minf(max_size.x / texture.get_width(), max_size.y / texture.get_height())
	add_child(icon)

func _draw() -> void:
	var rect := get_visual_bounds()
	var fill := Color(0.48, 0.27, 0.10) if source_kind == &"forage" else Color(0.42, 0.20, 0.08)
	var edge := Color(0.83, 0.58, 0.26)
	draw_rect(rect, fill)
	draw_rect(rect.grow(-3.0), edge, false, 5.0)
	draw_line(rect.position + Vector2(8, 8), Vector2(rect.end.x - 8, rect.position.y + 8), Color("f0cb8e"), 1.5, true)
	draw_line(Vector2(rect.position.x + 8, rect.end.y - 8), rect.end - Vector2(8, 8), Color("362c26"), 2, true)
	for offset in [Vector2(11, 11), Vector2(rect.size.x - 11, 11), Vector2(11, rect.size.y - 11), rect.size - Vector2(11, 11)]:
		draw_circle(rect.position + offset, 3, Color("d6b17b"))
		draw_line(rect.position + offset - Vector2(1.5, 0), rect.position + offset + Vector2(1.5, 0), Color("6d5138"), 1, true)
	# Carved category symbol, with no post or extra sand decoration.
	var mark := Vector2(rect.position.x + 25.0, rect.position.y + 24.0)
	if source_kind == &"forage":
		draw_circle(mark, 11.0, Color(0.22, 0.58, 0.24))
		draw_line(mark + Vector2(-6, 7), mark + Vector2(6, -7), Color(0.72, 0.94, 0.50), 3.0)
	else:
		draw_line(mark + Vector2(-8, -8), mark + Vector2(8, 8), Color(1.0, 0.76, 0.38), 4.0)
		draw_line(mark + Vector2(-8, 8), mark + Vector2(8, -8), Color(1.0, 0.76, 0.38), 4.0)
	_draw_region_direction_arrow(rect)
	for center in arrow_centers:
		var color := Color(1.0, 0.82, 0.42)
		draw_line(center - Vector2(10, 0), center + Vector2(10, 0), color, 3.0)
		draw_polyline(PackedVector2Array([center + Vector2(3, -7), center + Vector2(10, 0), center + Vector2(3, 7)]), color, 3.0)

func _draw_region_direction_arrow(rect: Rect2) -> void:
	var direction := region_direction.normalized()
	if direction == Vector2.ZERO:
		direction = Vector2.DOWN
	# Keep the directional marker in its own top-right safety area. The icon
	# rows start lower on the board, so this remains readable and never spills
	# over the wooden edge even when the arrow points upward or sideways.
	var safe_rect := rect.grow(-18.0)
	var center := safe_rect.position + Vector2(safe_rect.size.x - 26.0, 26.0)
	var length := minf(58.0, minf(safe_rect.size.x, safe_rect.size.y) * 0.42)
	var start := center - direction * length * 0.5
	var tip := center + direction * length * 0.5
	start.x = clampf(start.x, safe_rect.position.x + 5.0, safe_rect.end.x - 5.0)
	start.y = clampf(start.y, safe_rect.position.y + 5.0, safe_rect.end.y - 5.0)
	tip.x = clampf(tip.x, safe_rect.position.x + 5.0, safe_rect.end.x - 5.0)
	tip.y = clampf(tip.y, safe_rect.position.y + 5.0, safe_rect.end.y - 5.0)
	var color := Color(1.0, 0.94, 0.56, 1.0)
	# One continuous shaft and one triangular head. The head starts before the
	# tip and never extends beyond it, avoiding the previous square overhang.
	var head_length := minf(22.0, length * 0.42)
	var shaft_tip := tip - direction * (head_length * 0.48)
	draw_line(start, shaft_tip, Color(0.18, 0.08, 0.02, 0.95), 16.0, true)
	draw_line(start, shaft_tip, color, 10.0, true)
	var side := Vector2(-direction.y, direction.x) * minf(15.0, length * 0.24)
	var head_back := tip - direction * head_length
	var head := PackedVector2Array([tip, head_back + side, head_back - side])
	draw_colored_polygon(head, Color(0.18, 0.08, 0.02, 0.95))
	var inner_side := side * 0.68
	var inner_back := tip - direction * (head_length - 3.0)
	draw_colored_polygon(PackedVector2Array([tip - direction * 2.0, inner_back + inner_side, inner_back - inner_side]), color)
