extends CanvasLayer

signal finished
const MINIMUM_SECONDS := 3.0
var cards: Array[Dictionary] = []
var index := 0
var elapsed := 0.0
var previous_pause := false
var heading: Label
var body: Label
var hint: Label
var icon: TextureRect
var page: Label

func _ready() -> void:
	layer = 125
	process_mode = Node.PROCESS_MODE_ALWAYS
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	var shade := ColorRect.new()
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.color = Color("101b21ed")
	root.add_child(shade)
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = 180
	panel.offset_right = -180
	panel.offset_top = 110
	panel.offset_bottom = -110
	panel.add_theme_stylebox_override("panel", preload("res://Scripts/UI/AtelierStyle.gd").panel())
	root.add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 38)
	panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 22)
	margin.add_child(column)
	page = _label(22)
	column.add_child(page)
	heading = _label(42)
	column.add_child(heading)
	var row := HBoxContainer.new()
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 50)
	column.add_child(row)
	icon = TextureRect.new()
	icon.custom_minimum_size = Vector2(330, 330)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(icon)
	body = _label(28)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(body)
	hint = _label(24)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(hint)
	hide()

func _label(font_size: int) -> Label:
	var label := Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color("f3e7cb"))
	return label

func open(entries: Array[Dictionary]) -> void:
	if entries.is_empty():
		finished.emit()
		queue_free()
		return
	cards = entries.duplicate(true)
	index = 0
	previous_pause = get_tree().paused
	get_tree().paused = true
	show()
	_show_card()

func _show_card() -> void:
	elapsed = 0.0
	page.text = "营业前说明  ·  %d / %d" % [index + 1, cards.size()]
	heading.text = String(cards[index].get("title", "今日提示"))
	body.text = String(cards[index].get("body", ""))
	var path := String(cards[index].get("image", ""))
	icon.texture = load(path) if not path.is_empty() else null
	_update_hint()

func _process(delta: float) -> void:
	if visible:
		elapsed += maxf(delta, 0.0)
		_update_hint()

func _update_hint() -> void:
	hint.text = "请先阅读 · %d 秒后可继续" % ceili(MINIMUM_SECONDS - elapsed) if elapsed < MINIMUM_SECONDS else "按任意键继续"

func _input(event: InputEvent) -> void:
	if not visible:
		return
	get_viewport().set_input_as_handled()
	if elapsed < MINIMUM_SECONDS or event.is_echo():
		return
	if event is InputEventKey and event.pressed:
		if event.keycode in [KEY_SHIFT, KEY_CTRL, KEY_ALT, KEY_META]:
			return
		advance()
	elif event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
		advance()

func advance() -> void:
	if not visible or elapsed < MINIMUM_SECONDS:
		return
	index += 1
	if index < cards.size():
		_show_card()
		return
	hide()
	get_tree().paused = previous_pause
	for player: Node in get_tree().get_nodes_in_group("player"):
		if player.has_method("suppress_action_inputs_until_release"):
			player.suppress_action_inputs_until_release()
	finished.emit()
	queue_free()
