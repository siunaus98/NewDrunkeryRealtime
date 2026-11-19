extends SceneTree

const Items = preload("res://Scripts/Kitchen/TestItemDefs.gd")
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
	await process_frame
	_stop_ticks(main)
	paused = false
	var player: Node = main.get_node("Player")
	var controller: RefCounted = player.interaction_controller
	var prompt: Control = controller.prompt_view.interaction_button_prompt
	var table: Node = load("res://Scenes/Restaurant/test_table.tscn").instantiate()
	main.add_child(table)
	_stop_ticks(table)
	table.reset_state()
	player.clear_held_item()
	player.pick_up_item(Items.TEST_ITEM_ID, null)
	table.receive_item_from_player(player)
	controller._set_current_interaction_target(table)
	await process_frame
	_check(prompt.visible and prompt.get_node("ActionLabel_J").text == "拿起", "Real table focus must retain the pickup prompt.")
	_check(table.has_item and not player.is_holding_item(), "Rendering a prompt must not transfer food.")
	var first_key: Node = prompt.get_node("Keycap_J")
	for repeat in range(3):
		controller._update_interaction_button_prompt()
	_check(prompt.get_node("Keycap_J") == first_key, "Unchanged actions must reuse their key nodes.")
	controller.handle_pickup_drop(Vector2.RIGHT)
	controller._update_interaction_button_prompt()
	await process_frame
	_check(prompt.get_node("ActionLabel_J").text == "放下" and player.is_holding_item(), "Actual pickup must update the action through existing eligibility.")
	controller._set_current_interaction_target(null)
	await process_frame
	_check(not prompt.visible, "Losing a target must hide its prompt.")
	# Exercise parsing and bottom anchoring separately from gameplay eligibility.
	var view: RefCounted = controller.prompt_view
	view.update_prompt("j TAKE + K MOVE / J PLACE / invalid ignored", -154.0)
	await process_frame
	_check(prompt.get_child_count() == 4 and prompt.get_node("ActionLabel_K").text == "搬起", "Parsing must normalize keys, localize labels and suppress duplicates/invalid keys.")
	_check(prompt.size == Vector2(126, 84) and prompt.position == Vector2(-63, -200), "Two-row layout must preserve its dimensions and bottom anchor.")
	var key: Node = prompt.get_node("Keycap_K")
	view.update_prompt("j TAKE + K MOVE / J PLACE / invalid ignored", -176.0)
	_check(prompt.get_node("Keycap_K") == key and prompt.position.y == -222.0, "An unchanged two-row prompt must move with its bottom anchor without rebuilding.")
	view.update_prompt("空格 HOLD、退出 TASK", -154.0)
	await process_frame
	_check(prompt.get_node("ActionLabel_SPACE").text == "采集" and prompt.get_node("ActionLabel_ESC").text == "任务", "Chinese key aliases and separators must retain their labels.")
	view.update_prompt("K 自定义操作", -154.0)
	_check(prompt.get_child_count() == 2 and prompt.get_node("ActionLabel_K").text == "自定义操作", "Rebuilding must immediately detach old rows before deferred deletion.")
	await process_frame
	_check(prompt.get_node("ActionLabel_K").text == "自定义操作" and prompt.position.y == -154.0, "Unknown action labels must remain intact in a single row.")
	view.update_prompt("", -154.0)
	await process_frame
	_check(not prompt.visible and prompt.get_child_count() == 0, "Empty prompts must hide and release old keys.")
	# Existing process bubble must still lift the prompt through the controller.
	player.clear_held_item()
	player.pick_up_item(Items.TEST_ITEM_ID, null, Items.PROCESS_STATE_CUT)
	controller._set_current_interaction_target(table)
	await process_frame
	_check(controller.process_status_bubble.visible and prompt.position.y == controller.process_status_bubble.position.y - 44.0, "Processed-food bubble must retain the six-pixel gap above it.")
	main.queue_free()
	await process_frame
	_check(not is_instance_valid(prompt), "Player cleanup must release the prompt subtree.")
	if failures == 0:
		print("PASS: real prompt updates, read-only rendering, key reuse, parsing/localization, row anchoring, bubble clearance and cleanup.")
	quit(0 if failures == 0 else 1)
