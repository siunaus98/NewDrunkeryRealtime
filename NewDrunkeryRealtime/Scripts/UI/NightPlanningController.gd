extends Node

const TestItemDefs = preload("res://Scripts/Kitchen/TestItemDefs.gd")

enum PlanningAction {
	VIEW_MENU,
	START_DAY,
	VIEW_MODIFIERS
}

var overlay_title_label: Label
var overlay_body_label: Label
var overlay_hint_label: Label
var blessing_timer_label: Label
var blessing_timer_bar_frame: ColorRect
var blessing_cards_root: HBoxContainer
var blessing_card_panels: Array[Panel] = []

var current_menu_dish_ids: Array[StringName] = []
var selected_action_index: int = 0
var hovered_action_index: int = -1
var last_confirm_frame: int = -1

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

func prepare_for_open(new_menu_dish_ids: Array[StringName]) -> void:
	current_menu_dish_ids = new_menu_dish_ids.duplicate()
	if current_menu_dish_ids.is_empty():
		current_menu_dish_ids.append(TestItemDefs.DISH_RED_ID)
	selected_action_index = 0
	hovered_action_index = -1
	last_confirm_frame = -1

	if overlay_title_label != null:
		overlay_title_label.text = "夜间准备"
	if overlay_body_label != null:
		overlay_body_label.text = _build_body_text()
	if overlay_hint_label != null:
		overlay_hint_label.text = "左右键：选择    空格/J：打开    K：回到厨房"
	refresh_cards()

func move_selection(direction: int) -> void:
	selected_action_index = wrapi(selected_action_index + direction, 0, 3)
	hovered_action_index = -1
	refresh_cards()

func handle_mouse_enter(card_index: int) -> void:
	if card_index < 0 or card_index >= 3:
		return
	hovered_action_index = card_index
	refresh_cards()

func handle_mouse_exit(card_index: int) -> void:
	if hovered_action_index != card_index:
		return
	hovered_action_index = -1
	refresh_cards()

func handle_click(card_index: int) -> int:
	if card_index < 0 or card_index >= 3:
		return -1
	selected_action_index = card_index
	hovered_action_index = -1
	refresh_cards()
	return card_index

func mark_confirmed_this_frame() -> bool:
	var current_frame: int = Engine.get_process_frames()
	if last_confirm_frame == current_frame:
		return false
	last_confirm_frame = current_frame
	return true

func get_active_action() -> int:
	if hovered_action_index >= 0:
		return hovered_action_index
	return selected_action_index

func refresh_cards() -> void:
	if blessing_timer_label != null:
		blessing_timer_label.visible = false
	if blessing_timer_bar_frame != null:
		blessing_timer_bar_frame.visible = false
	if blessing_cards_root != null:
		blessing_cards_root.visible = true

	for i in range(blessing_card_panels.size()):
		var panel: Panel = blessing_card_panels[i]
		for child in panel.get_children():
			child.queue_free()
		panel.visible = i < 3
		panel.custom_minimum_size = Vector2(480, 540)
		_apply_card_style(panel, i == _get_active_card_index())
		if i >= 3:
			continue
		_build_action_card(panel, i)

func _build_action_card(panel: Panel, action_index: int) -> void:
	var content := VBoxContainer.new()
	content.set_anchors_preset(Control.PRESET_FULL_RECT)
	content.offset_left = 22.0
	content.offset_top = 24.0
	content.offset_right = -22.0
	content.offset_bottom = -24.0
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 16)
	panel.add_child(content)

	var title := Label.new()
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.add_theme_font_size_override("font_size", 33)
	title.text = ["查看菜单", "营业难度", "全局契约"][action_index]
	content.add_child(title)

	var description := Label.new()
	description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.add_theme_font_size_override("font_size", 22)
	description.modulate = Color(0.92, 0.94, 0.96, 0.94)
	description.text = ["查看完整菜谱，确认食材与料理台。", "选择当日收益与额外难题，BOSS 日难度固定。", "回顾本局已选择的全局强化，以及它们带来的代价。"][action_index]
	content.add_child(description)

	var detail := Label.new()
	detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.add_theme_font_size_override("font_size", 19)
	detail.modulate = Color(1.0, 0.92, 0.72, 0.96)
	detail.text = "当前菜单：\n%s" % "\n".join(_stringify_id_list(current_menu_dish_ids))
	if action_index == PlanningAction.VIEW_MODIFIERS:
		detail.text = "每夜选完菜单后签订一份契约。\n\n选择前可知强化，确认后揭示随机代价。"
	content.add_child(detail)

func _build_body_text() -> String:
	return "选完菜单与全局强化后，自由准备餐厅；在这里查看配方、回顾契约并选择当日难度。"

func _stringify_id_list(values: Variant) -> Array[String]:
	var result: Array[String] = []
	if values is Array:
		for value in values:
			result.append(TestItemDefs.get_item_display_name(StringName(value)))
	return result

func _get_active_card_index() -> int:
	if hovered_action_index >= 0:
		return hovered_action_index
	return selected_action_index

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
