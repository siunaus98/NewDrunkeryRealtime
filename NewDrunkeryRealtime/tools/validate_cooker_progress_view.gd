extends SceneTree

const Context = preload("res://Scripts/Core/LevelContext.gd")
const Items = preload("res://Scripts/Kitchen/TestItemDefs.gd")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _stop_ticks(node: Node) -> void:
	node.set_process(false)
	node.set_physics_process(false)
	for child in node.get_children():
		_stop_ticks(child)

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)

func _run() -> void:
	var main: Node = load("res://Scenes/Main/main.tscn").instantiate()
	root.add_child(main)
	await physics_frame
	_stop_ticks(main)
	paused = false
	var flow: Node = main.get_node("LevelFlowController")
	flow.run_context.state = Context.LevelState.PREPARE_PHASE
	var player: Node = main.get_node("Player")
	for scene_name in ["test_cooker", "grind_cooker", "bake_cooker"]:
		var station: Node = load("res://Scenes/Restaurant/%s.tscn" % scene_name).instantiate()
		main.add_child(station)
		_stop_ticks(station)
		var view: RefCounted = station.progress_view
		var bar: Node2D = view.station_bar
		_check(not bar.visible, "Empty station starts with hidden cooking progress.")
		_check(not station.has_node("LivingBlockProgressBar"), "Removed immobilization UI must not be created.")
		_check(bar.position == station.station_progress_offset and bar.size == station.station_progress_size and bar.z_index == 100, "Cooking bar dimensions, offset and sorting are preserved.")
		player.clear_held_item()
		player.pick_up_item(Items.TEST_ITEM_ID, null)
		_check(station.receive_item_from_player(player), "Station must accept its ingredient.")
		station.process_progress = station._get_required_process_progress() * 0.5
		station._update_stage_process_state()
		station._update_station_progress_visual()
		var saved_progress: float = station.process_progress
		var saved_state: StringName = station.item_process_state
		station._update_station_progress_visual()
		_check(station.process_progress == saved_progress and station.item_process_state == saved_state, "Rendering must not change progress or the ingredient stage.")
		if scene_name == "bake_cooker":
			_check(bar.visible and bar.display_mode == &"stage_single" and bar.stage_index == 1, "Roasting must show its current stage independently.")
			_check(is_equal_approx(bar.stage_progress, station._get_current_stage_progress()), "Roast stage fill must match the processing thresholds.")
			_check(bar.maturity_icon.texture == Items.get_process_icon_texture(station.item_process_state), "Roasting shows its actual current maturity icon.")
			station._advance_processing(100.0, null)
			station._advance_overcook(station.overcook_duration * 0.5)
			_check(bar.visible and bar.display_mode == &"single" and bar.fill_color == Color("995a32"), "Overcooking must switch to a brown single progress bar.")
			_check(bar.maturity_icon.texture == Items.get_process_icon_texture(Items.PROCESS_STATE_ROAST_WELL), "The brown warning bar must retain the actual well-done maturity icon.")
			_check(is_equal_approx(bar.progress, 0.5), "Overcooking must show its own progress.")
			station._advance_overcook(100.0)
			_check(not bar.visible and station.item_process_state == Items.PROCESS_STATE_BURNT, "Burnt food must stop the cooking bar.")
		else:
			_check(not bar.visible, "Manual processing must use the player interaction bar, not a station bar.")
			var data: Dictionary = station.get_interaction_progress_data(player)
			_check(not data.is_empty() and is_equal_approx(data.get("progress", 0.0), 0.5), "Manual processing must retain its interaction progress data.")
			_check(data.get("display_mode") == (&"split" if scene_name == "grind_cooker" else &"single"), "Grinding and cutting must keep their distinct progress display modes.")
			if scene_name == "grind_cooker":
				player.interaction_controller._set_current_interaction_target(station)
				player.interaction_controller.update_interaction_progress_ui()
				var manual_bar: Node2D = player.interaction_progress_bar
				_check(manual_bar.visible and manual_bar.maturity_icon.texture == Items.get_process_icon_texture(Items.PROCESS_STATE_GRIND_COARSE), "Grinding must display current coarse maturity beside the player's progress bar.")
				player.interaction_controller._set_current_interaction_target(null)
				player.interaction_controller.update_interaction_progress_ui()
				_check(not manual_bar.visible and not manual_bar.maturity_icon.visible, "Changing focus must clear the manual maturity icon.")
		station.reset_state()
		_check(not bar.visible, "Clearing the ingredient must immediately hide the station bar.")
		for refresh in range(3):
			station._update_station_progress_visual()
		_check(station.get_node("StationProgressBar") == bar, "Repeated updates must reuse the existing nodes.")
		station.queue_free()
		await process_frame
		_check(not is_instance_valid(bar), "Freeing a station must free all progress visual children.")
	main.queue_free()
	await process_frame
	if failures.is_empty():
		print("PASS: real cut/grind/roast bars, stage and overcook transitions, explicit maturity, reset, read-only rendering and node cleanup.")
	quit(0 if failures.is_empty() else 1)
