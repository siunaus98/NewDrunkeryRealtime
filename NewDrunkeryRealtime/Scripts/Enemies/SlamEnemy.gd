extends CharacterBody2D

const AudioCue = preload("res://Scripts/Audio/AudioCue.gd")

const TestItemDefs = preload("res://Scripts/Kitchen/TestItemDefs.gd")
const LINGERING_HAZARD_SCENE := preload("res://Scenes/Enemies/lingering_hazard.tscn")
const LevelRefs = preload("res://Scripts/Core/LevelRefs.gd")
const ZoneInteractionQuery = preload("res://Scripts/Core/ZoneInteractionQuery.gd")

signal defeated(enemy: Node2D, drop_item_id: StringName, drop_count: int, defeat_position: Vector2)

enum AttackState {
	CHASE,
	WINDUP,
	RECOVERY
}

@export var max_health: int = 400
@export var move_speed: float = 86.4
@export var hit_radius: float = 40.0
@export var movement_bounds: Rect2 = Rect2(Vector2.ZERO, Vector2(1792, 1152))
@export var edge_padding: Vector2 = Vector2(36, 36)
@export_range(0.0, 0.45, 0.01) var idle_edge_band_ratio: float = 0.0
@export var drop_item_id: StringName = TestItemDefs.MEAT_RED_ID
@export var drop_count_min: int = 1
@export var drop_count_max: int = 2
@export var detection_distance: float = 260.0
@export var slam_trigger_distance: float = 190.0
@export var slam_radius: float = 86.0
@export var slam_damage: int = 20
@export var slam_cooldown: float = 2.6
@export var slam_windup_duration: float = 0.95
@export var slam_recovery_duration: float = 0.7
@export var lingering_hazard_radius: float = 92.0
@export var lingering_hazard_duration: float = 4.2
@export var lingering_hazard_tick_interval: float = 0.55
@export var lingering_hazard_damage: int = 10
@export var wander_arrival_distance: float = 18.0
@export var wander_retarget_interval_min: float = 1.0
@export var wander_retarget_interval_max: float = 2.3

@onready var sprite: Sprite2D = $Sprite2D
@onready var health_label: Label = $HealthLabel
@onready var warning_circle: Node2D = $GroundWarningCircle

const SPECIAL_MODULATE: Color = Color(1.28, 0.72, 0.72, 1.0)

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
var slam_target_position: Vector2 = Vector2.ZERO
var slam_hit_applied: bool = false
var facing_direction: Vector2 = Vector2.RIGHT

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
	if is_instance_valid(warning_circle):
		warning_circle.visible = false
		if warning_circle.has_method("set_radius"):
			warning_circle.set_radius(slam_radius)
	_find_player()
	_update_health_label()
	preload("res://Scripts/Enemies/EnemyPresentation.gd").attach(self)

func _process(delta: float) -> void:
	attack_cooldown_remaining = maxf(attack_cooldown_remaining - delta, 0.0)
	wander_retarget_remaining = maxf(wander_retarget_remaining - delta, 0.0)
	state_time_remaining = maxf(state_time_remaining - delta, 0.0)
	if attack_state == AttackState.WINDUP and is_instance_valid(warning_circle) and warning_circle.has_method("set_progress_ratio"):
		var duration: float = maxf(slam_windup_duration, 0.001)
		var progress: float = 1.0 - state_time_remaining / duration
		warning_circle.set_progress_ratio(progress)

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
			facing_input = slam_target_position - global_position
			if state_time_remaining <= 0.0:
				_resolve_slam()
				_enter_recovery()
		AttackState.RECOVERY:
			velocity = Vector2.ZERO
			facing_input = slam_target_position - global_position
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
	if attack_cooldown_remaining <= 0.0 and distance_to_player <= slam_trigger_distance:
		_start_windup(player_point)
		velocity = Vector2.ZERO
		return

	velocity = to_player.normalized() * move_speed if distance_to_player > 0.001 else Vector2.ZERO

func _start_windup(target_point: Vector2) -> void:
	attack_state = AttackState.WINDUP
	state_time_remaining = slam_windup_duration
	slam_target_position = target_point.clamp(
		movement_bounds.position + edge_padding,
		movement_bounds.position + movement_bounds.size - edge_padding
	)
	slam_hit_applied = false
	if is_instance_valid(warning_circle):
		warning_circle.global_position = slam_target_position
		warning_circle.set_active(true)
		if warning_circle.has_method("set_progress_ratio"):
			warning_circle.set_progress_ratio(0.0)

func _resolve_slam() -> void:
	AudioCue.at(self, &"impact", -5.0)
	if slam_hit_applied:
		return
	slam_hit_applied = true
	if is_instance_valid(warning_circle):
		warning_circle.set_active(false)
	_spawn_lingering_hazard()
	if not is_instance_valid(player):
		return
	if not _can_damage_player_across_zones():
		return

	var player_point: Vector2 = player.global_position
	if player.has_method("get_sort_origin"):
		player_point = player.get_sort_origin()
	if player_point.distance_to(slam_target_position) > slam_radius:
		return
	if not player.has_method("take_damage"):
		return

	var push_direction: Vector2 = (player_point - slam_target_position).normalized()
	if push_direction.length_squared() <= 0.001:
		push_direction = Vector2.RIGHT
	var was_applied: Variant = player.take_damage(slam_damage, push_direction, &"special")
	if was_applied is bool and not was_applied:
		return
	if player.has_method("apply_contact_push"):
		player.apply_contact_push(push_direction, 34.0)

func _spawn_lingering_hazard() -> void:
	var scene_root: Node = level_refs.get_runtime_root() if level_refs != null else get_parent()
	if scene_root == null:
		return

	var hazard: Area2D = LINGERING_HAZARD_SCENE.instantiate()
	scene_root.add_child(hazard)
	if hazard.has_method("setup_hazard"):
		hazard.setup_hazard(
			slam_target_position,
			lingering_hazard_radius,
			lingering_hazard_duration,
			lingering_hazard_tick_interval,
			lingering_hazard_damage,
			movement_bounds,
			prototype_map,
			self
		)

func _enter_recovery() -> void:
	attack_state = AttackState.RECOVERY
	state_time_remaining = slam_recovery_duration
	attack_cooldown_remaining = slam_cooldown
	velocity = Vector2.ZERO

func _enter_chase() -> void:
	attack_state = AttackState.CHASE
	state_time_remaining = 0.0

func _find_player() -> void:
	var found_player: Node = get_tree().get_first_node_in_group("player")
	if found_player is Node2D:
		player = found_player

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

func _can_damage_player_across_zones() -> bool:
	if not is_instance_valid(prototype_map):
		_resolve_level_refs()
	return ZoneInteractionQuery.can_points_interact(prototype_map, global_position, ZoneInteractionQuery.get_node_point(player))

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
	sprite.modulate = Color(1.0, 0.55, 0.45, 1.0)
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
	if is_instance_valid(warning_circle):
		warning_circle.set_active(false)
	var clamped_drop_min: int = max(drop_count_min, 0)
	var clamped_drop_max: int = max(drop_count_max, clamped_drop_min)
	var drop_count: int = randi_range(clamped_drop_min, clamped_drop_max)
	defeated.emit(self, drop_item_id, drop_count, global_position)
	queue_free()
