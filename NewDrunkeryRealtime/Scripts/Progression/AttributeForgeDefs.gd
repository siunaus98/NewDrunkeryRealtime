class_name AttributeForgeDefs
extends RefCounted

const SILVER := &"silver"
const GOLD := &"gold"
const DIAMOND := &"diamond"

const SILVER_VALUES := {
	&"attack_damage": 10.0,
	&"armor": 15.0,
	&"max_health": 15.0,
	&"health_regen": 1.0,
	&"move_speed": 0.05,
	&"work_efficiency": 20.0,
	&"cooldown_haste": 15.0,
	&"skill_power": 15.0,
	&"lifesteal": 0.05
}
const GOLD_VALUES := {
	&"attack_damage": 25.0,
	&"armor": 40.0,
	&"max_health": 35.0,
	&"health_regen": 3.0,
	&"move_speed": 0.10,
	&"work_efficiency": 50.0,
	&"cooldown_haste": 40.0,
	&"skill_power": 40.0,
	&"lifesteal": 0.12
}
const ATTRIBUTE_NAMES := {
	&"attack_damage": "攻击力",
	&"armor": "护甲",
	&"max_health": "最大生命",
	&"health_regen": "生命恢复",
	&"move_speed": "移动速度",
	&"work_efficiency": "工作效率",
	&"cooldown_haste": "冷却急速",
	&"skill_power": "技能强度",
	&"lifesteal": "吸血"
}
const DIAMOND_OPTIONS := [
	{"id": &"diamond_blade", "attribute_id": &"attack_damage", "title": "至臻锋刃", "description": "攻击力 +15；总攻击力 +15%。", "fixed": 15.0, "total_attack": 0.15},
	{"id": &"diamond_heart", "attribute_id": &"max_health", "title": "巨人之心", "description": "最大生命 +20；总生命 +15%。", "fixed": 20.0, "total_health": 0.15},
	{"id": &"diamond_shell", "attribute_id": &"armor", "title": "不朽外壳", "description": "护甲 +30；最终伤害减免 10%。", "fixed": 30.0, "final_damage_reduction": 0.10},
	{"id": &"diamond_spring", "attribute_id": &"health_regen", "title": "不息血泉", "description": "生命恢复 +1/秒；每秒恢复最大生命 2%。", "fixed": 1.0, "percent_health_regen": 0.02},
	{"id": &"diamond_wind", "attribute_id": &"move_speed", "title": "逐风之躯", "description": "总移动速度 +12%。", "total_move_speed": 0.12},
	{"id": &"diamond_hand", "attribute_id": &"work_efficiency", "title": "神工之手", "description": "工作效率 +20；总工作速度 +35%。", "fixed": 20.0, "total_work": 0.35},
	{"id": &"diamond_time", "attribute_id": &"cooldown_haste", "title": "时流核心", "description": "冷却急速 +15；技能基础冷却时间缩短 25%。", "fixed": 15.0, "skill_cooldown_multiplier": 0.75},
	{"id": &"diamond_prism", "attribute_id": &"skill_power", "title": "魔力棱镜", "description": "技能强度 +20；总技能强度 +20%。", "fixed": 20.0, "total_skill_power": 0.20},
	{"id": &"diamond_contract", "attribute_id": &"lifesteal", "title": "血色契约", "description": "全能吸血 12%。", "omnivamp": 0.12}
]

static func get_attribute_name(attribute_id: StringName) -> String:
	return String(ATTRIBUTE_NAMES.get(attribute_id, attribute_id))

static func get_fixed_value(tier: StringName, attribute_id: StringName) -> float:
	if tier == DIAMOND:
		return 0.0
	var source: Dictionary = GOLD_VALUES if tier == GOLD else SILVER_VALUES
	return float(source.get(attribute_id, 0.0))

static func format_value(attribute_id: StringName, value: float) -> String:
	if attribute_id in [&"move_speed", &"lifesteal"]:
		return "+%d%%" % int(round(value * 100.0))
	return "+%d" % int(round(value))

