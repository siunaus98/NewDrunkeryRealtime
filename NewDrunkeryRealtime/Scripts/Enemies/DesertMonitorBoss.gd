extends "res://Scripts/Enemies/MapMechanismBoss.gd"

const Food = preload("res://Scripts/Enemies/MonitorFoodAccess.gd")
const Tongue = preload("res://Scripts/Enemies/MonitorFeedingController.gd")
const FacilityTongue = preload("res://Scripts/Enemies/MonitorFacilityTongue.gd")
@export var bait_scan_interval: float = 0.5
@export var eating_durations: Array[float] = [1.0, 1.5, 3.5, 7.0]
@export var rear_damage_multiplier: float = 2.0
@export var facing_turn_speed: float = PI / 2.0
@export var bite_interval: float = 4.0
@export var bite_radius: float = 300.0
@export var bite_half_angle: float = 0.75
@export var bite_damage: int = 20
@export var bite_recovery_duration: float = 1.0
var bite_remaining: float = 1.5
var facing: Vector2 = Vector2.DOWN
var weakpoint_view: Node2D
var combat_move_target: Vector2 = Vector2.ZERO
var tongue: Node2D
var facility_tongue: Node2D
var next_pressure_is_facility: bool = false
var pressure_gap: float = 0.0
var pressure_owner: Node2D
var bait: Dictionary = {}
var scan_remaining: float = 0.0
var eating_remaining: float = 0.0
var eating_quality: int = 0

func _ready() -> void:
	super._ready()
	add_to_group("monitor_bosses")
	tongue = Tongue.new()
	add_child(tongue)
	tongue.setup(self)
	facility_tongue = FacilityTongue.new()
	add_child(facility_tongue)
	facility_tongue.setup(self)
	weakpoint_view = Node2D.new()
	weakpoint_view.z_index = 6
	add_child(weakpoint_view)
	weakpoint_view.draw.connect(_draw_weakpoint)

func _physics_process(delta: float) -> void:
	if is_dead:
		return
	feedback_remaining = maxf(feedback_remaining - delta, 0.0)
	contact_cooldown_remaining = maxf(contact_cooldown_remaining - delta, 0.0)
	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player") as Node2D
	velocity = Vector2.ZERO
	if preload("res://Scripts/Facilities/FacilityControlEffect.gd").rooted(self):
		_update_visuals()
		return
	bite_remaining = maxf(bite_remaining - delta, 0.0)
	if eating_remaining > 0.0:
		eating_remaining = maxf(eating_remaining - delta, 0.0)
		if eating_remaining <= 0.0:
			_enter_recovery()
		_update_visuals()
		return
	_tick_pressure(delta)
	if is_dead:
		return
	if eating_remaining > 0 or tongue.blocks_boss() or facility_tongue.blocks_boss():
		_update_visuals()
		return
	_update_facing(delta)
	scan_remaining -= delta
	if scan_remaining <= 0.0:
		scan_remaining = bait_scan_interval
		_find_bait()
	if tongue.active():
		bait.clear()
	if not bait.is_empty() and not Food.valid(bait):
		bait.clear()
	state_remaining = maxf(state_remaining - delta, 0.0)
	match state:
		AttackState.WINDUP:
			if state_remaining <= 0.0:
				_resolve_attack()
		AttackState.CHARGE:
			var previous := global_position
			var motion := _forward_target(minf(rush_speed * delta, global_position.distance_to(attack_target))) - global_position
			var collided := _move_in_arena(motion)
			if not bait.is_empty() and Food.valid(bait) and _point_segment_distance(bait.position, previous, global_position) <= 120.0:
				_eat_bait()
			elif not contact_hit and geometry.swept_contact(_player_point(), global_position - previous, _player_contact_radius()):
				_damage_player(skill_damage, attack_direction)
				contact_hit = true
			if eating_remaining <= 0.0 and (state_remaining <= 0.0 or collided or global_position.distance_to(attack_target) <= 0.1):
				_enter_recovery()
		AttackState.RECOVERY:
			if state_remaining <= 0.0:
				state = AttackState.ACTIVE
		AttackState.ACTIVE:
			if not bait.is_empty():
				var offset: Vector2 = bait.position - global_position
				if offset.length() <= 130.0:
					_eat_bait()
				else:
					_approach_forward(bait.position, move_speed * 1.8, delta)
			elif _player_in_arena():
				attack_remaining -= delta
				if _bite_ready() and facing.dot((_player_point() - global_position).normalized()) >= cos(PI / 6.0):
					start_attack(Attack.BITE)
				elif attack_remaining <= 0.0:
					_start_next_attack()
				# Align before moving when a close-range attack is ready. Otherwise
				# forward pursuit can orbit a point under the head forever.
				if state == AttackState.ACTIVE and (attack_remaining > 0.3 or global_position.distance_to(_player_point()) > combat_spacing):
					_approach_forward(combat_move_target, move_speed, delta)
	_update_visuals()
	if eating_remaining <= 0.0:
		_try_contact_damage()

func _find_bait() -> void:
	var options := Food.candidates(get_tree(), _get_safe_arena_bounds(), true)
	options.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if Food.quality(a.item) != Food.quality(b.item):
			return Food.quality(a.item) > Food.quality(b.item)
		return global_position.distance_squared_to(a.position) < global_position.distance_squared_to(b.position)
	)
	# Reject bait behind placed obstacles instead of walking into them forever.
	for candidate: Dictionary in options:
		if geometry.motion_clear(global_position, candidate.position - global_position):
			bait = candidate
			return
	bait.clear()

func _eat_bait() -> void:
	var eaten := Food.consume(bait)
	bait.clear()
	if eaten.is_empty():
		return
	consume_feast([eaten])
	# A deliberate arena offering still postpones the next kitchen pressure.
	tongue.cooldown = tongue.interval
	facility_tongue.cooldown = facility_tongue.interval

func consume_feast(meals: Array[Dictionary]) -> void:
	if is_dead or meals.is_empty():
		return
	var duration := 0.0
	var meal_damage := 0
	eating_quality = 0
	for meal: Dictionary in meals:
		var quality := Food.quality(meal)
		eating_quality = maxi(eating_quality, quality)
		var id := StringName(meal.get("item_id", &""))
		if Food.Items.is_dish(id):
			var level := clampi(Food.Items.get_dish_difficulty(id), 1, 3)
			duration += 3.0 + level * 2.0
			meal_damage += roundi(max_health * 0.02 * level)
		else:
			duration += eating_durations[clampi(quality, 0, eating_durations.size() - 1)]
			var ingredient_id := StringName(meal.get("payload", {}).get("item_id", id)) if id == Food.Items.SEASONING_BOX_ID else id
			if Food.Items.is_ingredient(ingredient_id):
				duration += (Food.Items.get_ingredient_acquisition_tier(ingredient_id) - 1) * 0.5
	eating_remaining = minf(duration, 10.0)
	state = AttackState.RECOVERY
	velocity = Vector2.ZERO
	contact_cooldown_remaining = eating_remaining + 0.5
	if meal_damage > 0:
		# Meal damage never inherits positional weak-point multipliers.
		super.receive_hit(meal_damage)

func _update_facing(delta: float) -> void:
	# A committed attack keeps its facing through windup, movement and
	# recovery, so dodging around it opens the same rear shown by the marker.
	if state != AttackState.ACTIVE:
		return
	var nearest: Node2D
	var distance := INF
	for actor: Node2D in get_tree().get_nodes_in_group("player"):
		if not movement_bounds.has_point(actor.global_position):
			continue
		var offset := actor.global_position - global_position
		if offset.length_squared() < distance:
			nearest = actor
			distance = offset.length_squared()
	if nearest != null:
		player = nearest
	var target := nearest.global_position if nearest != null else global_position
	if not bait.is_empty() and Food.valid(bait):
		target = bait.position
	elif nearest != null and attack_remaining > 0.3 and not _bite_ready():
		target = combat_movement.target(self, target, delta)
	combat_move_target = target
	var offset: Vector2 = target - global_position
	if offset.length_squared() > 0.01:
		facing = facing.rotated(clampf(facing.angle_to(offset), -facing_turn_speed * delta, facing_turn_speed * delta)).normalized()

func _forward_target(distance: float) -> Vector2:
	return _directional_target(facing, distance)

func _approach_forward(target: Vector2, speed: float, delta: float) -> void:
	var offset := target - global_position
	if offset.is_zero_approx() or facing.dot(offset.normalized()) <= 0.35:
		return
	velocity = facing * speed
	var motion := _forward_target(minf(speed * delta, offset.length())) - global_position
	var previous := global_position
	_move_in_arena(motion)
	combat_movement.report_motion(motion, global_position - previous, delta)

func is_rear_hit(attacker_position: Vector2) -> bool:
	var offset := attacker_position - get_hit_position()
	var body_forward := (sprite.to_global(Vector2(-1, -1).normalized()) - sprite.global_position).normalized()
	return not offset.is_zero_approx() and offset.normalized().dot(body_forward) < -0.4

func receive_player_hit(damage: int, direction: Vector2, attacker: Node2D, _heavy: bool) -> void:
	var multiplier := rear_damage_multiplier if is_rear_hit(attacker.global_position) else 1.0
	super.receive_hit(roundi(damage * multiplier), direction)

func _tick_pressure(delta: float) -> void:
	pressure_gap = maxf(pressure_gap - delta, 0)
	if pressure_owner != null and not pressure_owner.active():
		next_pressure_is_facility = pressure_owner == tongue
		pressure_owner = null
		pressure_gap = 3.0
	var busy: bool = tongue.active() or facility_tongue.active()
	var can_start: bool = not busy and pressure_gap <= 0 and state == AttackState.ACTIVE and bait.is_empty()
	var selected: Node2D = facility_tongue if next_pressure_is_facility else tongue
	if busy:
		selected = tongue if tongue.active() else facility_tongue
		pressure_owner = selected
	var other: Node2D = facility_tongue if selected == tongue else tongue
	other.cooldown = maxf(other.cooldown - delta, 0)
	var attempted: bool = can_start and selected.cooldown <= delta
	selected.tick(delta, can_start)
	if selected.active():
		pressure_owner = selected
	elif busy:
		next_pressure_is_facility = selected == tongue
		pressure_owner = null
		pressure_gap = 3.0
	elif attempted:
		# An empty kitchen must not prevent the other head from disabling an
		# empty but essential cooker. Each head gets its own opportunity.
		next_pressure_is_facility = selected == tongue
		pressure_gap = 0.5

func _start_next_attack() -> void:
	var offset := _player_point() - global_position
	if not offset.is_zero_approx() and facing.dot(offset.normalized()) < cos(PI / 6.0):
		return
	var sequence: Array[int] = [Attack.STING, Attack.SWEEP, Attack.RUSH]
	start_attack(sequence[cycle_index % sequence.size()])
	cycle_index += 1

func _bite_ready() -> bool:
	return bite_remaining <= 0.0 and _player_in_arena() and global_position.distance_to(_player_point()) <= bite_radius

func attack_contains_point(point: Vector2) -> bool:
	if attack == Attack.BITE:
		var offset := point - attack_origin
		return offset.length() <= bite_radius and (offset.is_zero_approx() or absf(attack_direction.angle_to(offset)) <= bite_half_angle)
	if attack == Attack.STING:
		return point.distance_to(attack_target) <= leap_radius
	return super.attack_contains_point(point)

func _prepare_strike() -> void:
	super._prepare_strike()
	series_remaining = 1
	attack_direction = facing
	if attack == Attack.RUSH:
		attack_target = _forward_target(maxf(global_position.distance_to(_player_point()), rush_min_distance))
		windup_total = rush_windup_duration
	elif attack == Attack.STING:
		attack_target = _leap_target(facing, global_position.distance_to(_player_point()), 450.0, false)
		windup_total = 1.1
	elif attack == Attack.BITE:
		series_remaining = 2
		windup_total = 0.55
	else:
		windup_total = 1.3
	state_remaining = windup_total

func _minimum_displacement() -> float:
	return leap_min_distance if attack == Attack.STING else super._minimum_displacement()

func _resolve_attack() -> void:
	if attack == Attack.BITE:
		_spawn_scorpion_effect(&"bite", attack_origin, attack_direction, bite_radius)
		if _player_in_arena() and attack_contains_point(_player_point()):
			_damage_player(bite_damage, attack_direction)
		series_remaining -= 1
		if series_remaining > 0:
			# Second bite keeps the same warning and facing; no snap tracking.
			windup_total = 0.35
			state_remaining = windup_total
		else:
			bite_remaining = bite_interval
			state = AttackState.RECOVERY
			state_remaining = bite_recovery_duration
			velocity = Vector2.ZERO
	elif attack == Attack.RUSH:
		# The lane is locked during windup. Food entering it can stop the rush.
		state = AttackState.CHARGE
		state_remaining = maxf(global_position.distance_to(attack_target) / rush_speed, 0.1)
		contact_hit = false
	elif attack == Attack.STING:
		global_position = attack_target
		_spawn_scorpion_effect(&"leap", attack_target, attack_direction, leap_radius)
		if _player_in_arena() and _player_point().distance_to(attack_target) <= leap_radius:
			_damage_player(skill_damage, attack_direction)
		_enter_recovery()
	else:
		_spawn_scorpion_effect(&"sweep", global_position, attack_direction, sweep_radius)
		_damage_shape()
		_enter_recovery()

func receive_charged_hit(damage: int, direction: Vector2 = Vector2.ZERO) -> void:
	receive_hit(damage, direction)

func receive_hit(damage: int, direction: Vector2 = Vector2.ZERO) -> void:
	super.receive_hit(damage, direction)

func is_invulnerable() -> bool:
	return false

func get_boss_display_name() -> String:
	return "沙宴巨蜥"

func get_boss_status_text() -> String:
	if tongue != null and tongue.active():
		return tongue.status_text()
	if facility_tongue != null and facility_tongue.active():
		return facility_tongue.status_text()
	if eating_remaining > 0.0:
		return "进食晕眩 · 背后弱点暴露"
	if not bait.is_empty():
		return "发现诱饵"
	if state == AttackState.WINDUP:
		return "双颚连咬" if attack == Attack.BITE else ("扑咬" if attack == Attack.STING else ("横扫甩尾" if attack == Attack.SWEEP else "吞食猛冲"))
	return ""

func _update_visuals() -> void:
	super._update_visuals()
	# The oblique artwork points upper-left. Rotate with the gameplay
	# facing, so the glowing rear patch always matches positional damage.
	sprite.rotation += facing.angle() + 3.0 * PI / 4.0
	if eating_remaining > 0.0:
		sprite.scale = base_sprite_scale * Vector2(1.08, 0.88 + 0.03 * sin(eating_remaining * 9.0))
	elif tongue != null and (tongue.blocks_boss() or facility_tongue.blocks_boss()):
		sprite.position.y -= 12.0
		sprite.scale = base_sprite_scale * Vector2(0.96, 1.06)
	elif state == AttackState.WINDUP and attack == Attack.STING:
		var progress := clampf(1.0 - state_remaining / windup_total, 0, 1)
		sprite.position = base_sprite_position + (attack_target - global_position) * progress + Vector2.UP * sin(progress * PI) * 100.0
	elif state == AttackState.WINDUP and attack == Attack.BITE:
		var progress := clampf(1.0 - state_remaining / windup_total, 0, 1)
		sprite.position += attack_direction * (-18.0 * sin(progress * PI) + 28.0 * pow(progress, 3))
		sprite.scale *= Vector2(1.0 + 0.08 * sin(progress * PI), 1.0 - 0.06 * sin(progress * PI))
	geometry.sync_ground()
	if weakpoint_view != null:
		# Inherit the complete animated body pose, while retaining the marker's
		# authored world size at the neutral sprite scale.
		weakpoint_view.transform = sprite.transform * Transform2D(0.0, Vector2.ONE / base_sprite_scale, 0.0, Vector2.ZERO)
		weakpoint_view.queue_redraw()

func _draw_weakpoint() -> void:
	var rear := Vector2(88.0, 88.0)
	weakpoint_view.draw_circle(rear, 27, Color("56382b"))
	weakpoint_view.draw_circle(rear, 21, Color("f3cb72"))
	weakpoint_view.draw_arc(rear, 30, 0, TAU, 24, Color("ffe9a8"), 4, true)

func _draw() -> void:
	draw_circle(Vector2(0, 24), hit_radius, Color(0.08, 0.04, 0.03, 0.2))
	if state == AttackState.WINDUP and attack == Attack.BITE:
		var origin := to_local(attack_origin)
		var points := PackedVector2Array([origin])
		for i in range(25):
			points.append(origin + attack_direction.rotated(lerpf(-bite_half_angle, bite_half_angle, float(i) / 24.0)) * bite_radius)
		points.append(origin)
		draw_colored_polygon(points, Color(0.95, 0.25, 0.1, 0.3))
		draw_polyline(points, Color("f3c35a"), 4.0, true)
		# Opposing jaws close over the warned sector as the bite approaches.
		var progress := clampf(1.0 - state_remaining / windup_total, 0.0, 1.0)
		for side in [-1, 1]:
			draw_line(origin + attack_direction * 80, origin + attack_direction.rotated(side * bite_half_angle * (1.0 - progress)) * bite_radius, Color("ffe9a8"), 6.0, true)
	elif state == AttackState.WINDUP and attack == Attack.STING:
		var point := to_local(attack_target)
		draw_circle(point, leap_radius, Color(0.95, 0.25, 0.1, 0.25))
		draw_arc(point, leap_radius, 0, TAU, 48, Color("f3c35a"), 5, true)
	else:
		super._draw()

func _die() -> void:
	if tongue != null:
		tongue.release_captured_food()
	if facility_tongue != null:
		facility_tongue.finish()
	preload("res://Scripts/Facilities/FacilityWorkPause.gd").clear_owned(get_tree(), self)
	super._die()
