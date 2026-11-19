class_name SkillCooldownSlot

extends Control

@export var slot_size: Vector2 = Vector2(92.0, 92.0)
@export var icon_radius: float = 23.0
@export var icon_color: Color = Color(0.14, 0.16, 0.2, 0.95)
@export var ready_ring_color: Color = Color(0.44, 0.88, 1.0, 0.95)
@export var cooldown_ring_color: Color = Color(1.0, 0.75, 0.22, 0.95)
@export var ring_background_color: Color = Color(0.08, 0.1, 0.12, 0.82)
@export var key_label_text: String = "U"
@export var key_label_color: Color = Color(0.94, 0.96, 0.98, 1.0)
@export var key_label_bg_color: Color = Color(0.08, 0.09, 0.11, 0.86)
@export var key_label_border_color: Color = Color(0.72, 0.78, 0.84, 0.65)
@export var number_color: Color = Color(0.96, 0.96, 0.92, 1.0)
@export var ready_text: String = "READY"
@export var cooldown_precision: int = 1
@export var show_remaining_number: bool = true

var skill_icon: Control
var cooldown_label: Label
var cost_label: Label
var key_badge: Panel
var key_label: Label
var progress: float = 1.0
var remaining_seconds: float = 0.0
var magic_cost: int = 0
var energy_mode: bool = false

func _ready() -> void:
	custom_minimum_size = slot_size
	size = slot_size
	_build_ui()
	if energy_mode:
		set_energy_state(progress, remaining_seconds)
	else:
		set_slot_state(progress, remaining_seconds)
	queue_redraw()

func set_slot_state(cooldown_progress: float, remaining_time: float, new_key_label: String = "") -> void:
	progress = clampf(cooldown_progress, 0.0, 1.0)
	remaining_seconds = maxf(remaining_time, 0.0)
	if new_key_label != "":
		key_label_text = new_key_label
	if key_label != null:
		key_label.text = key_label_text
	if cooldown_label != null:
		if not show_remaining_number:
			cooldown_label.text = ready_text if progress >= 1.0 else ""
			cooldown_label.modulate = _ready_text_color() if progress >= 1.0 else Color(1.0, 1.0, 1.0, 0.0)
		elif progress >= 1.0:
			cooldown_label.text = ready_text
			cooldown_label.modulate = _ready_text_color()
		else:
			cooldown_label.text = _format_remaining_time(remaining_seconds)
			cooldown_label.modulate = number_color
	queue_redraw()

func set_key_label(new_key_label: String) -> void:
	key_label_text = new_key_label
	if key_label != null:
		key_label.text = key_label_text
	queue_redraw()

func set_energy_state(energy_progress: float, buff_remaining: float) -> void:
	set_slot_state(energy_progress, 0.0, "I")
	if cooldown_label != null:
		cooldown_label.text = ("%.1f 秒" % buff_remaining) if buff_remaining > 0.0 else ("可释放" if progress >= 1.0 else "%d%%" % int(progress * 100.0))
	if cost_label != null:
		cost_label.text = "能量"

func set_magic_cost(cost: int) -> void:
	magic_cost = maxi(cost, 0)
	if cost_label != null:
		cost_label.text = "魔力 %d" % magic_cost

func _build_ui() -> void:
	var bg := Panel.new()
	bg.show_behind_parent = true
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	var style := StyleBoxFlat.new()
	style.bg_color = ring_background_color
	style.border_color = Color(0.98, 0.98, 0.98, 0.08)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 18
	style.corner_radius_top_right = 18
	style.corner_radius_bottom_left = 18
	style.corner_radius_bottom_right = 18
	preload("res://Scripts/UI/AtelierStyle.gd").finish(style)
	bg.add_theme_stylebox_override("panel", style)
	add_child(bg)

	skill_icon = Control.new()
	skill_icon.position = Vector2((slot_size.x - icon_radius * 2.0) * 0.5, 10.0)
	skill_icon.size = Vector2(icon_radius * 2.0, icon_radius * 2.0)
	add_child(skill_icon)

	cooldown_label = Label.new()
	cooldown_label.position = Vector2(0.0, 52.0)
	cooldown_label.size = Vector2(slot_size.x, 18.0)
	cooldown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cooldown_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cooldown_label.add_theme_font_size_override("font_size", 15)
	cooldown_label.modulate = number_color
	add_child(cooldown_label)

	cost_label = Label.new()
	cost_label.position = Vector2(38.0, slot_size.y - 20.0)
	cost_label.size = Vector2(slot_size.x - 38.0, 20.0)
	cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	cost_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cost_label.add_theme_font_size_override("font_size", 11)
	cost_label.modulate = Color(0.72, 0.9, 1.0, 0.9)
	cost_label.text = "能量" if energy_mode else "魔力 %d" % magic_cost
	add_child(cost_label)

	key_badge = Panel.new()
	key_badge.position = Vector2(6.0, slot_size.y - 20.0)
	key_badge.size = Vector2(30.0, 20.0)
	var key_style := StyleBoxFlat.new()
	key_style.bg_color = key_label_bg_color
	key_style.border_color = key_label_border_color
	key_style.border_width_left = 1
	key_style.border_width_top = 1
	key_style.border_width_right = 1
	key_style.border_width_bottom = 1
	key_style.corner_radius_top_left = 5
	key_style.corner_radius_top_right = 5
	key_style.corner_radius_bottom_left = 5
	key_style.corner_radius_bottom_right = 5
	key_badge.add_theme_stylebox_override("panel", key_style)
	add_child(key_badge)

	key_label = Label.new()
	key_label.text = key_label_text
	key_label.position = Vector2.ZERO
	key_label.size = key_badge.size
	key_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	key_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	key_label.add_theme_font_size_override("font_size", 12)
	key_label.modulate = key_label_color
	key_badge.add_child(key_label)

func _draw() -> void:
	var center := Vector2(slot_size.x * 0.5, 28.0)
	draw_circle(center, icon_radius, icon_color)
	draw_arc(center, icon_radius, 0.0, TAU, 48, Color(0.0, 0.0, 0.0, 0.3), 2.0, true)
	# Authored glyphs distinguish the three formerly empty medallions.
	var glyph := Color("ebd5a3")
	if key_label_text == "SP":
		for offset in [-8.0, 2.0]:
			draw_polyline(PackedVector2Array([center + Vector2(offset - 5, -9), center + Vector2(offset + 4, 0), center + Vector2(offset - 5, 9)]), glyph, 2.5, true)
	elif energy_mode:
		draw_arc(center + Vector2(0, 1), 12, 0, PI, 24, glyph, 2.5, true)
		draw_line(center + Vector2(-15, 1), center + Vector2(15, 1), glyph, 2.5, true)
		for offset in [-7.0, 0.0, 7.0]:
			draw_line(center + Vector2(offset, -11), center + Vector2(offset + 2, -5), glyph, 1.8, true)
	else:
		draw_polyline(PackedVector2Array([center + Vector2(-13, 5), center + Vector2(4, 5), center + Vector2(11, -4), center + Vector2(3, -5), center + Vector2(-2, -12)]), glyph, 2.5, true)
		draw_line(center + Vector2(-12, 11), center + Vector2(5, 11), glyph, 1.5, true)

	if progress >= 1.0:
		draw_arc(center, icon_radius + 2.0, 0.0, TAU, 48, ready_ring_color, 3.5, true)
		return

	var start_angle := -PI * 0.5
	var end_angle := start_angle + TAU * progress
	draw_arc(center, icon_radius + 2.0, 0.0, TAU, 48, Color(0.18, 0.2, 0.24, 0.4), 3.5, true)
	draw_arc(center, icon_radius + 2.0, start_angle, end_angle, 48, cooldown_ring_color, 3.5, true)

func _format_remaining_time(value: float) -> String:
	if cooldown_precision <= 0:
		return str(ceili(value))
	var factor := pow(10.0, float(cooldown_precision))
	return "%.*f" % [cooldown_precision, ceil(value * factor) / factor]

func _ready_text_color() -> Color:
	return Color(0.6, 0.96, 1.0, 1.0)
