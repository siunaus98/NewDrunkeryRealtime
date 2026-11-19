extends RefCounted

const Defs = preload("res://Scripts/Player/BigSkillDefs.gd")
const Boost = preload("res://Scripts/Player/UltimateFacilityBoost.gd")
const WORK_EVENTS: Array[StringName] = [&"collect", &"cut", &"grind_coarse", &"grind_fine", &"order", &"wash", &"forage", &"serve", &"repair"]
const GRIND_TOKEN := "ultimate_grind_token"

var player: CharacterBody2D
var definition: Dictionary
var variant_id: StringName = Defs.BASE
var remaining: float = 0.0
var extension_used: float = 0.0
var charges: int = 0
var grind_free_tokens: Dictionary = {}
var grind_sequence: int = 0
var aura_origin: Vector2 = Vector2.ZERO
var boosted_facilities: Array[Node2D] = []
var base_config: Dictionary
var recovery_flash: float = 0.0

func setup(host: CharacterBody2D, config: Dictionary) -> void:
	player = host
	base_config = config.duplicate(true)
	set_variant(StringName(config.get("big_variant", Defs.BASE)))

func set_variant(id: StringName) -> void:
	reset_temporary_state()
	definition = Defs.get_definition(id)
	variant_id = StringName(definition.id)
	if variant_id == Defs.BASE:
		definition["duration"] = float(base_config.get("big_buff_duration", definition.duration))

func tick(delta: float) -> void:
	remaining = maxf(remaining - maxf(delta, 0.0), 0.0)
	var expired_tokens: Array[String] = []
	for token: String in grind_free_tokens.keys():
		var remaining_time := maxf(float(grind_free_tokens[token]) - maxf(delta, 0.0), 0.0)
		if remaining_time <= 0.0:
			expired_tokens.append(token)
		else:
			grind_free_tokens[token] = remaining_time
	for token: String in expired_tokens:
		grind_free_tokens.erase(token)
	recovery_flash = maxf(recovery_flash - maxf(delta, 0.0), 0.0)
	for effect: Node2D in boosted_facilities:
		if is_instance_valid(effect):
			effect.remaining = remaining
	if remaining <= 0.0:
		_end_buff()

func try_activate() -> bool:
	if remaining > 0.0:
		return false
	var target: Node2D
	if variant_id == Defs.SIGNATURE:
		target = _find_target_facility()
		if target == null:
			player.show_hint("面向附近的切台、磨台、烤台或酒桶后再按 I")
			return false
	remaining = float(definition.duration)
	extension_used = 0.0
	charges = int(definition.get("instant_work_charges", 0))
	grind_free_tokens.clear()
	if variant_id == Defs.AURA:
		aura_origin = player.global_position
		for station: Node in player.get_tree().get_nodes_in_group("pickup_drop_targets"):
			if Boost.is_eligible(station) and station.is_visible_in_tree() and station.global_position.distance_to(aura_origin) <= float(definition.facility_radius):
				_add_facility_boost(station)
	elif target != null:
		_add_facility_boost(target)
	if bool(definition.get("control_immunity", false)):
		player.clear_hostile_control()
	player.show_hint("%s · %d秒" % [definition.name, ceili(remaining)])
	return true

func get_work_multiplier() -> float:
	return float(definition.get("work_multiplier", 1.0)) if remaining > 0.0 else 1.0

func get_facility_work_multiplier(target: Node2D) -> float:
	return Boost.get_multiplier(target) if is_instance_valid(target) else 1.0

func is_control_immune() -> bool:
	return remaining > 0.0 and bool(definition.get("control_immunity", false))

func try_instant_work(event: StringName, payload: Dictionary = {}) -> bool:
	if remaining <= 0.0 or variant_id != Defs.INSTANT or event not in WORK_EVENTS or event == &"serve":
		return false
	# The grace token is written onto the coarse-grind item's payload.  This
	# keeps the free fine-grind follow-up attached to that exact ingredient when
	# the player moves it between a station, table, or plate.
	var token := String(payload.get(GRIND_TOKEN, ""))
	if event == &"grind_fine" and not token.is_empty() and grind_free_tokens.has(token) and float(grind_free_tokens[token]) > 0.0:
		grind_free_tokens.erase(token)
		payload.erase(GRIND_TOKEN)
		return true
	if charges <= 0:
		return false
	charges -= 1
	if event == &"grind_coarse":
		grind_sequence += 1
		var new_token := "%d:%d" % [player.get_instance_id(), grind_sequence]
		payload[GRIND_TOKEN] = new_token
		grind_free_tokens[new_token] = float(definition.get("grind_grace", 1.0))
	return true

func on_work_completed(event: StringName) -> void:
	if remaining <= 0.0 or event not in WORK_EVENTS:
		return
	if variant_id == Defs.EXTEND:
		var amount := minf(float(definition.extension_per_work), maxf(float(definition.max_extension) - extension_used, 0.0))
		extension_used += amount
		remaining += amount
	elif variant_id == Defs.RECOVERY:
		var reward: Dictionary = Defs.RECOVERY_REWARDS.get(event, {})
		var health_before: int = player.combat_controller.current_health
		player.heal_for_blessings(roundi(player.get_current_max_health() * float(reward.get("health_ratio", 0.0))))
		var magic_gain: int = player.adjust_skill_magic(int(reward.get("magic", 0)))
		if player.combat_controller.current_health > health_before or magic_gain > 0:
			recovery_flash = 0.5

func get_progress() -> float:
	return clampf(1.0 - remaining / maxf(float(definition.duration) + extension_used, 0.01), 0.0, 1.0)

func reset_temporary_state() -> void:
	_end_buff()
	extension_used = 0.0
	recovery_flash = 0.0

func _end_buff() -> void:
	remaining = 0.0
	charges = 0
	grind_free_tokens.clear()
	for effect: Node2D in boosted_facilities:
		if is_instance_valid(effect):
			effect.remaining = 0.0
			effect.queue_free()
	boosted_facilities.clear()

func _add_facility_boost(station: Node2D) -> void:
	boosted_facilities.append(Boost.attach(station, player, float(definition.facility_multiplier), remaining))

func _find_target_facility() -> Node2D:
	var origin: Vector2 = player.get_interaction_origin_world()
	var aim: Vector2 = player.get_aim_direction_world().normalized()
	var best: Node2D
	var best_distance := INF
	for station: Node in player.get_tree().get_nodes_in_group("pickup_drop_targets"):
		if not Boost.is_eligible(station) or station.is_in_group("plate_sinks") or not station.is_visible_in_tree():
			continue
		var point: Vector2 = player._get_facility_focus_point(station, origin)
		var offset: Vector2 = point - origin
		if offset.length() > player._get_facility_interaction_radius(station) or not player._can_damage_target_across_zones(point):
			continue
		if offset.length() > 0.01 and absf(aim.angle_to(offset)) > deg_to_rad(player.interaction_angle_degrees * 0.5):
			continue
		if offset.length() < best_distance:
			best = station
			best_distance = offset.length()
	return best

func draw_feedback() -> void:
	if remaining > 0.0 and variant_id == Defs.AURA:
		var center: Vector2 = player.to_local(aura_origin)
		player.draw_circle(center, float(definition.facility_radius), Color(1.0, 0.75, 0.2, 0.04))
		player.draw_arc(center, float(definition.facility_radius), 0.0, TAU, 64, Color(1.0, 0.78, 0.3, 0.7), 3.0, true)
	if remaining > 0.0 and variant_id == Defs.INSTANT:
		var text := "快手 ×%d" % charges
		player.draw_string_outline(ThemeDB.fallback_font, Vector2(-44, -145), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 23, 5, Color("413021"))
		player.draw_string(ThemeDB.fallback_font, Vector2(-44, -145), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 23, Color("fff0ab"))
	if recovery_flash > 0.0:
		player.draw_arc(Vector2(0, -35), 55, 0, TAU, 32, Color(0.35, 1.0, 0.65, recovery_flash * 2.0), 5, true)
