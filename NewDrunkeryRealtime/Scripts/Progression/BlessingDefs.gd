class_name BlessingDefs
extends RefCounted

# Stable compatibility aliases retained for older snapshots and tests.
const MOVE_SPEED_ID: StringName = &"blessing_002"
const ATTACK_DAMAGE_ID: StringName = &"blessing_001"
const DASH_RECOVERY_ID: StringName = &"blessing_069"

static func create_default_blessings() -> Array[Dictionary]:
	return [
		{
			"id": &"blessing_001",
			"title": "力量祝福",
			"type": &"general",
			"description": "总攻击力 +15%"
		},
		{
			"id": &"blessing_002",
			"title": "迅捷祝福",
			"type": &"general",
			"description": "总移动速度 +15%"
		},
		{
			"id": &"blessing_003",
			"title": "守护祝福",
			"type": &"general",
			"description": "总生命值 +15%"
		},
		{
			"id": &"blessing_004",
			"title": "坚韧祝福",
			"type": &"general",
			"description": "总生命恢复 +20%"
		},
		{
			"id": &"blessing_005",
			"title": "重力加速度",
			"type": &"general",
			"description": "向下移动时总移动速度 +25%"
		},
		{
			"id": &"blessing_006",
			"title": "长跑选手",
			"type": &"general",
			"description": "连续移动时每移动一格获得 +5% 移速，最多 +20%；停止 0.5 秒清除"
		},
		{
			"id": &"blessing_007",
			"title": "一路向北",
			"type": &"general",
			"description": "向上移动时总移动速度 +25%"
		},
		{
			"id": &"blessing_008",
			"title": "合理摸鱼",
			"type": &"general",
			"description": "每日开始前 100 秒移速与工作效率 -20%；之后移速与工作效率 +20%"
		},
		{
			"id": &"blessing_009",
			"title": "猎神之风",
			"type": &"general",
			"description": "击杀任意单位后移速 +25%，持续 3 秒；重复触发刷新持续时间"
		},
		{
			"id": &"blessing_010",
			"title": "猎神之刃",
			"type": &"general",
			"description": "击杀任意单位后，该单位的食材掉落数量 +1"
		},
		{
			"id": &"blessing_011",
			"title": "猎神之护",
			"type": &"general",
			"description": "击杀任意单位后获得相当于最大生命 20% 的护盾，持续 5 秒"
		},
		{
			"id": &"blessing_012",
			"title": "战神之锋",
			"type": &"general",
			"description": "轻攻击伤害 +25%"
		},
		{
			"id": &"blessing_013",
			"title": "战神之利",
			"type": &"general",
			"description": "重攻击伤害 +25%"
		},
		{
			"id": &"blessing_014",
			"title": "战神之瞩",
			"type": &"general",
			"description": "造成伤害 +25%，受到伤害 +15%"
		},
		{
			"id": &"blessing_015",
			"title": "懒惰之手",
			"type": &"general",
			"description": "连续 15 秒没有完成上菜时获得 5 金，可叠加"
		},
		{
			"id": &"blessing_016",
			"title": "古代复读机",
			"type": &"general",
			"description": "连续上菜的菜品相同，则本次收益 +4%，最多叠加 5 次"
		},
		{
			"id": &"blessing_017",
			"title": "多彩餐盘",
			"type": &"general",
			"description": "连续上菜的菜品不同，则本次收益 +3%，最多叠加 5 次"
		},
		{
			"id": &"blessing_018",
			"title": "虚空步伐",
			"type": &"general",
			"description": "穿越店门后移速 +35%，持续 3 秒；触发间隔 10 秒"
		},
		{
			"id": &"blessing_019",
			"title": "农耕血脉",
			"type": &"chi_baobao",
			"description": "采集完成时有 30% 概率额外获得 1 份同类食材"
		},
		{
			"id": &"blessing_020",
			"title": "热情好客",
			"type": &"chi_baobao",
			"description": "客人点单时有 35% 概率使本次点单动作时间减少 50%"
		},
		{
			"id": &"blessing_021",
			"title": "异界来客的威压",
			"type": &"chi_baobao",
			"description": "对非 BOSS 目标造成攻击时有 5% 概率直接击杀"
		},
		{
			"id": &"blessing_022",
			"title": "欢迎光临",
			"type": &"chi_baobao",
			"description": "玩家位于料理区时移动速度 +25%"
		},
		{
			"id": &"blessing_023",
			"title": "热盘快递",
			"type": &"general",
			"description": "拿着完成菜品时移动速度 +20%。"
		},
		{
			"id": &"blessing_024",
			"title": "满意加餐",
			"type": &"general",
			"description": "连续两次上菜都完全符合订单要求时，第二次上菜收益 +10%。"
		},
		{
			"id": &"blessing_025",
			"title": "余温回馈",
			"type": &"general",
			"description": "上菜时若菜品熟成度完全符合订单，获得 3 秒移速 +25%。"
		},
		{
			"id": &"blessing_026",
			"title": "空盘回程",
			"type": &"general",
			"description": "成功上菜后移速 +25%，持续 3 秒。"
		},
		{
			"id": &"blessing_027",
			"title": "组合巧手",
			"type": &"general",
			"description": "组合成功后，玩家操作切台或研磨台时工作效率 +25%，持续 6 秒。"
		},
		{
			"id": &"blessing_028",
			"title": "不浪费",
			"type": &"general",
			"description": "组合失败产出垃圾时，产出本次投入的最后一份食材。"
		},
		{
			"id": &"blessing_029",
			"title": "预备动作",
			"type": &"general",
			"description": "手持未加工食材时移动速度 +15%，手持半成品时移动速度 +10%。"
		},
		{
			"id": &"blessing_030",
			"title": "配方记忆",
			"type": &"general",
			"description": "连续组合出相同菜品时，随机返还其中 1 份随机非酒水食材。"
		},
		{
			"id": &"blessing_031",
			"title": "归位本能",
			"type": &"general",
			"description": "从切台或研磨台取出完成食材后，玩家工作效率 +20%，持续 4 秒。"
		},
		{
			"id": &"blessing_032",
			"title": "盘点时间",
			"type": &"general",
			"description": "从储存箱取出食材时有 15% 概率不消耗库存；触发后有15秒冷却时间"
		},
		{
			"id": &"blessing_033",
			"title": "半成品快递",
			"type": &"general",
			"description": "手持已加工但尚未组合的食材时移动速度 +15%。"
		},
		{
			"id": &"blessing_034",
			"title": "稳步作业",
			"type": &"general",
			"description": "连续站定 1 秒后，切菜与研磨效率提高 15%。"
		},
		{
			"id": &"blessing_035",
			"title": "流水线意识",
			"type": &"general",
			"description": "2格内有两台料理台正在工作时，玩家工作效率 +15%。"
		},
		{
			"id": &"blessing_036",
			"title": "台面余裕",
			"type": &"general",
			"description": "玩家完成一次切割或研磨后，移动速度 +20%，持续 3 秒。"
		},
		{
			"id": &"blessing_037",
			"title": "设施亲和",
			"type": &"general",
			"description": "搬起设施时移动速度惩罚降低 50%。"
		},
		{
			"id": &"blessing_038",
			"title": "备料熟手",
			"type": &"general",
			"description": "切菜与研磨效率提高 10%。"
		},
		{
			"id": &"blessing_039",
			"title": "刀口清亮",
			"type": &"general",
			"description": "切割的工作效率+ 33%"
		},
		{
			"id": &"blessing_040",
			"title": "节奏刀法",
			"type": &"general",
			"description": "切割时每连续正确按下 3 次交互键，第 3 次额外计作 1 次切割进度。"
		},
		{
			"id": &"blessing_041",
			"title": "趁热出锅",
			"type": &"general",
			"description": "从烤架取出完成食材后，手持移速 +35%，持续 3 秒。"
		},
		{
			"id": &"blessing_042",
			"title": "研磨回弹",
			"type": &"general",
			"description": "完成一次研磨后的 6 秒内开始下一次研磨，该食材从 30% 进度开始。"
		},
		{
			"id": &"blessing_043",
			"title": "粗磨起步",
			"type": &"general",
			"description": "研磨台上的食材达到粗磨后，后续研磨工作效率 +25%。"
		},
		{
			"id": &"blessing_044",
			"title": "刀磨同心",
			"type": &"general",
			"description": "完成切割或研磨后 8 秒内，操作另一种料理台时工作效率 +30%。"
		},
		{
			"id": &"blessing_045",
			"title": "手不停歇",
			"type": &"general",
			"description": "完成一次切割或研磨后 5 秒内继续操作任意手动料理台，工作效率 +20%。"
		},
		{
			"id": &"blessing_046",
			"title": "需求预判",
			"type": &"general",
			"description": "接取订单后，该订单要求的所有手动加工操作工作效率 +15%。"
		},
		{
			"id": &"blessing_047",
			"title": "开门红",
			"type": &"general",
			"description": "每日前三位客人的订单等待上菜时间 +20%，且完成后收益 +10%。"
		},
		{
			"id": &"blessing_048",
			"title": "耐心招待",
			"type": &"general",
			"description": "客人点单完成后，该客人的等待上菜时间额外增加 8%。"
		},
		{
			"id": &"blessing_049",
			"title": "及时回应",
			"type": &"general",
			"description": "玩家在客人点单提示出现后 3 秒内开始点单，获得 +40% 移速，持续 4 秒。"
		},
		{
			"id": &"blessing_050",
			"title": "快速响应",
			"type": &"general",
			"description": "在点单提示出现后 3 秒内接取订单，该订单等待上菜时间 +15%。"
		},
		{
			"id": &"blessing_051",
			"title": "多桌调度",
			"type": &"general",
			"description": "同时有两个或以上客人等待点单时，玩家移速 +15%。"
		},
		{
			"id": &"blessing_052",
			"title": "清台有方",
			"type": &"general",
			"description": "完成一位客人的全部订单后，其他正在等待上菜的客人恢复 5% 耐心。"
		},
		{
			"id": &"blessing_053",
			"title": "越忙越稳",
			"type": &"general",
			"description": "同时存在两个或以上已接取订单时，玩家工作效率 +15%。"
		},
		{
			"id": &"blessing_054",
			"title": "轻刃回响",
			"type": &"general",
			"description": "连续轻攻击命中同一目标时，每次伤害 +5%，最多叠加 3 层；攻击其他目标或 2 秒未命中后清除。"
		},
		{
			"id": &"blessing_055",
			"title": "重击蓄势",
			"type": &"general",
			"description": "重攻击整个蓄力期间受到伤害降低 20%，释放或取消蓄力后失效。"
		},
		{
			"id": &"blessing_056",
			"title": "满弦重击",
			"type": &"general",
			"description": "重攻击蓄力完成后，攻击范围 +15%。"
		},
		{
			"id": &"blessing_057",
			"title": "近身回报",
			"type": &"general",
			"description": "轻攻击命中近距离敌人时，恢复最大生命 2%；每 3 秒最多触发一次。"
		},
		{
			"id": &"blessing_058",
			"title": "击杀冲锋",
			"type": &"general",
			"description": "击杀敌人后冲刺冷却立即减少 25%；每 5 秒最多触发一次。"
		},
		{
			"id": &"blessing_059",
			"title": "连斩余势",
			"type": &"general",
			"description": "5 秒内连续击杀 2 个单位后，攻击力 +20%，持续 5 秒。"
		},
		{
			"id": &"blessing_060",
			"title": "狩猎路线",
			"type": &"general",
			"description": "在战斗区中心范围内击杀敌人时，掉落物吸引范围 +30%。"
		},
		{
			"id": &"blessing_061",
			"title": "弹幕预感",
			"type": &"general",
			"description": "敌人弹幕预警出现时，玩家移速 +20%，持续至预警结束。"
		},
		{
			"id": &"blessing_062",
			"title": "弹幕回避",
			"type": &"general",
			"description": "成功躲过弹幕后，下一次轻攻击伤害 +30%。"
		},
		{
			"id": &"blessing_063",
			"title": "破甲余波",
			"type": &"general",
			"description": "对精英或 BOSS 造成重击后，其下一次受到的伤害 +15%。"
		},
		{
			"id": &"blessing_064",
			"title": "非首领猎手",
			"type": &"general",
			"description": "对非 BOSS 敌人的伤害 +20%，对 BOSS 伤害 -10%。"
		},
		{
			"id": &"blessing_065",
			"title": "首领挑战",
			"type": &"general",
			"description": "对 BOSS 伤害 +20%，对非 BOSS 伤害 -10%。"
		},
		{
			"id": &"blessing_066",
			"title": "冲刺余速",
			"type": &"general",
			"description": "冲刺结束后移速 +25%，持续 2 秒。"
		},
		{
			"id": &"blessing_067",
			"title": "冲锋余威",
			"type": &"general",
			"description": "冲刺结束后，下一次攻击伤害 +20%；3 秒内未攻击则失效。"
		},
		{
			"id": &"blessing_068",
			"title": "节奏冲刺",
			"type": &"general",
			"description": "连续移动超过 1 秒后，下一次冲刺距离 +20%。"
		},
		{
			"id": &"blessing_069",
			"title": "临界闪身",
			"type": &"general",
			"description": "生命低于 35% 时，冲刺冷却恢复速度 +25%。"
		},
		{
			"id": &"blessing_070",
			"title": "一线生机",
			"type": &"general",
			"description": "每天第一次生命降至 0 时，保留 1 点生命并获得 1 秒无敌。"
		},
		{
			"id": &"blessing_071",
			"title": "回光返照",
			"type": &"general",
			"description": "复活后 8 秒内移速与工作效率 +25%。"
		},
		{
			"id": &"blessing_072",
			"title": "魔力回响",
			"type": &"general",
			"description": "消耗魔力后，有 25% 概率返还 1 点魔力；每 6 秒最多触发一次。"
		},
		{
			"id": &"blessing_073",
			"title": "节约施法",
			"type": &"general",
			"description": "技能消耗魔力低于 3 点时，技能效果持续时间 +25%。"
		},
		{
			"id": &"blessing_074",
			"title": "满溢魔力",
			"type": &"general",
			"description": "魔力满值时，工作效率与攻击力 +25%；魔力不满时失效。"
		},
		{
			"id": &"blessing_075",
			"title": "紧急供能",
			"type": &"general",
			"description": "魔力低于 25% 时，移速 +20%，但技能冷却恢复速度 -10%。"
		},
		{
			"id": &"blessing_076",
			"title": "共享节拍",
			"type": &"general",
			"description": "队友或其他玩家消耗魔力后，自己获得 +15% 移速，持续 3 秒。"
		},
		{
			"id": &"blessing_077",
			"title": "余量管理",
			"type": &"general",
			"description": "每日营业结束时，每剩余 1 点魔力获得 2 金。"
		},
		{
			"id": &"blessing_078",
			"title": "今日大吉",
			"type": &"chi_baobao",
			"description": "每天开始时，随机获得总攻击力、总工作效率或总移动速度 +20%，持续至当天结束。"
		},
		{
			"id": &"blessing_079",
			"title": "多切一刀",
			"type": &"chi_baobao",
			"description": "每次推进切割时有 20% 概率额外计作 1 次切割进度。"
		},
		{
			"id": &"blessing_080",
			"title": "石臼彩头",
			"type": &"chi_baobao",
			"description": "每份食材首次开始研磨时，有 40% 概率立即获得 40% 研磨进度。"
		},
		{
			"id": &"blessing_081",
			"title": "火候偏爱",
			"type": &"chi_baobao",
			"description": "食材放上烤台时有 40% 概率使其微生、半熟阶段的持续时间延长 50%；全熟至焦糊的时间不变。"
		},
		{
			"id": &"blessing_082",
			"title": "配方赠品",
			"type": &"chi_baobao",
			"description": "成功组合菜品时有 20% 概率返还其中 1 份随机非酒水食材。"
		},
		{
			"id": &"blessing_083",
			"title": "幸运预约",
			"type": &"chi_baobao",
			"description": "客人出现时有 30% 概率使其等待点单的耐心上限增加 50%。"
		},
		{
			"id": &"blessing_084",
			"title": "天降小费",
			"type": &"chi_baobao",
			"description": "完全符合订单要求地上菜时，有 25% 概率使本次金币和经验收益增加 40%。"
		},
		{
			"id": &"blessing_085",
			"title": "幸运一击",
			"type": &"chi_baobao",
			"description": "普通攻击命中时有 15% 概率造成双倍伤害。"
		},
		{
			"id": &"blessing_086",
			"title": "冲刺返券",
			"type": &"chi_baobao",
			"description": "冲刺时有 25% 概率使本次冲刺冷却减少 60%。"
		},
		{
			"id": &"blessing_087",
			"title": "魔力免单",
			"type": &"chi_baobao",
			"description": "成功消耗魔力后有 20% 概率全额返还本次消耗；释放前仍须拥有足够魔力。"
		}
	]

static func get_definition(blessing_id: StringName) -> Dictionary:
	for blessing_data in create_default_blessings():
		if StringName(blessing_data.get("id", &"")) == blessing_id:
			return blessing_data
	return {}

static func is_valid_id(blessing_id: StringName) -> bool:
	return not get_definition(blessing_id).is_empty()

static func get_id_by_title(title: String) -> StringName:
	for blessing_data in create_default_blessings():
		if String(blessing_data.get("title", "")) == title:
			return StringName(blessing_data.get("id", &""))
	return &""
