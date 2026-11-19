extends SceneTree

func _initialize() -> void:
	var main_scene: Node = load("res://Scenes/Main/main.tscn").instantiate()
	root.add_child(main_scene)
	await physics_frame
	await physics_frame
	var controller: Node = main_scene.get_node("ScarabMechanismController")
	controller.active = true
	controller._resolve_scene_refs()
	main_scene.get_node("PrototypeMap").rng.seed = 1090
	_assert(controller._spawn_scarab(), "A scarab must spawn in the real main-scene physics world.")
	await physics_frame
	controller._update_scarab_targets()
	var scarabs := get_nodes_in_group("scarab_enemies")
	_assert(not scarabs.is_empty(), "Runtime spawning must create a scarab node.")
	var scarab: CharacterBody2D = scarabs.back() as CharacterBody2D
	# Blocked direct approaches use the same time-sliced navigation cache as
	# boss arrivals. One update is not a complete route-search deadline.
	for frame in range(360):
		if is_instance_valid(scarab.current_target):
			break
		await physics_frame
		controller.navigation_clock += 1.0 / 60.0
		controller._tick_navigation_cache()
		controller._update_scarab_targets()
	_assert(scarab.current_target != null, "A spawned scarab must acquire an eligible ingredient target.")
	var initial_position := scarab.global_position
	for _frame in range(45):
		await physics_frame
	_assert(scarab.global_position.distance_to(initial_position) > 12.0 or scarab.get_state() != 0, "A scarab with a target must move or begin stealing in the real scene.")
	print("Scarab runtime OK: spawned scarab acquired a target and acted in the main-scene physics world.")
	quit(0)

func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
