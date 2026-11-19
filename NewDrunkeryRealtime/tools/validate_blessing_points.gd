extends SceneTree

const RunProgressionState = preload("res://Scripts/Core/RunProgressionState.gd")
const RunSetupController = preload("res://Scripts/Core/RunSetupController.gd")
const BlessingSelectController = preload("res://Scripts/UI/BlessingSelectController.gd")
const MAIN_SCENE := preload("res://Scenes/Main/main.tscn")

func _init() -> void:
	var progression := RunProgressionState.new()
	progression.reset(0, 0)
	_assert(progression.get_blessing_refreshes() == 3, "A new run must start with three blessing refreshes.")
	_assert(progression.get_blessing_points() == 0, "A new run must start with zero blessing points.")
	progression.add_blessing_points(2)
	_assert(progression.get_blessing_points() == 2, "Level rewards must accumulate blessing points.")

	var setup := RunSetupController.new()
	root.add_child(setup)
	var initial_snapshot: Dictionary = setup.build_progression_snapshot(null, 0, null, false)
	_assert(int(initial_snapshot.get("blessing_points", -1)) == 0, "A fresh run snapshot must start with zero blessing points.")
	var snapshot: Dictionary = setup.build_progression_snapshot(null, 0, progression, false)
	var restored := RunProgressionState.new()
	restored.reset(0, 0)
	restored.apply_snapshot(snapshot)
	_assert(restored.get_blessing_points() == 2, "Blessing points must survive progression snapshots.")
	_assert(restored.get_blessing_refreshes() == 3, "Blessing refreshes must survive progression snapshots.")

	var selector := BlessingSelectController.new()
	root.add_child(selector)
	selector.set_progression_state(restored)
	selector.enter_selection()
	_assert(selector.blessing_options.size() == 3, "Blessing selection must offer exactly three choices while the pool has enough entries.")
	var first_ids: Dictionary = {}
	for option in selector.blessing_options:
		first_ids[StringName(option.get("id", &""))] = true
	_assert(first_ids.size() == 3, "The three blessing choices must be different.")
	_assert(restored.get_seen_blessings().size() == 3, "Every shown blessing must immediately become unavailable for future rolls.")
	var old_selected_id := StringName(selector.get_selected_blessing().get("id", &""))
	_assert(selector.refresh_selected(), "L refresh should replace the currently selected blessing while unused blessings remain.")
	var new_selected_id := StringName(selector.get_selected_blessing().get("id", &""))
	_assert(new_selected_id != old_selected_id, "Refreshing one card must replace it with a different blessing.")
	_assert(restored.get_blessing_refreshes() == 2, "Refreshing one card must consume exactly one refresh.")
	_assert(restored.has_seen_blessing(new_selected_id), "A refreshed-in blessing must be marked as seen immediately.")
	var preserved_options: Array[Dictionary] = selector.blessing_options.duplicate(true)
	selector.enter_selection()
	_assert(selector.blessing_options == preserved_options, "Leaving and reopening blessing selection must preserve the current cards.")
	var seen_snapshot := setup.build_progression_snapshot(null, 0, restored, false)
	var seen_restored := RunProgressionState.new()
	seen_restored.reset(0, 0)
	seen_restored.apply_snapshot(seen_snapshot)
	_assert(seen_restored.get_seen_blessings() == restored.get_seen_blessings(), "Seen blessings must survive progression snapshots.")
	_assert(restored.spend_blessing_point(), "A blessing point must be spendable after choosing a blessing.")
	_assert(restored.get_blessing_points() == 1, "Choosing one blessing must consume exactly one point.")

	var reward_state := RunProgressionState.new()
	reward_state.reset(0, 0)
	for completed_day_index in range(6):
		_assert(reward_state.grant_completed_day_blessing_refresh(completed_day_index), "Days 1-6 must each grant one refresh.")
	_assert(reward_state.get_blessing_refreshes() == 9, "Six completed days should add six refreshes to the initial three.")
	_assert(not reward_state.grant_completed_day_blessing_refresh(6), "Day 7 must not grant a blessing refresh.")
	_assert(reward_state.get_blessing_refreshes() == 9, "Day 7 must leave refresh count unchanged.")

	var main_scene: Node = MAIN_SCENE.instantiate()
	var statue: Node = main_scene.get_node_or_null("BlessingStatue")
	_assert(statue != null, "The tavern must contain a blessing statue.")
	_assert(bool(statue.get("always_visible")), "The blessing statue must remain visible during the day.")
	_assert(bool(statue.get("movable_by_player")), "The blessing statue must use facility carrying rules.")
	_assert(StringName(statue.get("interaction_type")) == &"blessing_statue", "The statue must route night interaction to blessing selection.")
	_assert(Vector2i(statue.get("layout_footprint")) == Vector2i.ONE, "The blessing statue must occupy exactly one grid cell.")
	var map: Node2D = main_scene.get_node("PrototypeMap") as Node2D
	var tile_size: Vector2 = map.get_tile_size()
	var local_statue_position: Vector2 = map.to_local((statue as Node2D).position)
	var cell_offset: Vector2 = Vector2(fposmod(local_statue_position.x, tile_size.x), fposmod(local_statue_position.y, tile_size.y))
	_assert(cell_offset.is_equal_approx(tile_size * 0.5), "The blessing statue must start at the center of its grid cell.")
	main_scene.free()

	print("Blessing rules OK: unique offers, persistent seen pool, single-card refreshes, and day rewards.")
	quit(0)

func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
