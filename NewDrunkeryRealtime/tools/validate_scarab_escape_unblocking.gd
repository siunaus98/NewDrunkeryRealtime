extends SceneTree

const Enemy = preload("res://Scripts/Enemies/ScarabEnemy.gd")
const Context = preload("res://Scripts/Core/LevelContext.gd")
var failures: Array[String] = []
var controller: Node
var cabinet: Node2D
var actors: Array[Enemy] = []
var fixed_facilities: Array[Node] = []
var fixed_starts: Dictionary = {}
var fixed_moved: bool = false
var kitchen_publications: int = 0
var observed_grid: AStarGrid2D
var kitchen_bounds: Rect2

func _step() -> void:
	await physics_frame
	for facility in fixed_facilities:
		if facility.global_position.distance_to(fixed_starts[facility.get_instance_id()]) > 32.0:
			fixed_moved = true
	controller._process(1.0 / 60.0)
	var grid: AStarGrid2D = controller.navigation_cache.caches[kitchen_bounds].grid
	if grid != null and grid != observed_grid:
		observed_grid = grid
		kitchen_publications += 1
	var claims: Array[Vector2] = []
	for actor in actors:
		if not is_instance_valid(actor):
			continue
		actor._process(1.0 / 60.0)
		if actor.current_target == cabinet:
			_check(not claims.has(actor.target_approach_position), "Repeated opening must never duplicate approach slots.")
			claims.append(actor.target_approach_position)

func _claimant() -> Enemy:
	for actor in actors:
		if is_instance_valid(actor) and actor.current_target == cabinet:
			return actor
	return null

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
	_stop_ticks(main)
	paused = false
	var flow: Node = main.get_node("LevelFlowController")
	flow.run_context.state = Context.LevelState.WAVE_ACTIVE
	controller = main.get_node("ScarabMechanismController")
	controller.rng.seed = 1090
	seed(1090)
	var map: Node2D = main.get_node("PrototypeMap")
	kitchen_bounds = map.get_kitchen_zone_bounds()
	for facility in get_nodes_in_group("cooking_stations"):
		if facility.visible:
			fixed_facilities.append(facility)
			fixed_starts[facility.get_instance_id()] = facility.global_position
	cabinet = main.get_node("StorageCabinetSunnyBerry")
	var blocker_name := "StorageCabinetSandPotato"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--blocker="):
			blocker_name = argument.trim_prefix("--blocker=")
	var blocker: Node2D = main.get_node(blocker_name)
	controller.configure_for_level({"map_mechanism_ids": [&"scarab"], "boss_enhanced_map_mechanism_id": &"scarab"})
	controller.start_business()
	controller.max_active_scarabs = 0
	controller.storage_manager.fill_test_stock(0)
	controller.storage_manager.add_stock(&"sunny_berry", 30)
	for food in get_nodes_in_group("loose_items"):
		food.queue_free()
	var allowed: Array[StringName] = [&"sunny_berry"]
	for source in get_nodes_in_group("storage_facilities"):
		source.set_menu_allowed_item_ids(allowed)
	for i in range(3):
		var actor := Enemy.new()
		actor.collision_layer = 2
		actor.collision_mask = 4 | 8 | 16
		var collision := CollisionShape2D.new()
		var shape := CircleShape2D.new()
		shape.radius = 34.0
		collision.shape = shape
		actor.add_child(collision)
		main.add_child(actor)
		actor.stolen_limit = 5
		# Keep all three actors alive for several open/close cycles, while
		# still ticking and checking their actual escape countdowns.
		actor.escape_duration = 60.0
		actor.global_position = map.get_kitchen_zone_bounds().get_center() + Vector2(i * 120, 150)
		actor.set_process(false)
		actor.steal_action_finished.connect(controller._on_scarab_steal_action_finished)
		actor.escape_finished.connect(controller._on_scarab_escape_finished)
		actors.append(actor)
	for frame in range(1000):
		await _step()
		var casting := 0
		for actor in actors:
			if actor.state == Enemy.State.ESCAPING:
				casting += 1
		if casting == actors.size():
			break
	for actor in actors:
		_check(actor.state == Enemy.State.ESCAPING, "Enclosed original cabinet must lead to escape casting.")
	var carry: RefCounted = main.get_node("Player").facility_carry_controller
	for cycle in range(3):
		_check(carry.pick_up(blocker), "Player must actually lift the stone blocker.")
		for frame in range(180):
			await _step()
			if _claimant() != null:
				break
		var claimant := _claimant()
		_check(claimant != null, "Opening must interrupt escape on cycle %d." % cycle)
		if claimant == null:
			break
		_check(claimant.state == Enemy.State.SEARCHING and claimant.global_position.distance_to(cabinet.global_position) > 128.0, "Reclose while the claimant is still approaching, before it can steal.")
		carry.cancel_carry()
		for frame in range(180):
			await _step()
			if claimant.state in [Enemy.State.ESCAPING_TO_CORNER, Enemy.State.ESCAPING]:
				break
		_check(claimant.current_target == null and claimant.state in [Enemy.State.ESCAPING_TO_CORNER, Enemy.State.ESCAPING], "Reclosing must release ownership and resume escape on cycle %d." % cycle)
		_check(controller.storage_manager.get_stock(&"sunny_berry") == 30, "An enclosed cabinet must not be stolen through the blocker.")
		print("Toggle cycle=%d state=%d route=%d escape_target=%s" % [cycle, claimant.state, claimant.escape_navigation_route.size(), claimant.escape_target_position])
	# Every actor must still be able to act after the repeated reclosures.
	for actor in actors:
		var food: Node2D = load("res://Scenes/Restaurant/loose_item.tscn").instantiate()
		main.add_child(food)
		food.global_position = actor.global_position
		food.setup_item(&"crisp_sprout", null)
		_stop_ticks(food)
	for frame in range(300):
		await _step()
		var all_acted := true
		for actor in actors:
			all_acted = all_acted and actor.get_stolen_count() > 0
		if all_acted:
			break
	for actor in actors:
		_check(actor.get_stolen_count() > 0, "All actors must resume real theft after repeated open/close operations.")
	_check(not fixed_moved, "Cooking facilities must stay fixed during repeated route updates.")
	_check(kitchen_publications > 1, "Manually moved obstacles must publish a replacement navigation grid.")
	controller.stop_business()
	main.queue_free()
	await process_frame
	if failures.is_empty():
		print("PASS: three open/close cycles with fixed cooking facilities, released claims, no theft through blockers, repeated grid publications and all actors remain responsive.")
	quit(0 if failures.is_empty() else 1)

func _check(condition: bool, message: String) -> void:
	if not condition and not failures.has(message):
		failures.append(message)
		push_error(message)
