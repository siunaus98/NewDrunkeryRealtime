class_name LevelContext
extends RefCounted

enum LevelState {
	OUT_OF_LEVEL,
	NIGHT_REST,
	NIGHT_SHOP,
	NIGHT_PLANNING,
	ORDER_GROUP_SELECT,
	MENU_DISH_SELECT,
	PREPARE_PHASE,
	WAVE_ACTIVE,
	WAVE_BREAK,
	BLESSING_SELECT,
	LEVEL_SUCCESS,
	LEVEL_FAILED,
	GLOBAL_MODIFIER_SELECT,
	NIGHT_EVENT
}

var state: LevelState = LevelState.OUT_OF_LEVEL
var selected_order_group: Dictionary = {}
var current_wave_index: int = 0
var completed_orders: int = 0
var failed_orders: int = 0
var reputation_max: int = 100
var reputation: int = 100
var danger_active: bool = false
var danger_time_remaining: float = 0.0
var active_map_mechanism_ids: Array[StringName] = []
var boss_enhanced_map_mechanism_id: StringName = &""
var special_guest_arrived: bool = false

func initialize(order_group: Dictionary, new_reputation_max: int = 100) -> void:
	selected_order_group = order_group.duplicate(true)
	current_wave_index = 0
	completed_orders = 0
	failed_orders = 0
	special_guest_arrived = false
	reputation_max = max(new_reputation_max, 1)
	reputation = reputation_max
	danger_active = false
	danger_time_remaining = 0.0
	active_map_mechanism_ids.clear()
	var mechanism_values: Variant = selected_order_group.get("map_mechanism_ids", [])
	if mechanism_values is Array:
		for mechanism_value in mechanism_values:
			active_map_mechanism_ids.append(StringName(mechanism_value))
	boss_enhanced_map_mechanism_id = StringName(selected_order_group.get("boss_enhanced_map_mechanism_id", &""))
	state = LevelState.ORDER_GROUP_SELECT

func get_selected_group_name() -> String:
	return String(selected_order_group.get("display_name", ""))

func get_active_map_mechanism_ids() -> Array[StringName]:
	return active_map_mechanism_ids.duplicate()

func get_boss_enhanced_map_mechanism_id() -> StringName:
	return boss_enhanced_map_mechanism_id

func get_waves() -> Array:
	var waves: Variant = selected_order_group.get("waves", [])
	return waves if waves is Array else []

func has_remaining_waves() -> bool:
	return current_wave_index < get_waves().size()

func get_current_wave() -> Dictionary:
	if not has_remaining_waves():
		return {}
	var waves: Array = get_waves()
	var wave_data: Variant = waves[current_wave_index]
	return wave_data.duplicate(true) if wave_data is Dictionary else {}

func advance_wave() -> void:
	current_wave_index += 1

func get_total_order_count() -> int:
	var total: int = 0
	for wave_data in get_waves():
		var orders: Variant = wave_data.get("orders", [])
		if orders is Array:
			total += orders.size()
	return total

func record_order_completed(order_data: Dictionary) -> void:
	completed_orders += 1

func record_order_failed(order_data: Dictionary) -> void:
	failed_orders += 1
	reputation = max(reputation - int(order_data.get("reputation_penalty", 0)), 0)
