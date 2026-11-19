extends "res://Scripts/Enemies/MonitorTongueController.gd"

const Spot = preload("res://Scripts/Enemies/MonitorFeedingSpot.gd")
const Refs = preload("res://Scripts/Core/LevelRefs.gd")
var spots: Array[Node2D] = []
var rage_target: WeakRef
var rage_remaining := 0.0

func setup(host: CharacterBody2D) -> void:
	super.setup(host)
	lock_duration = 30.0

func blocks_boss() -> bool:
	# Transport is not eating: only consume_feast(), at mouth arrival,
	# grants the food's stun. The boss keeps fighting while food travels.
	return false

func begin() -> bool:
	if active() or not is_instance_valid(boss.prototype_map):
		return false
	var points := _find_offering_points(_target_count())
	if points.size() < _target_count():
		cooldown = 2.0
		return false
	branches.clear()
	for point: Vector2 in points:
		var spot: Node2D = Spot.new()
		spot.head = self
		boss.get_parent().add_child(spot)
		spot.global_position = point
		spots.append(spot)
		branches.append({"target": {"position": point}, "cancelled": false, "food": {}})
	phase = Phase.LOCK
	remaining = lock_duration
	AudioCue.play_sfx(&"boss_alert", -4.0)
	return true

func tick(delta: float, can_start: bool) -> void:
	rage_remaining = maxf(rage_remaining - delta, 0)
	if not active():
		super.tick(delta, can_start)
		return
	remaining = maxf(remaining - delta, 0)
	if remaining > 0:
		return
	match phase:
		Phase.LOCK:
			AudioCue.at(boss, &"spit", -4.0)
			_capture_offerings()
			phase = Phase.EXTEND
			remaining = extend_duration
		Phase.EXTEND:
			phase = Phase.RETRACT
			remaining = retract_duration
		Phase.RETRACT:
			var meals: Array[Dictionary] = []
			for branch: Dictionary in branches:
				if not Dictionary(branch.food).is_empty():
					meals.append(branch.food)
					branch.food = {}
			finish()
			boss.consume_feast(meals)

func _capture_offerings() -> void:
	var targets: Array[Dictionary] = []
	for spot: Node2D in spots:
		spot.locked = true
		var entries := Food.candidates(get_tree(), spot.get_interaction_rect_global())
		# J deposits and ordinary ground drops both count. Never reach into a
		# nearby work surface, plate rack, or ingredient cabinet.
		entries = entries.filter(func(entry: Dictionary) -> bool:
			var source: Node = entry.source.get_ref()
			return source == spot or source.is_in_group("loose_items")
		)
		entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return Food.quality(a.item) > Food.quality(b.item))
		targets.append(entries[0] if not entries.is_empty() else {})
	var portions := Food.consume_many(targets)
	var missing := false
	for index in branches.size():
		branches[index].food = portions[index]
		missing = missing or portions[index].is_empty()
	if missing:
		_enrage()

func _enrage() -> void:
	var options: Array[Node] = []
	var kitchen: Rect2 = boss.prototype_map.get_kitchen_zone_bounds()
	var seen: Dictionary = {}
	for cabinet: Node in get_tree().get_nodes_in_group("storage_facilities"):
		if not cabinet.is_visible_in_tree() or not kitchen.has_point(cabinet.global_position) or not cabinet.has_method("is_scarab_steal_target") or not cabinet.is_scarab_steal_target() or seen.has(cabinet.stored_item_id):
			continue
		seen[cabinet.stored_item_id] = true
		options.append(cabinet)
	if options.is_empty():
		return
	var cabinet: Node2D = options.pick_random()
	cabinet.storage_manager.clear_item_stock(cabinet.stored_item_id)
	rage_target = weakref(cabinet)
	rage_remaining = 4.0
	for actor: Node in get_tree().get_nodes_in_group("player"):
		actor.show_hint("巨蜥暴怒！%s库存被清空" % Food.Items.get_item_display_name(cabinet.stored_item_id))

func finish() -> void:
	for spot: Node2D in spots:
		if is_instance_valid(spot):
			spot.release_food()
			spot.queue_free()
	spots.clear()
	super.finish()

func status_text() -> String:
	if phase == Phase.LOCK:
		return "准备投喂 · 料理区 %d 处 · 剩余 %d 秒" % [spots.size(), ceili(remaining)]
	if phase == Phase.EXTEND:
		return "伸舌取食 · 尚未吞下"
	if phase == Phase.RETRACT:
		return "收舌运送 · 尚未吞下"
	return ""

func _find_offering_points(count: int) -> Array[Vector2]:
	var map: Node2D = boss.prototype_map
	var bounds: Rect2 = map.get_kitchen_zone_bounds()
	var tile: Vector2 = map.get_tile_size()
	var cells: Dictionary = {}
	var shape := RectangleShape2D.new()
	shape.size = tile - Vector2(8, 8)
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.collision_mask = 4 | 8 | 16
	var first: Vector2i = map.get_cell_for_point(bounds.position)
	var size := Vector2i(bounds.size / tile)
	for y in range(first.y, first.y + size.y):
		for x in range(first.x, first.x + size.x):
			var cell := Vector2i(x, y)
			var point: Vector2 = map.to_global((Vector2(cell) + Vector2(0.5, 0.5)) * tile)
			query.transform = Transform2D(0, point)
			if map.is_cell_editable_for_facility(cell) and boss.get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty():
				cells[cell] = point
	# Use the largest connected floor component, excluding pockets enclosed by
	# facilities. The marker itself has no body and cannot trap a player.
	var largest: Array[Vector2i] = []
	var player_component := false
	var player_cells: Array[Vector2i] = []
	for actor: Node2D in get_tree().get_nodes_in_group("player"):
		if bounds.has_point(actor.global_position):
			player_cells.append(map.get_cell_for_point(actor.get_sort_origin()))
	while not cells.is_empty():
		var queue: Array[Vector2i] = [cells.keys()[0]]
		cells.erase(queue[0])
		var cursor := 0
		while cursor < queue.size():
			var cell := queue[cursor]
			cursor += 1
			for direction: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
				var next := cell + direction
				if cells.has(next):
					queue.append(next)
					cells.erase(next)
		var contains_player := queue.any(func(cell: Vector2i) -> bool: return cell in player_cells)
		if (contains_player and not player_component) or (contains_player == player_component and queue.size() > largest.size()):
			largest = queue
			player_component = contains_player
	largest.shuffle()
	var result: Array[Vector2] = []
	for cell: Vector2i in largest:
		var point: Vector2 = map.to_global((Vector2(cell) + Vector2(0.5, 0.5)) * tile)
		if result.any(func(other: Vector2) -> bool: return point.distance_to(other) < tile.x * 2.5):
			continue
		result.append(point)
		if result.size() == count:
			break
	return result

func _draw() -> void:
	if phase in [Phase.EXTEND, Phase.RETRACT]:
		super._draw()
	if phase == Phase.EXTEND:
		for branch: Dictionary in branches:
			var meal: Dictionary = branch.food
			if meal.is_empty():
				continue
			var texture: Texture2D = Food.Items.get_world_item_texture(StringName(meal.item_id), meal.get("payload", {}))
			var at: Vector2 = to_local(branch.target.position)
			if texture != null:
				draw_texture_rect(texture, Rect2(at - Vector2(32, 32), Vector2(64, 64)), false)
	if rage_remaining > 0 and rage_target != null:
		var cabinet: Node2D = rage_target.get_ref()
		if is_instance_valid(cabinet):
			var at := to_local(cabinet.global_position)
			draw_circle(at, 70, Color(0.9, 0.15, 0.1, 0.25))
			draw_line(at - Vector2(42, 42), at + Vector2(42, 42), Color("ff755f"), 8, true)
			draw_line(at + Vector2(-42, 42), at + Vector2(42, -42), Color("ff755f"), 8, true)
