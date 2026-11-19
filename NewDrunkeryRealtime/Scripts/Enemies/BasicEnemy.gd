extends CharacterBody2D

const AudioCue = preload("res://Scripts/Audio/AudioCue.gd")

const TestItemDefs = preload("res://Scripts/Kitchen/TestItemDefs.gd")
const LevelRefs = preload("res://Scripts/Core/LevelRefs.gd")
const ZoneInteractionQuery = preload("res://Scripts/Core/ZoneInteractionQuery.gd")

signal defeated(enemy: Node2D, drop_item_id: StringName, drop_count: int, defeat_position: Vector2)

@export var max_health: int = 300
@export var move_speed: float = 120.0
@export var hit_radius: float = 36.0
@export var contact_damage_radius: float = 34.0
@export var contact_damage: int = 10
@export var contact_damage_interval: float = 0.28
@export var contact_stun_duration: float = 0.4
@export var player_push_distance: float = 34.0
@export var self_push_distance: float = 20.0
@export var movement_bounds: Rect2 = Rect2(Vector2.ZERO, Vector2(1792, 1152))
@export var edge_padding: Vector2 = Vector2(36, 36)
@export_range(0.0, 0.45, 0.01) var idle_edge_band_ratio: float = 0.0
@export var drop_item_id: StringName = TestItemDefs.MEAT_RED_ID
@export var drop_count_min: int = 1
@export var drop_count_max: int = 2
@export var detection_distance: float = 240.0
@export var wander_arrival_distance: float = 18.0
@export var wander_retarget_interval_min: float = 1.2
@export var wander_retarget_interval_max: float = 2.8

@onready var sprite: Sprite2D = $Sprite2D
@onready var health_label: Label = $HealthLabel
@onready var attack_range_visual: Node2D = $AttackRangeVisual

var current_health: int
var player: Node2D
var contact_cooldown_remaining: float = 0.0
var stun_remaining: float = 0.0
var is_dead: bool = false
var feedback_tween: Tween
var wander_target_position: Vector2 = Vector2.ZERO
var wander_retarget_remaining: float = 0.0
var rng := RandomNumberGenerator.new()
var prototype_map: Node
var level_refs: LevelRefs
var base_sprite_position: Vector2 = Vector2.ZERO
var base_sprite_scale: Vector2 = Vector2.ONE
var facing_direction: Vector2 = Vector2.RIGHT

func _ready() -> void:
	add_to_group("damageables")
	add_to_group("enemies")
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	current_health = max_health
	rng.randomize()
	wander_target_position = global_position
	if is_instance_valid(attack_range_visual):
		attack_range_visual.visible = false
	_find_player()
	_resolve_level_refs()
	base_sprite_position = sprite.position
	base_sprite_scale = sprite.scale
	facing_direction = Vector2.LEFT if sprite.flip_h else Vector2.RIGHT
	_update_health_label()
	preload("res://Scripts/Enemies/EnemyPresentation.gd").attach(self)

func _process(delta: float) -> void:
	contact_cooldown_remaining = maxf(contact_cooldown_remaining - delta, 0.0)
	stun_remaining = maxf(stun_remaining - delta, 0.0)
	wander_retarget_remaining = maxf(wander_retarget_remaining - delta, 0.0)

func _physics_process(_delta: float) -> void:
	if preload("res://Scripts/Facilities/FacilityControlEffect.gd").rooted(self):
		velocity = Vector2.ZERO
		return
	if not player:
		_find_player()

	if is_dead or not player:
		velocity = Vector2.ZERO
		return

	var player_point: Vector2 = player.global_position
	if player.has_method("get_sort_origin"):
		player_point = player.get_sort_origin()
	var is_player_detected: bool = (
		_is_point_within_bounds(player_point)
		and global_position.distance_to(player_point) <= detection_distance
	)
	var target_position: Vector2 = player.global_position if is_player_detected else _get_wander_target_position()
	var to_target: Vector2 = target_position - global_position
	var distance_to_target: float = to_target.length()
	var facing_input: Vector2 = facing_direction

	if stun_remaining > 0.0:
		velocity = Vector2.ZERO
	elif is_player_detected and distance_to_target <= contact_damage_radius:
		velocity = Vector2.ZERO
		_try_contact_damage(to_target)
	else:
		if not is_player_detected and distance_to_target <= wander_arrival_distance:
			velocity = Vector2.ZERO
		else:
			velocity = to_target.normalized() * move_speed

	if velocity.length_squared() > 0.001:
		facing_input = velocity
	elif is_player_detected and distance_to_target > contact_damage_radius + 8.0:
		facing_input = to_target

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

func _find_player() -> void:
	var found_player: Node = get_tree().get_first_node_in_group("player")
	if found_player is Node2D:
		player = found_player

func _resolve_level_refs() -> void:
	level_refs = LevelRefs.find_from(self)
	if level_refs != null:
		prototype_map = level_refs.get_prototype_map()

func _try_contact_damage(to_player: Vector2) -> void:
	if contact_cooldown_remaining > 0.0:
		return

	if not player.has_method("take_damage"):
		return
	if not _can_damage_player_across_zones():
		return

	var push_direction: Vector2 = to_player.normalized() if to_player.length_squared() > 0.001 else Vector2.RIGHT
	var was_applied: Variant = player.take_damage(contact_damage, push_direction, &"contact")
	if was_applied is bool and not was_applied:
		return

	_apply_contact_separation(push_direction)
	contact_cooldown_remaining = contact_damage_interval
	stun_remaining = contact_stun_duration
	_play_contact_feedback()

func _apply_contact_separation(push_direction: Vector2) -> void:
	global_position -= push_direction * self_push_distance
	_clamp_to_map_bounds()

	if player and player.has_method("apply_contact_push"):
		player.apply_contact_push(push_direction, player_push_distance)

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

func _update_facing(to_player: Vector2) -> void:
	if absf(to_player.x) > 8.0:
		facing_direction = Vector2.LEFT if to_player.x < 0.0 else Vector2.RIGHT
		sprite.flip_h = to_player.x < 0.0

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
	feedback_tween.tween_property(sprite, "modulate", Color.WHITE, 0.12)
	feedback_tween.tween_property(sprite, "scale", base_sprite_scale, 0.12)
	feedback_tween.tween_property(sprite, "position", base_sprite_position, 0.12)

func _play_contact_feedback() -> void:
	if feedback_tween:
		feedback_tween.kill()

	sprite.modulate = Color(1.0, 0.9, 0.45, 1.0)
	sprite.scale = Vector2(base_sprite_scale.x * 1.08, base_sprite_scale.y * 0.92)
	sprite.position = base_sprite_position

	feedback_tween = create_tween()
	feedback_tween.set_parallel(true)
	feedback_tween.tween_property(sprite, "modulate", Color.WHITE, 0.1)
	feedback_tween.tween_property(sprite, "scale", base_sprite_scale, 0.1)

func _die() -> void:
	AudioCue.at(self, &"enemy_down", -6.0)
	is_dead = true
	collision_layer = 0
	collision_mask = 0
	visible = false
	velocity = Vector2.ZERO
	stun_remaining = 0.0
	contact_cooldown_remaining = 0.0
	var clamped_drop_min: int = max(drop_count_min, 0)
	var clamped_drop_max: int = max(drop_count_max, clamped_drop_min)
	var drop_count: int = randi_range(clamped_drop_min, clamped_drop_max)
	defeated.emit(self, drop_item_id, drop_count, global_position)
	queue_free()
