extends RefCounted

# Stateless player combat formulas. Runtime controllers own state and effects.

static func current_attack_damage(base_damage: int, bonus_damage: float, total_multiplier: float, attack_multiplier: float) -> int:
	return max(1, int(round((float(base_damage) + bonus_damage) * total_multiplier * attack_multiplier)))

static func current_max_health(base_health: int, bonus_health: int, total_multiplier: float, guardian_blessing: bool) -> int:
	var multiplier := total_multiplier * (1.15 if guardian_blessing else 1.0)
	return max(1, int(round(float(base_health + bonus_health) * multiplier)))

static func current_dash_cooldown(base_cooldown: float, cooldown_multiplier: float) -> float:
	return maxf(base_cooldown * cooldown_multiplier, 0.01)
