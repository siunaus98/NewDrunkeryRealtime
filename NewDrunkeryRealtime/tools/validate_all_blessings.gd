extends SceneTree

const BlessingDefs = preload("res://Scripts/Progression/BlessingDefs.gd")
const BlessingRuntimeController = preload("res://Scripts/Progression/BlessingRuntimeController.gd")
const RunProgressionState = preload("res://Scripts/Core/RunProgressionState.gd")
const RunSetupController = preload("res://Scripts/Core/RunSetupController.gd")
const OrderManager = preload("res://Scripts/Orders/OrderManager.gd")
const TestItemDefs = preload("res://Scripts/Kitchen/TestItemDefs.gd")

const EXPECTED_COUNT := 87
const EXPECTED_GENERAL_COUNT := 73
const EXPECTED_CHI_BAOBAO_COUNT := 14
const VALID_TYPES := [&"general", &"chi_baobao"]
const BEHAVIOR_SOURCE_PATHS := [
	"res://Scripts/Progression/BlessingRuntimeController.gd",
	"res://Scripts/Player/PlayerCombatController.gd",
	"res://Scripts/Kitchen/TestCooker.gd"
]
var failure_count: int = 0

func _init() -> void:
	_validate_definitions()
	_validate_runtime_acceptance()
	_validate_behavior_source_coverage()
	_validate_snapshot_round_trip()
	_validate_representative_effects()
	if failure_count > 0:
		push_error("Blessing validation failed with %d error(s)." % failure_count)
		quit(1)
		return
	print("All blessing validation OK: 87 definitions, runtime coverage, persistence, and representative effects.")
	quit(0)

func _validate_definitions() -> void:
	var definitions := BlessingDefs.create_default_blessings()
	_assert(definitions.size() == EXPECTED_COUNT, "BlessingDefs must contain exactly %d blessings." % EXPECTED_COUNT)
	var ids: Dictionary = {}
	var titles: Dictionary = {}
	var general_count := 0
	var chi_baobao_count := 0
	for definition in definitions:
		var blessing_id := StringName(definition.get("id", &""))
		var title := String(definition.get("title", ""))
		var type := StringName(definition.get("type", &""))
		var description := String(definition.get("description", ""))
		_assert(blessing_id != &"", "Every blessing needs a stable id.")
		_assert(title != "", "Every blessing needs a title.")
		_assert(description != "", "%s needs a description." % title)
		_assert(type in VALID_TYPES, "%s has an invalid type." % title)
		_assert(not ids.has(blessing_id), "Duplicate blessing id: %s" % blessing_id)
		_assert(not titles.has(title), "Duplicate blessing title: %s" % title)
		ids[blessing_id] = true
		titles[title] = true
		if type == &"general":
			general_count += 1
		else:
			chi_baobao_count += 1
	_assert(general_count == EXPECTED_GENERAL_COUNT, "Expected %d general blessings, got %d." % [EXPECTED_GENERAL_COUNT, general_count])
	_assert(chi_baobao_count == EXPECTED_CHI_BAOBAO_COUNT, "Expected %d Chi Baobao blessings, got %d." % [EXPECTED_CHI_BAOBAO_COUNT, chi_baobao_count])

func _validate_runtime_acceptance() -> void:
	var runtime := BlessingRuntimeController.new()
	for definition in BlessingDefs.create_default_blessings():
		var blessing_id := StringName(definition.get("id", &""))
		_assert(runtime.apply_blessing(blessing_id), "Runtime rejected blessing %s." % blessing_id)
	_assert(runtime.owned.size() == EXPECTED_COUNT, "Runtime must retain all applied blessings.")

func _validate_behavior_source_coverage() -> void:
	var behavior_source := ""
	for path in BEHAVIOR_SOURCE_PATHS:
		var file := FileAccess.open(path, FileAccess.READ)
		_assert(file != null, "Could not read behavior source %s." % path)
		behavior_source += file.get_as_text()
	for definition in BlessingDefs.create_default_blessings():
		var title := String(definition.get("title", ""))
		_assert(behavior_source.contains('"%s"' % title), "%s has no explicit behavior handler." % title)

func _validate_snapshot_round_trip() -> void:
	var state := RunProgressionState.new()
	state.reset(0, 0)
	for definition in BlessingDefs.create_default_blessings():
		state.add_blessing(StringName(definition.get("id", &"")))
	var setup := RunSetupController.new()
	root.add_child(setup)
	var snapshot := setup.build_progression_snapshot(null, 0, state, false)
	var restored := RunProgressionState.new()
	restored.reset(0, 0)
	restored.apply_snapshot(snapshot)
	_assert(restored.get_owned_blessing_ids().size() == EXPECTED_COUNT, "All owned blessings must survive a progression snapshot.")

func _validate_representative_effects() -> void:
	var strength := _runtime_with("力量祝福")
	var strength_target := Node.new()
	_assert(strength.modify_attack_damage(100, strength_target, false, 200.0) == 115, "力量祝福 must add 15% total attack damage.")
	strength_target.free()

	var cutting := _runtime_with("刀口清亮")
	_assert(is_equal_approx(cutting.get_work_multiplier(TestItemDefs.PROCESS_STATE_CUT), 1.33), "刀口清亮 must add 33% cutting efficiency.")

	var endurance := _runtime_with("坚韧祝福")
	_assert(is_equal_approx(endurance.get_health_regen_multiplier(), 1.20), "坚韧祝福 must add 20% total health regeneration.")

	var remaining_magic := _runtime_with("余量管理")
	_assert(remaining_magic.get_end_of_day_gold(7) == 14, "余量管理 must grant two gold per remaining magic.")

	var shared_rhythm := _runtime_with("共享节拍")
	shared_rhythm.on_other_player_magic_spent()
	_assert(float(shared_rhythm.timers.get("shared_move", 0.0)) == 3.0, "共享节拍 must start its three-second movement buff.")

	var bullet_warning := _runtime_with("弹幕预感")
	bullet_warning.on_bullet_warning_started(0.92)
	_assert(is_equal_approx(float(bullet_warning.timers.get("bullet_move", 0.0)), 0.92), "弹幕预感 must match the real warning duration.")

	var order_manager := OrderManager.new()
	root.add_child(order_manager)
	order_manager.set_orders([{
		"order_id": "action_speed_test",
		"target_slot": 1,
		"dish_item_id": TestItemDefs.DISH_CRISP_PLATE_ID,
		"patience_duration": 30.0,
		"order_take_action_multiplier": 0.5
	}])
	_assert(order_manager.process_take_order_at_slot(1, 0.39), "A held order action must accept progress before completion.")
	_assert(order_manager.active_orders.is_empty(), "A halved 0.8-second order action must not finish before 0.4 seconds.")
	_assert(order_manager.process_take_order_at_slot(1, 0.02), "A held order action must complete at its modified duration.")
	_assert(order_manager.active_orders.size() == 1, "热情好客 must have a real halved order-action duration target.")
	order_manager.free()

	var dash_attack := _runtime_with("冲锋余威")
	dash_attack.on_dash_finished()
	dash_attack.begin_player_attack(true)
	var dash_target := Node.new()
	_assert(dash_attack.modify_attack_damage(100, dash_target, true, 200.0) == 120, "冲锋余威 must also empower a heavy attack.")
	dash_target.free()
	dash_attack.end_player_attack()

func _runtime_with(title: String) -> RefCounted:
	var runtime := BlessingRuntimeController.new()
	var blessing_id := BlessingDefs.get_id_by_title(title)
	_assert(blessing_id != &"", "Unknown blessing in validation: %s" % title)
	_assert(runtime.apply_blessing(blessing_id), "Could not apply blessing in validation: %s" % title)
	return runtime

func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	failure_count += 1
	push_error(message)
