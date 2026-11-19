extends CharacterBody2D

const AudioCue = preload("res://Scripts/Audio/AudioCue.gd")

const TestItemDefs = preload("res://Scripts/Kitchen/TestItemDefs.gd")
const PROJECTILE_SCENE := preload("res://Scenes/Enemies/enemy_projectile.tscn")
const LevelRefs = preload("res://Scripts/Core/LevelRefs.gd")

signal defeated(enemy: Node2D, drop_item_id: StringName, drop_count: int, defeat_position: Vector2)

enum AttackState {
	CHASE,
	WINDUP,
	RECOVERY
}

enum BulletPattern {
	FIXED_FAN,
	HOMING_FAN
}

const SPECIAL_MODULATE: Color = Color(0.9, 0.72, 1.22, 1.0)

@export var max_health: int = 400
@export var move_speed: float = 78.4
@export var hit_radius: float = 34.0
@export var movement_bounds: Rect2 = Rect2(Vector2.ZERO, Vector2(1792, 1152))
@export var edge_padding: Vector2 = Vector2(36, 36)
@export_range(0.0, 0.45, 0.01) var idle_edge_band_ratio: float = 0.0
@export var drop_item_id: StringName = TestItemDefs.MEAT_RED_ID
@export var drop_count_min: int = 1
@export var drop_count_max: int = 2
@export var detection_distance: float = 400.0
@export var bullet_trigger_distance: float = 360.0
@export var preferred_min_distance: float = 180.0
@export var preferred_max_distance: float = 300.0
@export var shoot_cooldown: float = 2.8
@export var windup_duration: float = 0.92
@export var recovery_duration: float = 0.72
@export var bullet_speed: float = 224.0
@export var bullet_damage: int = 10
@export var bullet_radius: float = 13.0
@export var bullet_range: float = 520.0
@export var bullet_count: int = 5
@export var bullet_spread_degrees: float = 48.0
@export var bullet_interval: float = 0.14
@export var homing_turn_strength: float = 3.8
@export var homing_max_turn_rate_degrees: float = 92.0
@export var wander_arrival_distance: float = 18.0
@export var wander_retarget_interval_min: float = 1.0
@export var wander_retarget_interval_max: float = 2.4
@export var strafe_hold_duration_min: float = 0.45
@export var strafe_hold_duration_max: float = 1.05

@onready var sprite: Sprite2D = $Sprite2D
@onready var health_label: Label = $HealthLabel
@onready var telegraph: Node2D = $BulletTelegraph

var current_health: int
var player: Node2D
var prototype_map: Node
var level_refs: LevelRefs
var is_dead: bool = false
var feedback_tween: Tween
var base_sprite_position: Vector2 = Vector2.ZERO
var base_sprite_scale: Vector2 = Vector2.ONE
var rng := RandomNumberGenerator.new()
var wander_target_position: Vector2 = Vector2.ZERO
var wander_retarget_remaining: float = 0.0
var attack_state: int = AttackState.CHASE
var attack_cooldown_remaining: float = 0.0
var state_time_remaining: float = 0.0
var bullet_pattern: BulletPattern = BulletPattern.FIXED_FAN
var bullet_queue: Array[Dictionary] = []
var bullet_queue_time: float = 0.0
var queued_attack_origin: Vector2 = Vector2.ZERO
var facing_direction: Vector2 = Vector2.RIGHT
var locked_attack_direction: Vector2 = Vector2.RIGHT
var strafe_sign: float = 1.0
var strafe_hold_remaining: float = 0.0
var unresolved_barrage_projectiles: int = 0
var barrage_hit_player: bool = false

func _ready() -> void:
	add_to_group("damageables")
	add_to_group("enemies")
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	current_health = max_health
	base_sprite_position = sprite.position
	base_sprite_scale = sprite.scale
	rng.randomize()
	wander_target_position = global_position
	_resolve_level_refs()
	sprite.modulate = SPECIAL_MODULATE
	facing_direction = Vector2.LEFT if sprite.flip_h else Vector2.RIGHT
	locked_attack_direction = facing_direction
	strafe_sign = -1.0 if int(rng.randi() % 2) == 0 else 1.0
	if is_instance_valid(telegraph):
		telegraph.visible = false
		telegraph.modulate = Color(1.0, 1.0, 1.0, 0.95)
	_find_player()
	_update_health_label()
	preload("res://Scripts/Enemies/EnemyPresentation.gd").attach(self)

func _process(delta: float) -> void:
	attack_cooldown_remaining = maxf(attack_cooldown_remaining - delta, 0.0)
	wander_retarget_remaining = maxf(wander_retarget_remaining - delta, 0.0)
	state_time_remaining = maxf(state_time_remaining - delta, 0.0)
	bullet_queue_time = maxf(bullet_queue_time - delta, 0.0)
	strafe_hold_remaining = maxf(strafe_hold_remaining - delta, 0.0)

	if attack_state == AttackState.WINDUP and is_instance_valid(telegraph) and telegraph.has_method("set_progress_ratio"):
		var duration: float = maxf(windup_duration, 0.001)
		var progress: float = 1.0 - state_time_remaining / duration
		telegraph.set_progress_ratio(progress)

	if attack_state == AttackState.WINDUP and bullet_queue_time <= 0.0 and not bullet_queue.is_empty():
		_fire_next_bullet()

func _physics_process(_delta: float) -> void:
	if preload("res://Scripts/Facilities/FacilityControlEffect.gd").rooted(self):
		velocity = Vector2.ZERO
		return
	if not is_instance_valid(player):
		_find_player()

	if is_dead or not is_instance_valid(player):
		velocity = Vector2.ZERO
		return

	var player_point: Vector2 = player.global_position
	if player.has_method("get_sort_origin"):
		player_point = player.get_sort_origin()
	var is_player_detected: bool = (
		_is_point_within_bounds(player_point)
		and global_position.distance_to(player_point) <= detection_distance
	)
	var to_player: Vector2 = player.global_position - global_position
	var facing_input: Vector2 = facing_direction

	match attack_state:
		AttackState.WINDUP:
			velocity = Vector2.ZERO
			facing_input = locked_attack_direction
			if state_time_remaining <= 0.0 and bullet_queue.is_empty():
				_end_attack_sequence()
		AttackState.RECOVERY:
			velocity = Vector2.ZERO
			facing_input = locked_attack_direction
			if state_time_remaining <= 0.0:
				_enter_chase()
		_:
			_run_non_attack_logic(is_player_detected, to_player, player_point)
			if velocity.length_squared() > 0.001:
				facing_input = velocity
			elif is_player_detected:
				facing_input = to_player

	velocity *= preload("res://Scripts/Facilities/FacilityControlEffect.gd").speed(self)
	move_and_slide()
	_clamp_to_map_bounds()
	_update_facing(facing_input)

func receive_hit(damage: int, hit_direction: Vector2 = Vector2.ZERO) -> void:
	damage = preload("res://Scripts/Facilities/FacilityControlEffect.gd").damage(self, damage)
	if is_dead:
		return

	current_health = max(current_health - damage, 0)
	_update_health_label()
	_play_hit_feedback(hit_direction)
	if current_health <= 0:
		_die()

func get_hit_position() -> Vector2:
	return global_position

func get_hit_radius() -> float:
	return hit_radius

func set_movement_bounds(bounds: Rect2) -> void:
	movement_bounds = bounds

func get_movement_bounds() -> Rect2:
	return movement_bounds

func setup_for_battle(new_drop_item_id: StringName, bounds: Rect2, wave_index: int = 0, speed_bonus_per_wave: float = 0.0, health_bonus_per_wave: int = 0) -> void:
	drop_item_id = new_drop_item_id
	set_movement_bounds(bounds)
	wander_target_position = global_position.clamp(
		_get_wander_bounds().position,
		_get_wander_bounds().position + _get_wander_bounds().size
	)
	wander_retarget_remaining = 0.0
	max_health += max(wave_index, 0) * max(health_bonus_per_wave, 0)
	current_health = max_health
	move_speed += max(wave_index, 0) * maxf(speed_bonus_per_wave, 0.0)
	_update_health_label()

func set_bullet_pattern(new_pattern: BulletPattern) -> void:
	bullet_pattern = new_pattern

func _run_non_attack_logic(is_player_detected: bool, to_player: Vector2, player_point: Vector2) -> void:
	if not is_player_detected:
		var wander_target: Vector2 = _get_wander_target_position()
		var to_wander: Vector2 = wander_target - global_position
		if to_wander.length() <= wander_arrival_distance:
			velocity = Vector2.ZERO
		else:
			velocity = to_wander.normalized() * move_speed
		return

	var distance_to_player: float = to_player.length()
	if attack_cooldown_remaining <= 0.0 and distance_to_player <= bullet_trigger_distance and distance_to_player >= preferred_min_distance * 0.68:
		_start_windup(player_point)
		velocity = Vector2.ZERO
		return

	if distance_to_player > preferred_max_distance:
		velocity = to_player.normalized() * move_speed
		return
	if distance_to_player < preferred_min_distance:
		velocity = (-to_player).normalized() * move_speed * 0.82 if distance_to_player > 0.001 else Vector2.ZERO
		return

	var strafe_direction: Vector2 = to_player.orthogonal().normalized()
	if strafe_direction.length_squared() <= 0.001:
		velocity = Vector2.ZERO
	else:
		if strafe_hold_remaining <= 0.0:
			strafe_sign = -1.0 if int(rng.randi() % 2) == 0 else 1.0
			strafe_hold_remaining = rng.randf_range(strafe_hold_duration_min, strafe_hold_duration_max)
		velocity = strafe_direction * strafe_sign * move_speed * 0.42

func _start_windup(target_point: Vector2) -> void:
	attack_state = AttackState.WINDUP
	state_time_remaining = windup_duration
	_notify_bullet_warning_started(windup_duration)
	unresolved_barrage_projectiles = 0
	barrage_hit_player = false
	queued_attack_origin = global_position
	bullet_pattern = BulletPattern.FIXED_FAN if rng.randf() < 0.55 else BulletPattern.HOMING_FAN
	if is_instance_valid(telegraph):
		telegraph.rotation = (target_point - global_position).angle()
		if telegraph.has_method("set_length"):
			telegraph.set_length(bullet_range)
		if telegraph.has_method("set_progress_ratio"):
			telegraph.set_progress_ratio(0.0)
		telegraph.modulate = Color(1.0, 0.42, 0.42, 0.95) if bullet_pattern == BulletPattern.FIXED_FAN else Color(0.82, 0.52, 1.0, 0.95)
		telegraph.visible = true

	bullet_queue.clear()
	var base_direction: Vector2 = target_point - global_position
	if base_direction.length_squared() <= 0.001:
		base_direction = Vector2.RIGHT
	else:
		base_direction = base_direction.normalized()
	locked_attack_direction = base_direction

	var use_homing_pattern: bool = bullet_pattern == BulletPattern.HOMING_FAN
	var half_spread: float = deg_to_rad(bullet_spread_degrees * 0.5)
	var bullet_total: int = 1 if use_homing_pattern else max(bullet_count, 1)
	for i in range(bullet_total):
		var t: float = 0.0 if bullet_total == 1 else float(i) / float(bullet_total - 1)
		var angle_offset: float = 0.0 if use_homing_pattern else lerpf(-half_spread, half_spread, t)
		var launch_direction: Vector2 = base_direction.rotated(angle_offset)
		bullet_queue.append({
			"direction": launch_direction,
			"mode": bullet_pattern,
			"speed": bullet_speed,
			"range": bullet_range,
			"damage": bullet_damage,
			"radius": bullet_radius,
			"turn_strength": homing_turn_strength,
			"turn_rate": homing_max_turn_rate_degrees
		})

	bullet_queue_time = 0.0
	_fire_next_bullet()

func _fire_next_bullet() -> void:
	if bullet_queue.is_empty():
		return

	var scene_root: Node = level_refs.get_runtime_root() if level_refs != null else get_parent()
	if scene_root == null:
		return

	var bullet_data: Dictionary = bullet_queue.pop_front()
	var projectile: Area2D = PROJECTILE_SCENE.instantiate()
	scene_root.add_child(projectile)
	if projectile.has_signal("projectile_resolved"):
		projectile.projectile_resolved.connect(_on_barrage_projectile_resolved)
		unresolved_barrage_projectiles += 1
	var launch_direction: Vector2 = Vector2(bullet_data.get("direction", Vector2.RIGHT))
	var spawn_position: Vector2 = queued_attack_origin + launch_direction * (hit_radius + bullet_radius + 10.0)
	var mode_value: int = 1 if bullet_data.get("mode", BulletPattern.FIXED_FAN) == BulletPattern.HOMING_FAN else 0
	if projectile.has_method("setup_projectile"):
		projectile.setup_projectile(
			spawn_position,
			launch_direction,
			float(bullet_data.get("speed", bullet_speed)),
			float(bullet_data.get("range", bullet_range)),
			int(bullet_data.get("damage", bullet_damage)),
			float(bullet_data.get("radius", bullet_radius)),
			movement_bounds,
			prototype_map,
			self,
			mode_value,
			float(bullet_data.get("turn_strength", homing_turn_strength)),
			float(bullet_data.get("turn_rate", homing_max_turn_rate_degrees))
		)
	if bullet_data.get("mode", BulletPattern.FIXED_FAN) == BulletPattern.FIXED_FAN:
		projectile.set("fill_color", Color(1.0, 0.2, 0.2, 0.92))
		projectile.set("outline_color", Color(1.0, 0.9, 0.84, 1.0))
		projectile.set("trail_color", Color(1.0, 0.42, 0.32, 0.38))
	else:
		projectile.set("fill_color", Color(0.72, 0.28, 1.0, 0.9))
		projectile.set("outline_color", Color(0.95, 0.9, 1.0, 1.0))
		projectile.set("trail_color", Color(0.82, 0.48, 1.0, 0.42))

	bullet_queue_time = bullet_interval
	if bullet_queue.is_empty():
		state_time_remaining = maxf(state_time_remaining, bullet_interval)

func _end_attack_sequence() -> void:
	if is_instance_valid(telegraph):
		telegraph.visible = false
	attack_state = AttackState.RECOVERY
	state_time_remaining = recovery_duration
	attack_cooldown_remaining = shoot_cooldown
	velocity = Vector2.ZERO

func _enter_chase() -> void:
	attack_state = AttackState.CHASE
	state_time_remaining = 0.0

func _find_player() -> void:
	var found_player: Node = get_tree().get_first_node_in_group("player")
	if found_player is Node2D:
		player = found_player

func _notify_bullet_warning_started(duration: float) -> void:
	if not is_instance_valid(player) or not player.has_method("get_blessing_controller"):
		return
	var blessing_runtime: RefCounted = player.get_blessing_controller()
	if blessing_runtime != null:
		blessing_runtime.on_bullet_warning_started(duration)

func _on_barrage_projectile_resolved(hit_player: bool) -> void:
	barrage_hit_player = barrage_hit_player or hit_player
	unresolved_barrage_projectiles = maxi(unresolved_barrage_projectiles - 1, 0)
	if unresolved_barrage_projectiles > 0 or not bullet_queue.is_empty() or barrage_hit_player:
		return
	if not is_instance_valid(player) or not player.has_method("get_blessing_controller"):
		return
	var blessing_runtime: RefCounted = player.get_blessing_controller()
	if blessing_runtime != null:
		blessing_runtime.on_bullet_dodged()

func _resolve_level_refs() -> void:
	level_refs = LevelRefs.find_from(self)
	if level_refs != null:
		prototype_map = level_refs.get_prototype_map()

func _clamp_to_map_bounds() -> void:
	var min_pos: Vector2 = movement_bounds.position + edge_padding
	var max_pos: Vector2 = movement_bounds.position + movement_bounds.size - edge_padding
	global_position = global_position.clamp(min_pos, max_pos)

func _is_point_within_bounds(point: Vector2) -> bool:
	var min_pos: Vector2 = movement_bounds.position + edge_padding
	var max_pos: Vector2 = movement_bounds.position + movement_bounds.size - edge_padding
	return (
		point.x >= min_pos.x
		and point.x <= max_pos.x
		and point.y >= min_pos.y
		and point.y <= max_pos.y
	)

func _get_wander_target_position() -> Vector2:
	var need_new_target: bool = wander_retarget_remaining <= 0.0 or global_position.distance_to(wander_target_position) <= wander_arrival_distance
	if need_new_target:
		var wander_bounds := _get_wander_bounds()
		var min_pos: Vector2 = wander_bounds.position
		var max_pos: Vector2 = wander_bounds.position + wander_bounds.size
		wander_target_position = Vector2(
			rng.randf_range(min_pos.x, max_pos.x),
			rng.randf_range(min_pos.y, max_pos.y)
		)
		wander_retarget_remaining = rng.randf_range(wander_retarget_interval_min, wander_retarget_interval_max)
	return wander_target_position

func _get_wander_bounds() -> Rect2:
	var band := Vector2(movement_bounds.size.x * idle_edge_band_ratio, movement_bounds.size.y * idle_edge_band_ratio)
	var padding := Vector2(maxf(edge_padding.x, band.x), maxf(edge_padding.y, band.y))
	var size := movement_bounds.size - padding * 2.0
	if size.x <= 0.0 or size.y <= 0.0:
		return Rect2(movement_bounds.get_center(), Vector2.ZERO)
	return Rect2(movement_bounds.position + padding, size)

func _update_facing(direction: Vector2) -> void:
	if absf(direction.x) > 0.01:
		facing_direction = Vector2.LEFT if direction.x < 0.0 else Vector2.RIGHT
		sprite.flip_h = direction.x < 0.0

func _update_health_label() -> void:
	preload("res://Scripts/UI/HealthBar.gd").update_overhead(health_label, current_health, max_health)

func _play_hit_feedback(hit_direction: Vector2) -> void:
	preload("res://Scripts/Enemies/HitSpark.gd").emit_at(self, hit_direction)
	if feedback_tween:
		feedback_tween.kill()

	var sprite_offset: Vector2 = hit_direction.normalized() * 14.0 if hit_direction.length_squared() > 0.001 else Vector2.ZERO
	sprite.modulate = Color(1.0, 0.62, 0.92, 1.0)
	sprite.scale = base_sprite_scale * 1.12
	sprite.position = base_sprite_position + sprite_offset

	feedback_tween = create_tween()
	feedback_tween.set_parallel(true)
	feedback_tween.tween_property(sprite, "modulate", SPECIAL_MODULATE, 0.12)
	feedback_tween.tween_property(sprite, "scale", base_sprite_scale, 0.12)
	feedback_tween.tween_property(sprite, "position", base_sprite_position, 0.12)

func _die() -> void:
	AudioCue.at(self, &"enemy_down", -6.0)
	is_dead = true
	collision_layer = 0
	collision_mask = 0
	visible = false
	velocity = Vector2.ZERO
	if is_instance_valid(telegraph):
		telegraph.visible = false
	var clamped_drop_min: int = max(drop_count_min, 0)
	var clamped_drop_max: int = max(drop_count_max, clamped_drop_min)
	var drop_count: int = randi_range(clamped_drop_min, clamped_drop_max)
	defeated.emit(self, drop_item_id, drop_count, global_position)
	queue_free()
