extends RefCounted

const LevelRefs = preload("res://Scripts/Core/LevelRefs.gd")

static func multiplier(facility: Node, key: StringName) -> float:
	if Engine.is_editor_hint():
		return 1.0
	var flow: Node
	var cached: WeakRef = facility.get_meta("event_flow_ref") if facility.has_meta("event_flow_ref") else null
	if cached != null:
		flow = cached.get_ref()
	if flow == null:
		var refs := LevelRefs.find_from(facility)
		flow = refs.get_level_flow_controller() if refs != null else null
		if flow != null:
			facility.set_meta("event_flow_ref", weakref(flow))
	if flow == null or flow.progression_state == null:
		return 1.0
	var events = flow.progression_state.events
	match key:
		&"roast": return events.roast_speed
		&"burn": return events.burn_speed
		&"wash": return events.wash_speed
	return 1.0

static func grind_yield_bonus(facility: Node) -> int:
	var flow: Node = _get_flow(facility)
	return int(flow.progression_state.events.grind_yield_bonus) if flow != null and flow.progression_state != null else 0

static func _get_flow(facility: Node) -> Node:
	var refs := LevelRefs.find_from(facility)
	return refs.get_level_flow_controller() if refs != null else null
