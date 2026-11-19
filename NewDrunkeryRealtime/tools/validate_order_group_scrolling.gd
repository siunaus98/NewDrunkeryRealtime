extends SceneTree

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)

func settle() -> void:
	for frame in range(6):
		await process_frame

func check_visible(controller: Node, overlay: Node) -> void:
	var card: Control = overlay.blessing_card_panels[controller.selected_group_index]
	var view: Rect2 = overlay.cards_scroll.get_global_rect()
	var rect := card.get_global_rect()
	check(rect.position.x >= view.position.x - 1 and rect.end.x <= view.end.x + 1, "Keyboard-selected card must be entirely inside scroll viewport: %d card=%s view=%s scroll=%s range=%s" % [controller.selected_group_index, rect, view, overlay.cards_scroll.scroll_horizontal, overlay.cards_scroll.get_h_scroll_bar().max_value])

func run() -> void:
	root.size = Vector2i(1920, 1080)
	var main: Node = load("res://Scenes/Main/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	await settle()
	var flow: Node = main.get_node("LevelFlowController")
	flow.progression_state.day_index = 1
	flow.progression_state.modifiers.ensure_offers(1)
	flow.progression_state.modifiers.choose_global(0, 1)
	flow._enter_order_group_select()
	await settle()
	var overlay: Node = flow.overlay_controller
	var controller: Node = flow.order_group_select_controller
	# Daily gameplay now has three difficulty cards. Keep exercising the shared
	# renderer with a deliberately larger authored list to guard overflow.
	controller.set_order_groups(preload("res://Scripts/Orders/OrderGroupDefs.gd").create_default_order_groups(1))
	controller.prepare_for_open()
	await settle()
	check(controller.order_groups.size() == 5, "Overflow fixture contains five cards")
	check(overlay.cards_scroll.visible and overlay.cards_scroll.get_h_scroll_bar().visible, "Overflowing card row exposes a horizontal scrollbar")
	for index in range(5):
		controller.move_selection(1)
		await settle()
		check(controller.get_active_group_index() == index, "Selection maps to the correct plan")
		check_visible(controller, overlay)
	check(overlay.cards_scroll.scroll_horizontal > 0, "Reaching later options scrolls the viewport")
	if OS.get_cmdline_user_args().has("--render-order-select"):
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://_artifact_work/order_group_last_option.png")
	controller.move_selection(1)
	await settle()
	check(controller.get_active_group_index() == 0, "Last-to-first navigation wraps")
	check_visible(controller, overlay)
	controller.move_selection(-1)
	await settle()
	check(controller.get_active_group_index() == 4, "First-to-last navigation wraps")
	check_visible(controller, overlay)
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel.pressed = true
	wheel.position = overlay.blessing_card_panels[4].get_global_rect().get_center()
	wheel.global_position = wheel.position
	var old_scroll: int = overlay.cards_scroll.scroll_horizontal
	root.push_input(wheel)
	await settle()
	check(overlay.cards_scroll.scroll_horizontal < old_scroll, "Mouse wheel scrolls the overflowing plan list")
	# Growing beyond the original five panels retains original signal indices.
	var more: Array[Dictionary] = controller.order_groups.duplicate(true)
	for index in range(3):
		more.append(more[0].duplicate(true))
	overlay.ensure_card_count(more.size())
	controller.set_order_groups(more)
	controller.prepare_for_open()
	await settle()
	controller.move_selection(-1)
	await settle()
	check(controller.get_active_group_index() == 7, "Lists beyond the original panel count remain selectable")
	check_visible(controller, overlay)
	check(controller.handle_click(7) == 7, "Last card click maps to its actual group index")
	flow._open_menu_dish_overlay()
	await settle()
	check(overlay.cards_scroll.scroll_horizontal == 0, "Returning to menu resets shared card scrolling")
	flow._open_night_planning_overlay()
	await settle()
	check(overlay.cards_scroll.visible == overlay.blessing_cards_root.visible, "Shared scroll visibility follows cards in other overlays")
	paused = false
	main.queue_free()
	await process_frame
	print("ORDER GROUP SCROLLING: %d failures; last option, keyboard follow, wrap, mouse wheel, extra panels and menu reset" % failures.size())
	quit(0 if failures.is_empty() else 1)
