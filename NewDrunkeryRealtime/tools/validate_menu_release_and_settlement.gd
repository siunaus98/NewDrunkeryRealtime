extends SceneTree

const Context = preload("res://Scripts/Core/LevelContext.gd")
const Adapter = preload("res://Scripts/Core/LevelFlowInputAdapter.gd")
var failures: Array[String] = []
var flow: Node
var player: Node

func _initialize() -> void:
	call_deferred("_run")

func _check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)

func _stop_ticks(node: Node) -> void:
	node.set_process(false)
	node.set_physics_process(false)
	for child: Node in node.get_children():
		_stop_ticks(child)

func _settle() -> void:
	for index: int in range(5):
		await process_frame

func _run() -> void:
	root.size = Vector2i(1920, 1080)
	var main: Node = load("res://Scenes/Main/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	await _settle()
	_stop_ticks(main)
	flow = main.get_node("LevelFlowController")
	player = flow.player
	flow.input_release_guard_active = false
	flow.overlay_controller.set_transition_visible(false)
	paused = false
	await _settle()
	player._process(0.0)
	# Exercise the actual event confirmation path with Space still held.
	# The regression uses any active visitor, independent of the playtest batch.
	var event_id: StringName = flow.night_event_controller._night_event_ids()[0]
	var npc: Node = flow.night_event_controller.npcs[event_id]
	npc.interact_with_player(player)
	flow.night_event_controller.dialogue.selected_index = flow.night_event_controller.options.size() - 1
	Input.action_press("dash")
	Input.action_press("ui_confirm")
	flow._handle_flow_input_action(Adapter.Action.CONFIRM)
	_check(flow.run_context.state == Context.LevelState.NIGHT_REST, "Decline must close NPC dialogue")
	player._process(0.016)
	_check(player.input_gate.is_blocked(&"dash") and player.combat_controller.dash_time_remaining == 0.0, "NPC confirm cannot become a dash")
	await _settle()
	player._process(0.016)
	_check(player.input_gate.is_blocked(&"dash"), "Held Space stays blocked across frames")
	Input.action_press("move_right")
	_check(player.input_gate.get_movement() == Vector2.RIGHT, "New movement must work immediately while menu Space remains held")
	var gold_before: int = flow.progression_state.gold
	Input.action_press("skill_small")
	player._process(0.0)
	_check(not player.input_gate.is_blocked(&"skill_small"), "A new skill press must pass the input gate while menu Space remains held")
	_check(flow.progression_state.gold == gold_before and player.combat_controller.dash_time_remaining == 0.0, "Unrelated actions cannot revive the blocked dash or repeat the NPC trade")
	Input.action_release("move_right")
	Input.action_release("skill_small")
	Input.action_release("ui_confirm")
	Input.action_release("dash")
	player._process(0.0)
	_check(player.input_gate.is_blocked(&"dash"), "Release frame must also stay blocked")
	await _settle()
	player._process(0.0)
	_check(not player.input_gate.is_blocked(&"dash"), "Releasing menu input restores gameplay")
	Input.action_press("dash")
	player._process(0.0)
	_check(player.combat_controller.dash_time_remaining > 0.0, "A fresh Space press must still dash")
	Input.action_release("dash")
	player.combat_controller.dash_time_remaining = 0.0
	# Mouse close and unrelated secondary menus share the pause boundary guard.
	for action: StringName in [&"pickup_drop", &"interact", &"primary_attack", &"skill_small", &"skill_big", &"move_right"]:
		paused = true
		Input.action_press(action)
		paused = false
		player._process(0.0)
		_check(player.input_gate.is_blocked(action) and player.movement_input_direction == Vector2.ZERO, "Menu input must remain isolated: %s" % action)
		Input.action_release(action)
		await _settle()
		player._process(0.0)
		_check(not player.input_gate.is_blocked(action), "Menu release must recover: %s" % action)
	main._show_pause_menu()
	Input.action_press("primary_attack")
	main._hide_pause_menu()
	_check(player.input_gate.is_blocked(&"primary_attack"), "Mouse resume from pause must isolate held attack")
	Input.action_release("primary_attack")
	main.codex_controller.open_codex()
	Input.action_press("interact")
	main.codex_controller._close()
	_check(player.input_gate.is_blocked(&"interact"), "Codex close must isolate held work input")
	Input.action_release("interact")
	await _validate_pause_keyboard(main)
	await _validate_settlement()
	main.queue_free()
	paused = false
	await process_frame
	if failures.is_empty():
		print("PASS: NPC confirm, held/released/fresh gameplay inputs, pause/codex close and bounded settlement layouts.")
	quit(0 if failures.is_empty() else 1)

func _send_pause_key(key: Key) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = key
	event.keycode = key
	event.pressed = true
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	await process_frame
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	await process_frame

func _validate_pause_keyboard(main: Node) -> void:
	main._show_pause_menu()
	_check(paused and main.pause_menu.selected_index == 0, "Pause starts with Continue selected")
	await _send_pause_key(KEY_W)
	_check(main.pause_menu.selected_index == 2, "W wraps from Continue to owned blessings while paused")
	await _capture("pause_keyboard")
	await _send_pause_key(KEY_SPACE)
	_check(main.codex_controller.is_open() and main.codex_controller.current_category == main.codex_controller.CATEGORY_BLESSINGS, "Space activates owned blessings from the paused keyboard menu")
	main.codex_controller._close()
	main._show_pause_menu()
	await _send_pause_key(KEY_S)
	_check(main.pause_menu.selected_index == 1, "S moves to Codex")
	await _send_pause_key(KEY_D)
	_check(main.pause_menu.selected_index == 2, "D moves to owned blessings")
	await _send_pause_key(KEY_A)
	_check(main.pause_menu.selected_index == 1, "A moves back to Codex")
	await _send_pause_key(KEY_SPACE)
	_check(main.codex_controller.is_open() and not main.pause_menu_visible, "Space opens Codex from pause")
	main.codex_controller._close()
	main._show_pause_menu()
	await _send_pause_key(KEY_SPACE)
	_check(not paused and not main.pause_menu_visible, "Space activates Continue")
	player._process(0.0)
	_check(player.combat_controller.dash_time_remaining == 0, "Pause confirmation does not leak into a gameplay dash")
	main._show_pause_menu()
	await _send_pause_key(KEY_ESCAPE)
	_check(not paused and not main.pause_menu_visible, "Escape closes the keyboard pause menu")

func _validate_settlement() -> void:
	var overlay: Node = flow.overlay_controller
	var context: Context = flow.run_context
	context.selected_order_group = {"day_index": 3, "reward": &"forge", "tier": 3}
	context.completed_orders = 13
	context.failed_orders = 2
	context.reputation = 76
	flow.progression_state.gold = 2431
	var before: Dictionary = flow.progression_state.get_snapshot().duplicate(true)
	var notice: String = "赌徒契约 · 挑战失败，已扣除当日营业收入的一半。\n".repeat(16)
	for viewport_size: Vector2i in [Vector2i(1920, 1080), Vector2i(1280, 720)]:
		root.content_scale_size = viewport_size
		root.size = viewport_size
		overlay.show_result(true, "所有订单已结算，明日还将迎来新的挑战。", context, flow.progression_state, notice)
		await _settle()
		var result: Control = overlay.settlement_panel
		_check(result.get_global_rect().encloses(result.panel.get_global_rect()), "Settlement panel stays inside viewport")
		_check(result.panel.get_global_rect().encloses(result.hint.get_global_rect()), "Continue hint stays inside panel")
		_check(result.panel.get_global_rect().encloses(result.stats.get_global_rect()), "Statistics stay inside panel")
		_check(result.summary_scroll.get_v_scroll_bar().max_value > result.summary_scroll.size.y, "Long notices scroll instead of expanding the panel")
		_check(not overlay.overlay_panel.visible and not overlay.debug_label.visible, "Settlement hides generic overlay and debug text")
		_check(result.heading.text.contains("3") and result.stats.get_child_count() == 6, "Settlement retains day and six statistics")
		await _capture("settlement_success_%d" % viewport_size.x)
	context.selected_order_group = {"day_index": 7, "final_boss": true}
	overlay.show_result(true, "特殊客人已满意离席，七日盛宴圆满落幕。", context, flow.progression_state)
	await _settle()
	_check(overlay.settlement_panel.title.text.contains("通关") and overlay.settlement_panel.hint.text.contains("返回标题"), "Final victory keeps correct continuation")
	await _capture("settlement_victory")
	overlay.show_result(false, "声望耗尽，本次营业结束。", context, flow.progression_state)
	await _settle()
	_check(overlay.settlement_panel.title.text.contains("未能") and overlay.settlement_panel.hint.text.contains("重新开始"), "Failure keeps correct continuation")
	await _capture("settlement_failure")
	_check(before == flow.progression_state.get_snapshot(), "Settlement presentation cannot mutate run progression")
	overlay.set_layout_mode(true)
	_check(not overlay.settlement_panel.visible and overlay.overlay_panel.visible, "Returning to another menu hides settlement")

func _capture(filename: String) -> void:
	if OS.get_cmdline_user_args().has("--capture"):
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://_artifact_work/%s.png" % filename)
