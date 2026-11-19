extends SceneTree

const Enemy = preload("res://Scripts/Enemies/ScarabEnemy.gd")
const Cabinet = preload("res://Scenes/Restaurant/ingredient_storage_cabinet.tscn")
const Items = preload("res://Scripts/Kitchen/TestItemDefs.gd")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _stop_ticks(node: Node) -> void:
	node.set_process(false)
	node.set_physics_process(false)
	for child in node.get_children():
		_stop_ticks(child)

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)

func _cabinet(main: Node, position: Vector2, item_id: StringName) -> Node2D:
	var cabinet: Node2D = Cabinet.instantiate()
	cabinet.position = position
	cabinet.stored_item_id = item_id
	main.add_child(cabinet)
	_stop_ticks(cabinet)
	return cabinet

func _warm_navigation(controller: Node) -> void:
	for frame in range(90):
		await physics_frame
		controller.navigation_clock += 1.0 / 60.0
		controller._tick_navigation_cache()

func _run() -> void:
	var main: Node = load("res://Scenes/Main/main.tscn").instantiate()
	root.add_child(main)
	await physics_frame
	_stop_ticks(main)
	paused = false
	for fixture in get_nodes_in_group("movable_facilities"):
		fixture.queue_free()
	for item in get_nodes_in_group("loose_items"):
		item.queue_free()
	await physics_frame
	var controller: Node = main.get_node("ScarabMechanismController")
	controller._resolve_scene_refs()
	controller.boss_scarab_mode = false
	var map: Node2D = main.get_node("PrototypeMap")
	var center: Vector2 = map.get_kitchen_zone_bounds().get_center()
	var storage: Node = controller.storage_manager
	storage.fill_test_stock(10)
	var enclosed := _cabinet(main, center - Vector2(300, 0), &"meat_red")
	var open := _cabinet(main, center + Vector2(0, 400), &"crisp_sprout")
	var empty := _cabinet(main, center - Vector2(600, 150), &"sunny_berry")
	storage.consume_stock(empty.stored_item_id, storage.get_stock(empty.stored_item_id))
	var stone := _cabinet(main, center - Vector2(600, 300), &"meat_red")
	var allowed_items: Array[StringName] = [&"crisp_sprout"]
	stone.set_menu_allowed_item_ids(allowed_items)
	var scarab := Enemy.new()
	main.add_child(scarab)
	_stop_ticks(scarab)
	scarab.global_position = center - Vector2(600, 0)
	var walls: Array[Node] = []
	for offset in [Vector2(-180, 0), Vector2(180, 0), Vector2(0, -180), Vector2(0, 180)]:
		var wall := StaticBody2D.new()
		wall.collision_layer = 4
		wall.position = enclosed.position + offset
		var shape := RectangleShape2D.new()
		shape.size = Vector2(40, 400) if offset.x != 0 else Vector2(400, 40)
		var collision := CollisionShape2D.new()
		collision.shape = shape
		wall.add_child(collision)
		main.add_child(wall)
		walls.append(wall)
	await physics_frame
	controller._prime_navigation_bounds(map.get_kitchen_zone_bounds())
	await _warm_navigation(controller)
	var targets: Array[Dictionary] = controller._collect_steal_targets()
	_check(targets.size() == 2, "Only stocked, menu-enabled cabinets should be eligible; empty and stone cabinets must be excluded.")
	var choice: Dictionary = controller._find_nearest_target(scarab, targets)
	_check(choice.get("node") == open and not choice.get("route", []).is_empty(), "A nearer enclosed cabinet must lose to a reachable cabinet.")
	_check(scarab.current_target == null and storage.get_stock(open.stored_item_id) == 10, "Selection query must not assign targets or consume stock.")
	for wall in walls:
		wall.queue_free()
	await physics_frame
	await _warm_navigation(controller)
	choice = controller._find_nearest_target(scarab, controller._collect_steal_targets())
	_check(choice.get("node") == enclosed, "Removing blockers must make the nearer cabinet selectable using refreshed navigation.")
	scarab.set_target(enclosed, &"cabinet", choice.get("route", []))
	storage.consume_stock(enclosed.stored_item_id, 1)
	choice = controller._find_nearest_target(scarab, controller._collect_steal_targets())
	_check(choice.get("node") == enclosed, "A partly depleted nearest cabinet must remain preferred.")
	storage.consume_stock(enclosed.stored_item_id, storage.get_stock(enclosed.stored_item_id))
	_check(not controller._is_current_target_valid(scarab), "Emptying the current cabinet must invalidate it immediately.")
	controller._retarget_scarab(scarab)
	_check(scarab.current_target == open, "An empty current cabinet must be replaced by the next reachable source.")
	scarab.global_position = open.global_position + Vector2(0, 120)
	choice = controller._find_nearest_target(scarab, controller._collect_steal_targets())
	_check(choice.get("node") == open, "A source already in steal range must remain valid without a route.")
	open.queue_free()
	await physics_frame
	_check(not controller._is_current_target_valid(scarab), "Deleted targets must be invalidated safely.")
	_check(storage.get_available_stock(&"crisp_sprout") == storage.get_stock(&"crisp_sprout"), "Deleting a reserved source must safely release its stock reservation.")
	var ground: Node2D = load("res://Scenes/Restaurant/loose_item.tscn").instantiate()
	main.add_child(ground)
	_stop_ticks(ground)
	scarab.global_position = center
	ground.global_position = scarab.global_position + Vector2(70, 0)
	ground.setup_item(&"crisp_sprout", null)
	await physics_frame
	choice = controller._find_nearest_target(scarab, controller._collect_steal_targets())
	_check(choice.get("node") == ground and choice.get("kind") == &"ground", "Nearby loose ingredients must remain eligible.")
	scarab.set_target(ground, &"ground")
	_check(controller._is_current_target_valid(scarab), "Current loose ingredient must remain valid.")
	ground.setup_item(&"dish_crisp_plate", null)
	_check(not controller._is_current_target_valid(scarab) and controller._collect_steal_targets().is_empty(), "Prepared dishes must not become steal targets.")
	ground.setup_item(&"crisp_sprout", null)
	ground.visible = false
	_check(controller._collect_steal_targets().is_empty(), "Hidden loose ingredients must be excluded.")
	ground.visible = true
	var player: Node = main.get_node("Player")
	player.clear_held_item()
	for item_id: StringName in [Items.SANDWORM_CORE_ID, Items.SCORPION_CLAW_ID, Items.VULTURE_FEATHERHEART_ID]:
		for process_state: StringName in [Items.PROCESS_STATE_NONE, Items.PROCESS_STATE_CUT]:
			ground.setup_item(item_id, Items.get_item_texture(item_id), process_state)
			scarab.state = Enemy.State.SEARCHING
			scarab.set_target(ground, &"ground")
			_check(not controller._is_current_target_valid(scarab) and controller._collect_steal_targets().is_empty(), "Raw and processed Boss drops must never be scarab targets.")
			controller._on_scarab_steal_action_finished(scarab, ground, &"ground")
			_check(not ground.is_queued_for_deletion() and scarab.get_stolen_count() == 0, "A stale ground theft must not consume a Boss ingredient.")
		_check(ground.can_take_item(player), "Protected Boss ingredients must remain available to the player.")
		var protected_cabinet := _cabinet(main, center + Vector2(500, 0), item_id)
		storage.add_stock(item_id, 1)
		var boss_menu: Array[StringName] = [item_id]
		protected_cabinet.set_menu_allowed_item_ids(boss_menu)
		scarab.state = Enemy.State.SEARCHING
		scarab.set_target(protected_cabinet, &"cabinet")
		_check(not controller._is_current_target_valid(scarab) and controller._collect_steal_targets().is_empty(), "Boss stock must remain protected even inside an enabled cabinet.")
		controller._on_scarab_steal_action_finished(scarab, protected_cabinet, &"cabinet")
		_check(storage.get_stock(item_id) == 1 and scarab.get_stolen_count() == 0 and protected_cabinet.can_take_item(player), "A stale cabinet theft must preserve Boss stock and player access.")
	main.queue_free()
	await process_frame
	if failures.is_empty():
		print("PASS: cabinet eligibility, enclosed-target rejection, blocker removal, nearest-source reuse, deleted reservation cleanup, in-range selection and protected raw/processed Boss food.")
	quit(0 if failures.is_empty() else 1)
