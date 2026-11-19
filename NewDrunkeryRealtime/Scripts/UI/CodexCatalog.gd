class_name CodexCatalog
extends RefCounted

const TestItemDefs = preload("res://Scripts/Kitchen/TestItemDefs.gd")
const FacilityCatalog = preload("res://Scripts/Facilities/FacilityCatalog.gd")

const BASIC_FACILITIES: Array[Dictionary] = [
	{"id": &"cut_station", "name": "切菜台", "cost": 24, "detail": "将生食材加工为切片。", "texture": "res://ArtResource/Cooker/cut_station.svg"},
	{"id": &"roast_station", "name": "烤台", "cost": 30, "detail": "自动烤制食材，经过全熟后继续加热会焦糊。", "texture": "res://ArtResource/Cooker/roast_station.svg"},
	{"id": &"grind_station", "name": "研磨台", "cost": 28, "detail": "将食材研磨为4份小料。", "texture": "res://ArtResource/Cooker/grind_station.svg"},
	{"id": &"prep_table", "name": "备料桌", "cost": 10, "detail": "存放食材、小料盒与盘子，增加料理区的备料空间。", "texture": "res://ArtResource/Restaurant/prep_table.svg"},
	{"id": &"conveyor", "name": "履带", "cost": 14, "detail": "占地两格，沿固定方向运输物品与玩家。", "texture": "res://ArtResource/Facilities/conveyor.svg"},
	{"id": &"lamp", "name": "明光灯", "cost": 16, "detail": "范围内加工、酿造、净化与培养效率+22%，并加速履带与摇摇车。", "texture": "res://ArtResource/Facilities/lamp.svg"}
]

static func get_dish_subcategories() -> Array[Dictionary]:
	return [
		{"id": &"drink", "name": "酒水"},
		{"id": &"small_plate", "name": "小菜"},
		{"id": &"main_dish", "name": "主菜"},
		{"id": &"dessert", "name": "甜品"}
	]

static func get_purchasable_facility_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	var seen: Dictionary = {}
	for source: Dictionary in BASIC_FACILITIES:
		_append_facility_entry(entries, seen, source)
	for source: Dictionary in FacilityCatalog.ENTRIES:
		_append_facility_entry(entries, seen, source)
	return entries

static func _append_facility_entry(entries: Array[Dictionary], seen: Dictionary, source: Dictionary) -> void:
	var id := StringName(source.get("id", &""))
	if id == &"" or seen.has(id):
		return
	seen[id] = true
	var texture_path := String(source.get("texture", ""))
	if texture_path.is_empty():
		texture_path = "res://ArtResource/Facilities/%s.svg" % String(id)
	var texture: Texture2D = load(texture_path) if ResourceLoader.exists(texture_path) else null
	var limit := int(source.get("limit", 0))
	var limit_text := "可重复购买" if limit <= 0 else "最多购买 %d 个" % limit
	var detail := String(source.get("detail", source.get("description", "")))
	entries.append({
		"id": id,
		"name": String(source.get("name", "设施")),
		"body": "可购买设施\n基础价格：%d 金币\n购买限制：%s\n\n%s" % [int(source.get("cost", 0)), limit_text, detail],
		"texture": texture
	})

static func get_ingredient_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for item_id in TestItemDefs.get_all_ingredient_ids():
		var meta := _get_ingredient_meta(item_id)
		entries.append({
			"id": item_id,
			"name": TestItemDefs.get_item_display_name(item_id),
			"body": "类型：%s\n主要来源：%s\n设计职责：%s" % [
				meta.get("kind", "食材"),
				meta.get("source", "战斗区与采集"),
				TestItemDefs.get_item_description(item_id)
			],
			"texture": TestItemDefs.get_item_texture(item_id)
		})
	return entries

static func get_battle_zone_entries() -> Array[Dictionary]:
	return [
		{"id": &"near", "name": "近门旱地", "body": "常驻敌人：沙原禽、疾风沙兔\n主要掉落：沙原禽肉、沙兔肉\n特点：距离料理区最近，适合优先处理基础肉类。", "texture": null},
		{"id": &"left", "name": "西侧花冠区", "body": "常驻敌人：脆芽甲虫、莳萝沙甲\n主要掉落：脆脆芽、莳萝\n采集：可采集该区的场景食材\n特点：以非肉食材为主，远程敌人较多。", "texture": null},
		{"id": &"right", "name": "东侧砂谷区", "body": "常驻敌人：红鬃岩羊、沙漠战驼\n主要掉落：红鬃羊肉、沙漠驼肉\n采集：可采集该区的场景食材\n特点：以肉类为主，敌人更耐打，返程距离较长。", "texture": null},
		{"id": &"top", "name": "顶部沙丘区", "body": "常驻敌人：日轮沙蛾、砂冠守卫、裂根兽\n主要掉落：太阳籽、砂冠花、沙薯\n采集：可采集该区的场景食材\n特点：高阶非肉食材集中区域，通常需要更晚解锁。", "texture": null}
	]

static func get_dish_entries(category: StringName = &"") -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for dish_id in TestItemDefs.get_all_dish_ids():
		var dish_category := TestItemDefs.get_item_category(dish_id)
		if category != &"" and dish_category != category:
			continue
		entries.append(_build_dish_entry(dish_id))
	return entries

static func _build_dish_entry(dish_id: StringName) -> Dictionary:
	var tier := _get_tier(dish_id)

	return {
		"id": dish_id,
		"name": TestItemDefs.get_item_display_name(dish_id),
		"category": TestItemDefs.get_item_category(dish_id),
		"body": "等级：%s\n备菜：%s\n配方：%s\n说明：%s" % [
			tier,
			TestItemDefs.get_dish_preparation_text(dish_id),
			_format_recipe(dish_id),
			TestItemDefs.get_item_description(dish_id)
		],
		"texture": TestItemDefs.get_item_texture(dish_id),
		"process_states": _get_dish_process_states(dish_id)
	}

static func _get_tier(dish_id: StringName) -> String:
	if TestItemDefs.is_barrel_drink(dish_id):
		return "初级"
	match TestItemDefs.get_dish_difficulty(dish_id):
		1:
			return "初级"
		2:
			return "中级"
		_:
			return "高级"

static func _get_ingredient_meta(item_id: StringName) -> Dictionary:
	match item_id:
		TestItemDefs.MEAT_RED_ID:
			return {"kind": "肉类", "rarity": "初级", "source": "第一区主产；二区、三区普通敌人少量掉落"}
		TestItemDefs.MEAT_WHITE_ID, TestItemDefs.SHRIMP_ID:
			return {"kind": "肉类", "rarity": "中级", "source": "第二区主产；第三区少量回流"}
		TestItemDefs.CAMEL_MEAT_ID:
			return {"kind": "肉类", "rarity": "高级", "source": "第三区精英敌人主产；BOSS区可能额外掉落"}
		TestItemDefs.VEG_LEAF_ID, TestItemDefs.VEG_ROOT_ID, TestItemDefs.RICE_ID:
			return {"kind": "非肉食材", "rarity": "初级", "source": "第一区主采；第三区偶发回流"}
		TestItemDefs.CABBAGE_ID, TestItemDefs.MUSHROOM_ID, TestItemDefs.SUN_SEED_ID:
			return {"kind": "非肉食材", "rarity": "中级", "source": "第二区主采；第三区稳定回流"}
		TestItemDefs.EGG_ID, TestItemDefs.TOFU_ID:
			return {"kind": "非肉食材", "rarity": "高级", "source": "第三区主采；精英敌人少量掉落"}
		_:
			return {"kind": "食材", "rarity": "未定", "source": "战斗区与采集"}

static func _format_recipe(dish_id: StringName) -> String:
	if TestItemDefs.is_barrel_drink(dish_id):
		var input_id := TestItemDefs.get_barrel_input_item_id(dish_id)
		return "%s（酿）*1" % TestItemDefs.get_item_display_name(input_id)

	var parts: Array[String] = []
	for entry in TestItemDefs.get_recipe_for_dish(dish_id):
		if not (entry is Dictionary):
			continue
		var item_id := StringName(entry.get("item_id", &""))
		var count := int(entry.get("count", 1))
		parts.append("%s（%s）*%d" % [
			TestItemDefs.get_item_display_name(item_id),
			_format_entry_process(entry),
			count
		])
	return " + ".join(parts)

static func _format_entry_process(entry: Dictionary) -> String:
	return TestItemDefs.get_recipe_entry_process_text(entry)

static func _get_dish_process_states(dish_id: StringName) -> Array[StringName]:
	var result: Array[StringName] = []
	for entry in TestItemDefs.get_recipe_for_dish(dish_id):
		if not (entry is Dictionary):
			continue
		for process_state in TestItemDefs.get_recipe_entry_process_states(entry):
			if TestItemDefs.get_process_icon_texture(process_state) != null and process_state not in result:
				result.append(process_state)
	return result
