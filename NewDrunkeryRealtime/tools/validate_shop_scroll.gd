extends SceneTree

var failures: Array[String] = []
var main: Node
var shop: Node

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)

func settle_layout() -> void:
	for frame in range(3):
		await process_frame

func selection_visible() -> bool:
	var panel: Control = shop.shop_item_panel_by_index.get(shop.selected_shop_index)
	if not is_instance_valid(panel):
		return false
	var viewport: Rect2 = shop.shop_scroll.get_global_rect()
	var card: Rect2 = panel.get_global_rect()
	return card.position.y >= viewport.position.y - 1.0 and card.end.y <= viewport.end.y + 1.0

func _run() -> void:
	main = load("res://Scenes/Main/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	await process_frame
	var flow: Node = main.get_node("LevelFlowController")
	flow.set_process(false)
	flow.input_release_guard_active = false
	flow._open_night_shop_overlay()
	shop = flow.night_shop_controller
	shop.move_category_selection(2)
	await settle_layout()
	check(paused and shop.shop_scroll.is_visible_in_tree(), "Exercise actual paused shop UI")
	shop.move_selection_2d(1, 0)
	await settle_layout()
	var indices: Array[int] = shop._get_shop_item_indices_for_category(2)
	var first_panel: Control = shop.shop_item_panel_by_index[indices.front()]
	check(selection_visible(), "First selection is visible")
	# Walk each row through the real input route, rather than just checking
	# the selected index while every panel still has its default position.
	for row in range(int((indices.size() - 1) / 3)):
		shop.move_selection_2d(0, 1)
		await settle_layout()
		check(selection_visible(), "Down navigation scrolls selected row %d into view" % (row + 1))
	check(shop.shop_scroll.scroll_vertical > 0, "Page scrolls down beyond the viewport")
	check(shop.shop_item_panel_by_index[indices.front()] == first_panel, "Navigation keeps laid-out cards instead of rebuilding them")
	shop.move_selection_2d(0, 1)
	await settle_layout()
	check(shop.selected_shop_index == indices.front() and selection_visible() and shop.shop_scroll.scroll_vertical == 0, "Last row wraps to visible first item")
	shop.move_selection_2d(-1, 0)
	await settle_layout()
	check(shop.selected_shop_index == indices.back() and selection_visible(), "Left wrap scrolls to the last item")
	# Repeated commands before layout settles must follow only the final cursor.
	shop.move_selection_2d(1, 0)
	shop.move_selection_2d(0, -1)
	shop.move_selection_2d(1, 0)
	shop.move_selection_2d(-1, 0)
	await settle_layout()
	check(shop.selected_shop_index == indices.back() and selection_visible(), "Rapid navigation discards stale scroll requests")
	flow.progression_state.gold = 2000
	shop.set_facility_purchase_callback(func(_item: Dictionary) -> bool: return true)
	var last_id: StringName = shop.merchant_shop_items[shop.selected_shop_index].id
	check(shop.purchase_selected(), "Buy a repeatable facility on the last row")
	await settle_layout()
	check(shop.merchant_shop_items[shop.selected_shop_index].id == last_id and selection_visible(), "Purchase rebuild retains both cursor and visible card")
	var limited_index: int = -1
	for index: int in indices:
		if shop.merchant_shop_items[index].id == &"facility_healing_spring":
			limited_index = index
	check(limited_index >= 0, "Limited facility exists for removal case")
	if limited_index >= 0:
		shop.selected_shop_index = limited_index
		shop._refresh_night_shop_overlay()
		await settle_layout()
		var next_id: StringName = shop.merchant_shop_items[limited_index + 1].id
		check(shop.purchase_selected(), "Buy and remove a limited facility")
		await settle_layout()
		check(shop.merchant_shop_items[shop.selected_shop_index].id == next_id and selection_visible(), "Sold-out successor scrolls into view after reflow")
	shop.move_category_selection(1)
	shop.move_selection_2d(1, 0)
	await settle_layout()
	check(selection_visible(), "Category switch and first navigation show the new selection")
	main.queue_free()
	await process_frame
	print("SHOP SCROLL: %d failures; actual paused UI, row navigation, wrapping, rapid input and purchase reflow" % failures.size())
	quit(0 if failures.is_empty() else 1)
