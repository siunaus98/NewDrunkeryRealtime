extends RefCounted

## Content and tuning only. Offers are generated once per night by RunModifierState.
const BUFFS := {
	&"gold": ["生意兴隆", "上菜金币收益", [0.15, 0.30, 0.45]],
	&"xp": ["声名远播", "上菜经验收益", [0.15, 0.30, 0.45]],
	&"work": ["熟能生巧", "手动工作速度", [0.10, 0.20, 0.30]],
	&"attack": ["磨砺锋刃", "玩家攻击力", [0.10, 0.20, 0.30]],
	&"move": ["脚下生风", "玩家移动速度", [0.05, 0.10, 0.15]]
}
const DEBUFFS := {
	&"enemy_move": ["躁动兽群", "敌人移动速度", [0.10, 0.20, 0.30]],
	&"enemy_attack": ["凶猛兽群", "敌人攻击伤害", [0.15, 0.30, 0.45]],
	&"patience": ["急性子客人", "普通与精英客人耐心总量", [-0.05, -0.10, -0.15]],
	&"reputation": ["苛刻评价", "客人造成的声望损失", [0.20, 0.40, 0.60]],
	&"move": ["沉重步伐", "玩家移动速度", [-0.04, -0.08, -0.12]],
	&"work": ["手忙脚乱", "手动工作速度", [-0.08, -0.16, -0.24]]
}

static func tier_name(tier: int) -> String:
	return ["低", "中", "高"][clampi(tier - 1, 0, 2)]

static func effect(key: StringName, tier: int, positive: bool) -> Dictionary:
	var row: Array = (BUFFS if positive else DEBUFFS)[key]
	var amount := float(row[2][clampi(tier - 1, 0, 2)])
	return {"key": key, "tier": tier, "title": row[0], "multiplier": 1.0 + amount,
		"description": "%s %s%d%%" % [row[1], "+" if amount > 0 else "", roundi(amount * 100)]}

static func shuffled(values: Array, rng: RandomNumberGenerator) -> Array:
	var result := values.duplicate(true)
	for index in range(result.size() - 1, 0, -1):
		var other := rng.randi_range(0, index)
		var temporary: Variant = result[index]
		result[index] = result[other]
		result[other] = temporary
	return result

static func global_offers(rng: RandomNumberGenerator) -> Array[Dictionary]:
	var keys := shuffled(BUFFS.keys(), rng)
	var tiers := shuffled([1, 2, 3], rng)
	var result: Array[Dictionary] = []
	for index in range(3):
		result.append(effect(StringName(keys[index]), int(tiers[index]), true))
	return result

static func random_debuff(tier: int, rng: RandomNumberGenerator, excluded_key: StringName = &"") -> Dictionary:
	# A reward never rolls its own direct opposite and cancels itself on selection.
	var keys := DEBUFFS.keys().filter(func(key: StringName) -> bool: return key != excluded_key)
	return effect(StringName(keys[rng.randi_range(0, keys.size() - 1)]), tier, false)

static func difficulty_offers(day_index: int, rng: RandomNumberGenerator) -> Array[Dictionary]:
	var basic := {"difficulty": 0, "tier": 0, "display_name": "简单 · 稳妥营业",
		"description": "基础收益，没有额外的当日难题。", "debuff": {}, "reward": &""}
	if day_index in [3, 6]:
		basic["display_name"] = "BOSS · 固定挑战"
		basic["description"] = "本日难度固定。击败 BOSS，完成特殊客人的订单即可通关。"
		return [basic]
	if day_index == 0:
		return [basic]
	var rewards := shuffled([&"gold", &"xp", &"forge"], rng)
	var result: Array[Dictionary] = [basic]
	for index in range(2):
		var tier := rng.randi_range(1, 2) if index == 0 else 3
		var reward := StringName(rewards[index])
		var debuff := random_debuff(tier, rng)
		var reward_text := ""
		var bonus: float = float([0.25, 0.50, 0.75][tier - 1])
		if reward == &"forge":
			reward_text = "通关后获得 1 个%s属性锻造器" % ["白银", "黄金", "钻石"][tier - 1]
		else:
			reward_text = "上菜%s收益 +%d%%" % ["金币" if reward == &"gold" else "经验", roundi(bonus * 100)]
		result.append({"difficulty": index + 1, "tier": tier, "reward": reward,
			"reward_multiplier": 1.0 + bonus, "debuff": debuff,
			"display_name": "%s · %s" % ["中等" if index == 0 else "困难", "属性锻造" if reward == &"forge" else ("金币丰收" if reward == &"gold" else "经验丰收")],
			"description": "%s\n\n仅限本日：%s" % [reward_text, debuff.description]})
	return result

static func apply_enemy(enemy: Node, multipliers: Dictionary) -> void:
	# Apply once after wave scaling, covering melee, projectiles and elite attacks.
	for property in enemy.get_property_list():
		var key := StringName(property.name)
		if key in [&"move_speed", &"dash_speed", &"rush_speed"]:
			enemy.set(key, float(enemy.get(key)) * float(multipliers.get(&"enemy_move", 1.0)))
		elif key in [&"contact_damage", &"dash_damage", &"slam_damage", &"lingering_hazard_damage", &"projectile_damage", &"bullet_damage", &"skill_damage", &"bite_damage"]:
			enemy.set(key, roundi(float(enemy.get(key)) * float(multipliers.get(&"enemy_attack", 1.0))))
