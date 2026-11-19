extends RefCounted

# Owns presentation nodes and the last rendered actions, never interaction state.
var interaction_button_prompt: Control
var last_prompt_actions: Array[Dictionary] = []

func setup(parent: Node) -> void:
	if not is_instance_valid(parent) or is_instance_valid(interaction_button_prompt):
		return
	var root := Control.new()
	root.name = "InteractionButtonPrompt"
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.visible = false
	root.z_index = 30
	root.position = Vector2(-58.0, -154.0)
	root.size = Vector2(116.0, 46.0)
	parent.add_child(root)
	interaction_button_prompt = root

func update_prompt(raw_text: String, bottom_row_y: float) -> void:
	if not is_instance_valid(interaction_button_prompt):
		return
	var actions: Array[Dictionary] = _parse_actions(raw_text)
	interaction_button_prompt.visible = not actions.is_empty()
	if actions != last_prompt_actions:
		last_prompt_actions = actions.duplicate(true)
		_rebuild_interaction_keycaps(actions, bottom_row_y)
	else:
		var prompt_y: float = bottom_row_y
		# Keep the bottom key anchored at prompt_y even while the key list is
		# unchanged; otherwise the container would jump back to a top-aligned
		# position every frame after a vertical stack was built.
		interaction_button_prompt.position.y = prompt_y - interaction_button_prompt.size.y + 38.0

func _rebuild_interaction_keycaps(actions: Array[Dictionary], bottom_row_y: float) -> void:
	if not is_instance_valid(interaction_button_prompt):
		return
	for child in interaction_button_prompt.get_children():
		interaction_button_prompt.remove_child(child)
		child.queue_free()
	if actions.is_empty():
		return

	var key_size := Vector2(42.0, 38.0)
	var spacing: float = 8.0
	var label_width: float = 76.0
	var label_gap: float = 8.0
	var total_width: float = key_size.x + label_gap + label_width
	var total_height: float = key_size.y * actions.size() + spacing * max(actions.size() - 1, 0)
	interaction_button_prompt.size = Vector2(total_width, total_height)
	var prompt_y: float = bottom_row_y
	# Keep the bottom key at the original anchor and stack additional actions
	# upward, so J is above K when both are available.
	interaction_button_prompt.position = Vector2(-total_width * 0.5, prompt_y - total_height + key_size.y)

	for i in range(actions.size()):
		var key: String = String(actions[i].get("key", ""))
		var action_text: String = String(actions[i].get("label", ""))
		var panel := Panel.new()
		panel.name = "Keycap_%s" % key
		panel.position = Vector2(0.0, float(i) * (key_size.y + spacing))
		panel.size = key_size
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.34, 0.34, 0.34, 0.96)
		style.border_color = Color(0.76, 0.76, 0.76, 1.0)
		style.border_width_left = 4
		style.border_width_top = 4
		style.border_width_right = 4
		style.border_width_bottom = 4
		style.corner_radius_top_left = 2
		style.corner_radius_top_right = 2
		style.corner_radius_bottom_left = 2
		style.corner_radius_bottom_right = 2
		style.shadow_color = Color(0.08, 0.08, 0.08, 0.8)
		style.shadow_size = 3
		style.shadow_offset = Vector2(3.0, 3.0)
		preload("res://Scripts/UI/AtelierStyle.gd").finish(style)
		style.set_corner_radius_all(5)
		style.shadow_size = 3
		panel.add_theme_stylebox_override("panel", style)
		interaction_button_prompt.add_child(panel)

		var label := Label.new()
		label.set_anchors_preset(Control.PRESET_FULL_RECT)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 22)
		label.modulate = Color(0.95, 0.95, 0.95, 1.0)
		label.text = key
		panel.add_child(label)

		var action_label := Label.new()
		action_label.name = "ActionLabel_%s" % key
		action_label.position = Vector2(key_size.x + label_gap, float(i) * (key_size.y + spacing))
		action_label.size = Vector2(label_width, key_size.y)
		action_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		action_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		action_label.add_theme_font_size_override("font_size", 22)
		action_label.add_theme_color_override("font_color", Color(0.98, 0.95, 0.86, 1.0))
		action_label.add_theme_color_override("font_outline_color", Color(0.08, 0.06, 0.05, 0.96))
		action_label.add_theme_constant_override("outline_size", 5)
		action_label.text = action_text
		interaction_button_prompt.add_child(action_label)

func _parse_actions(raw_text: String) -> Array[Dictionary]:
	var actions: Array[Dictionary] = []
	var normalized_text := raw_text.replace("+", "/").replace("、", "/")
	for raw_part in normalized_text.split("/", false):
		var tokens := String(raw_part).strip_edges().split(" ", false)
		if tokens.is_empty():
			continue
		var key := String(tokens[0]).strip_edges().to_upper()
		if key == "空格":
			key = "SPACE"
		elif key == "退出":
			key = "ESC"
		if key not in ["J", "K", "U", "I", "O", "L", "Q", "E", "W", "A", "S", "D", "SPACE", "ESC"]:
			continue
		var action_text := ""
		if tokens.size() > 1:
			action_text = " ".join(tokens.slice(1))
		action_text = _localize_prompt_action(action_text)
		var already_added := false
		for action in actions:
			if String(action.get("key", "")) == key:
				already_added = true
				break
		if not already_added:
			actions.append({"key": key, "label": action_text})
	return actions

func _localize_prompt_action(action_text: String) -> String:
	match action_text.strip_edges().to_upper():
		"TAKE": return "拿起"
		"PLACE", "STORE": return "放下"
		"MOVE": return "搬起"
		"COOK": return "加工"
		"ORDER": return "接单"
		"SERVE": return "上菜"
		"ASSEMBLE": return "组合"
		"TASK": return "任务"
		"FORAGE", "HARVEST", "HOLD": return "采集"
		_: return action_text

