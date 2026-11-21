@tool
extends StaticBody2D

const AudioCue = preload("res://Scripts/Audio/AudioCue.gd")

const InteractionGeometry = preload("res://Scripts/Core/InteractionGeometry.gd")

signal forage_finished(point: Node, success: bool)

const TestItemDefs = preload("res://Scripts/Kitchen/TestItemDefs.gd")
const LevelRefs = preload("res://Scripts/Core/LevelRefs.gd")

enum ForageState {
	IDLE,
	SEARCHING,
	SELECTING,
	COOLDOWN
}

@export var display_name: String = "采集点"
@export var forage_item_ids: Array[StringName] = [
	TestItemDefs.VEG_LEAF_ID,
	TestItemDefs.RICE_ID,
	TestItemDefs.EGG_ID
]
@export var search_duration: float = 3.0
@export var selection_duration: float = 1.0
@export var cooldown_duration: float = 5.0
@export var pickup_distance: float = 170.0
@export var continue_distance: float = 240.0
@export var interaction_area_center: Vector2 = Vector2(0, -18)
@export var interaction_area_size: Vector2 = Vector2(144, 136)
@export var body_color: Color = Color(0.52, 0.38, 0.18, 1.0)
@export var body_highlight_color: Color = Color(0.82, 0.64, 0.28, 1.0)
@export var accent_color: Color = Color(0.18, 0.62, 0.28, 1.0)
@export var option_radius: float = 38.0
@export var remove_after_attempt: bool = false
@export var show_interaction_debug: bool = false

@onready var name_label: Label = $NameLabel
@onready var prompt_label: Label = $PromptLabel

var player: Node2D
var state: ForageState = ForageState.IDLE
var search_progress: float = 0.0
var selection_remaining: float = 0.0
var cooldown_remaining: float = 0.0
var is_highlighted: bool = false
var active_player: Node
var rng := RandomNumberGenerator.new()
var option_root: Node2D
var active_options: Array[Dictionary] = []
var option_keys_were_down: Dictionary = {}
var storage_manager: Node
var level_refs: LevelRefs

func _ready() -> void:
	add_to_group("pickup_drop_targets")
	add_to_group("forage_points")
	rng.randomize()
	_update_player_reference()
	_resolve_storage_manager()
	_refresh_labels()
	queue_redraw()

func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		_refresh_labels()
		queue_redraw()
		return

	if not is_instance_valid(player):
		_update_player_reference()
	if storage_manager == null:
		_resolve_storage_manager()

	match state:
		ForageState.SEARCHING:
			if not Input.is_action_pressed("interact") or _should_cancel_active_state():
				_cancel_search()
		ForageState.SELECTING:
			if _should_cancel_active_state():
				_cancel_search()
				return
			selection_remaining = maxf(selection_remaining - delta, 0.0)
			_check_selection_input()
			if selection_remaining <= 0.0 and state == ForageState.SELECTING:
				_finish_selection_miss()
		ForageState.COOLDOWN:
			cooldown_remaining = maxf(cooldown_remaining - delta, 0.0)
			if cooldown_remaining <= 0.0:
				_set_state(ForageState.IDLE)

	_refresh_labels()
	queue_redraw()

func is_pickup_drop_focusable(other_player: Node) -> bool:
	if other_player == null:
		return false
	if other_player.has_method("is_holding_item") and other_player.is_holding_item():
		return false
	if storage_manager == null:
		_resolve_storage_manager()
	return storage_manager != null and storage_manager.has_method("add_stock") and state != ForageState.COOLDOWN

func interact_with_player(other_player: Node) -> bool:
	if not is_pickup_drop_focusable(other_player):
		return false
	if state == ForageState.IDLE:
		_start_search(other_player)
		return true
	return state == ForageState.SEARCHING or state == ForageState.SELECTING

func process_hold_interaction(other_player: Node, delta: float) -> bool:
	if state != ForageState.SEARCHING:
		return false
	if other_player != active_player:
		return false
	if _should_cancel_active_state():
		_cancel_search()
		return false

	var speed: float = float(other_player.get_work_progress_multiplier()) if other_player != null and other_player.has_method("get_work_progress_multiplier") else 1.0
	search_progress = minf(search_progress + maxf(delta, 0.0) * maxf(speed, 0.0), maxf(search_duration, 0.01))
	if search_progress >= search_duration:
		_start_selection()
	return true

func get_interaction_progress_data(_other_player: Node) -> Dictionary:
	if state == ForageState.SEARCHING:
		return {
			"visible": true,
			"progress": search_progress / maxf(search_duration, 0.01)
		}
	if state == ForageState.COOLDOWN:
		return {
			"visible": true,
			"progress": 1.0 - cooldown_remaining / maxf(cooldown_duration, 0.01)
		}
	return {}

func should_lock_player_movement(other_player: Node) -> bool:
	return other_player == active_player and state in [ForageState.SEARCHING, ForageState.SELECTING]

func should_block_player_pickup_drop(other_player: Node) -> bool:
	return other_player == active_player and state == ForageState.SELECTING

func should_block_player_action(other_player: Node) -> bool:
	return other_player == active_player and state == ForageState.SELECTING

func get_pickup_drop_radius() -> float:
	return pickup_distance

func get_interaction_rect_global() -> Rect2:
	return InteractionGeometry.world_rect(global_transform, interaction_area_center, interaction_area_size)

func get_interaction_button_prompt(_other_player: Node) -> String:
	match state:
		ForageState.IDLE:
			return "K 采集"
		ForageState.SEARCHING:
			return ""
		ForageState.SELECTING:
			return ""
		_:
			return ""

func set_pickup_drop_highlight(active: bool) -> void:
	is_highlighted = active
	_refresh_labels()
	queue_redraw()

func _start_search(other_player: Node) -> void:
	active_player = other_player
	search_progress = 0.0
	_clear_options()
	_set_state(ForageState.SEARCHING)

func _cancel_search() -> void:
	# Cancelling does not consume the point or free the region's spawn slot.
	_release_player_interaction_target()
	search_progress = 0.0
	selection_remaining = 0.0
	active_player = null
	_clear_options()
	_set_state(ForageState.IDLE)

func cancel_interaction(other_player: Node) -> void:
	if active_player == other_player and state in [ForageState.SEARCHING, ForageState.SELECTING]:
		_cancel_search()

func _start_selection() -> void:
	AudioCue.at(self, &"ui_tab", -5.0)
	search_progress = search_duration
	selection_remaining = selection_duration
	_build_options()
	_set_state(ForageState.SELECTING)

func _finish_selection_miss() -> void:
	var should_remove := remove_after_attempt
	if should_remove:
		_release_player_interaction_target()
	active_player = null
	_clear_options()
	forage_finished.emit(self, false)
	if should_remove:
		queue_free()
		return
	cooldown_remaining = cooldown_duration
	_set_state(ForageState.COOLDOWN)

func _select_option(option_data: Dictionary) -> void:
	if active_player == null or not is_instance_valid(active_player):
		_finish_selection_miss()
		return
	if active_player.has_method("is_holding_item") and active_player.is_holding_item():
		_finish_selection_miss()
		return
	if storage_manager == null:
		_resolve_storage_manager()
	if storage_manager == null or not storage_manager.has_method("add_stock"):
		_finish_selection_miss()
		return

	var item_id: StringName = StringName(option_data.get("item_id", &""))
	var yield_amount := maxi(int(option_data.get("yield_amount", 1)), 1)
	if active_player.has_method("get_blessing_controller"):
		var blessing_runtime: RefCounted = active_player.get_blessing_controller()
		if blessing_runtime != null:
			yield_amount = blessing_runtime.on_forage_yield(yield_amount)
	active_player.set_meta("forage_consumed_action_frame", Engine.get_process_frames())
	storage_manager.add_stock(item_id, yield_amount, &"fresh")
	preload("res://Scripts/Player/UltimateEnergyRules.gd").award(active_player, &"forage")
	preload("res://Scripts/Player/PlayerWorkEvents.gd").completed(active_player, &"forage")
	option_data["yield_amount"] = yield_amount
	var should_remove := remove_after_attempt
	if should_remove:
		_release_player_interaction_target()
	active_player = null
	_clear_options()
	forage_finished.emit(self, true)
	if should_remove:
		queue_free()
		return
	cooldown_remaining = cooldown_duration
	_set_state(ForageState.COOLDOWN)

func _build_options() -> void:
	_clear_options()
	var item_ids := forage_item_ids.duplicate()
	_shuffle_array(item_ids)
	var key_slots: Array[Dictionary] = _get_key_slots(mini(item_ids.size(), 3))
	for i in range(key_slots.size()):
		var item_id: StringName = StringName(item_ids[i])
		var slot: Dictionary = key_slots[i]
		var yield_range := TestItemDefs.get_forage_yield_range(item_id)
		var yield_min := maxi(yield_range.x, 1)
		var yield_max := maxi(yield_range.y, yield_min)
		active_options.append({
			"item_id": item_id,
			"key_code": int(slot.get("key_code", 0)),
			"label": String(slot.get("label", "")),
			"offset": slot.get("offset", Vector2.ZERO),
			"yield_amount": rng.randi_range(yield_min, yield_max)
		})
	_prime_option_key_state()

	option_root = Node2D.new()
	option_root.name = "ForageOptions"
	option_root.z_as_relative = false
	option_root.z_index = 90
	add_child(option_root)
	_refresh_option_nodes()

func harvest_for_vehicle(capacity: int) -> Dictionary:
	if is_queued_for_deletion() or active_player != null or capacity <= 0 or cooldown_remaining > 0:
		return {}
	var result: Dictionary = {}
	var total := 0
	for id: StringName in forage_item_ids:
		var yield_range: Vector2i = TestItemDefs.get_forage_yield_range(id)
		var amount := rng.randi_range(maxi(yield_range.x, 1), maxi(yield_range.y, 1))
		total += amount
		result[id] = int(result.get(id, 0)) + amount
	if total > capacity:
		return {}
	prepare_for_removal()
	forage_finished.emit(self, true)
	queue_free()
	return result

func _refresh_option_nodes() -> void:
	if option_root == null or active_player == null or not is_instance_valid(active_player):
		return

	for option in active_options:
		var item_id: StringName = StringName(option.get("item_id", &""))
		var offset: Vector2 = option.get("offset", Vector2.ZERO)
		var marker := Node2D.new()
		marker.position = to_local(active_player.global_position + offset)
		marker.z_as_relative = false
		marker.z_index = 90
		option_root.add_child(marker)

		var back := ColorRect.new()
		back.color = Color(0.06, 0.045, 0.03, 0.88)
		back.size = Vector2(104, 112)
		back.position = Vector2(-52, -56)
		marker.add_child(back)

		var icon := TextureRect.new()
		icon.texture = TestItemDefs.get_item_texture(item_id)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.size = Vector2(70, 70)
		icon.position = Vector2(-35, -46)
		marker.add_child(icon)

		var label := Label.new()
		label.text = "%s   ×%d" % [
			String(option.get("label", "")),
			maxi(int(option.get("yield_amount", 1)), 1)
		]
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 24)
		label.modulate = Color(1.0, 0.86, 0.45, 1.0)
		label.size = Vector2(104, 30)
		label.position = Vector2(-52, 24)
		marker.add_child(label)

func _clear_options() -> void:
	active_options.clear()
	option_keys_were_down.clear()
	if option_root != null and is_instance_valid(option_root):
		option_root.queue_free()
	option_root = null

func prepare_for_removal() -> void:
	_release_player_interaction_target()
	set_pickup_drop_highlight(false)
	active_player = null
	_clear_options()

func _release_player_interaction_target() -> void:
	if active_player != null and is_instance_valid(active_player) and active_player.has_method("clear_interaction_target_if_matches"):
		active_player.clear_interaction_target_if_matches(self)
	elif player != null and is_instance_valid(player) and player.has_method("clear_interaction_target_if_matches"):
		player.clear_interaction_target_if_matches(self)

func _check_selection_input() -> void:
	for option in active_options:
		if _is_option_key_just_pressed(option):
			_select_option(option)
			return

func _get_key_slots(count: int) -> Array[Dictionary]:
	var slots: Array[Dictionary] = [
		{"key_code": KEY_W, "label": "W", "offset": Vector2(0.0, -226.0)},
		{"key_code": KEY_A, "label": "A", "offset": Vector2(-132.0, -82.0)},
		{"key_code": KEY_S, "label": "S", "offset": Vector2(0.0, -82.0)},
		{"key_code": KEY_D, "label": "D", "offset": Vector2(132.0, -82.0)}
	]
	_shuffle_array(slots)
	return slots.slice(0, clampi(count, 0, slots.size()))

func _prime_option_key_state() -> void:
	option_keys_were_down.clear()
	for option in active_options:
		var key_code: int = int(option.get("key_code", 0))
		if key_code > 0:
			option_keys_were_down[key_code] = Input.is_key_pressed(key_code)

func _is_option_key_just_pressed(option: Dictionary) -> bool:
	var key_code: int = int(option.get("key_code", 0))
	if key_code <= 0:
		return false
	var is_down: bool = Input.is_key_pressed(key_code)
	var was_down: bool = bool(option_keys_were_down.get(key_code, false))
	option_keys_were_down[key_code] = is_down
	return is_down and not was_down

func _shuffle_array(values: Array) -> void:
	for i in range(values.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var temp: Variant = values[i]
		values[i] = values[j]
		values[j] = temp

func _should_cancel_active_state() -> bool:
	if active_player == null or not is_instance_valid(active_player):
		return true
	if active_player.has_method("is_downed") and active_player.is_downed():
		return true
	if active_player.has_method("is_holding_item") and active_player.is_holding_item():
		return true
	if active_player is Node2D and global_position.distance_to(active_player.global_position) > continue_distance:
		return true
	return false

func _set_state(new_state: ForageState) -> void:
	state = new_state
	_refresh_labels()
	queue_redraw()

func _update_player_reference() -> void:
	player = get_tree().get_first_node_in_group("player") as Node2D

func _resolve_storage_manager() -> void:
	if Engine.is_editor_hint():
		return
	level_refs = LevelRefs.find_from(self)
	if level_refs != null:
		storage_manager = level_refs.get_storage_manager()

func _refresh_labels() -> void:
	if name_label != null:
		name_label.text = display_name
		name_label.visible = Engine.is_editor_hint()
	if prompt_label == null:
		return
	prompt_label.visible = Engine.is_editor_hint()
	match state:
		ForageState.IDLE:
			prompt_label.text = "按住 K 搜寻"
		ForageState.SEARCHING:
			prompt_label.text = "搜寻中..."
		ForageState.SELECTING:
			prompt_label.text = "按 %s 入库" % _get_selection_key_hint()
		ForageState.COOLDOWN:
			prompt_label.text = "恢复中"

func _get_selection_key_hint() -> String:
	var labels: Array[String] = []
	for option in active_options:
		var label := String(option.get("label", ""))
		if not label.is_empty():
			labels.append(label)
	return " / ".join(labels) if not labels.is_empty() else "W / A / S / D"

func _draw() -> void:
	var color := body_highlight_color if is_highlighted else body_color
	# Grounded little desert gardens replace the old three-dot placeholders.
	draw_set_transform(Vector2(0, 9), 0, Vector2(1, 0.34))
	draw_circle(Vector2.ZERO, 46, Color(0.22, 0.17, 0.1, 0.2))
	draw_circle(Vector2(0, -7), 42, color.darkened(0.12))
	draw_set_transform(Vector2.ZERO)
	for index in range(7):
		var angle: float = float(index) * TAU / 7
		var at := Vector2(cos(angle) * 32, sin(angle) * 10 + 5)
		draw_circle(at, 6 + index % 3, color.lightened(0.16))
		draw_arc(at, 6 + index % 3, PI, TAU, 12, color.lightened(0.35), 1.5, true)
	var stony: bool = forage_item_ids.has(TestItemDefs.TOFU_ID)
	var grain: bool = forage_item_ids.has(TestItemDefs.RICE_ID)
	for index in range(5):
		var root := Vector2(float(index - 2) * 13, -4 + absf(float(index - 2)) * 3)
		var tip := root + Vector2(float(index % 3 - 1) * 9, -36 - (index * 7) % 19)
		draw_line(root, tip, accent_color.darkened(0.4), 3, true)
		if grain:
			for row in range(3):
				var center := tip + Vector2(0, row * 7)
				draw_line(center + Vector2(-7, -7), center, Color("e9c47d"), 5, true)
				draw_line(center + Vector2(7, -7), center, Color("f2d89d"), 4, true)
		elif stony:
			for petal in range(5):
				var at := tip + Vector2.RIGHT.rotated(float(petal) * TAU / 5) * 9
				draw_circle(at, 7, Color("cba4a0").lightened(float(petal % 2) * 0.12))
				draw_arc(at, 6, PI, TAU, 12, Color("f2d8bb"), 1.4, true)
			draw_circle(tip, 5, Color("f5d289"))
		else:
			for side in [-1.0, 1.0]:
				var mid := tip.lerp(root, 0.4)
				var leaf := PackedVector2Array([mid, mid + Vector2(side * 19, -18), mid + Vector2(side * 21, -5), mid + Vector2(side * 10, 5)])
				draw_colored_polygon(leaf, accent_color.lightened(0.12 if side < 0 else 0.0))
				draw_line(mid, mid + Vector2(side * 16, -10), accent_color.lightened(0.42), 1.3, true)
			draw_circle(tip, 6, accent_color.lightened(0.26))
	if state == ForageState.COOLDOWN:
		draw_arc(Vector2(0, -10), 46.0, -PI * 0.5, -PI * 0.5 + TAU * (1.0 - cooldown_remaining / maxf(cooldown_duration, 0.01)), 32, Color(0.95, 0.74, 0.28, 0.95), 5.0, true)
	if show_interaction_debug:
		var area_rect := Rect2(interaction_area_center - interaction_area_size * 0.5, interaction_area_size)
		draw_rect(area_rect, Color(0.4, 0.9, 1.0, 0.14), true)
		draw_rect(area_rect, Color(0.4, 0.9, 1.0, 0.75), false, 2.0)
