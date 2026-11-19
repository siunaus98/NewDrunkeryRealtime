extends Control

const AudioCue = preload("res://Scripts/Audio/AudioCue.gd")

const MAIN_SCENE_PATH := "res://Scenes/Main/main.tscn"
const PLAYER_AVATAR := preload("res://ArtResource/Player/CBB_QQ_172x271.png")
const CodexController = preload("res://Scripts/UI/CodexController.gd")
const SmallSkillDefs = preload("res://Scripts/Player/SmallSkillDefs.gd")
const BigSkillDefs = preload("res://Scripts/Player/BigSkillDefs.gd")
const CHINESE_FONT_NAMES := [
	"PingFang SC",
	"Hiragino Sans GB",
	"Heiti SC",
	"Songti SC",
	"Arial Unicode MS"
]

const CHARACTER_OPTIONS := {
	&"chi_baobao": {
		"name": "池饱饱",
		"role": "",
		"intro": "总能把翻车做成能上桌的一盘。",
		"story": [
			"她第一次踏进酒馆时，先学会的不是切菜，而是怎么在锅铲、客人和敌人同时喊人的时候，把盘子端稳。",
			"池饱饱的自我评价很朴素：不一定每局都漂亮，但至少要把每次翻车都修成能上桌的东西。",
			"她不太信命运会自动帮忙，更信另一件事：只要还在厨房里站着，就总还有一次翻回来的机会。"
		],
		"stats": [
			"生命：6",
			"移动速度：420",
			"攻击伤害：10",
			"冲刺冷却：0.9 秒"
		]
	}
}

const BIG_SKILL_OPTIONS := [
	{"id": BigSkillDefs.BASE, "name": "稳住这锅", "summary": "原版测试"},
	{"id": BigSkillDefs.EXTEND, "name": "忙中有序", "summary": "完成工作与上菜可以续时"},
	{"id": BigSkillDefs.FOCUS, "name": "专心掌勺", "summary": "持续时间更长并免疫控制"},
	{"id": BigSkillDefs.AURA, "name": "灶火共鸣", "summary": "范围内设施获得效率增益"},
	{"id": BigSkillDefs.INSTANT, "name": "连环快手", "summary": "数次手动工作瞬间完成"},
	{"id": BigSkillDefs.SIGNATURE, "name": "名灶点化", "summary": "长期强化一台料理设施"},
	{"id": BigSkillDefs.RECOVERY, "name": "回春开席", "summary": "完成工作回复生命与魔力"}
]

enum ScreenMode {
	TITLE,
	PREPARE
}

enum PrepareFocusSection {
	CHARACTER,
	ACTION
}

var current_mode: ScreenMode = ScreenMode.TITLE
var selected_character_id: StringName = &"chi_baobao"
var selected_small_skill_id: StringName = &"rush_order"
var selected_big_skill_id: StringName = BigSkillDefs.BASE
var small_skill_selector: OptionButton
var small_skill_detail: RichTextLabel
var big_skill_selector: OptionButton
var big_skill_detail: RichTextLabel

var title_root: Control
var prepare_root: Control
var selected_summary_label: Label
var character_name_label: Label
var character_intro_label: Label
var stats_body_label: Label
var character_avatar_button: Button
var title_menu_buttons: Array[Button] = []
var prepare_action_buttons: Array[Button] = []
var prepare_start_button: Button
var codex_controller: CodexController
var selected_title_menu_index: int = 0
var prepare_focus_section: PrepareFocusSection = PrepareFocusSection.CHARACTER
var prepare_focus_index: int = 0
var is_character_confirmed: bool = false
var detail_focus_kind: StringName = &"small_skill"
var detail_focus_id: StringName = &"rush_order"
var chinese_ui_font: Font

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	AudioCue.play_music(&"title")
	_apply_chinese_ui_font()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_background()
	_build_title_screen()
	_build_prepare_screen()
	_build_codex()
	_show_title()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_echo():
		return
	if _is_modifier_only_key_event(event):
		return
	if current_mode == ScreenMode.TITLE and _is_ui_confirm_pressed(event):
		AudioCue.play_ui()
		_activate_selected_title_menu_item()
		_mark_input_as_handled()
		return
	if current_mode == ScreenMode.TITLE:
		if _is_down_pressed(event):
			_move_title_menu_selection(1)
			AudioCue.play_ui(&"ui_move")
			_mark_input_as_handled()
			return
		if _is_up_pressed(event):
			_move_title_menu_selection(-1)
			AudioCue.play_ui(&"ui_move")
			_mark_input_as_handled()
			return
	if current_mode == ScreenMode.PREPARE:
		if _is_ui_confirm_pressed(event):
			_mark_input_as_handled()
			AudioCue.play_ui()
			_activate_prepare_focus()
			return
		if _is_ui_cancel_pressed(event):
			_show_title()
			AudioCue.play_ui(&"ui_cancel")
			_mark_input_as_handled()
			return
		if _is_right_pressed(event):
			AudioCue.play_ui(&"ui_move")
			_move_prepare_focus_horizontal(1)
			_mark_input_as_handled()
			return
		if _is_left_pressed(event):
			AudioCue.play_ui(&"ui_move")
			_move_prepare_focus_horizontal(-1)
			_mark_input_as_handled()
			return
		if _is_down_pressed(event):
			AudioCue.play_ui(&"ui_move")
			_move_prepare_focus_vertical(1)
			_mark_input_as_handled()
			return
		if _is_up_pressed(event):
			AudioCue.play_ui(&"ui_move")
			_move_prepare_focus_vertical(-1)
			_mark_input_as_handled()
			return

func _is_modifier_only_key_event(event: InputEvent) -> bool:
	var key_event := event as InputEventKey
	if key_event == null or not key_event.pressed:
		return false
	return key_event.keycode in [
		Key.KEY_ALT,
		Key.KEY_SHIFT,
		Key.KEY_CTRL,
		Key.KEY_META
	] or key_event.physical_keycode in [
		Key.KEY_ALT,
		Key.KEY_SHIFT,
		Key.KEY_CTRL,
		Key.KEY_META
	]

func _apply_chinese_ui_font() -> void:
	var font := SystemFont.new()
	font.font_names = PackedStringArray(CHINESE_FONT_NAMES)
	chinese_ui_font = font
	add_theme_font_override("font", chinese_ui_font)

func _mark_input_as_handled() -> void:
	var viewport := get_viewport()
	if viewport != null:
		viewport.set_input_as_handled()

func _is_up_pressed(event: InputEvent) -> bool:
	return event.is_action_pressed("move_up") or event.is_action_pressed("ui_up")

func _is_down_pressed(event: InputEvent) -> bool:
	return event.is_action_pressed("move_down") or event.is_action_pressed("ui_down")

func _is_left_pressed(event: InputEvent) -> bool:
	return event.is_action_pressed("move_left") or event.is_action_pressed("ui_left") or event.is_action_pressed("ui_navigate_left")

func _is_right_pressed(event: InputEvent) -> bool:
	return event.is_action_pressed("move_right") or event.is_action_pressed("ui_right") or event.is_action_pressed("ui_navigate_right")

func _is_ui_confirm_pressed(event: InputEvent) -> bool:
	return event.is_action_pressed("ui_confirm")

func _is_ui_cancel_pressed(event: InputEvent) -> bool:
	return event.is_action_pressed("ui_cancel") or _is_key_pressed(event, Key.KEY_K)

func _is_key_pressed(event: InputEvent, keycode: Key) -> bool:
	var key_event := event as InputEventKey
	if key_event == null or not key_event.pressed:
		return false
	return key_event.keycode == keycode or key_event.physical_keycode == keycode

func _build_background() -> void:
	var base := ColorRect.new()
	base.set_anchors_preset(Control.PRESET_FULL_RECT)
	base.color = Color(0.045, 0.055, 0.06, 1.0)
	add_child(base)

	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([Color("172b2e"), Color("243532"), Color("483522")])
	gradient.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill_from = Vector2(1, 0)
	texture.fill_to = Vector2(0, 1)
	var wash := TextureRect.new()
	wash.texture = texture
	wash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	wash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(wash)
	var backdrop := preload("res://Scripts/UI/TitleBackdrop.gd").new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)

func _build_title_screen() -> void:
	title_root = Control.new()
	title_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(title_root)

	var content := VBoxContainer.new()
	content.set_anchors_preset(Control.PRESET_CENTER)
	content.size = Vector2(760.0, 520.0)
	content.position = Vector2(-380.0, -260.0)
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 24)
	title_root.add_child(content)

	var title := Label.new()
	title.text = "New Drunkery"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 78)
	title.modulate = Color(1.0, 0.88, 0.56, 1.0)
	content.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "异世界酒馆试营业"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 30)
	subtitle.modulate = Color(0.86, 0.9, 0.88, 0.9)
	content.add_child(subtitle)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(1.0, 28.0)
	content.add_child(spacer)

	var start_button := _create_menu_button("开始 · 最终BOSS测试" if OS.get_cmdline_user_args().has("--test-monitor") else "开始")
	start_button.pressed.connect(_show_prepare)
	start_button.mouse_entered.connect(_set_title_menu_selection.bind(0))
	content.add_child(start_button)

	var codex_button := _create_menu_button("图鉴")
	codex_button.pressed.connect(_open_codex)
	codex_button.mouse_entered.connect(_set_title_menu_selection.bind(1))
	content.add_child(codex_button)

	var exit_button := _create_menu_button("结束")
	exit_button.pressed.connect(_quit_game)
	exit_button.mouse_entered.connect(_set_title_menu_selection.bind(2))
	content.add_child(exit_button)
	title_menu_buttons = [start_button, codex_button, exit_button]

	var hint := Label.new()
	hint.text = "Space 确认"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 18)
	hint.modulate = Color(0.78, 0.82, 0.8, 0.72)
	content.add_child(hint)

func _build_prepare_screen() -> void:
	prepare_root = Control.new()
	prepare_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	prepare_root.visible = false
	add_child(prepare_root)

	var panel := Panel.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = 46.0
	panel.offset_top = 36.0
	panel.offset_right = -46.0
	panel.offset_bottom = -36.0
	panel.add_theme_stylebox_override("panel", _create_panel_style(Color(0.075, 0.09, 0.105, 0.98), Color(0.86, 0.68, 0.3, 0.92), 3, 22))
	prepare_root.add_child(panel)

	var root_margin := MarginContainer.new()
	root_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_margin.add_theme_constant_override("margin_left", 30)
	root_margin.add_theme_constant_override("margin_top", 24)
	root_margin.add_theme_constant_override("margin_right", 30)
	root_margin.add_theme_constant_override("margin_bottom", 24)
	panel.add_child(root_margin)

	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 18)
	root_margin.add_child(page)

	var page_header := HBoxContainer.new()
	page_header.custom_minimum_size = Vector2(0.0, 62.0)
	page_header.add_theme_constant_override("separation", 18)
	page.add_child(page_header)

	var page_title := Label.new()
	page_title.text = "选择角色"
	page_title.add_theme_font_size_override("font_size", 38)
	page_title.modulate = Color(1.0, 0.88, 0.56, 1.0)
	page_header.add_child(page_title)

	var page_hint := Label.new()
	page_hint.text = "小技能与大招将在营业后的女神像处升级。"
	page_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	page_hint.add_theme_font_size_override("font_size", 17)
	page_hint.modulate = Color(0.72, 0.8, 0.82, 0.9)
	page_header.add_child(page_hint)

	var main_row := HBoxContainer.new()
	main_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_row.add_theme_constant_override("separation", 22)
	page.add_child(main_row)

	var character_card := Panel.new()
	character_card.custom_minimum_size = Vector2(286.0, 0.0)
	character_card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	character_card.add_theme_stylebox_override("panel", _create_panel_style(Color(0.12, 0.095, 0.07, 0.96), Color(0.78, 0.58, 0.24, 0.9), 2, 18))
	main_row.add_child(character_card)

	var character_margin := MarginContainer.new()
	character_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	character_margin.add_theme_constant_override("margin_left", 18)
	character_margin.add_theme_constant_override("margin_top", 18)
	character_margin.add_theme_constant_override("margin_right", 18)
	character_margin.add_theme_constant_override("margin_bottom", 18)
	character_card.add_child(character_margin)

	var character_column := VBoxContainer.new()
	character_column.alignment = BoxContainer.ALIGNMENT_CENTER
	character_column.add_theme_constant_override("separation", 12)
	character_margin.add_child(character_column)

	var character_title := Label.new()
	character_title.text = "当前角色"
	character_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	character_title.add_theme_font_size_override("font_size", 18)
	character_title.modulate = Color(1.0, 0.86, 0.56, 0.9)
	character_column.add_child(character_title)

	var avatar_panel := _create_avatar_button()
	avatar_panel.custom_minimum_size = Vector2(224.0, 224.0)
	avatar_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	avatar_panel.pressed.connect(_select_character.bind(&"chi_baobao", true))
	avatar_panel.mouse_entered.connect(_set_prepare_focus.bind(PrepareFocusSection.CHARACTER, 0))
	character_avatar_button = avatar_panel
	character_column.add_child(avatar_panel)

	var character_tag := Label.new()
	character_tag.text = "加速型料理人"
	character_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	character_tag.add_theme_font_size_override("font_size", 20)
	character_tag.modulate = Color(1.0, 0.94, 0.72, 1.0)
	character_column.add_child(character_tag)

	var coming_soon_a := _create_locked_character_slot("梵倪拉")
	coming_soon_a.custom_minimum_size = Vector2(0.0, 70.0)
	character_column.add_child(coming_soon_a)

	var coming_soon_b := _create_locked_character_slot("纳芙蒂蒂")
	coming_soon_b.custom_minimum_size = Vector2(0.0, 70.0)
	character_column.add_child(coming_soon_b)

	var detail_column := VBoxContainer.new()
	detail_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail_column.add_theme_constant_override("separation", 14)
	main_row.add_child(detail_column)

	var identity_panel := Panel.new()
	identity_panel.custom_minimum_size = Vector2(0.0, 136.0)
	identity_panel.size_flags_vertical = 0
	identity_panel.add_theme_stylebox_override("panel", _create_panel_style(Color(0.10, 0.13, 0.15, 0.96), Color(0.3, 0.65, 0.68, 0.72), 2, 16))
	detail_column.add_child(identity_panel)

	var identity_margin := MarginContainer.new()
	identity_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	identity_margin.add_theme_constant_override("margin_left", 20)
	identity_margin.add_theme_constant_override("margin_top", 14)
	identity_margin.add_theme_constant_override("margin_right", 20)
	identity_margin.add_theme_constant_override("margin_bottom", 12)
	identity_panel.add_child(identity_margin)

	var identity_column := VBoxContainer.new()
	identity_column.add_theme_constant_override("separation", 4)
	identity_margin.add_child(identity_column)

	character_name_label = Label.new()
	character_name_label.add_theme_font_size_override("font_size", 40)
	character_name_label.modulate = Color(0.98, 0.92, 0.74, 1.0)
	identity_column.add_child(character_name_label)

	character_intro_label = Label.new()
	character_intro_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	character_intro_label.add_theme_font_size_override("font_size", 24)
	character_intro_label.modulate = Color(0.82, 0.9, 0.9, 0.94)
	identity_column.add_child(character_intro_label)

	var info_row := HBoxContainer.new()
	info_row.custom_minimum_size = Vector2(0.0, 220.0)
	info_row.size_flags_vertical = 0
	info_row.add_theme_constant_override("separation", 14)
	detail_column.add_child(info_row)

	var stats_bundle := _create_labeled_panel("基础属性", Vector2(278.0, 0.0), Color(0.085, 0.105, 0.12, 0.96), Color(0.36, 0.5, 0.58, 0.72), 2, 14)
	var stats_panel: Panel = stats_bundle["panel"]
	var stats_column: VBoxContainer = stats_bundle["content"]
	stats_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stats_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	info_row.add_child(stats_panel)

	stats_body_label = Label.new()
	stats_body_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	stats_body_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	stats_body_label.add_theme_constant_override("line_spacing", 4)
	stats_body_label.add_theme_font_size_override("font_size", 24)
	stats_body_label.modulate = Color(0.92, 0.95, 0.94, 0.94)
	stats_column.add_child(stats_body_label)

	var passive_panel := _create_info_card("天生被动", "家常围裙", "降低料理失误带来的损失。", Color(0.45, 0.65, 0.46, 0.8))
	passive_panel.custom_minimum_size = Vector2(278.0, 0.0)
	passive_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	passive_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	info_row.add_child(passive_panel)

	var skill_panel := _create_skill_panel()
	skill_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	skill_panel.custom_minimum_size = Vector2(0.0, 330.0)
	skill_panel.size_flags_vertical = 0
	detail_column.add_child(skill_panel)

	selected_summary_label = Label.new()
	selected_summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	selected_summary_label.add_theme_font_size_override("font_size", 18)
	selected_summary_label.modulate = Color(0.72, 0.82, 0.84, 0.9)
	detail_column.add_child(selected_summary_label)

	var action_row := HBoxContainer.new()
	action_row.alignment = BoxContainer.ALIGNMENT_END
	action_row.add_theme_constant_override("separation", 14)
	page.add_child(action_row)

	var back_button := _create_footer_button("返回标题")
	back_button.pressed.connect(_show_title)
	back_button.mouse_entered.connect(_set_prepare_focus.bind(PrepareFocusSection.ACTION, 0))
	action_row.add_child(back_button)

	var start_button := _create_footer_button("开始游戏")
	start_button.pressed.connect(_start_run)
	start_button.mouse_entered.connect(_set_prepare_focus.bind(PrepareFocusSection.ACTION, 1))
	prepare_start_button = start_button
	action_row.add_child(start_button)
	prepare_action_buttons = [back_button, start_button]

	_refresh_character_details()
	_refresh_selection_state()

func _build_codex() -> void:
	codex_controller = CodexController.new()
	add_child(codex_controller)

func _create_menu_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(340.0, 62.0)
	button.add_theme_font_size_override("font_size", 28)
	_apply_menu_button_style(button, false)
	return button

func _create_footer_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(210.0, 54.0)
	button.add_theme_font_size_override("font_size", 22)
	_apply_footer_button_style(button, false)
	return button

func _create_avatar_button() -> Button:
	var button := Button.new()
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(184.0, 184.0)
	button.text = ""
	button.icon = PLAYER_AVATAR
	button.expand_icon = true
	_apply_avatar_button_style(button, false)
	return button

func _create_locked_character_slot(name_text: String) -> Panel:
	var panel := Panel.new()
	panel.custom_minimum_size = Vector2(184.0, 86.0)
	panel.add_theme_stylebox_override("panel", _create_panel_style(Color(0.08, 0.09, 0.1, 0.72), Color(0.42, 0.45, 0.46, 0.52), 2, 12))

	var label := Label.new()
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.text = "%s\n暂未开放" % name_text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 18)
	label.modulate = Color(0.78, 0.8, 0.78, 0.64)
	panel.add_child(label)
	return panel

func _create_labeled_panel(title_text: String, min_size: Vector2, bg: Color, border: Color, border_width: int, radius: int) -> Dictionary:
	var panel := Panel.new()
	panel.custom_minimum_size = min_size
	panel.add_theme_stylebox_override("panel", _create_panel_style(bg, border, border_width, radius))

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 14)
	panel.add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	margin.add_child(column)

	if title_text != "":
		var title_label := Label.new()
		title_label.text = title_text
		title_label.add_theme_font_size_override("font_size", 27)
		title_label.modulate = Color(1.0, 0.86, 0.56, 1.0)
		column.add_child(title_label)

	return {"panel": panel, "content": column}

func _create_info_card(title_text: String, name_text: String, detail_text: String, border_color: Color) -> Panel:
	var panel := Panel.new()
	panel.add_theme_stylebox_override("panel", _create_panel_style(Color(0.09, 0.11, 0.13, 0.96), border_color, 2, 14))
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_bottom", 14)
	panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	margin.add_child(column)
	var title := Label.new()
	title.text = title_text
	title.add_theme_font_size_override("font_size", 23)
	title.modulate = Color(0.74, 0.88, 0.88, 0.9)
	column.add_child(title)
	var name_label := Label.new()
	name_label.text = name_text
	name_label.add_theme_font_size_override("font_size", 32)
	name_label.modulate = Color(1.0, 0.9, 0.58, 1.0)
	column.add_child(name_label)
	var detail := Label.new()
	detail.text = detail_text
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.add_theme_font_size_override("font_size", 21)
	detail.modulate = Color(0.84, 0.9, 0.9, 0.9)
	column.add_child(detail)
	return panel

func _create_skill_panel() -> Panel:
	var bundle := _create_labeled_panel("初始技能", Vector2(0.0, 0.0), Color(0.075, 0.09, 0.1, 0.92), Color(0.36, 0.54, 0.52, 0.7), 2, 14)
	var panel: Panel = bundle["panel"]
	var column: VBoxContainer = bundle["content"]
	column.add_theme_constant_override("separation", 10)
	var small_label := Label.new()
	small_label.text = "小技能：抢灶步\n移速 +40%，持续 2 秒，冷却 15 秒。"
	small_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	small_label.add_theme_font_size_override("font_size", 22)
	column.add_child(small_label)
	var big_label := Label.new()
	big_label.text = "大招：稳住这锅\n所有读条型工作速度提高 100%，持续 10 秒。"
	big_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	big_label.add_theme_font_size_override("font_size", 22)
	column.add_child(big_label)
	var hint := Label.new()
	hint.text = "第 2 天结束后可升级小技能；第 4 天结束后可升级大招。"
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 18)
	hint.modulate = Color(0.72, 0.82, 0.84, 0.9)
	column.add_child(hint)

	return panel

func _on_small_skill_test_selected(index: int) -> void:
	var options: Array[Dictionary] = SmallSkillDefs.get_options()
	var selected: Dictionary = options[clampi(index, 0, options.size() - 1)]
	selected_small_skill_id = StringName(selected.id)
	if small_skill_selector != null:
		small_skill_selector.select(index)
	if small_skill_detail != null:
		small_skill_detail.text = SmallSkillDefs.get_description(selected_small_skill_id)
	_refresh_selection_state()

func _on_big_skill_test_selected(index: int) -> void:
	var options: Array[Dictionary] = BigSkillDefs.get_options()
	var safe_index := clampi(index, 0, options.size() - 1)
	var selected: Dictionary = options[safe_index]
	selected_big_skill_id = StringName(selected.id)
	if big_skill_selector != null:
		big_skill_selector.select(safe_index)
	if big_skill_detail != null:
		big_skill_detail.text = "%s\n%s\n%s" % [String(selected.name), String(selected.detail), String(selected.note)]
	_refresh_selection_state()

func _create_full_skill_card(data: Dictionary) -> Button:
	var button := Button.new()
	button.toggle_mode = false
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.text = ""
	button.custom_minimum_size = Vector2(0.0, 178.0)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.clip_contents = true
	button.add_theme_stylebox_override("normal", _create_card_style(Color(0.13, 0.15, 0.18, 0.9), Color(0.42, 0.45, 0.5, 0.8), 2, 12))
	button.add_theme_stylebox_override("hover", _create_card_style(Color(0.18, 0.2, 0.22, 0.95), Color(1.0, 0.82, 0.36, 0.95), 2, 12))
	button.add_theme_stylebox_override("pressed", _create_card_style(Color(0.24, 0.2, 0.12, 1.0), Color(1.0, 0.9, 0.5, 1.0), 2, 12))
	button.add_theme_stylebox_override("focus", _create_card_style(Color(0.18, 0.2, 0.22, 0.95), Color(1.0, 0.9, 0.5, 1.0), 2, 12))

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 12)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 5)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(column)
	var name_label := Label.new()
	name_label.text = String(data.get("name", ""))
	name_label.add_theme_font_size_override("font_size", 27)
	name_label.modulate = Color(1.0, 0.9, 0.58, 1.0)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(name_label)
	var summary_label := Label.new()
	summary_label.text = String(data.get("summary", ""))
	summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	summary_label.add_theme_font_size_override("font_size", 20)
	summary_label.modulate = Color(0.84, 0.94, 0.94, 0.96)
	summary_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(summary_label)
	var detail_label := Label.new()
	detail_label.text = String(data.get("detail", ""))
	detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_label.add_theme_font_size_override("font_size", 20)
	detail_label.modulate = Color(0.9, 0.93, 0.9, 0.94)
	detail_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(detail_label)
	var note_label := Label.new()
	note_label.text = String(data.get("note", ""))
	note_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note_label.add_theme_font_size_override("font_size", 18)
	note_label.modulate = Color(0.66, 0.78, 0.78, 0.9)
	note_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(note_label)
	return button

func _create_card_style(bg: Color, border: Color, border_width: int, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.border_width_left = border_width
	style.border_width_top = border_width
	style.border_width_right = border_width
	style.border_width_bottom = border_width
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.2)
	style.shadow_size = 4
	preload("res://Scripts/UI/AtelierStyle.gd").finish(style, border.r > 0.9 and border.g > 0.65)
	return style

func _create_panel_style(bg: Color, border: Color, border_width: int, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.border_width_left = border_width
	style.border_width_top = border_width
	style.border_width_right = border_width
	style.border_width_bottom = border_width
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.26)
	style.shadow_size = 8
	preload("res://Scripts/UI/AtelierStyle.gd").finish(style)
	return style

func _show_title() -> void:
	current_mode = ScreenMode.TITLE
	title_root.visible = true
	prepare_root.visible = false
	_refresh_title_menu_highlight()

func _show_prepare() -> void:
	current_mode = ScreenMode.PREPARE
	title_root.visible = false
	prepare_root.visible = true
	prepare_focus_section = PrepareFocusSection.CHARACTER
	prepare_focus_index = 0
	is_character_confirmed = false
	_refresh_character_details()
	_refresh_selection_state()
	_refresh_prepare_focus_highlight()

func _select_character(character_id: StringName, confirm_character: bool = false) -> void:
	selected_character_id = character_id
	if confirm_character:
		is_character_confirmed = true
		_set_prepare_focus(PrepareFocusSection.ACTION, 1)
	_refresh_character_details()
	_refresh_prepare_focus_highlight()

func _refresh_character_details() -> void:
	var character_data: Dictionary = CHARACTER_OPTIONS.get(selected_character_id, CHARACTER_OPTIONS[&"chi_baobao"])
	if character_name_label != null:
		character_name_label.text = String(character_data.get("name", ""))
	if character_intro_label != null:
		character_intro_label.text = String(character_data.get("intro", ""))
	if stats_body_label != null:
		stats_body_label.text = "\n".join(character_data.get("stats", []))

func _refresh_selection_state() -> void:
	if selected_summary_label != null:
		selected_summary_label.text = "当前角色：%s / 初始技能：抢灶步 / 初始大招：稳住这锅。上下选择区域，Space 开始，K 返回。" % [
			_get_character_name(selected_character_id),
		]
	_refresh_prepare_focus_highlight()

func _get_character_name(character_id: StringName) -> String:
	var character_data: Dictionary = CHARACTER_OPTIONS.get(character_id, CHARACTER_OPTIONS[&"chi_baobao"])
	return String(character_data.get("name", ""))

func _get_skill_name(skill_id: StringName, options: Array) -> String:
	for skill_data in options:
		if StringName(skill_data.get("id", &"")) == skill_id:
			return String(skill_data.get("name", ""))
	return ""

func _start_run() -> void:
	get_tree().set_meta("run_setup", {
		"character_id": selected_character_id,
		# Skill variants are earned at the goddess statue after day 2/day 4.
		# The start screen keeps the old selectors only as a visual test harness;
		# normal runs always begin with the base skills.
		"small_skill_variant": &"rush_order",
		"big_skill_variant": &"steady_pot",
		# The current start screen is a skill-testing harness. Begin each
		# launched test run with a full ultimate gauge so variants can be tried
		# immediately; headless gameplay and later run flows keep their normal
		# zero-energy initialization unless they opt in to this flag.
		"start_ultimate_full": true,
		"innate_passive_id": &"home_apron"
	})
	get_tree().change_scene_to_file(MAIN_SCENE_PATH)

func _quit_game() -> void:
	get_tree().quit()

func _move_title_menu_selection(direction: int) -> void:
	if title_menu_buttons.is_empty():
		return
	selected_title_menu_index = wrapi(selected_title_menu_index + direction, 0, title_menu_buttons.size())
	_refresh_title_menu_highlight()

func _set_title_menu_selection(index: int) -> void:
	if index < 0 or index >= title_menu_buttons.size():
		return
	selected_title_menu_index = index
	_refresh_title_menu_highlight()

func _activate_selected_title_menu_item() -> void:
	if selected_title_menu_index == 2:
		_quit_game()
	elif selected_title_menu_index == 1:
		_open_codex()
	else:
		_show_prepare()

func _open_codex() -> void:
	if codex_controller != null:
		codex_controller.open_codex()

func _refresh_title_menu_highlight() -> void:
	for i in range(title_menu_buttons.size()):
		var button := title_menu_buttons[i]
		if button != null:
			_apply_menu_button_style(button, i == selected_title_menu_index)

func _set_prepare_focus(section: PrepareFocusSection, index: int) -> void:
	if not is_character_confirmed and section != PrepareFocusSection.CHARACTER:
		return
	prepare_focus_section = section
	prepare_focus_index = _clamp_prepare_focus_index(section, index)
	_refresh_prepare_focus_highlight()

func _move_prepare_focus_horizontal(direction: int) -> void:
	var item_count := _get_prepare_focus_item_count(prepare_focus_section)
	if item_count <= 1:
		return
	prepare_focus_index = wrapi(prepare_focus_index + direction, 0, item_count)
	_refresh_prepare_focus_highlight()

func _move_prepare_focus_vertical(direction: int) -> void:
	if not is_character_confirmed:
		return
	var sections: Array[PrepareFocusSection] = [
		PrepareFocusSection.CHARACTER,
		PrepareFocusSection.ACTION
	]
	var current_section_index := sections.find(prepare_focus_section)
	if current_section_index < 0:
		current_section_index = 0
	var next_section: PrepareFocusSection = sections[wrapi(current_section_index + direction, 0, sections.size())]
	prepare_focus_section = next_section
	prepare_focus_index = _clamp_prepare_focus_index(next_section, prepare_focus_index)
	_refresh_prepare_focus_highlight()

func _activate_prepare_focus() -> void:
	match prepare_focus_section:
		PrepareFocusSection.CHARACTER:
			_select_character(&"chi_baobao", true)
			_set_prepare_focus(PrepareFocusSection.ACTION, 1)
		PrepareFocusSection.ACTION:
			if prepare_focus_index == 0:
				_show_title()
			else:
				_start_run()

func _refresh_prepare_focus_highlight() -> void:
	_apply_avatar_button_style(
		character_avatar_button,
		prepare_focus_section == PrepareFocusSection.CHARACTER,
		is_character_confirmed and selected_character_id == &"chi_baobao"
	)
	for i in range(prepare_action_buttons.size()):
		var button := prepare_action_buttons[i]
		if button != null:
			_apply_footer_button_style(button, prepare_focus_section == PrepareFocusSection.ACTION and i == prepare_focus_index)
			button.disabled = not is_character_confirmed

func _get_prepare_focus_item_count(section: PrepareFocusSection) -> int:
	match section:
		PrepareFocusSection.CHARACTER:
			return 1
		PrepareFocusSection.ACTION:
			return prepare_action_buttons.size()
	return 1

func _clamp_prepare_focus_index(section: PrepareFocusSection, index: int) -> int:
	return clampi(index, 0, max(_get_prepare_focus_item_count(section) - 1, 0))

func _apply_menu_button_style(button: Button, is_selected: bool) -> void:
	var normal_bg := Color(0.3, 0.2, 0.1, 0.98) if is_selected else Color(0.15, 0.16, 0.16, 0.92)
	var normal_border := Color(1.0, 0.86, 0.36, 1.0) if is_selected else Color(0.5, 0.5, 0.48, 0.78)
	button.add_theme_stylebox_override("normal", _create_card_style(normal_bg, normal_border, 4 if is_selected else 2, 14))
	button.add_theme_stylebox_override("hover", _create_card_style(Color(0.34, 0.24, 0.12, 1.0), Color(1.0, 0.92, 0.5, 1.0), 4, 14))
	button.add_theme_stylebox_override("pressed", _create_card_style(Color(0.42, 0.28, 0.1, 1.0), Color(1.0, 0.74, 0.28, 1.0), 4, 14))
	button.modulate = Color(1.0, 1.0, 1.0, 1.0) if is_selected else Color(0.86, 0.88, 0.86, 0.92)

func _apply_footer_button_style(button: Button, is_selected: bool) -> void:
	var normal_bg := Color(0.58, 0.46, 0.18, 1.0) if is_selected else Color(0.13, 0.15, 0.18, 0.9)
	var normal_border := Color(1.0, 0.98, 0.78, 1.0) if is_selected else Color(0.42, 0.45, 0.5, 0.8)
	var border_width := 7 if is_selected else 2
	button.add_theme_stylebox_override("normal", _create_card_style(normal_bg, normal_border, border_width, 12))
	button.add_theme_stylebox_override("hover", _create_card_style(Color(0.62, 0.5, 0.2, 1.0), Color(1.0, 0.98, 0.78, 1.0), 7, 12))
	button.add_theme_stylebox_override("pressed", _create_card_style(normal_bg, normal_border, border_width, 12))
	button.add_theme_stylebox_override("disabled", _create_card_style(Color(0.1, 0.11, 0.12, 0.72), Color(0.32, 0.34, 0.36, 0.58), 2, 12))

func _apply_avatar_button_style(button: Button, is_focused: bool, is_selected: bool = false) -> void:
	if button == null:
		return
	var bg := Color(0.54, 0.44, 0.18, 1.0) if is_focused else (Color(0.2, 0.18, 0.13, 0.95) if is_selected else Color(0.14, 0.15, 0.15, 0.9))
	var border := Color(1.0, 0.98, 0.78, 1.0) if is_focused else (Color(0.84, 0.66, 0.24, 0.9) if is_selected else Color(0.52, 0.48, 0.42, 0.72))
	var border_width := 7 if is_focused else (3 if is_selected else 2)
	button.add_theme_stylebox_override("normal", _create_panel_style(bg, border, border_width, 16))
	button.add_theme_stylebox_override("hover", _create_panel_style(Color(0.6, 0.48, 0.2, 1.0), Color(1.0, 0.98, 0.78, 1.0), 7, 16))
	button.add_theme_stylebox_override("pressed", _create_panel_style(Color(0.66, 0.46, 0.16, 1.0), Color(1.0, 0.86, 0.36, 1.0), 7, 16))
