extends RefCounted

const TITLES := {&"furnace": "炉火精灵", &"engraver": "刻碑师", &"porcelain": "瓷娃娃少女", &"gambler": "赌徒", &"merchant": "可疑游商", &"devil": "箱中魔鬼", &"sand_spirit": "沙灵", &"prankster": "恶作剧之神", &"repayment": "归来的游商"}
const OPENINGS := {
	&"furnace": "炉火里探出一张小脸。\n“带走一簇温顺的火，或者拿走那颗急性子的炉心？”",
	&"engraver": "刻碑师抹平了石板上的一行字。\n“先付钱，我再给你看三种新做法。旧的那一道，也得由你自己挑。”",
	&"porcelain": "少女轻叩净化池边的瓷盘。\n“多一只盘子，还是一双更利落的手？我只帮你选一边。”",
	&"gambler": "他把一枚护身符推到桌边。\n“买个安心，或者赌你明天不会让任何客人等急？”",
	&"repayment": "游商打开了沉甸甸的钱袋。\n“约好的日子到了。本金与利息，一分也不少。”"
	,
	&"merchant": "游商把金币在指间弹得叮当作响。\n“把钱交给我，等几天再取回来。你敢押哪一边？”",
	&"devil": "行李箱自己掀开一条缝。\n“生命、祝福，都是可以换成金币的东西。”",
	&"sand_spirit": "沙粒聚成一个小小的人影。\n“拿走一些积攒的东西，我会让接下来的日子轻松一点。”",
	&"prankster": "神灵从门框后探出半张笑脸。\n“我喜欢看人接受礼物之后，努力解释自己的选择。”"
}
const ENGRAVER_COST: int = 60
const CHARM_COST: int = 100
const PLATE_COST: int = 50

static func choices(id: StringName) -> Array[Dictionary]:
	match id:
		&"furnace":
			return [{"id": &"flame", "text": "取走火苗", "detail": "本局所有烤台加工速度 +10%。不改变焦糊计时。"},
				{"id": &"core", "text": "取走炉心", "detail": "本局所有烤台加工速度 +30%，焦糊速度 +50%（焦糊时间缩短至原来的 2/3）。"}]
		&"engraver":
			return [{"id": &"same", "text": "重刻旧方 · 60 金币", "detail": "先指定一道普通菜，再付费从同类别、同等级的新菜候选中选择。不能刷新。"},
				{"id": &"higher", "text": "学一道难菜 · 60 金币", "detail": "同类别、高一级的新菜候选中选择。先付款，不可退款、不能刷新。"},
				{"id": &"lower", "text": "换一道简菜 · 60 金币", "detail": "同类别、低一级的新菜候选中选择。先付款，不可退款、不能刷新。"}]
		&"porcelain":
			return [{"id": &"buy", "text": "买下瓷盘 · 50 金币", "detail": "本局盘子总数 +1，所有净化池清洗速度 -20%。"},
				{"id": &"sell", "text": "卖出瓷盘 · 获得 50 金币", "detail": "交出 1 只净盘，所有净化池清洗速度 +25%。全店至少保留 2 只盘子。"}]
		&"gambler":
			return [{"id": &"charm", "text": "买下护身符 · 100 金币", "detail": "本局每天免除首位普通或精英客人的全部声望损失。特殊客人不受影响。"},
				{"id": &"wager", "text": "与他打赌", "detail": "下一营业日不能有客人耐心归零（包括点单等待）。成功：护身符与 150 金币；失败：失去当日上菜金币收入的 50%。特殊客人不计入。"}]
		&"repayment":
			return [{"id": &"collect", "text": "收下本息", "detail": "取回约定金额后才能开始下一天营业。"}]
		&"merchant":
			return [{"id": &"half", "text": "交出一半金币", "detail": "两天后取回本金的 150%。"}, {"id": &"all", "text": "交出全部金币", "detail": "三天后取回本金的 300%。"}]
		&"devil":
			return [{"id": &"health", "text": "失去 20 点生命上限 · 获得 100 金币", "detail": "本局生命上限降低 20，立即获得 100 金币。"}, {"id": &"blessing", "text": "失去一个祝福 · 获得 160 金币", "detail": "随机失去一个祝福，立即获得 160 金币。"}, {"id": &"blessings", "text": "失去两个祝福 · 获得 280 金币", "detail": "随机失去两个祝福，立即获得 280 金币。"}]
		&"sand_spirit":
			return [{"id": &"patience", "text": "交出 10 份食材", "detail": "从已解锁食材箱随机扣除 10 份普通食材，普通与精英客人的耐心下降速度降低 15%。"}, {"id": &"grind", "text": "交出 20 份食材", "detail": "从已解锁食材箱随机扣除 20 份普通食材，此后研磨产量 +2。"}, {"id": &"aid", "text": "交出 30 份食材", "detail": "从已解锁食材箱随机扣除 30 份普通食材。本局进入战斗区时，沙灵随行；每 3 秒蓄力发动一次范围沙击，造成 150 伤害。"}]
		&"prankster":
			return chaos_choices(0)
	return []

static func chaos_choices(seed_value: int) -> Array[Dictionary]:
	var buffs: Array[Dictionary] = [
		{"key": &"gold", "text": "金币收益", "values": [1.15, 1.30, 1.50]}, {"key": &"xp", "text": "经验收益", "values": [1.15, 1.30, 1.50]},
		{"key": &"attack", "text": "攻击伤害", "values": [1.20, 1.40, 1.65]}, {"key": &"move", "text": "玩家移动速度", "values": [1.12, 1.24, 1.36]},
		{"key": &"work", "text": "手动工作速度", "values": [1.20, 1.40, 1.60]}, {"key": &"energy", "text": "大招能量获取", "values": [1.15, 1.30, 1.50]},
		{"key": &"patience_decay", "text": "客人耐心下降速度", "values": [0.90, 0.80, 0.65]},
		{"key": &"ordinary_drop", "text": "普通战斗食材掉落数量", "values": [1.20, 1.40, 1.60]}]
	var debuffs: Array[Dictionary] = [
		{"key": &"enemy_attack", "text": "敌人攻击力", "values": [1.40, 1.65, 1.90], "title": "凶敌的契约"}, {"key": &"enemy_move", "text": "敌人移动速度", "values": [1.18, 1.35, 1.55], "title": "躁动的沙丘"},
		{"key": &"attack", "text": "玩家攻击力", "values": [0.85, 0.70, 0.55], "title": "钝刃的代价"}, {"key": &"patience_decay", "text": "客人耐心下降速度", "values": [1.15, 1.30, 1.50], "title": "急客的契约"},
		{"key": &"reputation", "text": "声望损失", "values": [1.30, 1.55, 1.85], "title": "坏名声的预言"}, {"key": &"move", "text": "玩家移动速度", "values": [0.90, 0.80, 0.70], "title": "沉重的脚步"},
		{"key": &"work", "text": "手动工作速度", "values": [0.82, 0.65, 0.50], "title": "手忙脚乱"}]
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var result: Array[Dictionary] = []
	# Keep the three offers meaningfully different.  The buff/debuff pairing is
	# still random, but a single night should not show the same axis three times.
	var available_buffs: Array[Dictionary] = buffs.duplicate(true)
	var used_debuff_keys: Dictionary = {}
	var available_tiers: Array[int] = [1, 2, 3]
	for index in range(3):
		var buff_index: int = rng.randi_range(0, available_buffs.size() - 1)
		var buff: Dictionary = available_buffs[buff_index].duplicate(true)
		available_buffs.remove_at(buff_index)
		var available_debuffs: Array[Dictionary] = []
		for candidate: Dictionary in debuffs:
			if used_debuff_keys.has(candidate.key) or StringName(candidate.key) == StringName(buff.key):
				continue
			available_debuffs.append(candidate)
		# There are more debuff axes than offers, so this fallback is only a
		# defensive guard for future pool edits.
		if available_debuffs.is_empty():
			for candidate: Dictionary in debuffs:
				if StringName(candidate.key) != StringName(buff.key):
					available_debuffs.append(candidate)
		var debuff: Dictionary = available_debuffs[rng.randi_range(0, available_debuffs.size() - 1)].duplicate(true)
		used_debuff_keys[debuff.key] = true
		var tier_index: int = rng.randi_range(0, available_tiers.size() - 1)
		var tier: int = available_tiers[tier_index]
		available_tiers.remove_at(tier_index)
		buff["multiplier"] = float(buff.values[tier - 1])
		debuff["multiplier"] = float(debuff.values[tier - 1])
		result.append({"id": StringName("chaos_%d" % index), "text": "%s · %s强度" % [debuff.title, ["低", "中", "高"][tier - 1]], "detail": "本局永久：%s %s\n接下来三次营业：%s %s" % [buff.text, _percent(float(buff.multiplier)), debuff.text, _percent(float(debuff.multiplier))], "buff": buff, "debuff": debuff, "tier": tier})
	return result

static func _percent(multiplier: float) -> String:
	var amount: int = roundi((multiplier - 1.0) * 100.0)
	return "%s%d%%" % ["+" if amount >= 0 else "", amount]
