extends SceneTree

const TestItemDefs = preload("res://Scripts/Kitchen/TestItemDefs.gd")

func _init() -> void:
	var ranked: Array[Dictionary] = []
	for item_id in TestItemDefs.get_all_ingredient_ids():
		if TestItemDefs.is_boss_ingredient(item_id):
			continue
		ranked.append({
		"item_id": item_id,
		"rank": TestItemDefs.get_ingredient_value_rank(item_id),
		"source": TestItemDefs.get_ingredient_source(item_id),
		"forage_yield": TestItemDefs.get_forage_yield_range(item_id),
		"battle_drop": TestItemDefs.get_battle_drop_quantity(item_id, 1)
		})
	ranked.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["rank"]) < int(b["rank"]))
	var seen: Dictionary = {}
	var failures: Array[String] = []
	for entry in ranked:
		var rank := int(entry["rank"])
		if seen.has(rank):
			failures.append("食材价值排名重复：%d" % rank)
		seen[rank] = true
		print("%02d  %-18s source=%s forage=%s battle_drop=%d" % [
			rank,
			TestItemDefs.get_item_display_name(entry["item_id"]),
			entry["source"],
			entry["forage_yield"],
			entry["battle_drop"]
		])
	if ranked.size() != 12:
		failures.append("基础食材数量不是12：%d" % ranked.size())
	for item_id in TestItemDefs.get_all_ingredient_ids():
		if TestItemDefs.is_boss_ingredient(item_id):
			continue
		var source := TestItemDefs.get_ingredient_source(item_id)
		if source == &"forage_only" and TestItemDefs.can_drop_ingredient_from_battle(item_id):
			failures.append("采集限定食材错误进入战斗掉落：%s" % item_id)
		var yield_range := TestItemDefs.get_forage_yield_range(item_id)
		if source == &"battle_only" and yield_range != Vector2i.ZERO:
			failures.append("战斗限定食材错误拥有采集产量：%s" % item_id)
		if source != &"battle_only" and yield_range.x <= 0:
			failures.append("可采集食材没有正向产量：%s" % item_id)
	var meat_ids: Array[StringName] = [TestItemDefs.MEAT_RED_ID, TestItemDefs.MEAT_WHITE_ID, TestItemDefs.SHRIMP_ID, TestItemDefs.CAMEL_MEAT_ID]
	for meat_id in meat_ids:
		for non_meat_id in TestItemDefs.get_all_ingredient_ids():
			if non_meat_id in meat_ids or TestItemDefs.is_boss_ingredient(non_meat_id):
				continue
			if TestItemDefs.get_ingredient_acquisition_tier(meat_id) == TestItemDefs.get_ingredient_acquisition_tier(non_meat_id) and TestItemDefs.get_ingredient_value_rank(meat_id) <= TestItemDefs.get_ingredient_value_rank(non_meat_id):
				failures.append("同获取层级肉类未高于非肉类：%s <= %s" % [meat_id, non_meat_id])
	if failures.is_empty():
		print("Ingredient economy rules OK: 12 unique ranks, source gates, and yields.")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)
