extends SceneTree

const CodexController = preload("res://Scripts/UI/CodexController.gd")
const Items = preload("res://Scripts/Kitchen/TestItemDefs.gd")

func _init() -> void:
	var controller := CodexController.new()
	root.add_child(controller)
	var entries: Array[Dictionary] = controller._get_enemy_entries()
	var failures: Array[String] = []
	if entries.size() != 13:
		failures.append("图鉴敌人数量异常：%d" % entries.size())
	var boss_ids: Array[StringName] = [&"sandworm_boss", &"scorpion_boss", &"vulture_boss", &"monitor_boss"]
	var seen_ids: Array[StringName] = []
	for entry in entries:
		var id := StringName(entry.get("id", &""))
		if id == &"" or id in seen_ids:
			failures.append("敌人图鉴 ID 缺失或重复：%s" % id)
		seen_ids.append(id)
		if entry.get("texture", null) == null:
			failures.append("敌人缺少图鉴贴图：%s" % entry.get("name", ""))
		var body := String(entry.get("body", ""))
		if not body.contains("掉落："):
			failures.append("敌人缺少掉落说明：%s" % entry.get("name", ""))
		if id in boss_ids:
			var ingredient_id := StringName(entry.get("boss_ingredient_id", &""))
			var dish_id := StringName(entry.get("boss_dish_id", &""))
			if not Items.is_boss_ingredient(ingredient_id) or not Items.is_dish(dish_id):
				failures.append("BOSS 食材或料理无效：%s" % id)
			var recipe_contains_drop := false
			for component: Dictionary in Items.get_recipe_for_dish(dish_id):
				if StringName(component.get("item_id", &"")) == ingredient_id:
					recipe_contains_drop = true
			if not recipe_contains_drop or not body.contains(Items.get_item_display_name(dish_id)) or not body.contains("通关："):
				failures.append("BOSS 料理与通关说明不完整：%s" % id)
	for boss_id in boss_ids:
		if boss_id not in seen_ids:
			failures.append("缺少 BOSS 图鉴：%s" % boss_id)
	if failures.is_empty():
		print("Codex enemy entries OK: 9 enemies and 4 bosses, with textures, drops, matching recipes and victory conditions.")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)
