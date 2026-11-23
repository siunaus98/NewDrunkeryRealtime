extends Node

const BlessingDefs = preload("res://Scripts/Progression/BlessingDefs.gd")

var overlay_title_label: Label
var overlay_body_label: Label
var overlay_hint_label: Label
var blessing_timer_label: Label
var blessing_timer_bar_frame: ColorRect
var blessing_timer_bar_fill: ColorRect
var blessing_cards_root: HBoxContainer
var blessing_card_panels: Array[Panel] = []
var progression_state: Object

const OPTION_COUNT: int = 3

var blessing_select_duration: float = 30.0
var blessing_select_time_remaining: float = 0.0
var blessing_options: Array[Dictionary] = []
var selected_blessing_index: int = 0

func configure_ui(
	new_overlay_title_label: Label,
	new_overlay_body_label: Label,
	new_overlay_hint_label: Label,
	new_blessing_timer_label: Label,
	new_blessing_timer_bar_frame: ColorRect,
	new_blessing_timer_bar_fill: ColorRect,
	new_blessing_cards_root: HBoxContainer,
	new_blessing_card_panels: Array[Panel]
) -> void:
	overlay_title_label = new_overlay_title_label
	overlay_body_label = new_overlay_body_label
	overlay_hint_label = new_overlay_hint_label
	blessing_timer_label = new_blessing_timer_label
	blessing_timer_bar_frame = new_blessing_timer_bar_frame
	blessing_timer_bar_fill = new_blessing_timer_bar_fill
	blessing_cards_root = new_blessing_cards_root
	blessing_card_panels = new_blessing_card_panels

func set_duration(duration_seconds: float) -> void:
	blessing_select_duration = maxf(duration_seconds, 0.001)

func set_progression_state(state: Object) -> void:
	progression_state = state

func clear_state() -> void:
	blessing_select_time_remaining = 0.0
	blessing_options.clear()
	selected_blessing_index = 0

func enter_selection() -> void:
	blessing_select_time_remaining = 0.0
	if blessing_options.is_empty():
		blessing_options = _build_available_blessing_options()
		selected_blessing_index = 0
	if overlay_title_label != null:
		overlay_title_label.text = "女神的祝福"
	if overlay_body_label != null:
		var points: int = int(progression_state.get_blessing_points()) if progression_state != null and progression_state.has_method("get_blessing_points") else 0
		var refreshes: int = int(progression_state.get_blessing_refreshes()) if progression_state != null and progression_state.has_method("get_blessing_refreshes") else 0
		overlay_body_label.text = "消耗 1 点祝福点数，选择一项祝福。当前祝福点数：%d\n整局共享刷新次数：%d" % [points, refreshes]
	if overlay_hint_label != null:
		overlay_hint_label.text = "鼠标：悬停/点击    左右切换：选择    Space：选定    L：刷新当前选项（整局共用次数）    K：暂时离开"
	if blessing_timer_label != null:
		blessing_timer_label.visible = false
	if blessing_timer_bar_frame != null:
		blessing_timer_bar_frame.visible = false
	refresh_cards()

func move_selection(direction: int) -> void:
	if blessing_options.is_empty():
		return
	selected_blessing_index = wrapi(selected_blessing_index + direction, 0, blessing_options.size())
	refresh_cards()

func handle_mouse_enter(card_index: int) -> void:
	if card_index < 0 or card_index >= blessing_options.size():
		return
	if selected_blessing_index == card_index:
		return
	selected_blessing_index = card_index
	refresh_cards()

func handle_click(card_index: int) -> Dictionary:
	if card_index < 0 or card_index >= blessing_options.size():
		return {}
	selected_blessing_index = card_index
	refresh_cards()
	return get_selected_blessing()

func get_selected_blessing() -> Dictionary:
	if blessing_options.is_empty():
		return {}
	return blessing_options[selected_blessing_index]

func confirm_selection() -> Dictionary:
	var blessing_data: Dictionary = get_selected_blessing()
	if blessing_data.is_empty():
		return {}
	blessing_options.clear()
	blessing_select_time_remaining = 0.0
	return blessing_data

func refresh_selected() -> bool:
	if blessing_options.is_empty() or progression_state == null:
		return false
	if not progression_state.has_method("spend_blessing_refresh") or not progression_state.spend_blessing_refresh():
		return false
	var candidates: Array[Dictionary] = _build_available_blessing_options(blessing_options)
	if candidates.is_empty():
		# Do not consume a refresh if there is no legal replacement.
		progression_state.add_blessing_refreshes(1)
		if overlay_body_label != null:
			overlay_body_label.text = "祝福池中已经没有未出现过的可替换祝福。\n整局共享刷新次数：%d" % int(progression_state.get_blessing_refreshes())
		return false
	var replacement: Dictionary = candidates[0]
	var old_id := StringName(blessing_options[selected_blessing_index].get("id", &""))
	if progression_state.has_method("mark_blessing_seen"):
		progression_state.mark_blessing_seen(old_id)
	blessing_options[selected_blessing_index] = replacement
	if progression_state.has_method("mark_blessing_seen"):
		progression_state.mark_blessing_seen(StringName(replacement.get("id", &"")))
	refresh_cards()
	if overlay_body_label != null:
		var points: int = int(progression_state.get_blessing_points())
		var refreshes: int = int(progression_state.get_blessing_refreshes())
		overlay_body_label.text = "消耗 1 点祝福点数，选择一项祝福。当前祝福点数：%d\n整局共享刷新次数：%d" % [points, refreshes]
	return true

func refresh_cards() -> void:
	if blessing_timer_label != null:
		blessing_timer_label.visible = false
	if blessing_cards_root != null:
		blessing_cards_root.visible = true
		blessing_cards_root.add_theme_constant_override("separation", 28)

	var visible_card_count: int = mini(blessing_options.size(), blessing_card_panels.size())
	var card_width: float = 480.0 if visible_card_count >= 3 else 680.0

	for i in range(blessing_card_panels.size()):
		var panel: Panel = blessing_card_panels[i]
		for child in panel.get_children():
			child.queue_free()
		panel.visible = i < blessing_options.size()
		panel.custom_minimum_size = Vector2(card_width, 520.0)
		if i >= blessing_options.size():
			continue

		var card_data: Dictionary = blessing_options[i] if i < blessing_options.size() else {}
		var style := StyleBoxFlat.new()
		style.bg_color = Color("465e57") if i == selected_blessing_index else Color("283b39f5")
		style.border_color = Color("f4d796") if i == selected_blessing_index else Color("b79f78")
		style.border_width_left = 6
		style.border_width_top = 6
		style.border_width_right = 6
		style.border_width_bottom = 6
		style.corner_radius_top_left = 14
		style.corner_radius_top_right = 14
		style.corner_radius_bottom_left = 14
		style.corner_radius_bottom_right = 14
		style.shadow_color = Color(0.0, 0.0, 0.0, 0.28)
		style.shadow_size = 10
		panel.add_theme_stylebox_override("panel", style)

		var content := VBoxContainer.new()
		content.set_anchors_preset(Control.PRESET_FULL_RECT)
		content.offset_left = 26.0
		content.offset_top = 26.0
		content.offset_right = -26.0
		content.offset_bottom = -26.0
		content.alignment = BoxContainer.ALIGNMENT_CENTER
		content.add_theme_constant_override("separation", 20)
		panel.add_child(content)

		var badge := Label.new()
		badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		badge.add_theme_font_size_override("font_size", 20)
		badge.modulate = Color(1.0, 0.92, 0.72, 0.96)
		badge.text = "已选择" if i == selected_blessing_index else "选项 %d" % (i + 1)
		content.add_child(badge)

		var title := Label.new()
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		title.add_theme_font_size_override("font_size", 34)
		title.text = String(card_data.get("title", ""))
		content.add_child(title)

		var description := Label.new()
		description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		description.add_theme_font_size_override("font_size", 24)
		description.modulate = Color(0.9, 0.92, 0.94, 0.88)
		description.text = String(card_data.get("description", ""))
		content.add_child(description)

func update_timer() -> void:
	if blessing_timer_label == null:
		return
	var displayed_seconds: int = maxi(int(ceili(blessing_select_time_remaining)), 0)
	blessing_timer_label.text = "选择祝福  |  %d 秒" % displayed_seconds
	if blessing_timer_bar_frame != null and blessing_timer_bar_fill != null:
		var progress_ratio: float = clampf(blessing_select_time_remaining / maxf(blessing_select_duration, 0.001), 0.0, 1.0)
		blessing_timer_bar_fill.anchor_right = progress_ratio
		if progress_ratio > 0.5:
			blessing_timer_bar_fill.color = Color(1.0, 0.86, 0.32, 1.0)
		elif progress_ratio > 0.25:
			blessing_timer_bar_fill.color = Color(1.0, 0.66, 0.24, 1.0)
		else:
			blessing_timer_bar_fill.color = Color(0.96, 0.32, 0.24, 1.0)

func _build_available_blessing_options(excluded_options: Array[Dictionary] = []) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var excluded_ids: Dictionary = {}
	for excluded in excluded_options:
		excluded_ids[StringName(excluded.get("id", &""))] = true
	for blessing_data in BlessingDefs.create_default_blessings():
		if StringName(blessing_data.get("type", &"general")) == &"chi_baobao" and not _is_chi_baobao_selected():
			continue
		var blessing_id := StringName(blessing_data.get("id", &""))
		if excluded_ids.has(blessing_id):
			continue
		if progression_state != null and progression_state.has_method("has_seen_blessing") and bool(progression_state.has_seen_blessing(blessing_id)):
			continue
		result.append(blessing_data)
	result.shuffle()
	var options: Array[Dictionary] = []
	for blessing_data in result:
		if options.size() >= (OPTION_COUNT if excluded_options.is_empty() else 1):
			break
		options.append(blessing_data)
		if progression_state != null and progression_state.has_method("mark_blessing_seen"):
			progression_state.mark_blessing_seen(StringName(blessing_data.get("id", &"")))
	return options

func _is_chi_baobao_selected() -> bool:
	if not is_inside_tree():
		# Pure logic tests may invoke the selector before it enters a SceneTree.
		return true
	var tree := get_tree()
	var player := tree.get_first_node_in_group("player")
	if player == null:
		# Isolated selector tests do not instantiate a player; keep the full pool available there.
		return true
	return StringName(player.get_meta("selected_character_id", &"chi_baobao")) == &"chi_baobao"
