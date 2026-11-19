class_name MapMechanismBoss
extends CharacterBody2D

const AudioCue = preload("res://Scripts/Audio/AudioCue.gd")

const PROJECTILE_SCENE := preload("res://Scenes/Enemies/enemy_projectile.tscn")
const LevelRefs = preload("res://Scripts/Core/LevelRefs.gd")
const MapMechanismDefs = preload("res://Scripts/Core/MapMechanismDefs.gd")
const ScorpionEffect = preload("res://Scripts/Enemies/ScorpionSkillEffect.gd")
const TailStrike = preload("res://Scripts/Enemies/SandwormTailStrike.gd")
const VultureSkills = preload("res://Scripts/Enemies/VultureSkillController.gd")
const CombatMovement = preload("res://Scripts/Enemies/BossCombatMovement.gd")
signal defeated(enemy: Node2D, drop_item_id: StringName, drop_count: int, defeat_position: Vector2)

enum AttackState { ACTIVE, WINDUP, RECOVERY, CHARGE }
enum Attack { NEEDLES, TAIL, SLAM, RUSH, PULSE, STING, SWEEP, LEAP, SUMMON, GUST, DIVE, CYCLONE, BITE }

@export var boss_kind: StringName = MapMechanismDefs.QUICKSAND
@export var max_health: int = 24000
@export var move_speed: float = 96.0
@export var combat_spacing: float = 190.0
@export var hit_radius: float = 92.0
@export var hit_center_offset: Vector2 = Vector2.ZERO
@export var hit_center_follows_sprite: bool = false
@export var contact_damage: int = 0
@export var contact_damage_radius: float = 140.0
@export var contact_damage_interval: float = 0.8
@export var contact_push_distance: float = 34.0
@export var movement_bounds: Rect2 = Rect2()
@export var edge_padding: Vector2 = Vector2(120.0, 120.0)
@export var drop_item_id: StringName = &"meat_red"
@export var drop_count: int = 4
@export var attack_interval: float = 1.5
@export var windup_duration: float = 1.2
@export var recovery_duration: float = 1.0
@export var projectile_damage: int = 20
@export var skill_damage: int = 30
@export var projectile_speed: float = 304.0
@export var projectile_range: float = 1100.0
@export var tail_strike_count: int = 6
@export var tail_strike_radius: float = 110.0
@export var slam_length: float = 500.0
@export var slam_half_width: float = 100.0
@export var sweep_radius: float = 290.0
@export var leap_radius: float = 240.0
@export var leap_push_distance: float = 190.0
@export var rush_speed: float = 576.0
@export var rush_windup_duration: float = 0.65
@export var leap_min_distance: float = 256.0
@export var rush_min_distance: float = 384.0
@export var scorpion_scarab_bonus: int = 2
@export var scorpion_escape_heal_per_item: int = 400

@onready var sprite: Sprite2D = $Sprite2D
@onready var health_label: Label = $HealthLabel

var current_health: int = 0
var player: Node2D
var prototype_map: Node
var level_refs: LevelRefs
var is_dead: bool = false
var state: AttackState = AttackState.ACTIVE
var attack: Attack = Attack.NEEDLES
var state_remaining: float = 0.0
var attack_remaining: float = 1.2
var cycle_index: int = 0
var attack_target: Vector2 = Vector2.ZERO
var attack_origin: Vector2 = Vector2.ZERO
var attack_direction: Vector2 = Vector2.RIGHT
var series_remaining: int = 0
var windup_total: float = 1.0
var impact_remaining: float = 0.0
var contact_hit: bool = false
var contact_cooldown_remaining: float = 0.0
var feedback_remaining: float = 0.0
var healed_feedback: bool = false
var base_sprite_position: Vector2
var base_sprite_scale: Vector2
var rush_previous_position: Vector2
var skill_effect_layer: Node2D
var vulture_skills: RefCounted
var combat_movement := CombatMovement.new()

func _ready() -> void:
	for group in ["damageables", "enemies", "bosses", "map_mechanism_bosses"]:
		add_to_group(group)
	match boss_kind:
		MapMechanismDefs.SCARAB:
			add_to_group("scorpion_bosses")
		MapMechanismDefs.QUICKSAND:
			add_to_group("sandworm_bosses")
		MapMechanismDefs.SANDSTORM:
			add_to_group("vulture_bosses")
			vulture_skills = VultureSkills.new()
			vulture_skills.setup(self)
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	current_health = max_health
	base_sprite_position = sprite.position
	base_sprite_scale = sprite.scale
	level_refs = LevelRefs.find_from(self)
	if level_refs != null:
		prototype_map = level_refs.get_prototype_map()
	player = get_tree().get_first_node_in_group("player") as Node2D
	_update_health_label()
	skill_effect_layer = Node2D.new()
	skill_effect_layer.z_index = 2
	add_child(skill_effect_layer)
	skill_effect_layer.draw.connect(_draw_scorpion_windup)

func _physics_process(delta: float) -> void:
	if preload("res://Scripts/Facilities/FacilityControlEffect.gd").rooted(self):
		velocity = Vector2.ZERO
		return
	if is_dead:
		return
	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player") as Node2D
	impact_remaining = maxf(impact_remaining - delta, 0.0)
	feedback_remaining = maxf(feedback_remaining - delta, 0.0)
	state_remaining = maxf(state_remaining - delta, 0.0)
	contact_cooldown_remaining = maxf(contact_cooldown_remaining - delta, 0.0)
	velocity = Vector2.ZERO
	if vulture_skills != null:
		vulture_skills.tick_pressure(delta)
	if boss_kind == MapMechanismDefs.SCARAB and state == AttackState.ACTIVE and _can_summon_scarabs():
		start_attack(Attack.SUMMON)
	if not _player_in_arena() and not (state == AttackState.WINDUP and attack == Attack.SUMMON):
		# Leaving the arena cancels attacks; the boss never snipes the kitchen.
		if state != AttackState.ACTIVE:
			_enter_recovery()
			state = AttackState.ACTIVE
		attack_remaining = maxf(attack_remaining, 1.0)
		_update_visuals()
		return
	match state:
		AttackState.WINDUP:
			if state_remaining <= 0.0:
				_resolve_attack()
		AttackState.RECOVERY:
			if state_remaining <= 0.0:
				state = AttackState.ACTIVE
		AttackState.CHARGE:
			rush_previous_position = global_position
			velocity = attack_direction * rush_speed
			var collided := _move_in_arena((velocity * delta).limit_length(global_position.distance_to(attack_target)))
			if not contact_hit and _point_segment_distance(_player_point(), rush_previous_position, global_position) <= hit_radius + 20.0:
				_damage_player(skill_damage, attack_direction)
				contact_hit = true
			if state_remaining <= 0.0 or collided or global_position.distance_to(attack_target) <= 0.1:
				_enter_recovery()
		AttackState.ACTIVE:
			attack_remaining = maxf(attack_remaining - delta, 0.0)
			var goal := combat_movement.target(self, _player_point(), delta)
			var motion := (goal - global_position).limit_length(move_speed * delta)
			var previous := global_position
			velocity = motion / maxf(delta, 0.001)
			_move_in_arena(motion)
			combat_movement.report_motion(motion, global_position - previous, delta)
			if attack_remaining <= 0.0:
				_start_next_attack()
	_update_visuals()
	_try_contact_damage()

func _try_contact_damage() -> void:
	if is_dead or contact_damage <= 0 or contact_cooldown_remaining > 0.0 or state == AttackState.CHARGE:
		return
	if not _player_in_arena() or not player.has_method("take_damage"):
		return
	var offset := _player_point() - get_hit_position()
	if offset.length() > contact_damage_radius:
		return
	var direction := offset.normalized() if not offset.is_zero_approx() else Vector2.DOWN
	var applied: Variant = player.take_damage(contact_damage, direction, &"contact")
	if applied is bool and not applied:
		return
	contact_cooldown_remaining = contact_damage_interval
	if player.has_method("apply_contact_push"):
		player.apply_contact_push(direction, contact_push_distance)

func _start_next_attack() -> void:
	var sequence: Array[int] = [Attack.NEEDLES, Attack.TAIL, Attack.NEEDLES, Attack.PULSE, Attack.SLAM, Attack.NEEDLES, Attack.RUSH]
	if boss_kind == MapMechanismDefs.SCARAB:
		sequence = [Attack.STING, Attack.SWEEP, Attack.LEAP]
	elif boss_kind == MapMechanismDefs.SANDSTORM:
		sequence = [Attack.GUST, Attack.DIVE, Attack.CYCLONE]
	start_attack(sequence[cycle_index % sequence.size()])
	cycle_index += 1

func start_attack(kind: Attack) -> void:
	attack = kind
	series_remaining = tail_strike_count if attack == Attack.TAIL else (3 if attack == Attack.STING else 1)
	_prepare_strike()
	# Never advertise a displacement skill that has no room to move. Keep
	# walls/obstacles authoritative and choose a stationary skill instead.
	if attack_origin.distance_to(attack_target) + 0.1 < _minimum_displacement():
		attack = Attack.SLAM if boss_kind == MapMechanismDefs.QUICKSAND else (Attack.GUST if vulture_skills != null else Attack.SWEEP)
		series_remaining = 1
		_prepare_strike()

func _minimum_displacement() -> float:
	if attack == Attack.RUSH:
		return rush_min_distance
	return leap_min_distance if attack in [Attack.LEAP, Attack.DIVE] else 0.0

func _prepare_strike() -> void:
	state = AttackState.WINDUP
	AudioCue.at(self, &"warning", -7.0)
	attack_origin = global_position
	attack_target = _player_point()
	attack_direction = (attack_target - attack_origin).normalized()
	if attack_direction == Vector2.ZERO:
		attack_direction = Vector2.DOWN
	windup_total = windup_duration
	match attack:
		Attack.TAIL:
			windup_total = 0.85
		Attack.STING:
			windup_total = 1.1
		Attack.LEAP:
			# The landing point locks when the warning appears.
			attack_target = _leap_target(attack_direction, attack_origin.distance_to(attack_target), 600.0)
		Attack.RUSH:
			windup_total = rush_windup_duration
			# A straight left/right pass with a fixed lane and visible endpoint.
			attack_direction = Vector2.RIGHT if attack_target.x >= global_position.x else Vector2.LEFT
			var safe_bounds := _get_safe_arena_bounds()
			var end_x := safe_bounds.end.x if attack_direction.x > 0 else safe_bounds.position.x
			attack_target = Vector2(end_x, global_position.y)
			if attack_origin.distance_to(attack_target) < rush_min_distance:
				attack_direction *= -1.0
				end_x = safe_bounds.end.x if attack_direction.x > 0 else safe_bounds.position.x
				attack_target = Vector2(end_x, global_position.y)
		Attack.PULSE:
			windup_total = 0.7
		Attack.SUMMON:
			windup_total = 1.4
	if vulture_skills != null:
		vulture_skills.prepare()
	state_remaining = windup_total
	_update_health_label()
	queue_redraw()

func _resolve_attack() -> void:
	AudioCue.at(self, &"impact", -5.0)
	impact_remaining = 0.3
	if vulture_skills != null:
		vulture_skills.resolve()
		_enter_recovery()
		return
	if attack == Attack.SLAM:
		impact_remaining = 0.65
	if attack in [Attack.STING, Attack.SWEEP, Attack.LEAP, Attack.SUMMON]:
		_show_scorpion_impact()
	match attack:
		Attack.SUMMON:
			if level_refs != null:
				var controller := level_refs.get_scarab_mechanism_controller()
				if controller != null:
					controller.begin_boss_burst(self)
		Attack.PULSE:
			_spawn_empowered_quicksand()
		Attack.NEEDLES:
			_fire_fan()
		Attack.TAIL:
			_damage_shape()
			var tail := TailStrike.new()
			tail.boss_owner = self
			tail.radius = tail_strike_radius
			tail.position = get_parent().to_local(attack_target)
			get_parent().add_child(tail)
		Attack.SLAM, Attack.STING, Attack.SWEEP:
			_damage_shape()
		Attack.LEAP:
			global_position = attack_target
			if _player_in_arena() and attack_contains_point(_player_point()):
				var outward := _player_point() - attack_target
				if outward.is_zero_approx():
					outward = attack_direction
				if _damage_player(skill_damage, outward.normalized()) and player.has_method("apply_contact_push"):
					player.apply_contact_push(outward, leap_push_distance)
					# A nearby obstacle may shorten the push; keep contact harmless
					# throughout recovery rather than relying on distance alone.
					contact_cooldown_remaining = maxf(contact_damage_interval, recovery_duration + 0.35)
		Attack.RUSH:
			state = AttackState.CHARGE
			state_remaining = global_position.distance_to(attack_target) / rush_speed
			contact_hit = false
			return
	series_remaining -= 1
	if series_remaining > 0:
		_prepare_strike()
	else:
		_enter_recovery()

func _enter_recovery() -> void:
	state = AttackState.RECOVERY
	state_remaining = recovery_duration
	attack_remaining = attack_interval
	velocity = Vector2.ZERO
	_update_health_label()

func _player_in_arena() -> bool:
	return is_instance_valid(player) and movement_bounds.has_point(_player_point())

func _player_point() -> Vector2:
	if not is_instance_valid(player):
		return global_position
	return player.get_sort_origin() if player.has_method("get_sort_origin") else player.global_position

func attack_contains_point(point: Vector2) -> bool:
	var offset := point - attack_origin
	match attack:
		Attack.TAIL:
			return point.distance_to(attack_target) <= tail_strike_radius
		Attack.LEAP:
			return point.distance_to(attack_target) <= leap_radius
		Attack.SLAM, Attack.RUSH:
			var length: float = slam_length if attack == Attack.SLAM else attack_origin.distance_to(attack_target)
			var width: float = slam_half_width if attack == Attack.SLAM else hit_radius + 20.0
			return offset.dot(attack_direction) >= 0.0 and offset.dot(attack_direction) <= length and absf(offset.dot(attack_direction.orthogonal())) <= width
		Attack.STING, Attack.SWEEP:
			var radius: float = 390.0 if attack == Attack.STING else sweep_radius
			var half_angle: float = 0.32 if attack == Attack.STING else 1.3
			return offset.length() <= radius and (offset.length() < 1.0 or absf(attack_direction.angle_to(offset)) <= half_angle)
	return false

func _damage_shape() -> void:
	if _player_in_arena() and attack_contains_point(_player_point()):
		_damage_player(skill_damage, (_player_point() - attack_origin).normalized())

func _damage_player(damage: int, direction: Vector2) -> bool:
	if _player_in_arena() and player.has_method("take_damage"):
		var applied: Variant = player.take_damage(damage, direction, &"special")
		if not (applied is bool) or applied:
			# A skill impact must not also deal body-contact damage on the same tick.
			contact_cooldown_remaining = contact_damage_interval
			return true
	return false

func _fire_fan() -> void:
	var runtime_root: Node = level_refs.get_runtime_root() if level_refs != null else get_parent()
	for i in range(7):
		var direction := attack_direction.rotated((float(i) - 3.0) * 0.16)
		var projectile: Area2D = PROJECTILE_SCENE.instantiate()
		runtime_root.add_child(projectile)
		projectile.fill_color = Color("e5b65b")
		projectile.setup_projectile(global_position + direction * 100.0, direction, projectile_speed, projectile_range, projectile_damage, 14.0, movement_bounds, prototype_map, self)

func _spawn_empowered_quicksand() -> void:
	if level_refs != null:
		var controller := level_refs.get_quicksand_mechanism_controller()
		if controller != null:
			controller.spawn_boss_quicksand(self)

func is_invulnerable() -> bool:
	return state == AttackState.WINDUP and attack == Attack.TAIL

func receive_hit(damage: int, _direction: Vector2 = Vector2.ZERO) -> void:
	damage = preload("res://Scripts/Facilities/FacilityControlEffect.gd").damage(self, damage)
	if is_dead or is_invulnerable():
		return
	current_health = maxi(current_health - maxi(damage, 0), 0)
	preload("res://Scripts/Enemies/HitSpark.gd").emit_at(self, _direction)
	feedback_remaining = 0.16
	healed_feedback = false
	_update_health_label()
	if current_health == 0:
		_die()

func receive_scarab_escape(stolen_count: int) -> void:
	if boss_kind != MapMechanismDefs.SCARAB or is_dead:
		return
	current_health = mini(max_health, current_health + maxi(stolen_count, 0) * scorpion_escape_heal_per_item)
	feedback_remaining = 0.5
	healed_feedback = true
	_update_health_label()

func get_hit_position() -> Vector2:
	if hit_center_follows_sprite and is_instance_valid(sprite):
		return sprite.to_global(hit_center_offset)
	return to_global(hit_center_offset)

func get_hit_radius() -> float:
	return hit_radius

func set_movement_bounds(bounds: Rect2) -> void:
	movement_bounds = bounds

func get_movement_bounds() -> Rect2:
	return movement_bounds

func setup_for_battle(item: StringName, bounds: Rect2, _wave: int = 0, _speed: float = 0.0, _health: int = 0) -> void:
	drop_item_id = item
	movement_bounds = bounds
	_clamp_to_bounds()

func _clamp_to_bounds() -> void:
	# Spawn-time placement only; runtime movement clamps its destination BEFORE
	# sweeping. Never snap between the map's competing region projections.
	global_position = _safe_arena_point(global_position)

func _get_safe_arena_bounds() -> Rect2:
	var wall_inset := Vector2.ZERO
	if is_instance_valid(prototype_map):
		wall_inset = prototype_map.get_tile_size() * prototype_map.dune_wall_thickness_cells
	var padding := Vector2.ONE * (hit_radius + 20.0) + wall_inset
	padding = padding.max(edge_padding)
	var minimum := movement_bounds.position + padding
	var maximum := movement_bounds.end - padding
	# The fourth arena's exit is on its lower edge. Leave a full body width
	# between the boss and that edge, including jump landing positions.
	maximum.y -= 80.0
	minimum = minimum.min(movement_bounds.get_center())
	maximum = maximum.max(minimum)
	return Rect2(minimum, maximum - minimum)

func _safe_arena_point(point: Vector2) -> Vector2:
	var bounds := _get_safe_arena_bounds()
	return point.clamp(bounds.position, bounds.end)

func _move_in_arena(motion: Vector2) -> bool:
	motion *= preload("res://Scripts/Facilities/FacilityControlEffect.gd").speed(self)
	var target := _safe_arena_point(global_position + motion)
	var allowed := target - global_position
	# If a legacy position is outside the new bounds, return at normal speed.
	allowed = allowed.limit_length(motion.length())
	var collision := move_and_collide(allowed)
	return collision != null or allowed.length() + 0.01 < motion.length()

func _directional_target(direction: Vector2, distance: float) -> Vector2:
	# Clip the ray, not its X/Y components, to preserve displacement direction.
	var bounds := _get_safe_arena_bounds()
	var travel := maxf(distance, 0.0)
	for axis in range(2):
		if absf(direction[axis]) > 0.0001:
			var edge: float = bounds.end[axis] if direction[axis] > 0 else bounds.position[axis]
			travel = minf(travel, maxf((edge - global_position[axis]) / direction[axis], 0.0))
	return global_position + direction * travel

func _leap_target(direction: Vector2, distance: float, maximum: float, can_redirect: bool = true) -> Vector2:
	var travel := clampf(distance, leap_min_distance, maxf(maximum, leap_min_distance))
	# Prefer the player's lane. Redirect only before the warning locks, when
	# walls or an occupied landing leave less than the minimum travel.
	var turns: Array[float] = [0.0, PI / 4, -PI / 4, PI / 2, -PI / 2, PI * 0.75, -PI * 0.75, PI]
	if not can_redirect:
		turns.resize(1)
	for turn in turns:
		var target := _directional_target(direction.rotated(turn), travel)
		if global_position.distance_to(target) + 0.1 < leap_min_distance:
			continue
		var landing := _find_clear_landing(target, leap_min_distance)
		if global_position.distance_to(landing) + 0.1 >= leap_min_distance:
			return landing
	return global_position

func _find_clear_landing(target: Vector2, minimum_distance: float = 0.0) -> Vector2:
	var shape := CircleShape2D.new()
	shape.radius = 96.0
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.collision_mask = collision_mask
	query.exclude = [get_rid()]
	for i in range(13):
		var candidate := _safe_arena_point(target.lerp(global_position, float(i) / 12.0))
		if global_position.distance_to(candidate) + 0.1 < minimum_distance:
			break
		query.transform = Transform2D(0.0, candidate)
		if get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty():
			return candidate
	return global_position

func _can_summon_scarabs() -> bool:
	if level_refs == null:
		return false
	var controller := level_refs.get_scarab_mechanism_controller()
	return controller != null and controller.can_begin_boss_burst(self)

func show_scarab_emergence(point: Vector2) -> void:
	_spawn_scorpion_effect(&"emerge", point, Vector2.RIGHT, 72.0)

func _show_scorpion_impact() -> void:
	match attack:
		Attack.STING:
			_spawn_scorpion_effect(&"sting", attack_origin, attack_direction, 390.0)
		Attack.SWEEP:
			_spawn_scorpion_effect(&"sweep", attack_origin, attack_direction, sweep_radius)
		Attack.LEAP:
			_spawn_scorpion_effect(&"leap", attack_target, attack_direction, leap_radius)
		Attack.SUMMON:
			_spawn_scorpion_effect(&"summon", global_position, Vector2.RIGHT, 200.0)

func _spawn_scorpion_effect(kind: StringName, point: Vector2, direction: Vector2, radius: float) -> void:
	var effect := ScorpionEffect.new()
	effect.kind = kind
	effect.direction = direction
	effect.radius = radius
	get_parent().add_child(effect)
	effect.global_position = point

func _point_segment_distance(point: Vector2, a: Vector2, b: Vector2) -> float:
	return point.distance_to(Geometry2D.get_closest_point_to_segment(point, a, b))

func _update_visuals() -> void:
	sprite.position = base_sprite_position
	sprite.scale = base_sprite_scale
	sprite.rotation = 0.0
	sprite.modulate = Color.WHITE
	if feedback_remaining > 0.0:
		sprite.modulate = Color(0.6, 1.4, 0.65) if healed_feedback else Color(1.5, 0.6, 0.5)
	if state == AttackState.WINDUP:
		var progress := 1.0 - state_remaining / maxf(windup_total, 0.01)
		if attack == Attack.LEAP:
			sprite.position += (attack_target - global_position) * progress + Vector2.UP * sin(progress * PI) * 150.0
		elif attack == Attack.SLAM:
			# Rear up, then bring the upper body down onto the marked lane.
			var lift := clampf(progress / 0.72, 0.0, 1.0)
			var strike := pow(clampf((progress - 0.72) / 0.28, 0.0, 1.0), 2.0)
			sprite.position += Vector2.UP * 150.0 * lift * (1.0 - strike) + attack_direction * 160.0 * strike
			sprite.scale *= Vector2(1.0 - 0.18 * lift + 0.4 * strike, 1.0 + 0.3 * lift - 0.6 * strike)
			sprite.rotation = attack_direction.x * (-0.35 * lift + 0.6 * strike)
		elif attack == Attack.SWEEP:
			sprite.rotation = -0.35 + progress * 0.7
		elif attack == Attack.STING:
			var thrust := pow(clampf((progress - 0.65) / 0.35, 0.0, 1.0), 2.0)
			sprite.position += attack_direction * (-24.0 * sin(progress * PI) + 70.0 * thrust)
			sprite.scale *= Vector2(1.0 + thrust * 0.12, 1.0 - thrust * 0.1)
		elif attack == Attack.SUMMON:
			sprite.position.y -= sin(progress * PI) * 32.0
			sprite.modulate = Color.WHITE.lerp(Color(1.3, 0.8, 1.5), sin(progress * PI) * 0.6)
	elif attack == Attack.SLAM and impact_remaining > 0.0:
		var settle := impact_remaining / 0.65
		sprite.position += attack_direction * 160.0 * settle
		sprite.scale *= Vector2(1.0 + 0.22 * settle, 1.0 - 0.3 * settle)
		sprite.rotation = attack_direction.x * 0.25 * settle
	queue_redraw()
	if is_instance_valid(skill_effect_layer):
		if vulture_skills != null:
			vulture_skills.update_visuals()
		skill_effect_layer.queue_redraw()

func _draw_scorpion_windup() -> void:
	if boss_kind != MapMechanismDefs.SCARAB or state != AttackState.WINDUP:
		return
	var progress := clampf(1.0 - state_remaining / maxf(windup_total, 0.01), 0.0, 1.0)
	var center := to_local(get_hit_position())
	var gold := Color(1.0, 0.8, 0.35, 0.9)
	if attack == Attack.STING:
		var tip := center + attack_direction * (80.0 + progress * 160.0)
		var side := attack_direction.orthogonal() * 15.0
		skill_effect_layer.draw_colored_polygon(PackedVector2Array([center - side, tip, center + side]), gold)
	elif attack == Attack.SWEEP:
		var angle := attack_direction.angle() - 1.3 + progress * 2.6
		skill_effect_layer.draw_arc(Vector2.ZERO, sweep_radius * 0.8, angle - 0.7, angle, 20, gold, 12.0, true)
	elif attack == Attack.LEAP:
		var target := to_local(attack_target)
		skill_effect_layer.draw_arc(target, leap_radius * (1.0 - progress * 0.8), 0.0, TAU, 48, gold, 5.0, true)
	elif attack == Attack.SUMMON:
		skill_effect_layer.draw_arc(Vector2.ZERO, 190.0, -PI * 0.5, -PI * 0.5 + TAU * progress, 48, Color(0.85, 0.5, 1.0), 8.0, true)
		for i in range(4):
			var point := Vector2.RIGHT.rotated(i * TAU / 4.0) * 190.0
			skill_effect_layer.draw_circle(point, 12.0, gold)

func _update_health_label() -> void:
	health_label.hide()

func get_boss_display_name() -> String:
	if boss_kind == MapMechanismDefs.SANDSTORM:
		return "沙暴秃鹫"
	return "沙冠巨虫" if boss_kind == MapMechanismDefs.QUICKSAND else "金甲蝎王"

func get_boss_status_text() -> String:
	if vulture_skills != null and state == AttackState.WINDUP:
		match attack:
			Attack.GUST:
				return "风暴蓄力"
			Attack.DIVE:
				return "俯冲"
			Attack.CYCLONE:
				return "追踪沙旋"
	if is_invulnerable():
		return "硬壳无敌"
	if attack == Attack.SUMMON and state == AttackState.WINDUP:
		return "正在召唤圣甲虫"
	if boss_kind == MapMechanismDefs.SCARAB and level_refs != null:
		var controller := level_refs.get_scarab_mechanism_controller()
		if controller != null and controller.burst_owner == self and controller.burst_remaining > 0:
			return "虫群来袭 · 待出现 %d 只" % controller.burst_remaining
	return ""

func _die() -> void:
	AudioCue.play_sfx(&"success", -3.0)
	is_dead = true
	state = AttackState.RECOVERY
	collision_layer = 0
	collision_mask = 0
	for hazard in get_tree().get_nodes_in_group("quicksand_hazards"):
		if is_instance_valid(hazard) and hazard.boss_owner == self:
			hazard.remove_boss_enhancement()
	for projectile in get_tree().get_nodes_in_group("enemy_projectiles"):
		if is_instance_valid(projectile) and projectile.owner_enemy == self:
			projectile.queue_free()
	for group in ["boss_storm_hazards", "sandworm_tail_strikes"]:
		for hazard in get_tree().get_nodes_in_group(group):
			if is_instance_valid(hazard) and hazard.boss_owner == self:
				hazard.queue_free()
	defeated.emit(self, drop_item_id, drop_count, global_position)
	queue_free()

func _draw() -> void:
	if is_dead:
		return
	draw_circle(Vector2(0, 16), hit_radius, Color(0.08, 0.04, 0.03, 0.25))
	if vulture_skills != null:
		vulture_skills.draw_warning()
		return
	if is_invulnerable():
		draw_arc(Vector2.ZERO, hit_radius + 18.0, 0.0, TAU, 40, Color(1.0, 0.86, 0.28, 0.9), 6.0, true)
	if state != AttackState.WINDUP and state != AttackState.CHARGE and impact_remaining <= 0.0:
		return
	var origin := to_local(attack_origin)
	var target := to_local(attack_target)
	var fill := Color(0.95, 0.24, 0.06, 0.28 if impact_remaining <= 0.0 else 0.65)
	var outline := Color(1.0, 0.85, 0.48, 0.95)
	match attack:
		Attack.TAIL, Attack.LEAP:
			var radius: float = tail_strike_radius if attack == Attack.TAIL else leap_radius
			draw_circle(target, radius, fill)
			draw_arc(target, radius, 0.0, TAU, 48, outline, 4.0, true)
			if attack == Attack.TAIL:
				var progress := clampf(1.0 - state_remaining / maxf(windup_total, 0.01), 0.0, 1.0)
				for i in range(5):
					var ray := Vector2.RIGHT.rotated(float(i) * TAU / 5.0)
					draw_line(target + ray * 16.0, target + ray * radius * (0.3 + progress * 0.5), Color("b17d47"), 6.0, true)
		Attack.SLAM, Attack.RUSH:
			var length: float = slam_length if attack == Attack.SLAM else attack_origin.distance_to(attack_target)
			var width: float = slam_half_width if attack == Attack.SLAM else hit_radius + 20.0
			var side := attack_direction.orthogonal() * width
			var end := origin + attack_direction * length
			var points := PackedVector2Array([origin + side, end + side, end - side, origin - side])
			draw_colored_polygon(points, fill)
			points.append(points[0])
			draw_polyline(points, outline, 4.0, true)
			if attack == Attack.SLAM and impact_remaining > 0.0:
				var progress := 1.0 - impact_remaining / 0.65
				var front := origin + attack_direction * length * progress
				draw_line(front - side, front + side, Color(1.0, 0.8, 0.35, 1.0 - progress), 14.0, true)
				for i in range(10):
					var dust := origin + attack_direction * (float(i) / 10.0 * length) + side * sin(float(i) * 2.4) * (1.0 + progress)
					draw_circle(dust, 8.0 + progress * 22.0, Color(0.8, 0.59, 0.3, (1.0 - progress) * 0.75))
		Attack.STING, Attack.SWEEP:
			var radius: float = 390.0 if attack == Attack.STING else sweep_radius
			var half_angle: float = 0.32 if attack == Attack.STING else 1.3
			var points := PackedVector2Array([origin])
			for i in range(25):
				points.append(origin + attack_direction.rotated(lerpf(-half_angle, half_angle, float(i) / 24.0)) * radius)
			draw_colored_polygon(points, fill)
			points.append(origin)
			draw_polyline(points, outline, 4.0, true)
		Attack.NEEDLES:
			for i in range(7):
				draw_line(origin, origin + attack_direction.rotated((float(i)-3.0)*0.16) * 320.0, outline, 2.0, true)
