extends SceneTree

const Enemy = preload("res://Scripts/Enemies/ScarabEnemy.gd")
const Cabinet = preload("res://Scenes/Restaurant/ingredient_storage_cabinet.tscn")
const LooseItem = preload("res://Scenes/Restaurant/loose_item.tscn")
var failures: Array[String] = []
var main: Node
var controller: Node
var center: Vector2

func _initialize() -> void:
	call_deferred("_run")

func _check(condition: bool, message: String) -> void:
	if not condition and not failures.has(message):
		failures.append(message)
		push_error(message)

func _stop_ticks(node: Node) -> void:
	node.set_process(false)
	node.set_physics_process(false)
	for child in node.get_children():
		_stop_ticks(child)

func _scarab(position: Vector2) -> Enemy:
	var actor := Enemy.new()
	actor.collision_layer = 2
	actor.collision_mask = 4 | 8 | 16
	var collision := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 34.0
	collision.shape = circle
	actor.add_child(collision)
	main.add_child(actor)
	actor.global_position = position
	actor.stolen_limit = 4
	actor.escape_duration = 30.0
	actor.set_process(false)
	actor.steal_action_finished.connect(controller._on_scarab_steal_action_finished)
	actor.escape_finished.connect(controller._on_scarab_escape_finished)
	actor.defeated.connect(controller._on_scarab_defeated)
	return actor

func _cabinet(position: Vector2, item: StringName) -> Node2D:
	var cabinet: Node2D = Cabinet.instantiate()
	cabinet.stored_item_id = item
	main.add_child(cabinet)
	cabinet.global_position = position
	_stop_ticks(cabinet)
	return cabinet

func _food(position: Vector2) -> Node2D:
	var food: Node2D = LooseItem.instantiate()
	main.add_child(food)
	food.global_position = position
	food.setup_item(&"crisp_sprout", null)
	_stop_ticks(food)
	return food

func _step() -> void:
	await physics_frame
	controller._process(1.0 / 60.0)
	var claims: Dictionary = {}
	for actor in get_nodes_in_group("scarab_enemies"):
		if actor.is_dead or actor.is_queued_for_deletion():
			continue
		if actor.current_target_kind == &"ground" and is_instance_valid(actor.current_target):
			var key: int = actor.current_target.get_instance_id()
			_check(not claims.has(key), "Searching and stealing scarabs must never share a loose item.")
			claims[key] = true
		actor._process(1.0 / 60.0)

func _run() -> void:
	main = load("res://Scenes/Main/main.tscn").instantiate()
	root.add_child(main)
	await physics_frame
	_stop_ticks(main)
	paused = false
	for node in get_nodes_in_group("movable_facilities") + get_nodes_in_group("loose_items"):
		node.queue_free()
	await physics_frame
	controller = main.get_node("ScarabMechanismController")
	controller.configure_for_level({"map_mechanism_ids": [&"scarab"]})
	controller.start_business()
	controller.max_active_scarabs = 0
	var map: Node2D = main.get_node("PrototypeMap")
	center = map.get_kitchen_zone_bounds().get_center()
	controller.storage_manager.fill_test_stock(0)
	# Leave all diagonals open: four blocked cardinal sides must prevent theft.
	var enclosed := _cabinet(center, &"crisp_sprout")
	controller.storage_manager.fill_test_stock(10)
	var walls: Array[Node2D] = []
	for offset in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
		var wall := _cabinet(center + offset * 128.0, &"sunny_berry")
		var allowed: Array[StringName] = [&"crisp_sprout"]
		wall.set_menu_allowed_item_ids(allowed)
		walls.append(wall)
	var first := _scarab(center + Vector2(-400, 0))
	var second := _scarab(first.global_position)
	await physics_frame
	controller._update_scarab_targets()
	_check(first.state == Enemy.State.SEARCHING, "Pending initial navigation must not be mistaken for unreachable food.")
	for frame in range(1000):
		await _step()
		if first.state == Enemy.State.ESCAPING and second.state == Enemy.State.ESCAPING:
			break
	_check(first.state == Enemy.State.ESCAPING and second.state == Enemy.State.ESCAPING, "With only a four-sided enclosed cabinet, both scarabs must physically reach escape corners and start casting.")
	_check(first.get_stolen_count() == 0 and second.get_stolen_count() == 0 and controller.storage_manager.get_stock(enclosed.stored_item_id) == 10, "An enclosed cabinet must not be stolen from through its neighbors.")
	var remaining: float = first.escape_remaining
	for frame in range(65):
		await _step()
	_check(first.escape_remaining < remaining - 0.9, "Failed searches must not restart the escape countdown.")

	# One newly dropped ingredient can interrupt only one of the two casts.
	var food := _food(center + Vector2(-450, 100))
	await physics_frame
	for frame in range(80):
		await _step()
		if first.current_target == food or second.current_target == food:
			break
	var claimant: Enemy = first if first.current_target == food else second
	var waiting: Enemy = second if claimant == first else first
	_check(claimant.current_target == food and claimant.state == Enemy.State.SEARCHING, "New reachable food must cancel an underfilled scarab's escape cast.")
	_check(is_zero_approx(claimant.escape_remaining) and claimant.escape_navigation_route.is_empty(), "Resuming theft must clear the old escape countdown and route.")
	_check(waiting.state == Enemy.State.ESCAPING and waiting.current_target == null, "Another scarab must keep escaping while the new target is claimed.")
	# Escape corners are now farther away in the expanded kitchen.
	for frame in range(1200):
		await _step()
		if claimant.get_stolen_count() == 1:
			break
	_check(claimant.get_stolen_count() == 1 and waiting.get_stolen_count() == 0, "The resumed actor must physically reach and steal the single ingredient exactly once.")
	_check(controller.escape_search_retry_times.has(waiting.get_instance_id()), "Unsuccessful escape searches must be throttled.")

	# A queued target must be released immediately, even before the next frame.
	var temporary_food := _food(center + Vector2(-500, 100))
	temporary_food.queue_free()
	var queued_targets: Array[Dictionary] = [{"node": temporary_food, "kind": &"ground"}]
	_check(controller._find_nearest_target(waiting, queued_targets).is_empty(), "Queued ingredients must not be claimed or stolen a second time.")

	# Opening the enclosing ring is also new availability, without a new node.
	for wall in walls:
		wall.queue_free()
	await physics_frame
	for frame in range(200):
		await _step()
		if first.current_target == enclosed or second.current_target == enclosed:
			break
	_check(first.current_target == enclosed or second.current_target == enclosed, "Opening a previously inaccessible cabinet must interrupt an underfilled escape.")
	if first.current_target == enclosed and second.current_target == enclosed:
		_check(first.target_approach_position != second.target_approach_position, "Shared cabinet claimants must use separate approach slots.")

	# Remove both actors, then verify same-position arrivals split across two
	# cabinets and keep ownership throughout the theft animation.
	first.queue_free()
	second.queue_free()
	await physics_frame
	# One portion per cabinet still limits this fixture to two claimants.
	controller.storage_manager.fill_test_stock(1)
	controller.cabinet_steal_duration = 3.0
	var other := _cabinet(center + Vector2(-500, -100), &"sunny_berry")
	first = _scarab(center + Vector2(-250, -200))
	second = _scarab(first.global_position)
	await physics_frame
	controller.navigation_retry_times.clear()
	controller._update_scarab_targets()
	_check(is_instance_valid(first.current_target) and is_instance_valid(second.current_target) and first.current_target != second.current_target, "Same-position arrivals must choose different reachable cabinets.")
	for frame in range(350):
		await _step()
		if first.state == Enemy.State.STEALING and second.state == Enemy.State.STEALING:
			break
	_check(first.state == Enemy.State.STEALING and second.state == Enemy.State.STEALING, "Both assigned scarabs must actually approach their separate cabinets and start stealing.")
	var replacement := _scarab(center + Vector2(-250, -200))
	controller._update_single_scarab_target(replacement)
	_check(replacement.state == Enemy.State.ESCAPING_TO_CORNER and replacement.current_target == null, "A third scarab must escape when both reachable cabinets are already claimed.")
	var released: Node = first.current_target
	first.receive_charged_hit(1)
	var after_death: Dictionary = controller._find_nearest_target(replacement, controller._collect_steal_targets())
	_check(after_death.get("node") == released, "A killed claimant must release its cabinet immediately.")
	for frame in range(80):
		await _step()
		if replacement.current_target == released:
			break
	if not (replacement.current_target == released and replacement.state == Enemy.State.SEARCHING):
		print("RESUME DEBUG replacement_state=%s target=%s released=%s escape_remaining=%s retry=%s" % [replacement.state, replacement.current_target, released, replacement.escape_remaining, controller.escape_search_retry_times])
	_check(replacement.current_target == released and replacement.state == Enemy.State.SEARCHING, "An underfilled scarab must resume theft while still walking toward its escape corner.")
	_check(second.current_target != replacement.current_target, "A stealing survivor must retain its exclusive claim.")

	# Capacity is permanent for this actor; plentiful food must not cancel a
	# full actor's escape. Underfilled actors may leave with zero items too.
	replacement.stolen_limit = 2
	replacement.add_stolen_item(&"crisp_sprout")
	replacement.add_stolen_item(&"crisp_sprout")
	controller._update_scarab_targets()
	_check(replacement.state == Enemy.State.ESCAPING_TO_CORNER, "A full scarab must not retarget while walking to its escape corner.")
	replacement.set_escape_target(replacement.global_position)
	replacement._physics_process(0.0)
	controller._update_scarab_targets()
	_check(replacement.state == Enemy.State.ESCAPING, "A full scarab's escape cast must not be interrupted by available food.")
	other.queue_free()
	enclosed.queue_free()
	second.queue_free()
	replacement.queue_free()
	await physics_frame
	var empty_handed := _scarab(center + Vector2(-500, 250))
	empty_handed.escape_duration = 0.2
	for frame in range(900):
		await _step()
		if not is_instance_valid(empty_handed) or empty_handed.is_queued_for_deletion():
			break
	_check(not is_instance_valid(empty_handed) or empty_handed.is_queued_for_deletion(), "With no food, a scarab must complete its escape instead of remaining idle forever.")
	controller.stop_business()
	_check(controller.escape_search_retry_times.is_empty(), "Day cleanup must remove escape-search retry state.")
	main.queue_free()
	await process_frame
	if failures.is_empty():
		print("PASS: enclosed-only escape, exclusive food claims, cast interruption, real theft, unblocking, claimant death, full-capacity escape and empty-handed exit.")
	quit(0 if failures.is_empty() else 1)
