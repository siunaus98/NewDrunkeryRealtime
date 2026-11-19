extends RefCounted

const Defs = preload("res://Scripts/Progression/RunModifierDefs.gd")

var run_seed: int = 0
var offer_day: int = -1
var day_offers: Array[Dictionary] = []
var global_choices: Array[Dictionary] = []
var global_history: Array[Dictionary] = []
var global_multipliers: Dictionary = {}
var selected_day: Dictionary = {}
var selected_day_index: int = -1
var resolved_global_day: int = 0
var pending_forges: Array[StringName] = []
var settled_day: int = -1

func reset(seed_value: int = -1) -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	run_seed = rng.randi() if seed_value < 0 else seed_value
	offer_day = -1
	day_offers.clear()
	global_choices.clear()
	global_history.clear()
	global_multipliers.clear()
	selected_day.clear()
	selected_day_index = -1
	resolved_global_day = 0
	pending_forges.clear()
	settled_day = -1

func ensure_offers(day_index: int) -> void:
	if offer_day == day_index:
		return
	offer_day = day_index
	var rng := _rng(day_index, 11)
	day_offers = Defs.difficulty_offers(day_index, rng)
	global_choices.clear()
	if day_index > 0:
		global_choices = Defs.global_offers(_rng(day_index, 23))

func needs_global_choice(day_index: int) -> bool:
	return day_index > 0 and day_index <= 6 and resolved_global_day < day_index

func choose_global(index: int, day_index: int) -> Dictionary:
	ensure_offers(day_index)
	if not needs_global_choice(day_index) or index < 0 or index >= global_choices.size():
		return {}
	var buff := global_choices[index].duplicate(true)
	var debuff := Defs.random_debuff(int(buff.tier), _rng(day_index, 37), StringName(buff.key))
	var pair := {"day_index": day_index, "buff": buff, "debuff": debuff}
	global_history.append(pair)
	resolved_global_day = day_index
	_rebuild_multipliers()
	return pair.duplicate(true)

func choose_day(index: int, day_index: int) -> bool:
	ensure_offers(day_index)
	if index < 0 or index >= day_offers.size():
		return false
	selected_day = day_offers[index].duplicate(true)
	selected_day_index = day_index
	return true

func multiplier(key: StringName, day_index: int, include_day: bool = true) -> float:
	var result := float(global_multipliers.get(key, 1.0))
	if not include_day or selected_day_index != day_index:
		return result
	var debuff: Dictionary = selected_day.get("debuff", {})
	if StringName(debuff.get("key", &"")) == key:
		result *= float(debuff.get("multiplier", 1.0))
	if StringName(selected_day.get("reward", &"")) == key:
		result *= float(selected_day.get("reward_multiplier", 1.0))
	return result

func settle_success(day_index: int) -> void:
	if settled_day == day_index:
		return
	settled_day = day_index
	if selected_day_index == day_index and StringName(selected_day.get("reward", &"")) == &"forge":
		pending_forges.append([&"silver", &"gold", &"diamond"][clampi(int(selected_day.tier) - 1, 0, 2)])

func history_text() -> String:
	var lines: Array[String] = []
	for pair in global_history:
		lines.append("第%d夜：%s；代价：%s" % [int(pair.day_index), pair.buff.description, pair.debuff.description])
	return "\n".join(lines) if not lines.is_empty() else "尚未获得全局强化。"

func snapshot() -> Dictionary:
	return {"run_seed": run_seed, "offer_day": offer_day, "day_offers": day_offers.duplicate(true),
		"global_choices": global_choices.duplicate(true), "global_history": global_history.duplicate(true),
		"selected_day": selected_day.duplicate(true), "selected_day_index": selected_day_index,
		"resolved_global_day": resolved_global_day, "pending_forges": pending_forges.duplicate(), "settled_day": settled_day}

func restore(data: Dictionary) -> void:
	run_seed = int(data.get("run_seed", run_seed))
	offer_day = int(data.get("offer_day", -1))
	day_offers.assign(Array(data.get("day_offers", [])).duplicate(true))
	global_choices.assign(Array(data.get("global_choices", [])).duplicate(true))
	global_history.assign(Array(data.get("global_history", [])).duplicate(true))
	selected_day = Dictionary(data.get("selected_day", {})).duplicate(true)
	selected_day_index = int(data.get("selected_day_index", -1))
	resolved_global_day = int(data.get("resolved_global_day", 0))
	pending_forges.assign(data.get("pending_forges", []))
	settled_day = int(data.get("settled_day", -1))
	_rebuild_multipliers()

func _rng(day_index: int, salt: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%d:%d:%d" % [run_seed, day_index, salt])
	return rng

func _rebuild_multipliers() -> void:
	global_multipliers.clear()
	for pair in global_history:
		for entry: Dictionary in [pair.buff, pair.debuff]:
			var key := StringName(entry.key)
			global_multipliers[key] = float(global_multipliers.get(key, 1.0)) * float(entry.multiplier)
