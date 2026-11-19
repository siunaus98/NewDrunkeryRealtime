extends CanvasLayer

const AudioCue = preload("res://Scripts/Audio/AudioCue.gd")

signal cancelled

var buttons: Array[Button] = []
var selected_index: int = 0

func setup(new_buttons: Array[Button]) -> void:
	buttons = new_buttons
	for index in range(buttons.size()):
		buttons[index].focus_mode = Control.FOCUS_NONE
		buttons[index].mouse_entered.connect(select.bind(index))
	select(0)

func select(index: int) -> void:
	if buttons.is_empty():
		return
	selected_index = wrapi(index, 0, buttons.size())
	for button_index in range(buttons.size()):
		var style := StyleBoxFlat.new()
		style.bg_color = Color("5b4b36") if button_index == selected_index else Color("302c29")
		style.border_color = Color("f2cf83") if button_index == selected_index else Color("75654e")
		style.set_border_width_all(3)
		style.set_corner_radius_all(6)
		preload("res://Scripts/UI/AtelierStyle.gd").finish(style, button_index == selected_index)
		buttons[button_index].add_theme_stylebox_override("normal", style)
		buttons[button_index].add_theme_stylebox_override("hover", style)

func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_echo():
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_cancel") or _key(event, KEY_K):
		get_viewport().set_input_as_handled()
		cancelled.emit()
	elif event.is_action_pressed("move_up") or event.is_action_pressed("move_left") or event.is_action_pressed("ui_up") or event.is_action_pressed("ui_left"):
		get_viewport().set_input_as_handled()
		AudioCue.play_ui(&"ui_move")
		select(selected_index - 1)
	elif event.is_action_pressed("move_down") or event.is_action_pressed("move_right") or event.is_action_pressed("ui_down") or event.is_action_pressed("ui_right"):
		get_viewport().set_input_as_handled()
		AudioCue.play_ui(&"ui_move")
		select(selected_index + 1)
	elif event.is_action_pressed("ui_confirm") or _key(event, KEY_SPACE) or _key(event, KEY_J):
		get_viewport().set_input_as_handled()
		if not buttons.is_empty():
			buttons[selected_index].pressed.emit()

func _key(event: InputEvent, key: Key) -> bool:
	return event is InputEventKey and event.pressed and (event.keycode == key or event.physical_keycode == key)
