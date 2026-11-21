extends RefCounted

const Energy = preload("res://Scripts/Player/UltimateEnergyRules.gd")
const SmallSkill = preload("res://Scripts/Player/PlayerSmallSkillController.gd")
const BigSkill = preload("res://Scripts/Player/PlayerBigSkillController.gd")
const Field = preload("res://Scripts/Player/SmallSkillField.gd")
const TestItemDefs = preload("res://Scripts/Kitchen/TestItemDefs.gd")
const SMALL_SKILL_KEY_LABEL := "U"
const BIG_SKILL_KEY_LABEL := "I"

var player: CharacterBody2D
var small: RefCounted
var big: RefCounted
var ultimate_energy: float = 0.0
var cooldown_haste_multiplier: float = 1.0
var work_efficiency_multiplier: float = 1.0
var skill_power_multiplier: float = 1.0

func setup(new_player: CharacterBody2D, config: Dictionary = {}) -> void:
	player = new_player
	small = SmallSkill.new()
	small.setup(player, config)
	big = BigSkill.new()
	big.setup(player, config)

func tick(delta: float) -> void:
	if not player.is_skill_gameplay_active():
		return
	var cooldown_rate: float = 1.0
	var blessing_runtime: RefCounted = player.get_blessing_controller()
	if blessing_runtime != null:
		cooldown_rate = blessing_runtime.get_skill_cooldown_rate_multiplier()
	small.tick(delta, cooldown_rate)
	big.tick(delta)
	add_energy(Energy.PASSIVE_PER_SECOND * maxf(delta, 0.0))

func add_energy(amount: float) -> void:
	ultimate_energy = clampf(ultimate_energy + maxf(amount, 0.0), 0.0, Energy.CAPACITY)

func try_activate_small() -> bool:
	if player.is_downed():
		return false
	return small.try_activate(cooldown_haste_multiplier)

func set_small_variant(id: StringName) -> void:
	small.set_variant(id)

func set_big_variant(id: StringName) -> void:
	big.set_variant(id)

func get_big_variant_id() -> StringName:
	return big.variant_id

func try_activate_big() -> bool:
	if not player.is_skill_gameplay_active() or ultimate_energy < Energy.CAPACITY:
		return false
	if not big.try_activate():
		return false
	ultimate_energy = 0.0
	return true

func get_move_speed_multiplier() -> float:
	return 1.0 + maxf(small.get_personal_bonus(), Field.get_movement_bonus(player))

func get_cook_progress_multiplier() -> float:
	return get_work_progress_multiplier()

func get_work_progress_multiplier() -> float:
	return work_efficiency_multiplier * big.get_work_multiplier()

func get_facility_work_multiplier(target: Node2D) -> float:
	return big.get_facility_work_multiplier(target) if big != null and big.has_method("get_facility_work_multiplier") else 1.0

func consume_instant_work(process_state: StringName = &"", station_state: StringName = &"", payload: Dictionary = {}) -> bool:
	var event: StringName = &"cut"
	if TestItemDefs.get_process_family(station_state) == &"grind":
		event = &"grind_fine" if TestItemDefs.normalize_process_state(process_state) == TestItemDefs.PROCESS_STATE_GRIND_COARSE else &"grind_coarse"
	elif process_state in [&"order", &"wash", &"cut", &"collect", &"repair"]:
		event = process_state
	return big.try_instant_work(event, payload)

func on_work_completed(event: StringName) -> void:
	small.on_work_completed(event)
	big.on_work_completed(event)

func is_control_immune() -> bool:
	return big.is_control_immune()

func apply_forged_attribute(option: Dictionary) -> void:
	match StringName(option.get("attribute_id", &"")):
		&"work_efficiency":
			work_efficiency_multiplier *= (1.0 + float(option.get("fixed", 0.0)) / 100.0) * (1.0 + float(option.get("total_work", 0.0)))
		&"cooldown_haste":
			cooldown_haste_multiplier *= float(option.get("skill_cooldown_multiplier", 1.0)) / maxf(1.0 + float(option.get("fixed", 0.0)) / 100.0, 0.01)
		&"skill_power":
			skill_power_multiplier *= (1.0 + float(option.get("fixed", 0.0)) / 100.0) * (1.0 + float(option.get("total_skill_power", 0.0)))

func reset_temporary_state() -> void:
	# Energy belongs to the run and survives day/night station resets.
	small.reset_temporary_state()
	big.reset_temporary_state()

func get_small_skill_progress() -> float:
	return clampf(1.0 - small.cooldown_remaining / maxf(small.cooldown_duration, 0.01), 0.0, 1.0)

func get_small_skill_remaining() -> float:
	return small.cooldown_remaining

func get_small_move_buff_progress() -> float:
	return clampf(1.0 - small.buff_remaining / maxf(small.buff_duration, 0.01), 0.0, 1.0)

func is_small_move_buff_active() -> bool:
	return get_move_speed_multiplier() > 1.0

func get_big_skill_progress() -> float:
	return ultimate_energy / Energy.CAPACITY

func get_big_skill_remaining() -> float:
	return big.remaining

func get_big_skill_buff_progress() -> float:
	return big.get_progress()

func is_big_skill_buff_active() -> bool:
	return big.remaining > 0.0
