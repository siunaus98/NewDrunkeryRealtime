extends RefCounted

const TestItemDefs = preload("res://Scripts/Kitchen/TestItemDefs.gd")

# Pure menu-derived requirements. The flow owns when to apply these results.
static func collect_ingredient_ids(menu_dish_ids: Array[StringName]) -> Array[StringName]:
	var result: Array[StringName] = []
	for dish_id in menu_dish_ids:
		for entry in TestItemDefs.get_display_recipe_for_dish(dish_id):
			if not (entry is Dictionary):
				continue
			var item_id := StringName(entry.get("item_id", &""))
			if TestItemDefs.is_ingredient(item_id) and item_id not in result:
				result.append(item_id)
	return result

static func collect_process_states(menu_dish_ids: Array[StringName]) -> Array[StringName]:
	var result: Array[StringName] = []
	for dish_id in menu_dish_ids:
		for entry in TestItemDefs.get_display_recipe_for_dish(dish_id):
			if not (entry is Dictionary):
				continue
			for process_state in TestItemDefs.get_recipe_entry_process_states(entry):
				var station_state := TestItemDefs.get_station_output_state(StringName(process_state))
				if station_state != TestItemDefs.PROCESS_STATE_NONE and station_state not in result:
					result.append(station_state)
	return result
