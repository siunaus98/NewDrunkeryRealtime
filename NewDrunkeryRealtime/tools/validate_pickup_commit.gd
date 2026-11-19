extends SceneTree

const Items = preload("res://Scripts/Kitchen/TestItemDefs.gd")
var failures: int = 0

# Deliberately separates eligibility from acceptance to detect callers bypassing policy.
class PickupProbe extends Node2D:
	var allowed: bool = false
	var accept: bool = true
	var calls: int = 0
	func can_pick_up_item(_id: StringName, _state: StringName, _payload: Dictionary = {}) -> bool:
		return allowed
	func pick_up_item(_id: StringName, _texture: Texture2D, _state: StringName, _signature: String = "", _payload: Dictionary = {}) -> bool:
		calls += 1
		return accept

func _initialize() -> void:
	call_deferred("_run")

func _check(condition: bool, message: String) -> void:
	if not condition:
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
	var player: Node = main.get_node("Player")
	var probe := PickupProbe.new()
	main.add_child(probe)
	var table: Node = load("res://Scenes/Restaurant/test_table.tscn").instantiate()
	main.add_child(table)
	_stop_ticks(table)
	table.reset_state()
	player.clear_held_item()
	# Exercise the real dispatch: empty tables remain focusable for carrying.
	player.interaction_controller._set_current_interaction_target(table)
	player.interaction_controller.handle_pickup_drop(Vector2.RIGHT)
	_check(not player.is_holding_item() and not table.has_item, "An empty focused table must not create its default ingredient on J.")
	player.clear_held_item()
	player.pick_up_item(Items.TEST_ITEM_ID, Items.get_item_texture(Items.TEST_ITEM_ID), Items.PROCESS_STATE_CUT, "pickup-regression")
	_check(table.receive_item_from_player(player), "Occupied-table setup must use the normal receive path.")
	_check(not table.take_item_to_player(probe) and probe.calls == 0 and table.has_item, "Table commit must honor current pickup eligibility.")
	probe.allowed = true
	probe.accept = false
	_check(not table.take_item_to_player(probe) and table.has_item, "Rejected pickup must retain the table item.")
	_check(table.take_item_to_player(player), "Valid table pickup must succeed.")
	_check(player.get_held_item_process_state() == Items.PROCESS_STATE_CUT and player.get_held_item_recipe_signature() == "pickup-regression", "Table transfer must preserve processing state and recipe signature.")
	player.clear_held_item()
	_check(not table.take_item_to_player(player) and not player.is_holding_item(), "A consumed table item must not be picked up twice.")
	var assembly: Node = load("res://Scenes/Restaurant/assembly_station.tscn").instantiate()
	main.add_child(assembly)
	_stop_ticks(assembly)
	player.clear_held_item()
	player.pick_up_item(Items.TEST_ITEM_ID, null, Items.PROCESS_STATE_CUT)
	_check(assembly.receive_item_from_player(player), "Assembly setup must use the normal receive path.")
	probe.allowed = false
	probe.accept = true
	probe.calls = 0
	_check(not assembly.take_item_to_player(probe) and probe.calls == 0 and assembly.stored_items.size() == 1, "Assembly commit must honor current pickup eligibility.")
	probe.allowed = true
	probe.accept = false
	_check(not assembly.take_item_to_player(probe) and assembly.stored_items.size() == 1, "Rejected assembly pickup must retain the item.")
	_check(assembly.take_item_to_player(player) and assembly.stored_items.is_empty(), "Valid assembly pickup removes exactly one item.")
	player.clear_held_item()
	_check(not assembly.take_item_to_player(player), "An empty assembly station must reject pickup.")
	var loose: Node = load("res://Scenes/Restaurant/loose_item.tscn").instantiate()
	main.add_child(loose)
	_stop_ticks(loose)
	loose.setup_item(Items.TEST_ITEM_ID, Items.get_item_texture(Items.TEST_ITEM_ID), Items.PROCESS_STATE_CUT, "loose-regression")
	probe.allowed = false
	probe.accept = true
	probe.calls = 0
	_check(not loose.take_item_to_player(probe) and probe.calls == 0 and not loose.is_queued_for_deletion(), "Loose-item commit must honor current pickup eligibility.")
	probe.allowed = true
	probe.accept = false
	_check(not loose.take_item_to_player(probe) and not loose.is_queued_for_deletion(), "Rejected loose-item pickup must keep the item alive.")
	_check(loose.take_item_to_player(player), "Valid loose-item pickup must succeed.")
	_check(player.get_held_item_process_state() == Items.PROCESS_STATE_CUT and player.get_held_item_recipe_signature() == "loose-regression", "Loose-item transfer must preserve processing state and recipe signature.")
	player.clear_held_item()
	_check(not loose.can_take_item(player) and not loose.take_item_to_player(player) and not player.is_holding_item(), "Queued deletion must immediately block a second pickup in the same frame.")
	player.interaction_controller._set_current_interaction_target(null)
	main.queue_free()
	await process_frame
	if failures == 0:
		print("PASS: empty-table J dispatch, eligibility at commit, rejected transfers, metadata preservation and same-frame duplicate prevention.")
	quit(0 if failures == 0 else 1)
