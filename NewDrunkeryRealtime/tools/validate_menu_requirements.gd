extends SceneTree

const Items = preload("res://Scripts/Kitchen/TestItemDefs.gd")
const Query = preload("res://Scripts/Core/MenuRequirementsQuery.gd")
var failures: int = 0

func _initialize() -> void:
	var menus: Array[Array] = []
	var first: Array[StringName] = [Items.DISH_RED_ID]
	var second: Array[StringName] = [Items.DISH_SPICED_LAMB_ID, Items.DISH_CRISP_PLATE_ID]
	var third: Array[StringName] = [Items.DISH_SPICED_LAMB_ID, Items.DISH_SPICED_LAMB_ID]
	menus.append(first)
	menus.append(second)
	menus.append(third)
	for menu in menus:
		var expected_ids: Array[StringName] = []
		var expected_states: Array[StringName] = []
		for dish_id in menu:
			for entry in Items.get_display_recipe_for_dish(dish_id):
				if not (entry is Dictionary):
					continue
				var item_id := StringName(entry.get("item_id", &""))
				if Items.is_ingredient(item_id) and item_id not in expected_ids:
					expected_ids.append(item_id)
				for process_state in Items.get_recipe_entry_process_states(entry):
					var station_state := Items.get_station_output_state(StringName(process_state))
					if station_state != Items.PROCESS_STATE_NONE and station_state not in expected_states:
						expected_states.append(station_state)
		var actual_ids: Array[StringName] = Query.collect_ingredient_ids(menu)
		_check(actual_ids == expected_ids, "Ingredient requirements must preserve recipe order and remove duplicates: %s != %s" % [actual_ids, expected_ids])
		_check(Query.collect_process_states(menu) == expected_states, "Processing requirements must preserve first-seen station order and remove duplicates.")
	var empty_menu: Array[StringName] = []
	_check(Query.collect_ingredient_ids(empty_menu).is_empty() and Query.collect_process_states(empty_menu).is_empty(), "An empty menu must produce no requirements.")
	_check(Query.collect_ingredient_ids(first).duplicate() == Query.collect_ingredient_ids(first), "Pure queries must be repeatable without shared state.")
	if failures == 0:
		print("PASS: menu ingredient/process requirements, order, deduplication, empty menus and repeatability.")
	quit(0 if failures == 0 else 1)

func _check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)
