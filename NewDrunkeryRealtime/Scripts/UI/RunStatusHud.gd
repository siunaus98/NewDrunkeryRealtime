extends CanvasLayer

const LevelContext = preload("res://Scripts/Core/LevelContext.gd")
const RunProgressionState = preload("res://Scripts/Core/RunProgressionState.gd")
const HealthBar = preload("res://Scripts/UI/HealthBar.gd")

@export var side_margin: float = 28.0
@export var bottom_margin: float = 40.0
@export var bottom_safe_padding: float = 8.0
@export var gold_panel_size: Vector2 = Vector2(188.0, 58.0)
@export var xp_panel_size: Vector2 = Vector2(560.0, 74.0)
@export var reputation_panel_size: Vector2 = Vector2(118.0, 344.0)
@export var reputation_bar_size: Vector2 = Vector2(28.0, 244.0)
@export var magic_panel_size: Vector2 = Vector2(78.0, 344.0)
@export var magic_bar_size: Vector2 = Vector2(28.0, 244.0)
@export var skill_slot_size: Vector2 = Vector2(92.0, 92.0)
@export var skill_slot_gap: float = 14.0
@export var skill_bar_bottom_margin: float = 52.0
@export var skill_bar_left_gap_after_gold: float = 18.0
@export var xp_panel_width: float = 560.0
@export var day_clock_size: Vector2 = Vector2(112.0, 112.0)

var root: Control
var gold_panel: Panel
var gold_value_label: Label
var xp_panel: Panel
var xp_level_label: Label
var xp_value_label: Label
var xp_fill: ColorRect
var current_level: int = 1
var current_blessing_points: int = 0
var reputation_panel: Panel
var reputation_value_label: Label
var reputation_state_label: Label
var reputation_fill: ColorRect
var reputation_fill_holder: Control
var magic_panel: Panel
var magic_value_label: Label
var magic_state_label: Label
var magic_fill_holder: Control
var magic_segments: Array[ColorRect] = []
var magic_preview_cost: int = 0
var magic_preview_can_afford: bool = true
var skill_bar_root: Control
var action_slot_dash: Control
var skill_slot_small: Control
var skill_slot_big: Control
var day_clock: Control
var boss_panel: Control
var boss_name_label: Label
var boss_health_bar: ActorHealthBar

func _process(_delta: float) -> void:
	if boss_panel == null:
		return
	var active_boss: Node
	for boss in get_tree().get_nodes_in_group("map_mechanism_bosses"):
		if is_instance_valid(boss) and not boss.is_dead and not boss.is_queued_for_deletion():
			active_boss = boss
			break
	boss_panel.visible = active_boss != null
	if active_boss != null:
		var status: String = active_boss.get_boss_status_text()
		boss_name_label.text = active_boss.get_boss_display_name() + ("  ·  " + status if not status.is_empty() else "")
		boss_health_bar.set_health(active_boss.current_health, active_boss.max_health)

func _ready() -> void:
	layer = 31
	_build_ui()
	_layout_ui()
	call_deferred("_layout_ui")
	clear_status()

# Read live state without retaining a second copy or committing gameplay changes.
func update_run_status(run_context: LevelContext, progression_state: RunProgressionState, player: Node, magic_current: int, magic_max: int) -> void:
	if run_context == null:
		clear_status()
		return

	set_status_visible(run_context.state not in [
		LevelContext.LevelState.ORDER_GROUP_SELECT,
		LevelContext.LevelState.NIGHT_SHOP,
		LevelContext.LevelState.MENU_DISH_SELECT,
		LevelContext.LevelState.BLESSING_SELECT,
		LevelContext.LevelState.GLOBAL_MODIFIER_SELECT,
		LevelContext.LevelState.LEVEL_SUCCESS,
		LevelContext.LevelState.LEVEL_FAILED
	])
	set_gold(progression_state.gold)
	set_level(progression_state.level)
	set_blessing_points(progression_state.get_blessing_points())
	var xp_ratio: float = 0.0
	if progression_state.xp_for_next_level > 0:
		xp_ratio = clampf(float(progression_state.xp) / float(progression_state.xp_for_next_level), 0.0, 1.0)
	set_xp(progression_state.xp, xp_ratio, progression_state.xp_for_next_level)
	set_reputation(run_context.reputation, run_context.reputation_max, run_context.danger_active)
	var preview_cost: int = 0
	if player != null and player.has_method("get_carried_facility_magic_cost"):
		preview_cost = maxi(int(player.get_carried_facility_magic_cost()), 0)
	set_magic(magic_current, magic_max, preview_cost, magic_current >= preview_cost)
	sync_skill_states(player)

func update_day_clock(run_context: LevelContext, day_time_remaining: float, prepare_phase_duration: float, service_phase_duration: float, special_clock: Dictionary = {}) -> void:
	if run_context == null:
		return
	var daytime_state: bool = run_context.state in [
		LevelContext.LevelState.PREPARE_PHASE,
		LevelContext.LevelState.WAVE_ACTIVE,
		LevelContext.LevelState.WAVE_BREAK
	]
	var phase_text := "备菜"
	if run_context.state == LevelContext.LevelState.WAVE_ACTIVE or run_context.state == LevelContext.LevelState.WAVE_BREAK:
		phase_text = "营业"
	if bool(run_context.selected_order_group.get("boss_special_guest", false)):
		if not run_context.special_guest_arrived:
			if run_context.state != LevelContext.LevelState.PREPARE_PHASE:
				phase_text = "来客"
		elif not special_clock.is_empty():
			phase_text = "失望" if bool(special_clock.get("overdue", false)) else "耐心" if bool(special_clock.get("accepted", false)) else "接单"
			set_day_clock(float(special_clock.remaining), float(special_clock.duration), 0.0, phase_text, daytime_state)
			return
	set_day_clock(
		day_time_remaining,
		prepare_phase_duration + service_phase_duration,
		prepare_phase_duration,
		phase_text,
		daytime_state
	)

func clear_status() -> void:
	visible = false
	if day_clock != null:
		day_clock.visible = false
	set_gold(0)
	set_level(1)
	set_xp(0, 0.0)
	set_reputation(0, 100, false)
	set_magic(0, 8)

func set_status_visible(is_visible: bool) -> void:
	visible = is_visible

func set_gold(value: int) -> void:
	if gold_value_label != null:
		gold_value_label.text = str(max(value, 0))

func set_level(value: int) -> void:
	current_level = maxi(value, 1)
	_refresh_level_text()

func set_blessing_points(value: int) -> void:
	current_blessing_points = maxi(value, 0)
	_refresh_level_text()

func _refresh_level_text() -> void:
	if xp_level_label != null:
		xp_level_label.text = "等级 %d   祝福点 %d" % [current_level, current_blessing_points]

func set_xp(current_xp: int, progress_ratio: float = 0.0, xp_needed: int = 0) -> void:
	if xp_value_label != null:
		if xp_needed > 0:
			xp_value_label.text = "%d / %d" % [max(current_xp, 0), xp_needed]
		else:
			xp_value_label.text = "经验 %d" % max(current_xp, 0)
	if xp_fill != null:
		var clamped_ratio: float = clampf(progress_ratio, 0.0, 1.0)
		xp_fill.size = Vector2(504.0 * clamped_ratio, 16.0)

func set_reputation(current: int, maximum: int, danger_active: bool = false) -> void:
	if reputation_value_label != null:
		reputation_value_label.text = "%d / %d" % [max(current, 0), max(maximum, 1)]
	if reputation_state_label != null:
		reputation_state_label.text = "危险" if danger_active else "声望"

	if reputation_fill != null and reputation_fill_holder != null:
		var clamped_ratio: float = clampf(float(max(current, 0)) / float(max(maximum, 1)), 0.0, 1.0)
		var fill_height: float = reputation_bar_size.y * clamped_ratio
		reputation_fill.position.y = reputation_bar_size.y - fill_height
		reputation_fill.size.y = fill_height
		if clamped_ratio > 0.6:
			reputation_fill.color = Color(0.52, 0.88, 0.48, 1.0)
		elif clamped_ratio > 0.25:
			reputation_fill.color = Color(0.96, 0.76, 0.28, 1.0)
		else:
			reputation_fill.color = Color(0.92, 0.34, 0.3, 1.0)
		if danger_active:
			reputation_fill.color = reputation_fill.color.lerp(Color(1.0, 0.94, 0.64, 1.0), 0.2)

func set_magic(current: int, maximum: int, preview_cost: int = 0, preview_can_afford: bool = true) -> void:
	var safe_maximum: int = maxi(maximum, 1)
	var safe_current: int = clampi(current, 0, safe_maximum)
	magic_preview_cost = clampi(preview_cost, 0, safe_maximum)
	magic_preview_can_afford = preview_can_afford
	if magic_value_label != null:
		if magic_preview_cost > 0:
			magic_value_label.text = "%d / %d  -%d" % [safe_current, safe_maximum, magic_preview_cost]
		else:
			magic_value_label.text = "%d / %d" % [safe_current, safe_maximum]
	if magic_state_label != null:
		magic_state_label.text = "魔力"
	if magic_fill_holder == null:
		return
	_rebuild_magic_segments(safe_maximum)
	for i in range(magic_segments.size()):
		var segment: ColorRect = magic_segments[i]
		var is_filled: bool = i < safe_current
		var preview_start: int = maxi(safe_current - magic_preview_cost, 0) if magic_preview_can_afford else 0
		var preview_end: int = safe_current if magic_preview_can_afford else mini(magic_preview_cost, safe_maximum)
		var is_preview_spent: bool = magic_preview_cost > 0 and i >= preview_start and i < preview_end
		if is_preview_spent:
			var flash: float = 0.45 + 0.55 * absf(sin(float(Time.get_ticks_msec()) * 0.012))
			var warning_color := Color(1.0, 0.12, 0.08, 0.92).lerp(Color(1.0, 0.78, 0.32, 0.96), flash)
			if not magic_preview_can_afford:
				warning_color = Color(1.0, 0.05, 0.03, 0.96).lerp(Color(0.35, 0.02, 0.02, 0.92), flash)
			segment.color = warning_color
		else:
			segment.color = Color(0.24, 0.72, 1.0, 1.0) if is_filled else Color(0.07, 0.13, 0.2, 1.0)

func _build_ui() -> void:
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	root.resized.connect(_layout_ui)

	gold_panel = _create_panel(gold_panel_size)
	root.add_child(gold_panel)

	var gold_icon := Label.new()
	gold_icon.text = "金"
	gold_icon.position = Vector2(14.0, 9.0)
	gold_icon.size = Vector2(28.0, 32.0)
	gold_icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	gold_icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	gold_icon.add_theme_font_size_override("font_size", 24)
	gold_icon.modulate = Color(1.0, 0.84, 0.34, 1.0)
	gold_panel.add_child(gold_icon)

	var gold_title := Label.new()
	gold_title.text = "金币"
	gold_title.position = Vector2(48.0, 8.0)
	gold_title.size = Vector2(120.0, 20.0)
	gold_title.add_theme_font_size_override("font_size", 14)
	gold_title.modulate = Color(0.88, 0.9, 0.92, 0.78)
	gold_panel.add_child(gold_title)

	gold_value_label = Label.new()
	gold_value_label.position = Vector2(48.0, 24.0)
	gold_value_label.size = Vector2(126.0, 24.0)
	gold_value_label.add_theme_font_size_override("font_size", 22)
	gold_value_label.modulate = Color(1.0, 0.96, 0.78, 1.0)
	gold_panel.add_child(gold_value_label)

	xp_panel = _create_panel(xp_panel_size)
	root.add_child(xp_panel)

	xp_level_label = Label.new()
	xp_level_label.position = Vector2(16.0, 11.0)
	xp_level_label.size = Vector2(260.0, 24.0)
	xp_level_label.add_theme_font_size_override("font_size", 20)
	xp_level_label.modulate = Color(0.95, 0.96, 0.98, 1.0)
	xp_panel.add_child(xp_level_label)

	xp_value_label = Label.new()
	xp_value_label.position = Vector2(446.0, 11.0)
	xp_value_label.size = Vector2(96.0, 22.0)
	xp_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	xp_value_label.add_theme_font_size_override("font_size", 16)
	xp_value_label.modulate = Color(0.78, 0.86, 1.0, 0.86)
	xp_panel.add_child(xp_value_label)

	var xp_frame := ColorRect.new()
	xp_frame.position = Vector2(16.0, 42.0)
	xp_frame.size = Vector2(504.0, 16.0)
	xp_frame.color = Color(0.08, 0.11, 0.16, 1.0)
	xp_panel.add_child(xp_frame)

	xp_fill = ColorRect.new()
	xp_fill.position = Vector2.ZERO
	xp_fill.size = Vector2.ZERO
	xp_fill.color = Color(0.42, 0.72, 1.0, 1.0)
	xp_frame.add_child(xp_fill)

	reputation_panel = _create_panel(reputation_panel_size)
	root.add_child(reputation_panel)

	reputation_state_label = Label.new()
	reputation_state_label.position = Vector2(14.0, 12.0)
	reputation_state_label.size = Vector2(90.0, 20.0)
	reputation_state_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reputation_state_label.add_theme_font_size_override("font_size", 13)
	reputation_state_label.modulate = Color(0.96, 0.92, 0.76, 0.92)
	reputation_panel.add_child(reputation_state_label)

	reputation_fill_holder = Control.new()
	reputation_fill_holder.position = Vector2(45.0, 48.0)
	reputation_fill_holder.size = reputation_bar_size
	reputation_panel.add_child(reputation_fill_holder)

	var reputation_frame := ColorRect.new()
	reputation_frame.position = Vector2.ZERO
	reputation_frame.size = reputation_bar_size
	reputation_frame.color = Color(0.08, 0.10, 0.12, 1.0)
	reputation_fill_holder.add_child(reputation_frame)

	reputation_fill = ColorRect.new()
	reputation_fill.position = Vector2(0.0, reputation_bar_size.y)
	reputation_fill.size = Vector2(reputation_bar_size.x, 0.0)
	reputation_fill.color = Color(0.52, 0.88, 0.48, 1.0)
	reputation_frame.add_child(reputation_fill)

	reputation_value_label = Label.new()
	reputation_value_label.position = Vector2(10.0, 304.0)
	reputation_value_label.size = Vector2(98.0, 22.0)
	reputation_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reputation_value_label.add_theme_font_size_override("font_size", 14)
	reputation_value_label.modulate = Color(0.94, 0.95, 0.97, 0.9)
	reputation_panel.add_child(reputation_value_label)

	magic_panel = _create_panel(magic_panel_size)
	root.add_child(magic_panel)

	magic_state_label = Label.new()
	magic_state_label.position = Vector2(9.0, 12.0)
	magic_state_label.size = Vector2(60.0, 20.0)
	magic_state_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	magic_state_label.add_theme_font_size_override("font_size", 13)
	magic_state_label.modulate = Color(0.72, 0.9, 1.0, 0.96)
	magic_panel.add_child(magic_state_label)

	magic_fill_holder = Control.new()
	magic_fill_holder.position = Vector2(25.0, 48.0)
	magic_fill_holder.size = magic_bar_size
	magic_panel.add_child(magic_fill_holder)

	magic_value_label = Label.new()
	magic_value_label.position = Vector2(4.0, 304.0)
	magic_value_label.size = Vector2(70.0, 22.0)
	magic_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	magic_value_label.add_theme_font_size_override("font_size", 13)
	magic_value_label.modulate = Color(0.84, 0.94, 1.0, 0.92)
	magic_panel.add_child(magic_value_label)

	skill_bar_root = Control.new()
	skill_bar_root.set_anchors_preset(Control.PRESET_TOP_LEFT)
	skill_bar_root.position = Vector2.ZERO
	skill_bar_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(skill_bar_root)

	action_slot_dash = load("res://Scripts/UI/SkillCooldownSlot.gd").new()
	action_slot_dash.slot_size = skill_slot_size
	action_slot_dash.ready_text = "DASH"
	action_slot_dash.ready_ring_color = Color(0.44, 0.88, 1.0, 0.95)
	action_slot_dash.cooldown_ring_color = Color(1.0, 0.75, 0.22, 0.95)
	action_slot_dash.set_key_label("SP")
	skill_bar_root.add_child(action_slot_dash)

	skill_slot_small = load("res://Scripts/UI/SkillCooldownSlot.gd").new()
	skill_slot_small.slot_size = skill_slot_size
	skill_slot_small.ready_text = "SKL"
	skill_slot_small.set_key_label("U")
	skill_slot_small.set_magic_cost(2)
	skill_bar_root.add_child(skill_slot_small)

	skill_slot_big = load("res://Scripts/UI/SkillCooldownSlot.gd").new()
	skill_slot_big.energy_mode = true
	skill_slot_big.progress = 0.0
	skill_slot_big.slot_size = skill_slot_size
	skill_slot_big.ready_text = "ULT"
	skill_slot_big.set_key_label("I")
	skill_bar_root.add_child(skill_slot_big)

	day_clock = load("res://Scripts/UI/DayClock.gd").new()
	day_clock.name = "DayClock"
	day_clock.size = day_clock_size
	root.add_child(day_clock)

	boss_panel = Control.new()
	boss_panel.name = "BossHealthPanel"
	boss_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	boss_panel.hide()
	root.add_child(boss_panel)
	boss_name_label = Label.new()
	boss_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	boss_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_name_label.add_theme_font_size_override("font_size", 22)
	boss_name_label.add_theme_color_override("font_outline_color", Color("171c24"))
	boss_name_label.add_theme_constant_override("outline_size", 6)
	boss_panel.add_child(boss_name_label)
	boss_health_bar = HealthBar.new()
	boss_health_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	boss_health_bar.position = Vector2(0, 32)
	boss_panel.add_child(boss_health_bar)

func _layout_ui() -> void:
	if root == null:
		return

	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		viewport_size = root.size

	var bottom_y: float = viewport_size.y - bottom_margin - bottom_safe_padding
	gold_panel.position = Vector2(side_margin, bottom_y - gold_panel_size.y)
	var current_xp_panel_size := Vector2(xp_panel_width, xp_panel_size.y)
	xp_panel.position = Vector2(viewport_size.x - side_margin - current_xp_panel_size.x, bottom_y - current_xp_panel_size.y)
	xp_panel.size = current_xp_panel_size
	reputation_panel.position = Vector2(viewport_size.x - side_margin - reputation_panel_size.x, side_margin)
	magic_panel.position = Vector2(reputation_panel.position.x - magic_panel_size.x - 10.0, side_margin)
	if day_clock != null:
		day_clock.size = day_clock_size
		day_clock.position = Vector2((viewport_size.x - day_clock_size.x) * 0.5, side_margin - 4.0)
	if boss_panel != null:
		var boss_width := minf(600.0, viewport_size.x * 0.4)
		boss_panel.position = Vector2((viewport_size.x - boss_width) * 0.5, side_margin + day_clock_size.y + 4.0)
		boss_panel.size = Vector2(boss_width, 54)
		boss_name_label.size = Vector2(boss_width, 30)
		boss_health_bar.size = Vector2(boss_width, 22)

	if skill_bar_root != null:
		var start_x: float = side_margin + gold_panel_size.x + skill_bar_left_gap_after_gold
		var skill_y: float = viewport_size.y - skill_bar_bottom_margin - skill_slot_size.y
		action_slot_dash.size = skill_slot_size
		skill_slot_small.size = skill_slot_size
		skill_slot_big.size = skill_slot_size
		action_slot_dash.position = Vector2(start_x, skill_y)
		skill_slot_small.position = Vector2(start_x + (skill_slot_size.x + skill_slot_gap), skill_y)
		skill_slot_big.position = Vector2(start_x + (skill_slot_size.x + skill_slot_gap) * 2.0, skill_y)

func set_day_clock(remaining: float, total_duration: float, prepare_duration: float, phase_text: String, is_visible: bool = true) -> void:
	if day_clock != null and day_clock.has_method("set_schedule"):
		day_clock.visible = is_visible
		day_clock.set_schedule(remaining, total_duration, prepare_duration, phase_text)

func set_dash_state(cooldown_progress: float, remaining_seconds: float, key_label: String = "SP") -> void:
	if action_slot_dash != null:
		action_slot_dash.set_slot_state(cooldown_progress, remaining_seconds, key_label)

func set_small_skill_state(cooldown_progress: float, remaining_seconds: float, key_label: String = "U") -> void:
	if skill_slot_small != null:
		skill_slot_small.set_slot_state(cooldown_progress, remaining_seconds, key_label)

func set_big_skill_state(cooldown_progress: float, remaining_seconds: float, key_label: String = "I") -> void:
	if skill_slot_big != null:
		skill_slot_big.set_energy_state(cooldown_progress, remaining_seconds)

func sync_skill_states(player: Node) -> void:
	if player == null:
		return
	var small_progress: float = 1.0
	var small_remaining: float = 0.0
	var big_progress: float = 1.0
	var big_remaining: float = 0.0
	var dash_progress: float = 1.0
	var dash_remaining: float = 0.0
	if player.has_method("get_dash_cooldown_progress"):
		dash_progress = float(player.get_dash_cooldown_progress())
	if player.has_method("get_dash_cooldown_remaining"):
		dash_remaining = float(player.get_dash_cooldown_remaining())
	if player.has_method("get_small_skill_progress"):
		small_progress = float(player.get_small_skill_progress())
	if player.has_method("get_small_skill_remaining"):
		small_remaining = float(player.get_small_skill_remaining())
	if player.has_method("get_big_skill_progress"):
		big_progress = float(player.get_big_skill_progress())
	if player.has_method("get_big_skill_remaining"):
		big_remaining = float(player.get_big_skill_remaining())
	set_dash_state(dash_progress, dash_remaining, "SP")
	set_small_skill_state(small_progress, small_remaining, "U")
	if player.has_method("get_small_skill_display_data"):
		var skill_data: Dictionary = player.get_small_skill_display_data()
		skill_slot_small.set_magic_cost(int(skill_data.cost))
		skill_slot_small.tooltip_text = preload("res://Scripts/Player/SmallSkillDefs.gd").get_description(StringName(skill_data.id))
	set_big_skill_state(big_progress, big_remaining, "I")

func _create_panel(panel_size: Vector2) -> Panel:
	var panel := Panel.new()
	panel.size = panel_size

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.12, 0.14, 0.18, 0.92)
	panel_style.border_color = Color(0.86, 0.88, 0.92, 0.9)
	panel_style.border_width_left = 2
	panel_style.border_width_top = 2
	panel_style.border_width_right = 2
	panel_style.border_width_bottom = 2
	panel_style.corner_radius_top_left = 8
	panel_style.corner_radius_top_right = 8
	panel_style.corner_radius_bottom_left = 8
	panel_style.corner_radius_bottom_right = 8
	panel_style.shadow_color = Color(0.0, 0.0, 0.0, 0.24)
	panel_style.shadow_size = 6
	preload("res://Scripts/UI/AtelierStyle.gd").finish(panel_style)
	panel.add_theme_stylebox_override("panel", panel_style)

	return panel

func _rebuild_magic_segments(maximum: int) -> void:
	if magic_fill_holder == null:
		return
	if magic_segments.size() == maximum:
		return
	for child in magic_fill_holder.get_children():
		child.queue_free()
	magic_segments.clear()
	var gap: float = 4.0
	var segment_height: float = (magic_bar_size.y - gap * float(maximum - 1)) / float(maximum)
	for i in range(maximum):
		var segment := ColorRect.new()
		var y: float = magic_bar_size.y - (segment_height + gap) * float(i + 1) + gap
		segment.position = Vector2.ZERO + Vector2(0.0, y)
		segment.size = Vector2(magic_bar_size.x, segment_height)
		segment.color = Color(0.07, 0.13, 0.2, 1.0)
		magic_fill_holder.add_child(segment)
		magic_segments.append(segment)
