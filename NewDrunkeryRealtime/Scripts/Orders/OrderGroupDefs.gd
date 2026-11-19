class_name OrderGroupDefs
extends RefCounted

const TestItemDefs = preload("res://Scripts/Kitchen/TestItemDefs.gd")
const SPECIAL_GUEST_TAKE_DURATION: float = 60.0
const SPECIAL_GUEST_PATIENCE_DURATION: float = 600.0
const ELITE_CUSTOMER_CHANCE: float = 0.30

const CUSTOMER_NAMES := [
	"娜菲", "哈山", "梅伦", "阿姬", "赛特",
	"伊莲", "卡里", "露塔", "帕夏", "奈布",
	"索贝", "塔娅", "阿映", "米娜", "荷鲁"
]

static func create_advanced_dish_playtest_group() -> Dictionary:
	# A sampled set kept stable across restarts so cooking issues are repeatable.
	var dishes: Array[StringName] = [TestItemDefs.DISH_ROYAL_ROAST_PLATE_ID, TestItemDefs.DISH_CAMEL_DOUBLE_ROAST_ID, TestItemDefs.DISH_STONEFLOWER_HONEY_FEAST_ID]
	var waves: Array = []
	for index in dishes.size():
		var order := _order("TEST-%02d" % (index + 1), index + 1, dishes[index], 0.0)
		order["order_take_patience_duration"] = 5.0
		order["patience_duration"] = 120.0
		waves.append(_wave(index + 1, [order]))
	var group := _group(&"advanced_dish_playtest", 0, "高级料理试玩", "依次测试王庭烤拼、驼肉双烧、砂冠花蜜宴，每波一位客人。", [], [], [&"chaser", &"sprinter"], 4.0, waves)
	group["menu_dish_ids"] = dishes
	group["service_duration"] = 2400.0
	group["allowed_meats"] = _collect_recipe_items_by_kind(dishes, true)
	group["allowed_veggies"] = _collect_recipe_items_by_kind(dishes, false)
	return group

static func create_boss_completion_playtest_group(mechanism_id: StringName) -> Dictionary:
	var special_orders := get_boss_special_orders(mechanism_id)
	var dishes: Array[StringName] = []
	for order_data in special_orders:
		dishes.append(StringName(order_data.get("dish_item_id", &"")))
	var group := _group(
		&"boss_completion_playtest",
		0,
		"Boss 通关试玩",
		"快速击败 Boss，并完成特殊客人的三道料理。",
		_collect_recipe_items_by_kind(dishes, true),
		_collect_recipe_items_by_kind(dishes, false),
		[&"chaser", &"sprinter", &"ranged"],
		2.0,
		[_wave(1, [])]
	)
	group["menu_dish_ids"] = dishes
	group["prepare_duration"] = 6.0
	group["service_duration"] = 20.0
	group["boss_enhanced_map_mechanism_id"] = mechanism_id
	group["boss_health_override"] = 300
	return group

static func create_default_order_groups(day_index: int = -1) -> Array[Dictionary]:
	var groups: Array[Dictionary] = [
		_group(&"d1_cactus_intro", 0, "第一日 料理台入门", "先认识处理台、研磨台和火候台，再把最简单的订单送出去。", [TestItemDefs.MEAT_RED_ID, TestItemDefs.MEAT_WHITE_ID], [TestItemDefs.VEG_LEAF_ID, TestItemDefs.VEG_ROOT_ID], [&"chaser", &"sprinter"], 4.5, [
			_wave(1, [_order("01", 3, TestItemDefs.DISH_RED_ROLL_ID, 44.0), _order("02", 6, TestItemDefs.DRINK_OASIS_WINE_ID, 44.0)]),
			_wave(2, [_order("03", 4, TestItemDefs.DISH_CRISP_PLATE_ID, 42.0), _order("04", 7, TestItemDefs.DISH_GOLDEN_FLATBREAD_ID, 46.0)]),
			_wave(3, [_order("05", 2, TestItemDefs.DISH_RED_ROLL_ID, 44.0), _order("06", 8, TestItemDefs.DISH_CRISP_PLATE_ID, 44.0)])
		]),
		_group(&"d1_oasis_herbs", 0, "第一日 组合台识读", "小菜先走，主菜后走，让玩家知道组合台负责什么。", [TestItemDefs.MEAT_WHITE_ID], [TestItemDefs.MUSHROOM_ID, TestItemDefs.TOFU_ID, TestItemDefs.CABBAGE_ID, TestItemDefs.EGG_ID], [&"chaser", &"ranged"], 4.5, [
			_wave(1, [_order("01", 2, TestItemDefs.DISH_DRYFROST_ROLL_ID, 44.0), _order("02", 6, TestItemDefs.DISH_STONEFLOWER_BAKED_CUP_ID, 44.0)]),
			_wave(2, [_order("03", 3, TestItemDefs.DISH_DRYFROST_ROLL_ID, 46.0), _order("04", 7, TestItemDefs.DISH_QINGMEI_SWEET_BOWL_ID, 42.0)]),
			_wave(3, [_order("05", 1, TestItemDefs.DISH_STONEFLOWER_BAKED_CUP_ID, 46.0), _order("06", 8, TestItemDefs.DISH_DRYFROST_ROLL_ID, 44.0)])
		]),
		_group(&"d1_sand_potato", 0, "第一日 火候窗口", "把火候台的等待和收手时机先学会。", [TestItemDefs.MEAT_RED_ID, TestItemDefs.SHRIMP_ID], [TestItemDefs.VEG_ROOT_ID, TestItemDefs.RICE_ID, TestItemDefs.MUSHROOM_ID], [&"sprinter", &"ranged"], 4.0, [
			_wave(1, [_order("01", 3, TestItemDefs.DISH_GOLDEN_FLATBREAD_ID, 46.0), _order("02", 5, TestItemDefs.DISH_HARE_SKEWER_ID, 46.0)]),
			_wave(2, [_order("03", 2, TestItemDefs.DISH_SAND_POTATO_CUTLET_ID, 42.0), _order("04", 6, TestItemDefs.DISH_STONEFLOWER_BAKED_CUP_ID, 46.0)]),
			_wave(3, [_order("05", 4, TestItemDefs.DISH_GOLDEN_FLATBREAD_ID, 46.0), _order("06", 8, TestItemDefs.DISH_HARE_SKEWER_ID, 48.0)])
		]),
		_group(&"d1_sunseed_oil", 0, "第一日 研磨与调味", "让玩家开始把碎金子、太阳籽和香草联想到研磨台。", [TestItemDefs.MEAT_RED_ID, TestItemDefs.MEAT_WHITE_ID], [TestItemDefs.SUN_SEED_ID, TestItemDefs.RICE_ID, TestItemDefs.VEG_LEAF_ID], [&"chaser", &"slammer"], 4.5, [
			_wave(1, [_order("01", 2, TestItemDefs.DISH_SUNSEED_CRISP_ID, 46.0), _order("02", 4, TestItemDefs.DISH_GOLDEN_FOWL_CAKE_ID, 48.0)]),
			_wave(2, [_order("03", 6, TestItemDefs.DISH_DRYFROST_MEAT_WRAP_ID, 48.0), _order("04", 7, TestItemDefs.DISH_SUNRISE_BANQUET_ID, 44.0)]),
			_wave(3, [_order("05", 1, TestItemDefs.DISH_SUNSEED_CRISP_ID, 46.0), _order("06", 8, TestItemDefs.DISH_GOLDEN_FOWL_CAKE_ID, 48.0)])
		]),
		_group(&"d1_market_mix", 0, "第一日 菜单确认", "一眼能看懂当前菜单需要哪些台、哪些食材、哪些成品。", [TestItemDefs.MEAT_RED_ID, TestItemDefs.SHRIMP_ID], [TestItemDefs.VEG_LEAF_ID, TestItemDefs.VEG_ROOT_ID, TestItemDefs.COCONUT_ID, TestItemDefs.SUN_SEED_ID, TestItemDefs.CABBAGE_ID], [&"chaser", &"sprinter", &"ranged"], 4.0, [
			_wave(1, [_order("01", 2, TestItemDefs.DISH_CRISP_PLATE_ID, 42.0), _order("02", 4, TestItemDefs.DISH_DRYFROST_ROLL_ID, 42.0), _order("03", 6, TestItemDefs.DISH_HARE_SKEWER_ID, 46.0)]),
			_wave(2, [_order("04", 3, TestItemDefs.DISH_GOLDEN_FOWL_CAKE_ID, 48.0), _order("05", 7, TestItemDefs.DISH_STONEFLOWER_BAKED_CUP_ID, 46.0)]),
			_wave(3, [_order("06", 1, TestItemDefs.DISH_CRISP_PLATE_ID, 44.0), _order("07", 8, TestItemDefs.DISH_HARE_SKEWER_ID, 48.0)])
		]),
		_group(&"d2_spice_heat", 1, "第二日 莳萝热锅", "莳萝和肉类组合变多，炒锅压力开始上升。", [TestItemDefs.MEAT_RED_ID, TestItemDefs.SHRIMP_ID], [TestItemDefs.MUSHROOM_ID, TestItemDefs.VEG_LEAF_ID, TestItemDefs.VEG_ROOT_ID], [&"sprinter", &"slammer", &"sniper"], 5.5, [
			_wave(1, [_order("01", 1, TestItemDefs.DISH_HARE_SKEWER_ID, 27.0), _order("02", 5, TestItemDefs.DISH_ROYAL_ROAST_PLATE_ID, 36.0)]),
			_wave(2, [_order("03", 3, TestItemDefs.DISH_SPICED_LAMB_ID, 38.0), _order("04", 8, TestItemDefs.DISH_CAMEL_DOUBLE_ROAST_ID, 44.0)])
		]),
		_group(&"d2_frost_leaf", 1, "第二日 旱霜菜席", "火候台和凉菜穿插，考验半成品识别。", [TestItemDefs.MEAT_WHITE_ID], [TestItemDefs.CABBAGE_ID, TestItemDefs.VEG_LEAF_ID, TestItemDefs.EGG_ID, TestItemDefs.TOFU_ID], [&"chaser", &"bruiser", &"sniper"], 5.0, [
			_wave(1, [_order("01", 2, TestItemDefs.DISH_DRYFROST_ROLL_ID, 34.0), _order("02", 6, TestItemDefs.DISH_STONEFLOWER_COLD_PLATE_ID, 42.0)]),
			_wave(2, [_order("03", 4, TestItemDefs.DISH_DRYFROST_MEAT_WRAP_ID, 36.0), _order("04", 8, TestItemDefs.DISH_OASIS_HOTPOT_ID, 46.0)])
		]),
		_group(&"d2_sweet_oasis", 1, "第二日 甜味绿洲", "晴天梅和砂冠花负责甜品与高级组合。", [TestItemDefs.MEAT_WHITE_ID], [TestItemDefs.EGG_ID, TestItemDefs.TOFU_ID, TestItemDefs.RICE_ID, TestItemDefs.CABBAGE_ID], [&"ranged", &"sniper", &"bullet_fan"], 4.8, [
			_wave(1, [_order("01", 1, TestItemDefs.DISH_QINGMEI_SWEET_BOWL_ID, 36.0), _order("02", 4, TestItemDefs.DISH_STONEFLOWER_BAKED_CUP_ID, 30.0), _order("03", 7, TestItemDefs.DISH_DILL_FOWL_POT_ID, 38.0)]),
			_wave(2, [_order("04", 2, TestItemDefs.DISH_OASIS_HOTPOT_ID, 46.0), _order("05", 8, TestItemDefs.DISH_QINGMEI_SWEET_BOWL_ID, 34.0)])
		]),
		_group(&"d2_grain_line", 1, "第二日 碎金主食", "碎金子与太阳籽成为主食底，烤台占用更明显。", [TestItemDefs.MEAT_RED_ID, TestItemDefs.SHRIMP_ID], [TestItemDefs.RICE_ID, TestItemDefs.SUN_SEED_ID, TestItemDefs.COCONUT_ID, TestItemDefs.VEG_ROOT_ID], [&"sprinter", &"slammer", &"bullet_fan"], 4.8, [
			_wave(1, [_order("01", 2, TestItemDefs.DISH_SUNSEED_CRISP_ID, 30.0), _order("02", 5, TestItemDefs.DISH_SUNRISE_BANQUET_ID, 42.0)]),
			_wave(2, [_order("03", 1, TestItemDefs.DISH_DILL_FOWL_POT_ID, 38.0), _order("04", 6, TestItemDefs.DISH_ROYAL_HEAT_PLATE_ID, 52.0), _order("05", 8, TestItemDefs.DISH_GOLDEN_FLATBREAD_ID, 30.0)])
		]),
		_group(&"d2_caravan_exam", 1, "第二日 商队考核", "三件和四件菜混排，开始逼迫玩家规划路线。", [TestItemDefs.MEAT_RED_ID, TestItemDefs.MEAT_WHITE_ID, TestItemDefs.SHRIMP_ID], [TestItemDefs.VEG_LEAF_ID, TestItemDefs.CABBAGE_ID, TestItemDefs.RICE_ID, TestItemDefs.MUSHROOM_ID], [&"chaser", &"bruiser", &"sniper", &"bullet_fan"], 4.5, [
			_wave(1, [_order("01", 1, TestItemDefs.DISH_ROYAL_ROAST_PLATE_ID, 38.0), _order("02", 5, TestItemDefs.DISH_SUNRISE_BANQUET_ID, 42.0)]),
			_wave(2, [_order("03", 3, TestItemDefs.DISH_CAMEL_DOUBLE_ROAST_ID, 46.0), _order("04", 6, TestItemDefs.DISH_OASIS_HOTPOT_ID, 46.0), _order("05", 8, TestItemDefs.DISH_STONEFLOWER_BAKED_CUP_ID, 34.0)])
		]),
		_group(&"d3_market_rush", 2, "第三日 烈日快单", "低中难度菜大量穿插，客人耐心更短。", [TestItemDefs.MEAT_RED_ID, TestItemDefs.SHRIMP_ID], [TestItemDefs.VEG_LEAF_ID, TestItemDefs.VEG_ROOT_ID, TestItemDefs.RICE_ID, TestItemDefs.EGG_ID, TestItemDefs.CABBAGE_ID], [&"sprinter", &"splitter", &"ranged"], 4.2, [
			_wave(1, [_order("01", 1, TestItemDefs.DISH_RED_ROLL_ID, 22.0), _order("02", 4, TestItemDefs.DISH_CRISP_PLATE_ID, 24.0), _order("03", 7, TestItemDefs.DISH_SUNSEED_CRISP_ID, 25.0)]),
			_wave(2, [_order("04", 3, TestItemDefs.DISH_GOLDEN_FOWL_CAKE_ID, 30.0), _order("05", 6, TestItemDefs.DISH_DILL_FOWL_POT_ID, 34.0), _order("06", 8, TestItemDefs.DISH_DRYFROST_ROLL_ID, 26.0)])
		]),
		_group(&"d3_hot_sand", 2, "第三日 热砂压迫", "砸地和弹幕压迫更多，厨房需要边打边做。", [TestItemDefs.MEAT_WHITE_ID], [TestItemDefs.TOFU_ID, TestItemDefs.CABBAGE_ID, TestItemDefs.VEG_ROOT_ID, TestItemDefs.MUSHROOM_ID, TestItemDefs.COCONUT_ID], [&"slammer", &"bruiser", &"bullet_fan", &"orbiter"], 4.0, [
			_wave(1, [_order("01", 2, TestItemDefs.DISH_OASIS_HOTPOT_ID, 44.0), _order("02", 5, TestItemDefs.DISH_SPICED_LAMB_ID, 38.0), _order("03", 8, TestItemDefs.DISH_STONEFLOWER_BAKED_CUP_ID, 26.0)]),
			_wave(2, [_order("04", 1, TestItemDefs.DISH_ROYAL_HEAT_PLATE_ID, 50.0), _order("05", 6, TestItemDefs.DISH_SUNRISE_BANQUET_ID, 42.0)])
		]),
		_group(&"d3_banquet_line", 2, "第三日 王陵长宴", "高收益四件菜为主，单子少但每张都重。", [TestItemDefs.MEAT_RED_ID, TestItemDefs.SHRIMP_ID], [TestItemDefs.RICE_ID, TestItemDefs.TOFU_ID, TestItemDefs.VEG_LEAF_ID, TestItemDefs.MUSHROOM_ID, TestItemDefs.COCONUT_ID], [&"bruiser", &"sniper", &"bullet_fan", &"orbiter"], 5.0, [
			_wave(1, [_order("01", 1, TestItemDefs.DISH_CAMEL_DOUBLE_ROAST_ID, 50.0), _order("02", 5, TestItemDefs.DISH_OASIS_HOTPOT_ID, 48.0)]),
			_wave(2, [_order("03", 3, TestItemDefs.DISH_ROYAL_HEAT_PLATE_ID, 50.0), _order("04", 8, TestItemDefs.DISH_WINE_PLATTER_ID, 62.0)])
		]),
		_group(&"d3_full_menu", 2, "第三日 全菜单抽查", "覆盖全部料理台，订单类型跨度最大。", [TestItemDefs.MEAT_RED_ID, TestItemDefs.MEAT_WHITE_ID, TestItemDefs.SHRIMP_ID], [TestItemDefs.VEG_LEAF_ID, TestItemDefs.VEG_ROOT_ID, TestItemDefs.CABBAGE_ID, TestItemDefs.RICE_ID, TestItemDefs.EGG_ID, TestItemDefs.TOFU_ID, TestItemDefs.SUN_SEED_ID], [&"chaser", &"sprinter", &"slammer", &"ranged", &"bullet_fan", &"orbiter"], 3.8, [
			_wave(1, [_order("01", 1, TestItemDefs.DISH_QINGMEI_SWEET_BOWL_ID, 28.0), _order("02", 4, TestItemDefs.DISH_ROYAL_ROAST_PLATE_ID, 34.0), _order("03", 8, TestItemDefs.DISH_DRYFROST_ROLL_ID, 33.0)]),
			_wave(2, [_order("04", 2, TestItemDefs.DISH_CAMEL_DOUBLE_ROAST_ID, 42.0), _order("05", 6, TestItemDefs.DISH_OASIS_HOTPOT_ID, 48.0), _order("06", 7, TestItemDefs.DISH_ROYAL_HEAT_PLATE_ID, 50.0)])
		]),
		_group(&"d3_region_finale", 2, "第三日 第一绿洲试炼", "最终 demo 关：五件试炼菜和高压刷怪一起出现。", [TestItemDefs.MEAT_RED_ID, TestItemDefs.MEAT_WHITE_ID, TestItemDefs.SHRIMP_ID], [TestItemDefs.TOFU_ID, TestItemDefs.RICE_ID, TestItemDefs.EGG_ID, TestItemDefs.CABBAGE_ID, TestItemDefs.VEG_ROOT_ID, TestItemDefs.COCONUT_ID, TestItemDefs.SUN_SEED_ID], [&"sprinter", &"bruiser", &"sniper", &"bullet_fan", &"orbiter", &"splitter"], 3.5, [
			_wave(1, [_order("01", 2, TestItemDefs.DISH_ROYAL_HEAT_PLATE_ID, 46.0), _order("02", 5, TestItemDefs.DISH_WINE_PLATTER_ID, 52.0), _order("03", 8, TestItemDefs.DISH_OASIS_HOTPOT_ID, 47.0)]),
			_wave(2, [_order("04", 1, TestItemDefs.DISH_ROYAL_HEAT_PLATE_ID, 64.0), _order("05", 6, TestItemDefs.DISH_CAMEL_DOUBLE_ROAST_ID, 50.0), _order("06", 3, TestItemDefs.DISH_ROYAL_HEAT_PLATE_ID, 60.0)])
		])
	]

	if day_index < 0:
		return groups

	var filtered_groups: Array[Dictionary] = []
	for group in groups:
		if int(group.get("day_index", 0)) == day_index:
			filtered_groups.append(group)
	return filtered_groups

static func build_group_for_menu(group_data: Dictionary, menu_dish_ids: Array[StringName], random_seed: int = -1) -> Dictionary:
	var result := group_data.duplicate(true)
	var clean_menu: Array[StringName] = []
	var orderable_menu: Array[StringName] = []
	for dish_id in menu_dish_ids:
		if TestItemDefs.is_dish(dish_id):
			clean_menu.append(dish_id)
			if not TestItemDefs.is_dessert(dish_id):
				orderable_menu.append(dish_id)
	if orderable_menu.is_empty():
		orderable_menu.append(TestItemDefs.DISH_RED_ID)
		if TestItemDefs.DISH_RED_ID not in clean_menu:
			clean_menu.append(TestItemDefs.DISH_RED_ID)

	var rng := RandomNumberGenerator.new()
	if random_seed < 0:
		rng.randomize()
	else:
		rng.seed = random_seed
	var previous_dish_id: StringName = &""
	var rewritten_waves: Array[Dictionary] = []
	var source_waves: Variant = group_data.get("waves", [])
	if source_waves is Array:
		for wave_data in source_waves:
			if not (wave_data is Dictionary):
				continue
			var rewritten_orders: Array[Dictionary] = []
			var source_orders: Variant = wave_data.get("orders", [])
			if source_orders is Array:
				for source_order in source_orders:
					if not (source_order is Dictionary):
						continue
					var day_index := int(group_data.get("day_index", 0))
					var dishes := _choose_customer_dishes(orderable_menu, day_index, rng, previous_dish_id)
					var source_id := String(source_order.get("order_id", "%02d" % [rewritten_orders.size() + 1]))
					var batch_id := "wave_%d_customer_%s" % [rewritten_waves.size(), source_id]
					var customer_name := ""
					for index in dishes.size():
						var rewritten_order := _order(source_id if dishes.size() == 1 else "%s_%d" % [source_id, index + 1], int(source_order.get("target_slot", 1)), dishes[index], 0.0)
						if index == 0:
							customer_name = String(rewritten_order.customer_name)
						rewritten_order["customer_name"] = customer_name
						rewritten_order["customer_batch_id"] = batch_id
						rewritten_order["elite_customer"] = dishes.size() > 1
						rewritten_order["customer_order_index"] = index
						rewritten_order["customer_order_total"] = dishes.size()
						rewritten_order["day_index"] = day_index
						rewritten_orders.append(rewritten_order)
					previous_dish_id = dishes.back()
			rewritten_waves.append(_wave(int(wave_data.get("wave_number", rewritten_waves.size() + 1)), rewritten_orders))

	result["waves"] = rewritten_waves
	result["menu_dish_ids"] = clean_menu.duplicate()
	result["allowed_meats"] = _collect_recipe_items_by_kind(clean_menu, true)
	result["allowed_veggies"] = _collect_recipe_items_by_kind(clean_menu, false)
	return result

static func _choose_customer_dishes(menu: Array[StringName], day_index: int, rng: RandomNumberGenerator, previous_dish_id: StringName) -> Array[StringName]:
	if day_index >= 2 and rng.randf() < ELITE_CUSTOMER_CHANCE:
		var by_category: Dictionary = {}
		for dish_id in menu:
			var category := TestItemDefs.get_item_category(dish_id)
			if not by_category.has(category):
				by_category[category] = []
			by_category[category].append(dish_id)
		var combinations: Array = []
		if by_category.has(&"drink"):
			if by_category.has(&"small_plate"):
				combinations.append([&"drink", &"small_plate"])
			if by_category.has(&"main_dish"):
				combinations.append([&"drink", &"main_dish"])
			if by_category.has(&"small_plate") and by_category.has(&"main_dish"):
				combinations.append([&"drink", &"small_plate", &"main_dish"])
		if not combinations.is_empty():
			var result: Array[StringName] = []
			for category: StringName in combinations[rng.randi_range(0, combinations.size() - 1)]:
				var candidates: Array[StringName] = []
				candidates.assign(by_category[category])
				result.append(_choose_weighted_dish(candidates, rng))
			return result
	return [_choose_weighted_dish(menu, rng, previous_dish_id)]

static func append_boss_special_orders(group_data: Dictionary, mechanism_id: StringName) -> Dictionary:
	var result := group_data.duplicate(true)
	var waves: Variant = result.get("waves", [])
	if not waves is Array or waves.is_empty():
		return result
	var special_orders := get_boss_special_orders(mechanism_id)
	if special_orders.is_empty():
		return result
	# Keep the guest out of opening waves. The flow adds this separate batch
	# when the service clock ends; ordinary customers keep their own timers.
	result["boss_special_orders"] = special_orders
	result["boss_special_guest"] = true
	result["boss_special_guest_id"] = StringName("%s_guest" % mechanism_id)
	# Special requests need ingredient supplies, but must not enter the ordinary
	# customer's random dish pool or consume permanent menu slots.
	var required_dishes: Array[StringName] = []
	for order: Dictionary in special_orders:
		required_dishes.append(StringName(order.dish_item_id))
	var displayed_menu: Array = result.get("menu_dish_ids", []).duplicate()
	for dish: StringName in required_dishes:
		if dish not in displayed_menu:
			displayed_menu.append(dish)
	result["menu_dish_ids"] = displayed_menu
	for key: String in ["allowed_meats", "allowed_veggies"]:
		var ingredients: Array = result.get(key, []).duplicate()
		for ingredient: StringName in _collect_recipe_items_by_kind(required_dishes, key == "allowed_meats"):
			if ingredient not in ingredients:
				ingredients.append(ingredient)
		result[key] = ingredients
	return result

static func get_boss_special_orders(mechanism_id: StringName) -> Array[Dictionary]:
	var guest_id := StringName("%s_guest" % mechanism_id)
	var guest_name := "特殊客人"
	var dishes: Array[StringName] = []
	match mechanism_id:
		&"quicksand":
			guest_name = "沙海王庭使者"
			dishes = [TestItemDefs.DISH_SANDWORM_ROYAL_HEAT_PLATE_ID, TestItemDefs.DISH_OASIS_HOTPOT_ID, TestItemDefs.DISH_DRYFROST_MEAT_WRAP_ID]
		&"scarab":
			guest_name = "毒宴商会会首"
			dishes = [TestItemDefs.DISH_SCORPION_SUNPLATE_ID, TestItemDefs.DISH_SPICED_LAMB_ID, TestItemDefs.DISH_QINGMEI_SEARED_CUP_ID]
		&"sandstorm":
			guest_name = "逐风信使"
			dishes = [TestItemDefs.DISH_VULTURE_FEATHER_FEAST_ID, TestItemDefs.DISH_ROYAL_ROAST_PLATE_ID, TestItemDefs.DRINK_OASIS_WINE_ID]
		&"monitor":
			guest_name = "沙海宴会评审"
			dishes = [TestItemDefs.DISH_MONITOR_ROYAL_BANQUET_ID, TestItemDefs.DISH_ROYAL_ROAST_PLATE_ID, TestItemDefs.DRINK_OASIS_WINE_ID]
		_:
			return []
	var result: Array[Dictionary] = []
	var ordered_dishes: Array[StringName] = dishes.duplicate()
	ordered_dishes.sort_custom(func(a: StringName, b: StringName) -> bool:
		return _customer_course_rank(a) < _customer_course_rank(b)
	)
	for index in ordered_dishes.size():
		var order := _order("BOSS-%02d" % (index + 1), 1, ordered_dishes[index], SPECIAL_GUEST_PATIENCE_DURATION)
		order["customer_name"] = guest_name
		order["special_guest"] = true
		order["special_guest_id"] = guest_id
		order["special_guest_index"] = index
		order["special_guest_total"] = dishes.size()
		order["order_take_patience_duration"] = SPECIAL_GUEST_TAKE_DURATION
		order["special_guest_patience_duration"] = SPECIAL_GUEST_PATIENCE_DURATION
		order["gold_reward"] = int(order["gold_reward"]) * 5
		order["xp_reward"] = int(order["xp_reward"]) * 5
		order["reputation_penalty"] = 0
		result.append(order)
	return result

static func _customer_course_rank(dish_id: StringName) -> int:
	match TestItemDefs.get_item_category(dish_id):
		&"drink":
			return 0
		&"small_plate":
			return 1
		&"main_dish":
			return 2
		_:
			return 3

static func get_order_weight(dish_item_id: StringName) -> float:
	# Simple, quick dishes should be common; high-level and multi-step dishes
	# remain available but are naturally less likely to appear.
	var profile := TestItemDefs.get_dish_balance_profile(dish_item_id)
	var category := StringName(profile.get("category", &"drink"))
	var level := float(profile.get("level", 1))
	var ingredient_count := float(profile.get("ingredient_count", 1))
	var method_complexity := float(profile.get("method_complexity", 0))
	var maturation_complexity := float(profile.get("maturation_complexity", 0))
	var category_factor: float = float({
		&"drink": 1.35,
		&"small_plate": 1.15,
		&"main_dish": 0.95,
		&"dessert": 0.82
	}.get(category, 1.0))
	var complexity_penalty := 1.0 \
		+ (level - 1.0) * 0.55 \
		+ maxf(ingredient_count - 1.0, 0.0) * 0.10 \
		+ method_complexity * 0.08 \
		+ maturation_complexity * 0.06
	return maxf(category_factor / maxf(complexity_penalty, 0.1), 0.01)

static func _choose_weighted_dish(candidates: Array[StringName], rng: RandomNumberGenerator, previous_dish_id: StringName = &"") -> StringName:
	if candidates.is_empty():
		return TestItemDefs.DISH_RED_ID
	var total_weight := 0.0
	for dish_id in candidates:
		var weight := get_order_weight(dish_id)
		# Avoid a visually monotonous run when another dish is available, while
		# still allowing duplicates elsewhere in the wave.
		if dish_id == previous_dish_id and candidates.size() > 1:
			weight *= 0.18
		total_weight += weight
	if total_weight <= 0.0:
		return candidates[rng.randi_range(0, candidates.size() - 1)]
	var roll := rng.randf() * total_weight
	for dish_id in candidates:
		var weight := get_order_weight(dish_id)
		if dish_id == previous_dish_id and candidates.size() > 1:
			weight *= 0.18
		roll -= weight
		if roll <= 0.0:
			return dish_id
	return candidates.back()

static func _group(
	id: StringName,
	day_index: int,
	display_name: String,
	description: String,
	allowed_meats: Array,
	allowed_veggies: Array,
	enemy_pool: Array[StringName],
	wave_break_duration: float,
	waves: Array
) -> Dictionary:
	var tagged_waves: Array[Dictionary] = []
	for wave_data in waves:
		if not (wave_data is Dictionary):
			continue
		var tagged_wave: Dictionary = wave_data.duplicate(true)
		var tagged_orders: Array[Dictionary] = []
		var source_orders: Variant = tagged_wave.get("orders", [])
		if source_orders is Array:
			for order_data in source_orders:
				if not (order_data is Dictionary):
					continue
				var tagged_order: Dictionary = order_data.duplicate(true)
				tagged_order["day_index"] = day_index
				tagged_orders.append(tagged_order)
		tagged_wave["orders"] = tagged_orders
		tagged_waves.append(tagged_wave)
	return {
		"id": id,
		"day_index": day_index,
		"display_name": display_name,
		"description": description,
		"allowed_meats": allowed_meats,
		"allowed_veggies": allowed_veggies,
		"enemy_pool": enemy_pool,
		"wave_break_duration": wave_break_duration,
		"waves": tagged_waves
	}

static func _wave(wave_number: int, orders: Array) -> Dictionary:
	return {
		"wave_number": wave_number,
		"orders": orders
	}

static func _order(order_id: String, target_slot: int, dish_item_id: StringName, _authored_patience_duration: float) -> Dictionary:
	var difficulty: int = TestItemDefs.get_dish_difficulty(dish_item_id)
	var customer_index: int = abs(hash("%s_%s" % [order_id, String(dish_item_id)])) % CUSTOMER_NAMES.size()
	return {
		"order_id": order_id,
		"customer_name": CUSTOMER_NAMES[customer_index],
		"dish_item_id": dish_item_id,
		"dish_name": TestItemDefs.get_item_display_name(dish_item_id),
		"target_slot": target_slot,
		"patience_duration": TestItemDefs.get_dish_patience_duration(dish_item_id),
		"gold_reward": TestItemDefs.get_dish_gold_reward(dish_item_id),
		"xp_reward": TestItemDefs.get_dish_xp_reward(dish_item_id),
		"reputation_penalty": clampi(18 + difficulty * 4, 20, 42),
		"recipe_items": TestItemDefs.instantiate_order_recipe_for_dish(dish_item_id)
	}

static func _collect_recipe_items_by_kind(dish_ids: Array[StringName], meat_only: bool) -> Array[StringName]:
	var result: Array[StringName] = []
	for dish_id in dish_ids:
		for entry in TestItemDefs.get_display_recipe_for_dish(dish_id):
			if not (entry is Dictionary):
				continue
			var item_id := StringName(entry.get("item_id", &""))
			if not TestItemDefs.is_ingredient(item_id):
				continue
			# Boss ingredients come only from defeating their Boss, never the
			# ordinary battle/forage sources or initial loose-item slots.
			if TestItemDefs.is_boss_ingredient(item_id):
				continue
			if _is_meat_item(item_id) != meat_only:
				continue
			if item_id not in result:
				result.append(item_id)
	return result

static func _is_meat_item(item_id: StringName) -> bool:
	return item_id in [
		TestItemDefs.MEAT_RED_ID,
		TestItemDefs.MEAT_WHITE_ID,
		TestItemDefs.SHRIMP_ID,
		TestItemDefs.CAMEL_MEAT_ID
	]
