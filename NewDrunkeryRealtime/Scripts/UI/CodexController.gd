class_name CodexController
extends CanvasLayer

const AudioCue = preload("res://Scripts/Audio/AudioCue.gd")

const TestItemDefs = preload("res://Scripts/Kitchen/TestItemDefs.gd")
const CodexCatalog = preload("res://Scripts/UI/CodexCatalog.gd")
const BlessingDefs = preload("res://Scripts/Progression/BlessingDefs.gd")

const CATEGORY_ENEMIES: StringName = &"enemies"
const CATEGORY_BATTLE_ZONES: StringName = &"battle_zones"
const CATEGORY_INGREDIENTS: StringName = &"ingredients"
const CATEGORY_DISHES: StringName = &"dishes"
const CATEGORY_STATIONS: StringName = &"stations"
const CATEGORY_BLESSINGS: StringName = &"blessings"

const ENEMY_TEXTURES := {
	&"chaser": preload("res://ArtResource/Generated/Enemy/desert_bird_enemy.svg"),
	&"sprinter": preload("res://ArtResource/Generated/Enemy/sand_hare_enemy.svg"),
	&"slammer": preload("res://ArtResource/Generated/Enemy/red_lamb_enemy.svg"),
	&"ranged": preload("res://ArtResource/Generated/Enemy/cactus_beetle_enemy.svg"),
	&"bullet_fan": preload("res://ArtResource/Generated/Enemy/sun_moth_enemy.svg"),
	&"bruiser": preload("res://ArtResource/Generated/Enemy/camel_enemy.svg"),
	&"sniper": preload("res://ArtResource/Generated/Enemy/sand_scarab_enemy.svg"),
	&"orbiter": preload("res://ArtResource/Generated/Enemy/sun_guardian_enemy.svg"),
	&"splitter": preload("res://ArtResource/Generated/Enemy/thorn_splitter_enemy.svg"),
	&"sandworm_boss": preload("res://ArtResource/Generated/Enemy/sandworm_boss.svg"),
	&"scorpion_boss": preload("res://ArtResource/Generated/Enemy/scorpion_boss.svg"),
	&"vulture_boss": preload("res://ArtResource/Generated/Enemy/vulture_boss.svg"),
	&"monitor_boss": preload("res://ArtResource/Generated/Enemy/monitor_boss.svg")
}

const STATION_TEXTURES := {
	&"cut": preload("res://ArtResource/Cooker/cut_station.svg"),
	&"heat": preload("res://ArtResource/Cooker/roast_station.svg"),
	&"grind": preload("res://ArtResource/Cooker/grind_station.svg"),
	&"assembly": preload("res://ArtResource/Cooker/assembly_station.svg")
}

signal closed

var root: Control
var tabs_row: HBoxContainer
var dish_tabs_row: HBoxContainer
var list_scroll: ScrollContainer
var list_container: VBoxContainer
var detail_icon: TextureRect
var detail_title: Label
var detail_body: Label
var detail_process_row: HBoxContainer
var category_buttons: Dictionary = {}
var dish_category_buttons: Dictionary = {}
var item_buttons: Array[Button] = []
var current_category: StringName = CATEGORY_INGREDIENTS
var current_dish_category: StringName = &"drink"
var selected_index: int = 0
var was_tree_paused_before_open: bool = false
var owned_blessing_ids: Array[StringName] = []

func _ready() -> void:
	layer = 90
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	_show_category(CATEGORY_INGREDIENTS)
	hide_codex()

func open_codex(category: StringName = CATEGORY_INGREDIENTS) -> void:
	was_tree_paused_before_open = get_tree().paused
	visible = true
	get_tree().paused = true
	_show_category(category)

func hide_codex() -> void:
	visible = false

func is_open() -> bool:
	return visible

func set_owned_blessings(blessing_ids: Array) -> void:
	owned_blessing_ids.clear()
	for blessing_id in blessing_ids:
		var normalized_id := StringName(blessing_id)
		if normalized_id != &"" and normalized_id not in owned_blessing_ids:
			owned_blessing_ids.append(normalized_id)
	if visible and current_category == CATEGORY_BLESSINGS:
		_rebuild_list()
		_refresh_detail()

func _unhandled_input(event: InputEvent) -> void:
	if not visible or event.is_echo():
		return
	if _is_ui_cancel_pressed(event):
		AudioCue.play_ui(&"ui_cancel")
		_close()
		get_viewport().set_input_as_handled()
		return
	if current_category == CATEGORY_DISHES:
		if event.is_action_pressed("ui_navigate_left") or event.is_action_pressed("ui_left"):
			AudioCue.play_ui(&"ui_tab")
			_move_dish_category(-1)
			get_viewport().set_input_as_handled()
			return
		if event.is_action_pressed("ui_navigate_right") or event.is_action_pressed("ui_right"):
			AudioCue.play_ui(&"ui_tab")
			_move_dish_category(1)
			get_viewport().set_input_as_handled()
			return
	if event.is_action_pressed("ui_navigate_left") or event.is_action_pressed("ui_left"):
		AudioCue.play_ui(&"ui_tab")
		_move_category(-1)
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_navigate_right") or event.is_action_pressed("ui_right"):
		AudioCue.play_ui(&"ui_tab")
		_move_category(1)
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_up") or event.is_action_pressed("move_up"):
		AudioCue.play_ui(&"ui_move")
		_move_selection(-1)
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_down") or event.is_action_pressed("move_down"):
		AudioCue.play_ui(&"ui_move")
		_move_selection(1)
		get_viewport().set_input_as_handled()

func _build_ui() -> void:
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	var shade := ColorRect.new()
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.02, 0.025, 0.03, 0.86)
	root.add_child(shade)

	var panel := Panel.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = 96.0
	panel.offset_top = 72.0
	panel.offset_right = -96.0
	panel.offset_bottom = -72.0
	panel.add_theme_stylebox_override("panel", _style(Color(0.12, 0.11, 0.09, 0.98), Color(0.86, 0.68, 0.32, 1.0), 3, 10))
	root.add_child(panel)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_bottom", 24)
	panel.add_child(margin)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 18)
	margin.add_child(layout)

	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 18)
	layout.add_child(title_row)

	var title := Label.new()
	title.text = "图鉴"
	title.add_theme_font_size_override("font_size", 42)
	title.modulate = Color(1.0, 0.86, 0.48, 1.0)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(title)

	var close_button := Button.new()
	close_button.text = "返回"
	close_button.set_meta("audio_cue", &"ui_cancel")
	close_button.custom_minimum_size = Vector2(120, 44)
	close_button.add_theme_font_size_override("font_size", 20)
	close_button.pressed.connect(_close)
	title_row.add_child(close_button)

	tabs_row = HBoxContainer.new()
	tabs_row.add_theme_constant_override("separation", 10)
	layout.add_child(tabs_row)
	_add_category_button(CATEGORY_ENEMIES, "敌人")
	_add_category_button(CATEGORY_BATTLE_ZONES, "战斗区")
	_add_category_button(CATEGORY_INGREDIENTS, "食材")
	_add_category_button(CATEGORY_DISHES, "料理")
	_add_category_button(CATEGORY_STATIONS, "设施")
	_add_category_button(CATEGORY_BLESSINGS, "已拥有祝福")

	dish_tabs_row = HBoxContainer.new()
	dish_tabs_row.add_theme_constant_override("separation", 10)
	dish_tabs_row.visible = false
	layout.add_child(dish_tabs_row)
	for entry in CodexCatalog.get_dish_subcategories():
		_add_dish_category_button(StringName(entry.get("id", &"")), String(entry.get("name", "")))

	var content_row := HBoxContainer.new()
	content_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_row.add_theme_constant_override("separation", 18)
	layout.add_child(content_row)

	list_scroll = ScrollContainer.new()
	list_scroll.custom_minimum_size = Vector2(360, 0)
	list_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_row.add_child(list_scroll)

	list_container = VBoxContainer.new()
	list_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_container.add_theme_constant_override("separation", 8)
	list_scroll.add_child(list_container)

	var detail_panel := Panel.new()
	detail_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail_panel.add_theme_stylebox_override("panel", _style(Color(0.08, 0.085, 0.08, 0.96), Color(0.38, 0.34, 0.26, 0.95), 2, 8))
	content_row.add_child(detail_panel)

	var detail_margin := MarginContainer.new()
	detail_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	detail_margin.add_theme_constant_override("margin_left", 28)
	detail_margin.add_theme_constant_override("margin_top", 24)
	detail_margin.add_theme_constant_override("margin_right", 28)
	detail_margin.add_theme_constant_override("margin_bottom", 22)
	detail_panel.add_child(detail_margin)

	var detail_column := VBoxContainer.new()
	detail_column.add_theme_constant_override("separation", 18)
	detail_margin.add_child(detail_column)

	var header_row := HBoxContainer.new()
	header_row.add_theme_constant_override("separation", 22)
	detail_column.add_child(header_row)

	var icon_frame := Panel.new()
	icon_frame.custom_minimum_size = Vector2(144, 144)
	icon_frame.add_theme_stylebox_override("panel", _style(Color(0.16, 0.13, 0.08, 0.98), Color(0.82, 0.62, 0.24, 1.0), 2, 8))
	header_row.add_child(icon_frame)

	detail_icon = TextureRect.new()
	detail_icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	detail_icon.offset_left = 10.0
	detail_icon.offset_top = 10.0
	detail_icon.offset_right = -10.0
	detail_icon.offset_bottom = -10.0
	detail_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	detail_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_frame.add_child(detail_icon)

	detail_title = Label.new()
	detail_title.add_theme_font_size_override("font_size", 34)
	detail_title.modulate = Color(1.0, 0.88, 0.56, 1.0)
	detail_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	detail_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_row.add_child(detail_title)

	detail_process_row = HBoxContainer.new()
	detail_process_row.name = "DishProcessIconsRow"
	detail_process_row.add_theme_constant_override("separation", 10)
	detail_column.add_child(detail_process_row)

	detail_body = Label.new()
	detail_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_body.add_theme_font_size_override("font_size", 22)
	detail_body.modulate = Color(0.92, 0.9, 0.82, 1.0)
	detail_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail_column.add_child(detail_body)

	var hint := Label.new()
	hint.text = "方向键切换，K 返回（Esc 备用）"
	hint.add_theme_font_size_override("font_size", 18)
	hint.modulate = Color(0.86, 0.8, 0.62, 0.86)
	detail_column.add_child(hint)

func _is_ui_cancel_pressed(event: InputEvent) -> bool:
	return event.is_action_pressed("ui_cancel") or _is_key_pressed(event, Key.KEY_K)

func _is_key_pressed(event: InputEvent, keycode: Key) -> bool:
	var key_event := event as InputEventKey
	if key_event == null or not key_event.pressed:
		return false
	return key_event.keycode == keycode or key_event.physical_keycode == keycode

func _add_category_button(category: StringName, text: String) -> void:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(132, 42)
	button.add_theme_font_size_override("font_size", 18)
	button.set_meta("audio_cue", &"ui_tab")
	button.pressed.connect(_show_category.bind(category))
	tabs_row.add_child(button)
	category_buttons[category] = button

func _add_dish_category_button(category: StringName, text: String) -> void:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(120, 40)
	button.add_theme_font_size_override("font_size", 18)
	button.set_meta("audio_cue", &"ui_tab")
	button.pressed.connect(_show_dish_category.bind(category))
	dish_tabs_row.add_child(button)
	dish_category_buttons[category] = button

func _show_category(category: StringName) -> void:
	current_category = category
	selected_index = 0
	if current_category != CATEGORY_DISHES:
		current_dish_category = &"drink"
	_rebuild_list()
	_refresh_tabs()
	_refresh_detail()
	_scroll_to_selected()

func _show_dish_category(category: StringName) -> void:
	current_dish_category = category
	current_category = CATEGORY_DISHES
	selected_index = 0
	_rebuild_list()
	_refresh_tabs()
	_refresh_detail()
	_scroll_to_selected()

func _move_category(direction: int) -> void:
	var categories := [CATEGORY_ENEMIES, CATEGORY_BATTLE_ZONES, CATEGORY_INGREDIENTS, CATEGORY_DISHES, CATEGORY_STATIONS, CATEGORY_BLESSINGS]
	var index := categories.find(current_category)
	index = wrapi(index + direction, 0, categories.size())
	_show_category(categories[index])

func _move_dish_category(direction: int) -> void:
	var categories := CodexCatalog.get_dish_subcategories()
	if categories.is_empty():
		return
	var ids: Array[StringName] = []
	for entry in categories:
		ids.append(StringName(entry.get("id", &"")))
	var index := ids.find(current_dish_category)
	index = wrapi(index + direction, 0, ids.size())
	_show_dish_category(ids[index])

func _move_selection(direction: int) -> void:
	var entries := _get_entries(current_category)
	if entries.is_empty():
		return
	selected_index = wrapi(selected_index + direction, 0, entries.size())
	_refresh_list_selection()
	_refresh_detail()
	_scroll_to_selected()

func _rebuild_list() -> void:
	for child in list_container.get_children():
		list_container.remove_child(child)
		child.queue_free()
	item_buttons.clear()
	var entries := _get_entries(current_category)
	for i in range(entries.size()):
		var entry: Dictionary = entries[i]
		var button := Button.new()
		button.text = String(entry.get("name", ""))
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.custom_minimum_size = Vector2(0, 54)
		button.add_theme_font_size_override("font_size", 20)
		button.pressed.connect(_select_index.bind(i))
		list_container.add_child(button)
		item_buttons.append(button)
	_refresh_list_selection()

func _select_index(index: int) -> void:
	selected_index = index
	_refresh_list_selection()
	_refresh_detail()
	_scroll_to_selected()

func _refresh_tabs() -> void:
	for category in category_buttons.keys():
		var button: Button = category_buttons[category]
		button.button_pressed = category == current_category
		button.add_theme_stylebox_override("normal", _button_style(Color(0.32, 0.24, 0.12, 1.0) if category == current_category else Color(0.16, 0.15, 0.13, 1.0), Color(0.94, 0.76, 0.34, 1.0), 2, 8, 12))
	if dish_tabs_row != null:
		dish_tabs_row.visible = current_category == CATEGORY_DISHES
	for category in dish_category_buttons.keys():
		var button: Button = dish_category_buttons[category]
		var pressed: bool = current_category == CATEGORY_DISHES and StringName(category) == current_dish_category
		button.button_pressed = pressed
		button.add_theme_stylebox_override("normal", _button_style(Color(0.24, 0.2, 0.14, 1.0) if pressed else Color(0.14, 0.14, 0.12, 0.96), Color(0.92, 0.74, 0.32, 1.0) if pressed else Color(0.34, 0.32, 0.28, 1.0), 2, 8, 12))

func _refresh_list_selection() -> void:
	for i in range(item_buttons.size()):
		var button := item_buttons[i]
		var selected := i == selected_index
		button.add_theme_stylebox_override("normal", _button_style(Color(0.34, 0.26, 0.12, 1.0) if selected else Color(0.13, 0.13, 0.12, 0.96), Color(0.92, 0.74, 0.32, 1.0) if selected else Color(0.34, 0.32, 0.28, 1.0), 2, 6, 18))
		button.add_theme_stylebox_override("hover", _button_style(Color(0.26, 0.2, 0.1, 1.0), Color(0.92, 0.74, 0.32, 1.0), 2, 6, 18))
		button.add_theme_stylebox_override("pressed", _button_style(Color(0.38, 0.28, 0.12, 1.0), Color(1.0, 0.86, 0.4, 1.0), 2, 6, 18))

func _refresh_detail() -> void:
	var entries := _get_entries(current_category)
	if entries.is_empty():
		detail_title.text = ""
		detail_body.text = ""
		detail_icon.texture = null
		_rebuild_detail_process_icons([])
		return
	var entry: Dictionary = entries[clampi(selected_index, 0, entries.size() - 1)]
	detail_title.text = String(entry.get("name", ""))
	if current_category == CATEGORY_DISHES:
		detail_title.text = "%s · %s" % [_get_current_dish_category_name(), detail_title.text]
	detail_body.text = String(entry.get("body", ""))
	detail_icon.texture = entry.get("texture", null)
	_rebuild_detail_process_icons(entry.get("process_states", []))

func _rebuild_detail_process_icons(process_states: Variant) -> void:
	if detail_process_row == null:
		return
	for child in detail_process_row.get_children():
		child.queue_free()
	var states: Array = process_states if process_states is Array else []
	detail_process_row.visible = current_category == CATEGORY_DISHES and not states.is_empty()
	if not detail_process_row.visible:
		return

	var label := Label.new()
	label.text = "熟成度"
	label.add_theme_font_size_override("font_size", 20)
	label.modulate = Color(0.86, 0.80, 0.62, 0.94)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	detail_process_row.add_child(label)

	for state_variant in states:
		var process_state := StringName(state_variant)
		var icon_texture: Texture2D = TestItemDefs.get_process_icon_texture(process_state)
		if icon_texture == null:
			continue
		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(40.0, 40.0)
		icon.texture = icon_texture
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.tooltip_text = TestItemDefs.get_process_display_name(process_state)
		detail_process_row.add_child(icon)

func _scroll_to_selected() -> void:
	if list_scroll == null or selected_index < 0 or selected_index >= item_buttons.size():
		return
	var button := item_buttons[selected_index]
	await get_tree().process_frame
	if list_scroll != null and is_instance_valid(button):
		list_scroll.ensure_control_visible(button)

func _close() -> void:
	hide_codex()
	get_tree().paused = was_tree_paused_before_open
	closed.emit()

func _get_entries(category: StringName) -> Array[Dictionary]:
	match category:
		CATEGORY_ENEMIES:
			return _get_enemy_entries()
		CATEGORY_BATTLE_ZONES:
			return CodexCatalog.get_battle_zone_entries()
		CATEGORY_INGREDIENTS:
			return _get_ingredient_entries()
		CATEGORY_DISHES:
			return _get_dish_entries()
		CATEGORY_STATIONS:
			return _get_station_entries()
		CATEGORY_BLESSINGS:
			return _get_blessing_entries()
	return []

func _get_blessing_entries() -> Array[Dictionary]:
	var owned: Dictionary = {}
	for blessing_id in owned_blessing_ids:
		owned[blessing_id] = true
	var entries: Array[Dictionary] = []
	for blessing_data in BlessingDefs.create_default_blessings():
		var blessing_id := StringName(blessing_data.get("id", &""))
		if not owned.has(blessing_id):
			continue
		entries.append({
			"id": blessing_id,
			"name": String(blessing_data.get("title", "祝福")),
			"body": String(blessing_data.get("description", "")),
			"texture": null
		})
	if entries.is_empty():
		entries.append({
			"id": &"__empty_blessings__",
			"name": "尚未获得祝福",
			"body": "当前还没有已拥有的祝福。升级后获得祝福点，并在夜间与女神像交互进行选择。",
			"texture": null
		})
	return entries

func _get_enemy_entries() -> Array[Dictionary]:
	return [
		_enemy(&"chaser", "沙原禽", "生命 300 / 速度 150\n攻击：接触伤害。\n掉落：沙原禽肉。\n说明：最基础的追击敌人，会持续把玩家从厨房节奏里赶出来。"),
		_enemy(&"sprinter", "疾风沙兔", "生命 400 / 速度 118\n攻击：带预警的直线冲锋。\n掉落：沙兔肉。\n说明：冲锋速度快，需要避开它面前的长直线。"),
		_enemy(&"slammer", "红鬃岩羊", "生命 400 / 速度 108\n攻击：范围砸地并留下危险区域。\n掉落：红鬃羊肉。\n说明：会封锁前场地面，与订单高峰同时出现时压力更大。"),
		_enemy(&"ranged", "脆芽甲虫", "生命 300 / 速度 104\n攻击：远程直线弹。\n掉落：脆脆芽。\n说明：会主动拉开距离，需要离开厨房路线清理。"),
		_enemy(&"bullet_fan", "日轮沙蛾", "生命 400 / 速度 98\n攻击：扇形弹幕或追踪弹。\n掉落：太阳籽。\n说明：通过连续弹幕制造走位压力。"),
		_enemy(&"bruiser", "沙漠战驼", "生命 620 / 速度 82\n攻击：大范围重砸。\n掉落：沙漠驼肉。\n说明：行动缓慢但生命高，是高压波次的中心威胁。"),
		_enemy(&"sniper", "莳萝沙甲", "生命 280 / 速度 90\n攻击：更远、更快、更痛的直线弹。\n掉落：莳萝。\n说明：会切断厨房与战斗区之间的动线，适合优先清理。"),
		_enemy(&"orbiter", "砂冠守卫", "生命 460 / 速度 116\n攻击：高速多段环形弹幕。\n掉落：砂冠花。\n说明：会压缩安全空间，是后期常规区域的高压敌人。"),
		_enemy(&"splitter", "裂根兽", "生命 240 / 速度 154\n攻击：短冷却快速冲锋。\n掉落：沙薯。\n说明：生命较低但节奏很快，容易打断采集和返程路线。"),
		_boss(&"sandworm_boss", "沙冠巨虫", TestItemDefs.SANDWORM_CORE_ID, TestItemDefs.DISH_SANDWORM_ROYAL_HEAT_PLATE_ID,
			"攻击：弹幕、地底尾刺、范围砸地与横向冲刺。\n机制：强化流沙；尾刺结束后会延迟留下小型流沙，别在原地逗留。\n应对：避开地面预警，给自己留出离开流沙的路线。击杀后，当天流沙机制暂停。"),
		_boss(&"scorpion_boss", "金甲蝎王", TestItemDefs.SCORPION_CLAW_ID, TestItemDefs.DISH_SCORPION_SUNPLATE_ID,
			"攻击：连续尾刺、近身横扫与跳跃砸地；跳砸命中会击退。\n机制：召来更多圣甲虫偷取食材；携带赃物逃走的甲虫会为蝎王回血。\n应对：兼顾战斗与食材防守，及时拦下携带食材的甲虫。击杀后，当天甲虫机制暂停。"),
		_boss(&"vulture_boss", "沙暴秃鹫", TestItemDefs.VULTURE_FEATHERHEART_ID, TestItemDefs.DISH_VULTURE_FEATHER_FEAST_ID,
			"攻击：蓄力小风暴、俯冲扑击与缓慢追踪的圆形风暴；圆形风暴会减速并持续伤害。\n机制：两格宽的大风暴会从视野外沿四个方向袭向料理区。风暴会吹飞玩家，撞上墙或设施会眩晕并受到高额伤害。\n应对：观察远处来风，避开沿途障碍。击杀后，当天风暴与风沙跳板暂停。"),
		_boss(&"monitor_boss", "沙宴巨蜥", TestItemDefs.MONITOR_TENDERLOIN_ID, TestItemDefs.DISH_MONITOR_ROYAL_BANQUET_ID,
			"攻击：近身咬击、扑击与冲刺。身后弱点承受更高伤害，可趁偷食、吐口水及技能后摇绕后攻击。\n献食：在料理区标记处放食材或菜品；半血后需准备两份。漏交会清空一个食材箱。食物收回嘴里后才会使其眩晕；品质越高，眩晕越久，菜品还会直接造成伤害。\n口水：设施被附着后无法取放物品，需及时读条修理。超时会摧毁台面食物，进入深度失控，倒计时结束后仍需修理；半血后封锁更久，烤物仍会烧糊。\n应对：提前献食并及时修理；白天可通过女神像传送到 BOSS 战斗区。")
	]

func _enemy(id: StringName, name: String, body: String) -> Dictionary:
	return {"id": id, "name": name, "body": body, "texture": ENEMY_TEXTURES.get(id, null)}

func _boss(id: StringName, name: String, ingredient_id: StringName, dish_id: StringName, mechanics: String) -> Dictionary:
	var body := "%s\n\n掉落：%s，需从战斗区自行搬回。\n专属料理：%s（完整配方见料理图鉴）。\n通关：击杀 BOSS 后，完成特殊客人的全部订单才算通关。" % [
		mechanics, TestItemDefs.get_item_display_name(ingredient_id), TestItemDefs.get_item_display_name(dish_id)
	]
	var entry := _enemy(id, "%s · BOSS" % name, body)
	entry["boss_ingredient_id"] = ingredient_id
	entry["boss_dish_id"] = dish_id
	return entry

func _get_ingredient_entries() -> Array[Dictionary]:
	return CodexCatalog.get_ingredient_entries()

func _get_dish_entries() -> Array[Dictionary]:
	return CodexCatalog.get_dish_entries(current_dish_category)

func _get_current_dish_category_name() -> String:
	for entry in CodexCatalog.get_dish_subcategories():
		if StringName(entry.get("id", &"")) == current_dish_category:
			return String(entry.get("name", "料理"))
	return "料理"

func _get_station_entries() -> Array[Dictionary]:
	var entries := CodexCatalog.get_purchasable_facility_entries()
	entries.insert(3, _station(&"assembly", "组合台", "把已处理的食材按配方组合成料理。取走完成的非酒水料理需要空盘子。"))
	return entries

func _station(id: StringName, name: String, body: String) -> Dictionary:
	return {"id": id, "name": name, "body": body, "texture": STATION_TEXTURES.get(id, null)}

func _style(bg: Color, border: Color, border_width: int, radius: int) -> StyleBoxFlat:
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
	preload("res://Scripts/UI/AtelierStyle.gd").finish(style, border.r > 0.9 and border.g > 0.65)
	return style

func _button_style(bg: Color, border: Color, border_width: int, radius: int, margin_left: int) -> StyleBoxFlat:
	var style := _style(bg, border, border_width, radius)
	style.content_margin_left = margin_left
	style.content_margin_right = 10
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	return style
