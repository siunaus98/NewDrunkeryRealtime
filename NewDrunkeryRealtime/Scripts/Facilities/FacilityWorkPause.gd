extends Node2D

## Repairable attachment -> forced shutdown -> longer repair. The facility
## owns the effect, including while hidden in a player's carry preview.
const EFFECT_NAME := "FacilityWorkPause"
const DEEP_DURATION := 15.0
const EARLY_REPAIR_DURATION := 3.0
const LATE_REPAIR_DURATION := 5.0
var owner_ref: WeakRef
var remaining := 10.0
var deep := false
var shutdown_duration := DEEP_DURATION
var repair_progress := 0.0
var repair_frame := -10
var repair_player: WeakRef
var carry_label: Label

static func effect_for(station: Node) -> Node:
	if not is_instance_valid(station):
		return null
	var effect := station.get_node_or_null(EFFECT_NAME)
	if effect == null and station.get("sink") != null:
		effect = station.sink.get_node_or_null(EFFECT_NAME)
	if effect != null and not effect.is_queued_for_deletion() and (effect.deep or effect.remaining > 0) and (effect.deep or effect._owner_alive()):
		return effect
	return null

static func is_paused(station: Node) -> bool:
	return effect_for(station) != null

func _owner_alive() -> bool:
	var host: Node = owner_ref.get_ref() if owner_ref != null else null
	return is_instance_valid(host) and not host.is_queued_for_deletion() and not host.is_dead

static func attach(station: Node2D, owner_boss: Node, duration: float = 10.0, forced_duration: float = DEEP_DURATION) -> Node2D:
	var existing := station.get_node_or_null(EFFECT_NAME)
	if existing != null and existing.is_queued_for_deletion():
		station.remove_child(existing)
		existing = null
	if existing != null:
		return existing
	var effect: Node2D = load("res://Scripts/Facilities/FacilityWorkPause.gd").new()
	effect.name = EFFECT_NAME
	effect.owner_ref = weakref(owner_boss)
	effect.remaining = duration
	effect.shutdown_duration = forced_duration
	station.add_child(effect)
	return effect

static func clear_owned(tree: SceneTree, owner_boss: Node) -> void:
	for effect: Node in tree.get_nodes_in_group("facility_work_pauses"):
		if effect.owner_ref.get_ref() == owner_boss and not effect.deep:
			effect.queue_free()

func _ready() -> void:
	add_to_group("facility_work_pauses")
	z_index = 25
	var inherited: Vector2 = get_parent().global_scale
	scale = Vector2(1.0 / maxf(absf(inherited.x), 0.001), 1.0 / maxf(absf(inherited.y), 0.001))

func can_repair() -> bool:
	return not is_queued_for_deletion() and (not deep or remaining <= 0)

func repair_duration() -> float:
	return LATE_REPAIR_DURATION if deep else EARLY_REPAIR_DURATION

func get_pickup_drop_radius() -> float:
	return get_parent().get_pickup_drop_radius()

func get_interaction_rect_global() -> Rect2:
	return get_parent().get_interaction_rect_global()

func set_pickup_drop_highlight(value: bool) -> void:
	get_parent().set_pickup_drop_highlight(value)

func can_take_item(_player: Node) -> bool:
	return false

func can_receive_item(_player: Node) -> bool:
	return false

func get_hold_interaction_action() -> StringName:
	return &"interact"

func should_prioritize_hold_interaction(_player: Node) -> bool:
	return true

func get_interaction_button_prompt(player: Node) -> String:
	if not can_repair():
		return "深度失控 · %d秒后可修理" % ceili(remaining)
	return "放下手中物品后修理" if player.is_holding_item() else "K 按住修理 · %d秒" % ceili(repair_duration())

func interact_with_player(player: Node) -> bool:
	return process_hold_interaction(player, get_process_delta_time())

func process_hold_interaction(player: Node, delta: float) -> bool:
	if not can_repair() or not is_visible_in_tree() or player.is_holding_item() or player.is_carrying_facility():
		return false
	if preload("res://Scripts/Facilities/FacilityControlEffect.gd").rooted(player) or player.is_quicksand_processing_blocked():
		repair_progress = 0
		return false
	var frame := Engine.get_process_frames()
	if repair_frame == frame:
		return false
	if repair_player == null or repair_player.get_ref() != player or frame - repair_frame > 1:
		repair_progress = 0
		repair_player = weakref(player)
	repair_frame = frame
	if repair_progress <= 0 and player.consume_instant_work(&"repair"):
		repair_progress = repair_duration()
	else:
		repair_progress += maxf(delta, 0) * player.get_work_progress_multiplier() * player.get_facility_work_multiplier(get_parent()) * preload("res://Scripts/Core/SupportFacilityAuraQuery.gd").get_cook_multiplier(get_tree(), get_parent().global_position)
	if repair_progress < repair_duration():
		return true
	queue_free()
	preload("res://Scripts/Player/PlayerWorkEvents.gd").completed(player, &"repair")
	player.show_hint("设施修复完成")
	return true

func get_interaction_progress_data(_player: Node) -> Dictionary:
	return {"visible": repair_progress > 0 and can_repair(), "progress": repair_progress / repair_duration()}

func should_lock_player_movement(_player: Node) -> bool:
	return repair_progress > 0 and Engine.get_process_frames() - repair_frame <= 1 and can_repair()

func should_block_player_action(player: Node) -> bool:
	return should_lock_player_movement(player)

func _process(delta: float) -> void:
	if is_queued_for_deletion():
		return
	if not deep and not _owner_alive():
		queue_free()
		return
	if Engine.get_process_frames() - repair_frame > 1:
		repair_progress = 0
	remaining -= maxf(delta, 0)
	if remaining <= 0 and not deep:
		deep = true
		remaining += shutdown_duration
		repair_progress = 0
		repair_player = null
		if get_parent().has_method("destroy_surface_food"):
			get_parent().destroy_surface_food()
	remaining = maxf(remaining, 0)
	if get_parent().get("work_progress") != null and float(get_parent().get("work_progress")) > 0:
		get_parent().set("work_frame", Engine.get_process_frames())
	_update_carry_feedback()
	queue_redraw()

func _update_carry_feedback() -> void:
	var station: Node = get_parent()
	var carrier: Node = station.get_meta("facility_carrier").get_ref() if station.has_meta("facility_carrier") else null
	if not is_instance_valid(carrier):
		if is_instance_valid(carry_label):
			carry_label.queue_free()
			carry_label = null
		return
	if not is_instance_valid(carry_label):
		carry_label = Label.new()
		carry_label.position = Vector2(-200, -300)
		carry_label.size.x = 400
		carry_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		carry_label.add_theme_font_size_override("font_size", 22)
		carry_label.add_theme_color_override("font_outline_color", Color("513420"))
		carry_label.add_theme_constant_override("outline_size", 5)
		carrier.add_child(carry_label)
	carry_label.text = "设施附着口水 · %d秒 · 放下后修理" % ceili(remaining)
	if deep:
		carry_label.text = "设施深度失控 · %d秒" % ceili(remaining) if remaining > 0 else "设施损坏 · 放下后修理"

func _exit_tree() -> void:
	if is_instance_valid(carry_label):
		carry_label.queue_free()

func _draw() -> void:
	var width := 116.0
	var station: Node2D = get_parent()
	if station.has_method("get_layout_footprint"):
		width = float(station.get_layout_footprint().x) * 128 - 12
	var rect := Rect2(-width / 2, -65, width, 112)
	var tint := Color("713944") if deep else Color("6caa86")
	draw_rect(rect, Color(tint, 0.38))
	for index in range(5):
		var x := -width * 0.38 + index * width * 0.19
		var y := -32.0 + sin(index * 2.3) * 18
		draw_circle(Vector2(x, y), 16 + index % 3 * 4, tint)
		draw_line(Vector2(x, y), Vector2(x + 4, 28 + index % 2 * 12), tint, 10, true)
	if deep:
		draw_line(rect.position, rect.end, Color("e0a98b"), 7, true)
		draw_line(Vector2(rect.end.x, rect.position.y), Vector2(rect.position.x, rect.end.y), Color("e0a98b"), 7, true)
	var text := "口水 %d秒 · 按住K修理" % ceili(remaining)
	if deep:
		text = "深度失控 %d秒 · 暂不可修理" % ceili(remaining) if remaining > 0 else "设施损坏 · 按住K修理"
	var at := Vector2(-ThemeDB.fallback_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x / 2, -78)
	draw_string_outline(ThemeDB.fallback_font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, 5, Color("513420"))
	draw_string(ThemeDB.fallback_font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color("e3f5ed"))
