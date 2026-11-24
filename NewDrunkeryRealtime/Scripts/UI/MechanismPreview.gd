extends HBoxContainer

# Use the actual gameplay drawing code, frozen in representative states.
# Samples never process, collide or remain in gameplay query groups.
func show_mechanism(id: StringName) -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	visible = id != &""
	add_theme_constant_override("separation", 18)
	match id:
		&"scarab":
			for escaping: bool in [false, true]:
				var scarab := preload("res://Scripts/Enemies/ScarabEnemy.gd").new()
				_add_sample(scarab, "逃跑中 · 红条" if escaping else "偷取中 · 黄条", 1.0)
				scarab.state = scarab.State.ESCAPING if escaping else scarab.State.STEALING
				scarab.action_duration = 10.0
				scarab.action_remaining = 4.0
				scarab.escape_remaining = scarab.escape_duration * 0.4
				scarab.queue_redraw()
		&"sandstorm":
			for ready: bool in [false, true]:
				var pad := preload("res://Scripts/Hazards/WindSandPad.gd").new()
				pad.configure_direction(0)
				_add_sample(pad, "黄色 · 踩上弹射" if ready else "蓝色 · 即将出现", 0.9)
				pad.state = pad.State.READY if ready else pad.State.BLUE_WARNING
				pad.queue_redraw()
		&"quicksand":
			for active: bool in [false, true]:
				var sand := preload("res://Scripts/Hazards/QuicksandHazard.gd").new()
				_add_sample(sand, "流沙 · 深色中心危险" if active else "金色圆圈 · 地面预警", 0.25)
				sand.warning_remaining = 0.0 if active else sand.warning_duration * 0.5
				sand.lifetime_remaining = 4.0
				sand.queue_redraw()

func _add_sample(sample: Node2D, caption: String, sample_scale: float) -> void:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var style := StyleBoxFlat.new()
	style.bg_color = Color("6b6148")
	style.border_color = Color("b9a375")
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	panel.add_child(column)
	var stage := Control.new()
	stage.custom_minimum_size = Vector2(0, 180)
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(stage)
	sample.process_mode = Node.PROCESS_MODE_DISABLED
	if sample is CollisionObject2D:
		sample.collision_layer = 0
		sample.collision_mask = 0
	sample.scale = Vector2.ONE * sample_scale
	stage.add_child(sample)
	for group: StringName in sample.get_groups():
		sample.remove_from_group(group)
	stage.resized.connect(func() -> void: sample.position = stage.size * 0.5 + Vector2(0, 12))
	var label := Label.new()
	label.text = caption
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 23)
	label.add_theme_color_override("font_color", Color("fff1cc"))
	column.add_child(label)
