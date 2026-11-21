extends RefCounted

## Single, player-facing source map for ingredient planning.
## Keep this table small and data-only so signs, cabinet hints and the codex
## can all use the same wording without duplicating source rules.
const TestItemDefs = preload("res://Scripts/Kitchen/TestItemDefs.gd")

const REGION_ORDER: Array[StringName] = [&"near", &"left", &"right", &"top"]
const REGION_LABELS := {
	&"near": "中",
	&"left": "西",
	&"right": "东",
	&"top": "北"
}
const REGION_DISPLAY_NAMES := {
	&"near": "中部战斗区",
	&"left": "西部战斗区",
	&"right": "东部战斗区",
	&"top": "北部战斗区"
}

const FORAGE_ITEMS := {
	&"near": [TestItemDefs.VEG_LEAF_ID, TestItemDefs.RICE_ID, TestItemDefs.EGG_ID],
	&"left": [TestItemDefs.CABBAGE_ID, TestItemDefs.TOFU_ID, TestItemDefs.EGG_ID],
	&"right": [TestItemDefs.VEG_ROOT_ID, TestItemDefs.MUSHROOM_ID, TestItemDefs.SUN_SEED_ID],
	&"top": []
}

const ENEMY_DROPS := {
	&"near": {
		&"chaser": TestItemDefs.MEAT_WHITE_ID,
		&"sprinter": TestItemDefs.SHRIMP_ID
	},
	&"left": {
		&"ranged": TestItemDefs.VEG_LEAF_ID,
		&"sniper": TestItemDefs.MUSHROOM_ID
	},
	&"right": {
		&"slammer": TestItemDefs.MEAT_RED_ID,
		&"bruiser": TestItemDefs.CAMEL_MEAT_ID
	},
	&"top": {
		&"bullet_fan": TestItemDefs.SUN_SEED_ID,
		&"orbiter": TestItemDefs.TOFU_ID,
		&"splitter": TestItemDefs.VEG_ROOT_ID
	}
}

static func get_region_label(region_id: StringName) -> String:
	return String(REGION_LABELS.get(region_id, region_id))

## All regions remain explorable. Only recipe offers follow this introduction order.
static func get_menu_stage(day_index: int) -> int:
	return 1 if day_index < 2 else (2 if day_index < 4 else 3)

static func get_ingredient_stage(item_id: StringName) -> int:
	var earliest := 4
	for source: Dictionary in get_sources_for_item(item_id):
		var stage := int({&"near": 1, &"left": 2, &"right": 3, &"top": 3}.get(source.region, 4))
		earliest = mini(earliest, stage)
	return earliest

static func get_dish_stage(dish_id: StringName) -> int:
	var stage := 1
	for entry: Dictionary in TestItemDefs.get_display_recipe_for_dish(dish_id):
		var item_id := StringName(entry.get("item_id", &""))
		if TestItemDefs.is_ingredient(item_id):
			stage = maxi(stage, get_ingredient_stage(item_id))
		elif TestItemDefs.is_barrel_drink(item_id):
			stage = maxi(stage, get_ingredient_stage(TestItemDefs.get_barrel_input_item_id(item_id)))
	return stage

static func is_menu_recipe_available(dish_id: StringName, day_index: int) -> bool:
	return get_dish_stage(dish_id) <= get_menu_stage(day_index)

static func get_dish_source_text(dish_id: StringName) -> String:
	match get_dish_stage(dish_id):
		1: return "中区原料 · 开局可制作"
		2: return "中 / 左区原料 · 第3天起加入菜单候选"
		3: return "含右区原料 · 第5天起加入菜单候选"
		_: return "BOSS 专属食材 · 击败对应 BOSS 后制作"

static func get_region_display_name(region_id: StringName) -> String:
	return String(REGION_DISPLAY_NAMES.get(region_id, region_id))

static func get_forage_items(region_id: StringName) -> Array[StringName]:
	var result: Array[StringName] = []
	for item_id in FORAGE_ITEMS.get(region_id, []):
		result.append(StringName(item_id))
	return result

static func get_enemy_drop_items(region_id: StringName) -> Array[StringName]:
	var result: Array[StringName] = []
	for item_id in ENEMY_DROPS.get(region_id, {}).values():
		if item_id not in result:
			result.append(StringName(item_id))
	return result

static func get_enemy_drop_entries(region_id: StringName) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var drops: Dictionary = ENEMY_DROPS.get(region_id, {})
	for enemy_id in drops.keys():
		result.append({"enemy_id": StringName(enemy_id), "item_id": StringName(drops[enemy_id])})
	return result

static func get_enemy_home_region(enemy_id: StringName) -> StringName:
	for region_id in REGION_ORDER:
		if ENEMY_DROPS.get(region_id, {}).has(enemy_id):
			return region_id
	return &"near"

static func get_enemy_drop_item(enemy_id: StringName) -> StringName:
	for region_id in REGION_ORDER:
		var drops: Dictionary = ENEMY_DROPS.get(region_id, {})
		if drops.has(enemy_id):
			return StringName(drops[enemy_id])
	return &""

static func get_sources_for_item(item_id: StringName) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for region_id in REGION_ORDER:
		var methods: Array[String] = []
		if item_id in get_forage_items(region_id):
			methods.append("采集")
		if item_id in get_enemy_drop_items(region_id):
			methods.append("战斗")
		if not methods.is_empty():
			result.append({"region": region_id, "methods": methods})
	return result

static func format_source_hint(item_id: StringName) -> String:
	var sources := get_sources_for_item(item_id)
	if sources.is_empty():
		return "暂无来源记录"
	var parts: Array[String] = []
	for source in sources:
		var methods: Array = source.get("methods", [])
		parts.append("%s：%s" % [get_region_label(StringName(source.get("region", &""))), " / ".join(methods)])
	return "\n".join(parts)

static func format_item_list(item_ids: Array[StringName]) -> String:
	if item_ids.is_empty():
		return "暂无"
	var names: Array[String] = []
	for item_id in item_ids:
		var name := TestItemDefs.get_item_display_name(item_id)
		if name not in names:
			names.append(name)
	return "、".join(names)
