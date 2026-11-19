extends "res://tools/validate_scarab_target_lifecycle.gd"

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
	controller.storage_manager.fill_test_stock(0)
	center = main.get_node("PrototypeMap").get_kitchen_zone_bounds().get_center()
	controller.rng.seed = 7
	var victim := _scarab(center)
	victim.add_stolen_item(&"crisp_sprout")
	victim.add_stolen_item(&"sunny_berry")
	victim.receive_charged_hit(1)
	for frame in range(90):
		await _step()
	var drops := get_nodes_in_group("loose_items")
	_check(drops.size() == 2, "Defeating a loaded scarab must drop both ingredients.")
	var survivor := _scarab(center + Vector2(-450, 0))
	await physics_frame
	var choice: Dictionary = controller._find_nearest_target(survivor, controller._collect_steal_targets())
	print("LOOT REPRO: eligible=%s separation=%s choice=%s" % [controller._collect_steal_targets().size(), drops[0].global_position.distance_to(drops[1].global_position), choice.get("kind", &"")])
	_check(not choice.is_empty(), "Nearby loot must be reachable from outside theft range even when the food centers block each other.")
	for frame in range(600):
		await _step()
		if survivor.get_stolen_count() == 2:
			break
	_check(survivor.get_stolen_count() == 2, "A survivor must physically recover both ingredients dropped by a defeated scarab.")

	# The same failure can affect ordinary food pushed into a pile. Use real
	# hits and physics, then let an underfilled actor discover it from red cast.
	survivor.global_position = center + Vector2(-450, 0)
	survivor.begin_escape()
	survivor.set_escape_target(survivor.global_position)
	survivor._physics_process(0.0)
	var first := _food(center + Vector2(0, -20))
	var second := _food(center + Vector2(0, 20))
	first.set_physics_process(true)
	second.set_physics_process(true)
	await physics_frame
	first.receive_hit(100, Vector2.RIGHT)
	second.receive_hit(100, Vector2.RIGHT)
	for frame in range(90):
		await physics_frame
	_check(first.global_position.distance_to(center) > 50.0 and second.global_position.distance_to(center) > 50.0, "The attacked ingredients must actually move before testing their availability.")
	_check(first.is_scarab_steal_target() and second.is_scarab_steal_target(), "Hits must preserve ingredient eligibility.")
	var interrupted := false
	for frame in range(700):
		await _step()
		interrupted = interrupted or survivor.state in [Enemy.State.SEARCHING, Enemy.State.STEALING]
		if survivor.get_stolen_count() == 4:
			break
	_check(interrupted and survivor.get_stolen_count() == 4, "An underfilled red cast must be interrupted to recover both physically displaced ingredients.")
	survivor.queue_free()
	await physics_frame

	# A short distance alone must never allow theft through a facility.
	var food := _food(center)
	var actor := _scarab(center + Vector2(-90, 0))
	actor.set_physics_process(false)
	var wall := StaticBody2D.new()
	wall.collision_layer = 4
	var collision := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(12, 220)
	collision.shape = rectangle
	wall.add_child(collision)
	main.add_child(wall)
	wall.global_position = center + Vector2(-45, 0)
	await physics_frame
	for frame in range(65):
		await _step()
	_check(actor.get_stolen_count() == 0 and actor.state != Enemy.State.STEALING, "Food within range but behind a wall must not start a theft.")
	actor.set_physics_process(true)
	for frame in range(450):
		await _step()
		if actor.get_stolen_count() == 1:
			break
	_check(actor.get_stolen_count() == 1, "The scarab must walk around the wall to a clear food approach.")
	wall.queue_free()
	await physics_frame

	# Knock food away during its theft bar. Cancel the old action and approach
	# its new position instead of consuming it remotely when the bar finishes.
	actor.clear_target()
	actor.global_position = center + Vector2(-80, 0)
	food = _food(center)
	food.set_physics_process(true)
	await physics_frame
	controller.navigation_retry_times.clear()
	controller._update_single_scarab_target(actor)
	controller._process(0.0)
	_check(actor.state == Enemy.State.STEALING, "Nearby unobstructed food must start stealing immediately.")
	actor.set_physics_process(false)
	food.receive_hit(100, Vector2.RIGHT)
	for frame in range(40):
		await _step()
	_check(actor.get_stolen_count() == 1 and is_instance_valid(food) and actor.state != Enemy.State.STEALING, "Food knocked beyond reach during a theft must not be consumed remotely.")
	actor.set_physics_process(true)
	for frame in range(450):
		await _step()
		if actor.get_stolen_count() == 2:
			break
	_check(actor.get_stolen_count() == 2, "A cancelled theft must replan and physically recover the displaced food.")
	main.queue_free()
	await process_frame
	if failures.is_empty():
		print("PASS: death loot, hit-displaced piles, escape interruption, wall avoidance and theft displacement recovery.")
	quit(0 if failures.is_empty() else 1)
