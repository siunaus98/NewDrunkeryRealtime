extends RefCounted

const BASE: StringName = &"rush_order"
const KITCHEN: StringName = &"kitchen_rush"
const RANDOM: StringName = &"lucky_rush"
const WORK: StringName = &"working_rush"
const FIELD: StringName = &"kitchen_field"
const DIRECTION: StringName = &"planned_rush"
const TRAIL: StringName = &"lasting_trail"

const OPTIONS: Array[Dictionary] = [
	{"id": BASE, "name": "抢灶步", "cooldown": 15.0, "cost": 2, "bonus": 0.4, "duration": 2.0,
		"detail": "移速 +40%，持续 2 秒。", "note": "原版技能，作为测试对照。"},
	{"id": KITCHEN, "name": "灶间疾步", "cooldown": 15.0, "cost": 2, "bonus": 0.3, "duration": 1.5,
		"detail": "移速 +30%，持续 1.5 秒。料理区内释放时效果和持续时间翻倍；离开料理区立即结束。", "note": "强化仅在释放时判定。"},
	{"id": RANDOM, "name": "随运而行", "cooldown": 15.0, "cost": 2, "bonus": 0.0, "duration": 1.0,
		"random_bonus_min": 0.3, "random_bonus_max": 1.3, "random_duration_min": 1.0, "random_duration_max": 2.0,
		"detail": "随机移速 +30%～130%，持续 1～2 秒。释放后等概率获得 1 魔力、额外失去 1 魔力或不变。", "note": "固定先付 2 魔力；魔力为 0 时不再额外扣除。"},
	{"id": WORK, "name": "越忙越快", "cooldown": 15.0, "cost": 1, "bonus": 0.8, "duration": 1.0,
		"detail": "移速 +80%，持续 1 秒。完成读条型工作或上菜后，重置小技能冷却。", "note": "点单、切、粗磨、细磨、洗盘分别触发；不回复魔力。取烤物、组合出菜与酒桶投料不触发。"},
	{"id": FIELD, "name": "灶边顺风", "cooldown": 40.0, "cost": 3, "bonus": 0.8, "duration": 8.0,
		"radius": 320.0, "team_bonus": 0.4, "team_duration": 8.0,
		"detail": "仅料理区可用。在原地制造半径 2.5 格的加速区。单人移速 +80%，持续 8 秒；多人 +40%，持续 8 秒。", "note": "固定地点，对范围内所有玩家生效。"},
	{"id": DIRECTION, "name": "一路不停", "cooldown": 15.0, "cost": 2, "bonus": 0.6, "duration": 2.0,
		"direction_wait": 1.0,
		"detail": "移速 +60%，持续 2 秒。前 2 秒转向不取消加速。释放后 1 秒内锁定首次移动方向，沿该方向及相邻方向实际移动可持续续时。", "note": "保护期结束后，转出允许方向立即结束；停止或撞墙仅停止续时。箭头始终指向最初方向。"},
	{"id": TRAIL, "name": "熟路生风", "cooldown": 30.0, "cost": 2, "bonus": 0.3, "duration": 3.0,
		"trail_duration": 6.0, "trail_width": 96.0,
		"detail": "移速 +30%，持续 3 秒，移动时留下小径。技能结束后小径才生效，为所有玩家提供 +30% 移速，持续 6 秒。", "note": "铺设期间无小径加速；重复路径不叠加。"}
]

static func get_definition(id: StringName) -> Dictionary:
	for entry: Dictionary in OPTIONS:
		if StringName(entry.id) == id:
			return entry.duplicate(true)
	return OPTIONS[0].duplicate(true)

static func get_options() -> Array[Dictionary]:
	return OPTIONS.duplicate(true)

static func get_description(id: StringName) -> String:
	var entry: Dictionary = get_definition(id)
	return "%s\nU · %d 魔力 · 冷却 %s 秒\n%s\n%s" % [entry.name, entry.cost, str(entry.cooldown), entry.detail, entry.note]
