extends Node

const TestItemDefs = preload("res://Scripts/Kitchen/TestItemDefs.gd")

var overlay_title_label: Label
var overlay_body_label: Label
var overlay_hint_label: Label
var blessing_timer_label: Label
var blessing_timer_bar_frame: ColorRect
var blessing_cards_root: HBoxContainer
var blessing_card_panels: Array[Panel] = []

var offer_dish_ids: Array[StringName] = []
var current_menu_dish_ids: Array[StringName] = []
var offer_selection_index: int = 0
var menu_selection_index: int = 0
var focused_column: int = 0
var pending_offer_index: int = -1
var menu_max_size: int = 4
var needs_replacement: bool = false
var is_mandatory_update: bool = false
var overlay_title_text: String = "夜间菜单"
var offer_header_text: String = "可加入的新菜"
var replacement_dish_ids: Array[StringName] = []
var menu_scroll_containers: Array[ScrollContainer] = []
var menu_row_controls: Array[Array] = [[], []]
var last_confirm_frame: int = -1
var refresh_generation: int = 0
var refreshes_remaining: int = 0
var event_exchange: bool = false
var event_target_name: String = ""

func set_refresh_status(remaining: int, is_event: bool, target_name: String = "") -> void:
	refreshes_remaining = remaining
	event_exchange = is_event
	event_target_name = target_name
	_update_labels()
	refresh_cards()

func configure_ui(
	new_overlay_title_label: Label,
	new_overlay_body_label: Label,
	new_overlay_hint_label: Label,
	new_blessing_timer_label: Label,
	new_blessing_timer_bar_frame: ColorRect,
	new_blessing_cards_root: HBoxContainer,
	new_blessing_card_panels: Array[Panel]
) -> void:
	overlay_title_label = new_overlay_title_label
	overlay_body_label = new_overlay_body_label
	overlay_hint_label = new_overlay_hint_label
	blessing_timer_label = new_blessing_timer_label
	blessing_timer_bar_frame = new_blessing_timer_bar_frame
	blessing_cards_root = new_blessing_cards_root
	blessing_card_panels = new_blessing_card_panels

func prepare_for_open(
	new_offer_dish_ids: Array[StringName],
	new_current_menu_dish_ids: Array[StringName],
	new_menu_max_size: int,
	new_replace_index: int,
	new_needs_replacement: bool = false,
	new_is_mandatory_update: bool = false,
	new_overlay_title_text: String = "夜间菜单",
	new_offer_header_text: String = "可加入的新菜"
) -> void:
	offer_dish_ids = new_offer_dish_ids.duplicate()
	current_menu_dish_ids = new_current_menu_dish_ids.duplicate()
	if current_menu_dish_ids.is_empty():
		current_menu_dish_ids.append(TestItemDefs.DISH_WHITE_PLATE_ID)
	menu_max_size = maxi(new_menu_max_size, 1)
	needs_replacement = new_needs_replacement
	is_mandatory_update = new_is_mandatory_update
	overlay_title_text = new_overlay_title_text
	offer_header_text = new_offer_header_text
	offer_selection_index = clampi(offer_selection_index, 0, maxi(offer_dish_ids.size() - 1, 0))
	menu_selection_index = clampi(new_replace_index, 0, maxi(current_menu_dish_ids.size() - 1, 0)) if new_replace_index >= 0 else clampi(menu_selection_index, 0, maxi(current_menu_dish_ids.size() - 1, 0))
	focused_column = 0 if not offer_dish_ids.is_empty() else 1
	pending_offer_index = -1
	replacement_dish_ids.clear()
	last_confirm_frame = -1
	_update_labels()
	refresh_cards()

func move_selection(direction: int) -> void:
	if direction == 0:
		return
	focused_column = wrapi(focused_column + direction, 0, 2)
	if focused_column == 0 and offer_dish_ids.is_empty():
		focused_column = 1
	refresh_cards()

func move_replace_selection(direction: int) -> void:
	var visible_ids: Array[StringName] = _get_focused_dish_ids()
	if visible_ids.is_empty():
		return
	if focused_column == 0:
		offer_selection_index = wrapi(offer_selection_index + direction, 0, visible_ids.size())
	else:
		var replace_indices := _get_allowed_replace_indices()
		if pending_offer_index >= 0 and not replace_indices.is_empty():
			var current_position := replace_indices.find(menu_selection_index)
			current_position = wrapi(current_position + direction, 0, replace_indices.size()) if current_position >= 0 else 0
			menu_selection_index = int(replace_indices[current_position])
		else:
			menu_selection_index = wrapi(menu_selection_index + direction, 0, visible_ids.size())
	refresh_cards()

func handle_mouse_enter(card_index: int) -> void:
	if card_index < 0 or card_index > 1:
		return
	focused_column = card_index
	if focused_column == 0 and offer_dish_ids.is_empty():
		focused_column = 1
	refresh_cards()

func handle_click(card_index: int) -> int:
	handle_mouse_enter(card_index)
	return card_index if card_index >= 0 and card_index <= 1 else -1

func mark_confirmed_this_frame() -> bool:
	var current_frame: int = Engine.get_process_frames()
	if last_confirm_frame == current_frame:
		return false
	last_confirm_frame = current_frame
	return true

func has_pending_selection() -> bool:
	return pending_offer_index >= 0

func cancel_pending_selection() -> void:
	pending_offer_index = -1
	focused_column = 0 if not offer_dish_ids.is_empty() else 1
	_update_labels()
	refresh_cards()

func handle_primary_action() -> Dictionary:
	if focused_column == 0:
		if offer_dish_ids.is_empty():
			return {}
		pending_offer_index = offer_selection_index
		if not needs_replacement:
			return {
				"commit": true,
				"offer_index": pending_offer_index,
				"replace_index": -1
			}
		_refresh_replacement_ids_for_pending_offer()
		if replacement_dish_ids.is_empty():
			pending_offer_index = -1
			return {}
		focused_column = 1
		menu_selection_index = current_menu_dish_ids.find(replacement_dish_ids[0])
		_update_labels()
		refresh_cards()
		return {"pending": true}

	if pending_offer_index < 0 or current_menu_dish_ids.is_empty():
		return {}
	if current_menu_dish_ids[menu_selection_index] not in replacement_dish_ids:
		return {}

	return {
		"commit": true,
		"offer_index": pending_offer_index,
		"replace_index": menu_selection_index
	}

func refresh_cards() -> void:
	refresh_generation += 1
	if blessing_timer_label != null:
		blessing_timer_label.visible = false
	if blessing_timer_bar_frame != null:
		blessing_timer_bar_frame.visible = false
	if blessing_cards_root != null:
		blessing_cards_root.visible = true
		blessing_cards_root.size_flags_vertical = Control.SIZE_EXPAND_FILL
		blessing_cards_root.add_theme_constant_override("separation", 24)
		var outer := blessing_cards_root.get_parent() as ScrollContainer
		if outer != null:
			outer.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED

	menu_scroll_containers.clear()
	menu_row_controls = [[], []]
	for i in range(blessing_card_panels.size()):
		var panel: Panel = blessing_card_panels[i]
		for child in panel.get_children():
			child.free()
		panel.visible = i < 2
		if i >= 2:
			continue
		panel.custom_minimum_size = Vector2(760.0, 0.0)
		panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_apply_card_style(panel, i == focused_column)
		_build_column(panel, i)
	call_deferred("_deferred_ensure_focused_row_visible", refresh_generation)

func _build_column(panel: Panel, column_index: int) -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 22)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_right", 22)
	margin.add_theme_constant_override("margin_bottom", 18)
	panel.add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	margin.add_child(column)

	var header := Label.new()
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_theme_font_size_override("font_size", 30)
	header.modulate = Color(1.0, 0.92, 0.72, 0.98)
	header.text = offer_header_text if column_index == 0 else "当前菜单"
	column.add_child(header)

	var subheader := Label.new()
	subheader.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subheader.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subheader.add_theme_font_size_override("font_size", 18)
	subheader.modulate = Color(0.78, 0.83, 0.88, 0.92)
	subheader.text = (
		"按 J 选择。本次确认后不可撤销。"
		if column_index == 0
		else ("只可替换同类菜品，按 J 确认目标。" if pending_offer_index >= 0 else "每道菜都显示完整制作方法。")
	)
	column.add_child(subheader)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	column.add_child(scroll)
	menu_scroll_containers.append(scroll)

	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 10)
	scroll.add_child(list)

	var dish_ids: Array[StringName] = offer_dish_ids if column_index == 0 else current_menu_dish_ids
	if dish_ids.is_empty():
		var empty_label := Label.new()
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		empty_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty_label.add_theme_font_size_override("font_size", 23)
		empty_label.modulate = Color(0.76, 0.8, 0.84, 0.9)
		empty_label.text = "目前没有待加入的菜品。\n完成营业后会在这里出现新的菜单选择。" if column_index == 0 else "菜单为空。"
		list.add_child(empty_label)
		return

	for i in range(dish_ids.size()):
		var dish_id: StringName = dish_ids[i]
		var is_selected: bool = (
			(column_index == 0 and i == offer_selection_index)
			or (column_index == 1 and i == menu_selection_index)
		)
		var row_title := ""
		if column_index == 1 and i == menu_selection_index and pending_offer_index >= 0:
			row_title = "替换目标"
		elif event_exchange and column_index == 1 and TestItemDefs.get_item_display_name(dish_id) == event_target_name:
			row_title = "将被替换"
		var is_disabled := column_index == 1 and pending_offer_index >= 0 and dish_id not in replacement_dish_ids
		_build_dish_row(list, dish_id, is_selected, row_title, is_disabled)
		menu_row_controls[column_index].append(list.get_child(list.get_child_count() - 1))

func _deferred_ensure_focused_row_visible(generation: int) -> void:
	# Wrapped recipe labels update minimum heights over multiple layout passes.
	for frame in range(4):
		await get_tree().process_frame
		if generation != refresh_generation:
			return
	_ensure_focused_row_visible()

func _ensure_focused_row_visible() -> void:
	if menu_scroll_containers.size() < 2:
		return
	var column_index := focused_column
	var selected_index := offer_selection_index if column_index == 0 else menu_selection_index
	var scroll := menu_scroll_containers[column_index]
	if scroll == null or selected_index < 0 or selected_index >= menu_row_controls[column_index].size():
		return
	var row := menu_row_controls[column_index][selected_index] as Control
	if row == null:
		return
	scroll.ensure_control_visible(row)
	var row_top := row.position.y
	var row_bottom := row_top + row.size.y
	var visible_top := float(scroll.scroll_vertical)
	var visible_bottom := visible_top + scroll.size.y
	if row_top < visible_top:
		scroll.scroll_vertical = maxi(int(row_top - 12.0), 0)
	elif row_bottom > visible_bottom:
		scroll.scroll_vertical = maxi(int(row_bottom - scroll.size.y + 12.0), 0)

func _build_dish_row(parent: VBoxContainer, dish_id: StringName, is_selected: bool, row_title: String, is_disabled: bool = false) -> void:
	var row := PanelContainer.new()
	row.custom_minimum_size = Vector2(0.0, 166.0)
	_apply_row_style(row, is_selected, is_disabled)
	parent.add_child(row)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 10)
	row.add_child(margin)

	var content := HBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	margin.add_child(content)

	var cursor := Label.new()
	cursor.custom_minimum_size = Vector2(22.0, 0.0)
	cursor.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cursor.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cursor.add_theme_font_size_override("font_size", 28)
	cursor.modulate = Color(1.0, 0.82, 0.26, 1.0)
	cursor.text = ">" if is_selected else " "
	content.add_child(cursor)

	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(82.0, 82.0)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture = TestItemDefs.get_item_texture(dish_id)
	content.add_child(icon)

	var text_column := VBoxContainer.new()
	text_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_column.add_theme_constant_override("separation", 3)
	content.add_child(text_column)

	var title := Label.new()
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.add_theme_font_size_override("font_size", 27)
	title.text = ("%s：%s" % [row_title, TestItemDefs.get_item_display_name(dish_id)]) if not row_title.is_empty() else TestItemDefs.get_item_display_name(dish_id)
	if is_disabled:
		title.modulate = Color(0.7, 0.72, 0.75, 0.7)
	text_column.add_child(title)

	var meta := Label.new()
	meta.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	meta.add_theme_font_size_override("font_size", 18)
	meta.modulate = Color(1.0, 0.92, 0.72, 0.96)
	if is_disabled:
		meta.modulate = Color(0.7, 0.72, 0.75, 0.65)
	meta.text = "难度 %d  /  奖励 %d 金币  /  %d 经验\n%s\n%s" % [
		TestItemDefs.get_dish_difficulty(dish_id),
		TestItemDefs.get_dish_gold_reward(dish_id),
		TestItemDefs.get_dish_xp_reward(dish_id),
		TestItemDefs.get_dish_preparation_text(dish_id),
		preload("res://Scripts/Core/IngredientSourceDefs.gd").get_dish_source_text(dish_id)
	]
	text_column.add_child(meta)

	var recipe := Label.new()
	recipe.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	recipe.add_theme_font_size_override("font_size", 19)
	recipe.modulate = Color(0.9, 0.93, 0.96, 0.94)
	if is_disabled:
		recipe.modulate = Color(0.7, 0.72, 0.75, 0.65)
	recipe.text = "制作：%s" % _build_recipe_text(dish_id)
	text_column.add_child(recipe)

func _build_body_text() -> String:
	var menu_names: Array[String] = []
	for dish_id in current_menu_dish_ids:
		menu_names.append(TestItemDefs.get_item_display_name(dish_id))
	var menu_line := "、".join(menu_names)
	if offer_dish_ids.is_empty():
		return "夜间可以在这里查看当前菜单的完整菜谱。菜单更新后，未被使用的食材箱会重新变回石头箱。"
	if needs_replacement:
		return "当前菜单：%s\n非酒水菜单槽位已满。先在左侧按 J 选择新菜，再在右侧选择同类旧菜并按 J 确认替换。" % menu_line
	return "当前菜单：%s\n左侧按 J 选择一项加入菜单。本次确认后不可撤销。" % menu_line

func _build_recipe_text(dish_id: StringName) -> String:
	var parts: Array[String] = []
	for entry in TestItemDefs.get_display_recipe_for_dish(dish_id):
		if not (entry is Dictionary):
			continue
		if StringName(entry.get("source", &"")) == &"barrel":
			parts.append("%s → 酒桶酿造" % TestItemDefs.get_item_display_name(StringName(entry.get("item_id", &""))))
			continue
		var item_id := StringName(entry.get("item_id", &""))
		var count := int(entry.get("count", 1))
		var count_text := " x%d" % count if count > 1 else ""
		parts.append("%s %s%s" % [
			TestItemDefs.get_item_display_name(item_id),
			_get_recipe_process_text(entry),
			count_text
		])
	return "；".join(parts)

func _get_recipe_process_text(recipe_entry: Dictionary) -> String:
	return TestItemDefs.get_recipe_entry_process_text(recipe_entry)

func _get_focused_dish_ids() -> Array[StringName]:
	return offer_dish_ids if focused_column == 0 else current_menu_dish_ids

func _update_labels() -> void:
	if overlay_title_label != null:
		overlay_title_label.text = overlay_title_text
	if overlay_body_label != null:
		overlay_body_label.text = _build_body_text()
		if event_exchange:
			overlay_body_label.text = "已支付换菜费用。选择一种新做法替换“%s”；不消耗菜单槽位。本次不可刷新。" % event_target_name
	if overlay_hint_label != null:
		if offer_dish_ids.is_empty():
			overlay_hint_label.text = "W/S：浏览菜品    A/D：切换栏位    K：退出    L：营业难度"
		elif is_mandatory_update:
			overlay_hint_label.text = "W/S：浏览菜品    A/D：切换栏位    J：加入或确认替换    K：取消当前选择"
		else:
			overlay_hint_label.text = "W/S：浏览菜品    A/D：切换栏位    J：加入或确认替换    K：取消选择/退出    L：营业难度"
		if not offer_dish_ids.is_empty() and not event_exchange:
			overlay_hint_label.text += "    R：刷新（全局剩余 %d 次）" % refreshes_remaining

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

func _apply_row_style(panel: PanelContainer, is_highlighted: bool, is_disabled: bool = false) -> void:
	var style := StyleBoxFlat.new()
	if is_disabled:
		style.bg_color = Color(0.08, 0.09, 0.11, 0.58)
		style.border_color = Color(0.28, 0.31, 0.35, 0.58)
	else:
		style.bg_color = Color(0.28, 0.36, 0.44, 0.98) if is_highlighted else Color(0.1, 0.12, 0.16, 0.72)
		style.border_color = Color(0.68, 0.86, 1.0, 1.0) if is_highlighted else Color(0.4, 0.46, 0.52, 0.72)
	style.border_width_left = 3
	style.border_width_top = 3
	style.border_width_right = 3
	style.border_width_bottom = 3
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	panel.add_theme_stylebox_override("panel", style)

func _refresh_replacement_ids_for_pending_offer() -> void:
	replacement_dish_ids.clear()
	if pending_offer_index < 0 or pending_offer_index >= offer_dish_ids.size():
		return
	var offer_category := TestItemDefs.get_item_category(offer_dish_ids[pending_offer_index])
	for dish_id in current_menu_dish_ids:
		if TestItemDefs.is_drink(dish_id):
			continue
		if TestItemDefs.get_item_category(dish_id) == offer_category:
			replacement_dish_ids.append(dish_id)

func _get_allowed_replace_indices() -> Array[int]:
	var result: Array[int] = []
	if pending_offer_index < 0:
		return result
	for dish_id in replacement_dish_ids:
		var index := current_menu_dish_ids.find(dish_id)
		if index >= 0:
			result.append(index)
	return result
