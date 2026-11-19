extends SceneTree

const TestItemDefs = preload("res://Scripts/Kitchen/TestItemDefs.gd")

func _init() -> void:
	var failures: Array[String] = []
	var recipes := TestItemDefs.get_recipes()
	var ingredient_keys: Dictionary = {}
	var recipes_with_five_or_six_items := 0
	var fixed_medium_found := false
	var fixed_advanced_found := false

	for recipe in recipes:
		var ingredients: Array = recipe.get("ingredients", [])
		var total_count := _get_total_count(ingredients)
		if total_count > 6:
			failures.append("配方超过组合台容量：%s (%d)" % [recipe.get("output_item_id", &""), total_count])
		if total_count >= 5:
			recipes_with_five_or_six_items += 1
		var has_maturation_range := false
		for entry in ingredients:
			if entry is Dictionary and not Array(entry.get("accepted_process_states", [])).is_empty():
				has_maturation_range = true
		if int(recipe.get("difficulty", 1)) == 2 and total_count == 4 and not has_maturation_range:
			fixed_medium_found = true
		if int(recipe.get("difficulty", 1)) == 3 and total_count == 5 and not has_maturation_range:
			fixed_advanced_found = true

		var ingredient_key := _get_ingredient_and_process_family_key(ingredients)
		if ingredient_keys.has(ingredient_key):
			failures.append("存在材料和加工方式完全相同的歧义配方：%s / %s" % [ingredient_keys[ingredient_key], recipe.get("output_item_id", &"")])
		else:
			ingredient_keys[ingredient_key] = recipe.get("output_item_id", &"")

		var exact_items := _expand_recipe_items(ingredients, false)
		var exact_result: Dictionary = TestItemDefs.find_matching_recipe(exact_items, true)
		if exact_result.get("output_item_id", &"") != recipe.get("output_item_id", &""):
			failures.append("完整配方无法识别：%s" % recipe.get("output_item_id", &""))

	var lamb_recipe: Array = TestItemDefs.get_recipe_for_dish(TestItemDefs.DISH_SPICED_LAMB_ID)
	var wrong_state_items := _expand_recipe_items(lamb_recipe, true)
	if TestItemDefs.matches_recipe(wrong_state_items, lamb_recipe):
		failures.append("错误熟成度被严格配方接受")
	var loose_result: Dictionary = TestItemDefs.find_matching_recipe_with_alternate_completion(wrong_state_items)
	if loose_result.get("output_item_id", &"") != TestItemDefs.DISH_SPICED_LAMB_ID:
		failures.append("正确材料搭配错误熟成度时未能产出对应菜品")
	if String(loose_result.get("recipe_signature", "")) == TestItemDefs.get_recipe_signature(lamb_recipe):
		failures.append("错误熟成度菜品错误地获得了标准客单签名")

	var impossible_items: Array[Dictionary] = [
		{"item_id": TestItemDefs.MEAT_RED_ID, "process_state": TestItemDefs.PROCESS_STATE_NONE},
		{"item_id": TestItemDefs.TOFU_ID, "process_state": TestItemDefs.PROCESS_STATE_NONE}
	]
	if not TestItemDefs.find_matching_recipe_with_alternate_completion(impossible_items).is_empty():
		failures.append("无配方材料错误地匹配到了菜品")

	var raw_sprouts: Array[Dictionary] = [
		{"item_id": TestItemDefs.VEG_LEAF_ID, "process_state": TestItemDefs.PROCESS_STATE_NONE},
		{"item_id": TestItemDefs.VEG_LEAF_ID, "process_state": TestItemDefs.PROCESS_STATE_NONE}
	]
	if not TestItemDefs.find_matching_recipe_with_alternate_completion(raw_sprouts).is_empty():
		failures.append("两个未切的脆脆芽错误地匹配到了脆芽冷盘")
	var cut_sprouts: Array[Dictionary] = [
		{"item_id": TestItemDefs.VEG_LEAF_ID, "process_state": TestItemDefs.PROCESS_STATE_CUT},
		{"item_id": TestItemDefs.VEG_LEAF_ID, "process_state": TestItemDefs.PROCESS_STATE_CUT}
	]
	if TestItemDefs.find_matching_recipe_with_alternate_completion(cut_sprouts).get("output_item_id", &"") != TestItemDefs.DISH_CRISP_PLATE_ID:
		failures.append("两个已切的脆脆芽无法匹配脆芽冷盘")
	var trash_data: Dictionary = TestItemDefs.get_trash_item_data()
	if trash_data.get("item_id", &"") != TestItemDefs.TRASH_ID or trash_data.get("texture", null) == null:
		failures.append("垃圾产物数据或素材缺失")

	if recipes_with_five_or_six_items <= 0:
		failures.append("没有覆盖 5-6 份材料的高级配方")
	if not fixed_medium_found:
		failures.append("没有固定四份食材的中级配方")
	if not fixed_advanced_found:
		failures.append("没有固定五份食材的高级配方")

	if failures.is_empty():
		print("Assembly rules OK: %d recipes, %d recipes use 5-6 items." % [recipes.size(), recipes_with_five_or_six_items])
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)

func _get_total_count(ingredients: Array) -> int:
	var result := 0
	for entry in ingredients:
		if entry is Dictionary:
			result += int(entry.get("count", 1))
	return result

func _get_ingredient_and_process_family_key(ingredients: Array) -> String:
	var counts: Dictionary = {}
	for entry in ingredients:
		if not (entry is Dictionary):
			continue
		var item_id := String(entry.get("item_id", &""))
		var family := String(TestItemDefs.get_process_family(StringName(entry.get("process_state", TestItemDefs.PROCESS_STATE_NONE))))
		var key := "%s:%s" % [item_id, family]
		counts[key] = int(counts.get(key, 0)) + int(entry.get("count", 1))
	var parts: Array[String] = []
	for key in counts.keys():
		parts.append("%s:%d" % [key, counts[key]])
	parts.sort()
	return "|".join(parts)

func _expand_recipe_items(ingredients: Array, force_wrong_state: bool) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry in ingredients:
		if not (entry is Dictionary):
			continue
		for _index in range(int(entry.get("count", 1))):
			var process_state := StringName(entry.get("process_state", TestItemDefs.PROCESS_STATE_NONE))
			if force_wrong_state and process_state in [TestItemDefs.PROCESS_STATE_ROAST_MEDIUM, TestItemDefs.PROCESS_STATE_ROAST_WELL]:
				process_state = TestItemDefs.PROCESS_STATE_ROAST_RARE
			elif force_wrong_state and process_state == TestItemDefs.PROCESS_STATE_GRIND_COARSE:
				process_state = TestItemDefs.PROCESS_STATE_GRIND_FINE
			elif force_wrong_state and process_state == TestItemDefs.PROCESS_STATE_GRIND_FINE:
				process_state = TestItemDefs.PROCESS_STATE_GRIND_COARSE
			result.append({
				"item_id": entry.get("item_id", &""),
				"process_state": process_state
			})
	return result
