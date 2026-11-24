class_name RunProgressionState
extends RefCounted

const TestItemDefs = preload("res://Scripts/Kitchen/TestItemDefs.gd")
const IngredientSourceDefs = preload("res://Scripts/Core/IngredientSourceDefs.gd")
const AttributeForgeDefs = preload("res://Scripts/Progression/AttributeForgeDefs.gd")
const MapMechanismDefs = preload("res://Scripts/Core/MapMechanismDefs.gd")
const SmallSkillDefs = preload("res://Scripts/Player/SmallSkillDefs.gd")
const BigSkillDefs = preload("res://Scripts/Player/BigSkillDefs.gd")
const RunModifierState = preload("res://Scripts/Progression/RunModifierState.gd")
const NightEventState = preload("res://Scripts/Progression/NightEventState.gd")

signal level_up_reached(new_level: int)
signal blessings_changed

const NON_DRINK_MENU_CAPS := {
	&"small_plate": 2,
	&"main_dish": 2,
	&"dessert": 1
}

const MEDIUM_DRINK_IDS: Array[StringName] = [
	TestItemDefs.DRINK_QINGMEI_LIGHT_FERMENT_ID,
	TestItemDefs.DRINK_DOUBLE_FERMENT_ID,
	TestItemDefs.DRINK_STONEFLOWER_HONEY_ID,
	TestItemDefs.DRINK_SUNWHEEL_INFUSION_ID
]

const HIGH_DRINK_IDS: Array[StringName] = [
	TestItemDefs.DRINK_ROYAL_AGED_ID,
	TestItemDefs.DRINK_MOON_DEW_ID,
	TestItemDefs.DRINK_SCORCH_DOUBLE_FERMENT_ID
]

var gold: int = 0
var xp: int = 0
var level: int = 1
var xp_for_next_level: int = 20
var day_index: int = 0
const INITIAL_BLESSING_POINTS: int = 0
var blessing_points: int = INITIAL_BLESSING_POINTS
var blessing_refreshes: int = 3
var skill_refreshes: int = 3
var menu_refreshes: int = 3
var menu_offer_generation: int = 0
var event_menu_target: StringName = &""
var events := NightEventState.new()
var small_skill_variant: StringName = SmallSkillDefs.BASE
var big_skill_variant: StringName = BigSkillDefs.BASE
var pending_small_skill_upgrade: bool = false
var pending_big_skill_upgrade: bool = false
var seen_blessings: Dictionary = {}
var seen_mechanism_briefings: Dictionary = {}
var shop_stat_purchase_counts: Dictionary = {}
var owned_shop_blessings: Dictionary = {}
var forged_attributes: Dictionary = {}
var map_mechanism_order: Array[StringName] = []
var modifiers := RunModifierState.new()

var menu_drink_ids: Array[StringName] = []
var menu_non_drink_ids: Array[StringName] = []
# Kept as a compatibility mirror for older callers and snapshots.
var menu_dish_ids: Array[StringName] = []

var pending_menu_offer_ids: Array[StringName] = []
var pending_menu_offer_kind: StringName = &""
var pending_menu_replace_index: int = -1
var pending_menu_replacement_ids: Array[StringName] = []
var menu_max_size: int = 5

func reset(starting_gold: int, starting_day_index: int = 0, map_mechanism_seed: int = -1) -> void:
	gold = max(starting_gold, 0)
	xp = 0
	level = 1
	xp_for_next_level = 20
	day_index = max(starting_day_index, 0)
	blessing_points = INITIAL_BLESSING_POINTS
	blessing_refreshes = 3
	skill_refreshes = 3
	menu_refreshes = 3
	menu_offer_generation = 0
	event_menu_target = &""
	events.reset()
	small_skill_variant = SmallSkillDefs.BASE
	big_skill_variant = BigSkillDefs.BASE
	pending_small_skill_upgrade = false
	pending_big_skill_upgrade = false
	seen_blessings.clear()
	seen_mechanism_briefings.clear()
	shop_stat_purchase_counts.clear()
	owned_shop_blessings.clear()
	blessings_changed.emit()
	forged_attributes.clear()
	modifiers.reset(map_mechanism_seed)
	_initialize_map_mechanism_order(map_mechanism_seed)
	menu_drink_ids = [
		TestItemDefs.DRINK_OASIS_WINE_ID,
		TestItemDefs.DRINK_GOLD_ALE_ID,
		TestItemDefs.DRINK_QINGMEI_WINE_ID
	]
	menu_non_drink_ids = [
		TestItemDefs.DISH_CRISP_PLATE_ID,
		TestItemDefs.DISH_WHITE_PLATE_ID
	]
	_clear_pending_menu_offer()
	_sync_legacy_menu_ids()

func apply_snapshot(snapshot: Dictionary) -> void:
	if snapshot.is_empty():
		return
	if snapshot.has("run_modifiers"):
		modifiers.restore(snapshot["run_modifiers"])
	if snapshot.has("night_events"):
		events.restore(snapshot["night_events"])
	menu_refreshes = maxi(int(snapshot.get("menu_refreshes", menu_refreshes)), 0)
	menu_offer_generation = int(snapshot.get("menu_offer_generation", menu_offer_generation))
	event_menu_target = StringName(snapshot.get("event_menu_target", &""))
	if snapshot.has("pending_menu_offer_ids"):
		pending_menu_offer_ids.assign(snapshot.pending_menu_offer_ids)
		pending_menu_offer_kind = StringName(snapshot.get("pending_menu_offer_kind", &""))
	gold = max(int(snapshot.get("gold", gold)), 0)
	xp = max(int(snapshot.get("xp", xp)), 0)
	level = max(int(snapshot.get("level", level)), 1)
	xp_for_next_level = max(int(snapshot.get("xp_for_next_level", xp_for_next_level)), 1)
	day_index = max(int(snapshot.get("day_index", day_index)), 0)
	blessing_points = max(int(snapshot.get("blessing_points", blessing_points)), 0)
	blessing_refreshes = max(int(snapshot.get("blessing_refreshes", blessing_refreshes)), 0)
	skill_refreshes = max(int(snapshot.get("skill_refreshes", skill_refreshes)), 0)
	small_skill_variant = StringName(snapshot.get("small_skill_variant", small_skill_variant))
	big_skill_variant = StringName(snapshot.get("big_skill_variant", big_skill_variant))
	pending_small_skill_upgrade = bool(snapshot.get("pending_small_skill_upgrade", pending_small_skill_upgrade))
	pending_big_skill_upgrade = bool(snapshot.get("pending_big_skill_upgrade", pending_big_skill_upgrade))
	var snapshot_seen_blessings: Variant = snapshot.get("seen_blessings", null)
	if snapshot_seen_blessings is Dictionary:
		seen_blessings = snapshot_seen_blessings.duplicate(true)
	seen_mechanism_briefings = Dictionary(snapshot.get("seen_mechanism_briefings", {})).duplicate(true)
	var snapshot_owned_blessings: Variant = snapshot.get("owned_blessings", null)
	if snapshot_owned_blessings is Dictionary:
		owned_shop_blessings = snapshot_owned_blessings.duplicate(true)
		blessings_changed.emit()
	var snapshot_attributes: Variant = snapshot.get("forged_attributes", null)
	if snapshot_attributes is Dictionary:
		forged_attributes = snapshot_attributes.duplicate(true)
	var snapshot_mechanism_order: Variant = snapshot.get("map_mechanism_order", null)
	if snapshot_mechanism_order is Array:
		_set_map_mechanism_order(snapshot_mechanism_order)
	else:
		_initialize_map_mechanism_order()

	var snapshot_drinks: Variant = snapshot.get("menu_drink_ids", null)
	var snapshot_non_drinks: Variant = snapshot.get("menu_non_drink_ids", null)
	if snapshot_drinks is Array or snapshot_non_drinks is Array:
		if snapshot_drinks is Array:
			menu_drink_ids = _clean_menu_ids(snapshot_drinks, true)
		if snapshot_non_drinks is Array:
			menu_non_drink_ids = _clean_menu_ids(snapshot_non_drinks, false)
	else:
		var snapshot_menu: Variant = snapshot.get("menu_dish_ids", null)
		if snapshot_menu is Array:
			menu_drink_ids = []
			menu_non_drink_ids = []
			for dish_id in snapshot_menu:
				_add_to_menu(StringName(dish_id))

	_ensure_menu_defaults()
	_sync_legacy_menu_ids()

func get_snapshot() -> Dictionary:
	return {
		"run_modifiers": modifiers.snapshot(),
		"night_events": events.snapshot(),
		"menu_refreshes": menu_refreshes,
		"menu_offer_generation": menu_offer_generation,
		"event_menu_target": event_menu_target,
		"pending_menu_offer_ids": pending_menu_offer_ids.duplicate(),
		"pending_menu_offer_kind": pending_menu_offer_kind,
		"gold": gold,
		"xp": xp,
		"level": level,
		"xp_for_next_level": xp_for_next_level,
		"day_index": day_index,
		"blessing_points": blessing_points,
		"blessing_refreshes": blessing_refreshes,
		"skill_refreshes": skill_refreshes,
		"small_skill_variant": small_skill_variant,
		"big_skill_variant": big_skill_variant,
		"pending_small_skill_upgrade": pending_small_skill_upgrade,
		"pending_big_skill_upgrade": pending_big_skill_upgrade,
		"seen_blessings": seen_blessings.duplicate(true),
		"seen_mechanism_briefings": seen_mechanism_briefings.duplicate(true),
		"owned_blessings": owned_shop_blessings.duplicate(true),
		"forged_attributes": forged_attributes.duplicate(true),
		"map_mechanism_order": map_mechanism_order.duplicate(),
		"menu_drink_ids": menu_drink_ids.duplicate(),
		"menu_non_drink_ids": menu_non_drink_ids.duplicate(),
		"menu_dish_ids": get_menu_dish_ids()
	}

func can_afford(cost: int) -> bool:
	return gold >= cost

func spend_gold(cost: int) -> bool:
	if cost <= 0:
		return true
	if gold < cost:
		return false
	gold -= cost
	return true

func add_gold(amount: int) -> void:
	gold = max(gold + amount, 0)

func apply_order_rewards(order_data: Dictionary) -> void:
	add_gold(int(order_data.get("gold_reward", 0)))
	add_xp(int(order_data.get("xp_reward", 0)))

func add_xp(amount: int) -> void:
	xp = max(xp + amount, 0)
	_resolve_level_ups()

func get_stat_purchase_count(stat_id: StringName) -> int:
	return int(shop_stat_purchase_counts.get(stat_id, 0))

func increment_stat_purchase_count(stat_id: StringName) -> int:
	var next_count: int = get_stat_purchase_count(stat_id) + 1
	shop_stat_purchase_counts[stat_id] = next_count
	return next_count

func add_blessing(blessing_id: StringName) -> void:
	if owned_shop_blessings.has(blessing_id):
		return
	owned_shop_blessings[blessing_id] = true
	blessings_changed.emit()

func remove_blessing(blessing_id: StringName) -> bool:
	if not owned_shop_blessings.has(blessing_id):
		return false
	owned_shop_blessings.erase(blessing_id)
	blessings_changed.emit()
	return true

func get_owned_blessing_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	for blessing_id in owned_shop_blessings.keys():
		result.append(StringName(blessing_id))
	return result

func add_blessing_points(amount: int = 1) -> void:
	blessing_points = maxi(blessing_points + amount, 0)

func get_blessing_points() -> int:
	return blessing_points

func spend_blessing_point() -> bool:
	if blessing_points <= 0:
		return false
	blessing_points -= 1
	return true

func get_blessing_refreshes() -> int:
	return blessing_refreshes

func add_blessing_refreshes(amount: int = 1) -> void:
	blessing_refreshes = maxi(blessing_refreshes + amount, 0)

func grant_completed_day_blessing_refresh(completed_day_index: int) -> bool:
	# Day indices are zero-based. Days 1-6 grant one refresh; day 7 does not.
	if completed_day_index < 0 or completed_day_index >= 6:
		return false
	add_blessing_refreshes(1)
	return true

func spend_blessing_refresh() -> bool:
	if blessing_refreshes <= 0:
		return false
	blessing_refreshes -= 1
	return true

func get_skill_refreshes() -> int:
	return skill_refreshes

func add_skill_refreshes(amount: int = 1) -> void:
	skill_refreshes = maxi(skill_refreshes + amount, 0)

func spend_skill_refresh() -> bool:
	if skill_refreshes <= 0:
		return false
	skill_refreshes -= 1
	return true

func get_skill_variant(kind: StringName) -> StringName:
	return small_skill_variant if kind == &"small" else big_skill_variant

func has_pending_skill_upgrade() -> bool:
	return pending_small_skill_upgrade or pending_big_skill_upgrade

func get_pending_skill_upgrade_kind() -> StringName:
	if pending_small_skill_upgrade:
		return &"small"
	if pending_big_skill_upgrade:
		return &"big"
	return &""

func queue_skill_upgrade_for_completed_day(completed_day_index: int) -> void:
	# Day 2 and day 4 use zero-based completion indices 1 and 3.
	if completed_day_index == 1:
		pending_small_skill_upgrade = true
	elif completed_day_index == 3:
		pending_big_skill_upgrade = true

func apply_skill_upgrade(kind: StringName, variant_id: StringName) -> bool:
	if kind == &"small":
		if not pending_small_skill_upgrade:
			return false
		small_skill_variant = variant_id
		pending_small_skill_upgrade = false
		return true
	if kind == &"big":
		if not pending_big_skill_upgrade:
			return false
		big_skill_variant = variant_id
		pending_big_skill_upgrade = false
		return true
	return false

func has_seen_blessing(blessing_id: StringName) -> bool:
	return seen_blessings.has(blessing_id)

func mark_blessing_seen(blessing_id: StringName) -> void:
	if blessing_id != &"":
		seen_blessings[blessing_id] = true

func get_seen_blessings() -> Dictionary:
	return seen_blessings.duplicate(true)

func add_forged_attribute(option: Dictionary) -> void:
	var attribute_id := StringName(option.get("attribute_id", &""))
	if attribute_id == &"":
		return
	var entry: Dictionary = forged_attributes.get(attribute_id, {}).duplicate(true)
	entry["fixed"] = float(entry.get("fixed", 0.0)) + float(option.get("fixed", 0.0))
	for key in ["total_attack", "total_health", "total_move_speed", "total_work", "skill_cooldown_multiplier", "total_skill_power", "final_damage_reduction", "percent_health_regen", "omnivamp"]:
		if option.has(key):
			if key == "skill_cooldown_multiplier":
				entry[key] = float(entry.get(key, 1.0)) * float(option.get(key, 1.0))
			else:
				entry[key] = float(entry.get(key, 0.0)) + float(option.get(key, 0.0))
	entry["count"] = int(entry.get("count", 0)) + 1
	forged_attributes[attribute_id] = entry

func get_forged_attribute(attribute_id: StringName) -> Dictionary:
	return forged_attributes.get(attribute_id, {}).duplicate(true)

func get_forged_attributes() -> Dictionary:
	return forged_attributes.duplicate(true)

func get_map_mechanism_order() -> Array[StringName]:
	return map_mechanism_order.duplicate()

func get_active_map_mechanism_ids(for_day_index: int = -1) -> Array[StringName]:
	var target_day_index := day_index if for_day_index < 0 else for_day_index
	# Day indices are zero-based: day 1 has none; days 2/3/4 unlock one more.
	var unlocked_count := clampi(target_day_index, 0, MapMechanismDefs.MECHANISM_IDS.size())
	return map_mechanism_order.slice(0, unlocked_count)

func get_boss_enhanced_map_mechanism_id(for_day_index: int = -1) -> StringName:
	var target_day_index := day_index if for_day_index < 0 else for_day_index
	# Only the day-4 small Boss is enhanced. It always enhances the mechanism
	# introduced on day 2, i.e. the first entry in the persistent order.
	if target_day_index != 3 or map_mechanism_order.is_empty():
		return &""
	return map_mechanism_order[0]

func _initialize_map_mechanism_order(seed: int = -1) -> void:
	map_mechanism_order = MapMechanismDefs.get_all_ids()
	var rng := RandomNumberGenerator.new()
	if seed < 0:
		rng.randomize()
	else:
		rng.seed = seed
	for index in range(map_mechanism_order.size() - 1, 0, -1):
		var swap_index := rng.randi_range(0, index)
		var temporary := map_mechanism_order[index]
		map_mechanism_order[index] = map_mechanism_order[swap_index]
		map_mechanism_order[swap_index] = temporary

func _set_map_mechanism_order(values: Array) -> void:
	map_mechanism_order.clear()
	for value in values:
		var mechanism_id := StringName(value)
		if mechanism_id in MapMechanismDefs.MECHANISM_IDS and mechanism_id not in map_mechanism_order:
			map_mechanism_order.append(mechanism_id)
	for mechanism_id in MapMechanismDefs.MECHANISM_IDS:
		if mechanism_id not in map_mechanism_order:
			map_mechanism_order.append(mechanism_id)

func get_menu_dish_ids() -> Array[StringName]:
	_sync_legacy_menu_ids()
	return menu_dish_ids.duplicate()

func get_menu_drink_ids() -> Array[StringName]:
	return menu_drink_ids.duplicate()

func get_menu_non_drink_ids() -> Array[StringName]:
	return menu_non_drink_ids.duplicate()

func has_menu_dish(dish_id: StringName) -> bool:
	return dish_id in menu_drink_ids or dish_id in menu_non_drink_ids

func set_menu_max_size(new_size: int) -> void:
	menu_max_size = maxi(new_size, 1)

func get_non_drink_menu_capacity() -> int:
	var capacity: int = 0
	for value in NON_DRINK_MENU_CAPS.values():
		capacity += int(value)
	return capacity

func is_non_drink_menu_full() -> bool:
	return menu_non_drink_ids.size() >= get_non_drink_menu_capacity()

func get_menu_category_count(category: StringName) -> int:
	var count: int = 0
	for dish_id in menu_non_drink_ids:
		if TestItemDefs.get_item_category(dish_id) == category:
			count += 1
	return count

func get_menu_category_capacity(category: StringName) -> int:
	return int(NON_DRINK_MENU_CAPS.get(category, 0))

func should_offer_drink_menu_update() -> bool:
	if day_index == 1:
		return not _contains_any(menu_drink_ids, [TestItemDefs.DRINK_QINGMEI_LIGHT_FERMENT_ID, TestItemDefs.DRINK_DOUBLE_FERMENT_ID])
	if day_index == 2:
		return not _contains_any(menu_drink_ids, [TestItemDefs.DRINK_STONEFLOWER_HONEY_ID, TestItemDefs.DRINK_SUNWHEEL_INFUSION_ID])
	if day_index == 4:
		return not _contains_any(menu_drink_ids, HIGH_DRINK_IDS)
	return false

func has_pending_menu_offer() -> bool:
	return not pending_menu_offer_ids.is_empty()

func has_pending_drink_offer() -> bool:
	return pending_menu_offer_kind == &"drink" and has_pending_menu_offer()

func has_pending_non_drink_offer() -> bool:
	return pending_menu_offer_kind == &"non_drink" and has_pending_menu_offer()

func create_next_drink_offer(option_count: int = 3) -> Array[StringName]:
	_clear_pending_menu_offer()
	var source_ids: Array[StringName] = []
	if day_index == 1:
		source_ids = [TestItemDefs.DRINK_QINGMEI_LIGHT_FERMENT_ID, TestItemDefs.DRINK_DOUBLE_FERMENT_ID]
	elif day_index == 2:
		source_ids = [TestItemDefs.DRINK_STONEFLOWER_HONEY_ID, TestItemDefs.DRINK_SUNWHEEL_INFUSION_ID]
	elif day_index == 4:
		source_ids = HIGH_DRINK_IDS.duplicate()
	else:
		return []

	var candidates: Array[StringName] = []
	for drink_id in source_ids:
		if drink_id not in menu_drink_ids and IngredientSourceDefs.is_menu_recipe_available(drink_id, day_index):
			candidates.append(drink_id)
	_set_pending_offer(_take_offer_candidates(candidates, option_count), &"drink")
	return pending_menu_offer_ids.duplicate()

func create_next_non_drink_offer(option_count: int = 3) -> Array[StringName]:
	_clear_pending_menu_offer()
	var owned: Dictionary = {}
	for dish_id in menu_non_drink_ids:
		owned[dish_id] = true

	var candidates: Array[StringName] = []
	for dish_id in TestItemDefs.get_all_dish_ids():
		if not TestItemDefs.is_dish(dish_id) or TestItemDefs.is_drink(dish_id):
			continue
		if _is_special_recipe(dish_id):
			continue
		if not IngredientSourceDefs.is_menu_recipe_available(dish_id, day_index):
			continue
		if owned.has(dish_id):
			continue
		var category := TestItemDefs.get_item_category(dish_id)
		if not is_non_drink_menu_full() and get_menu_category_count(category) >= get_menu_category_capacity(category):
			continue
		candidates.append(dish_id)

	# At each new region's first night, make its introduction an actual choice.
	if day_index in [2, 4]:
		var introduced_stage := IngredientSourceDefs.get_menu_stage(day_index)
		var regional_candidates: Array[StringName] = []
		for candidate in candidates:
			if IngredientSourceDefs.get_dish_stage(candidate) == introduced_stage:
				regional_candidates.append(candidate)
		if not regional_candidates.is_empty():
			candidates = regional_candidates

	candidates.sort_custom(func(a: StringName, b: StringName) -> bool:
		var category_a := TestItemDefs.get_item_category(a)
		var category_b := TestItemDefs.get_item_category(b)
		var remaining_a := get_menu_category_capacity(category_a) - get_menu_category_count(category_a)
		var remaining_b := get_menu_category_capacity(category_b) - get_menu_category_count(category_b)
		if remaining_a != remaining_b:
			return remaining_a > remaining_b
		var diff_a := TestItemDefs.get_dish_difficulty(a)
		var diff_b := TestItemDefs.get_dish_difficulty(b)
		if diff_a != diff_b:
			return diff_a < diff_b
		return String(a) < String(b)
	)
	_set_pending_offer(_take_offer_candidates(candidates, option_count), &"non_drink")
	if is_non_drink_menu_full() and not pending_menu_offer_ids.is_empty():
		_set_replacement_ids_for_offer(pending_menu_offer_ids[0])
	return pending_menu_offer_ids.duplicate()

func choose_menu_offer(offer_index: int, replace_index: int = -1) -> bool:
	if offer_index < 0 or offer_index >= pending_menu_offer_ids.size():
		return false
	var dish_id: StringName = pending_menu_offer_ids[offer_index]
	if has_menu_dish(dish_id):
		return false
	if pending_menu_offer_kind == &"event":
		var menu: Array[StringName] = menu_drink_ids if TestItemDefs.is_drink(event_menu_target) else menu_non_drink_ids
		var index := menu.find(event_menu_target)
		if index < 0:
			return false
		menu[index] = dish_id
		event_menu_target = &""
		_sync_legacy_menu_ids()
		_clear_pending_menu_offer()
		return true

	if pending_menu_offer_kind == &"drink":
		if not TestItemDefs.is_drink(dish_id):
			return false
		menu_drink_ids.append(dish_id)
	else:
		if TestItemDefs.is_drink(dish_id):
			return false
		if not is_non_drink_menu_full():
			var category := TestItemDefs.get_item_category(dish_id)
			if get_menu_category_count(category) >= get_menu_category_capacity(category):
				return false
			menu_non_drink_ids.append(dish_id)
		else:
			_set_replacement_ids_for_offer(dish_id)
			var safe_replace_index := replace_index
			if safe_replace_index < 0:
				safe_replace_index = pending_menu_replace_index
			if safe_replace_index < 0 or safe_replace_index >= menu_dish_ids.size():
				return false
			var old_dish_id: StringName = menu_dish_ids[safe_replace_index]
			if old_dish_id not in pending_menu_replacement_ids:
				return false
			var old_non_drink_index := menu_non_drink_ids.find(old_dish_id)
			if old_non_drink_index < 0:
				return false
			menu_non_drink_ids[old_non_drink_index] = dish_id

	_sync_legacy_menu_ids()
	_clear_pending_menu_offer()
	return true

func _set_pending_offer(offer_ids: Array[StringName], offer_kind: StringName) -> void:
	pending_menu_offer_ids = offer_ids.duplicate()
	pending_menu_offer_kind = offer_kind
	pending_menu_replace_index = -1
	pending_menu_replacement_ids.clear()

func _set_replacement_ids_for_offer(dish_id: StringName) -> void:
	pending_menu_replacement_ids.clear()
	var category := TestItemDefs.get_item_category(dish_id)
	for current_dish_id in menu_non_drink_ids:
		if TestItemDefs.get_item_category(current_dish_id) == category:
			pending_menu_replacement_ids.append(current_dish_id)
	if not pending_menu_replacement_ids.is_empty():
		pending_menu_replace_index = menu_dish_ids.find(pending_menu_replacement_ids[0])

func _take_offer_candidates(candidates: Array[StringName], option_count: int) -> Array[StringName]:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("menu:%d:%d:%d" % [modifiers.run_seed, day_index, menu_offer_generation])
	menu_offer_generation += 1
	var shuffled: Array = preload("res://Scripts/Progression/RunModifierDefs.gd").shuffled(candidates, rng)
	var result: Array[StringName] = []
	for candidate in shuffled:
		if result.size() >= maxi(option_count, 1):
			break
		result.append(candidate)
	return result

func event_menu_candidates(old_id: StringName, relation: StringName) -> Array[StringName]:
	var result: Array[StringName] = []
	var difference: int = 1 if relation == &"higher" else (-1 if relation == &"lower" else 0)
	var difficulty := TestItemDefs.get_dish_difficulty(old_id) + difference
	for id: StringName in TestItemDefs.get_all_dish_ids():
		if has_menu_dish(id) or TestItemDefs.get_item_category(id) != TestItemDefs.get_item_category(old_id):
			continue
		if TestItemDefs.get_dish_difficulty(id) == difficulty and not _is_special_recipe(id):
			if IngredientSourceDefs.is_menu_recipe_available(id, day_index):
				result.append(id)
	return result

func create_event_menu_offer(old_id: StringName, relation: StringName) -> bool:
	if not has_menu_dish(old_id) or _is_special_recipe(old_id) or has_pending_menu_offer():
		return false
	var candidates := event_menu_candidates(old_id, relation)
	if candidates.is_empty():
		return false
	event_menu_target = old_id
	_set_pending_offer(_take_offer_candidates(candidates, 3), &"event")
	return true

func refresh_menu_offer(option_count: int = 3) -> bool:
	if menu_refreshes <= 0 or pending_menu_offer_kind not in [&"drink", &"non_drink"]:
		return false
	var old_ids := pending_menu_offer_ids.duplicate()
	var old_kind := pending_menu_offer_kind
	var old_generation := menu_offer_generation
	# Build the eligible pool with the same rules as the original offer.
	if old_kind == &"drink":
		create_next_drink_offer(1000)
	else:
		create_next_non_drink_offer(1000)
	var pool := pending_menu_offer_ids.duplicate()
	var unseen := pool.filter(func(id: StringName) -> bool: return id not in old_ids)
	if unseen.is_empty():
		_set_pending_offer(old_ids, old_kind)
		menu_offer_generation = old_generation
		return false
	# Prefer new recipes; retain an old option only when the pool is small.
	var next_ids: Array[StringName] = []
	next_ids.assign(unseen.slice(0, option_count))
	for id: StringName in pool:
		if next_ids.size() >= option_count:
			break
		if id not in next_ids:
			next_ids.append(id)
	_set_pending_offer(next_ids, old_kind)
	menu_refreshes -= 1
	return true

func _is_special_recipe(id: StringName) -> bool:
	for entry: Dictionary in TestItemDefs.get_display_recipe_for_dish(id):
		if TestItemDefs.is_boss_ingredient(StringName(entry.get("item_id", &""))):
			return true
	return false

func _clear_pending_menu_offer() -> void:
	pending_menu_offer_ids.clear()
	pending_menu_offer_kind = &""
	pending_menu_replace_index = -1
	pending_menu_replacement_ids.clear()

func _clean_menu_ids(values: Array, drinks_only: bool) -> Array[StringName]:
	var result: Array[StringName] = []
	for value in values:
		var item_id := StringName(value)
		if not TestItemDefs.is_dish(item_id):
			continue
		if TestItemDefs.is_drink(item_id) != drinks_only:
			continue
		if item_id not in result:
			result.append(item_id)
	return result

func _add_to_menu(item_id: StringName) -> void:
	if not TestItemDefs.is_dish(item_id) or has_menu_dish(item_id):
		return
	if TestItemDefs.is_drink(item_id):
		menu_drink_ids.append(item_id)
	else:
		menu_non_drink_ids.append(item_id)

func _ensure_menu_defaults() -> void:
	if menu_drink_ids.is_empty():
		menu_drink_ids = [TestItemDefs.DRINK_OASIS_WINE_ID, TestItemDefs.DRINK_GOLD_ALE_ID, TestItemDefs.DRINK_QINGMEI_WINE_ID]
	if menu_non_drink_ids.is_empty():
		menu_non_drink_ids = [
			TestItemDefs.DISH_CRISP_PLATE_ID,
			TestItemDefs.DISH_WHITE_PLATE_ID
		]

func _sync_legacy_menu_ids() -> void:
	menu_dish_ids.clear()
	menu_dish_ids.append_array(menu_drink_ids)
	menu_dish_ids.append_array(menu_non_drink_ids)

func _contains_any(values: Array[StringName], candidates: Array[StringName]) -> bool:
	for candidate in candidates:
		if candidate in values:
			return true
	return false

func _resolve_level_ups() -> void:
	while xp >= xp_for_next_level:
		xp -= xp_for_next_level
		level += 1
		level_up_reached.emit(level)
		xp_for_next_level = _get_xp_requirement_for_level(level)

func _get_xp_requirement_for_level(target_level: int) -> int:
	return 20 + max(target_level - 1, 0) * 10
