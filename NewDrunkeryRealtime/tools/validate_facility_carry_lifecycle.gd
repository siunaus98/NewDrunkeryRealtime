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
	var player: CharacterBody2D = main.get_node("Player")
	var flow: Node = main.get_node("LevelFlowController")
	flow.run_context = Context.new()
	flow.run_context.state = Context.LevelState.NIGHT_REST
	var map: Node2D = main.get_node("PrototypeMap")
	# The enlarged kitchen's centre overlaps the assembly work island. Remove
	# all interactables here so this remains an isolated placement lifecycle test.
	for fixture in get_nodes_in_group("pickup_drop_targets"):
		fixture.queue_free()
	await physics_frame
	var cell: Vector2i = map.get_cell_for_point(map.get_kitchen_zone_bounds().get_center())
	var center: Vector2 = map.to_global(Vector2(cell) * map.tile_size + map.tile_size * 0.5)
	var cooker: Node2D = load("res://Scenes/Restaurant/test_cooker.tscn").instantiate()
	cooker.scale = Vector2.ONE * 0.17
	cooker.position = center + Vector2(512, 0)
	main.add_child(cooker)
	_stop_ticks(cooker)
	var origin := cooker.global_position
	var blocker: StaticBody2D = cooker.get_node("ItemBlocker")
	var controller: RefCounted = player.facility_carry_controller
	player.global_position = center - player.get_node("CollisionShape2D").position
	player.aim_direction = Vector2.RIGHT
	var speed_before: float = player.get_current_move_speed()
	player._pick_up_facility(cooker)
	await physics_frame
	_check(player.get_carried_facility_node() == cooker and not cooker.visible, "Pickup must hide the real fixture and expose the carried fixture immediately.")
	_check(cooker.collision_layer == 0 and blocker.collision_layer == 0, "Pickup must disable both fixture and child blocker and stop wandering.")
	_check(is_equal_approx(player.get_current_move_speed(), speed_before), "Night carrying retains normal movement speed.")
	player._try_dash()
	_check(player.combat_controller.is_dash_active(), "Night carrying permits dash.")
	player.combat_controller.dash_time_remaining = 0.0
	player.combat_controller.dash_cooldown_remaining = 0.0
	flow.run_context.state = Context.LevelState.PREPARE_PHASE
	_check(is_equal_approx(player.get_current_move_speed(), speed_before * player.carried_facility_move_speed_multiplier), "Daytime carrying retains the movement penalty.")
	player._try_dash()
	_check(not player.combat_controller.is_dash_active(), "Daytime carrying still prevents dash.")
	flow.run_context.state = Context.LevelState.NIGHT_REST
	var hand: Node2D = player.facility_preview_controller.get_hand_preview_root()
	_check(hand.visible and hand.get_child_count() > 0 and not controller.get_sprite_previews().is_empty(), "Pickup signal must build the existing sprite hand preview.")
	_check(not controller.pick_up(cooker) and controller.get_original_position() == origin, "Repeated pickup must not overwrite the saved collision state or origin.")
	var geometry: Dictionary = PlacementQuery.calculate(player, cooker)
	_check(geometry.valid, "Fixture must begin with an open target cell.")
	for i in range(3):
		PlacementQuery.calculate(player, cooker)
	_check(cooker.global_position == origin and not cooker.visible and cooker.collision_layer == 0, "Placement queries must not move, reveal or restore the carried fixture.")

	# A cached green preview must not permit a newly occupied placement.
	var obstacle := StaticBody2D.new()
	obstacle.collision_layer = 4
	obstacle.position = geometry.position
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(40, 40)
	collision.shape = shape
	obstacle.add_child(collision)
	main.add_child(obstacle)
	await physics_frame
	player._handle_interact()
	_check(player.is_carrying_facility() and not controller.can_place_facility(), "Interact must reject a newly blocked target and keep carrying.")
	_check(cooker.global_position == origin and cooker.collision_layer == 0 and hand.visible, "Rejected placement must preserve the hidden fixture and its preview.")
	obstacle.queue_free()
	await physics_frame

	# Fixed cooking stations can be manually moved without spending magic.
	flow.run_context.state = Context.LevelState.PREPARE_PHASE
	flow.magic_current = 0
	controller.tick(true)
	_check(controller.can_place_facility(), "Fixed stations must not charge magic for manual rearrangement.")
	for i in range(3):
		controller.tick(true)
	_check(flow.magic_current == 0, "Preview must not spend magic.")
	player._handle_interact()
	_check(not player.is_carrying_facility() and flow.magic_current == 0, "Manual placement succeeds with zero magic.")
	_check(cooker.visible and cooker.collision_layer == 4 and blocker.collision_layer == 16, "Successful placement must restore every collider and facility behavior.")
	_check(cooker.global_position == geometry.position and not hand.visible and controller.get_sprite_previews().is_empty(), "Commit must use the displayed target and clear previews.")
	_check(is_equal_approx(player.get_current_move_speed(), speed_before), "Placing must remove the carrying slowdown immediately.")
	player._try_place_carried_facility()
	_check(flow.magic_current == 0, "Repeated commit with empty hands must not spend magic.")

	# Losing rearrangement permission returns the fixture, without charging.
	var placed_position := cooker.global_position
	player._pick_up_facility(cooker)
	flow.run_context.state = Context.LevelState.LEVEL_SUCCESS
	player._process(0.0)
	_check(not player.is_carrying_facility() and cooker.global_position == placed_position and cooker.visible, "Stage transition must return the carried fixture to its pickup position.")
	_check(cooker.collision_layer == 4 and blocker.collision_layer == 16 and not hand.visible and flow.magic_current == 0, "Cancellation must restore both colliders and hide preview without charging.")
	flow.run_context.state = Context.LevelState.NIGHT_REST
	player._pick_up_facility(cooker)
	cooker.queue_free()
	await physics_frame
	player._process(0.0)
	_check(not player.is_carrying_facility() and not hand.visible and controller.get_placement_rect() == Rect2(), "Deleting a carried fixture must clear stale placement and preview state.")

	# Procedural facilities use the fallback preview and rotation input route.
	var conveyor: Node2D = load("res://Scenes/Restaurant/support_facility.tscn").instantiate()
	conveyor.position = center + Vector2(512, 256)
	main.add_child(conveyor)
	_stop_ticks(conveyor)
	# Support facilities now have imported art; hide it deliberately to retain
	# coverage of the geometry-only fallback used when no sprite is available.
	conveyor.art_sprite.visible = false
	player._pick_up_facility(conveyor)
	await process_frame
	_check(hand.visible and hand.get_child_count() > 0 and controller.get_sprite_previews().is_empty(), "Procedural facilities must still display their fallback hand preview.")
	var old_direction: int = conveyor.conveyor_direction
	player._try_rotate_carried_facility()
	await process_frame
	_check(conveyor.conveyor_direction == -old_direction and player.get_carried_facility_node() == conveyor and hand.visible, "Rotation must update the carried fixture and keep its preview alive.")
	controller.cancel_carry()
	_check(conveyor.visible and not conveyor.is_carried and conveyor.collision_layer == 4 and conveyor.get_node("ItemBlocker").collision_layer == 16, "Procedural fixture cancellation must restore its complete collision state.")
	main.queue_free()
	await process_frame
	if failures.is_empty():
		print("PASS: carry lifecycle, night full-speed movement/dash, daytime penalties, previews, placement, cancellation and rotation.")
	quit(0 if failures.is_empty() else 1)

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)
