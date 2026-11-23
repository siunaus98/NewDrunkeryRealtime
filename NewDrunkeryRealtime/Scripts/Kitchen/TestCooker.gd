@tool
extends StaticBody2D

const AudioCue = preload("res://Scripts/Audio/AudioCue.gd")

const InteractionGeometry = preload("res://Scripts/Core/InteractionGeometry.gd")

const TestItemDefs = preload("res://Scripts/Kitchen/TestItemDefs.gd")
const CarryItemRules = preload("res://Scripts/Kitchen/CarryItemRules.gd")
const Energy = preload("res://Scripts/Player/UltimateEnergyRules.gd")
const WorkEvents = preload("res://Scripts/Player/PlayerWorkEvents.gd")
const CookerProcessRules = preload("res://Scripts/Kitchen/CookerProcessRules.gd")
const SupportFacilityAuraQuery = preload("res://Scripts/Core/SupportFacilityAuraQuery.gd")
const ProcessStateMark = preload("res://Scripts/Kitchen/ProcessStateMark.gd")
const UltimateBoost = preload("res://Scripts/Player/UltimateFacilityBoost.gd")
const NightEventEffects = preload("res://Scripts/Progression/NightEventEffects.gd")

const PROCESS_MODE_TAP: StringName = &"tap"
const PROCESS_MODE_AUTO: StringName = &"auto"
const PROCESS_MODE_HOLD: StringName = &"hold"
const CookerProgressView = preload("res://Scripts/Kitchen/CookerProgressView.gd")

@export var front_lower_z: int = 0
@export var front_top_z: int = 0
@export var front_item_z: int = 0
@export var back_lower_z: int = 2
@export var back_top_z: int = 3
@export var back_item_z: int = 4
@export var pickup_distance: float = 180.0
@export var interaction_area_center: Vector2 = Vector2(0, -110)
@export var interaction_area_size: Vector2 = Vector2(680, 220)
@export var interaction_area_columns: int = 4
@export var interaction_area_rows: int = 2
@export var cooking_process_mode: StringName = PROCESS_MODE_TAP
@export var output_process_state: StringName = TestItemDefs.PROCESS_STATE_CUT
@export var required_interact_presses: int = 6
@export var required_process_progress: float = 100.0
@export var stage_thresholds: Array[float] = [0.33, 0.67]
@export var stage_labels: Array[String] = ["第一阶段", "第二阶段", "第三阶段"]
@export var auto_process_duration: float = 5.0
@export var hold_process_duration: float = 3.0
@export var overcook_enabled: bool = true
@export var overcook_duration: float = 4.0
@export var normal_modulate: Color = Color.WHITE
@export var highlight_modulate: Color = Color(1.22, 1.18, 1.0, 1.0)
@export var item_normal_scale: Vector2 = Vector2(3.294118, 3.294118)
@export var item_highlight_scale: Vector2 = Vector2(3.294118, 3.294118)
@export var show_interaction_debug: bool = false
@export var debug_area_fill_color: Color = Color(0.98, 0.56, 0.18, 0.12)
@export var debug_area_outline_color: Color = Color(1.0, 0.72, 0.34, 0.6)
@export var debug_point_fill_color: Color = Color(1.0, 0.94, 0.84, 0.95)
@export var debug_point_outline_color: Color = Color(1.0, 0.72, 0.34, 0.95)
@export var debug_point_radius: float = 6.0
@export var station_progress_offset: Vector2 = Vector2(0.0, -500.0)
@export var station_progress_size: Vector2 = Vector2(480.0, 60.0)
@export var station_progress_background_color: Color = Color(0.08, 0.07, 0.06, 0.82)
@export var station_progress_fill_color: Color = Color(0.46, 0.88, 1.0, 0.96)
@export var station_overcook_fill_color: Color = Color("995a32")
@export var station_progress_border_color: Color = Color(0.02, 0.02, 0.02, 0.96)
@export var stage_fill_colors: Array[Color] = [
	Color("f6d43b"),
	Color("ff932f"),
	Color("ed493b")
]
@export var stage_separator_color: Color = Color(0.08, 0.04, 0.02, 0.96)

@onready var lower_sprite: Sprite2D = $LowerSprite
@onready var top_sprite: Sprite2D = $TopSprite
@onready var item_layer: Node2D = $ItemLayer
@onready var item_anchor: Marker2D = $ItemLayer/ItemAnchor
@onready var item_sprite: Sprite2D = $ItemLayer/ItemSprite
@onready var sort_anchor: Marker2D = $SortAnchor
var process_state_mark: Node2D

var player: Node2D
var has_item: bool = false
var item_id: StringName = TestItemDefs.TEST_ITEM_ID
var item_process_state: StringName = TestItemDefs.PROCESS_STATE_NONE
var item_texture: Texture2D
var item_payload: Dictionary = {}
var processing_produced_item: bool = false
var processing_speed_multiplier: float = 1.0
var batch_servings: int = -1
var process_press_count: int = 0
var process_progress: float = 0.0
var overcook_progress: float = 0.0
var process_stage_index: int = 0
var is_highlighted: bool = false
var process_progress_remainder: float = 0.0
var processing_active: bool = false
var last_processing_player: Node
var progress_view: RefCounted
var blessing_auto_duration_multiplier: float = 1.0
var instant_grind_requires_release: bool = false

func _ready() -> void:
	add_to_group("pickup_drop_targets")
	add_to_group("cooking_stations")
	add_to_group("movable_facilities")
	_update_player_reference()
	process_state_mark = ProcessStateMark.new()
	process_state_mark.name = "ProcessStateMark"
	item_layer.add_child(process_state_mark)
	process_state_mark.position = item_sprite.position
	process_state_mark.z_index = item_sprite.z_index + 1
	_apply_front_sorting()
	_update_item_visual()
	if not Engine.is_editor_hint():
		var work_art := preload("res://Scripts/Kitchen/CookerWorkArt.gd").new()
		work_art.name = "CookerWorkArt"
		add_child(work_art)
		progress_view = CookerProgressView.new()
		progress_view.setup(self, {
			"station_progress_offset": station_progress_offset,
			"station_progress_size": station_progress_size,
			"station_progress_background_color": station_progress_background_color,
			"station_progress_fill_color": station_progress_fill_color,
			"station_overcook_fill_color": station_overcook_fill_color,
			"station_progress_border_color": station_progress_border_color,
			"stage_separator_color": stage_separator_color
		})
		_update_station_progress_visual()
	queue_redraw()

func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		if show_interaction_debug:
			queue_redraw()
		return
	if instant_grind_requires_release and not Input.is_action_pressed("interact"):
		instant_grind_requires_release = false

	if not is_instance_valid(player):
		_update_player_reference()
		if not is_instance_valid(player):
			return

	var player_sort_origin: Vector2 = _get_player_sort_origin()
	if player_sort_origin.y > sort_anchor.global_position.y:
		_apply_front_sorting()
	else:
		_apply_back_sorting()

	if show_interaction_debug:
		queue_redraw()

	if not Engine.is_editor_hint() and _is_auto_processing():
		_advance_processing(_delta, null)
	elif not Engine.is_editor_hint() and _is_overcooking():
		_advance_overcook(_delta)
	_update_station_progress_visual()

func _update_player_reference() -> void:
	player = get_tree().get_first_node_in_group("player") as Node2D

func _get_player_sort_origin() -> Vector2:
	if player.has_method("get_sort_origin"):
		return player.get_sort_origin()
	return player.global_position

func _apply_front_sorting() -> void:
	lower_sprite.z_index = front_lower_z
	top_sprite.z_index = front_top_z
	item_layer.z_index = front_item_z

func _apply_back_sorting() -> void:
	lower_sprite.z_index = back_lower_z
	top_sprite.z_index = back_top_z
	item_layer.z_index = back_item_z

func can_take_item(other_player: Node) -> bool:
	if preload("res://Scripts/Facilities/FacilityWorkPause.gd").is_paused(self):
		return false
	if not visible:
		return false
	if not has_item:
		return false
	# Cutting is the only irreversible in-progress operation: once the first
	# cut has been made it must be completed. Roast and grind ingredients may
	# be removed at any point; _clear_item() then discards the station progress.
	if _is_cutting_in_progress():
		return false
	var is_box: bool = TestItemDefs.get_process_family(item_process_state) == &"grind"
	var output_id: StringName = TestItemDefs.SEASONING_BOX_ID if is_box else item_id
	var payload: Dictionary = CarryItemRules.seasoning(item_id, item_process_state, item_payload) if is_box else item_payload.duplicate(true)
	if is_box and batch_servings >= 0:
		payload["servings"] = batch_servings
	return other_player.has_method("can_pick_up_item") and other_player.can_pick_up_item(output_id, item_process_state, payload)

func is_pickup_drop_focusable(other_player: Node) -> bool:
	if preload("res://Scripts/Facilities/FacilityWorkPause.gd").is_paused(self):
		return true
	return (
		can_take_item(other_player)
		or can_receive_item(other_player)
		or (
			cooking_process_mode != PROCESS_MODE_AUTO
			and has_item
			and processing_active
			and TestItemDefs.is_ingredient(item_id)
		)
		or _can_be_carried_by_player(other_player)
	)

func can_receive_item(other_player: Node) -> bool:
	if preload("res://Scripts/Facilities/FacilityWorkPause.gd").is_paused(self):
		return false
	if not visible:
		return false
	if has_item:
		return false
	if not other_player.has_method("is_holding_item") or not other_player.is_holding_item():
		return false
	if not other_player.has_method("get_held_item_id"):
		return false
	var held_item_id: StringName = other_player.get_held_item_id()
	if held_item_id == TestItemDefs.PLATE_ID:
		return _find_receivable_plate_portion(CarryItemRules.payload_from(other_player)) >= 0
	if held_item_id == TestItemDefs.SEASONING_BOX_ID:
		var data: Dictionary = CarryItemRules.payload_from(other_player)
		return cooking_process_mode != PROCESS_MODE_AUTO and int(data.get("servings", 0)) > 0 and TestItemDefs.is_ingredient(StringName(data.get("item_id", &"")))
	if not TestItemDefs.is_ingredient(held_item_id):
		return false
	if not other_player.has_method("get_held_item_process_state"):
		return false
	return _can_receive_ingredient_state(held_item_id, other_player.get_held_item_process_state())

func _can_receive_ingredient_state(incoming_id: StringName, state: StringName) -> bool:
	return CookerProcessRules.can_accept_process_state(output_process_state, state) or (cooking_process_mode != PROCESS_MODE_AUTO and CarryItemRules.can_collect({}, incoming_id, state, {}))

func _find_receivable_plate_portion(payload: Dictionary) -> int:
	var entries: Array = payload.get("items", [])
	for i in range(entries.size()):
		var entry: Dictionary = entries[i]
		var incoming_id: StringName = StringName(entry.get("item_id", &""))
		if TestItemDefs.is_ingredient(incoming_id) and _can_receive_ingredient_state(incoming_id, StringName(entry.get("process_state", &""))):
			return i
	return -1

func take_item_to_player(other_player: Node) -> bool:
	if not can_take_item(other_player):
		return false
	if not other_player.has_method("pick_up_item"):
		return false

	var is_box: bool = TestItemDefs.get_process_family(item_process_state) == &"grind"
	var output_id: StringName = TestItemDefs.SEASONING_BOX_ID if is_box else item_id
	var payload: Dictionary = CarryItemRules.seasoning(item_id, item_process_state, item_payload) if is_box else item_payload.duplicate(true)
	var reward_on_pickup: bool = processing_produced_item and not TestItemDefs.is_raw_state(item_process_state) and item_process_state != TestItemDefs.PROCESS_STATE_BURNT and not bool(item_payload.get(Energy.PROCESS_REWARDED, false))
	if reward_on_pickup:
		payload[Energy.PROCESS_REWARDED] = true
	if is_box and batch_servings >= 0:
		payload["servings"] = batch_servings
	var leaves_servings: bool = is_box and CarryItemRules.is_collecting(other_player)
	var was_picked_up: Variant = other_player.pick_up_item(output_id, TestItemDefs.get_item_texture(output_id), item_process_state if not is_box else &"", "", payload)
	if was_picked_up is bool and was_picked_up:
		if reward_on_pickup:
			Energy.claim_processing(other_player, item_payload)
		if other_player.has_method("get_blessing_controller"):
			var blessing_runtime: RefCounted = other_player.get_blessing_controller()
			if blessing_runtime != null:
				blessing_runtime.on_station_item_taken(item_process_state, not processing_active)
		if leaves_servings and int(payload.servings) > 1:
			# The finished batch remains on the station with its remaining portions.
			batch_servings = CarryItemRules.GRIND_SERVINGS - 1 if batch_servings < 0 else batch_servings - 1
			processing_active = false
			_update_item_visual()
		else:
			_clear_item()
		return true
	return false

func receive_item_from_player(other_player: Node) -> bool:
	if not can_receive_item(other_player):
		return false

	var from_plate: bool = CarryItemRules.is_collecting(other_player)
	var from_box: bool = other_player.get_held_item_id() == TestItemDefs.SEASONING_BOX_ID
	var payload: Dictionary = CarryItemRules.payload_from(other_player)
	var portion_index: int = _find_receivable_plate_portion(payload) if from_plate else -1
	var incoming: Dictionary = Array(payload.get("items", []))[portion_index] if from_plate else payload
	item_payload = Dictionary(incoming.get("payload", {})).duplicate(true) if from_plate else payload.duplicate(true)
	if from_box:
		for key: String in ["item_id", "process_state", "servings"]:
			item_payload.erase(key)
	processing_produced_item = false
	item_id = StringName(incoming.get("item_id", &"")) if from_plate or from_box else other_player.get_held_item_id()
	item_process_state = StringName(incoming.get("process_state", &"")) if from_plate or from_box else TestItemDefs.normalize_process_state(other_player.get_held_item_process_state())
	item_texture = TestItemDefs.get_item_texture(item_id)
	batch_servings = int(payload.get("servings", 1)) if from_box else (1 if TestItemDefs.get_process_family(item_process_state) == &"grind" else -1)
	var required_progress: float = _get_required_process_progress()
	var same_family: bool = TestItemDefs.get_process_family(item_process_state) == TestItemDefs.get_process_family(output_process_state)
	process_progress = CookerProcessRules.progress_for_state(item_process_state, required_progress, _get_stage_thresholds()) if same_family else 0.0
	process_press_count = int(floor(clampf(process_progress / required_progress, 0.0, 1.0) * float(required_interact_presses)))
	overcook_progress = 0.0
	process_stage_index = _get_current_process_stage_index()
	process_progress_remainder = 0.0
	processing_active = CookerProcessRules.can_continue_processing_from_state(output_process_state, item_process_state)
	blessing_auto_duration_multiplier = 1.0
	if cooking_process_mode == PROCESS_MODE_AUTO and other_player.has_method("get_blessing_controller"):
		var blessing_runtime: RefCounted = other_player.get_blessing_controller()
		if blessing_runtime != null:
			blessing_auto_duration_multiplier = blessing_runtime.get_auto_stage_duration_multiplier()
	if cooking_process_mode == PROCESS_MODE_HOLD and TestItemDefs.is_raw_state(item_process_state) and other_player.has_method("get_blessing_controller"):
		var blessing_runtime: RefCounted = other_player.get_blessing_controller()
		if blessing_runtime != null:
			var initial_ratio := maxf(blessing_runtime.get_initial_grind_progress_ratio(), blessing_runtime.get_grind_rebound_ratio())
			process_progress = maxf(process_progress, required_progress * initial_ratio)
	has_item = true
	last_processing_player = other_player

	if from_plate:
		CarryItemRules.remove_plate_portion(other_player, portion_index)
	elif other_player.has_method("clear_held_item"):
		other_player.clear_held_item()

	_update_item_visual()
	return true

func interact_with_player(other_player: Node) -> bool:
	if not has_item:
		return false
	if other_player.has_method("is_holding_item") and other_player.is_holding_item():
		return false
	if not TestItemDefs.is_ingredient(item_id) or not processing_active:
		return false
	last_processing_player = other_player
	if cooking_process_mode == PROCESS_MODE_AUTO:
		return false
	if cooking_process_mode == PROCESS_MODE_HOLD:
		# The instant-work variant is intentionally a tap: do not also advance
		# the hold processor during the same K press. The next press performs the
		# free fine-grind follow-up after the player has released K.
		if other_player != null and other_player.has_method("consume_instant_work") and process_progress <= 0.001:
			return _advance_processing(0.0, other_player, false)
		return process_hold_interaction(other_player, get_process_delta_time())

	return _advance_processing(0.0, other_player, true)

func process_hold_interaction(other_player: Node, delta: float) -> bool:
	if cooking_process_mode != PROCESS_MODE_HOLD:
		return false
	if not has_item or not TestItemDefs.is_ingredient(item_id) or not processing_active:
		return false
	if other_player.has_method("is_holding_item") and other_player.is_holding_item():
		return false
	# A single K press may enter both the tap handler and the held-work update
	# during one frame. After instant coarse grind, require releasing K before
	# the free fine-grind follow-up can start.
	if instant_grind_requires_release:
		return false
	last_processing_player = other_player
	return _advance_processing(delta, other_player)

func get_interaction_progress_data(other_player: Node) -> Dictionary:
	if _is_processing_interrupted(other_player):
		return {}
	if cooking_process_mode == PROCESS_MODE_AUTO:
		return {}
	if not has_item or not TestItemDefs.is_ingredient(item_id) or not processing_active:
		return {}
	if other_player.has_method("is_holding_item") and other_player.is_holding_item():
		return {}
	if process_progress <= 0.0:
		return {}

	var progress_value: float = process_progress / _get_required_process_progress()
	if _is_overcooking():
		progress_value = overcook_progress / _get_required_overcook_progress()

	return {
		"visible": true,
		"progress": progress_value,
		"stage_index": _get_current_process_stage_index(),
		"stage_label": _get_current_process_stage_label(),
		"process_state": item_process_state,
		"display_mode": _get_process_progress_display_mode(),
		"stage_progress": _get_current_stage_progress(),
		"stage_boundaries": _get_stage_thresholds(),
		"stage_colors": _get_stage_colors()
	}

func get_interaction_button_prompt(other_player: Node) -> String:
	if preload("res://Scripts/Facilities/FacilityWorkPause.gd").is_paused(self):
		return ""
	var prompts: Array[String] = []
	if other_player != null and other_player.has_method("is_holding_item") and other_player.is_holding_item():
		if can_receive_item(other_player):
			prompts.append("J 放入一份")
		elif can_take_item(other_player):
			prompts.append("J 装盘")
		return " / ".join(prompts)
	if can_take_item(other_player):
		prompts.append("J 拿起")
	if (
		cooking_process_mode != PROCESS_MODE_AUTO
		and has_item
		and TestItemDefs.is_ingredient(item_id)
		and processing_active
	):
		prompts.append("K %s" % _get_process_action_label())
	if not has_item and _can_be_carried_by_player(other_player):
		prompts.append("K 搬起")
	return " / ".join(prompts)

func _get_process_action_label() -> String:
	match TestItemDefs.normalize_process_state(output_process_state):
		TestItemDefs.PROCESS_STATE_CUT:
			return "切"
		TestItemDefs.PROCESS_STATE_GRIND_FINE:
			return "研磨"
		_:
			return "加工"

func _is_cutting_in_progress() -> bool:
	return (
		has_item
		and processing_active
		and TestItemDefs.normalize_process_state(output_process_state) == TestItemDefs.PROCESS_STATE_CUT
		and process_progress > 0.0
		and process_progress < _get_required_process_progress()
	)

func _can_be_carried_by_player(other_player: Node) -> bool:
	return not has_item and can_be_moved_by_player(other_player)

func get_pickup_drop_positions() -> Array[Vector2]:
	return InteractionGeometry.grid_points(global_transform, interaction_area_center, interaction_area_size, interaction_area_columns, interaction_area_rows)

func get_interaction_rect_global() -> Rect2:
	return InteractionGeometry.world_rect(global_transform, interaction_area_center, interaction_area_size)

func get_pickup_drop_radius() -> float:
	return pickup_distance

func set_pickup_drop_highlight(active: bool) -> void:
	is_highlighted = active
	lower_sprite.modulate = highlight_modulate if active else normal_modulate
	top_sprite.modulate = highlight_modulate if active else normal_modulate
	_update_item_visual()

func can_be_moved_by_player(_other_player: Node) -> bool:
	return not has_item and not preload("res://Scripts/Facilities/FacilityWorkPause.gd").is_paused(self)

func destroy_surface_food() -> void:
	_clear_item()

func get_station_process_state() -> StringName:
	return TestItemDefs.normalize_process_state(output_process_state)

func get_layout_footprint() -> Vector2i:
	return Vector2i(1, 1)

func _finish_processing(other_player: Node) -> void:
	if cooking_process_mode == PROCESS_MODE_AUTO:
		AudioCue.at(self, &"complete", -6.0)
	item_process_state = TestItemDefs.normalize_process_state(output_process_state)
	if cooking_process_mode != PROCESS_MODE_AUTO and is_instance_valid(other_player):
		Energy.claim_processing(other_player, item_payload)
		match TestItemDefs.get_process_family(item_process_state):
			&"cut":
				WorkEvents.completed(other_player, &"cut")
			&"grind":
				WorkEvents.completed(other_player, &"grind_fine")
	process_press_count = required_interact_presses
	process_progress = _get_required_process_progress()
	overcook_progress = 0.0
	process_stage_index = _get_current_process_stage_index()
	process_progress_remainder = 0.0
	processing_active = false
	blessing_auto_duration_multiplier = 1.0
	_update_item_visual()
	var source_player := other_player if other_player != null else last_processing_player
	if source_player != null and source_player.has_method("get_blessing_controller"):
		var blessing_runtime: RefCounted = source_player.get_blessing_controller()
		if blessing_runtime != null:
			if cooking_process_mode != PROCESS_MODE_AUTO:
				blessing_runtime.on_manual_process_completed(item_process_state)
			if TestItemDefs.get_process_family(item_process_state) == &"grind":
				blessing_runtime.on_grind_completed()

	# Completing work leaves the result on the station. J is the explicit pickup.
	_update_station_progress_visual()

func _clear_item() -> void:
	item_payload = {}
	processing_produced_item = false
	batch_servings = -1
	has_item = false
	item_id = TestItemDefs.TEST_ITEM_ID
	item_process_state = TestItemDefs.PROCESS_STATE_NONE
	process_press_count = 0
	process_progress = 0.0
	overcook_progress = 0.0
	process_stage_index = 0
	process_progress_remainder = 0.0
	processing_active = false
	instant_grind_requires_release = false
	last_processing_player = null
	item_texture = null
	_update_item_visual()
	_update_station_progress_visual()

func _get_required_process_progress() -> float:
	return maxf(required_process_progress, 1.0)

func _get_required_overcook_progress() -> float:
	return 100.0

func _is_auto_processing() -> bool:
	return (
		cooking_process_mode == PROCESS_MODE_AUTO
		and has_item
		and TestItemDefs.is_ingredient(item_id)
		and processing_active
	)

func _is_overcooking() -> bool:
	return (
		overcook_enabled and
		cooking_process_mode == PROCESS_MODE_AUTO
		and has_item
		and TestItemDefs.is_ingredient(item_id)
		and not processing_active
		and TestItemDefs.normalize_process_state(item_process_state) == TestItemDefs.normalize_process_state(output_process_state)
	)

func _advance_overcook(delta: float) -> void:
	overcook_progress = minf(
		overcook_progress + _get_required_overcook_progress() * maxf(delta, 0.0) * NightEventEffects.multiplier(self, &"burn") / maxf(overcook_duration, 0.01),
		_get_required_overcook_progress()
	)
	if overcook_progress >= _get_required_overcook_progress():
		item_process_state = TestItemDefs.PROCESS_STATE_BURNT
		overcook_progress = 0.0
	_update_item_visual()
	_update_station_progress_visual()
	queue_redraw()

func _advance_processing(delta: float, other_player: Node, is_tap: bool = false) -> bool:
	if preload("res://Scripts/Facilities/FacilityWorkPause.gd").is_paused(self):
		return false
	if _is_processing_interrupted(other_player):
		return false
	var required_progress: float = _get_required_process_progress()
	var process_gain: float = 0.0
	var instant_work: bool = false
	var instant_grind_to_coarse: bool = false
	var can_consume_instant := process_progress <= 0.001 or (TestItemDefs.get_process_family(output_process_state) == &"grind" and TestItemDefs.normalize_process_state(item_process_state) == TestItemDefs.PROCESS_STATE_GRIND_COARSE)
	if can_consume_instant and cooking_process_mode != PROCESS_MODE_AUTO and other_player != null and other_player.has_method("consume_instant_work"):
		instant_work = bool(other_player.consume_instant_work(item_process_state, output_process_state, item_payload))
		instant_grind_to_coarse = instant_work and TestItemDefs.get_process_family(output_process_state) == &"grind" and TestItemDefs.normalize_process_state(item_process_state) != TestItemDefs.PROCESS_STATE_GRIND_COARSE
	if is_tap:
		var tap_steps := 1
		if other_player != null and other_player.has_method("get_blessing_controller"):
			var blessing_runtime: RefCounted = other_player.get_blessing_controller()
			if blessing_runtime != null:
				tap_steps = blessing_runtime.modify_tap_progress_count(1, process_press_count + 1)
		process_gain = required_progress * float(tap_steps) / float(max(required_interact_presses, 1))
	elif cooking_process_mode == PROCESS_MODE_AUTO:
		process_gain = required_progress * maxf(delta, 0.0) / maxf(auto_process_duration, 0.01)
		# 火候偏爱只延长微生、半熟和全熟窗口；生食到微生的等待保持不变。
		if TestItemDefs.normalize_process_state(item_process_state) in [TestItemDefs.PROCESS_STATE_ROAST_RARE, TestItemDefs.PROCESS_STATE_ROAST_MEDIUM]:
			process_gain /= blessing_auto_duration_multiplier
	elif cooking_process_mode == PROCESS_MODE_HOLD:
		process_gain = required_progress * maxf(delta, 0.0) / maxf(hold_process_duration, 0.01)
	if instant_work:
		if TestItemDefs.get_process_family(output_process_state) == &"grind" and process_progress < _get_stage_thresholds()[0] * required_progress:
			process_gain = _get_stage_thresholds()[0] * required_progress - process_progress
		else:
			process_gain = required_progress - process_progress

	if process_gain <= 0.0:
		return true
	if cooking_process_mode != PROCESS_MODE_AUTO and other_player != null and other_player.has_method("get_station_cook_progress_multiplier"):
		process_gain *= float(other_player.get_station_cook_progress_multiplier(output_process_state))
	elif cooking_process_mode != PROCESS_MODE_AUTO and other_player != null and other_player.has_method("get_cook_progress_multiplier"):
		process_gain *= float(other_player.get_cook_progress_multiplier())
	if other_player != null and other_player.has_method("has_blessing_title") and other_player.has_blessing_title("粗磨起步") and TestItemDefs.get_process_family(item_process_state) == &"grind" and TestItemDefs.normalize_process_state(item_process_state) == TestItemDefs.PROCESS_STATE_GRIND_COARSE:
		process_gain *= 1.25
	process_gain *= _get_nearby_support_cook_multiplier() * processing_speed_multiplier * UltimateBoost.get_multiplier(self)
	if cooking_process_mode == PROCESS_MODE_AUTO:
		process_gain *= NightEventEffects.multiplier(self, &"roast")
	# Instant work must preserve the grind station's two-step choice. The first
	# instant action stops exactly at the coarse threshold even when a facility,
	# blessing, or another multiplier would otherwise push it into fine grind.
	if instant_grind_to_coarse:
		var coarse_target := _get_stage_thresholds()[0] * required_progress if not _get_stage_thresholds().is_empty() else required_progress * 0.5
		process_gain = maxf(coarse_target - process_progress, 0.0)
		instant_grind_requires_release = true

	var work_cue := TestItemDefs.get_process_family(output_process_state)
	AudioCue.work(self, &"roast" if cooking_process_mode == PROCESS_MODE_AUTO else work_cue)
	var previous_progress: float = process_progress
	process_progress = minf(process_progress + process_gain, required_progress)
	_update_stage_process_state()
	if cooking_process_mode != PROCESS_MODE_AUTO and TestItemDefs.get_process_family(output_process_state) == &"grind":
		var thresholds: Array[float] = _get_stage_thresholds()
		var coarse_threshold: float = thresholds[0] * required_progress if not thresholds.is_empty() else required_progress * 0.5
		if previous_progress < coarse_threshold and process_progress >= coarse_threshold:
			WorkEvents.completed(other_player, &"grind_coarse")
	processing_produced_item = true
	if cooking_process_mode != PROCESS_MODE_AUTO and not TestItemDefs.is_raw_state(item_process_state):
		Energy.claim_processing(other_player, item_payload)
	process_stage_index = _get_current_process_stage_index()
	var normalized_progress: float = process_progress / required_progress
	process_press_count = min(int(floor(normalized_progress * float(required_interact_presses))), required_interact_presses)
	process_progress_remainder = process_progress - floor(process_progress)
	if process_progress >= required_progress:
		_finish_processing(other_player)
	else:
		_update_item_visual()
		_update_station_progress_visual()
	queue_redraw()
	return true

func _is_processing_interrupted(other_player: Node) -> bool:
	return (
		cooking_process_mode != PROCESS_MODE_AUTO
		and TestItemDefs.get_process_family(output_process_state) in [&"cut", &"grind"]
		and is_instance_valid(other_player)
		and other_player.has_method("is_quicksand_processing_blocked")
		and other_player.is_quicksand_processing_blocked()
	)

func is_processing_for_blessings() -> bool:
	return has_item and processing_active

func _update_stage_process_state() -> void:
	item_process_state = CookerProcessRules.state_at_progress(output_process_state, item_process_state, process_progress / _get_required_process_progress(), _get_stage_thresholds())
	# A new raw batch earns the yield once. Reinserted boxes and individual
	# portions already carry their quantity and must never grow on reprocessing.
	if batch_servings < 0 and TestItemDefs.get_process_family(item_process_state) == &"grind":
		batch_servings = CarryItemRules.GRIND_SERVINGS + NightEventEffects.grind_yield_bonus(self)
	_update_item_visual()

func _get_nearby_support_cook_multiplier() -> float:
	return SupportFacilityAuraQuery.get_cook_multiplier(get_tree(), global_position)

func reset_state() -> void:
	_clear_item()
	instant_grind_requires_release = false
	is_highlighted = false
	set_pickup_drop_highlight(false)

func _update_item_visual() -> void:
	if item_sprite == null:
		return
	item_sprite.visible = has_item
	item_sprite.texture = item_texture
	item_sprite.scale = item_highlight_scale if is_highlighted else item_normal_scale
	var state_modulate: Color = TestItemDefs.get_item_modulate(item_process_state, item_id)
	item_sprite.modulate = state_modulate * (highlight_modulate if is_highlighted else normal_modulate)
	if is_instance_valid(process_state_mark):
		process_state_mark.scale = item_sprite.scale
		if TestItemDefs.get_process_family(item_process_state) == &"grind":
			var data: Dictionary = CarryItemRules.seasoning(item_id, item_process_state)
			if batch_servings >= 0:
				data["servings"] = batch_servings
			item_sprite.texture = TestItemDefs.get_item_texture(TestItemDefs.SEASONING_BOX_ID)
			process_state_mark.call("set_item_data", TestItemDefs.SEASONING_BOX_ID, &"", data, has_item)
		else:
			process_state_mark.call("set_item_data", item_id, item_process_state, {}, has_item)

func _draw() -> void:
	if not show_interaction_debug:
		return

	var area_rect := Rect2(interaction_area_center - interaction_area_size * 0.5, interaction_area_size)
	draw_rect(area_rect, debug_area_fill_color, true)
	draw_rect(area_rect, debug_area_outline_color, false, 2.0)

	var columns: int = max(interaction_area_columns, 1)
	var rows: int = max(interaction_area_rows, 1)
	var top_left: Vector2 = interaction_area_center - interaction_area_size * 0.5

	for y in range(rows):
		var y_ratio: float = 0.5 if rows == 1 else float(y) / float(rows - 1)
		for x in range(columns):
			var x_ratio: float = 0.5 if columns == 1 else float(x) / float(columns - 1)
			var local_position := top_left + Vector2(interaction_area_size.x * x_ratio, interaction_area_size.y * y_ratio)
			draw_circle(local_position, debug_point_radius, debug_point_fill_color)
			draw_arc(local_position, debug_point_radius, 0.0, TAU, 20, debug_point_outline_color, 2.0, true)

func _should_draw_station_progress() -> bool:
	return _is_auto_processing() or _is_overcooking()

func _update_station_progress_visual() -> void:
	if progress_view == null:
		return
	var data: Dictionary = {"visible": _should_draw_station_progress()}
	if data.visible:
		var overcooking: bool = _is_overcooking()
		data["overcooking"] = overcooking
		data["process_state"] = item_process_state
		data["progress"] = overcook_progress / _get_required_overcook_progress() if overcooking else process_progress / _get_required_process_progress()
		if not overcooking and (_uses_roast_stage_visual() or _uses_grind_stage_visual()):
			data["stage_index"] = _get_current_process_stage_index()
			data["stage_progress"] = _get_current_stage_progress()
			data["stage_thresholds"] = _get_stage_thresholds()
			data["stage_colors"] = _get_stage_colors()
			data["display_mode"] = _get_process_progress_display_mode()
	progress_view.update_station(data)

func get_current_process_stage_index() -> int:
	return _get_current_process_stage_index()

func _get_current_process_stage_index() -> int:
	return CookerProcessRules.stage_index(process_progress / _get_required_process_progress(), _get_stage_thresholds())

func _get_current_process_stage_label() -> String:
	var stage_index: int = _get_current_process_stage_index()
	if stage_index >= 0 and stage_index < stage_labels.size():
		return stage_labels[stage_index]
	return "阶段%d" % [stage_index + 1]

func _get_current_stage_progress() -> float:
	return CookerProcessRules.stage_progress(process_progress / _get_required_process_progress(), _get_stage_thresholds())

func _get_process_progress_display_mode() -> StringName:
	if _uses_roast_stage_visual():
		return &"stage_single"
	if TestItemDefs.normalize_process_state(output_process_state) == TestItemDefs.PROCESS_STATE_GRIND_FINE:
		return &"split"
	return &"single"

func _uses_roast_stage_visual() -> bool:
	return TestItemDefs.normalize_process_state(output_process_state) == TestItemDefs.PROCESS_STATE_ROAST_WELL

func _uses_grind_stage_visual() -> bool:
	return TestItemDefs.normalize_process_state(output_process_state) == TestItemDefs.PROCESS_STATE_GRIND_FINE

func _get_stage_colors() -> Array:
	if _uses_roast_stage_visual():
		return stage_fill_colors.duplicate()
	return [
		Color(0.72, 0.88, 0.42, 0.98),
		Color(0.28, 0.78, 1.0, 0.98)
	]

func _get_stage_thresholds() -> Array[float]:
	return CookerProcessRules.normalized_thresholds(stage_thresholds)
