extends SceneTree

const Items = preload("res://Scripts/Kitchen/TestItemDefs.gd")
const Context = preload("res://Scripts/Core/LevelContext.gd")
var failures: int = 0

func _initialize() -> void:
	call_deferred("_run")

func _check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

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
	main.get_node("LevelFlowController").run_context.state = Context.LevelState.PREPARE_PHASE
	var player: Node = main.get_node("Player")
	var orders: Node = main.get_node("OrderManager")
	var counter: Node = main.get_node("TestServingCounter")
	var station: Node = load("res://Scenes/Restaurant/assembly_station.tscn").instantiate()
	main.add_child(station)
	_stop_ticks(station)
	var table: Node = load("res://Scenes/Restaurant/test_table.tscn").instantiate()
	main.add_child(table)
	_stop_ticks(table)
	table.reset_state()
	var recipe: Array = Items.get_recipe_for_dish(Items.DISH_SPICED_LAMB_ID)
	orders.set_orders([{"order_id": "transfer-check", "target_slot": counter.slot_number_offset + 1, "dish_item_id": Items.DISH_SPICED_LAMB_ID, "recipe_items": recipe}])
	orders.take_order_at_slot(counter.slot_number_offset + 1)
	counter.focused_slot_index = 0
	# Generate both exact and off-spec dishes through the real assembly entry point.
	for exact in [true, false]:
		station.stored_items.clear()
		player.clear_held_item()
		for entry in recipe:
			var state: StringName = entry.get("process_state", Items.PROCESS_STATE_NONE)
			if not exact and state in [Items.PROCESS_STATE_ROAST_MEDIUM, Items.PROCESS_STATE_ROAST_WELL]:
				state = Items.PROCESS_STATE_ROAST_RARE
			elif not exact and state == Items.PROCESS_STATE_GRIND_COARSE:
				state = Items.PROCESS_STATE_GRIND_FINE
			elif not exact and state == Items.PROCESS_STATE_GRIND_FINE:
				state = Items.PROCESS_STATE_GRIND_COARSE
			for count_index in range(int(entry.get("count", 1))):
				player.pick_up_item(entry.item_id, Items.get_item_texture(entry.item_id), state)
				_check(station.receive_item_from_player(player), "Recipe ingredients must transfer into the station.")
		_check(station.interact_with_player(player), "Assembly must produce a dish.")
		_check(player.pick_up_item(Items.PLATE_ID, Items.get_item_texture(Items.PLATE_ID)) and station.take_item_to_player(player), "A finished dish must be retrieved with a plate.")
		var signature: String = player.get_held_item_recipe_signature()
		var texture: Texture2D = player.get_held_item_texture()
		_check(not signature.is_empty() and player.get_held_item_id() == Items.DISH_SPICED_LAMB_ID, "Generated dish must carry its actual recipe signature.")
		_check(counter._held_item_matches_order(player) == exact, "Initial serving classification must match preparation.")
		for round_trip in range(2):
			_check(station.receive_item_from_player(player) and not player.is_holding_item() and station.stored_items.size() == 1, "Placing a finished dish transfers exactly one item.")
			_check(not station.receive_item_from_player(player) and station.stored_items.size() == 1, "Repeated placement with empty hands must not duplicate food.")
			_check(station.take_item_to_player(player) and station.stored_items.is_empty(), "Taking a finished dish empties the station.")
			_check(player.get_held_item_recipe_signature() == signature and player.get_held_item_texture() == texture, "Assembly round-trip must preserve recipe signature and texture.")
			_check(table.receive_item_from_player(player) and table.take_item_to_player(player), "Table round-trip must succeed.")
			_check(counter.can_receive_item(player) == exact and counter._held_item_matches_order(player) == exact, "Only the requested maturation may be served after temporary placement.")
		# Rejection must preserve both the held dish and existing station contents.
		station.stored_items.append({"item_id": Items.TEST_ITEM_ID, "process_state": Items.PROCESS_STATE_CUT})
		var saved: Array = station.stored_items.duplicate(true)
		_check(not station.receive_item_from_player(player), "A finished dish must be rejected by an occupied station.")
		_check(station.stored_items == saved and player.get_held_item_recipe_signature() == signature and player.get_held_item_id() == Items.DISH_SPICED_LAMB_ID, "Rejected placement must preserve both sides of the transfer.")
	# Legacy unsigned dishes remain unsigned; placing them must not certify them.
	station.stored_items.clear()
	player.clear_held_item()
	player.pick_up_item(Items.DISH_SPICED_LAMB_ID, null, &"", "", {"uses_plate": true})
	_check(station.receive_item_from_player(player) and station.take_item_to_player(player), "Unsigned dish round-trip must remain supported.")
	_check(player.get_held_item_recipe_signature().is_empty() and not counter._held_item_matches_order(player), "Missing signatures must remain missing.")
	main.queue_free()
	await process_frame
	if failures == 0:
		print("PASS: real exact/off-spec assembly, repeated station/table transfers, serving classification, rejected placement and unsigned dishes.")
	quit(0 if failures == 0 else 1)
