extends SceneTree

const Items = preload("res://Scripts/Kitchen/TestItemDefs.gd")
const Carry = preload("res://Scripts/Kitchen/CarryItemRules.gd")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)

func _run() -> void:
	var main: Node = load("res://Scenes/Main/main.tscn").instantiate()
	root.add_child(main)
	await physics_frame
	paused = false
	main.process_mode = Node.PROCESS_MODE_DISABLED
	var player: Node2D = main.get_node("Player")
	var assembly: Node2D = main.get_node("AssemblyStation")
	_check(assembly.get_layout_footprint() == Vector2i(3, 2), "The larger assembly island reserves both rows for carrying and navigation.")
	_check(not assembly.show_interaction_debug, "Assembly interaction debug geometry is off by default.")
	player.clear_held_item()
	for index in range(6):
		var id: StringName = Items.INGREDIENT_IDS[index]
		_check(player.pick_up_item(id, Items.get_item_texture(id), Items.PROCESS_STATE_CUT), "Test portion enters hand.")
		_check(assembly.receive_item_from_player(player), "Six full-size ingredients still fit the assembly data model.")
	await process_frame
	var positions: Array[Vector2] = []
	for index in range(6):
		var local_position: Vector2 = assembly._get_item_local_position(index, 6)
		var world_position: Vector2 = assembly.item_layer.to_global(local_position)
		for previous: Vector2 in positions:
			_check(previous.distance_to(world_position) >= 72.0, "Full-size ingredient rectangles do not overlap across either row.")
		positions.append(world_position)
		var origin_offset: Vector2 = player.get_interaction_origin_world() - player.global_position
		player.global_position = world_position - origin_offset
		var selected: Dictionary = assembly._get_nearest_item_for_player(player)
		_check(selected.get("item_id") == Items.INGREDIENT_IDS[index], "Pickup selection follows the rendered two-row slot positions.")
	for sprite: Node2D in assembly.item_sprites.get_children():
		_check(sprite.global_scale.is_equal_approx(Vector2.ONE * 0.56), "Assembly ingredients keep the hand's normal world scale.")
	var table: Node2D = main.get_node("PrepTableA")
	_check((table.global_scale * table.meat_normal_scale).is_equal_approx(Vector2.ONE * 0.56), "Table items use the same world scale.")
	for name: String in ["TestCooker", "GrindCooker", "BakeCooker"]:
		var cooker: Node2D = main.get_node(name)
		_check((cooker.global_scale * cooker.item_normal_scale).is_equal_approx(Vector2.ONE * 0.56), "Cooking stations use the same world scale.")
	assembly.reset_state()
	player.clear_held_item()
	var content: Array[Dictionary] = []
	for index in range(6):
		content.append(Carry.portion(Items.INGREDIENT_IDS[index], Items.PROCESS_STATE_CUT))
	player.pick_up_item(Items.DISH_SANDWORM_ROYAL_HEAT_PLATE_ID, Items.get_item_texture(Items.DISH_SANDWORM_ROYAL_HEAT_PLATE_ID), &"", Items.get_recipe_signature(content), {"uses_plate": true})
	var view: RefCounted = player.interaction_controller.held_item_bubble
	_check(view.dish_icon.visible and view.slots[5].visible and view.panel.size.x == 376.0, "A six-portion dish shows its identity plus every ingredient without truncation.")
	player.clear_held_item()
	main.queue_free()
	await process_frame
	print("Kitchen presentation: %d failures" % failures.size())
	quit(0 if failures.is_empty() else 1)
