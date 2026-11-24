extends Node

const RunProgressionState = preload("res://Scripts/Core/RunProgressionState.gd")
const TestItemDefs = preload("res://Scripts/Kitchen/TestItemDefs.gd")
const LevelContext = preload("res://Scripts/Core/LevelContext.gd")
const DailySettlementPanel = preload("res://Scripts/UI/DailySettlementPanel.gd")

var overlay_layer: CanvasLayer
var overlay_root: Control
var settlement_panel: DailySettlementPanel
var transition_layer: CanvasLayer
var transition_shade: ColorRect
var overlay_panel: Panel
var overlay_content: VBoxContainer
var overlay_title_label: Label
var overlay_body_label: Label
var overlay_hint_label: Label
var debug_label: Label
var blessing_timer_label: Label
var blessing_timer_bar_frame: ColorRect
var blessing_timer_bar_fill: ColorRect
var blessing_cards_root: HBoxContainer
var cards_scroll: ScrollContainer
var blessing_card_panels: Array[Panel] = []
var card_mouse_entered: Callable
var card_mouse_exited: Callable
var card_gui_input: Callable
var shop_root: VBoxContainer
var shop_category_tabs: HBoxContainer
var shop_scroll: ScrollContainer
var shop_item_list: GridContainer
var toast_layer: CanvasLayer
var toast_label: Label
var toast_time_remaining: float = 0.0

func build_overlay(
	mouse_entered_handler: Callable,
	mouse_exited_handler: Callable,
	gui_input_handler: Callable,
	card_count: int = 3
) -> void:
	if overlay_layer != null:
		return

	overlay_layer = CanvasLayer.new()
	overlay_layer.layer = 60
	overlay_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(overlay_layer)

	overlay_root = Control.new()
	overlay_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay_root.process_mode = Node.PROCESS_MODE_ALWAYS
	overlay_layer.add_child(overlay_root)

	transition_layer = CanvasLayer.new()
	transition_layer.layer = 100
	transition_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(transition_layer)
	transition_shade = ColorRect.new()
	transition_shade.color = Color.BLACK
	transition_shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	transition_shade.mouse_filter = Control.MOUSE_FILTER_STOP
	transition_shade.process_mode = Node.PROCESS_MODE_ALWAYS
	transition_layer.add_child(transition_shade)
	transition_layer.visible = false

	var shade := ColorRect.new()
	shade.color = Color(0.03, 0.04, 0.05, 0.82)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay_root.add_child(shade)

	overlay_panel = Panel.new()
	overlay_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay_root.add_child(overlay_panel)

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.12, 0.14, 0.18, 0.96)
	panel_style.border_color = Color(0.88, 0.78, 0.46, 1.0)
	panel_style.border_width_left = 3
	panel_style.border_width_top = 3
	panel_style.border_width_right = 3
	panel_style.border_width_bottom = 3
	panel_style.corner_radius_top_left = 10
	panel_style.corner_radius_top_right = 10
	panel_style.corner_radius_bottom_left = 10
	panel_style.corner_radius_bottom_right = 10
	preload("res://Scripts/UI/AtelierStyle.gd").finish(panel_style)
	overlay_panel.add_theme_stylebox_override("panel", panel_style)

	overlay_content = VBoxContainer.new()
	overlay_content.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay_panel.add_child(overlay_content)

	overlay_title_label = Label.new()
	overlay_content.add_child(overlay_title_label)

	overlay_body_label = Label.new()
	overlay_body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	overlay_content.add_child(overlay_body_label)

	overlay_hint_label = Label.new()
	overlay_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	overlay_hint_label.modulate = Color(0.92, 0.86, 0.64, 1.0)
	overlay_content.add_child(overlay_hint_label)

	blessing_timer_label = Label.new()
	blessing_timer_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	blessing_timer_label.offset_top = 18.0
	blessing_timer_label.offset_bottom = 84.0
	blessing_timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	blessing_timer_label.add_theme_font_size_override("font_size", 44)
	blessing_timer_label.modulate = Color(1.0, 0.9, 0.42, 1.0)
	blessing_timer_label.visible = false
	overlay_root.add_child(blessing_timer_label)

	blessing_timer_bar_frame = ColorRect.new()
	blessing_timer_bar_frame.set_anchors_preset(Control.PRESET_TOP_WIDE)
	blessing_timer_bar_frame.offset_left = 240.0
	blessing_timer_bar_frame.offset_top = 86.0
	blessing_timer_bar_frame.offset_right = -240.0
	blessing_timer_bar_frame.offset_bottom = 104.0
	blessing_timer_bar_frame.color = Color(0.12, 0.14, 0.18, 0.96)
	blessing_timer_bar_frame.visible = false
	overlay_root.add_child(blessing_timer_bar_frame)

	blessing_timer_bar_fill = ColorRect.new()
	blessing_timer_bar_fill.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	blessing_timer_bar_fill.offset_left = 0.0
	blessing_timer_bar_fill.offset_top = 0.0
	blessing_timer_bar_fill.offset_right = 0.0
	blessing_timer_bar_fill.offset_bottom = 0.0
	blessing_timer_bar_fill.color = Color(1.0, 0.86, 0.32, 1.0)
	blessing_timer_bar_frame.add_child(blessing_timer_bar_fill)

	cards_scroll = ScrollContainer.new()
	cards_scroll.process_mode = Node.PROCESS_MODE_ALWAYS
	cards_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cards_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cards_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	cards_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	cards_scroll.gui_input.connect(_on_cards_scroll_input)
	overlay_content.add_child(cards_scroll)
	blessing_cards_root = HBoxContainer.new()
	blessing_cards_root.process_mode = Node.PROCESS_MODE_ALWAYS
	blessing_cards_root.alignment = BoxContainer.ALIGNMENT_CENTER
	blessing_cards_root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	blessing_cards_root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	blessing_cards_root.add_theme_constant_override("separation", 24 if card_count > 3 else 42)
	blessing_cards_root.visible = false
	cards_scroll.add_child(blessing_cards_root)
	blessing_cards_root.visibility_changed.connect(func() -> void: cards_scroll.visible = blessing_cards_root.visible)
	cards_scroll.visible = false
	card_mouse_entered = mouse_entered_handler
	card_mouse_exited = mouse_exited_handler
	card_gui_input = gui_input_handler
	ensure_card_count(card_count)

	shop_root = VBoxContainer.new()
	shop_root.process_mode = Node.PROCESS_MODE_ALWAYS
	shop_root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shop_root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	shop_root.add_theme_constant_override("separation", 12)
	shop_root.visible = false
	overlay_content.add_child(shop_root)

	shop_category_tabs = HBoxContainer.new()
	shop_category_tabs.process_mode = Node.PROCESS_MODE_ALWAYS
	shop_category_tabs.alignment = BoxContainer.ALIGNMENT_BEGIN
	shop_category_tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shop_category_tabs.add_theme_constant_override("separation", 12)
	shop_root.add_child(shop_category_tabs)

	shop_scroll = ScrollContainer.new()
	shop_scroll.process_mode = Node.PROCESS_MODE_ALWAYS
	shop_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shop_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	shop_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	shop_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_ALWAYS
	shop_root.add_child(shop_scroll)

	var shop_grid_margin := MarginContainer.new()
	shop_grid_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shop_grid_margin.add_theme_constant_override("margin_right", 24)
	shop_scroll.add_child(shop_grid_margin)

	shop_item_list = GridContainer.new()
	shop_item_list.process_mode = Node.PROCESS_MODE_ALWAYS
	shop_item_list.columns = 3
	shop_item_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shop_item_list.add_theme_constant_override("h_separation", 15)
	shop_item_list.add_theme_constant_override("v_separation", 15)
	shop_grid_margin.add_child(shop_item_list)

	debug_label = Label.new()
	debug_label.visible = OS.get_cmdline_user_args().has("--debug-ui")
	debug_label.position = Vector2(24.0, 24.0)
	debug_label.size = Vector2(620.0, 240.0)
	debug_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	debug_label.add_theme_font_size_override("font_size", 18)
	debug_label.modulate = Color(0.94, 0.95, 0.97, 1.0)
	overlay_root.add_child(debug_label)

	toast_layer = CanvasLayer.new()
	toast_layer.layer = 120
	toast_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(toast_layer)
	toast_label = Label.new()
	toast_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	toast_label.offset_top = 850.0
	toast_label.offset_bottom = 1015.0
	toast_label.offset_left = 260.0
	toast_label.offset_right = -260.0
	toast_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	toast_label.add_theme_font_size_override("font_size", 25)
	toast_label.add_theme_color_override("font_outline_color", Color("3b3930"))
	toast_label.add_theme_constant_override("outline_size", 5)
	toast_label.modulate = Color(1.0, 0.91, 0.52, 1.0)
	toast_label.visible = false
	toast_layer.add_child(toast_label)

	settlement_panel = DailySettlementPanel.new()
	overlay_root.add_child(settlement_panel)
	settlement_panel.hide()
	set_layout_mode(false)
	set_overlay_visible(false)

func _process(delta: float) -> void:
	if toast_time_remaining <= 0.0:
		return
	toast_time_remaining = maxf(toast_time_remaining - delta, 0.0)
	if toast_time_remaining <= 0.0 and toast_label != null:
		toast_label.visible = false

func ensure_card_count(count: int) -> void:
	for i in range(blessing_card_panels.size(), count):
		var card := Panel.new()
		card.process_mode = Node.PROCESS_MODE_ALWAYS
		card.mouse_filter = Control.MOUSE_FILTER_STOP
		card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		card.custom_minimum_size = Vector2(300.0, 420.0) if count > 3 else Vector2(360.0, 420.0)
		blessing_cards_root.add_child(card)
		blessing_card_panels.append(card)
		card.mouse_entered.connect(card_mouse_entered.bind(i))
		card.mouse_exited.connect(card_mouse_exited.bind(i))
		card.gui_input.connect(card_gui_input.bind(i))

func _on_cards_scroll_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN] and cards_scroll.get_h_scroll_bar().max_value > cards_scroll.size.x:
		cards_scroll.scroll_horizontal += -160 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 160
		cards_scroll.accept_event()

func show_toast(message: String, duration: float = 2.5) -> void:
	if toast_label == null:
		return
	toast_label.text = message
	toast_time_remaining = maxf(duration, 0.1)
	toast_label.visible = true

func hide_toast() -> void:
	toast_time_remaining = 0.0
	if toast_label != null:
		toast_label.visible = false

func get_title_label() -> Label:
	return overlay_title_label

func get_body_label() -> Label:
	return overlay_body_label

func get_hint_label() -> Label:
	return overlay_hint_label

func get_blessing_timer_label() -> Label:
	return blessing_timer_label

func get_blessing_timer_bar_frame() -> ColorRect:
	return blessing_timer_bar_frame

func get_blessing_timer_bar_fill() -> ColorRect:
	return blessing_timer_bar_fill

func get_blessing_cards_root() -> HBoxContainer:
	return blessing_cards_root

func get_blessing_card_panels() -> Array[Panel]:
	return blessing_card_panels

func get_shop_root() -> VBoxContainer:
	return shop_root

func get_shop_category_tabs() -> HBoxContainer:
	return shop_category_tabs

func get_shop_scroll() -> ScrollContainer:
	return shop_scroll

func get_shop_item_list() -> GridContainer:
	return shop_item_list

func set_blessing_overlay_visible(visible: bool) -> void:
	if blessing_timer_label != null:
		blessing_timer_label.visible = visible
	if blessing_timer_bar_frame != null:
		blessing_timer_bar_frame.visible = visible
	if blessing_cards_root != null:
		blessing_cards_root.visible = visible
		blessing_cards_root.size_flags_vertical = Control.SIZE_EXPAND_FILL if visible else 0
	if shop_root != null:
		shop_root.visible = false

func set_layout_mode(is_selection_layout: bool) -> void:
	if overlay_panel == null or overlay_content == null:
		return
	if settlement_panel != null:
		settlement_panel.hide()
	overlay_panel.show()
	if cards_scroll != null:
		cards_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
		cards_scroll.scroll_horizontal = 0
		cards_scroll.scroll_vertical = 0
	overlay_body_label.visible = true

	if is_selection_layout:
		overlay_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
		overlay_panel.offset_left = 72.0
		overlay_panel.offset_top = 110.0
		overlay_panel.offset_right = -72.0
		overlay_panel.offset_bottom = -80.0
		overlay_content.offset_left = 36.0
		overlay_content.offset_top = 34.0
		overlay_content.offset_right = -36.0
		overlay_content.offset_bottom = -34.0
		overlay_content.alignment = BoxContainer.ALIGNMENT_CENTER
		overlay_content.add_theme_constant_override("separation", 28)
		overlay_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		overlay_title_label.add_theme_font_size_override("font_size", 44)
		overlay_body_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		overlay_body_label.add_theme_font_size_override("font_size", 24)
		overlay_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		overlay_hint_label.add_theme_font_size_override("font_size", 20)
	else:
		overlay_panel.set_anchors_preset(Control.PRESET_CENTER)
		overlay_panel.custom_minimum_size = Vector2(720.0, 260.0)
		overlay_panel.size = Vector2(720.0, 260.0)
		overlay_panel.position = Vector2(-360.0, -130.0)
		overlay_panel.offset_left = 0.0
		overlay_panel.offset_top = 0.0
		overlay_panel.offset_right = 0.0
		overlay_panel.offset_bottom = 0.0
		overlay_content.offset_left = 28.0
		overlay_content.offset_top = 24.0
		overlay_content.offset_right = -28.0
		overlay_content.offset_bottom = -24.0
		overlay_content.alignment = BoxContainer.ALIGNMENT_BEGIN
		overlay_content.add_theme_constant_override("separation", 12)
		overlay_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		overlay_title_label.add_theme_font_size_override("font_size", 28)
		overlay_body_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		overlay_body_label.add_theme_font_size_override("font_size", 20)
		overlay_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		overlay_hint_label.add_theme_font_size_override("font_size", 18)

func set_shop_layout() -> void:
	# About 85% of the previous shop footprint, with two complete product rows.
	toast_time_remaining = 0.0
	if toast_label != null:
		toast_label.hide()
	overlay_panel.offset_left = 185.0
	overlay_panel.offset_right = -185.0
	overlay_panel.offset_top = 115.0
	overlay_panel.offset_bottom = -115.0
	overlay_content.offset_left = 30.0
	overlay_content.offset_right = -30.0
	overlay_content.offset_top = 20.0
	overlay_content.offset_bottom = -20.0
	overlay_content.alignment = BoxContainer.ALIGNMENT_BEGIN
	overlay_content.add_theme_constant_override("separation", 10)
	overlay_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	overlay_title_label.add_theme_font_size_override("font_size", 34)
	overlay_body_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	overlay_body_label.add_theme_font_size_override("font_size", 21)
	overlay_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	overlay_hint_label.add_theme_font_size_override("font_size", 20)

func set_overlay_visible(visible: bool) -> void:
	if overlay_layer != null:
		overlay_layer.visible = visible

func set_transition_visible(visible: bool) -> void:
	if transition_layer != null:
		transition_layer.visible = visible

func show_result(success: bool, message: String, run_context: LevelContext, progression_state: Object = null, notice: String = "") -> void:
	set_blessing_overlay_visible(false)
	set_overlay_visible(true)
	overlay_panel.hide()
	debug_label.hide()
	settlement_panel.present(success, message, run_context, progression_state, notice)

func set_debug_text(text: String) -> void:
	if debug_label != null:
		debug_label.text = text

func update_debug_status(run_context: LevelContext, progression_state: RunProgressionState, selected_group_name: String, prepare_time_remaining: float, wave_break_time_remaining: float) -> void:
	var lines: Array[String] = []
	lines.append("状态：%s" % _get_state_name(run_context.state if run_context != null else LevelContext.LevelState.ORDER_GROUP_SELECT))

	if run_context == null:
		lines.append("已选订单组：%s" % selected_group_name)
		set_debug_text("\n".join(lines))
		return

	lines.append("天数：%d" % progression_state.day_index)
	lines.append("订单组：%s" % run_context.get_selected_group_name())
	lines.append("波次：%d / %d" % [run_context.current_wave_index + 1, max(run_context.get_waves().size(), 1)])
	lines.append("订单总数：%d" % run_context.get_total_order_count())
	lines.append("完成：%d    失败：%d" % [run_context.completed_orders, run_context.failed_orders])
	lines.append("金币：%d    经验：%d    等级：%d" % [progression_state.gold, progression_state.xp, progression_state.level])
	lines.append("声望：%d / %d" % [run_context.reputation, run_context.reputation_max])
	if run_context.state == LevelContext.LevelState.PREPARE_PHASE:
		lines.append("准备时间：%.1f 秒" % prepare_time_remaining)
	if run_context.state == LevelContext.LevelState.WAVE_BREAK:
		lines.append("波间休整：%.1f 秒" % wave_break_time_remaining)
	if run_context.state == LevelContext.LevelState.NIGHT_REST:
		lines.append("夜间休整中：商人与任务书可用")
	if run_context.state == LevelContext.LevelState.NIGHT_SHOP:
		lines.append("夜间商店已开启")
		lines.append("可用金币：%d" % progression_state.gold)
	if run_context.state == LevelContext.LevelState.MENU_DISH_SELECT:
		lines.append("Menu update")
		lines.append("Current menu: %s" % ", ".join(_stringify_id_list(progression_state.get_menu_dish_ids())))
	if run_context.danger_active:
		lines.append("声望偏低；归零时营业失败")
	set_debug_text("\n".join(lines))

func _get_state_name(state_value: int) -> String:
	match state_value:
		LevelContext.LevelState.OUT_OF_LEVEL:
			return "OUT_OF_LEVEL"
		LevelContext.LevelState.NIGHT_REST:
			return "NIGHT_REST"
		LevelContext.LevelState.NIGHT_SHOP:
			return "NIGHT_SHOP"
		LevelContext.LevelState.NIGHT_PLANNING:
			return "NIGHT_PLANNING"
		LevelContext.LevelState.ORDER_GROUP_SELECT:
			return "ORDER_GROUP_SELECT"
		LevelContext.LevelState.MENU_DISH_SELECT:
			return "MENU_DISH_SELECT"
		LevelContext.LevelState.PREPARE_PHASE:
			return "PREPARE_PHASE"
		LevelContext.LevelState.WAVE_ACTIVE:
			return "WAVE_ACTIVE"
		LevelContext.LevelState.WAVE_BREAK:
			return "WAVE_BREAK"
		LevelContext.LevelState.BLESSING_SELECT:
			return "BLESSING_SELECT"
		LevelContext.LevelState.GLOBAL_MODIFIER_SELECT:
			return "GLOBAL_MODIFIER_SELECT"
		LevelContext.LevelState.LEVEL_SUCCESS:
			return "LEVEL_SUCCESS"
		LevelContext.LevelState.LEVEL_FAILED:
			return "LEVEL_FAILED"
		_:
			return "UNKNOWN"

func _stringify_id_list(values: Variant) -> Array[String]:
	var result: Array[String] = []
	if values is Array:
		for value in values:
			var item_id: StringName = StringName(value)
			result.append(TestItemDefs.get_item_display_name(item_id))
	return result

