extends SceneTree

const Context = preload("res://Scripts/Core/LevelContext.gd")
const PlacementQuery = preload("res://Scripts/Player/FacilityPlacementQuery.gd")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _stop_ticks(node: Node) -> void:
	node.set_process(false)
	node.set_physics_process(false)
	for child in node.get_children():
		_stop_ticks(child)

func _run() -> void:
	var main: Node = load("res://Scenes/Main/main.tscn").instantiate()
	root.add_child(main)
	await physics_frame
	await physics_frame
	paused = false
	_stop_ticks(main)
	var flow: Node = main.get_node("LevelFlowController")
	flow.run_context = Context.new()
	flow.run_context.state = Context.LevelState.NIGHT_REST
	var player: CharacterBody2D = main.get_node("Player")
	var map: Node2D = main.get_node("PrototypeMap")
	# Isolate a real kitchen cell while retaining the real map, player and fixture.
	for fixture in get_nodes_in_group("pickup_drop_targets"):
		fixture.queue_free()
	await physics_frame
	var center: Vector2 = map.get_kitchen_zone_bounds().get_center()
	var cell: Vector2i = map.get_cell_for_point(center)
	center = map.to_global(Vector2(cell) * map.tile_size + map.tile_size * 0.5)
	var cooker: Node2D = load("res://Scenes/Restaurant/test_cooker.tscn").instantiate()
	cooker.position = center + Vector2(500, 0)
	cooker.scale = Vector2.ONE * 0.17
	main.add_child(cooker)
	_stop_ticks(cooker)
	var body: CollisionShape2D = player.get_node("CollisionShape2D")
	var obstacle: CollisionShape2D = cooker.get_node("CollisionShape2D")
	var placements := 0
	for direction in [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]:
		for edge_offset in [-44.0, 0.0, 44.0]:
			player.global_position = center + direction * edge_offset - body.position
			player.aim_direction = direction
			if not player.is_carrying_facility():
				player._pick_up_facility(cooker)
			await physics_frame
			var placement: Dictionary = player.facility_carry_controller.calculate_placement()
			if not placement.valid:
				continue
			placements += 1
			player._try_place_carried_facility()
			_check(not player.is_carrying_facility(), "Clear cutter placement must complete.")
			# No physics wait: suction may be consumed immediately after drop.
			player.apply_quicksand_spawn_pull(placement.position, 90.0)
			player._physics_process(1.0 / 60.0)
			_check(not obstacle.shape.collide(obstacle.global_transform, body.shape, body.global_transform), "An immediate quicksand impulse after placing must not enter the cutter.")
			for frame in range(12):
				await physics_frame
				player.apply_quicksand_pull((placement.position - player.global_position).normalized() * 300.0)
				player._physics_process(1.0 / 60.0)
				_check(not obstacle.shape.collide(obstacle.global_transform, body.shape, body.global_transform), "Sustained pull must not embed the player in the cutter edge.")
			var before := player.global_position
			player.push_controller.move_with_axis_separation(-direction * 80.0, -direction * 200.0, 200.0, false)
			_check(player.global_position.distance_to(before) > 79.0, "The player must be able to move away from the cutter after suction.")
			player._pick_up_facility(cooker)
	player.global_position = center - body.position
	player.aim_direction = Vector2.RIGHT
	var controller: RefCounted = player.facility_carry_controller
	var pending: Dictionary = controller.calculate_placement()
	player.global_position = pending.position - body.position
	_check(PlacementQuery.would_overlap_player_at(player, cooker, pending.position), "A player moved into a proposed drop must fail the actual-shape check before physics synchronization.")
	_check(placements > 0, "Fixture must exercise successful placements.")
	main.queue_free()
	await process_frame
	if failures.is_empty():
		print("PASS: %d cutter placements under instant/sustained suction, live-transform overlap checks and walking away." % placements)
	quit(0 if failures.is_empty() else 1)

func _check(condition: bool, message: String) -> void:
	if not condition and not failures.has(message):
		failures.append(message)
		push_error(message)
