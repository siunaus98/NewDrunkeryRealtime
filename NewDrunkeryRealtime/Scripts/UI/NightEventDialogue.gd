extends CanvasLayer

signal choice_selected(index: int)
signal dialogue_closed

var title_label: Label
var body_label: Label
var hint_label: Label
var portrait: TextureRect
var choice_list: VBoxContainer
var scroll: ScrollContainer
var rows: Array[Button] = []
var selected_index: int = 0
var last_confirm_frame: int = -1
var resize_pending: bool = false

func _ready() -> void:
	layer = 70
	process_mode = Node.PROCESS_MODE_ALWAYS
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	var shade := ColorRect.new()
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.04, 0.03, 0.02, 0.68)
	root.add_child(shade)
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = 230
	panel.offset_top = 140
	panel.offset_right = -230
	panel.offset_bottom = -130
	var style := StyleBoxFlat.new()
	style.bg_color = Color("302c29")
	style.border_color = Color("bfa16e")
	style.set_border_width_all(4)
	style.set_corner_radius_all(14)
	preload("res://Scripts/UI/AtelierStyle.gd").finish(style)
	panel.add_theme_stylebox_override("panel", style)
	root.add_child(panel)
	var margin := MarginContainer.new()
	for edge: String in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 30)
	panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 18)
	margin.add_child(column)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 28)
	column.add_child(header)
	portrait = TextureRect.new()
	portrait.custom_minimum_size = Vector2(120, 152)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	header.add_child(portrait)
	var speech := VBoxContainer.new()
	speech.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(speech)
	title_label = _label(34)
	title_label.modulate = Color("ffe1a0")
	speech.add_child(title_label)
	body_label = _label(25)
	speech.add_child(body_label)
	scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	choice_list = VBoxContainer.new()
	choice_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	choice_list.add_theme_constant_override("separation", 12)
	scroll.add_child(choice_list)
	hint_label = _label(20)
	hint_label.text = "W/S：选择    J/空格：确认    K：关闭对话（不拒绝交易）"
	hint_label.modulate = Color("d5c5a9")
	column.add_child(hint_label)
	visible = false

func show_page(title: String, body: String, id: StringName, options: Array[Dictionary]) -> void:
	title_label.text = title
	body_label.text = body
	portrait.texture = load("res://ArtResource/Events/%s.svg" % id)
	for child: Node in choice_list.get_children():
		child.free()
	rows.clear()
	selected_index = -1
	for index in range(options.size()):
		var option: Dictionary = options[index]
		var button := Button.new()
		button.custom_minimum_size.y = 104
		button.focus_mode = Control.FOCUS_NONE
		button.disabled = bool(option.get("disabled", false))
		button.pressed.connect(_confirm.bind(index))
		var margin := MarginContainer.new()
		margin.set_anchors_preset(Control.PRESET_FULL_RECT)
		margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
		for edge: String in ["left", "top", "right", "bottom"]:
			margin.add_theme_constant_override("margin_" + edge, 12)
		button.add_child(margin)
		var label := _label(25)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.text = "%s\n%s" % [option.text, option.get("detail", "")]
		margin.add_child(label)
		label.minimum_size_changed.connect(_queue_choice_resize)
		label.resized.connect(_queue_choice_resize)
		choice_list.add_child(button)
		rows.append(button)
		_queue_choice_resize()
	visible = true
	scroll.scroll_vertical = 0
	_move_selection(1)

func handle_action(action: int) -> void:
	var actions = preload("res://Scripts/Core/LevelFlowInputAdapter.gd").Action
	if action == actions.CANCEL:
		dialogue_closed.emit()
	elif action in [actions.UP, actions.LEFT]:
		_move_selection(-1)
	elif action in [actions.DOWN, actions.RIGHT]:
		_move_selection(1)
	elif action == actions.CONFIRM:
		_confirm(selected_index)

func _move_selection(direction: int) -> void:
	var candidate: int = selected_index
	for step in range(rows.size()):
		candidate = wrapi(candidate + direction, 0, rows.size())
		if not rows[candidate].disabled:
			selected_index = candidate
			_refresh_selection()
			return
	selected_index = -1
	_refresh_selection()

func _confirm(index: int) -> void:
	if index < 0 or index >= rows.size() or rows[index].disabled or last_confirm_frame == Engine.get_process_frames():
		return
	last_confirm_frame = Engine.get_process_frames()
	choice_selected.emit(index)

func _refresh_selection() -> void:
	for index in range(rows.size()):
		var style := StyleBoxFlat.new()
		style.bg_color = Color("5b4b36") if index == selected_index else Color("3d3934")
		style.border_color = Color("f2cf83") if index == selected_index else Color("75654e")
		style.set_border_width_all(3)
		style.set_corner_radius_all(6)
		preload("res://Scripts/UI/AtelierStyle.gd").finish(style, index == selected_index)
		rows[index].add_theme_stylebox_override("normal", style)
	if not rows.is_empty():
		_ensure_selected_visible.call_deferred()

func _ensure_selected_visible() -> void:
	if selected_index >= 0 and selected_index < rows.size() and is_instance_valid(rows[selected_index]) and scroll.is_ancestor_of(rows[selected_index]):
		scroll.ensure_control_visible(rows[selected_index])

func _queue_choice_resize() -> void:
	if resize_pending:
		return
	resize_pending = true
	_resize_choices.call_deferred()

func _resize_choices() -> void:
	resize_pending = false
	for button: Button in rows:
		var label := button.get_child(0).get_child(0) as Label
		button.custom_minimum_size.y = maxf(104, label.get_minimum_size().y + 28)

func _label(font_size: int) -> Label:
	var label := Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	return label
