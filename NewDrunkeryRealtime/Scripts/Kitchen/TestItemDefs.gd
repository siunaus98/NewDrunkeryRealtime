class_name TestItemDefs
extends RefCounted

const MEAT_RED_ID: StringName = &"meat_red"
const MEAT_WHITE_ID: StringName = &"meat_white"
const SHRIMP_ID: StringName = &"sand_hare"
const CAMEL_MEAT_ID: StringName = &"camel_meat"
const VEG_LEAF_ID: StringName = &"crisp_sprout"
const VEG_ROOT_ID: StringName = &"sand_potato"
const RICE_ID: StringName = &"golden_wheat"
const CABBAGE_ID: StringName = &"dryfrost_cabbage"
const MUSHROOM_ID: StringName = &"dill"
const SUN_SEED_ID: StringName = &"sun_seed"
const EGG_ID: StringName = &"sunny_berry"
const TOFU_ID: StringName = &"stone_bloom"
const SANDWORM_CORE_ID: StringName = &"sandworm_core"
const SCORPION_CLAW_ID: StringName = &"scorpion_claw"
const VULTURE_FEATHERHEART_ID: StringName = &"vulture_featherheart"
const MONITOR_TENDERLOIN_ID: StringName = &"monitor_tenderloin"
const PLATE_ID: StringName = &"transport_plate"
const DIRTY_PLATE_ID: StringName = &"dirty_plate"
const SEASONING_BOX_ID: StringName = &"seasoning_box"
const TRASH_ID: StringName = &"trash"

# Compatibility name for older callers. First-region v7 uses 砂冠花, so the
# old 风铃椰 slot now resolves to the same canonical ingredient.
const COCONUT_ID: StringName = TOFU_ID

const DRINK_OASIS_WINE_ID: StringName = &"drink_oasis_wine"
const DRINK_GOLD_ALE_ID: StringName = &"drink_gold_ale"
const DRINK_QINGMEI_WINE_ID: StringName = &"drink_qingmei_wine"
const DRINK_QINGMEI_LIGHT_FERMENT_ID: StringName = &"drink_qingmei_light_ferment"
const DRINK_DOUBLE_FERMENT_ID: StringName = &"drink_double_ferment"
const DRINK_STONEFLOWER_HONEY_ID: StringName = &"drink_stoneflower_honey"
const DRINK_SUNWHEEL_INFUSION_ID: StringName = &"drink_sunwheel_infusion"
const DRINK_ROYAL_AGED_ID: StringName = &"drink_royal_aged"
const DRINK_MOON_DEW_ID: StringName = &"drink_moon_dew"
const DRINK_SCORCH_DOUBLE_FERMENT_ID: StringName = &"drink_scorch_double_ferment"

const DISH_CRISP_PLATE_ID: StringName = &"dish_crisp_plate"
const DISH_SAND_POTATO_PLATE_ID: StringName = &"dish_sand_potato_plate"
const DISH_GOLDEN_FLATBREAD_ID: StringName = &"dish_golden_flatbread"
const DISH_RED_ROLL_ID: StringName = &"dish_red_roll"
const DISH_WHITE_PLATE_ID: StringName = &"dish_white_plate"
const DISH_SAND_POTATO_CUTLET_ID: StringName = &"dish_sand_potato_cutlet"
const DISH_FOWL_SAND_ROLL_ID: StringName = &"dish_fowl_sand_roll"
const DISH_RED_DOUBLE_ROAST_ID: StringName = &"dish_red_double_roast"
const DISH_GOLDEN_FOWL_CAKE_ID: StringName = &"dish_golden_fowl_cake"
const DISH_QINGMEI_LEAF_SHARD_ID: StringName = &"dish_qingmei_leaf_shard"
const DISH_DRYFROST_ROLL_ID: StringName = &"dish_dryfrost_roll"
const DISH_SUNSEED_CRISP_ID: StringName = &"dish_sunseed_crisp"
const DISH_DILL_SAND_POTATO_CUP_ID: StringName = &"dish_dill_sand_potato_cup"
const DISH_STONEFLOWER_BAKED_CUP_ID: StringName = &"dish_stoneflower_baked_cup"
const DISH_HARE_SKEWER_ID: StringName = &"dish_hare_skewer"
const DISH_FOWL_POT_ID: StringName = &"dish_fowl_pot"
const DISH_OASIS_HOTPOT_ID: StringName = &"dish_oasis_hotpot"
const DISH_DILL_FOWL_POT_ID: StringName = &"dish_dill_fowl_pot"
const DISH_DRYFROST_MEAT_WRAP_ID: StringName = &"dish_dryfrost_meat_wrap"
const DISH_CAMEL_THIN_ROAST_ID: StringName = &"dish_camel_thin_roast"
const DISH_QINGMEI_SWEET_BOWL_ID: StringName = &"dish_qingmei_sweet_bowl"
const DISH_GOLDEN_BAKED_CAKE_ID: StringName = &"dish_golden_baked_cake"
const DISH_STONEFLOWER_FROZEN_ID: StringName = &"dish_stoneflower_frozen"
const DISH_ROYAL_ROAST_PLATE_ID: StringName = &"dish_royal_roast_plate"
const DISH_STONEFLOWER_COLD_PLATE_ID: StringName = &"dish_stoneflower_cold_plate"
const DISH_QINGMEI_SEARED_CUP_ID: StringName = &"dish_qingmei_seared_cup"
const DISH_SPICED_LAMB_ID: StringName = &"dish_spiced_lamb"
const DISH_CAMEL_DOUBLE_ROAST_ID: StringName = &"dish_camel_double_roast"
const DISH_ROYAL_HEAT_PLATE_ID: StringName = &"dish_royal_heat_plate"
const DISH_WINE_PLATTER_ID: StringName = &"dish_wine_platter"
const DISH_SUNRISE_BANQUET_ID: StringName = &"dish_sunrise_banquet"
const DISH_STONEFLOWER_HONEY_FEAST_ID: StringName = &"dish_stoneflower_honey_feast"
const DISH_SANDWORM_ROYAL_HEAT_PLATE_ID: StringName = &"dish_sandworm_royal_heat_plate"
const DISH_SCORPION_SUNPLATE_ID: StringName = &"dish_scorpion_sunplate"
const DISH_VULTURE_FEATHER_FEAST_ID: StringName = &"dish_vulture_feather_feast"
const DISH_MONITOR_ROYAL_BANQUET_ID: StringName = &"dish_monitor_royal_banquet"

const DISH_RED_ID: StringName = DISH_RED_ROLL_ID
const DISH_GREEN_ID: StringName = DISH_SAND_POTATO_CUTLET_ID
const DISH_YELLOW_ID: StringName = DISH_WHITE_PLATE_ID
const DISH_OASIS_HERB_SOUP_ID: StringName = DISH_DRYFROST_ROLL_ID
const DISH_CACTUS_COOL_PLATE_ID: StringName = DISH_CRISP_PLATE_ID
const DISH_COCONUT_STEAM_CUP_ID: StringName = DISH_STONEFLOWER_BAKED_CUP_ID
const DISH_SAND_POTATO_CAKE_ID: StringName = DISH_GOLDEN_FLATBREAD_ID
const DISH_DILL_HARE_SKEWER_ID: StringName = DISH_HARE_SKEWER_ID
const DISH_SUNSEED_FLATBREAD_ID: StringName = DISH_SUNSEED_CRISP_ID
const DISH_STONEFLOWER_STEW_ID: StringName = DISH_STONEFLOWER_BAKED_CUP_ID
const DISH_BERRY_SWEET_BOWL_ID: StringName = DISH_QINGMEI_SWEET_BOWL_ID
const DISH_OASIS_GRAIN_PILAF_ID: StringName = DISH_DILL_FOWL_POT_ID
const DISH_DESERT_HUNTER_PLATE_ID: StringName = DISH_ROYAL_ROAST_PLATE_ID
const DISH_SPICED_LAMB_BAKE_ID: StringName = DISH_SPICED_LAMB_ID
const DISH_CACTUS_MEAT_WRAP_ID: StringName = DISH_DRYFROST_MEAT_WRAP_ID
const DISH_SUN_OIL_CUTLET_ID: StringName = DISH_GOLDEN_FOWL_CAKE_ID
const DISH_COCONUT_BIRD_POT_ID: StringName = DISH_FOWL_POT_ID
const DISH_STONE_CROWN_SALAD_ID: StringName = DISH_STONEFLOWER_COLD_PLATE_ID
const DISH_DAWN_BREAD_FEAST_ID: StringName = DISH_SUNRISE_BANQUET_ID
const DISH_CARAVAN_SKEWER_SET_ID: StringName = DISH_CAMEL_DOUBLE_ROAST_ID
const DISH_OASIS_MOON_STEW_ID: StringName = DISH_OASIS_HOTPOT_ID
const DISH_PHARAOHS_HOT_PLATE_ID: StringName = DISH_ROYAL_HEAT_PLATE_ID
const DISH_SANDSTORM_BANQUET_ID: StringName = DISH_WINE_PLATTER_ID
const DISH_FIRST_REGION_TRIAL_ID: StringName = DISH_ROYAL_HEAT_PLATE_ID
const DRINK_DATE_ALE_ID: StringName = DRINK_GOLD_ALE_ID
const DRINK_SUNBERRY_WINE_ID: StringName = DRINK_QINGMEI_WINE_ID
const DRINK_DILL_ALE_ID: StringName = DRINK_SUNWHEEL_INFUSION_ID
const DISH_PHARAOH_WINE_PLATTER_ID: StringName = DISH_WINE_PLATTER_ID

const TEST_ITEM_ID: StringName = MEAT_RED_ID
const TEST_DISH_ID: StringName = DISH_RED_ID

const PROCESS_STATE_NONE: StringName = &""
const PROCESS_STATE_CUT: StringName = &"cut"
const PROCESS_STATE_ROAST_RARE: StringName = &"roast_rare"
const PROCESS_STATE_ROAST_MEDIUM: StringName = &"roast_medium"
const PROCESS_STATE_ROAST_WELL: StringName = &"roast_well"
const PROCESS_STATE_GRIND_COARSE: StringName = &"grind_coarse"
const PROCESS_STATE_GRIND_FINE: StringName = &"grind_fine"
const PROCESS_STATE_BURNT: StringName = &"burnt"
const PROCESS_STATE_STEAM: StringName = &"steam"
const PROCESS_STATE_STIR_FRY: StringName = &"stir_fry"
const PROCESS_STATE_DEEP_FRY: StringName = &"deep_fry"
const PROCESS_STATE_BOIL: StringName = &"boil"
const PROCESS_STATE_BAKE: StringName = &"bake"

const RAW_MODULATE: Color = Color.WHITE
# Cutting is communicated by the visible seams, not by tinting the whole
# ingredient. Keep the original art colors intact.
const CUT_MODULATE: Color = Color.WHITE
const ROAST_RARE_MODULATE: Color = Color(1.0, 0.76, 0.50, 1.0)
const ROAST_MEDIUM_MODULATE: Color = Color(1.0, 0.58, 0.30, 1.0)
const ROAST_WELL_MODULATE: Color = Color(0.88, 0.32, 0.18, 1.0)
const GRIND_COARSE_MODULATE: Color = Color(0.84, 0.76, 0.48, 1.0)
const GRIND_FINE_MODULATE: Color = Color(0.96, 0.88, 0.60, 1.0)
const BURNT_MODULATE: Color = Color(0.08, 0.07, 0.06, 1.0)

const INGREDIENT_IDS: Array[StringName] = [
	MEAT_RED_ID, MEAT_WHITE_ID, SHRIMP_ID, CAMEL_MEAT_ID,
	VEG_LEAF_ID, VEG_ROOT_ID, RICE_ID, CABBAGE_ID,
	MUSHROOM_ID, SUN_SEED_ID, EGG_ID, TOFU_ID
	,SANDWORM_CORE_ID, SCORPION_CLAW_ID, VULTURE_FEATHERHEART_ID, MONITOR_TENDERLOIN_ID
]

const DISH_IDS: Array[StringName] = [
	DRINK_OASIS_WINE_ID, DRINK_GOLD_ALE_ID, DRINK_QINGMEI_WINE_ID,
	DISH_CRISP_PLATE_ID, DISH_SAND_POTATO_PLATE_ID, DISH_GOLDEN_FLATBREAD_ID,
	DISH_RED_ROLL_ID, DISH_WHITE_PLATE_ID, DISH_SAND_POTATO_CUTLET_ID,
	DISH_FOWL_SAND_ROLL_ID, DISH_RED_DOUBLE_ROAST_ID, DISH_GOLDEN_FOWL_CAKE_ID,
	DRINK_QINGMEI_LIGHT_FERMENT_ID, DRINK_DOUBLE_FERMENT_ID,
	DRINK_STONEFLOWER_HONEY_ID, DRINK_SUNWHEEL_INFUSION_ID,
	DISH_DRYFROST_ROLL_ID, DISH_SUNSEED_CRISP_ID, DISH_DILL_SAND_POTATO_CUP_ID,
	DISH_QINGMEI_LEAF_SHARD_ID, DISH_STONEFLOWER_BAKED_CUP_ID, DISH_HARE_SKEWER_ID,
	DISH_FOWL_POT_ID, DISH_OASIS_HOTPOT_ID, DISH_DILL_FOWL_POT_ID,
	DISH_DRYFROST_MEAT_WRAP_ID, DISH_CAMEL_THIN_ROAST_ID, DISH_QINGMEI_SWEET_BOWL_ID,
	DISH_GOLDEN_BAKED_CAKE_ID, DISH_STONEFLOWER_FROZEN_ID, DRINK_ROYAL_AGED_ID,
	DRINK_MOON_DEW_ID, DRINK_SCORCH_DOUBLE_FERMENT_ID, DISH_ROYAL_ROAST_PLATE_ID,
	DISH_STONEFLOWER_COLD_PLATE_ID, DISH_QINGMEI_SEARED_CUP_ID, DISH_SPICED_LAMB_ID,
	DISH_CAMEL_DOUBLE_ROAST_ID, DISH_ROYAL_HEAT_PLATE_ID, DISH_WINE_PLATTER_ID,
	DISH_SUNRISE_BANQUET_ID, DISH_STONEFLOWER_HONEY_FEAST_ID,
	DISH_SANDWORM_ROYAL_HEAT_PLATE_ID, DISH_SCORPION_SUNPLATE_ID, DISH_VULTURE_FEATHER_FEAST_ID, DISH_MONITOR_ROYAL_BANQUET_ID
]

const ASSEMBLY_COMPONENT_IDS: Array[StringName] = [
	DRINK_OASIS_WINE_ID, DRINK_GOLD_ALE_ID, DRINK_QINGMEI_WINE_ID,
	DRINK_QINGMEI_LIGHT_FERMENT_ID, DRINK_DOUBLE_FERMENT_ID,
	DRINK_STONEFLOWER_HONEY_ID, DRINK_SUNWHEEL_INFUSION_ID,
	DRINK_ROYAL_AGED_ID, DRINK_MOON_DEW_ID, DRINK_SCORCH_DOUBLE_FERMENT_ID
]

const BARREL_DRINK_IDS: Array[StringName] = [DRINK_OASIS_WINE_ID, DRINK_GOLD_ALE_ID, DRINK_QINGMEI_WINE_ID]

const BARREL_INPUTS := {
	DRINK_OASIS_WINE_ID: VEG_LEAF_ID,
	DRINK_GOLD_ALE_ID: RICE_ID,
	DRINK_QINGMEI_WINE_ID: EGG_ID
}

const ITEM_DISPLAY_NAMES := {
	PLATE_ID: "运输盘", DIRTY_PLATE_ID: "脏盘子", SEASONING_BOX_ID: "小料盒",
	TRASH_ID: "垃圾",
	MEAT_RED_ID: "红鬃羊肉", MEAT_WHITE_ID: "沙原禽肉", SHRIMP_ID: "沙兔肉",
	CAMEL_MEAT_ID: "沙漠驼肉", VEG_LEAF_ID: "脆脆芽", VEG_ROOT_ID: "沙薯",
	RICE_ID: "碎金子", CABBAGE_ID: "旱霜白菜", MUSHROOM_ID: "莳萝",
	SUN_SEED_ID: "太阳籽", EGG_ID: "晴天梅", TOFU_ID: "砂冠花",
	SANDWORM_CORE_ID: "沙虫晶髓", SCORPION_CLAW_ID: "蝎甲肉", VULTURE_FEATHERHEART_ID: "风暴羽心",
	MONITOR_TENDERLOIN_ID: "巨蜥珍脊", DISH_MONITOR_ROYAL_BANQUET_ID: "沙宴珍脊盛筵",
	DRINK_OASIS_WINE_ID: "绿洲葡酒", DRINK_GOLD_ALE_ID: "砂金麦酒",
	DRINK_QINGMEI_WINE_ID: "晴梅淡酿", DRINK_QINGMEI_LIGHT_FERMENT_ID: "晴梅轻酿",
	DRINK_DOUBLE_FERMENT_ID: "双酿酒", DRINK_STONEFLOWER_HONEY_ID: "砂冠花蜜酒",
	DRINK_SUNWHEEL_INFUSION_ID: "日轮浸酿", DRINK_ROYAL_AGED_ID: "王庭陈酿",
	DRINK_MOON_DEW_ID: "月露特酿", DRINK_SCORCH_DOUBLE_FERMENT_ID: "烈阳双酿",
	DISH_CRISP_PLATE_ID: "脆芽冷盘", DISH_SAND_POTATO_PLATE_ID: "沙薯凉盘",
	DISH_GOLDEN_FLATBREAD_ID: "砂金小饼", DISH_RED_ROLL_ID: "红鬃芽卷",
	DISH_WHITE_PLATE_ID: "白肉菜盘", DISH_SAND_POTATO_CUTLET_ID: "沙薯肉排",
	DISH_FOWL_SAND_ROLL_ID: "禽肉沙薯卷", DISH_RED_DOUBLE_ROAST_ID: "红鬃双烤",
	DISH_GOLDEN_FOWL_CAKE_ID: "砂金禽饼", DISH_QINGMEI_LEAF_SHARD_ID: "梅香芽片",
	DISH_DRYFROST_ROLL_ID: "旱霜菜卷", DISH_SUNSEED_CRISP_ID: "太阳籽脆片",
	DISH_DILL_SAND_POTATO_CUP_ID: "莳萝沙薯盏", DISH_STONEFLOWER_BAKED_CUP_ID: "砂冠花烤盅",
	DISH_HARE_SKEWER_ID: "沙兔串", DISH_FOWL_POT_ID: "沙原禽锅",
	DISH_OASIS_HOTPOT_ID: "绿洲香锅", DISH_DILL_FOWL_POT_ID: "莳萝禽锅",
	DISH_DRYFROST_MEAT_WRAP_ID: "旱霜包肉", DISH_CAMEL_THIN_ROAST_ID: "驼肉薄烤",
	DISH_QINGMEI_SWEET_BOWL_ID: "晴梅甜羹", DISH_GOLDEN_BAKED_CAKE_ID: "砂金烤饼",
	DISH_STONEFLOWER_FROZEN_ID: "砂冠花酿冻", DISH_ROYAL_ROAST_PLATE_ID: "王庭烤拼",
	DISH_STONEFLOWER_COLD_PLATE_ID: "砂冠花冷拼", DISH_QINGMEI_SEARED_CUP_ID: "晴梅炙盏",
	DISH_SPICED_LAMB_ID: "香料烤羊", DISH_CAMEL_DOUBLE_ROAST_ID: "驼肉双烧",
	DISH_ROYAL_HEAT_PLATE_ID: "王陵热盘", DISH_WINE_PLATTER_ID: "酒香拼盘",
	DISH_SUNRISE_BANQUET_ID: "日出甜宴", DISH_STONEFLOWER_HONEY_FEAST_ID: "砂冠花蜜宴",
	DISH_SANDWORM_ROYAL_HEAT_PLATE_ID: "流沙晶髓王庭热盘", DISH_SCORPION_SUNPLATE_ID: "蝎甲烈阳拼盘", DISH_VULTURE_FEATHER_FEAST_ID: "逐风羽心宴"
}

const ITEM_DESCRIPTIONS := {
	TRASH_ID: "组合失败后留下的废料，不能用于料理或上菜。",
	MEAT_RED_ID: "沙漠牧民常备的基础红肉，后期仍会回流到高级菜。",
	MEAT_WHITE_ID: "轻肉类，连接中级火候菜。",
	SHRIMP_ID: "紧实沙兔肉，适合串类和双份烤制。",
	CAMEL_MEAT_ID: "高级肉类，高价值但更考验火候排程。",
	VEG_LEAF_ID: "仙人掌新芽，基础小菜、卷类与绿洲葡酒核心。",
	VEG_ROOT_ID: "沙地块茎，负责主食感、冷盘与甜品底。",
	RICE_ID: "沙漠小麦，连接烤饼、砂金麦酒和高级甜品。",
	CABBAGE_ID: "耐旱白菜，负责包裹、菜卷和主菜结构。",
	MUSHROOM_ID: "草本香料，负责研磨与酒水尾韵。",
	SUN_SEED_ID: "中级采集物，是烤制小菜、香锅与高级酒水的火候载体。",
	EGG_ID: "高级甜味核心，进入甜品、晴梅淡酿和高阶酒水。",
	TOFU_ID: "沙漠花材，承担花蜜、研磨与甜品线。",
	SANDWORM_CORE_ID: "沙虫体内凝结的晶髓，带有流沙的余力。",
	SCORPION_CLAW_ID: "蝎甲与毒刺之间的坚韧肉质，适合高温处理。",
	VULTURE_FEATHERHEART_ID: "秃鹫胸腔中的风暴羽心，入口轻盈但余韵强烈。"
	,MONITOR_TENDERLOIN_ID: "沙宴巨蜥背脊的珍肉，需要亲手从战斗区搬回。"
}

const ITEM_TEXTURES := {
	PLATE_ID: preload("res://ArtResource/Kitchen/plate.svg"),
	DIRTY_PLATE_ID: preload("res://ArtResource/Kitchen/dirty_plate.svg"),
	SEASONING_BOX_ID: preload("res://ArtResource/Kitchen/seasoning_box.svg"),
	MEAT_RED_ID: preload("res://ArtResource/Generated/Ingredient/meat_red.svg"),
	MEAT_WHITE_ID: preload("res://ArtResource/Generated/Ingredient/meat_white.svg"),
	SHRIMP_ID: preload("res://ArtResource/Generated/Ingredient/sand_hare.svg"),
	CAMEL_MEAT_ID: preload("res://ArtResource/Generated/Ingredient/camel_meat.svg"),
	SANDWORM_CORE_ID: preload("res://ArtResource/Generated/Ingredient/sandworm_core.svg"),
	SCORPION_CLAW_ID: preload("res://ArtResource/Generated/Ingredient/scorpion_claw.svg"),
	VULTURE_FEATHERHEART_ID: preload("res://ArtResource/Generated/Ingredient/vulture_featherheart.svg"),
	MONITOR_TENDERLOIN_ID: preload("res://ArtResource/Generated/Ingredient/monitor_tenderloin.svg"),
	DISH_MONITOR_ROYAL_BANQUET_ID: preload("res://ArtResource/Generated/Dish/dish_monitor_royal_banquet.svg"),
	VEG_LEAF_ID: preload("res://ArtResource/Generated/Ingredient/crisp_sprout.svg"),
	VEG_ROOT_ID: preload("res://ArtResource/Generated/Ingredient/sand_potato.svg"),
	RICE_ID: preload("res://ArtResource/Generated/Ingredient/golden_wheat.svg"),
	CABBAGE_ID: preload("res://ArtResource/Generated/Ingredient/dryfrost_cabbage.svg"),
	MUSHROOM_ID: preload("res://ArtResource/Generated/Ingredient/dill.svg"),
	SUN_SEED_ID: preload("res://ArtResource/Generated/Ingredient/sun_seed.svg"),
	EGG_ID: preload("res://ArtResource/Generated/Ingredient/sunny_berry.svg"),
	TOFU_ID: preload("res://ArtResource/Generated/Ingredient/stone_bloom.svg"),
	TRASH_ID: preload("res://ArtResource/Generated/Dish/failed_food.svg"),
	DRINK_OASIS_WINE_ID: preload("res://ArtResource/Generated/Dish/drink_oasis_wine.svg"),
	DRINK_GOLD_ALE_ID: preload("res://ArtResource/Generated/Dish/drink_gold_ale.svg"),
	DRINK_QINGMEI_WINE_ID: preload("res://ArtResource/Generated/Dish/drink_qingmei_wine.svg"),
	DRINK_QINGMEI_LIGHT_FERMENT_ID: preload("res://ArtResource/Generated/Dish/drink_qingmei_light_ferment.svg"),
	DRINK_DOUBLE_FERMENT_ID: preload("res://ArtResource/Generated/Dish/drink_double_ferment.svg"),
	DRINK_STONEFLOWER_HONEY_ID: preload("res://ArtResource/Generated/Dish/drink_stoneflower_honey.svg"),
	DRINK_SUNWHEEL_INFUSION_ID: preload("res://ArtResource/Generated/Dish/drink_sunwheel_infusion.svg"),
	DRINK_ROYAL_AGED_ID: preload("res://ArtResource/Generated/Dish/drink_royal_aged.svg"),
	DRINK_MOON_DEW_ID: preload("res://ArtResource/Generated/Dish/drink_moon_dew.svg"),
	DRINK_SCORCH_DOUBLE_FERMENT_ID: preload("res://ArtResource/Generated/Dish/drink_scorch_double_ferment.svg"),
	DISH_CRISP_PLATE_ID: preload("res://ArtResource/Generated/Dish/dish_crisp_plate.svg"),
	DISH_SAND_POTATO_PLATE_ID: preload("res://ArtResource/Generated/Dish/dish_sand_potato_plate.svg"),
	DISH_GOLDEN_FLATBREAD_ID: preload("res://ArtResource/Generated/Dish/dish_golden_flatbread.svg"),
	DISH_RED_ROLL_ID: preload("res://ArtResource/Generated/Dish/dish_red_roll.svg"),
	DISH_WHITE_PLATE_ID: preload("res://ArtResource/Generated/Dish/dish_white_plate.svg"),
	DISH_SAND_POTATO_CUTLET_ID: preload("res://ArtResource/Generated/Dish/dish_sand_potato_cutlet.svg"),
	DISH_FOWL_SAND_ROLL_ID: preload("res://ArtResource/Generated/Dish/dish_fowl_sand_roll.svg"),
	DISH_RED_DOUBLE_ROAST_ID: preload("res://ArtResource/Generated/Dish/dish_red_double_roast.svg"),
	DISH_GOLDEN_FOWL_CAKE_ID: preload("res://ArtResource/Generated/Dish/dish_golden_fowl_cake.svg"),
	DISH_QINGMEI_LEAF_SHARD_ID: preload("res://ArtResource/Generated/Dish/dish_qingmei_leaf_shard.svg"),
	DISH_DRYFROST_ROLL_ID: preload("res://ArtResource/Generated/Dish/dish_dryfrost_roll.svg"),
	DISH_SUNSEED_CRISP_ID: preload("res://ArtResource/Generated/Dish/dish_sunseed_crisp.svg"),
	DISH_DILL_SAND_POTATO_CUP_ID: preload("res://ArtResource/Generated/Dish/dish_dill_sand_potato_cup.svg"),
	DISH_STONEFLOWER_BAKED_CUP_ID: preload("res://ArtResource/Generated/Dish/dish_stoneflower_baked_cup.svg"),
	DISH_HARE_SKEWER_ID: preload("res://ArtResource/Generated/Dish/dish_hare_skewer.svg"),
	DISH_FOWL_POT_ID: preload("res://ArtResource/Generated/Dish/dish_fowl_pot.svg"),
	DISH_OASIS_HOTPOT_ID: preload("res://ArtResource/Generated/Dish/dish_oasis_hotpot.svg"),
	DISH_DILL_FOWL_POT_ID: preload("res://ArtResource/Generated/Dish/dish_dill_fowl_pot.svg"),
	DISH_DRYFROST_MEAT_WRAP_ID: preload("res://ArtResource/Generated/Dish/dish_dryfrost_meat_wrap.svg"),
	DISH_CAMEL_THIN_ROAST_ID: preload("res://ArtResource/Generated/Dish/dish_camel_thin_roast.svg"),
	DISH_QINGMEI_SWEET_BOWL_ID: preload("res://ArtResource/Generated/Dish/dish_qingmei_sweet_bowl.svg"),
	DISH_GOLDEN_BAKED_CAKE_ID: preload("res://ArtResource/Generated/Dish/dish_golden_baked_cake.svg"),
	DISH_STONEFLOWER_FROZEN_ID: preload("res://ArtResource/Generated/Dish/dish_stoneflower_frozen.svg"),
	DISH_ROYAL_ROAST_PLATE_ID: preload("res://ArtResource/Generated/Dish/dish_royal_roast_plate.svg"),
	DISH_STONEFLOWER_COLD_PLATE_ID: preload("res://ArtResource/Generated/Dish/dish_stoneflower_cold_plate.svg"),
	DISH_QINGMEI_SEARED_CUP_ID: preload("res://ArtResource/Generated/Dish/dish_qingmei_seared_cup.svg"),
	DISH_SPICED_LAMB_ID: preload("res://ArtResource/Generated/Dish/dish_spiced_lamb.svg"),
	DISH_CAMEL_DOUBLE_ROAST_ID: preload("res://ArtResource/Generated/Dish/dish_camel_double_roast.svg"),
	DISH_ROYAL_HEAT_PLATE_ID: preload("res://ArtResource/Generated/Dish/dish_royal_heat_plate.svg"),
	DISH_WINE_PLATTER_ID: preload("res://ArtResource/Generated/Dish/dish_wine_platter.svg"),
	DISH_SUNRISE_BANQUET_ID: preload("res://ArtResource/Generated/Dish/dish_sunrise_banquet.svg"),
	DISH_STONEFLOWER_HONEY_FEAST_ID: preload("res://ArtResource/Generated/Dish/dish_stoneflower_honey_feast.svg"),
	DISH_SANDWORM_ROYAL_HEAT_PLATE_ID: preload("res://ArtResource/Generated/Dish/dish_sandworm_royal_heat_plate.svg"),
	DISH_SCORPION_SUNPLATE_ID: preload("res://ArtResource/Generated/Dish/dish_scorpion_sunplate.svg"),
	DISH_VULTURE_FEATHER_FEAST_ID: preload("res://ArtResource/Generated/Dish/dish_vulture_feather_feast.svg")
}

const PLATED_DISH_TEXTURES := {
	DISH_MONITOR_ROYAL_BANQUET_ID: preload("res://ArtResource/Generated/DishPlated/dish_monitor_royal_banquet.svg"),
	&"dish_camel_double_roast": preload("res://ArtResource/Generated/DishPlated/dish_camel_double_roast.svg"),
	&"dish_camel_thin_roast": preload("res://ArtResource/Generated/DishPlated/dish_camel_thin_roast.svg"),
	&"dish_crisp_plate": preload("res://ArtResource/Generated/DishPlated/dish_crisp_plate.svg"),
	&"dish_dill_fowl_pot": preload("res://ArtResource/Generated/DishPlated/dish_dill_fowl_pot.svg"),
	&"dish_dill_sand_potato_cup": preload("res://ArtResource/Generated/DishPlated/dish_dill_sand_potato_cup.svg"),
	&"dish_dryfrost_meat_wrap": preload("res://ArtResource/Generated/DishPlated/dish_dryfrost_meat_wrap.svg"),
	&"dish_dryfrost_roll": preload("res://ArtResource/Generated/DishPlated/dish_dryfrost_roll.svg"),
	&"dish_fowl_pot": preload("res://ArtResource/Generated/DishPlated/dish_fowl_pot.svg"),
	&"dish_fowl_sand_roll": preload("res://ArtResource/Generated/DishPlated/dish_fowl_sand_roll.svg"),
	&"dish_golden_baked_cake": preload("res://ArtResource/Generated/DishPlated/dish_golden_baked_cake.svg"),
	&"dish_golden_flatbread": preload("res://ArtResource/Generated/DishPlated/dish_golden_flatbread.svg"),
	&"dish_golden_fowl_cake": preload("res://ArtResource/Generated/DishPlated/dish_golden_fowl_cake.svg"),
	&"dish_hare_skewer": preload("res://ArtResource/Generated/DishPlated/dish_hare_skewer.svg"),
	&"dish_oasis_hotpot": preload("res://ArtResource/Generated/DishPlated/dish_oasis_hotpot.svg"),
	&"dish_qingmei_leaf_shard": preload("res://ArtResource/Generated/DishPlated/dish_qingmei_leaf_shard.svg"),
	&"dish_qingmei_seared_cup": preload("res://ArtResource/Generated/DishPlated/dish_qingmei_seared_cup.svg"),
	&"dish_qingmei_sweet_bowl": preload("res://ArtResource/Generated/DishPlated/dish_qingmei_sweet_bowl.svg"),
	&"dish_red_double_roast": preload("res://ArtResource/Generated/DishPlated/dish_red_double_roast.svg"),
	&"dish_red_roll": preload("res://ArtResource/Generated/DishPlated/dish_red_roll.svg"),
	&"dish_royal_heat_plate": preload("res://ArtResource/Generated/DishPlated/dish_royal_heat_plate.svg"),
	&"dish_royal_roast_plate": preload("res://ArtResource/Generated/DishPlated/dish_royal_roast_plate.svg"),
	&"dish_sand_potato_cutlet": preload("res://ArtResource/Generated/DishPlated/dish_sand_potato_cutlet.svg"),
	&"dish_sand_potato_plate": preload("res://ArtResource/Generated/DishPlated/dish_sand_potato_plate.svg"),
	&"dish_sandworm_royal_heat_plate": preload("res://ArtResource/Generated/DishPlated/dish_sandworm_royal_heat_plate.svg"),
	&"dish_scorpion_sunplate": preload("res://ArtResource/Generated/DishPlated/dish_scorpion_sunplate.svg"),
	&"dish_spiced_lamb": preload("res://ArtResource/Generated/DishPlated/dish_spiced_lamb.svg"),
	&"dish_stoneflower_baked_cup": preload("res://ArtResource/Generated/DishPlated/dish_stoneflower_baked_cup.svg"),
	&"dish_stoneflower_cold_plate": preload("res://ArtResource/Generated/DishPlated/dish_stoneflower_cold_plate.svg"),
	&"dish_stoneflower_frozen": preload("res://ArtResource/Generated/DishPlated/dish_stoneflower_frozen.svg"),
	&"dish_stoneflower_honey_feast": preload("res://ArtResource/Generated/DishPlated/dish_stoneflower_honey_feast.svg"),
	&"dish_sunrise_banquet": preload("res://ArtResource/Generated/DishPlated/dish_sunrise_banquet.svg"),
	&"dish_sunseed_crisp": preload("res://ArtResource/Generated/DishPlated/dish_sunseed_crisp.svg"),
	&"dish_vulture_feather_feast": preload("res://ArtResource/Generated/DishPlated/dish_vulture_feather_feast.svg"),
	&"dish_white_plate": preload("res://ArtResource/Generated/DishPlated/dish_white_plate.svg"),
	&"dish_wine_platter": preload("res://ArtResource/Generated/DishPlated/dish_wine_platter.svg"),
	&"trash": preload("res://ArtResource/Generated/DishPlated/failed_food.svg")
}

const PREPARED_DISH_TEXTURES := {
	&"dish_dill_fowl_pot": preload("res://ArtResource/Generated/DishPrepared/dish_dill_fowl_pot.svg"),
	&"dish_dill_sand_potato_cup": preload("res://ArtResource/Generated/DishPrepared/dish_dill_sand_potato_cup.svg"),
	&"dish_fowl_pot": preload("res://ArtResource/Generated/DishPrepared/dish_fowl_pot.svg"),
	&"dish_oasis_hotpot": preload("res://ArtResource/Generated/DishPrepared/dish_oasis_hotpot.svg"),
	&"dish_qingmei_seared_cup": preload("res://ArtResource/Generated/DishPrepared/dish_qingmei_seared_cup.svg"),
	&"dish_qingmei_sweet_bowl": preload("res://ArtResource/Generated/DishPrepared/dish_qingmei_sweet_bowl.svg"),
	&"dish_stoneflower_baked_cup": preload("res://ArtResource/Generated/DishPrepared/dish_stoneflower_baked_cup.svg")
}

const PROCESS_ICON_TEXTURES := {
	PROCESS_STATE_CUT: preload("res://ArtResource/Generated/Process/cut.svg"),
	PROCESS_STATE_ROAST_RARE: preload("res://ArtResource/Generated/Process/roast_rare.svg"),
	PROCESS_STATE_ROAST_MEDIUM: preload("res://ArtResource/Generated/Process/roast_medium.svg"),
	PROCESS_STATE_ROAST_WELL: preload("res://ArtResource/Generated/Process/roast_well.svg"),
	PROCESS_STATE_GRIND_COARSE: preload("res://ArtResource/Generated/Process/grind_coarse.svg"),
	PROCESS_STATE_GRIND_FINE: preload("res://ArtResource/Generated/Process/grind_fine.svg")
}

const ITEM_TYPES := {
	MONITOR_TENDERLOIN_ID: &"ingredient",
	MEAT_RED_ID: &"ingredient", MEAT_WHITE_ID: &"ingredient", SHRIMP_ID: &"ingredient",
	CAMEL_MEAT_ID: &"ingredient", SANDWORM_CORE_ID: &"ingredient", SCORPION_CLAW_ID: &"ingredient", VULTURE_FEATHERHEART_ID: &"ingredient", VEG_LEAF_ID: &"ingredient", VEG_ROOT_ID: &"ingredient",
	RICE_ID: &"ingredient", CABBAGE_ID: &"ingredient", MUSHROOM_ID: &"ingredient",
	SUN_SEED_ID: &"ingredient", EGG_ID: &"ingredient", TOFU_ID: &"ingredient"
}

const ITEM_CATEGORIES := {
	DRINK_OASIS_WINE_ID: &"drink", DRINK_GOLD_ALE_ID: &"drink", DRINK_QINGMEI_WINE_ID: &"drink",
	DRINK_QINGMEI_LIGHT_FERMENT_ID: &"drink", DRINK_DOUBLE_FERMENT_ID: &"drink",
	DRINK_STONEFLOWER_HONEY_ID: &"drink", DRINK_SUNWHEEL_INFUSION_ID: &"drink",
	DRINK_ROYAL_AGED_ID: &"drink", DRINK_MOON_DEW_ID: &"drink", DRINK_SCORCH_DOUBLE_FERMENT_ID: &"drink",
	DISH_CRISP_PLATE_ID: &"small_plate", DISH_SAND_POTATO_PLATE_ID: &"small_plate",
	DISH_GOLDEN_FLATBREAD_ID: &"small_plate", DISH_QINGMEI_LEAF_SHARD_ID: &"small_plate",
	DISH_DRYFROST_ROLL_ID: &"small_plate", DISH_SUNSEED_CRISP_ID: &"small_plate",
	DISH_DILL_SAND_POTATO_CUP_ID: &"small_plate", DISH_STONEFLOWER_BAKED_CUP_ID: &"small_plate",
	DISH_ROYAL_ROAST_PLATE_ID: &"small_plate", DISH_STONEFLOWER_COLD_PLATE_ID: &"small_plate",
	DISH_QINGMEI_SEARED_CUP_ID: &"small_plate", DISH_RED_ROLL_ID: &"main_dish",
	DISH_WHITE_PLATE_ID: &"main_dish", DISH_SAND_POTATO_CUTLET_ID: &"main_dish",
	DISH_FOWL_SAND_ROLL_ID: &"main_dish", DISH_RED_DOUBLE_ROAST_ID: &"main_dish",
	DISH_GOLDEN_FOWL_CAKE_ID: &"main_dish", DISH_HARE_SKEWER_ID: &"main_dish",
	DISH_FOWL_POT_ID: &"main_dish", DISH_OASIS_HOTPOT_ID: &"main_dish",
	DISH_DILL_FOWL_POT_ID: &"main_dish", DISH_DRYFROST_MEAT_WRAP_ID: &"main_dish",
	DISH_CAMEL_THIN_ROAST_ID: &"main_dish", DISH_SPICED_LAMB_ID: &"main_dish",
	DISH_CAMEL_DOUBLE_ROAST_ID: &"main_dish", DISH_ROYAL_HEAT_PLATE_ID: &"main_dish",
	DISH_WINE_PLATTER_ID: &"main_dish", DISH_QINGMEI_SWEET_BOWL_ID: &"dessert",
	DISH_GOLDEN_BAKED_CAKE_ID: &"dessert", DISH_STONEFLOWER_FROZEN_ID: &"dessert",
	DISH_SUNRISE_BANQUET_ID: &"dessert", DISH_STONEFLOWER_HONEY_FEAST_ID: &"dessert",
	DISH_SANDWORM_ROYAL_HEAT_PLATE_ID: &"main_dish", DISH_SCORPION_SUNPLATE_ID: &"main_dish", DISH_VULTURE_FEATHER_FEAST_ID: &"main_dish", DISH_MONITOR_ROYAL_BANQUET_ID: &"main_dish"
}

const STAGE_GROUPS := {
	&"cut_work": {"display_name": "切台", "desc": "持续按键完成切配，速度快且没有过熟风险。"},
	&"heat_work": {"display_name": "火候台", "desc": "自动经过微生、半熟、全熟，之后会糊掉。"},
	&"grind_work": {"display_name": "研磨台", "desc": "持续按键经过粗磨和细磨两个完成度。"},
	&"assembly": {"display_name": "组合台", "desc": "把多个半成品按配方组装成料理。"}
}

const PROCESS_DIFFICULTY := {
	PROCESS_STATE_CUT: 1, PROCESS_STATE_ROAST_RARE: 2, PROCESS_STATE_ROAST_MEDIUM: 3,
	PROCESS_STATE_ROAST_WELL: 4, PROCESS_STATE_GRIND_COARSE: 2, PROCESS_STATE_GRIND_FINE: 3
}

static var _recipe_cache: Array[Dictionary] = []

static func _ingredient(item_id: StringName, process_state: StringName, count: int = 1, accepted_states: Array = []) -> Dictionary:
	var result := {"item_id": item_id, "process_state": process_state, "count": count}
	if not accepted_states.is_empty():
		result["accepted_process_states"] = accepted_states.duplicate()
	return result

static func _recipe(output_item_id: StringName, ingredients: Array, difficulty: int) -> Dictionary:
	return {"ingredients": ingredients, "output_item_id": output_item_id, "difficulty": difficulty}

static func get_recipes() -> Array[Dictionary]:
	if not _recipe_cache.is_empty():
		return _recipe_cache
	var roast_all: Array = [PROCESS_STATE_ROAST_RARE, PROCESS_STATE_ROAST_MEDIUM, PROCESS_STATE_ROAST_WELL]
	var roast_rare_medium: Array = [PROCESS_STATE_ROAST_RARE, PROCESS_STATE_ROAST_MEDIUM]
	var roast_medium_well: Array = [PROCESS_STATE_ROAST_MEDIUM, PROCESS_STATE_ROAST_WELL]
	var grind_both: Array = [PROCESS_STATE_GRIND_COARSE, PROCESS_STATE_GRIND_FINE]
	_recipe_cache = [
		_recipe(DISH_CRISP_PLATE_ID, [_ingredient(VEG_LEAF_ID, PROCESS_STATE_CUT, 2)], 1),
		_recipe(DISH_SAND_POTATO_PLATE_ID, [_ingredient(VEG_ROOT_ID, PROCESS_STATE_CUT, 2)], 1),
		_recipe(DISH_GOLDEN_FLATBREAD_ID, [_ingredient(RICE_ID, PROCESS_STATE_ROAST_WELL, 2)], 1),
		_recipe(DISH_RED_ROLL_ID, [_ingredient(MEAT_RED_ID, PROCESS_STATE_CUT), _ingredient(VEG_LEAF_ID, PROCESS_STATE_CUT)], 1),
		_recipe(DISH_WHITE_PLATE_ID, [_ingredient(MEAT_WHITE_ID, PROCESS_STATE_CUT), _ingredient(VEG_LEAF_ID, PROCESS_STATE_CUT)], 1),
		_recipe(DISH_SAND_POTATO_CUTLET_ID, [_ingredient(MEAT_RED_ID, PROCESS_STATE_CUT), _ingredient(VEG_ROOT_ID, PROCESS_STATE_CUT)], 1),
		_recipe(DISH_FOWL_SAND_ROLL_ID, [_ingredient(MEAT_WHITE_ID, PROCESS_STATE_CUT), _ingredient(VEG_ROOT_ID, PROCESS_STATE_CUT)], 1),
		_recipe(DISH_RED_DOUBLE_ROAST_ID, [_ingredient(MEAT_RED_ID, PROCESS_STATE_ROAST_MEDIUM, 2)], 1),
		_recipe(DISH_GOLDEN_FOWL_CAKE_ID, [_ingredient(MEAT_WHITE_ID, PROCESS_STATE_ROAST_WELL), _ingredient(RICE_ID, PROCESS_STATE_ROAST_WELL)], 1),
		_recipe(DRINK_QINGMEI_LIGHT_FERMENT_ID, [_ingredient(DRINK_QINGMEI_WINE_ID, PROCESS_STATE_NONE), _ingredient(EGG_ID, PROCESS_STATE_ROAST_WELL, 1, roast_all), _ingredient(EGG_ID, PROCESS_STATE_GRIND_FINE, 1, grind_both)], 2),
		_recipe(DRINK_DOUBLE_FERMENT_ID, [_ingredient(DRINK_OASIS_WINE_ID, PROCESS_STATE_NONE), _ingredient(DRINK_GOLD_ALE_ID, PROCESS_STATE_NONE), _ingredient(SUN_SEED_ID, PROCESS_STATE_ROAST_RARE, 1, roast_rare_medium)], 2),
		_recipe(DRINK_STONEFLOWER_HONEY_ID, [_ingredient(DRINK_GOLD_ALE_ID, PROCESS_STATE_NONE), _ingredient(DRINK_QINGMEI_WINE_ID, PROCESS_STATE_NONE), _ingredient(TOFU_ID, PROCESS_STATE_GRIND_COARSE, 1, grind_both)], 2),
		_recipe(DRINK_SUNWHEEL_INFUSION_ID, [_ingredient(DRINK_OASIS_WINE_ID, PROCESS_STATE_NONE), _ingredient(SUN_SEED_ID, PROCESS_STATE_ROAST_WELL, 1, roast_all), _ingredient(MUSHROOM_ID, PROCESS_STATE_GRIND_COARSE, 1, grind_both)], 2),
		_recipe(DISH_DRYFROST_ROLL_ID, [_ingredient(CABBAGE_ID, PROCESS_STATE_CUT, 2), _ingredient(VEG_LEAF_ID, PROCESS_STATE_CUT, 2)], 2),
		_recipe(DISH_SUNSEED_CRISP_ID, [_ingredient(SUN_SEED_ID, PROCESS_STATE_ROAST_WELL, 2), _ingredient(VEG_LEAF_ID, PROCESS_STATE_CUT, 2)], 2),
		_recipe(DISH_DILL_SAND_POTATO_CUP_ID, [_ingredient(VEG_ROOT_ID, PROCESS_STATE_CUT, 3), _ingredient(MUSHROOM_ID, PROCESS_STATE_GRIND_FINE)], 2),
		_recipe(DISH_QINGMEI_LEAF_SHARD_ID, [_ingredient(VEG_LEAF_ID, PROCESS_STATE_CUT), _ingredient(EGG_ID, PROCESS_STATE_ROAST_MEDIUM, 1, roast_all), _ingredient(EGG_ID, PROCESS_STATE_GRIND_COARSE, 1, grind_both)], 2),
		_recipe(DISH_STONEFLOWER_BAKED_CUP_ID, [_ingredient(TOFU_ID, PROCESS_STATE_CUT, 2), _ingredient(CABBAGE_ID, PROCESS_STATE_CUT), _ingredient(EGG_ID, PROCESS_STATE_ROAST_WELL)], 2),
		_recipe(DISH_HARE_SKEWER_ID, [_ingredient(SHRIMP_ID, PROCESS_STATE_ROAST_RARE, 2, roast_rare_medium), _ingredient(VEG_LEAF_ID, PROCESS_STATE_CUT)], 2),
		_recipe(DISH_FOWL_POT_ID, [_ingredient(MEAT_WHITE_ID, PROCESS_STATE_ROAST_WELL, 2), _ingredient(CABBAGE_ID, PROCESS_STATE_CUT, 2)], 2),
		_recipe(DISH_OASIS_HOTPOT_ID, [_ingredient(MEAT_RED_ID, PROCESS_STATE_ROAST_RARE, 1, roast_rare_medium), _ingredient(SUN_SEED_ID, PROCESS_STATE_ROAST_RARE, 1, roast_rare_medium), _ingredient(CABBAGE_ID, PROCESS_STATE_CUT, 1)], 2),
		_recipe(DISH_DILL_FOWL_POT_ID, [_ingredient(MEAT_WHITE_ID, PROCESS_STATE_ROAST_MEDIUM, 1, roast_medium_well), _ingredient(VEG_ROOT_ID, PROCESS_STATE_ROAST_MEDIUM, 1, roast_medium_well), _ingredient(DRINK_OASIS_WINE_ID, PROCESS_STATE_NONE)], 2),
		_recipe(DISH_DRYFROST_MEAT_WRAP_ID, [_ingredient(SHRIMP_ID, PROCESS_STATE_ROAST_WELL, 2), _ingredient(CABBAGE_ID, PROCESS_STATE_CUT, 2)], 2),
		_recipe(DISH_CAMEL_THIN_ROAST_ID, [_ingredient(CAMEL_MEAT_ID, PROCESS_STATE_ROAST_MEDIUM, 1, roast_medium_well), _ingredient(SHRIMP_ID, PROCESS_STATE_ROAST_MEDIUM, 1, roast_medium_well), _ingredient(VEG_ROOT_ID, PROCESS_STATE_CUT)], 2),
		_recipe(DISH_QINGMEI_SWEET_BOWL_ID, [_ingredient(EGG_ID, PROCESS_STATE_ROAST_WELL, 2), _ingredient(EGG_ID, PROCESS_STATE_GRIND_FINE), _ingredient(TOFU_ID, PROCESS_STATE_GRIND_FINE)], 2),
		_recipe(DISH_GOLDEN_BAKED_CAKE_ID, [_ingredient(RICE_ID, PROCESS_STATE_ROAST_WELL, 2), _ingredient(EGG_ID, PROCESS_STATE_GRIND_FINE, 2)], 2),
		_recipe(DISH_STONEFLOWER_FROZEN_ID, [_ingredient(TOFU_ID, PROCESS_STATE_ROAST_RARE, 1, roast_rare_medium), _ingredient(TOFU_ID, PROCESS_STATE_GRIND_FINE, 1, grind_both), _ingredient(DRINK_QINGMEI_WINE_ID, PROCESS_STATE_NONE)], 2),
		_recipe(DRINK_ROYAL_AGED_ID, [_ingredient(DRINK_OASIS_WINE_ID, PROCESS_STATE_NONE), _ingredient(DRINK_QINGMEI_WINE_ID, PROCESS_STATE_NONE), _ingredient(EGG_ID, PROCESS_STATE_ROAST_RARE, 1, roast_all), _ingredient(TOFU_ID, PROCESS_STATE_ROAST_RARE, 1, roast_all)], 3),
		_recipe(DRINK_MOON_DEW_ID, [_ingredient(DRINK_QINGMEI_WINE_ID, PROCESS_STATE_NONE), _ingredient(TOFU_ID, PROCESS_STATE_ROAST_MEDIUM, 1, roast_medium_well), _ingredient(TOFU_ID, PROCESS_STATE_GRIND_COARSE, 1, grind_both), _ingredient(DRINK_OASIS_WINE_ID, PROCESS_STATE_NONE)], 3),
		_recipe(DRINK_SCORCH_DOUBLE_FERMENT_ID, [_ingredient(DRINK_GOLD_ALE_ID, PROCESS_STATE_NONE), _ingredient(SUN_SEED_ID, PROCESS_STATE_GRIND_FINE, 1, grind_both), _ingredient(DRINK_OASIS_WINE_ID, PROCESS_STATE_NONE), _ingredient(SUN_SEED_ID, PROCESS_STATE_ROAST_WELL, 1, roast_all)], 3),
		_recipe(DISH_ROYAL_ROAST_PLATE_ID, [_ingredient(VEG_ROOT_ID, PROCESS_STATE_ROAST_WELL, 2), _ingredient(SUN_SEED_ID, PROCESS_STATE_ROAST_WELL, 2), _ingredient(MUSHROOM_ID, PROCESS_STATE_GRIND_FINE)], 3),
		_recipe(DISH_STONEFLOWER_COLD_PLATE_ID, [_ingredient(TOFU_ID, PROCESS_STATE_CUT, 2), _ingredient(CABBAGE_ID, PROCESS_STATE_CUT), _ingredient(VEG_LEAF_ID, PROCESS_STATE_CUT), _ingredient(MUSHROOM_ID, PROCESS_STATE_GRIND_FINE)], 3),
		_recipe(DISH_QINGMEI_SEARED_CUP_ID, [_ingredient(EGG_ID, PROCESS_STATE_ROAST_RARE, 1, roast_all), _ingredient(SUN_SEED_ID, PROCESS_STATE_ROAST_RARE, 1, roast_all), _ingredient(DRINK_QINGMEI_WINE_ID, PROCESS_STATE_NONE), _ingredient(TOFU_ID, PROCESS_STATE_GRIND_FINE, 1, grind_both)], 3),
		_recipe(DISH_SPICED_LAMB_ID, [_ingredient(MEAT_RED_ID, PROCESS_STATE_ROAST_WELL, 3), _ingredient(VEG_ROOT_ID, PROCESS_STATE_CUT), _ingredient(MUSHROOM_ID, PROCESS_STATE_GRIND_FINE)], 3),
		_recipe(DISH_CAMEL_DOUBLE_ROAST_ID, [_ingredient(CAMEL_MEAT_ID, PROCESS_STATE_ROAST_RARE, 1, roast_all), _ingredient(MEAT_RED_ID, PROCESS_STATE_ROAST_RARE, 1, roast_all), _ingredient(DRINK_GOLD_ALE_ID, PROCESS_STATE_NONE), _ingredient(CABBAGE_ID, PROCESS_STATE_CUT)], 3),
		_recipe(DISH_ROYAL_HEAT_PLATE_ID, [_ingredient(CAMEL_MEAT_ID, PROCESS_STATE_ROAST_RARE, 1, roast_all), _ingredient(SHRIMP_ID, PROCESS_STATE_ROAST_RARE, 1, roast_all), _ingredient(VEG_ROOT_ID, PROCESS_STATE_CUT), _ingredient(CABBAGE_ID, PROCESS_STATE_CUT)], 3),
		_recipe(DISH_WINE_PLATTER_ID, [_ingredient(MEAT_RED_ID, PROCESS_STATE_ROAST_RARE, 1, roast_all), _ingredient(DRINK_OASIS_WINE_ID, PROCESS_STATE_NONE), _ingredient(EGG_ID, PROCESS_STATE_GRIND_FINE, 1, grind_both), _ingredient(SUN_SEED_ID, PROCESS_STATE_ROAST_RARE, 1, roast_all)], 3),
		_recipe(DISH_SUNRISE_BANQUET_ID, [_ingredient(EGG_ID, PROCESS_STATE_ROAST_WELL, 2), _ingredient(RICE_ID, PROCESS_STATE_ROAST_WELL, 2), _ingredient(TOFU_ID, PROCESS_STATE_GRIND_FINE)], 3),
		_recipe(DISH_STONEFLOWER_HONEY_FEAST_ID, [_ingredient(TOFU_ID, PROCESS_STATE_ROAST_WELL, 2), _ingredient(EGG_ID, PROCESS_STATE_ROAST_WELL, 2), _ingredient(TOFU_ID, PROCESS_STATE_GRIND_FINE)], 3)
		,_recipe(DISH_SANDWORM_ROYAL_HEAT_PLATE_ID, [_ingredient(SANDWORM_CORE_ID, PROCESS_STATE_ROAST_MEDIUM, 1, roast_all), _ingredient(CAMEL_MEAT_ID, PROCESS_STATE_ROAST_RARE, 1, roast_all), _ingredient(CABBAGE_ID, PROCESS_STATE_CUT), _ingredient(SUN_SEED_ID, PROCESS_STATE_GRIND_FINE, 1, grind_both), _ingredient(DRINK_OASIS_WINE_ID, PROCESS_STATE_NONE), _ingredient(TOFU_ID, PROCESS_STATE_GRIND_COARSE, 1, grind_both)], 3)
		,_recipe(DISH_SCORPION_SUNPLATE_ID, [_ingredient(SCORPION_CLAW_ID, PROCESS_STATE_ROAST_MEDIUM, 1, roast_all), _ingredient(MEAT_RED_ID, PROCESS_STATE_ROAST_WELL, 1, roast_all), _ingredient(VEG_LEAF_ID, PROCESS_STATE_CUT), _ingredient(EGG_ID, PROCESS_STATE_GRIND_FINE, 1, grind_both), _ingredient(DRINK_GOLD_ALE_ID, PROCESS_STATE_NONE), _ingredient(MUSHROOM_ID, PROCESS_STATE_GRIND_COARSE, 1, grind_both)], 3)
		,_recipe(DISH_VULTURE_FEATHER_FEAST_ID, [_ingredient(VULTURE_FEATHERHEART_ID, PROCESS_STATE_ROAST_RARE, 1, roast_all), _ingredient(SHRIMP_ID, PROCESS_STATE_ROAST_MEDIUM, 1, roast_all), _ingredient(RICE_ID, PROCESS_STATE_ROAST_WELL, 1, roast_all), _ingredient(VEG_LEAF_ID, PROCESS_STATE_CUT), _ingredient(DRINK_QINGMEI_WINE_ID, PROCESS_STATE_NONE), _ingredient(TOFU_ID, PROCESS_STATE_GRIND_FINE, 1, grind_both)], 3)
		,_recipe(DISH_MONITOR_ROYAL_BANQUET_ID, [_ingredient(MONITOR_TENDERLOIN_ID, PROCESS_STATE_ROAST_MEDIUM, 1, roast_all), _ingredient(MEAT_RED_ID, PROCESS_STATE_ROAST_WELL), _ingredient(VEG_ROOT_ID, PROCESS_STATE_ROAST_WELL), _ingredient(CABBAGE_ID, PROCESS_STATE_CUT), _ingredient(MUSHROOM_ID, PROCESS_STATE_GRIND_FINE), _ingredient(DRINK_OASIS_WINE_ID, PROCESS_STATE_NONE)], 3)
	]
	return _recipe_cache

static func is_supported_item(item_id: StringName) -> bool:
	return item_id in [&"ice_water", &"magic_net", &"bear_trap", PLATE_ID, DIRTY_PLATE_ID, SEASONING_BOX_ID, TRASH_ID] or ITEM_TYPES.has(item_id) or ITEM_CATEGORIES.has(item_id)

static func is_ingredient(item_id: StringName) -> bool:
	return ITEM_TYPES.get(item_id, &"") == &"ingredient"

static func is_dish(item_id: StringName) -> bool:
	return ITEM_CATEGORIES.has(item_id)

static func is_assembly_component(item_id: StringName) -> bool:
	return is_ingredient(item_id) or item_id in ASSEMBLY_COMPONENT_IDS

static func get_trash_item_data() -> Dictionary:
	return {
		"item_id": TRASH_ID,
		"texture": get_item_texture(TRASH_ID),
		"process_state": PROCESS_STATE_NONE,
		"recipe_signature": ""
	}

static func is_barrel_drink(item_id: StringName) -> bool:
	return item_id in BARREL_DRINK_IDS

static func get_barrel_input_item_id(drink_item_id: StringName) -> StringName:
	return StringName(BARREL_INPUTS.get(drink_item_id, &""))

static func get_barrel_drink_for_input(input_item_id: StringName) -> StringName:
	for drink_item_id in BARREL_INPUTS.keys():
		if StringName(BARREL_INPUTS[drink_item_id]) == input_item_id:
			return StringName(drink_item_id)
	return &""

static func is_drink_related_dish(item_id: StringName) -> bool:
	if is_barrel_drink(item_id):
		return true
	for entry in get_recipe_for_dish(item_id):
		if is_barrel_drink(StringName(entry.get("item_id", &""))):
			return true
	return false

static func get_all_ingredient_ids() -> Array[StringName]:
	return INGREDIENT_IDS.duplicate()

static func is_boss_ingredient(item_id: StringName) -> bool:
	return item_id in [SANDWORM_CORE_ID, SCORPION_CLAW_ID, VULTURE_FEATHERHEART_ID, MONITOR_TENDERLOIN_ID]

static func get_all_dish_ids() -> Array[StringName]:
	return DISH_IDS.duplicate()

static func is_valid_process_state(process_state: StringName) -> bool:
	return process_state in [
		PROCESS_STATE_NONE, PROCESS_STATE_CUT, PROCESS_STATE_ROAST_RARE,
		PROCESS_STATE_ROAST_MEDIUM, PROCESS_STATE_ROAST_WELL, PROCESS_STATE_GRIND_COARSE,
		PROCESS_STATE_GRIND_FINE, PROCESS_STATE_BURNT, PROCESS_STATE_STEAM,
		PROCESS_STATE_STIR_FRY, PROCESS_STATE_DEEP_FRY, PROCESS_STATE_BOIL, PROCESS_STATE_BAKE
	]

static func normalize_process_state(process_state: StringName) -> StringName:
	match process_state:
		PROCESS_STATE_STEAM, PROCESS_STATE_STIR_FRY:
			return PROCESS_STATE_ROAST_MEDIUM
		PROCESS_STATE_DEEP_FRY, PROCESS_STATE_BOIL, PROCESS_STATE_BAKE:
			return PROCESS_STATE_ROAST_WELL
		_:
			return process_state if is_valid_process_state(process_state) else PROCESS_STATE_NONE

static func get_station_output_state(process_state: StringName) -> StringName:
	match normalize_process_state(process_state):
		PROCESS_STATE_CUT:
			return PROCESS_STATE_CUT
		PROCESS_STATE_ROAST_RARE, PROCESS_STATE_ROAST_MEDIUM, PROCESS_STATE_ROAST_WELL:
			return PROCESS_STATE_ROAST_WELL
		PROCESS_STATE_GRIND_COARSE, PROCESS_STATE_GRIND_FINE:
			return PROCESS_STATE_GRIND_FINE
		_:
			return PROCESS_STATE_NONE

static func is_raw_state(process_state: StringName) -> bool:
	return normalize_process_state(process_state) == PROCESS_STATE_NONE

static func get_item_modulate(process_state: StringName, item_id: StringName = &"") -> Color:
	if is_dish(item_id):
		return Color.WHITE
	match normalize_process_state(process_state):
		PROCESS_STATE_CUT:
			return CUT_MODULATE
		PROCESS_STATE_ROAST_RARE:
			return ROAST_RARE_MODULATE
		PROCESS_STATE_ROAST_MEDIUM:
			return ROAST_MEDIUM_MODULATE
		PROCESS_STATE_ROAST_WELL:
			return ROAST_WELL_MODULATE
		PROCESS_STATE_GRIND_COARSE:
			return GRIND_COARSE_MODULATE
		PROCESS_STATE_GRIND_FINE:
			return GRIND_FINE_MODULATE
		PROCESS_STATE_BURNT:
			return BURNT_MODULATE
		_:
			return RAW_MODULATE

static func get_item_texture(item_id: StringName) -> Texture2D:
	if item_id in [&"ice_water", &"magic_net", &"bear_trap"]:
		return load("res://ArtResource/Facilities/%s.svg" % item_id)
	return ITEM_TEXTURES.get(item_id, null)

## UI uses food-only textures; world items choose tableware from their payload.
static func get_world_item_texture(item_id: StringName, payload: Dictionary = {}, fallback: Texture2D = null) -> Texture2D:
	if PLATED_DISH_TEXTURES.has(item_id):
		if bool(payload.get("uses_plate", false)):
			return PLATED_DISH_TEXTURES[item_id]
		return PREPARED_DISH_TEXTURES.get(item_id, get_item_texture(item_id))
	return fallback if fallback != null else get_item_texture(item_id)

static func get_process_icon_texture(process_state: StringName) -> Texture2D:
	return PROCESS_ICON_TEXTURES.get(normalize_process_state(process_state), null)

static func get_item_texture_for_process(item_id: StringName, process_state: StringName) -> Texture2D:
	return get_item_texture(item_id)

static func get_item_display_name(item_id: StringName) -> String:
	if item_id in [&"ice_water", &"magic_net", &"bear_trap"]:
		return {&"ice_water": "冰水", &"magic_net": "魔网", &"bear_trap": "捕兽夹"}[item_id]
	return ITEM_DISPLAY_NAMES.get(item_id, String(item_id))

static func get_item_description(item_id: StringName) -> String:
	return ITEM_DESCRIPTIONS.get(item_id, "")

static func get_item_category(item_id: StringName) -> StringName:
	return StringName(ITEM_CATEGORIES.get(item_id, &""))

static func is_drink(item_id: StringName) -> bool:
	return get_item_category(item_id) == &"drink"

static func is_small_plate(item_id: StringName) -> bool:
	return get_item_category(item_id) == &"small_plate"

static func is_main_dish(item_id: StringName) -> bool:
	return get_item_category(item_id) == &"main_dish"

static func is_dessert(item_id: StringName) -> bool:
	return get_item_category(item_id) == &"dessert"

static func get_stage_group_def(stage_group_id: StringName) -> Dictionary:
	return STAGE_GROUPS.get(stage_group_id, {})

static func get_stage_group_display_name(stage_group_id: StringName) -> String:
	return String(get_stage_group_def(stage_group_id).get("display_name", String(stage_group_id)))

static func get_stage_group_description(stage_group_id: StringName) -> String:
	return String(get_stage_group_def(stage_group_id).get("desc", ""))

static func get_processed_item_name(item_id: StringName, process_state: StringName) -> String:
	var base_name := get_item_display_name(item_id)
	if is_dish(item_id) or is_raw_state(process_state):
		return base_name
	return "%s（%s）" % [base_name, get_process_display_name(process_state)]

static func get_process_display_name(process_state: StringName) -> String:
	match normalize_process_state(process_state):
		PROCESS_STATE_CUT:
			return "切"
		PROCESS_STATE_ROAST_RARE:
			return "烤·微生"
		PROCESS_STATE_ROAST_MEDIUM:
			return "烤·半熟"
		PROCESS_STATE_ROAST_WELL:
			return "烤·全熟"
		PROCESS_STATE_GRIND_COARSE:
			return "磨·粗磨"
		PROCESS_STATE_GRIND_FINE:
			return "磨·细磨"
		PROCESS_STATE_BURNT:
			return "糊"
		_:
			return "生"

static func get_recipe_entry_process_states(recipe_entry: Dictionary) -> Array[StringName]:
	var result: Array[StringName] = []
	var accepted_states: Variant = recipe_entry.get("accepted_process_states", [])
	var source_states: Array = accepted_states if accepted_states is Array and not accepted_states.is_empty() else [
		recipe_entry.get("process_state", PROCESS_STATE_NONE)
	]
	for process_state in source_states:
		var normalized_state := normalize_process_state(StringName(process_state))
		if normalized_state not in result:
			result.append(normalized_state)
	return result

static func get_recipe_entry_process_text(recipe_entry: Dictionary) -> String:
	var allowed: Array = recipe_entry.get("accepted_process_states", [])
	if not allowed.is_empty():
		var family: StringName = get_process_family(StringName(allowed[0]))
		if family == &"roast" and allowed.size() == 3:
			return "烤·任意熟度"
		if family == &"grind" and allowed.size() == 2:
			return "磨·粗细均可"
	var names: Array[String] = []
	for process_state in get_recipe_entry_process_states(recipe_entry):
		var display_name := get_process_display_name(process_state)
		if display_name not in names:
			names.append(display_name)
	return "/".join(names)

static func get_recipe_for_dish(dish_item_id: StringName) -> Array:
	for recipe in get_recipes():
		if recipe.get("output_item_id", &"") == dish_item_id:
			return recipe.get("ingredients", []).duplicate(true)
	return []

static func get_display_recipe_for_dish(dish_item_id: StringName) -> Array:
	var recipe := get_recipe_for_dish(dish_item_id)
	if not recipe.is_empty():
		return recipe
	if is_barrel_drink(dish_item_id):
		return [{"item_id": get_barrel_input_item_id(dish_item_id), "process_state": PROCESS_STATE_NONE, "source": &"barrel"}]
	return []

static func get_dish_preparation_text(dish_item_id: StringName) -> String:
	if is_barrel_drink(dish_item_id):
		return "酒桶酿造，可提前备酒"
	var portions: int = 0
	var has_variable_maturation: bool = false
	var has_drink: bool = false
	for entry: Dictionary in get_recipe_for_dish(dish_item_id):
		portions += int(entry.get("count", 1))
		has_variable_maturation = has_variable_maturation or not Array(entry.get("accepted_process_states", [])).is_empty()
		has_drink = has_drink or is_barrel_drink(StringName(entry.item_id))
	if has_variable_maturation:
		var rule: String = "同类加工统一熟成度" if get_dish_difficulty(dish_item_id) == 2 else "仅一项熟成度随客单变化"
		return "熟成变种 · %d份；%s" % [portions, rule]
	if has_drink:
		return "含酒配方 · %d份；加工要求固定，可提前备菜备酒" % portions
	return "固定配方 · %d份；加工要求固定，可提前备菜" % portions

static func instantiate_order_recipe_for_dish(dish_item_id: StringName) -> Array:
	var recipe_items: Array = get_display_recipe_for_dish(dish_item_id)
	var difficulty: int = get_dish_difficulty(dish_item_id)
	var variable_indices: Array[int] = []
	for i in range(recipe_items.size()):
		if not Array(recipe_items[i].get("accepted_process_states", [])).is_empty():
			variable_indices.append(i)
	var precise_index: int = variable_indices.pick_random() if not variable_indices.is_empty() else -1
	var family_states: Dictionary = {}
	if difficulty == 2:
		# A medium dish shares one maturation for each processing family.
		for i: int in variable_indices:
			var entry: Dictionary = recipe_items[i]
			var family: StringName = get_process_family(StringName(entry.process_state))
			var allowed: Array = entry.accepted_process_states
			var shared: Array = family_states.get(family, allowed.duplicate())
			family_states[family] = shared.filter(func(state: Variant) -> bool: return allowed.has(state))
		for family: StringName in family_states:
			var allowed: Array = family_states[family]
			assert(not allowed.is_empty(), "Medium recipe has incompatible maturation requirements")
			family_states[family] = allowed.pick_random()
	for i: int in variable_indices:
		var entry: Dictionary = recipe_items[i]
		if difficulty == 2:
			entry["process_state"] = family_states[get_process_family(StringName(entry.process_state))]
		elif difficulty >= 3 and i != precise_index:
			# Only one component varies per customer; the rest use the fixed
			# menu state so they can be prepared in advance.
			pass
		else:
			entry["process_state"] = Array(entry.accepted_process_states).pick_random()
		entry.erase("accepted_process_states")
	return recipe_items

## A finished dish records its actual inputs; delivery checks the order's
## fixed per-order states instead of comparing opaque strings.
static func signature_matches_recipe(signature: String, recipe_items: Array) -> bool:
	if signature.is_empty():
		return false
	var actual: Array[Dictionary] = []
	for token: String in signature.split("|"):
		var parts: PackedStringArray = token.split(":")
		if parts.size() != 3 or not parts[2].is_valid_int():
			return false
		var count: int = int(parts[2])
		if count < 1 or count > 6:
			return false
		for _portion in range(count):
			actual.append({"item_id": StringName(parts[0]), "process_state": normalize_process_state(StringName(parts[1]))})
	return matches_recipe(actual, recipe_items)

static func get_recipe_data_for_dish(dish_item_id: StringName) -> Dictionary:
	for recipe in get_recipes():
		if recipe.get("output_item_id", &"") == dish_item_id:
			return recipe.duplicate(true)
	return {}

static func get_dish_difficulty(dish_item_id: StringName) -> int:
	return int(get_recipe_data_for_dish(dish_item_id).get("difficulty", 1))

## Balance model shared by orders, rewards and the codex.  Recipe data remains
## authoritative; these values are derived from category, level, portions,
## processing method and maturation requirements.
const DISH_LEVEL_GOLD_BASE := {
	1: 8,
	2: 22,
	3: 42
}
const DISH_TYPE_GOLD_BONUS := {
	&"drink": 0,
	&"small_plate": 5,
	&"main_dish": 11,
	&"dessert": 17
}
const DISH_LEVEL_WAIT_BASE := {
	1: 18.0,
	2: 30.0,
	3: 44.0
}
const DISH_TYPE_WAIT_BONUS := {
	&"drink": 0.0,
	&"small_plate": 3.0,
	&"main_dish": 7.0,
	&"dessert": 10.0
}
const PROCESS_METHOD_SCORE := {
	&"raw": 0,
	&"cut": 1,
	&"grind": 2,
	&"roast": 3,
	&"burnt": 4
}

## Hidden acquisition tier. It reflects enemy/biome access rather than a
## player-facing rarity label, and only contributes a small balance modifier.
const INGREDIENT_ACQUISITION_TIER := {
	MEAT_RED_ID: 1, VEG_LEAF_ID: 1, VEG_ROOT_ID: 1, RICE_ID: 1,
	MEAT_WHITE_ID: 2, SHRIMP_ID: 2, CABBAGE_ID: 2, MUSHROOM_ID: 2, SUN_SEED_ID: 2,
	CAMEL_MEAT_ID: 3, EGG_ID: 3, TOFU_ID: 3
}

## Hidden economy profile for the 12 base ingredients.  The rank is never
## shown in the codex; it only gives the balance model a stable ordering.
## Within a tier, meat is intentionally worth more than non-meat.  Ingredients
## that can come from both battle and foraging have a lower rank than forage-
## only ingredients, while lower-ranked battle drops appear in larger stacks.
const INGREDIENT_VALUE_PROFILE := {
	VEG_LEAF_ID: {"rank": 1, "source": &"battle_and_forage", "forage_yield_min": 3, "forage_yield_max": 5, "battle_drop_bonus": 2},
	VEG_ROOT_ID: {"rank": 2, "source": &"battle_and_forage", "forage_yield_min": 3, "forage_yield_max": 5, "battle_drop_bonus": 2},
	RICE_ID: {"rank": 3, "source": &"forage_only", "forage_yield_min": 3, "forage_yield_max": 5, "battle_drop_bonus": 0},
	MEAT_RED_ID: {"rank": 4, "source": &"battle_only", "forage_yield_min": 0, "forage_yield_max": 0, "battle_drop_bonus": 1},
	CABBAGE_ID: {"rank": 5, "source": &"battle_and_forage", "forage_yield_min": 2, "forage_yield_max": 4, "battle_drop_bonus": 1},
	MUSHROOM_ID: {"rank": 6, "source": &"battle_and_forage", "forage_yield_min": 2, "forage_yield_max": 4, "battle_drop_bonus": 1},
	SUN_SEED_ID: {"rank": 7, "source": &"forage_only", "forage_yield_min": 2, "forage_yield_max": 4, "battle_drop_bonus": 0},
	MEAT_WHITE_ID: {"rank": 8, "source": &"battle_only", "forage_yield_min": 0, "forage_yield_max": 0, "battle_drop_bonus": 0},
	SHRIMP_ID: {"rank": 9, "source": &"battle_only", "forage_yield_min": 0, "forage_yield_max": 0, "battle_drop_bonus": 0},
	EGG_ID: {"rank": 10, "source": &"forage_only", "forage_yield_min": 1, "forage_yield_max": 2, "battle_drop_bonus": 0},
	TOFU_ID: {"rank": 11, "source": &"forage_only", "forage_yield_min": 1, "forage_yield_max": 2, "battle_drop_bonus": 0},
	CAMEL_MEAT_ID: {"rank": 12, "source": &"battle_only", "forage_yield_min": 0, "forage_yield_max": 0, "battle_drop_bonus": 0}
}

static func get_ingredient_acquisition_tier(item_id: StringName) -> int:
	return clampi(int(INGREDIENT_ACQUISITION_TIER.get(item_id, 1)), 1, 3)

static func get_ingredient_value_rank(item_id: StringName) -> int:
	return clampi(int(INGREDIENT_VALUE_PROFILE.get(item_id, {}).get("rank", 1)), 1, INGREDIENT_IDS.size())

static func get_ingredient_source(item_id: StringName) -> StringName:
	return StringName(INGREDIENT_VALUE_PROFILE.get(item_id, {}).get("source", &"forage_only"))

static func can_drop_ingredient_from_battle(item_id: StringName) -> bool:
	var source := get_ingredient_source(item_id)
	return source == &"battle_only" or source == &"battle_and_forage"

static func get_forage_yield_range(item_id: StringName) -> Vector2i:
	var profile: Dictionary = INGREDIENT_VALUE_PROFILE.get(item_id, {})
	return Vector2i(
		maxi(int(profile.get("forage_yield_min", 1)), 0),
		maxi(int(profile.get("forage_yield_max", 1)), 0)
	)

static func get_battle_drop_quantity(item_id: StringName, authored_count: int) -> int:
	var profile: Dictionary = INGREDIENT_VALUE_PROFILE.get(item_id, {})
	var bonus := maxi(int(profile.get("battle_drop_bonus", 0)), 0)
	return maxi(authored_count, 0) + bonus

static func _get_base_ingredient_cost(item_id: StringName, visited: Dictionary) -> Dictionary:
	if is_ingredient(item_id):
		return {"count": 1.0, "value": float(get_ingredient_value_rank(item_id))}
	if visited.has(item_id):
		return {"count": 0.0, "value": 0.0}
	visited[item_id] = true
	if is_barrel_drink(item_id):
		var barrel_input := get_barrel_input_item_id(item_id)
		return {
			"count": 0.5,
			"value": float(get_ingredient_value_rank(barrel_input)) * 0.5
		}
	var total_count := 0.0
	var total_value := 0.0
	for entry in get_recipe_for_dish(item_id):
		if not (entry is Dictionary):
			continue
		var component_id := StringName(entry.get("item_id", &""))
		var component_count := maxi(int(entry.get("count", 1)), 1)
		var branch_visited := visited.duplicate()
		var component_cost := _get_base_ingredient_cost(component_id, branch_visited)
		total_count += float(component_cost.get("count", 0.0)) * float(component_count)
		total_value += float(component_cost.get("value", 0.0)) * float(component_count)
	return {"count": total_count, "value": total_value}

static func get_dish_balance_profile(dish_item_id: StringName) -> Dictionary:
	var recipe := get_recipe_for_dish(dish_item_id)
	var item_count := 0
	var method_complexity := 0
	var maturation_complexity := 0
	var ingredient_tier_score := 0
	for entry in recipe:
		if not (entry is Dictionary):
			continue
		var count := maxi(int(entry.get("count", 1)), 1)
		item_count += count
		ingredient_tier_score += get_ingredient_acquisition_tier(StringName(entry.get("item_id", &""))) * count
		var required_state := normalize_process_state(StringName(entry.get("process_state", PROCESS_STATE_NONE)))
		var family := get_process_family(required_state)
		method_complexity += int(PROCESS_METHOD_SCORE.get(family, 0)) * count
		if required_state != PROCESS_STATE_NONE:
			var accepted_states: Variant = entry.get("accepted_process_states", [])
			if accepted_states is Array and not accepted_states.is_empty():
				maturation_complexity += maxi(accepted_states.size(), 1) * count
			else:
				maturation_complexity += count
	if item_count <= 0 and is_barrel_drink(dish_item_id):
		item_count = 1
		method_complexity = 0
		maturation_complexity = 0
	var base_ingredient_cost := _get_base_ingredient_cost(dish_item_id, {})
	var base_ingredient_count := float(base_ingredient_cost.get("count", 0.0))
	var ingredient_value_score := float(base_ingredient_cost.get("value", 0.0))
	var average_ingredient_value := ingredient_value_score / maxf(base_ingredient_count, 0.5)
	return {
		"category": get_item_category(dish_item_id),
		"level": maxi(get_dish_difficulty(dish_item_id), 1),
		"ingredient_count": maxi(item_count, 1),
		"method_complexity": method_complexity,
		"maturation_complexity": maturation_complexity,
		"ingredient_tier_score": ingredient_tier_score,
		"base_ingredient_count": base_ingredient_count,
		"ingredient_value_score": ingredient_value_score,
		"average_ingredient_value": average_ingredient_value
	}

static func get_dish_patience_duration(dish_item_id: StringName) -> float:
	var profile := get_dish_balance_profile(dish_item_id)
	var category := StringName(profile.get("category", &"drink"))
	var level := int(profile.get("level", 1))
	var ingredient_count := int(profile.get("ingredient_count", 1))
	var method_complexity := int(profile.get("method_complexity", 0))
	var maturation_complexity := int(profile.get("maturation_complexity", 0))
	var average_ingredient_value := float(profile.get("average_ingredient_value", 1.0))
	var duration := float(DISH_LEVEL_WAIT_BASE.get(level, 68.0)) \
		+ float(DISH_TYPE_WAIT_BONUS.get(category, 0.0)) \
		+ float(ingredient_count) * 1.0 \
		+ float(method_complexity) * 1.0 \
		+ float(maturation_complexity) * 0.7 \
		+ average_ingredient_value * 0.3
	return snappedf(maxf(duration * 1.6, 32.0), 0.5)

static func get_dish_gold_reward(dish_item_id: StringName) -> int:
	var profile := get_dish_balance_profile(dish_item_id)
	var category := StringName(profile.get("category", &"drink"))
	var level := int(profile.get("level", 1))
	var ingredient_count := int(profile.get("ingredient_count", 1))
	var method_complexity := int(profile.get("method_complexity", 0))
	var maturation_complexity := int(profile.get("maturation_complexity", 0))
	var ingredient_value_score := float(profile.get("ingredient_value_score", 0.0))
	var reward := float(DISH_LEVEL_GOLD_BASE.get(level, 42)) \
		+ float(DISH_TYPE_GOLD_BONUS.get(category, 0)) \
		+ float(ingredient_count) \
		+ float(method_complexity) \
		+ float(maturation_complexity) \
		+ ingredient_value_score * 0.35
	return maxi(int(round(reward)), 1)

static func get_dish_xp_reward(dish_item_id: StringName) -> int:
	return maxi(int(round(float(get_dish_gold_reward(dish_item_id)) * 0.32)), 1)

static func matches_ingredient(item_data: Dictionary, required_item_id: StringName, required_process_state: StringName, accepted_states: Array = []) -> bool:
	if item_data.get("item_id", &"") != required_item_id:
		return false
	var actual_state := normalize_process_state(StringName(item_data.get("process_state", PROCESS_STATE_NONE)))
	var allowed_states: Array = []
	if accepted_states.is_empty():
		allowed_states.append(normalize_process_state(required_process_state))
	else:
		for state in accepted_states:
			allowed_states.append(normalize_process_state(StringName(state)))
	return actual_state in allowed_states

static func matches_recipe(stored_items: Array[Dictionary], ingredients: Array) -> bool:
	var required_count: int = 0
	for entry in ingredients:
		if entry is Dictionary:
			required_count += int(entry.get("count", 1))
	if stored_items.size() != required_count:
		return false

	var unmatched := stored_items.duplicate(true)
	for required_entry in ingredients:
		if not (required_entry is Dictionary):
			continue
		var accepted_states: Array = required_entry.get("accepted_process_states", [])
		for _repeat_index in range(int(required_entry.get("count", 1))):
			var matched_index := -1
			for i in range(unmatched.size()):
				if matches_ingredient(unmatched[i], required_entry.get("item_id", &""), required_entry.get("process_state", PROCESS_STATE_NONE), accepted_states):
					matched_index = i
					break
			if matched_index < 0:
				return false
			unmatched.remove_at(matched_index)
	return true

static func get_process_family(process_state: StringName) -> StringName:
	match normalize_process_state(process_state):
		PROCESS_STATE_NONE:
			return &"raw"
		PROCESS_STATE_CUT:
			return &"cut"
		PROCESS_STATE_ROAST_RARE, PROCESS_STATE_ROAST_MEDIUM, PROCESS_STATE_ROAST_WELL:
			return &"roast"
		PROCESS_STATE_GRIND_COARSE, PROCESS_STATE_GRIND_FINE:
			return &"grind"
		PROCESS_STATE_BURNT:
			return &"burnt"
		_:
			return &"invalid"

## Free-form assembly may differ only in completion within the same processing
## family. Rare/medium/well and coarse/fine are interchangeable for producing
## the dish, while raw, cut, roast, grind and burnt remain distinct operations.
static func matches_recipe_process_family(stored_items: Array[Dictionary], ingredients: Array) -> bool:
	var required_count: int = 0
	for entry in ingredients:
		if entry is Dictionary:
			required_count += int(entry.get("count", 1))
	if stored_items.size() != required_count:
		return false

	var unmatched := stored_items.duplicate(true)
	for required_entry in ingredients:
		if not (required_entry is Dictionary):
			continue
		var required_item_id: StringName = StringName(required_entry.get("item_id", &""))
		var required_family := get_process_family(StringName(required_entry.get("process_state", PROCESS_STATE_NONE)))
		for _repeat_index in range(int(required_entry.get("count", 1))):
			var matched_index := -1
			for i in range(unmatched.size()):
				var actual_item_id := StringName(unmatched[i].get("item_id", &""))
				var actual_family := get_process_family(StringName(unmatched[i].get("process_state", PROCESS_STATE_NONE)))
				if actual_item_id == required_item_id and actual_family == required_family:
					matched_index = i
					break
			if matched_index < 0:
				return false
			unmatched.remove_at(matched_index)
	return true

static func get_recipe_signature(ingredients: Array) -> String:
	var counts_by_item_and_state: Dictionary = {}
	for entry in ingredients:
		if not (entry is Dictionary):
			continue
		var item_id := StringName(entry.get("item_id", &""))
		var process_state := normalize_process_state(StringName(entry.get("process_state", PROCESS_STATE_NONE)))
		var count := int(entry.get("count", 1))
		var key := "%s:%s" % [String(item_id), String(process_state)]
		counts_by_item_and_state[key] = int(counts_by_item_and_state.get(key, 0)) + count
	var parts: Array[String] = []
	for key in counts_by_item_and_state.keys():
		parts.append("%s:%d" % [String(key), int(counts_by_item_and_state[key])])
	parts.sort()
	return "|".join(parts)

static func find_matching_recipe(stored_items: Array[Dictionary], allow_customer_ranges: bool = true) -> Dictionary:
	for recipe in get_recipes():
		var ingredients: Array = recipe.get("ingredients", [])
		if not allow_customer_ranges:
			var has_customer_range := false
			for required_entry in ingredients:
				if required_entry is Dictionary and not Array(required_entry.get("accepted_process_states", [])).is_empty():
					has_customer_range = true
					break
			if has_customer_range:
				continue
		if matches_recipe(stored_items, ingredients):
			var output_item_id: StringName = recipe.get("output_item_id", &"")
			return {
				"output_item_id": output_item_id,
				"output_process_state": PROCESS_STATE_NONE,
				"output_texture": get_item_texture(output_item_id),
				"recipe_signature": get_recipe_signature(stored_items)
			}
	return {}

static func find_matching_recipe_with_alternate_completion(stored_items: Array[Dictionary]) -> Dictionary:
	for recipe in get_recipes():
		var ingredients: Array = recipe.get("ingredients", [])
		if not matches_recipe_process_family(stored_items, ingredients):
			continue
		var output_item_id: StringName = recipe.get("output_item_id", &"")
		return {
			"output_item_id": output_item_id,
			"output_process_state": PROCESS_STATE_NONE,
			"output_texture": get_item_texture(output_item_id),
			"recipe_signature": get_recipe_signature(stored_items)
		}
	return {}
