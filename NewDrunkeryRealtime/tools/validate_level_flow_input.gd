extends SceneTree

const Context = preload("res://Scripts/Core/LevelContext.gd")
const Adapter = preload("res://Scripts/Core/LevelFlowInputAdapter.gd")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _key(code: Key, pressed: bool = true, echo: bool = false) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = pressed
	event.echo = echo
	return event

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
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
	var flow: Node = main.get_node("LevelFlowController")
	var player: Node = main.get_node("Player")
	flow.input_release_guard_active = false
	flow._enter_order_group_select()
	flow._input(_key(KEY_D))
	var selected: int = flow.order_group_select_controller.selected_group_index
	_check(selected >= 0, "Mapped navigation must select a real order group.")
	flow._input(_key(KEY_D, true, true))
	flow._input(_key(KEY_D, false))
	flow._input(_key(KEY_SHIFT))
	_check(flow.order_group_select_controller.selected_group_index == selected, "Echo, key release and modifier-only events must not move selection.")
	flow._input(_key(KEY_L))
	_check(flow.get_current_level_state() == Context.LevelState.MENU_DISH_SELECT, "L must open the menu from order selection.")
	flow.menu_update_is_mandatory = true
	flow.menu_dish_select_controller.pending_offer_index = 0
	flow._input(_key(KEY_K))
	_check(not flow.menu_dish_select_controller.has_pending_selection(), "Cancel must first clear a pending dish selection.")
	flow._input(_key(KEY_K))
	flow._input(_key(KEY_L))
	_check(flow.get_current_level_state() == Context.LevelState.MENU_DISH_SELECT, "Mandatory menu update must block cancel and switching to orders.")
	flow.menu_update_is_mandatory = false
	flow._input(_key(KEY_K))
	_check(flow.get_current_level_state() == Context.LevelState.NIGHT_REST, "K must close the optional menu.")
	_check(player.interaction_input_suppressed_frame == Engine.get_process_frames(), "Closing with K must suppress player interaction for that frame.")
	flow.input_release_guard_active = false
	flow._open_night_shop_overlay()
	flow.night_shop_controller.pending_forge_options.assign([{"title": "A"}, {"title": "B"}])
	flow.night_shop_controller.pending_forge_selection = 0
	flow._input(_key(KEY_K))
	_check(flow.get_current_level_state() == Context.LevelState.NIGHT_SHOP, "Pending forge must prevent leaving the shop.")
	flow._input(_key(KEY_D))
	_check(flow.night_shop_controller.pending_forge_selection == 1, "Forge navigation must route to forge options.")
	flow._input(_key(KEY_Q))
	_check(flow.night_shop_controller.pending_forge_selection == 1, "Other keys must not change a pending forge selection.")
	flow.night_shop_controller.pending_forge_options.clear()
	flow._input(_key(KEY_K))
	_check(flow.get_current_level_state() == Context.LevelState.NIGHT_REST, "Shop must close once no forge is pending.")
	flow.input_release_guard_active = false
	flow._enter_order_group_select()
	flow._input(_key(KEY_D))
	Input.action_press("ui_confirm")
	flow._input(_key(KEY_SPACE))
	_check(flow.day_transition_active and paused, "Confirm must start the real day transition and pause gameplay.")
	flow._update_day_transition(1.0)
	_check(not flow.day_transition_active and not paused, "A held confirm must never prolong the black transition.")
	_check(flow.get_current_level_state() == Context.LevelState.PREPARE_PHASE and not flow.overlay_controller.transition_layer.visible, "Timed transition must reveal preparation while confirm stays held.")
	player._process(0.0)
	_check(player.combat_controller.dash_time_remaining == 0.0, "Held transition confirm cannot trigger gameplay.")
	Input.action_release("ui_confirm")
	flow._update_day_transition(0.0)
	_check(not flow.day_transition_active and flow.get_current_level_state() == Context.LevelState.PREPARE_PHASE, "Releasing confirm after the delay must start preparation.")
	flow._enter_night_rest()
	Input.action_press("interact")
	flow._process(0.0)
	_check(not flow.input_release_guard_active and not paused and not flow.overlay_controller.transition_layer.visible, "Returning to night must resume without waiting for a held key.")
	Input.action_release("interact")
	flow._process(0.0)
	_check(not flow.input_release_guard_active and not paused, "Release guard must unpause after interaction is released.")
	# Remapping and physical-key fallback must both keep working.
	var remapped := _key(KEY_F8)
	InputMap.action_add_event("ui_confirm", remapped)
	_check(Adapter.decode(remapped, Context.LevelState.LEVEL_FAILED) == Adapter.Action.CONFIRM, "InputMap remapping must still confirm results.")
	InputMap.action_erase_event("ui_confirm", remapped)
	var physical := InputEventKey.new()
	physical.physical_keycode = KEY_K
	physical.pressed = true
	_check(Adapter.decode(physical, Context.LevelState.BLESSING_SELECT) == Adapter.Action.CANCEL, "Physical K fallback must close blessing selection.")
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
	wheel.pressed = true
	_check(Adapter.decode(wheel, Context.LevelState.NIGHT_SHOP) == Adapter.Action.SCROLL_DOWN, "Shop mouse wheel must remain mapped.")
	_check(Adapter.decode(wheel, Context.LevelState.NIGHT_SHOP, true) == Adapter.Action.CONSUME, "Forge overlay must consume wheel events without scrolling the shop.")
	_check(Adapter.decode(_key(KEY_J), Context.LevelState.MENU_DISH_SELECT) == Adapter.Action.CONFIRM, "J must still confirm a dish selection.")
	_check(Adapter.decode(_key(KEY_L), Context.LevelState.BLESSING_SELECT) == Adapter.Action.REFRESH, "L must still refresh blessings.")
	_check(Adapter.decode(_key(KEY_K), Context.LevelState.WAVE_ACTIVE) == Adapter.Action.NONE, "Gameplay interaction must pass through during service.")
	flow._enter_order_group_select()
	flow._on_blessing_card_mouse_entered(0)
	_check(flow.order_group_select_controller.hovered_group_index == 0, "Existing card hover route must remain intact.")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	await process_frame
	flow._on_blessing_card_gui_input(click, 0)
	_check(flow.day_transition_active, "Existing card click must still start the selected day.")
	main.queue_free()
	paused = false
	await process_frame
	if failures.is_empty():
		print("PASS: real flow navigation, menu/forge constraints, K suppression, echo/release filters, held-input transition guards, remapping and mouse routes.")
	quit(0 if failures.is_empty() else 1)
