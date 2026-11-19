extends RefCounted

const FIRST_BATCH: Array[StringName] = [&"furnace", &"engraver", &"porcelain", &"gambler"]
const SECOND_BATCH: Array[StringName] = [&"merchant", &"devil", &"sand_spirit", &"prankster"]
# Temporary playtest: 1 = first batch, 2 = second batch, 3 = all eight NPC
# events at once, 0 = normal random event flow.
const PLAYTEST_BATCH: int = 3
const INITIAL_NIGHT_PLAYTEST: bool = PLAYTEST_BATCH == 1
const SECOND_NIGHT_PLAYTEST: bool = PLAYTEST_BATCH == 2
const ALL_EVENTS_PLAYTEST: bool = PLAYTEST_BATCH == 3

var night_index: int = -1
var event_id: StringName = &""
var resolved: bool = false
var history: Array[Dictionary] = []
var roast_speed: float = 1.0
var burn_speed: float = 1.0
var wash_speed: float = 1.0
var extra_plates: int = 0
var plate_allocations: Dictionary = {}
var protected_customer: String = ""
var daily_charm: bool = false
var charm_used_day: int = -1
var wager: Dictionary = {}
var investment: Dictionary = {}
var pending_notice: String = ""
var max_health_penalty: int = 0
var grind_yield_bonus: int = 0
var sand_spirit_aid: bool = false
var event_multipliers: Dictionary = {}
var temporary_debuff: Dictionary = {}
var temporary_debuff_until_day: int = -1

func reset() -> void:
	restore({})

func ensure_night(day: int, seed_value: int) -> void:
	if day == night_index:
		return
	night_index = day
	resolved = false
	event_id = &""
	if day < 1 or day > 6:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("night-event:%d:%d" % [seed_value, day])
	var candidates := FIRST_BATCH.duplicate()
	if day >= 1:
		candidates.append_array(SECOND_BATCH)
	if day != 1:
		candidates.erase(&"merchant")
	# A run should encounter the whole first batch before repeating it.
	for entry: Dictionary in history:
		candidates.erase(StringName(entry.id))
	if candidates.is_empty():
		candidates = FIRST_BATCH.duplicate()
	if daily_charm:
		candidates.erase(&"gambler")
	if candidates.is_empty():
		candidates = [&"furnace", &"engraver", &"porcelain"]
	event_id = candidates[rng.randi_range(0, candidates.size() - 1)]

func is_complete(id: StringName) -> bool:
	if id == event_id:
		return resolved
	for entry: Dictionary in history:
		if int(entry.day) == night_index and StringName(entry.id) == id:
			return true
	return false

func complete(option: StringName, description: String, id: StringName = &"") -> void:
	if id == &"":
		id = event_id
	if is_complete(id):
		return
	if id == event_id:
		resolved = true
	history.append({"day": night_index, "id": id, "option": option, "description": description})

func begin_investment(principal: int, long_term: bool, day: int) -> bool:
	if principal <= 0 or not investment.is_empty() or day != 1:
		return false
	investment = {"principal": principal, "due_day": 4 if long_term else 3,
		"payout": roundi(principal * (3.0 if long_term else 1.5))}
	return true

func investment_due(day: int) -> bool:
	return not investment.is_empty() and day >= int(investment.due_day)

func collect_investment(day: int) -> int:
	if not investment_due(day):
		return 0
	var amount := int(investment.payout)
	investment.clear()
	return amount

func get_event_multiplier(key: StringName, day: int, include_day: bool = true) -> float:
	var result: float = float(event_multipliers.get(key, 1.0))
	if include_day and day <= temporary_debuff_until_day:
		var debuff_key := StringName(temporary_debuff.get("key", &""))
		if debuff_key == key:
			result *= float(temporary_debuff.get("multiplier", 1.0))
	return result

func apply_multiplier(key: StringName, multiplier: float) -> void:
	event_multipliers[key] = float(event_multipliers.get(key, 1.0)) * multiplier

func apply_chaos(choice: Dictionary, day: int) -> void:
	var buff: Dictionary = choice.get("buff", {})
	apply_multiplier(StringName(buff.key), float(buff.multiplier))
	temporary_debuff = Dictionary(choice.get("debuff", {})).duplicate(true)
	# day is the upcoming zero-based service index, not the completed day.
	temporary_debuff_until_day = day + 2

func apply_devil(option_id: StringName) -> void:
	match option_id:
		&"health": max_health_penalty += 20
		&"blessing": pass
		&"blessings": pass

func apply_sand_spirit(option_id: StringName) -> void:
	match option_id:
		&"patience": apply_multiplier(&"patience_decay", 0.85)
		&"grind": grind_yield_bonus += 2
		&"aid": sand_spirit_aid = true

func begin_wager(day: int) -> void:
	wager = {"day": day, "failed": false, "income": 0, "settled": false}

func record_income(day: int, amount: int) -> void:
	if int(wager.get("day", -1)) == day and not bool(wager.get("settled", false)):
		wager.income = int(wager.income) + maxi(amount, 0)

func on_customer_expired(day: int, customer_id: String) -> bool:
	if int(wager.get("day", -1)) == day:
		wager["failed"] = true
	if daily_charm and charm_used_day == day and protected_customer == customer_id:
		return true
	if not daily_charm or charm_used_day == day or customer_id.is_empty():
		return false
	charm_used_day = day
	protected_customer = customer_id
	return true

func settle_wager(day: int) -> int:
	if int(wager.get("day", -1)) != day or bool(wager.get("settled", false)):
		return 0
	wager["settled"] = true
	if bool(wager.failed):
		var loss := roundi(int(wager.income) * 0.5)
		pending_notice = "赌约失败：本日上菜收入的一半（%d 金币）已交给赌徒。" % loss
		return -loss
	daily_charm = true
	pending_notice = "赌约成功！获得护身符与 150 金币。此后每天免除首位普通或精英客人的声望损失。"
	return 150

func snapshot() -> Dictionary:
	return {"night_index": night_index, "event_id": event_id, "resolved": resolved, "history": history.duplicate(true),
		"roast_speed": roast_speed, "burn_speed": burn_speed, "wash_speed": wash_speed, "extra_plates": extra_plates,
		"plate_allocations": plate_allocations.duplicate(), "protected_customer": protected_customer,
		"daily_charm": daily_charm, "charm_used_day": charm_used_day, "wager": wager.duplicate(true),
		"investment": investment.duplicate(true), "pending_notice": pending_notice,
		"max_health_penalty": max_health_penalty, "grind_yield_bonus": grind_yield_bonus,
		"sand_spirit_aid": sand_spirit_aid, "event_multipliers": event_multipliers.duplicate(true),
		"temporary_debuff": temporary_debuff.duplicate(true), "temporary_debuff_until_day": temporary_debuff_until_day}

func restore(data: Dictionary) -> void:
	night_index = int(data.get("night_index", -1))
	event_id = StringName(data.get("event_id", &""))
	resolved = bool(data.get("resolved", false))
	history.assign(Array(data.get("history", [])).duplicate(true))
	roast_speed = float(data.get("roast_speed", 1.0))
	burn_speed = float(data.get("burn_speed", 1.0))
	wash_speed = float(data.get("wash_speed", 1.0))
	extra_plates = int(data.get("extra_plates", 0))
	plate_allocations = Dictionary(data.get("plate_allocations", {})).duplicate()
	protected_customer = String(data.get("protected_customer", ""))
	daily_charm = bool(data.get("daily_charm", false))
	charm_used_day = int(data.get("charm_used_day", -1))
	wager = Dictionary(data.get("wager", {})).duplicate(true)
	investment = Dictionary(data.get("investment", {})).duplicate(true)
	pending_notice = String(data.get("pending_notice", ""))
	max_health_penalty = int(data.get("max_health_penalty", 0))
	grind_yield_bonus = int(data.get("grind_yield_bonus", 0))
	sand_spirit_aid = bool(data.get("sand_spirit_aid", false))
	event_multipliers = Dictionary(data.get("event_multipliers", {})).duplicate(true)
	temporary_debuff = Dictionary(data.get("temporary_debuff", {})).duplicate(true)
	temporary_debuff_until_day = int(data.get("temporary_debuff_until_day", -1))
