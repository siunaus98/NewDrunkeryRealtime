extends Node

const TestItemDefs = preload("res://Scripts/Kitchen/TestItemDefs.gd")

var overlay_title_label: Label
var overlay_body_label: Label
var overlay_hint_label: Label
var blessing_timer_label: Label
var blessing_timer_bar_frame: ColorRect
var blessing_cards_root: HBoxContainer
var blessing_card_panels: Array[Panel] = []
var cards_scroll: ScrollContainer
var card_font_scale: float = 1.4

var order_groups: Array[Dictionary] = []
var current_menu_dish_ids: Array[StringName] = []
var selected_group_index: int = -1
var hovered_group_index: int = -1
var last_confirm_frame: int = -1

func configure_ui(
	new_overlay_title_label: Label,
	new_overlay_body_label: Label,
	new_overlay_hint_label: Label,
	new_blessing_timer_label: Label,
	new_blessing_timer_bar_frame: ColorRect,
	new_blessing_cards_root: HBoxContainer,
	new_blessing_card_panels: Array[Panel],
	new_cards_scroll: ScrollContainer = null
) -> void:
	overlay_title_label = new_overlay_title_label
	overlay_body_label = new_overlay_body_label
	overlay_hint_label = new_overlay_hint_label
	blessing_timer_label = new_blessing_timer_label
	blessing_timer_bar_frame = new_blessing_timer_bar_frame
	blessing_cards_root = new_blessing_cards_root
	blessing_card_panels = new_blessing_card_panels
	cards_scroll = new_cards_scroll

func set_order_groups(new_order_groups: Array[Dictionary]) -> void:
	order_groups = new_order_groups
	if selected_group_index >= order_groups.size():
		selected_group_index = -1
	if hovered_group_index >= order_groups.size():
		hovered_group_index = -1

func set_current_menu_dish_ids(new_menu_dish_ids: Array[StringName]) -> void:
	current_menu_dish_ids = new_menu_dish_ids.duplicate()
	if current_menu_dish_ids.is_empty():
		current_menu_dish_ids.append(TestItemDefs.DISH_RED_ID)

func prepare_for_open() -> void:
	selected_group_index = 0 if order_groups.size() == 1 else -1
	hovered_group_index = -1
	last_confirm_frame = -1
	if cards_scroll != null:
		cards_scroll.scroll_horizontal = 0
		cards_scroll.scroll_vertical = 0
	if overlay_title_label != null:
		overlay_title_label.text = "下一日营业难度"
	if overlay_body_label != null:
		overlay_body_label.text = "难度越高，额外收益越高。额外难题只作用于本日；BOSS 日难度固定。"
	if overlay_hint_label != null:
		overlay_hint_label.text = "左右切换（自动滚动），鼠标滚轮/底部滚动条查看全部方案，点击或 Space 开始营业；L 返回菜单，K 返回夜间。"
	refresh_cards()

func move_selection(direction: int) -> void:
	if order_groups.is_empty():
		return
	if selected_group_index < 0 or selected_group_index >= order_groups.size():
		selected_group_index = 0 if direction >= 0 else order_groups.size() - 1
	else:
		selected_group_index = wrapi(selected_group_index + direction, 0, order_groups.size())
	hovered_group_index = -1
	refresh_cards()
	call_deferred("_reveal_selected_card")

func _reveal_selected_card() -> void:
	# Refreshing a card rebuilds its contents; let container minimum sizes
	# settle before calculating the scroll range (also after wheel input).
	for frame in range(3):
		await get_tree().process_frame
		if cards_scroll == null or not cards_scroll.is_visible_in_tree() or selected_group_index < 0 or selected_group_index >= blessing_card_panels.size():
			return
		cards_scroll.ensure_control_visible(blessing_card_panels[selected_group_index])

func handle_mouse_enter(card_index: int) -> void:
	if card_index < 0 or card_index >= order_groups.size():
		return
	if hovered_group_index == card_index:
		return
	hovered_group_index = card_index
	refresh_cards()

func handle_mouse_exit(card_index: int) -> void:
	if hovered_group_index != card_index:
		return
	hovered_group_index = -1
	refresh_cards()

func handle_click(card_index: int) -> int:
	if card_index < 0 or card_index >= order_groups.size():
		return -1
	selected_group_index = card_index
	hovered_group_index = -1
	refresh_cards()
	return card_index

func mark_confirmed_this_frame() -> bool:
	var current_frame: int = Engine.get_process_frames()
	if last_confirm_frame == current_frame:
		return false
	last_confirm_frame = current_frame
	return true

func get_active_group_index() -> int:
	if hovered_group_index >= 0 and hovered_group_index < order_groups.size():
		return hovered_group_index
	if selected_group_index >= 0 and selected_group_index < order_groups.size():
		return selected_group_index
	return -1

func refresh_cards() -> void:
	if blessing_timer_label != null:
		blessing_timer_label.visible = false
	if blessing_timer_bar_frame != null:
		blessing_timer_bar_frame.visible = false
	if blessing_cards_root != null:
		blessing_cards_root.visible = true
		blessing_cards_root.add_theme_constant_override("separation", 28)

	var visible_card_count: int = mini(order_groups.size(), blessing_card_panels.size())
	var card_width: float = 480.0 if visible_card_count >= 3 else 680.0
	var card_height: float = 540.0 if visible_card_count >= 3 else 560.0

	for i in range(blessing_card_panels.size()):
		var panel: Panel = blessing_card_panels[i]
		for child in panel.get_children():
			child.queue_free()
		panel.visible = i < order_groups.size()
		panel.custom_minimum_size = Vector2(card_width, card_height)

		var card_data: Dictionary = order_groups[i] if i < order_groups.size() else {}
		var is_hovered: bool = i == hovered_group_index
		var is_selected: bool = i == selected_group_index and hovered_group_index < 0
		var is_highlighted: bool = is_hovered or is_selected
		_apply_card_style(panel, is_highlighted)

		var content := VBoxContainer.new()
		content.set_anchors_preset(Control.PRESET_FULL_RECT)
		content.offset_left = 18.0
		content.offset_top = 20.0
		content.offset_right = -18.0
		content.offset_bottom = -20.0
		content.alignment = BoxContainer.ALIGNMENT_CENTER
		content.add_theme_constant_override("separation", 12)
		panel.add_child(content)

		if card_data.is_empty():
			var empty_label := Label.new()
			empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			empty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			empty_label.add_theme_font_size_override("font_size", 24)
			empty_label.text = "无关卡"
			content.add_child(empty_label)
			continue

		var day_index: int = int(card_data.get("day_index", 0)) + 1
		var badge := Label.new()
		badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		badge.add_theme_font_size_override("font_size", roundi(18 * card_font_scale))
		badge.modulate = Color(1.0, 0.92, 0.72, 0.96)
		badge.text = String(card_data.get("badge_text", "第%d天" % day_index))
		content.add_child(badge)

		var title := Label.new()
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		title.add_theme_font_size_override("font_size", roundi(27 * card_font_scale))
		title.text = String(card_data.get("display_name", "未知关卡"))
		content.add_child(title)

		var description := Label.new()
		description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		description.add_theme_font_size_override("font_size", roundi(19 * card_font_scale))
		description.modulate = Color(0.9, 0.92, 0.94, 0.88)
		description.text = String(card_data.get("description", ""))
		content.add_child(description)

		var detail := Label.new()
		detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		detail.add_theme_font_size_override("font_size", roundi(18 * card_font_scale))
		detail.modulate = Color(0.96, 0.96, 0.9, 0.9)
		detail.text = String(card_data.get("detail_text", ""))
		detail.visible = not detail.text.is_empty()
		content.add_child(detail)

func _apply_card_style(panel: Panel, is_highlighted: bool) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("465e57") if is_highlighted else Color("283b39f5")
	style.border_color = Color("f4d796") if is_highlighted else Color("b79f78")
	style.border_width_left = 5
	style.border_width_top = 5
	style.border_width_right = 5
	style.border_width_bottom = 5
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.28)
	style.shadow_size = 8
	panel.add_theme_stylebox_override("panel", style)

func _get_wave_count(card_data: Dictionary) -> int:
	var waves: Variant = card_data.get("waves", [])
	return waves.size() if waves is Array else 0

func _get_total_order_count(card_data: Dictionary) -> int:
	var total_orders: int = 0
	var waves: Variant = card_data.get("waves", [])
	if waves is Array:
		for wave_data in waves:
			var wave_orders: Variant = wave_data.get("orders", [])
			if wave_orders is Array:
				total_orders += wave_orders.size()
	return total_orders

func _stringify_id_list(values: Variant) -> Array[String]:
	var result: Array[String] = []
	if values is Array:
		for value in values:
			result.append(_get_item_display_name(StringName(value)))
	return result

func _get_item_display_name(item_id: StringName) -> String:
	return TestItemDefs.get_item_display_name(item_id)

func _collect_menu_items_by_kind(meat_only: bool) -> Array[StringName]:
	var result: Array[StringName] = []
	for dish_id in current_menu_dish_ids:
		for entry in TestItemDefs.get_recipe_for_dish(dish_id):
			if not (entry is Dictionary):
				continue
			var item_id := StringName(entry.get("item_id", &""))
			if not TestItemDefs.is_ingredient(item_id):
				continue
			if _is_meat_item(item_id) != meat_only:
				continue
			if item_id not in result:
				result.append(item_id)
	return result

func _is_meat_item(item_id: StringName) -> bool:
	return item_id in [TestItemDefs.MEAT_RED_ID, TestItemDefs.MEAT_WHITE_ID, TestItemDefs.SHRIMP_ID]
