extends SceneTree

const RunProgressionState = preload("res://Scripts/Core/RunProgressionState.gd")
const AttributeForgeDefs = preload("res://Scripts/Progression/AttributeForgeDefs.gd")

func _initialize() -> void:
	var state := RunProgressionState.new()
	state.reset(0)
	var attrs := AttributeForgeDefs.ATTRIBUTE_NAMES.keys()
	assert(attrs.size() == 9, "attribute pool should contain 9 attributes")
	var ids: Array[StringName] = []
	for i in range(3):
		ids.append(StringName(attrs[i]))
	assert(ids.size() == ids.duplicate().size(), "forge options must use distinct attributes")
	state.add_forged_attribute({"attribute_id": ids[0], "fixed": 10.0})
	assert(float(state.get_forged_attribute(ids[0]).get("fixed", 0.0)) == 10.0, "forged attribute should persist")
	var snapshot := state.get_snapshot()
	var restored := RunProgressionState.new()
	restored.apply_snapshot(snapshot)
	assert(float(restored.get_forged_attribute(ids[0]).get("fixed", 0.0)) == 10.0, "forged attribute should survive snapshot")
	print("validate_attribute_forge: PASS")
	quit()
