extends RefCounted

const AudioCue = preload("res://Scripts/Audio/AudioCue.gd")

var player: CharacterBody2D
const PlayerAttackTargetQuery = preload("res://Scripts/Player/PlayerAttackTargetQuery.gd")
const PlayerCombatMath = preload("res://Scripts/Player/PlayerCombatMath.gd")
var sprite: Sprite2D
var attack_visualizer: Node2D
var dash_cooldown_indicator: Node2D
var health_label: Label

var max_health_base: int = 100
var move_speed_base: float = 420.0
var attack_damage_base: int = 100
var attack_origin_offset: Vector2 = Vector2(0, -34)
var attack_inner_radius: float = 42.0
var attack_outer_radius: float = 145.0
var attack_angle_degrees: float = 82.0
var attack_cooldown: float = 0.18
var light_attack_release_window: float = 0.22
var light_attack_damage_multiplier: float = 0.65
var light_attack_auto_aim_angle_degrees: float = 220.0
var light_attack_close_auto_aim_radius: float = 104.0
var heavy_charge_full_duration: float = 0.85
var heavy_charge_overhold_duration: float = 0.8
var heavy_charge_move_slow_min: float = 0.82
var heavy_charge_move_slow_max: float = 0.42
var heavy_damage_multiplier_min: float = 1.25
var heavy_damage_multiplier_max: float = 2.2
var attack_snap_input_grace_duration: float = 0.12
var attack_auto_aim_angle_degrees: float = 150.0
var dash_duration: float = 0.16
var dash_cooldown: float = 0.9
var contact_immunity_duration: float = 0.32

var current_health: int = 0
var attack_cooldown_remaining: float = 0.0
var attack_hold_time: float = 0.0
var attack_hold_aim_direction: Vector2 = Vector2.RIGHT
var attack_last_input_direction: Vector2 = Vector2.RIGHT
var attack_input_grace_remaining: float = 0.0
var is_attack_button_held: bool = false
var is_heavy_charging: bool = false
var heavy_overhold_remaining: float = 0.0
var dash_cooldown_remaining: float = 0.0
var dash_time_remaining: float = 0.0
var contact_immunity_remaining: float = 0.0
var dash_direction: Vector2 = Vector2.RIGHT
var move_speed_multiplier: float = 1.0
var attack_damage_multiplier: float = 1.0
var dash_cooldown_multiplier: float = 1.0
var bonus_max_health: int = 0
var event_max_health_penalty: int = 0
var bonus_attack_damage: float = 0.0
var total_attack_multiplier: float = 1.0
var total_health_multiplier: float = 1.0
var bonus_armor: float = 0.0
var bonus_health_regen: float = 0.0
var percent_health_regen: float = 0.0
var bonus_lifesteal: float = 0.0
var health_regen_remainder: float = 0.0
var total_move_speed_multiplier: float = 1.0
var total_damage_reduction: float = 0.0
var hit_feedback_tween: Tween
var base_sprite_position: Vector2 = Vector2.ZERO
var base_sprite_scale: Vector2 = Vector2.ONE
var blessing_controller: RefCounted

func setup(
	new_player: CharacterBody2D,
	new_sprite: Sprite2D,
	new_attack_visualizer: Node2D,
	new_dash_cooldown_indicator: Node2D,
	new_health_label: Label,
	config: Dictionary
) -> void:
	player = new_player
	sprite = new_sprite
	attack_visualizer = new_attack_visualizer
	dash_cooldown_indicator = new_dash_cooldown_indicator
	health_label = new_health_label

	max_health_base = int(config.get("max_health", max_health_base))
	move_speed_base = float(config.get("move_speed", move_speed_base))
	attack_damage_base = int(config.get("attack_damage", attack_damage_base))
	attack_origin_offset = config.get("attack_origin_offset", attack_origin_offset)
	attack_inner_radius = float(config.get("attack_inner_radius", attack_inner_radius))
	attack_outer_radius = float(config.get("attack_outer_radius", attack_outer_radius))
	attack_angle_degrees = float(config.get("attack_angle_degrees", attack_angle_degrees))
	attack_cooldown = float(config.get("attack_cooldown", attack_cooldown))
	light_attack_release_window = float(config.get("light_attack_release_window", light_attack_release_window))
	light_attack_damage_multiplier = float(config.get("light_attack_damage_multiplier", light_attack_damage_multiplier))
	light_attack_auto_aim_angle_degrees = float(config.get("light_attack_auto_aim_angle_degrees", light_attack_auto_aim_angle_degrees))
	light_attack_close_auto_aim_radius = float(config.get("light_attack_close_auto_aim_radius", light_attack_close_auto_aim_radius))
	heavy_charge_full_duration = float(config.get("heavy_charge_full_duration", heavy_charge_full_duration))
	heavy_charge_overhold_duration = float(config.get("heavy_charge_overhold_duration", heavy_charge_overhold_duration))
	heavy_charge_move_slow_min = float(config.get("heavy_charge_move_slow_min", heavy_charge_move_slow_min))
	heavy_charge_move_slow_max = float(config.get("heavy_charge_move_slow_max", heavy_charge_move_slow_max))
	heavy_damage_multiplier_min = float(config.get("heavy_damage_multiplier_min", heavy_damage_multiplier_min))
	heavy_damage_multiplier_max = float(config.get("heavy_damage_multiplier_max", heavy_damage_multiplier_max))
	attack_snap_input_grace_duration = float(config.get("attack_snap_input_grace_duration", attack_snap_input_grace_duration))
	attack_auto_aim_angle_degrees = float(config.get("attack_auto_aim_angle_degrees", attack_auto_aim_angle_degrees))
	dash_duration = float(config.get("dash_duration", dash_duration))
	dash_cooldown = float(config.get("dash_cooldown", dash_cooldown))
	contact_immunity_duration = float(config.get("contact_immunity_duration", contact_immunity_duration))
	if sprite != null:
		base_sprite_position = sprite.position
		base_sprite_scale = sprite.scale

	current_health = get_current_max_health()
	_update_health_label()

func tick_cooldowns(delta: float, input_direction: Vector2 = Vector2.ZERO) -> void:
	attack_cooldown_remaining = maxf(attack_cooldown_remaining - delta, 0.0)
	var dash_rate: float = float(blessing_controller.get_dash_cooldown_rate_multiplier()) if blessing_controller != null else 1.0
	dash_cooldown_remaining = maxf(dash_cooldown_remaining - delta * dash_rate, 0.0)
	dash_time_remaining = maxf(dash_time_remaining - delta, 0.0)
	contact_immunity_remaining = maxf(contact_immunity_remaining - delta, 0.0)
	if (bonus_health_regen > 0.0 or percent_health_regen > 0.0) and current_health > 0:
		var regen_multiplier: float = float(blessing_controller.get_health_regen_multiplier()) if blessing_controller != null else 1.0
		health_regen_remainder += (bonus_health_regen + float(get_current_max_health()) * percent_health_regen) * regen_multiplier * delta
		var regen_amount := int(floor(health_regen_remainder))
		if regen_amount > 0:
			current_health = mini(current_health + regen_amount, get_current_max_health())
			health_regen_remainder -= regen_amount
			_update_health_label()
	_update_attack_input_memory(input_direction, delta)
	if is_attack_button_held:
		attack_hold_time += delta
		attack_hold_aim_direction = _resolve_attack_direction(attack_hold_aim_direction)
		if attack_hold_time > light_attack_release_window:
			is_heavy_charging = true
		if is_heavy_charging:
			var charge_ratio := get_heavy_charge_ratio()
			_show_charge_preview(attack_hold_aim_direction, charge_ratio)
			if is_heavy_charge_full():
				heavy_overhold_remaining = maxf(heavy_overhold_remaining - delta, 0.0)
				if heavy_overhold_remaining <= 0.0:
					cancel_attack_charge(false)

func begin_attack_hold(aim_direction: Vector2 = Vector2.RIGHT, input_direction: Vector2 = Vector2.ZERO) -> bool:
	if attack_cooldown_remaining > 0.0:
		return false
	if dash_time_remaining > 0.0:
		return false
	_update_attack_input_memory(input_direction, 0.0)
	is_attack_button_held = true
	is_heavy_charging = false
	attack_hold_time = 0.0
	attack_hold_aim_direction = _resolve_attack_direction(aim_direction)
	heavy_overhold_remaining = heavy_charge_overhold_duration
	return true

func release_attack_hold(aim_direction: Vector2, can_damage_target_across_zones: Callable, input_direction: Vector2 = Vector2.ZERO) -> bool:
	if not is_attack_button_held:
		return false
	_update_attack_input_memory(input_direction, 0.0)
	var held_long_enough_for_heavy := is_heavy_charging or attack_hold_time > light_attack_release_window
	var charge_ratio := get_heavy_charge_ratio()
	var release_direction := _resolve_attack_direction(aim_direction)
	_reset_attack_hold()
	if held_long_enough_for_heavy:
		return try_attack(release_direction, can_damage_target_across_zones, charge_ratio)
	return try_attack(release_direction, can_damage_target_across_zones, 0.0)

func cancel_attack_charge(_apply_cooldown: bool = true) -> void:
	if not is_attack_button_held and not is_heavy_charging:
		return
	_reset_attack_hold()

func cancel_input_actions() -> void:
	cancel_attack_charge(false)
	dash_time_remaining = 0.0
	attack_last_input_direction = Vector2.ZERO
	attack_input_grace_remaining = 0.0

func try_attack(aim_direction: Vector2, can_damage_target_across_zones: Callable, charge_ratio: float = 0.0) -> bool:
	if attack_cooldown_remaining > 0.0:
		return false
	attack_cooldown_remaining = attack_cooldown
	AudioCue.play_sfx(&"attack_heavy" if charge_ratio > 0.0 else &"attack_light", -3.0)
	var attack_shape: Dictionary = _build_attack_shape(aim_direction, can_damage_target_across_zones, charge_ratio)
	_play_attack_visual(attack_shape, charge_ratio)
	_apply_attack_hit(attack_shape, can_damage_target_across_zones, charge_ratio)
	return true

func try_dash(input_direction: Vector2, aim_direction: Vector2) -> bool:
	if dash_cooldown_remaining > 0.0 or dash_time_remaining > 0.0:
		return false

	if input_direction.length_squared() > 0.001:
		dash_direction = input_direction.normalized()
	else:
		dash_direction = aim_direction

	var dash_distance_multiplier: float = float(blessing_controller.get_next_dash_distance_multiplier()) if blessing_controller != null else 1.0
	dash_time_remaining = dash_duration * dash_distance_multiplier
	var cooldown_multiplier: float = float(blessing_controller.on_dash_started()) if blessing_controller != null else 1.0
	dash_cooldown_remaining = get_current_dash_cooldown() * cooldown_multiplier
	cancel_attack_charge(true)
	return true

func take_damage(damage: int, hit_direction: Vector2 = Vector2.ZERO, damage_type: StringName = &"special") -> bool:
	if player.has_meta("facility_vehicle"):
		var vehicle: Node = player.get_meta("facility_vehicle")
		if is_instance_valid(vehicle):
			# The vehicle resolves actual body contact as one reciprocal event.
			# Enemy radius attacks would otherwise double-charge and pause it.
			if damage_type == &"contact":
				return false
			return vehicle.take_damage(damage, hit_direction, damage_type)
	damage = preload("res://Scripts/Facilities/FacilityControlEffect.gd").damage(player, damage)
	if blessing_controller != null and blessing_controller.is_invulnerable():
		return false
	if damage_type == &"contact" and contact_immunity_remaining > 0.0:
		return false
	var modified_damage: int = int(blessing_controller.modify_incoming_damage(damage, is_heavy_charging)) if blessing_controller != null else damage
	var incoming_damage := maxf(float(modified_damage), 0.0)
	var armor_reduction := bonus_armor / (bonus_armor + 100.0) if bonus_armor > 0.0 else 0.0
	var reduced_damage := incoming_damage * (1.0 - armor_reduction) * (1.0 - total_damage_reduction)
	var final_damage := maxi(int(round(reduced_damage)), 1 if incoming_damage > 0.0 else 0)
	if blessing_controller != null and blessing_controller.prevent_fatal_damage(current_health, final_damage):
		current_health = 1
	else:
		current_health = clampi(current_health - final_damage, 0, get_current_max_health())
	if damage_type == &"contact":
		contact_immunity_remaining = contact_immunity_duration
	if final_damage > 0:
		AudioCue.at(player, &"hurt", -3.0)
	_update_health_label()
	_play_hit_feedback(hit_direction, damage_type == &"quicksand")
	return true

func reset_runtime_stats() -> void:
	move_speed_multiplier = 1.0
	attack_damage_multiplier = 1.0
	dash_cooldown_multiplier = 1.0

func reset_temporary_state() -> void:
	current_health = get_current_max_health()
	attack_cooldown_remaining = 0.0
	_reset_attack_hold()
	dash_cooldown_remaining = 0.0
	dash_time_remaining = 0.0
	contact_immunity_remaining = 0.0
	if hit_feedback_tween:
		hit_feedback_tween.kill()
		hit_feedback_tween = null
	if sprite != null:
		sprite.modulate = Color.WHITE
		sprite.position = base_sprite_position
		sprite.scale = base_sprite_scale
	_update_health_label()

func add_shop_move_speed_bonus(multiplier_bonus: float) -> void:
	move_speed_multiplier *= maxf(multiplier_bonus, 0.01)

func add_shop_attack_damage_bonus(multiplier_bonus: float) -> void:
	attack_damage_multiplier *= maxf(multiplier_bonus, 0.01)

func add_shop_max_health_bonus(health_bonus: int) -> void:
	if health_bonus <= 0:
		return
	bonus_max_health += health_bonus
	current_health += health_bonus
	_update_health_label()

func set_event_max_health_penalty(penalty: int) -> void:
	event_max_health_penalty = maxi(penalty, 0)
	current_health = mini(current_health, get_current_max_health())
	_update_health_label()

func apply_forged_attribute(option: Dictionary) -> void:
	var attribute_id := StringName(option.get("attribute_id", &""))
	var fixed := float(option.get("fixed", 0.0))
	match attribute_id:
		&"attack_damage":
			bonus_attack_damage += fixed
			total_attack_multiplier += float(option.get("total_attack", 0.0))
		&"max_health":
			bonus_max_health += int(round(fixed))
			total_health_multiplier += float(option.get("total_health", 0.0))
			current_health += int(round(fixed))
		&"armor":
			bonus_armor += fixed
			total_damage_reduction = 1.0 - (1.0 - total_damage_reduction) * (1.0 - float(option.get("final_damage_reduction", 0.0)))
		&"health_regen":
			bonus_health_regen += fixed
			percent_health_regen += float(option.get("percent_health_regen", 0.0))
		&"move_speed":
			total_move_speed_multiplier += float(option.get("total_move_speed", 0.0)) + fixed
		&"work_efficiency", &"cooldown_haste", &"skill_power", &"lifesteal":
			if attribute_id == &"lifesteal":
				bonus_lifesteal += fixed + float(option.get("omnivamp", 0.0))
	_update_health_label()

func get_current_move_speed() -> float:
	return move_speed_base * move_speed_multiplier * total_move_speed_multiplier * get_attack_charge_move_multiplier()

func get_current_attack_damage() -> int:
	var damage: int = PlayerCombatMath.current_attack_damage(attack_damage_base, bonus_attack_damage, total_attack_multiplier, attack_damage_multiplier)
	var multiplier: float = player.get_run_modifier_multiplier(&"attack") if is_instance_valid(player) and player.has_method("get_run_modifier_multiplier") else 1.0
	return roundi(damage * multiplier)

func get_current_dash_cooldown() -> float:
	return PlayerCombatMath.current_dash_cooldown(dash_cooldown, dash_cooldown_multiplier)

func get_dash_cooldown_progress() -> float:
	var current_dash_cooldown: float = get_current_dash_cooldown()
	if current_dash_cooldown <= 0.0:
		return 1.0
	return clampf(1.0 - dash_cooldown_remaining / current_dash_cooldown, 0.0, 1.0)

func get_dash_cooldown_remaining() -> float:
	return dash_cooldown_remaining

func get_current_max_health() -> int:
	var guardian_blessing: bool = blessing_controller != null and blessing_controller.has_title("守护祝福")
	return maxi(PlayerCombatMath.current_max_health(max_health_base, bonus_max_health, total_health_multiplier, guardian_blessing) - event_max_health_penalty, 1)

func set_blessing_controller(controller: RefCounted) -> void:
	blessing_controller = controller

func get_health_ratio() -> float:
	return float(current_health) / float(maxi(get_current_max_health(), 1))

func heal(amount: int) -> void:
	current_health = mini(current_health + maxi(amount, 0), get_current_max_health())
	_update_health_label()

func reduce_dash_cooldown_fraction(fraction: float) -> void:
	dash_cooldown_remaining = maxf(dash_cooldown_remaining - get_current_dash_cooldown() * clampf(fraction, 0.0, 1.0), 0.0)

func get_dash_direction() -> Vector2:
	return dash_direction

func is_dash_active() -> bool:
	return dash_time_remaining > 0.0

func get_heavy_charge_ratio() -> float:
	if not is_attack_button_held:
		return 0.0
	var heavy_time := maxf(attack_hold_time - light_attack_release_window, 0.0)
	return clampf(heavy_time / maxf(heavy_charge_full_duration, 0.001), 0.0, 1.0)

func is_heavy_charge_full() -> bool:
	return get_heavy_charge_ratio() >= 1.0

func get_attack_charge_move_multiplier() -> float:
	if not is_heavy_charging:
		return 1.0
	return lerpf(heavy_charge_move_slow_min, heavy_charge_move_slow_max, get_heavy_charge_ratio())

func _apply_attack_hit(attack_shape: Dictionary, can_damage_target_across_zones: Callable, charge_ratio: float = 0.0) -> void:
	var attack_origin: Vector2 = player.global_position + attack_origin_offset
	var aim_direction: Vector2 = attack_shape.get("direction", Vector2.RIGHT)
	var effective_inner_radius: float = float(attack_shape.get("inner_radius", attack_inner_radius))
	var effective_outer_radius: float = float(attack_shape.get("outer_radius", attack_outer_radius))
	var effective_attack_angle_degrees: float = float(attack_shape.get("angle_degrees", attack_angle_degrees))
	var half_attack_angle: float = deg_to_rad(effective_attack_angle_degrees * 0.5)
	var base_damage := get_current_attack_damage()
	var attack_damage := base_damage
	var is_heavy_attack := charge_ratio > 0.0
	var is_full_heavy := charge_ratio >= 1.0
	if blessing_controller != null:
		effective_outer_radius *= blessing_controller.get_heavy_range_multiplier(is_full_heavy)
	if is_heavy_attack:
		attack_damage = max(1, int(round(float(base_damage) * lerpf(heavy_damage_multiplier_min, heavy_damage_multiplier_max, charge_ratio))))
	else:
		attack_damage = max(1, int(round(float(base_damage) * light_attack_damage_multiplier)))
	if blessing_controller != null:
		blessing_controller.begin_player_attack(is_heavy_attack)

	var successful_hits := 0
	for target in player.get_tree().get_nodes_in_group("damageables"):
		if not target.has_method("receive_hit"):
			continue

		var geometry := PlayerAttackTargetQuery.get_target_geometry(target, attack_origin)
		var target_position: Vector2 = geometry.position
		var target_radius: float = float(geometry.radius)
		var distance: float = float(geometry.distance)
		if not PlayerAttackTargetQuery.is_in_attack_geometry(geometry, effective_inner_radius, effective_outer_radius, aim_direction, half_attack_angle):
			continue
		if not bool(can_damage_target_across_zones.call(target_position)):
			continue

		var target_damage: int = int(blessing_controller.modify_attack_damage(attack_damage, target, is_heavy_attack, distance)) if blessing_controller != null else attack_damage
		var is_enemy: bool = target.is_in_group("enemies") or target.is_in_group("scarab_enemies")
		var was_alive: bool = is_enemy and not bool(target.is_dead)
		var health_before: int = int(target.current_health) if target.is_in_group("enemies") else 0
		var scarab_hits_before: int = int(target.light_hits) if target.is_in_group("scarab_enemies") else 0
		if target.has_method("receive_player_hit"):
			target.receive_player_hit(target_damage, aim_direction, player, is_heavy_attack)
		elif is_heavy_attack and target.has_method("receive_charged_hit"):
			target.receive_charged_hit(target_damage, aim_direction)
		else:
			target.receive_hit(target_damage, aim_direction)
		AudioCue.play_sfx(&"hit", -5.0, 1.0 + float(successful_hits % 3) * 0.04)
		if was_alive:
			var was_killed: bool = bool(target.is_dead)
			var hit_landed: bool = was_killed or (int(target.current_health) < health_before if target.is_in_group("enemies") else int(target.light_hits) > scarab_hits_before)
			if hit_landed:
				preload("res://Scripts/Player/UltimateEnergyRules.gd").award(player, &"heavy_hit" if is_heavy_attack else &"light_hit")
			if was_killed:
				preload("res://Scripts/Player/UltimateEnergyRules.gd").award(player, &"kill")
		successful_hits += 1
	if blessing_controller != null:
		blessing_controller.end_player_attack()
	if successful_hits > 0 and bonus_lifesteal > 0.0:
		current_health = mini(get_current_max_health(), current_health + int(floor(float(attack_damage * successful_hits) * bonus_lifesteal)))
		_update_health_label()

func _build_attack_shape(aim_direction: Vector2, can_damage_target_across_zones: Callable, charge_ratio: float = 0.0) -> Dictionary:
	var resolved_aim_direction: Vector2 = _get_auto_aim_direction(aim_direction, can_damage_target_across_zones, charge_ratio)
	return {
		"direction": resolved_aim_direction,
		"inner_radius": attack_inner_radius,
		"outer_radius": _get_attack_hit_outer_radius(charge_ratio),
		"angle_degrees": attack_angle_degrees
	}

func _play_attack_visual(attack_shape: Dictionary, charge_ratio: float = 0.0) -> void:
	if attack_visualizer == null:
		return
	var resolved_aim_direction: Vector2 = attack_shape.get("direction", Vector2.RIGHT)
	var visual_angle: float = resolved_aim_direction.angle()
	var visual_inner_radius: float = float(attack_shape.get("inner_radius", attack_inner_radius))
	var visual_outer_radius: float = float(attack_shape.get("outer_radius", attack_outer_radius))
	var visual_arc_angle_degrees: float = float(attack_shape.get("angle_degrees", attack_angle_degrees))
	if charge_ratio > 0.0 and attack_visualizer.has_method("play_charged_shape"):
		attack_visualizer.play_charged_shape(visual_angle, charge_ratio, charge_ratio >= 1.0, visual_inner_radius, visual_outer_radius, visual_arc_angle_degrees)
	elif charge_ratio > 0.0 and attack_visualizer.has_method("play_charged"):
		attack_visualizer.play_charged(visual_angle, charge_ratio, charge_ratio >= 1.0)
	elif attack_visualizer.has_method("play_attack_shape"):
		attack_visualizer.play_attack_shape(visual_angle, visual_inner_radius, visual_outer_radius, visual_arc_angle_degrees)
	else:
		attack_visualizer.play(visual_angle)

func _show_charge_preview(preview_direction: Vector2, charge_ratio: float) -> void:
	if attack_visualizer == null:
		return
	var preview_shape: Dictionary = _build_preview_attack_shape(preview_direction, charge_ratio)
	var visual_direction: Vector2 = preview_shape.get("direction", Vector2.RIGHT)
	if attack_visualizer.has_method("preview_charge_shape"):
		attack_visualizer.preview_charge_shape(
			visual_direction,
			charge_ratio,
			charge_ratio >= 1.0,
			float(preview_shape.get("inner_radius", attack_inner_radius)),
			float(preview_shape.get("outer_radius", attack_outer_radius)),
			float(preview_shape.get("angle_degrees", attack_angle_degrees))
		)
	elif attack_visualizer.has_method("preview_charge"):
		attack_visualizer.preview_charge(visual_direction, charge_ratio, charge_ratio >= 1.0)

func _build_preview_attack_shape(preview_direction: Vector2, charge_ratio: float = 0.0) -> Dictionary:
	var safe_direction := preview_direction.normalized() if preview_direction.length_squared() > 0.001 else _get_aim_direction_for_preview()
	return {
		"direction": safe_direction,
		"inner_radius": attack_inner_radius,
		"outer_radius": _get_attack_hit_outer_radius(charge_ratio),
		"angle_degrees": attack_angle_degrees
	}

func _get_attack_hit_outer_radius(charge_ratio: float = 0.0) -> float:
	return attack_outer_radius * (1.0 + maxf(charge_ratio, 0.0) * 0.18)

func _get_auto_aim_direction(fallback_direction: Vector2, can_damage_target_across_zones: Callable, charge_ratio: float = 0.0) -> Vector2:
	var attack_origin: Vector2 = player.global_position + attack_origin_offset
	var best_target_position: Vector2 = Vector2.ZERO
	var best_score: float = INF
	var is_light_attack: bool = charge_ratio <= 0.0
	var auto_aim_angle_degrees: float = light_attack_auto_aim_angle_degrees if is_light_attack else attack_auto_aim_angle_degrees
	var effective_outer_radius: float = _get_attack_hit_outer_radius(charge_ratio)
	var reference_direction: Vector2 = fallback_direction.normalized() if fallback_direction.length_squared() > 0.001 else _get_aim_direction_for_preview()
	var half_auto_aim_angle: float = deg_to_rad(auto_aim_angle_degrees * 0.5)

	for target in player.get_tree().get_nodes_in_group("damageables"):
		if not target.has_method("receive_hit"):
			continue

		var geometry := PlayerAttackTargetQuery.get_target_geometry(target, attack_origin)
		var target_position: Vector2 = geometry.position
		var target_radius: float = float(geometry.radius)
		var distance: float = float(geometry.distance)
		var to_target: Vector2 = geometry.offset
		if not PlayerAttackTargetQuery.is_in_attack_geometry(geometry, attack_inner_radius, effective_outer_radius, reference_direction, half_auto_aim_angle):
			continue
		if not bool(can_damage_target_across_zones.call(target_position)):
			continue
		var target_direction: Vector2 = to_target.normalized()
		var angle_to_reference: float = abs(reference_direction.angle_to(target_direction))
		var is_close_light_target: bool = is_light_attack and distance <= light_attack_close_auto_aim_radius + target_radius
		if not is_close_light_target and angle_to_reference > half_auto_aim_angle:
			continue
		var angle_score: float = 0.0 if is_close_light_target else angle_to_reference * 80.0
		var score: float = distance + angle_score
		if score < best_score:
			best_score = score
			best_target_position = target_position

	if best_score < INF:
		var auto_direction: Vector2 = best_target_position - attack_origin
		if auto_direction.length_squared() > 0.001:
			return auto_direction.normalized()

	if fallback_direction.length_squared() > 0.001:
		return fallback_direction.normalized()
	return Vector2.RIGHT

func _get_aim_direction_for_preview() -> Vector2:
	if player != null:
		var aim_value: Variant = player.get("aim_direction")
		if aim_value is Vector2 and aim_value.length_squared() > 0.001:
			return aim_value.normalized()
	return Vector2.RIGHT

func _update_attack_input_memory(input_direction: Vector2, delta: float) -> void:
	if input_direction.length_squared() > 0.001:
		attack_last_input_direction = input_direction.normalized()
		attack_input_grace_remaining = attack_snap_input_grace_duration
	else:
		attack_input_grace_remaining = maxf(attack_input_grace_remaining - delta, 0.0)

func _resolve_attack_direction(fallback_direction: Vector2) -> Vector2:
	if attack_input_grace_remaining > 0.0 and attack_last_input_direction.length_squared() > 0.001:
		return attack_last_input_direction.normalized()
	if fallback_direction.length_squared() > 0.001:
		return fallback_direction.normalized()
	return _get_aim_direction_for_preview()

func _reset_attack_hold() -> void:
	is_attack_button_held = false
	is_heavy_charging = false
	attack_hold_time = 0.0
	heavy_overhold_remaining = 0.0
	if attack_visualizer != null and attack_visualizer.has_method("stop_charge_preview"):
		attack_visualizer.stop_charge_preview()

func _update_health_label() -> void:
	if health_label != null:
		preload("res://Scripts/UI/HealthBar.gd").update_overhead(health_label, current_health, get_current_max_health(), true)

func _play_hit_feedback(hit_direction: Vector2, color_only: bool = false) -> void:
	if sprite == null or player == null:
		return
	if hit_feedback_tween:
		hit_feedback_tween.kill()
	if color_only:
		sprite.position = base_sprite_position
		sprite.scale = base_sprite_scale
		sprite.modulate = Color(1.0, 0.6, 0.4)
		hit_feedback_tween = player.create_tween()
		hit_feedback_tween.tween_property(sprite, "modulate", Color.WHITE, 0.18)
		return

	var sprite_offset: Vector2 = hit_direction.normalized() * 10.0 if hit_direction.length_squared() > 0.001 else Vector2.ZERO
	sprite.modulate = Color(1.0, 0.5, 0.5, 1.0)
	sprite.scale = Vector2(base_sprite_scale.x * 1.12, base_sprite_scale.y * 0.92)
	sprite.position = base_sprite_position + sprite_offset

	hit_feedback_tween = player.create_tween()
	hit_feedback_tween.set_parallel(true)
	hit_feedback_tween.tween_property(sprite, "modulate", Color.WHITE, 0.12)
	hit_feedback_tween.tween_property(sprite, "scale", base_sprite_scale, 0.12)
	hit_feedback_tween.tween_property(sprite, "position", base_sprite_position, 0.12)
