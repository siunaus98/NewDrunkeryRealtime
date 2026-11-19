extends SceneTree

const TestItemDefs = preload("res://Scripts/Kitchen/TestItemDefs.gd")

func _init() -> void:
	for dish_id in TestItemDefs.get_all_dish_ids():
		var profile := TestItemDefs.get_dish_balance_profile(dish_id)
		print("%-24s cat=%-10s lv=%d n=%d method=%d mature=%d tier=%d value=%d gold=%d wait=%.1f" % [
			TestItemDefs.get_item_display_name(dish_id),
			profile.get("category", &""),
			int(profile.get("level", 0)),
			int(profile.get("ingredient_count", 0)),
			int(profile.get("method_complexity", 0)),
			int(profile.get("maturation_complexity", 0)),
			int(profile.get("ingredient_tier_score", 0)),
			int(profile.get("ingredient_value_score", 0)),
			TestItemDefs.get_dish_gold_reward(dish_id),
			TestItemDefs.get_dish_patience_duration(dish_id)
		])
	quit(0)
