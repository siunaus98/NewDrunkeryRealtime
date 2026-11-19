extends Node

const SkillUpgradeDefs = preload("res://Scripts/Player/SkillUpgradeDefs.gd")

var overlay_title_label: Label
var overlay_body_label: Label
var overlay_hint_label: Label
var cards_root: HBoxContainer
var card_panels: Array[Panel] = []
var progression_state: Object
var kind: StringName = &""
var options: Array[Dictionary] = []
var selected_index: int = 0

func configure_ui(title_label: Label, body_label: Label, hint_label: Label, root: HBoxContainer, panels: Array[Panel]) -> void:
	overlay_title_label = title_label
	overlay_body_label = body_label
	overlay_hint_label = hint_label
	cards_root = root
	card_panels = panels

func set_progression_state(state: Object) -> void:
	progression_state = state

func clear_state() -> void:
	kind = &""
	options.clear()
	selected_index = 0

func enter_selection(upgrade_kind: StringName) -> void:
	if kind != upgrade_kind:
		options.clear()
		selected_index = 0
	kind = upgrade_kind
	var current_id: StringName = StringName(progression_state.get_skill_variant(kind)) if progression_state != null and progression_state.has_method("get_skill_variant") else &""
	if options.is_empty():
		options = SkillUpgradeDefs.draw_three(kind, StringName(current_id))
		selected_index = 0
	if overlay_title_label != null:
		overlay_title_label.text = "小技能升级" if kind == SkillUpgradeDefs.SMALL_KIND else "大技能升级"
	if overlay_body_label != null:
		var refreshes := int(progression_state.get_skill_refreshes()) if progression_state != null and progression_state.has_method("get_skill_refreshes") else 0
		overlay_body_label.text = "选择一项升级。刷新次数：%d" % refreshes
	if overlay_hint_label != null:
		overlay_hint_label.text = "鼠标：悬停/点击    左右切换：选择    Space：选定    L：刷新当前选项    K：暂时离开"
	refresh_cards()

func move_selection(direction: int) -> void:
	if options.is_empty():
		return
	selected_index = wrapi(selected_index + direction, 0, options.size())
	refresh_cards()

func handle_mouse_enter(index: int) -> void:
	if index >= 0 and index < options.size():
		selected_index = index
		refresh_cards()

func handle_click(index: int) -> Dictionary:
	if index < 0 or index >= options.size():
		return {}
	selected_index = index
	refresh_cards()
	return get_selected()

func get_selected() -> Dictionary:
	return options[selected_index] if selected_index >= 0 and selected_index < options.size() else {}

func confirm_selection() -> Dictionary:
	var result := get_selected()
	if result.is_empty():
		return {}
	result = result.duplicate(true)
	result["upgrade_kind"] = kind
	return result

func refresh_selected() -> bool:
	if options.is_empty() or progression_state == null or not progression_state.spend_skill_refresh():
		return false
	var excluded: Array[StringName] = []
	for option in options:
		excluded.append(StringName(option.get("id", &"")))
	var current_id: StringName = StringName(progression_state.get_skill_variant(kind))
	var replacement := SkillUpgradeDefs.draw_replacement(kind, current_id, excluded)
	if replacement.is_empty():
		progression_state.add_skill_refreshes(1)
		return false
	options[selected_index] = replacement
	refresh_cards()
	if overlay_body_label != null:
		overlay_body_label.text = "选择一项升级。刷新次数：%d" % int(progression_state.get_skill_refreshes())
	return true

func refresh_cards() -> void:
	if cards_root != null:
		cards_root.visible = true
		cards_root.add_theme_constant_override("separation", 28)
	for i in range(card_panels.size()):
		var panel := card_panels[i]
		for child in panel.get_children():
			child.queue_free()
		panel.visible = i < options.size()
		if i >= options.size():
			continue
		panel.custom_minimum_size = Vector2(480.0, 520.0)
		var style := StyleBoxFlat.new()
		style.bg_color = Color("465e57") if i == selected_index else Color("283b39f5")
		style.border_color = Color("f4d796") if i == selected_index else Color("b79f78")
		style.set_border_width_all(6)
		style.set_corner_radius_all(14)
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
		badge.text = "已选择" if i == selected_index else "选项 %d" % (i + 1)
		badge.add_theme_font_size_override("font_size", 20)
		content.add_child(badge)
		var title := Label.new()
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		title.add_theme_font_size_override("font_size", 36)
		title.text = String(options[i].get("name", ""))
		content.add_child(title)
		var description := Label.new()
		description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		description.add_theme_font_size_override("font_size", 24)
		description.text = "%s\n%s" % [String(options[i].get("detail", "")), String(options[i].get("note", ""))]
		content.add_child(description)
