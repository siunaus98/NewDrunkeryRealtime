extends SceneTree

const TestItemDefs = preload("res://Scripts/Kitchen/TestItemDefs.gd")
const OrderGroupDefs = preload("res://Scripts/Orders/OrderGroupDefs.gd")
const OrderManager = preload("res://Scripts/Orders/OrderManager.gd")
const TestCooker = preload("res://Scripts/Kitchen/TestCooker.gd")
const FixedBarrelBlocker = preload("res://Scripts/Restaurant/FixedBarrelBlocker.gd")
const NightShopController = preload("res://Scripts/Progression/NightShopController.gd")
const StorageManager = preload("res://Scripts/Kitchen/StorageManager.gd")
const RunSetupController = preload("res://Scripts/Core/RunSetupController.gd")

class DummyPlayer extends Node:
	var held_item_id: StringName = &""
	var held_process_state: StringName = TestItemDefs.PROCESS_STATE_NONE

	func is_holding_item() -> bool:
		return held_item_id != &""

	func get_held_item_id() -> StringName:
		return held_item_id

	func get_held_item_process_state() -> StringName:
		return held_process_state

	func can_pick_up_item(_item_id: StringName = &"", _process_state: StringName = TestItemDefs.PROCESS_STATE_NONE, _payload: Dictionary = {}) -> bool:
		return not is_holding_item()

	func pick_up_item(item_id: StringName, _texture: Texture2D, process_state: StringName = TestItemDefs.PROCESS_STATE_NONE, _recipe_signature: String = "", _payload: Dictionary = {}) -> bool:
		if is_holding_item():
			return false
		held_item_id = item_id
		held_process_state = process_state
		return true

var failures: Array[String] = []
var test_root: Node

func _init() -> void:
	test_root = Node.new()
	test_root.name = "OrderFlowValidationRoot"
	get_root().add_child(test_root)
	_test_day_one_process_states_are_fixed()
	_test_menu_orders_are_weighted_and_randomized()
	_test_order_timing_is_fixed_and_derived()
	_test_playtest_patience_survives_acceptance()
	_test_later_orders_instantiate_one_process_state()
	_test_order_rewards_for_exact_and_off_spec_delivery()
	_test_cooker_accepts_intermediate_states()
	_test_cooker_rejects_terminal_or_wrong_family_states()
	_test_processing_cooker_remains_focusable()
	_test_cooker_pickup_and_prompt_rules()
	_test_empty_barrel_accepts_any_legal_input()
	_test_starting_stock_is_only_initialized_once()
	_test_shop_grid_navigation_matches_three_columns()

	if failures.is_empty():
		print("Order flow rules OK: orders, cooker focus, barrels, stock persistence, and shop navigation.")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)

func _test_day_one_process_states_are_fixed() -> void:
	var groups := OrderGroupDefs.create_default_order_groups(0)
	if groups.is_empty():
		failures.append("第一日订单组为空")
		return
	var opening_menu: Array[StringName] = [
		TestItemDefs.DRINK_OASIS_WINE_ID,
		TestItemDefs.DRINK_GOLD_ALE_ID,
		TestItemDefs.DRINK_QINGMEI_WINE_ID,
		TestItemDefs.DISH_CRISP_PLATE_ID,
		TestItemDefs.DISH_RED_ROLL_ID
	]
	var active_group := OrderGroupDefs.build_group_for_menu(groups[0], opening_menu)
	var range_count := 0
	for wave in active_group.get("waves", []):
		for order in wave.get("orders", []):
			var dish_id := StringName(order.get("dish_item_id", &""))
			for entry in TestItemDefs.get_display_recipe_for_dish(dish_id):
				if entry is Dictionary and not Array(entry.get("accepted_process_states", [])).is_empty():
					range_count += 1
	if range_count != 0:
		failures.append("实际开局菜单生成的第一日订单不应出现客单熟成度范围，发现%d项" % range_count)

func _test_menu_orders_are_weighted_and_randomized() -> void:
	var groups := OrderGroupDefs.create_default_order_groups(0)
	if groups.is_empty():
		failures.append("加权随机订单测试：第一日订单组为空")
		return
	var opening_menu: Array[StringName] = [
		TestItemDefs.DRINK_OASIS_WINE_ID,
		TestItemDefs.DRINK_GOLD_ALE_ID,
		TestItemDefs.DRINK_QINGMEI_WINE_ID,
		TestItemDefs.DISH_CRISP_PLATE_ID,
		TestItemDefs.DISH_RED_ROLL_ID
	]
	var seeded_a := OrderGroupDefs.build_group_for_menu(groups[0], opening_menu, 1101)
	var seeded_b := OrderGroupDefs.build_group_for_menu(groups[0], opening_menu, 2202)
	var sequence_a := _get_order_dish_sequence(seeded_a)
	var sequence_b := _get_order_dish_sequence(seeded_b)
	if sequence_a.size() < 2 or sequence_b.size() < 2:
		failures.append("加权随机订单测试：生成的订单数量不足")
		return
	if _unique_count(sequence_a) < 2:
		failures.append("加权随机订单测试：同一局订单仍全部相同")
	if sequence_a == sequence_b:
		failures.append("加权随机订单测试：不同种子生成了完全相同的订单序列")
	if OrderGroupDefs.get_order_weight(TestItemDefs.DRINK_OASIS_WINE_ID) <= OrderGroupDefs.get_order_weight(TestItemDefs.DISH_RED_ROLL_ID):
		failures.append("加权随机订单测试：基础酒水的权重应高于复杂主菜")
	for dish_id in sequence_a:
		if dish_id not in opening_menu:
			failures.append("加权随机订单测试：生成了不在当前菜单中的菜品：%s" % dish_id)
	var drink_hits := 0
	var main_hits := 0
	for seed in range(100, 300):
		var sampled_group := OrderGroupDefs.build_group_for_menu(groups[0], opening_menu, seed)
		for dish_id in _get_order_dish_sequence(sampled_group):
			if TestItemDefs.is_drink(dish_id):
				drink_hits += 1
			elif TestItemDefs.is_main_dish(dish_id):
				main_hits += 1
	if drink_hits <= main_hits:
		failures.append("加权随机订单测试：200次采样中基础酒水没有比主菜更常出现（酒水%d，主菜%d）" % [drink_hits, main_hits])

func _get_order_dish_sequence(group_data: Dictionary) -> Array[StringName]:
	var result: Array[StringName] = []
	for wave_data in group_data.get("waves", []):
		for order_data in wave_data.get("orders", []):
			result.append(StringName(order_data.get("dish_item_id", &"")))
	return result

func _unique_count(values: Array[StringName]) -> int:
	var unique: Dictionary = {}
	for value in values:
		unique[value] = true
	return unique.size()

func _test_order_timing_is_fixed_and_derived() -> void:
	var manager := OrderManager.new()
	test_root.add_child(manager)
	manager.set_orders([
		{"order_id": "timing_a", "dish_item_id": TestItemDefs.DISH_CRISP_PLATE_ID},
		{"order_id": "timing_b", "dish_item_id": TestItemDefs.DISH_CRISP_PLATE_ID}
	])
	var waiting := manager.get_waiting_orders()
	if waiting.size() != 2:
		failures.append("固定点单时间测试订单未正确进入等待列表")
	else:
		if not is_equal_approx(float(waiting[0].get("order_take_patience_duration", 0.0)), 75.0) or not is_equal_approx(float(waiting[1].get("order_take_patience_duration", 0.0)), 75.0):
			failures.append("点单等待时间没有统一为固定值")
		var expected := TestItemDefs.get_dish_patience_duration(TestItemDefs.DISH_CRISP_PLATE_ID)
		if not is_equal_approx(float(waiting[0].get("patience_duration", 0.0)), expected):
			failures.append("订单等待时间没有使用菜品模型计算")
	manager.queue_free()

func _test_playtest_patience_survives_acceptance() -> void:
	var manager := OrderManager.new()
	test_root.add_child(manager)
	var group := OrderGroupDefs.create_advanced_dish_playtest_group()
	for wave: Dictionary in group["waves"]:
		manager.set_orders(wave["orders"])
		manager._process(4.0)
		var waiting := manager.get_waiting_orders()
		if waiting.size() != 1 or not is_equal_approx(float(waiting[0]["order_take_time_remaining"]), 1.0):
			failures.append("Advanced cooking playtest must allow 5 seconds before accepting an order.")
			continue
		var slot: int = int(waiting[0]["target_slot"])
		if not manager.take_order_at_slot(slot):
			failures.append("Advanced cooking playtest order could not be accepted.")
			continue
		var accepted := manager.get_active_order_for_slot(slot)
		if not is_equal_approx(float(accepted["patience_duration"]), 120.0) or not is_equal_approx(float(accepted["time_remaining"]), 120.0):
			failures.append("Accepting an advanced cooking playtest order must retain its 120-second cooking allowance.")
		manager._process(119.0)
		if not manager.has_active_order_for_slot(slot):
			failures.append("Advanced cooking playtest order expired before the cooking allowance ended.")
		manager._process(1.0)
		if manager.has_active_order():
			failures.append("Advanced cooking playtest order must still expire when its full allowance ends.")
	manager.queue_free()

func _test_later_orders_instantiate_one_process_state() -> void:
	var range_definition_found := false
	var instantiated_range_found := false
	for recipe in TestItemDefs.get_recipes():
		for entry in recipe.get("ingredients", []):
			if not (entry is Dictionary):
				continue
			var accepted_states: Array = entry.get("accepted_process_states", [])
			if accepted_states.is_empty():
				continue
			range_definition_found = true
			var dish_id: StringName = StringName(recipe.get("output_item_id", &""))
			var order_items: Array = TestItemDefs.instantiate_order_recipe_for_dish(dish_id)
			for order_entry in order_items:
				if not (order_entry is Dictionary):
					continue
				if not Array(order_entry.get("accepted_process_states", [])).is_empty():
					failures.append("订单实例仍携带完整熟成度范围：%s" % dish_id)
				if order_entry.get("item_id", &"") == entry.get("item_id", &"") and order_entry.get("count", 1) == entry.get("count", 1):
					var state := TestItemDefs.normalize_process_state(StringName(order_entry.get("process_state", TestItemDefs.PROCESS_STATE_NONE)))
					if state in accepted_states.map(func(value): return TestItemDefs.normalize_process_state(StringName(value))):
						instantiated_range_found = true
			if instantiated_range_found:
					break
		if instantiated_range_found:
			break
	if not range_definition_found:
		failures.append("配方数据中没有可测试的熟成度范围")
	if not instantiated_range_found:
		failures.append("客单熟成度范围未实例化为单一状态")

func _test_order_rewards_for_exact_and_off_spec_delivery() -> void:
	var manager := OrderManager.new()
	test_root.add_child(manager)
	var completed: Array[Dictionary] = []
	manager.order_completed.connect(func(order_data: Dictionary): completed.append(order_data))
	var order := {
		"order_id": "reward_test",
		"target_slot": 1,
		"dish_item_id": TestItemDefs.DISH_RED_ROLL_ID,
		"gold_reward": 20,
		"xp_reward": 10,
		"patience_duration": 30.0,
		"recipe_items": []
	}
	manager.set_orders([order])
	if not manager.take_order_at_slot(1):
		failures.append("奖励测试订单无法接取")
	manager.complete_current_order(1, true)
	if completed.is_empty() or int(completed.back().get("gold_reward", -1)) != 20 or int(completed.back().get("xp_reward", -1)) != 10:
		failures.append("正确熟成度订单未保留全额奖励")
	completed.clear()
	manager.set_orders([order])
	manager.take_order_at_slot(1)
	manager.complete_current_order(1, false)
	if not completed.is_empty() or manager.get_active_orders().size() != 1:
		failures.append("错误熟成度不得完成订单或发放折扣奖励")
	completed.clear()
	var odd_reward_order := order.duplicate(true)
	odd_reward_order["order_id"] = "rounding_test"
	odd_reward_order["gold_reward"] = 21
	odd_reward_order["xp_reward"] = 11
	manager.set_orders([odd_reward_order])
	manager.take_order_at_slot(1)
	manager.complete_current_order(2, false)
	if not completed.is_empty() or manager.get_active_orders().size() != 1:
		failures.append("错误窗口意外完成了订单")
	manager.complete_current_order(1, false)
	if not completed.is_empty() or manager.get_active_orders().size() != 1:
		failures.append("重复提交错误熟成度不得消耗订单")
	manager.queue_free()

func _test_cooker_accepts_intermediate_states() -> void:
	var roast := TestCooker.new()
	roast.output_process_state = TestItemDefs.PROCESS_STATE_ROAST_WELL
	for state in [TestItemDefs.PROCESS_STATE_NONE, TestItemDefs.PROCESS_STATE_ROAST_RARE, TestItemDefs.PROCESS_STATE_ROAST_MEDIUM, TestItemDefs.PROCESS_STATE_ROAST_WELL]:
		if not _cooker_accepts(roast, state):
			failures.append("火候台未接受状态：%s" % state)
	roast.free()
	var grind := TestCooker.new()
	grind.output_process_state = TestItemDefs.PROCESS_STATE_GRIND_FINE
	for state in [TestItemDefs.PROCESS_STATE_NONE, TestItemDefs.PROCESS_STATE_GRIND_COARSE]:
		if not _cooker_accepts(grind, state):
			failures.append("研磨台未接受状态：%s" % state)
	grind.free()

func _test_cooker_rejects_terminal_or_wrong_family_states() -> void:
	var roast := TestCooker.new()
	roast.cooking_process_mode = TestCooker.PROCESS_MODE_AUTO
	roast.output_process_state = TestItemDefs.PROCESS_STATE_ROAST_WELL
	for state in [TestItemDefs.PROCESS_STATE_BURNT, TestItemDefs.PROCESS_STATE_GRIND_COARSE, TestItemDefs.PROCESS_STATE_CUT]:
		if _cooker_accepts(roast, state):
			failures.append("火候台错误接受状态：%s" % state)
	roast.free()
	var grind := TestCooker.new()
	grind.output_process_state = TestItemDefs.PROCESS_STATE_GRIND_FINE
	for state in [TestItemDefs.PROCESS_STATE_GRIND_FINE, TestItemDefs.PROCESS_STATE_ROAST_RARE, TestItemDefs.PROCESS_STATE_CUT]:
		if not _cooker_accepts(grind, state):
			failures.append("研磨台未允许暂存半成品：%s" % state)
	if _cooker_accepts(grind, TestItemDefs.PROCESS_STATE_BURNT):
		failures.append("研磨台错误接受烧焦食材")
	grind.free()

func _test_processing_cooker_remains_focusable() -> void:
	var cooker := TestCooker.new()
	cooker.has_item = true
	cooker.processing_active = true
	cooker.item_id = TestItemDefs.MEAT_RED_ID
	var player := DummyPlayer.new()
	if not cooker.is_pickup_drop_focusable(player):
		failures.append("加工中的切台或研磨台无法保持交互锁定")
	player.free()
	cooker.free()

func _test_cooker_pickup_and_prompt_rules() -> void:
	var player := DummyPlayer.new()
	var roast := TestCooker.new()
	roast.cooking_process_mode = TestCooker.PROCESS_MODE_AUTO
	roast.output_process_state = TestItemDefs.PROCESS_STATE_ROAST_WELL
	roast.has_item = true
	roast.processing_active = true
	roast.item_id = TestItemDefs.MEAT_RED_ID
	roast.item_process_state = TestItemDefs.PROCESS_STATE_NONE
	roast.process_progress = 12.0
	if "K" in roast.get_interaction_button_prompt(player):
		failures.append("自动火候台刚放入食材时错误显示K交互")
	if roast.interact_with_player(player):
		failures.append("自动火候台错误接受手动K加工")
	if not roast.take_item_to_player(player):
		failures.append("未达到微生的火候食材无法取回")
	elif roast.process_progress != 0.0:
		failures.append("取回未完成火候食材后进度未重置")
	roast.free()
	player.held_item_id = &""
	player.held_process_state = TestItemDefs.PROCESS_STATE_NONE

	var cutter := TestCooker.new()
	cutter.cooking_process_mode = TestCooker.PROCESS_MODE_TAP
	cutter.output_process_state = TestItemDefs.PROCESS_STATE_CUT
	cutter.has_item = true
	cutter.processing_active = true
	cutter.item_id = TestItemDefs.VEG_LEAF_ID
	cutter.process_progress = 0.0
	if "切" not in cutter.get_interaction_button_prompt(player):
		failures.append("未开切食材未显示K切提示")
	if not cutter.can_take_item(player):
		failures.append("一刀未切的食材无法从切台取回")
	cutter.process_progress = 1.0
	if not cutter._is_cutting_in_progress():
		failures.append("切台开始加工后未锁定食材")
	if cutter.can_take_item(player):
		failures.append("切到一半的食材仍可从切台取回")
	cutter.free()

	var grinder := TestCooker.new()
	grinder.cooking_process_mode = TestCooker.PROCESS_MODE_HOLD
	grinder.output_process_state = TestItemDefs.PROCESS_STATE_GRIND_FINE
	grinder.has_item = true
	grinder.processing_active = true
	grinder.item_id = TestItemDefs.RICE_ID
	grinder.item_process_state = TestItemDefs.PROCESS_STATE_NONE
	grinder.process_progress = 12.0
	if "研磨" not in grinder.get_interaction_button_prompt(player):
		failures.append("研磨台未显示K研磨提示")
	if not grinder.take_item_to_player(player):
		failures.append("未达到粗磨的研磨食材无法取回")
	elif grinder.process_progress != 0.0:
		failures.append("取回未完成研磨食材后进度未重置")
	grinder.free()
	player.free()

func _test_empty_barrel_accepts_any_legal_input() -> void:
	var barrel := FixedBarrelBlocker.new()
	for input_id in [TestItemDefs.VEG_LEAF_ID, TestItemDefs.RICE_ID, TestItemDefs.EGG_ID]:
		var player := DummyPlayer.new()
		player.held_item_id = input_id
		player.held_process_state = TestItemDefs.PROCESS_STATE_NONE
		if not barrel.can_receive_item(player):
			failures.append("空酒桶未接受合法原料：%s" % input_id)
		player.free()
	barrel.free()

func _test_starting_stock_is_only_initialized_once() -> void:
	var storage := StorageManager.new()
	test_root.add_child(storage)
	var setup := RunSetupController.new()
	test_root.add_child(setup)
	setup.set_scene_refs(test_root, null, storage, null)
	setup.reset_for_night(0, 5)
	storage.consume_stock(TestItemDefs.VEG_LEAF_ID, 2)
	storage.add_stock(TestItemDefs.RICE_ID, 4)
	setup.reset_for_night(1, 5)
	if storage.get_stock(TestItemDefs.VEG_LEAF_ID) != 3:
		failures.append("跨天后已消耗库存被重置")
	if storage.get_stock(TestItemDefs.RICE_ID) != 9:
		failures.append("跨天后新增库存被重置")
	setup.queue_free()
	storage.queue_free()

func _test_shop_grid_navigation_matches_three_columns() -> void:
	if NightShopController.get_grid_target_index(0, 4, 3, 1, 0) != 1:
		failures.append("商店三列导航：A右未到B")
	if NightShopController.get_grid_target_index(1, 4, 3, 1, 0) != 2:
		failures.append("商店三列导航：B右未到C")
	if NightShopController.get_grid_target_index(3, 4, 3, 0, -1) != 0:
		failures.append("商店三列导航：D上未到A")
	if NightShopController.get_grid_target_index(3, 4, 3, 1, 0) != 0:
		failures.append("商店三列导航：D右应循环到A")
	if NightShopController.get_grid_target_index(3, 4, 3, 0, 1) != 0:
		failures.append("商店三列导航：末行下应循环到A")
	if NightShopController.get_grid_target_index(0, 4, 3, -1, 0) != 3:
		failures.append("商店三列导航：A左应循环到D")

func _cooker_accepts(cooker: TestCooker, process_state: StringName) -> bool:
	var player := DummyPlayer.new()
	player.held_item_id = TestItemDefs.MEAT_RED_ID
	player.held_process_state = process_state
	var result := cooker.can_receive_item(player)
	player.free()
	return result
