extends SceneTree

const Items = preload("res://Scripts/Kitchen/TestItemDefs.gd")
const Rules = preload("res://Scripts/Kitchen/CookerProcessRules.gd")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)

func _stop_ticks(node: Node) -> void:
	node.set_process(false)
	node.set_physics_process(false)
	for child in node.get_children():
		_stop_ticks(child)

func _run() -> void:
	var main: Node = load("res://Scenes/Main/main.tscn").instantiate()
	root.add_child(main)
	await physics_frame
	_stop_ticks(main)
	paused = false
	var player: Node = main.get_node("Player")
	for scene_name in ["bake_cooker", "grind_cooker"]:
		var station: Node = load("res://Scenes/Restaurant/%s.tscn" % scene_name).instantiate()
		main.add_child(station)
		_stop_ticks(station)
		var states: Array[StringName] = [Items.PROCESS_STATE_NONE, Items.PROCESS_STATE_GRIND_COARSE, Items.PROCESS_STATE_GRIND_FINE]
		if scene_name == "bake_cooker":
			states = [Items.PROCESS_STATE_NONE, Items.PROCESS_STATE_ROAST_RARE, Items.PROCESS_STATE_ROAST_MEDIUM, Items.PROCESS_STATE_ROAST_WELL]
		# Read scene configuration first, then verify edits made after _ready remain live.
		_check_stage_boundaries(station, states)
		station.required_process_progress = 200.0
		var edited_thresholds: Array[float] = [0.4]
		if scene_name == "bake_cooker":
			edited_thresholds.assign([0.25, 0.75])
		station.stage_thresholds = edited_thresholds
		_check_stage_boundaries(station, states)
		for stage in range(1, states.size() - 1):
			station.reset_state()
			player.clear_held_item()
			player.pick_up_item(Items.TEST_ITEM_ID, null, states[stage])
			_check(station.receive_item_from_player(player), "Intermediate food must be accepted.")
			var threshold: float = station.stage_thresholds[stage - 1]
			_check(is_equal_approx(station.process_progress, threshold * 200.0) and station.processing_active, "Reinsertion must resume at its stage boundary using current exports.")
			station.process_progress += 1.0
			_check(station.take_item_to_player(player), "Intermediate food must remain removable.")
			_check(not station.has_item and station.process_progress == 0.0, "Removal must clear station progress.")
			_check(station.receive_item_from_player(player), "Removed food must be reinsertable.")
			_check(is_equal_approx(station.process_progress, threshold * 200.0), "Reinsertion restores the food stage, not discarded partial progress.")
		if scene_name == "bake_cooker":
			station.reset_state()
			player.clear_held_item()
			player.pick_up_item(Items.TEST_ITEM_ID, null, Items.PROCESS_STATE_ROAST_WELL)
			_check(station.receive_item_from_player(player), "Well-done food must still be accepted.")
			_check(not station.processing_active and station._is_overcooking(), "Well-done food goes directly into the overcook window.")
			station._advance_overcook(station.overcook_duration)
			_check(station.item_process_state == Items.PROCESS_STATE_BURNT, "Reinserted well-done food must burn normally.")
		station.queue_free()
		await process_frame
	var cut: Node = load("res://Scenes/Restaurant/test_cooker.tscn").instantiate()
	main.add_child(cut)
	_stop_ticks(cut)
	player.clear_held_item()
	player.pick_up_item(Items.TEST_ITEM_ID, null)
	_check(cut.receive_item_from_player(player), "Cutting must accept raw food.")
	cut._advance_processing(0.0, player, true)
	_check(cut.item_process_state == Items.PROCESS_STATE_NONE and not cut.can_take_item(player), "Partial cutting stays raw and cannot be removed.")
	for press in range(cut.required_interact_presses + 1):
		if cut.processing_active:
			cut._advance_processing(0.0, player, true)
	_check(cut.item_process_state == Items.PROCESS_STATE_CUT and cut.can_take_item(player), "Finished cutting must become removable cut food.")
	_check(not player.is_holding_item() and cut.has_item, "Finishing cutting with an actual player leaves food on the station.")
	_check(cut.take_item_to_player(player) and player.get_held_item_process_state() == Items.PROCESS_STATE_CUT, "Only explicit pickup takes completed cutting output.")
	var raw_thresholds: Array[float] = [0.75, -0.1, 0.25, 1.0, 0.25, 1.5]
	var thresholds: Array[float] = Rules.normalized_thresholds(raw_thresholds)
	_check(thresholds == [0.25, 0.25, 0.75] and raw_thresholds[0] == 0.75, "Threshold normalization must sort/filter without mutating exports or removing duplicates.")
	_check(Rules.stage_index(0.25, thresholds) == 2 and Rules.stage_progress(0.25, thresholds) == 0.0, "Equal thresholds must advance past both boundaries without division errors.")
	_check(Rules.stage_progress(0.5, []) == 0.5 and Rules.progress_for_state(Items.PROCESS_STATE_ROAST_MEDIUM, 200.0, []) == 134.0, "Empty thresholds retain single-stage progress and legacy restore defaults.")
	_check(Rules.state_at_progress(Items.PROCESS_STATE_BOIL, Items.PROCESS_STATE_NONE, 0.9, []) == Items.PROCESS_STATE_NONE, "Legacy single-output stations retain raw food until completion.")
	main.queue_free()
	await process_frame
	if failures.is_empty():
		print("PASS: real cooker stage boundaries, live exports, partial-food reinsertion, well-done overcook, cutting lock and threshold edge cases.")
	quit(0 if failures.is_empty() else 1)

func _check_stage_boundaries(station: Node, states: Array[StringName]) -> void:
	var thresholds: Array[float] = station.stage_thresholds
	for index in range(thresholds.size()):
		var threshold: float = thresholds[index]
		station.process_progress = (threshold - 0.0001) * station.required_process_progress
		station._update_stage_process_state()
		_check(station.item_process_state == states[index] and station.get_current_process_stage_index() == index, "Just below a boundary, food and UI must stay in the previous stage.")
		station.process_progress = threshold * station.required_process_progress
		station._update_stage_process_state()
		_check(station.item_process_state == states[index + 1] and station.get_current_process_stage_index() == index + 1, "At a boundary, food and UI must enter the next stage together.")
		_check(is_zero_approx(station._get_current_stage_progress()), "New stage progress must start at zero.")
	station.process_progress = station.required_process_progress
	station._update_stage_process_state()
	_check(station.item_process_state == states.back() and station._get_current_stage_progress() == 1.0, "Full progress must produce the final stage and a full bar.")
