extends SceneTree

const MapMechanismDefs = preload("res://Scripts/Core/MapMechanismDefs.gd")
const RunProgressionState = preload("res://Scripts/Core/RunProgressionState.gd")
const RunSetupController = preload("res://Scripts/Core/RunSetupController.gd")
const LevelContext = preload("res://Scripts/Core/LevelContext.gd")

func _init() -> void:
	var progression := RunProgressionState.new()
	progression.reset(0, 0, 10405)
	var order := progression.get_map_mechanism_order()
	_assert(order.size() == 3, "Map mechanism order must contain exactly three entries.")
	_assert(_unique_count(order) == 3, "Map mechanism order must not contain duplicates.")
	for mechanism_id in order:
		_assert(mechanism_id in MapMechanismDefs.MECHANISM_IDS, "Map mechanism order contains an unknown mechanism.")
	_assert(progression.get_active_map_mechanism_ids(0).size() == 0, "Day 1 must not expose a map mechanism.")
	_assert(progression.get_active_map_mechanism_ids(1).size() == 1, "Day 2 must unlock the first map mechanism.")
	_assert(progression.get_active_map_mechanism_ids(2).size() == 2, "Day 3 must unlock the first two map mechanisms.")
	_assert(progression.get_active_map_mechanism_ids(3).size() == 3, "Day 4 must unlock all three map mechanisms.")
	_assert(progression.get_active_map_mechanism_ids(6).size() == 3, "Days 7 and later must retain all three mechanisms.")
	_assert(progression.get_boss_enhanced_map_mechanism_id(0) == &"", "Day 1 must not have a Boss pairing.")
	_assert(progression.get_boss_enhanced_map_mechanism_id(2) == &"", "Day 3 must not have a Boss-enhanced mechanism.")
	_assert(progression.get_boss_enhanced_map_mechanism_id(3) == order[0], "Day 4 Boss must enhance the day-2 mechanism.")
	_assert(progression.get_boss_enhanced_map_mechanism_id(4) == &"", "Day 5 must not retain the day-4 Boss enhancement flag.")

	var setup := RunSetupController.new()
	var snapshot: Dictionary = setup.build_progression_snapshot(null, 3, progression, false)
	var restored := RunProgressionState.new()
	restored.reset(0, 0, 20406)
	restored.apply_snapshot(snapshot)
	_assert(restored.get_map_mechanism_order() == order, "Map mechanism order must survive progression snapshots.")
	var context := LevelContext.new()
	context.initialize({
		"map_mechanism_ids": restored.get_active_map_mechanism_ids(3),
		"boss_enhanced_map_mechanism_id": restored.get_boss_enhanced_map_mechanism_id(3)
	})
	_assert(context.get_active_map_mechanism_ids().size() == 3, "Level context must expose all active day-4 mechanisms.")
	_assert(context.get_boss_enhanced_map_mechanism_id() == order[0], "Level context must expose the day-4 Boss pairing.")
	setup.free()

	print("Map mechanism rules OK: persistent order, day 2-4 unlocks, and day 4 Boss pairing.")
	quit(0)

func _unique_count(values: Array[StringName]) -> int:
	var unique: Dictionary = {}
	for value in values:
		unique[value] = true
	return unique.size()

func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
