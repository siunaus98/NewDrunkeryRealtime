extends RefCounted

const TestItemDefs = preload("res://Scripts/Kitchen/TestItemDefs.gd")

# Stateless processing policy. The station owns exports, progress and side effects.
# Threshold consumers use normalized_thresholds; duplicates retain legacy semantics.

static func can_accept_process_state(output_process_state: StringName, process_state: StringName) -> bool:
	var normalized_state := TestItemDefs.normalize_process_state(process_state)
	if TestItemDefs.is_raw_state(normalized_state):
		return true

	var station_state := TestItemDefs.normalize_process_state(output_process_state)
	var station_family := TestItemDefs.get_process_family(station_state)
	var item_family := TestItemDefs.get_process_family(normalized_state)
	if station_family != item_family:
		return false

	match station_family:
		&"roast":
			# 焦糊是烤制终点；微生、半熟、全熟都允许重新放回火候台。
			return normalized_state != TestItemDefs.PROCESS_STATE_BURNT
		&"grind":
			# 粗磨是研磨过程的中间阶段，细磨已经是终点。
			return normalized_state == TestItemDefs.PROCESS_STATE_GRIND_COARSE
		_:
			return false

static func can_continue_processing_from_state(output_process_state: StringName, process_state: StringName) -> bool:
	var normalized_state := TestItemDefs.normalize_process_state(process_state)
	if TestItemDefs.is_raw_state(normalized_state):
		return true
	var station_state := TestItemDefs.normalize_process_state(output_process_state)
	if TestItemDefs.get_process_family(station_state) != TestItemDefs.get_process_family(normalized_state):
		return false
	return normalized_state in [
		TestItemDefs.PROCESS_STATE_ROAST_RARE,
		TestItemDefs.PROCESS_STATE_ROAST_MEDIUM,
		TestItemDefs.PROCESS_STATE_GRIND_COARSE
	]

static func progress_for_state(process_state: StringName, required_progress: float, thresholds: Array[float]) -> float:
	var normalized_state := TestItemDefs.normalize_process_state(process_state)
	if TestItemDefs.is_raw_state(normalized_state):
		return 0.0
	match normalized_state:
		TestItemDefs.PROCESS_STATE_ROAST_RARE, TestItemDefs.PROCESS_STATE_GRIND_COARSE:
			return required_progress * (thresholds[0] if not thresholds.is_empty() else 0.5)
		TestItemDefs.PROCESS_STATE_ROAST_MEDIUM:
			return required_progress * (thresholds[1] if thresholds.size() > 1 else 0.67)
		TestItemDefs.PROCESS_STATE_ROAST_WELL, TestItemDefs.PROCESS_STATE_GRIND_FINE:
			return required_progress
		_:
			return 0.0

static func state_at_progress(output_process_state: StringName, current_state: StringName, normalized_progress: float, thresholds: Array[float]) -> StringName:
	var normalized_output := TestItemDefs.normalize_process_state(output_process_state)
	normalized_progress = clampf(normalized_progress, 0.0, 1.0)

	if normalized_output == TestItemDefs.PROCESS_STATE_CUT:
		return TestItemDefs.PROCESS_STATE_NONE
	elif normalized_output == TestItemDefs.PROCESS_STATE_ROAST_WELL:
		if normalized_progress >= 1.0:
			return TestItemDefs.PROCESS_STATE_ROAST_WELL
		elif thresholds.size() >= 2 and normalized_progress >= thresholds[1]:
			return TestItemDefs.PROCESS_STATE_ROAST_MEDIUM
		elif thresholds.size() >= 1 and normalized_progress >= thresholds[0]:
			return TestItemDefs.PROCESS_STATE_ROAST_RARE
		else:
			return TestItemDefs.PROCESS_STATE_NONE
	elif normalized_output == TestItemDefs.PROCESS_STATE_GRIND_FINE:
		if normalized_progress >= 1.0:
			return TestItemDefs.PROCESS_STATE_GRIND_FINE
		elif thresholds.size() >= 1 and normalized_progress >= thresholds[0]:
			return TestItemDefs.PROCESS_STATE_GRIND_COARSE
		else:
			return TestItemDefs.PROCESS_STATE_NONE
	# Legacy single-output stations retain their state until completion.
	return current_state

static func stage_index(normalized_progress: float, thresholds: Array[float]) -> int:
	normalized_progress = clampf(normalized_progress, 0.0, 1.0)
	for i in range(thresholds.size()):
		if normalized_progress < thresholds[i]:
			return i
	return thresholds.size()

static func stage_progress(normalized_progress: float, thresholds: Array[float]) -> float:
	normalized_progress = clampf(normalized_progress, 0.0, 1.0)
	var boundaries: Array[float] = [0.0]
	boundaries.append_array(thresholds)
	boundaries.append(1.0)
	var current_stage: int = mini(stage_index(normalized_progress, thresholds), boundaries.size() - 2)
	var start: float = boundaries[current_stage]
	var end: float = boundaries[current_stage + 1]
	if normalized_progress >= end:
		return 1.0
	if normalized_progress <= start:
		return 0.0
	return clampf((normalized_progress - start) / maxf(end - start, 0.001), 0.0, 1.0)

static func normalized_thresholds(stage_thresholds: Array[float]) -> Array[float]:
	var result: Array[float] = []
	for threshold in stage_thresholds:
		var normalized_threshold: float = clampf(threshold, 0.0, 1.0)
		if normalized_threshold > 0.0 and normalized_threshold < 1.0:
			result.append(normalized_threshold)
	result.sort()
	return result
