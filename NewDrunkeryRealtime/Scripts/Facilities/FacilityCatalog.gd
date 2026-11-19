extends RefCounted

## Shop data and construction only; behavior belongs to the facility scripts.
const ENTRIES: Array[Dictionary] = [
	{"id": &"flyer", "name": "传单机", "cost": 32, "limit": 1, "script": "MagicFacility", "detail": "消耗1魔力招来普通客人，收益+5%。"},
	{"id": &"fire_furnace", "name": "火神炉", "cost": 42, "limit": 1, "script": "MagicFacility", "detail": "消耗2魔力，6秒祝福料理。收益+10%，连续上祝福菜每次再+5%，最高+50%。"},
	{"id": &"water_dispenser", "name": "饮水机", "cost": 26, "limit": 1, "script": "MagicFacility", "detail": "冰水消耗1魔力，恢复已接单客人损失耐心的30%；每客一次，特殊客人除外。"},
	{"id": &"net_rack", "name": "魔网架", "cost": 36, "limit": 1, "script": "MagicFacility", "detail": "消耗2魔力。禁锢非BOSS单位5秒，期间承伤+50%；也会影响玩家。"},
	{"id": &"healing_spring", "name": "治疗之泉", "cost": 48, "limit": 1, "script": "MagicFacility", "detail": "消耗2魔力回复全部生命。每人冷却180秒，跨昼夜重置。"},
	{"id": &"portal", "name": "微型传送门（一对）", "cost": 65, "limit": 1, "script": "PortalFacility", "pair": true, "detail": "消耗1魔力传送整件物品，距离越远越慢；一对门共用一次传送。"},
	{"id": &"duplicator", "name": "神奇复制器", "cost": 52, "limit": 1, "script": "MagicFacility", "detail": "消耗3魔力复制普通食材或半成品。小料最多4份，不能复制BOSS食材。"},
	{"id": &"shuttle", "name": "摇摇车（双端点）", "cost": 34, "limit": 0, "script": "ShuttleFacility", "pair": true, "detail": "在双端点间快速运输最多3件食材或半成品，可受明光灯加速。"},
	{"id": &"stack_table", "name": "堆叠台", "cost": 22, "limit": 0, "script": "StackFacility", "detail": "同种同加工食材可堆5份，小料可堆20份。"},
	{"id": &"forklift", "name": "铲车", "cost": 180, "limit": 1, "script": "ForkliftFacility", "detail": "战斗区采集车，容量40、耐久2000、移速120%。碰撞承伤减半，造成50伤害并击退；耐久不自动恢复。"},
	{"id": &"culture", "name": "培养皿", "cost": 38, "limit": 3, "script": "CultureFacility", "detail": "消耗1份普通非肉类生食材，白天每25秒产1份，最多12份。"},
	{"id": &"trap_rack", "name": "捕兽夹", "cost": 8, "limit": 0, "script": "CombatFacility", "detail": "一次性陷阱，敌人受300伤害、玩家受60伤害。普通敌人禁锢2秒并永久减速40%；玩家与BOSS仅暂时减速。"},
	{"id": &"ballista", "name": "弩台", "cost": 60, "limit": 0, "script": "CombatFacility", "detail": "每2.5秒沿固定方向发射180伤害弩箭，也会伤害玩家。"}
]

static func definition(id: StringName) -> Dictionary:
	for entry: Dictionary in ENTRIES:
		if StringName(entry.id) == id:
			return entry
	return {}

static func available(id: StringName, count: int) -> bool:
	var entry := definition(id)
	return not entry.is_empty() and (int(entry.limit) <= 0 or count < int(entry.limit))

static func create(id: StringName) -> Node2D:
	var entry := definition(id)
	if entry.is_empty():
		return null
	var result: Node2D = load("res://Scripts/Facilities/%s.gd" % entry.script).new()
	if result.has_method("configure"):
		result.configure(id, String(entry.name))
	return result
