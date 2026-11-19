extends RefCounted

const BASE: StringName = &"steady_pot"
const EXTEND: StringName = &"long_service"
const FOCUS: StringName = &"focused_chef"
const AURA: StringName = &"empowered_kitchen"
const INSTANT: StringName = &"rapid_prep"
const SIGNATURE: StringName = &"blessed_station"
const RECOVERY: StringName = &"comeback_feast"

const OPTIONS: Array[Dictionary] = [
	{"id": BASE, "name": "稳住这锅", "duration": 10.0, "work_multiplier": 2.0,
		"detail": "持续 10 秒，所有读条型工作速度提高 100%。仍会受到伤害和控制。", "note": "原版，作为大招升级对照。"},
	{"id": EXTEND, "name": "忙中有序", "duration": 12.0, "work_multiplier": 2.0, "max_extension": 30.0, "extension_per_work": 3.0,
		"detail": "持续 12 秒，读条型工作速度提高 100%。每完成一次手动工作或上菜，延长 3 秒，最多额外延长 30 秒。", "note": "连续完成工作可以把爆发窗口延长到 42 秒。"},
	{"id": FOCUS, "name": "专心掌勺", "duration": 20.0, "work_multiplier": 2.0, "control_immunity": true,
		"detail": "持续 20 秒，读条型工作速度提高 100%，解除并免疫控制。", "note": "仍会受到伤害。"},
	{"id": AURA, "name": "灶火共鸣", "duration": 25.0, "facility_multiplier": 2.0, "facility_radius": 320.0,
		"detail": "以玩家为中心强化范围内设施 25 秒，工作效率提高 100%。", "note": "切、磨、烤台和酒桶均可获得增益；效果跟随释放者的位置。"},
	{"id": INSTANT, "name": "连环快手", "duration": 30.0, "instant_work_charges": 6,
		"detail": "持续 30 秒，接下来的 6 次手动工作立即完成。", "note": "磨台粗磨与细磨各算一次；粗磨完成后 1 秒内继续细磨不消耗次数。"},
	{"id": SIGNATURE, "name": "名灶点化", "duration": 60.0, "facility_multiplier": 3.0, "signature_station": true,
		"detail": "点化一台料理设施，持续 60 秒，工作效率提高 200%。", "note": "增益跟随设施；烤台和酒桶也会加速。"},
	{"id": RECOVERY, "name": "回春开席", "duration": 20.0, "work_multiplier": 2.25, "recover_health": 2, "recover_magic": 1,
		"detail": "持续 20 秒，读条型工作速度提高 125%。每完成一次手动工作或上菜，回复生命和魔力。", "note": "回复只在工作真正完成时发生，不能通过中断或重复放置触发。"}
]

const RECOVERY_REWARDS := {
	&"repair": {"health_ratio": 0.02, "magic": 1},
	&"collect": {"health_ratio": 0.02, "magic": 1},
	&"cut": {"health_ratio": 0.03, "magic": 1},
	&"grind_coarse": {"health_ratio": 0.04, "magic": 1},
	&"grind_fine": {"health_ratio": 0.05, "magic": 1},
	&"order": {"health_ratio": 0.02, "magic": 1},
	&"wash": {"health_ratio": 0.02, "magic": 1},
	&"forage": {"health_ratio": 0.02, "magic": 1},
	&"serve": {"health_ratio": 0.08, "magic": 2}
}

static func get_definition(id: StringName) -> Dictionary:
	for entry: Dictionary in OPTIONS:
		if StringName(entry.id) == id:
			return entry.duplicate(true)
	return OPTIONS[0].duplicate(true)

static func get_options() -> Array[Dictionary]:
	return OPTIONS.duplicate(true)
