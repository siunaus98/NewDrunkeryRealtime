extends RefCounted

const SmallSkillDefs = preload("res://Scripts/Player/SmallSkillDefs.gd")
const BigSkillDefs = preload("res://Scripts/Player/BigSkillDefs.gd")

const SMALL_KIND: StringName = &"small"
const BIG_KIND: StringName = &"big"

static func get_pool(kind: StringName, current_id: StringName) -> Array[Dictionary]:
	var source: Array[Dictionary] = SmallSkillDefs.get_options() if kind == SMALL_KIND else BigSkillDefs.get_options()
	var result: Array[Dictionary] = []
	for option: Dictionary in source:
		var option_id := StringName(option.get("id", &""))
		if option_id == current_id:
			continue
		# The base skill is the starting state, not an upgrade card.
		if kind == SMALL_KIND and option_id == SmallSkillDefs.BASE:
			continue
		if kind == BIG_KIND and option_id == BigSkillDefs.BASE:
			continue
		result.append(option.duplicate(true))
	return result

static func draw_three(kind: StringName, current_id: StringName, rng: RandomNumberGenerator = null) -> Array[Dictionary]:
	var pool := get_pool(kind, current_id)
	if rng == null:
		pool.shuffle()
	else:
		for i in range(pool.size() - 1, 0, -1):
			var j := rng.randi_range(0, i)
			var swap := pool[i]
			pool[i] = pool[j]
			pool[j] = swap
	var result: Array[Dictionary] = []
	for option in pool:
		if result.size() >= 3:
			break
		result.append(option)
	return result

static func draw_replacement(kind: StringName, current_id: StringName, excluded_ids: Array[StringName]) -> Dictionary:
	var pool := get_pool(kind, current_id)
	var excluded: Dictionary = {}
	for id in excluded_ids:
		excluded[id] = true
	pool = pool.filter(func(option: Dictionary) -> bool:
		return not excluded.has(StringName(option.get("id", &"")))
	)
	if pool.is_empty():
		return {}
	pool.shuffle()
	return pool[0]
