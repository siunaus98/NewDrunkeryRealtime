extends CharacterBody2D

const AudioCue = preload("res://Scripts/Audio/AudioCue.gd")

const TestItemDefs = preload("res://Scripts/Kitchen/TestItemDefs.gd")
const LevelRefs = preload("res://Scripts/Core/LevelRefs.gd")
const ZoneInteractionQuery = preload("res://Scripts/Core/ZoneInteractionQuery.gd")
const SupportFacilityAuraQuery = preload("res://Scripts/Core/SupportFacilityAuraQuery.gd")
const PlayerInteractionController = preload("res://Scripts/Player/PlayerInteractionController.gd")
const PlayerCombatController = preload("res://Scripts/Player/PlayerCombatController.gd")
const PlayerInputGate = preload("res://Scripts/Player/PlayerInputGate.gd")
const PlayerSkillController = preload("res://Scripts/Player/PlayerSkillController.gd")
const PlayerBuffIndicator = preload("res://Scripts/Player/PlayerBuffIndicator.gd")
const PlayerPushController = preload("res://Scripts/Player/PlayerPushController.gd")
const PlayerStormController = preload("res://Scripts/Player/PlayerStormController.gd")
const PlayerFacilityPreviewController = preload("res://Scripts/Player/PlayerFacilityPreviewController.gd")
const PlayerFacilityCarryController = preload("res://Scripts/Player/PlayerFacilityCarryController.gd")
const LevelContext = preload("res://Scripts/Core/LevelContext.gd")
const BlessingDefs = preload("res://Scripts/Progression/BlessingDefs.gd")
const BlessingRuntimeController = preload("res://Scripts/Progression/BlessingRuntimeController.gd")

@export var move_speed: float = 336.0
@export var max_health: int = 100
@export var movement_bounds: Rect2 = Rect2(Vector2.ZERO, Vector2(1792, 1152))
@export var edge_padding: Vector2 = Vector2(24, 24)
@export var map_edge_air_wall_padding: Vector2 = Vector2.ZERO
@export var collision_safe_margin: float = 0.01
@export var movement_substep_pixels: float = 6.0
@export var contact_immunity_duration: float = 0.32
@export var attack_damage: int = 100
@export var attack_origin_offset: Vector2 = Vector2(0, -34)
@export var attack_inner_radius: float = 42.0
@export var attack_outer_radius: float = 145.0
@export var attack_angle_degrees: float = 82.0
@export var attack_cooldown: float = 0.18
@export var light_attack_release_window: float = 0.22
@export var light_attack_damage_multiplier: float = 0.65
@export var light_attack_auto_aim_angle_degrees: float = 220.0
@export var light_attack_close_auto_aim_radius: float = 104.0
@export var heavy_charge_full_duration: float = 0.85
@export var heavy_charge_overhold_duration: float = 0.8
@export var heavy_charge_move_slow_min: float = 0.82
@export var heavy_charge_move_slow_max: float = 0.42
@export var heavy_damage_multiplier_min: float = 1.25
@export var heavy_damage_multiplier_max: float = 2.2
@export var attack_snap_input_grace_duration: float = 0.12
@export var attack_auto_aim_angle_degrees: float = 150.0
@export var dash_speed_multiplier: float = 3.6
@export var dash_duration: float = 0.16
@export var dash_cooldown: float = 1.08
@export var interaction_radius: float = 80.0
@export var interaction_angle_degrees: float = 64.0
@export var interaction_origin_offset: Vector2 = Vector2(0, -34)
@export var floor_interaction_radius: float = 86.0
@export var show_interaction_range: bool = false
@export var interaction_range_fill_color: Color = Color(0.28, 0.85, 1.0, 0.11)
@export var interaction_range_edge_color: Color = Color(0.42, 0.95, 1.0, 0.42)
@export var interaction_range_circle_color: Color = Color(0.42, 0.95, 1.0, 0.22)
@export var show_item_push_debug: bool = false
@export var item_push_debug_fill_color: Color = Color(1.0, 0.44, 0.22, 0.10)
@export var item_push_debug_outline_color: Color = Color(1.0, 0.62, 0.36, 0.88)
@export var item_push_margin: float = 8.0
@export var item_push_acceleration: float = 5400.0
@export var item_push_min_speed: float = 24.0
@export var item_push_overlap_bias: float = 2.5
@export var item_push_low_speed_multiplier: float = 0.08
@export var item_push_high_speed_multiplier: float = 0.58
@export var item_push_speed_curve: float = 1.55
@export var dash_nearby_push_multiplier: float = 8.0
@export var dash_nearby_push_ahead_margin: float = 0.05
@export var dash_horizontal_push_force_multiplier: float = 1.7
@export var small_skill_cooldown: float = 15.0
@export var small_skill_magic_cost: int = 2
@export var small_skill_speed_multiplier: float = 1.4
@export var small_skill_speed_duration: float = 2.0
@export var big_skill_buff_duration: float = 10.0
@export var carried_facility_preview_body_offset: Vector2 = Vector2(0, -22)
@export var carried_facility_preview_max_size: Vector2 = Vector2(132, 112)
@export_range(0.0, 1.0, 0.05) var facility_preview_tint_strength: float = 0.8
@export var facility_place_valid_color: Color = Color(1.0, 0.78, 0.22, 0.32)
@export var facility_place_invalid_color: Color = Color(1.0, 0.18, 0.12, 0.34)
@export var facility_place_outline_valid_color: Color = Color(1.0, 0.92, 0.48, 0.92)
@export var facility_place_outline_invalid_color: Color = Color(1.0, 0.24, 0.16, 0.95)
@export var facility_place_origin_color: Color = Color(0.22, 0.68, 1.0, 0.30)
@export var facility_place_origin_outline_color: Color = Color(0.48, 0.9, 1.0, 0.86)
@export var facility_place_player_eject_step: float = 24.0
@export var facility_place_player_eject_rings: int = 8
@export var carried_facility_move_speed_multiplier: float = 0.45

@onready var sprite: Sprite2D = $Sprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var item_push_area: Area2D = $ItemPushArea
@onready var item_push_collision_shape: CollisionShape2D = $ItemPushArea/CollisionShape2D
@onready var aim_indicator: Node2D = $AimIndicator
@onready var attack_visualizer: Node2D = $AttackVisualizer
@onready var dash_cooldown_indicator: Node2D = $DashCooldownIndicator
@onready var health_label: Label = $HealthLabel
@onready var held_item_sprite: Sprite2D = $HeldItemSprite
@onready var interaction_progress_bar: Node2D = $InteractionProgressBar

var aim_direction: Vector2 = Vector2.RIGHT
var movement_input_direction: Vector2 = Vector2.ZERO
var window_input_focused: bool = true
var prototype_map: Node
var level_refs: LevelRefs
var interaction_controller: RefCounted
var combat_controller: RefCounted
var skill_controller: RefCounted
var buff_indicator: Node2D
var push_controller: RefCounted
var facility_preview_controller: RefCounted
var facility_carry_controller: RefCounted
var blessing_controller: RefCounted
var storm_controller: RefCounted
var interaction_input_suppressed_frame: int = -1
var input_gate: PlayerInputGate = PlayerInputGate.new()
var wind_jump_velocity: Vector2 = Vector2.ZERO
var wind_jump_remaining: float = 0.0
var wind_jump_total_duration: float = 0.0
var wind_jump_target: Vector2 = Vector2.ZERO
var wind_jump_base_sprite_scale: Vector2 = Vector2.ONE
var wind_jump_base_held_scale: Vector2 = Vector2.ONE
var quicksand_pull_velocity: Vector2 = Vector2.ZERO
var quicksand_spawn_motion: Vector2 = Vector2.ZERO
var quicksand_processing_block_remaining: float = 0.0
var quicksand_processing_needs_release: bool = false
var source_hint_key_was_down: bool = false

func _ready() -> void:
	add_to_group("player")
	collision_mask |= 32  # Inset BOSS ground bodies.
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	safe_margin = collision_safe_margin
	storm_controller = PlayerStormController.new()
	storm_controller.setup(self)
	interaction_controller = PlayerInteractionController.new()
	interaction_controller.setup(self, held_item_sprite, interaction_progress_bar)
	combat_controller = PlayerCombatController.new()
	combat_controller.setup(
		self,
		sprite,
		attack_visualizer,
		dash_cooldown_indicator,
		health_label,
		{
			"max_health": max_health,
			"move_speed": move_speed,
			"attack_damage": attack_damage,
			"attack_origin_offset": attack_origin_offset,
			"attack_inner_radius": attack_inner_radius,
			"attack_outer_radius": attack_outer_radius,
			"attack_angle_degrees": attack_angle_degrees,
			"attack_cooldown": attack_cooldown,
			"light_attack_release_window": light_attack_release_window,
			"light_attack_damage_multiplier": light_attack_damage_multiplier,
			"light_attack_auto_aim_angle_degrees": light_attack_auto_aim_angle_degrees,
			"light_attack_close_auto_aim_radius": light_attack_close_auto_aim_radius,
			"heavy_charge_full_duration": heavy_charge_full_duration,
			"heavy_charge_overhold_duration": heavy_charge_overhold_duration,
			"heavy_charge_move_slow_min": heavy_charge_move_slow_min,
			"heavy_charge_move_slow_max": heavy_charge_move_slow_max,
			"heavy_damage_multiplier_min": heavy_damage_multiplier_min,
			"heavy_damage_multiplier_max": heavy_damage_multiplier_max,
			"attack_snap_input_grace_duration": attack_snap_input_grace_duration,
			"attack_auto_aim_angle_degrees": attack_auto_aim_angle_degrees,
			"dash_duration": dash_duration,
			"dash_cooldown": dash_cooldown,
			"contact_immunity_duration": contact_immunity_duration
		}
	)
	skill_controller = PlayerSkillController.new()
	skill_controller.setup(
		self,
		{
			"small_cooldown": small_skill_cooldown,
			"small_magic_cost": small_skill_magic_cost,
			"small_speed_multiplier": small_skill_speed_multiplier,
			"small_speed_duration": small_skill_speed_duration,
			"big_buff_duration": big_skill_buff_duration,
			"big_work_efficiency_multiplier": 2.0,
			"big_control_immunity": false,
			"big_variant": StringName(get_meta("big_skill_variant", &"steady_pot"))
		}
	)
	push_controller = PlayerPushController.new()
	push_controller.setup(
		self,
		collision_shape,
		item_push_area,
		item_push_collision_shape,
		{
			"movement_bounds": movement_bounds,
			"edge_padding": edge_padding,
			"show_item_push_debug": show_item_push_debug,
			"item_push_margin": item_push_margin,
			"item_push_acceleration": item_push_acceleration,
			"item_push_min_speed": item_push_min_speed,
			"item_push_overlap_bias": item_push_overlap_bias,
			"item_push_low_speed_multiplier": item_push_low_speed_multiplier,
			"item_push_high_speed_multiplier": item_push_high_speed_multiplier,
			"item_push_speed_curve": item_push_speed_curve,
			"dash_nearby_push_multiplier": dash_nearby_push_multiplier,
			"dash_nearby_push_ahead_margin": dash_nearby_push_ahead_margin,
			"dash_horizontal_push_force_multiplier": dash_horizontal_push_force_multiplier,
			"movement_substep_pixels": movement_substep_pixels
		}
	)
	wind_jump_base_sprite_scale = sprite.scale
	wind_jump_base_held_scale = held_item_sprite.scale
	facility_carry_controller = PlayerFacilityCarryController.new()
	facility_carry_controller.setup(self)
	facility_preview_controller = PlayerFacilityPreviewController.new()
	facility_preview_controller.setup(self, facility_carry_controller, {
		"preview_body_offset": carried_facility_preview_body_offset,
		"preview_max_size": carried_facility_preview_max_size,
		"preview_tint_strength": facility_preview_tint_strength,
		"place_valid_color": facility_place_valid_color,
		"place_invalid_color": facility_place_invalid_color,
		"place_outline_valid_color": facility_place_outline_valid_color,
		"place_outline_invalid_color": facility_place_outline_invalid_color,
		"place_origin_color": facility_place_origin_color,
		"place_origin_outline_color": facility_place_origin_outline_color
	})
	if not facility_carry_controller.preview_changed.is_connected(facility_preview_controller._on_preview_changed):
		facility_carry_controller.preview_changed.connect(facility_preview_controller._on_preview_changed)
	blessing_controller = BlessingRuntimeController.new()
	blessing_controller.setup(self)
	if combat_controller != null and combat_controller.has_method("set_blessing_controller"):
		combat_controller.set_blessing_controller(blessing_controller)
	if interaction_controller != null and interaction_controller.has_method("set_push_controller"):
		interaction_controller.set_push_controller(push_controller)
	_build_buff_indicator()
	_resolve_prototype_map()
	_refresh_movement_bounds_from_map()

func _notification(what: int) -> void:
	if what == NOTIFICATION_PAUSED or what == NOTIFICATION_UNPAUSED:
		# Input polling ignores handled UI events, including a closing mouse click.
		suppress_action_inputs_until_release()
	elif what == NOTIFICATION_WM_WINDOW_FOCUS_OUT or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		window_input_focused = false
		_clear_focus_input()
	elif what == NOTIFICATION_WM_WINDOW_FOCUS_IN or what == NOTIFICATION_APPLICATION_FOCUS_IN:
		_clear_focus_input()
		window_input_focused = true

func _clear_focus_input() -> void:
	# The key-up event can go to another application; discard latched actions
	# on both transitions so returning never resumes an old movement/hold.
	for action: StringName in InputMap.get_actions():
		Input.action_release(action)
	movement_input_direction = Vector2.ZERO
	velocity = Vector2.ZERO
	if combat_controller != null:
		combat_controller.cancel_input_actions()
	if interaction_controller != null:
		interaction_controller.pickup_hold_requires_release = false
	suppress_interaction_input_for_current_frame()

func _process(delta: float) -> void:
	input_gate.refresh()
	if is_downed():
		combat_controller.tick_downed(delta)
		queue_redraw()
		return
	if push_controller != null:
		push_controller.update_ignored_pushable_items(delta)
	if combat_controller != null:
		combat_controller.tick_cooldowns(delta, movement_input_direction)
	if skill_controller != null and skill_controller.has_method("tick"):
		skill_controller.tick(delta)
	if blessing_controller != null:
		blessing_controller.tick(delta)
	if has_meta("facility_vehicle"):
		combat_controller.cancel_input_actions()
		return
	if not input_gate.is_pressed(&"interact"):
		quicksand_processing_needs_release = false
	_update_buff_indicator()
	_update_facing()
	if not window_input_focused:
		return
	# The ultimate must remain reachable while stunned or holding a work key.
	if input_gate.is_just_pressed(&"skill_big"):
		_try_big_skill()
	if storm_controller.blocks_actions():
		interaction_controller.update_interaction_progress_ui()
		queue_redraw()
		return
	if facility_carry_controller != null:
		facility_carry_controller.tick(is_carrying_facility() and _is_facility_rearrange_allowed())
	if interaction_controller != null:
		interaction_controller.update_current_interaction_target(
			_get_interaction_origin(),
			aim_direction,
			interaction_radius,
			interaction_angle_degrees,
			floor_interaction_radius
		)
		if facility_carry_controller == null or not facility_carry_controller.is_carrying():
			if interaction_controller.has_method("update_held_interaction"):
				interaction_controller.update_held_interaction(delta)
		interaction_controller.update_interaction_progress_ui()
	var source_hint_key_down: bool = input_gate.is_source_hint_pressed()
	if source_hint_key_down and not source_hint_key_was_down:
		_show_focused_ingredient_source_hint()
	source_hint_key_was_down = source_hint_key_down
	queue_redraw()
	var suppress_interaction_input: bool = interaction_input_suppressed_frame == Engine.get_process_frames()
	if input_gate.is_just_pressed(&"pickup_drop") and not suppress_interaction_input:
		_handle_pickup_drop()
	if get_tree().paused:
		return
	if input_gate.is_just_pressed(&"interact") and not suppress_interaction_input:
		if facility_carry_controller != null and facility_carry_controller.is_carrying():
			_handle_interact()
			return
		if _should_block_action_for_interaction():
			return
		_handle_interact()
	if get_tree().paused:
		return
	if input_gate.is_just_pressed(&"skill_small"):
		if _should_block_action_for_interaction():
			return
		if facility_carry_controller != null and facility_carry_controller.is_carrying():
			return
		_try_small_skill()
	if input_gate.is_just_pressed(&"primary_attack"):
		if _should_block_action_for_interaction():
			return
		if facility_carry_controller != null and facility_carry_controller.is_carrying():
			_try_rotate_carried_facility()
			return
		_begin_attack_hold()
	if input_gate.is_just_released(&"primary_attack"):
		_release_attack_hold()
	if input_gate.is_just_pressed(&"dash"):
		_try_dash()

func suppress_interaction_input_for_current_frame() -> void:
	interaction_input_suppressed_frame = Engine.get_process_frames()

func suppress_action_inputs_until_release() -> void:
	input_gate.capture_menu_inputs()
	interaction_input_suppressed_frame = Engine.get_process_frames()
	movement_input_direction = Vector2.ZERO
	if combat_controller != null:
		combat_controller.cancel_input_actions()

func _physics_process(_delta: float) -> void:
	if is_downed():
		velocity = Vector2.ZERO
		quicksand_pull_velocity = Vector2.ZERO
		quicksand_spawn_motion = Vector2.ZERO
		return
	if has_meta("facility_vehicle") or preload("res://Scripts/Facilities/FacilityControlEffect.gd").rooted(self):
		velocity = Vector2.ZERO
		return
	quicksand_processing_block_remaining = maxf(quicksand_processing_block_remaining - _delta, 0.0)
	if storm_controller.tick(_delta):
		queue_redraw()
		return
	if wind_jump_remaining > 0.0:
		quicksand_pull_velocity = Vector2.ZERO
		quicksand_spawn_motion = Vector2.ZERO
		wind_jump_remaining = maxf(wind_jump_remaining - _delta, 0.0)
		velocity = wind_jump_velocity
		var collision := move_and_collide(wind_jump_velocity * _delta)
		if collision != null:
			wind_jump_remaining = 0.0
			wind_jump_target = global_position
		if push_controller != null:
			push_controller.clamp_to_map_bounds()
		var wind_progress: float = 1.0 - wind_jump_remaining / maxf(wind_jump_total_duration, 0.001)
		var wind_scale: float = 1.0 + sin(clampf(wind_progress, 0.0, 1.0) * PI) * 0.28
		sprite.scale = wind_jump_base_sprite_scale * wind_scale
		held_item_sprite.scale = wind_jump_base_held_scale * wind_scale
		if wind_jump_remaining <= 0.0:
			sprite.scale = wind_jump_base_sprite_scale
			held_item_sprite.scale = wind_jump_base_held_scale
		velocity = Vector2.ZERO
		return
	if not quicksand_spawn_motion.is_zero_approx():
		move_and_collide(quicksand_spawn_motion)
		if push_controller != null:
			push_controller.clamp_to_map_bounds()
		quicksand_spawn_motion = Vector2.ZERO
	var input_direction: Vector2 = input_gate.get_movement() if window_input_focused else Vector2.ZERO
	if _should_lock_movement_for_interaction():
		input_direction = Vector2.ZERO
	movement_input_direction = input_direction
	skill_controller.small.before_motion(input_direction)
	var skill_motion_start: Vector2 = global_position
	var skill_expected_distance: float = get_current_move_speed() * _delta * input_direction.length()
	var desired_velocity: Vector2
	if combat_controller != null and combat_controller.is_dash_active():
		desired_velocity = combat_controller.get_dash_direction() * get_current_move_speed() * dash_speed_multiplier
	else:
		desired_velocity = input_direction * get_current_move_speed()
	# Quicksand contributes to the same physics movement as player input.  It is
	# intentionally added here instead of moving global_position from the hazard,
	# so opposing movement remains continuous rather than alternating each frame.
	desired_velocity += quicksand_pull_velocity
	quicksand_pull_velocity = Vector2.ZERO

	velocity = desired_velocity
	var physics_delta: float = get_physics_process_delta_time()
	var is_dash_active: bool = combat_controller != null and combat_controller.is_dash_active()
	if push_controller != null:
		if is_dash_active:
			push_controller.push_nearby_items(physics_delta, velocity, get_current_move_speed(), dash_speed_multiplier, true, true)
		push_controller.move_with_axis_separation(desired_velocity * physics_delta, velocity, get_current_move_speed(), is_dash_active)
		if is_dash_active:
			push_controller.push_nearby_items(physics_delta, velocity, get_current_move_speed(), dash_speed_multiplier, true)
		push_controller.clamp_to_map_bounds()
	skill_controller.small.after_motion(input_direction, skill_motion_start, global_position, skill_expected_distance)

func _update_facing() -> void:
	var new_aim_direction: Vector2 = movement_input_direction
	if new_aim_direction.length_squared() <= 0.001:
		return

	aim_direction = new_aim_direction.normalized()
	var aim_angle: float = aim_direction.angle()
	aim_indicator.rotation = aim_angle
	sprite.flip_h = cos(aim_angle) < 0.0

func _refresh_movement_bounds_from_map() -> void:
	if prototype_map == null or not prototype_map.has_method("get_world_bounds"):
		_resolve_prototype_map()
	if prototype_map == null or not prototype_map.has_method("get_world_bounds"):
		return
	movement_bounds = prototype_map.get_world_bounds()
	if push_controller != null and push_controller.has_method("set_movement_bounds"):
		push_controller.set_movement_bounds(movement_bounds)
	if push_controller != null and push_controller.has_method("set_prototype_map"):
		push_controller.set_prototype_map(prototype_map)

func _resolve_prototype_map() -> void:
	if is_instance_valid(prototype_map):
		return
	level_refs = LevelRefs.find_from(self)
	if level_refs != null:
		prototype_map = level_refs.get_prototype_map()
	if prototype_map == null:
		push_warning("RealtimePlayer could not resolve PrototypeMap from LevelRefs.")

func _begin_attack_hold() -> void:
	if combat_controller != null:
		var input_direction: Vector2 = input_gate.get_movement()
		combat_controller.begin_attack_hold(aim_direction, input_direction)

func _release_attack_hold() -> void:
	if combat_controller != null and combat_controller.has_method("release_attack_hold"):
		var input_direction: Vector2 = input_gate.get_movement()
		combat_controller.release_attack_hold(aim_direction, Callable(self, "_can_damage_target_across_zones"), input_direction)

func _try_dash() -> void:
	if is_carrying_facility() and not _is_night_rest_active():
		return
	var input_direction: Vector2 = input_gate.get_movement()
	if combat_controller != null:
		if combat_controller.try_dash(input_direction, aim_direction):
			AudioCue.play_sfx(&"dash", -4.0)
			var tutorial := get_parent().get_node_or_null("TutorialController")
			if tutorial != null:
				tutorial.record_event(&"dash")

func _try_small_skill() -> void:
	if skill_controller != null and skill_controller.has_method("try_activate_small"):
		if skill_controller.try_activate_small():
			AudioCue.play_sfx(&"skill", -3.0, 1.08)

func _try_big_skill() -> void:
	if skill_controller != null and skill_controller.has_method("try_activate_big"):
		if skill_controller.try_activate_big():
			AudioCue.play_sfx(&"ultimate", -1.0)

func try_spend_magic(amount: int) -> bool:
	var level_flow_controller: Node = _get_level_flow_controller()
	if level_flow_controller == null or not level_flow_controller.has_method("spend_magic"):
		return false
	return bool(level_flow_controller.spend_magic(amount))

func adjust_skill_magic(amount: int) -> int:
	var flow: Node = _get_level_flow_controller()
	if flow != null:
		return flow.adjust_skill_magic(amount)
	return 0

func on_work_completed(event: StringName) -> void:
	if skill_controller != null:
		skill_controller.on_work_completed(event)
	var tutorial := get_parent().get_node_or_null("TutorialController")
	if tutorial != null:
		tutorial.record_event(event)

func set_big_skill_variant(id: StringName) -> void:
	if skill_controller != null:
		skill_controller.set_big_variant(id)
	set_meta("big_skill_variant", skill_controller.get_big_variant_id())

func fill_ultimate_energy() -> void:
	if skill_controller != null:
		skill_controller.ultimate_energy = preload("res://Scripts/Player/UltimateEnergyRules.gd").CAPACITY

func consume_instant_work(process_state: StringName = &"", station_state: StringName = &"", payload: Dictionary = {}) -> bool:
	return skill_controller.consume_instant_work(process_state, station_state, payload) if skill_controller != null and skill_controller.has_method("consume_instant_work") else false

func set_small_skill_variant(id: StringName) -> void:
	if skill_controller != null:
		skill_controller.set_small_variant(id)
	set_meta("small_skill_variant", skill_controller.small.variant_id)

func get_small_skill_display_data() -> Dictionary:
	return skill_controller.small.definition.duplicate(true)

func _try_rotate_carried_facility() -> void:
	if facility_carry_controller != null:
		facility_carry_controller.rotate_carried_facility()

func take_damage(damage: int, hit_direction: Vector2 = Vector2.ZERO, damage_type: StringName = &"special") -> bool:
	return combat_controller != null and combat_controller.take_damage(damage, hit_direction, damage_type)

func is_downed() -> bool:
	return combat_controller != null and combat_controller.is_downed()

func on_downed() -> void:
	velocity = Vector2.ZERO
	movement_input_direction = Vector2.ZERO
	clear_hostile_control()
	wind_jump_remaining = 0.0
	wind_jump_velocity = Vector2.ZERO
	if held_item_sprite != null:
		held_item_sprite.scale = wind_jump_base_held_scale
	if interaction_controller != null:
		var target: Node = interaction_controller.get_current_interaction_target()
		if is_instance_valid(target) and target.has_method("cancel_interaction"):
			target.cancel_interaction(self)
		interaction_controller._set_current_interaction_target(null)
		interaction_controller.update_interaction_progress_ui()
	suppress_action_inputs_until_release()

func apply_contact_push(push_direction: Vector2, push_distance: float) -> void:
	if has_meta("facility_vehicle"):
		return
	if is_control_immune():
		return
	var motion := push_direction.normalized() * maxf(push_distance, 0.0)
	if motion.is_zero_approx():
		return
	# Sweep the body through the entire knockback path. Direct position changes
	# could place the player inside forage points, facilities or walls.
	move_and_collide(motion)
	if push_controller != null:
		push_controller.clamp_to_map_bounds()

func apply_storm_launch(direction: Vector2, distance: float, damage: int, stun: float, source: Node) -> bool:
	return storm_controller.launch(direction, distance, damage, stun, source)

func apply_storm_slow(source: Node, multiplier: float) -> void:
	storm_controller.apply_slow(source, multiplier)

func apply_conveyor_motion(motion: Vector2) -> void:
	if is_downed():
		return
	if motion.length_squared() <= 0.000001:
		return
	global_position += motion
	if push_controller != null:
		push_controller.clamp_to_map_bounds()

func apply_quicksand_pull(pull_velocity: Vector2) -> void:
	if is_control_immune():
		return
	if not pull_velocity.is_zero_approx() and wind_jump_remaining <= 0.0:
		_interrupt_processing_for_quicksand()
	var safe_limit := minf(300.0, get_current_move_speed() * dash_speed_multiplier * 0.4)
	var candidate := pull_velocity.limit_length(safe_limit)
	if candidate.length_squared() > quicksand_pull_velocity.length_squared():
		quicksand_pull_velocity = candidate

func apply_quicksand_spawn_pull(center: Vector2, distance: float) -> void:
	if is_control_immune():
		return
	var motion := (center - global_position).limit_length(minf(maxf(distance, 0.0), global_position.distance_to(center)))
	if not motion.is_zero_approx() and wind_jump_remaining <= 0.0:
		_interrupt_processing_for_quicksand()
	if motion.length_squared() > quicksand_spawn_motion.length_squared():
		quicksand_spawn_motion = motion

func is_quicksand_processing_blocked() -> bool:
	return quicksand_processing_block_remaining > 0.0 or quicksand_processing_needs_release or storm_controller.blocks_actions()

func _interrupt_processing_for_quicksand() -> void:
	quicksand_processing_block_remaining = 0.12
	if input_gate.is_pressed(&"interact"):
		quicksand_processing_needs_release = true

func apply_wind_sand_jump(motion: Vector2) -> bool:
	if is_downed():
		return false
	if storm_controller.blocks_actions():
		return false
	if motion.length_squared() <= 0.000001:
		return false
	var target_position := global_position + motion
	if prototype_map != null and prototype_map.has_method("clamp_point_to_playable_from"):
		target_position = prototype_map.clamp_point_to_playable_from(target_position, global_position, Vector2(24.0, 24.0))
	elif prototype_map != null and prototype_map.has_method("clamp_point_to_playable"):
		target_position = prototype_map.clamp_point_to_playable(target_position, Vector2(24.0, 24.0))
	var actual_motion := target_position - global_position
	var travel_distance: float = actual_motion.length()
	if travel_distance <= 4.0:
		return false
	# Do not begin the wind-up animation when the launch direction is blocked at
	# the player's feet. A later collision still stops the player at the actual
	# contact point, but an immediate one should let the pad choose another way.
	var launch_probe := actual_motion.normalized() * minf(12.0, travel_distance)
	if test_move(global_transform, launch_probe):
		return false
	wind_jump_target = target_position
	wind_jump_total_duration = clampf(travel_distance / maxf(get_current_move_speed() * dash_speed_multiplier, 1.0), 0.24, 0.95)
	wind_jump_remaining = wind_jump_total_duration
	wind_jump_velocity = actual_motion / maxf(wind_jump_total_duration, 0.001)
	if combat_controller != null and combat_controller.has_method("cancel_attack_charge"):
		combat_controller.cancel_attack_charge(false)
	return true

func is_holding_item() -> bool:
	return interaction_controller != null and interaction_controller.is_holding_item()

func can_pick_up_item(_item_id: StringName = &"", _process_state: StringName = TestItemDefs.PROCESS_STATE_NONE, payload: Dictionary = {}) -> bool:
	return interaction_controller != null and interaction_controller.can_pick_up_item(_item_id, _process_state, payload)

func pick_up_item(item_id: StringName, item_texture: Texture2D, process_state: StringName = TestItemDefs.PROCESS_STATE_NONE, recipe_signature: String = "", payload: Dictionary = {}) -> bool:
	return interaction_controller != null and interaction_controller.pick_up_item(item_id, item_texture, process_state, recipe_signature, payload)

func set_held_item_payload(payload: Dictionary) -> void:
	if interaction_controller != null:
		interaction_controller.set_held_item_payload(payload)

func show_hint(message: String) -> void:
	if interaction_controller != null:
		interaction_controller.show_hint(message)

func get_held_item_payload() -> Dictionary:
	return interaction_controller.get_held_item_payload() if interaction_controller != null else {}

func get_held_item_id() -> StringName:
	return interaction_controller.get_held_item_id() if interaction_controller != null else &""

func get_held_item_texture() -> Texture2D:
	return interaction_controller.get_held_item_texture() if interaction_controller != null else null

func get_held_item_process_state() -> StringName:
	return interaction_controller.get_held_item_process_state() if interaction_controller != null else TestItemDefs.PROCESS_STATE_NONE

func get_held_item_recipe_signature() -> String:
	return interaction_controller.get_held_item_recipe_signature() if interaction_controller != null else ""

func clear_held_item() -> void:
	if interaction_controller != null:
		interaction_controller.clear_held_item()

func clear_interaction_target_if_matches(target) -> void:
	if interaction_controller != null and interaction_controller.has_method("clear_current_interaction_target_if_matches"):
		interaction_controller.clear_current_interaction_target_if_matches(target)

func reset_runtime_stats() -> void:
	if combat_controller != null:
		combat_controller.reset_runtime_stats()

func reset_temporary_state() -> void:
	var facility_effect: Node = get_node_or_null("FacilityControlEffect")
	if facility_effect != null:
		facility_effect.queue_free()
	if storm_controller != null:
		storm_controller.reset()
	if combat_controller != null:
		combat_controller.reset_temporary_state()
	if skill_controller != null and skill_controller.has_method("reset_temporary_state"):
		skill_controller.reset_temporary_state()

func add_shop_move_speed_bonus(multiplier_bonus: float) -> void:
	if combat_controller != null:
		combat_controller.add_shop_move_speed_bonus(multiplier_bonus)

func add_shop_attack_damage_bonus(multiplier_bonus: float) -> void:
	if combat_controller != null:
		combat_controller.add_shop_attack_damage_bonus(multiplier_bonus)

func add_shop_max_health_bonus(health_bonus: int) -> void:
	if combat_controller != null:
		combat_controller.add_shop_max_health_bonus(health_bonus)

func set_event_max_health_penalty(penalty: int) -> void:
	if combat_controller != null:
		combat_controller.set_event_max_health_penalty(penalty)

func apply_forged_attribute(option: Dictionary) -> void:
	if combat_controller != null and combat_controller.has_method("apply_forged_attribute"):
		combat_controller.apply_forged_attribute(option)
	if skill_controller != null and skill_controller.has_method("apply_forged_attribute"):
		skill_controller.apply_forged_attribute(option)

func get_current_max_health() -> int:
	return combat_controller.get_current_max_health() if combat_controller != null else max_health

func apply_blessing(blessing_id: StringName) -> bool:
	return blessing_controller != null and blessing_controller.apply_blessing(blessing_id)

func get_current_move_speed() -> float:
	var base_speed: float = combat_controller.get_current_move_speed() if combat_controller != null else move_speed
	if skill_controller != null and skill_controller.has_method("get_move_speed_multiplier"):
		base_speed *= skill_controller.get_move_speed_multiplier()
	base_speed *= _get_support_facility_move_multiplier() * preload("res://Scripts/Facilities/FacilityControlEffect.gd").speed(self)
	if blessing_controller != null:
		base_speed *= blessing_controller.get_move_speed_multiplier()
	base_speed *= get_facility_carry_move_multiplier()
	if storm_controller != null:
		base_speed *= storm_controller.get_speed_multiplier()
	base_speed *= get_run_modifier_multiplier(&"move")
	return base_speed

func get_run_modifier_multiplier(key: StringName) -> float:
	var flow: Node = level_refs.get_level_flow_controller() if is_instance_valid(level_refs) else null
	return float(flow.get_run_modifier_multiplier(key)) if flow != null and flow.has_method("get_run_modifier_multiplier") else 1.0

func get_facility_carry_move_multiplier() -> float:
	return carried_facility_move_speed_multiplier if is_carrying_facility() and not _is_night_rest_active() else 1.0

func _get_support_facility_move_multiplier() -> float:
	return SupportFacilityAuraQuery.get_movement_multiplier(get_tree(), global_position)

func get_small_skill_progress() -> float:
	return skill_controller.get_small_skill_progress() if skill_controller != null and skill_controller.has_method("get_small_skill_progress") else 1.0

func get_small_skill_remaining() -> float:
	return skill_controller.get_small_skill_remaining() if skill_controller != null and skill_controller.has_method("get_small_skill_remaining") else 0.0

func get_big_skill_progress() -> float:
	return skill_controller.get_big_skill_progress() if skill_controller != null and skill_controller.has_method("get_big_skill_progress") else 1.0

func get_big_skill_remaining() -> float:
	return skill_controller.get_big_skill_remaining() if skill_controller != null and skill_controller.has_method("get_big_skill_remaining") else 0.0

func get_dash_cooldown_progress() -> float:
	return combat_controller.get_dash_cooldown_progress() if combat_controller != null and combat_controller.has_method("get_dash_cooldown_progress") else 1.0

func get_dash_cooldown_remaining() -> float:
	return combat_controller.get_dash_cooldown_remaining() if combat_controller != null and combat_controller.has_method("get_dash_cooldown_remaining") else 0.0

func get_cook_progress_multiplier() -> float:
	var speed: float = skill_controller.get_cook_progress_multiplier() if skill_controller != null and skill_controller.has_method("get_cook_progress_multiplier") else 1.0
	return speed * get_run_modifier_multiplier(&"work")

func get_work_progress_multiplier() -> float:
	var speed: float = skill_controller.get_work_progress_multiplier() if skill_controller != null and skill_controller.has_method("get_work_progress_multiplier") else 1.0
	return speed * get_run_modifier_multiplier(&"work")

func get_station_cook_progress_multiplier(station_state: StringName) -> float:
	var multiplier := get_cook_progress_multiplier()
	if blessing_controller != null:
		multiplier *= blessing_controller.get_work_multiplier(station_state)
	return multiplier

func get_facility_work_multiplier(target: Node2D) -> float:
	return skill_controller.get_facility_work_multiplier(target) if skill_controller != null and skill_controller.has_method("get_facility_work_multiplier") else 1.0

func get_blessing_controller() -> RefCounted:
	return blessing_controller

func set_owned_blessings_for_run(blessing_ids: Array[StringName]) -> void:
	if blessing_controller != null:
		blessing_controller.set_owned_blessings(blessing_ids)

func begin_blessing_day() -> void:
	if blessing_controller != null:
		blessing_controller.begin_day()

func has_blessing_title(title: String) -> bool:
	return blessing_controller != null and blessing_controller.has_title(title)

func is_dash_active_for_blessings() -> bool:
	return combat_controller != null and combat_controller.is_dash_active()

func get_health_ratio_for_blessings() -> float:
	return combat_controller.get_health_ratio() if combat_controller != null and combat_controller.has_method("get_health_ratio") else 1.0

func heal_for_blessings(amount: int) -> void:
	if combat_controller != null and combat_controller.has_method("heal"):
		combat_controller.heal(amount)

func reduce_dash_cooldown_fraction(fraction: float) -> void:
	if combat_controller != null and combat_controller.has_method("reduce_dash_cooldown_fraction"):
		combat_controller.reduce_dash_cooldown_fraction(fraction)

func award_ultimate_energy(event: StringName) -> void:
	var tutorial := get_parent().get_node_or_null("TutorialController")
	if tutorial != null:
		tutorial.record_event(event)
	if skill_controller != null and is_skill_gameplay_active():
		var amount: float = float(preload("res://Scripts/Player/UltimateEnergyRules.gd").REWARDS.get(event, 0))
		amount *= get_run_modifier_multiplier(&"energy")
		skill_controller.add_energy(amount)

func is_skill_gameplay_active() -> bool:
	return not is_downed() and not get_tree().paused and _is_daytime_facility_rearrange_active()

func is_control_immune() -> bool:
	return is_downed() or (skill_controller != null and skill_controller.has_method("is_control_immune") and skill_controller.is_control_immune())

func clear_hostile_control() -> void:
	var facility_effect: Node = get_node_or_null("FacilityControlEffect")
	if facility_effect != null:
		facility_effect.queue_free()
	storm_controller.reset()
	quicksand_pull_velocity = Vector2.ZERO
	quicksand_spawn_motion = Vector2.ZERO
	quicksand_processing_block_remaining = 0.0
	quicksand_processing_needs_release = false

func get_sort_origin() -> Vector2:
	if is_instance_valid(collision_shape):
		return collision_shape.global_position
	return global_position

func get_aim_direction_world() -> Vector2:
	return aim_direction

func get_interaction_origin_world() -> Vector2:
	return _get_interaction_origin()

func get_item_push_capsule_data() -> Dictionary:
	return push_controller.get_item_push_capsule_data() if push_controller != null else {}

func is_carrying_facility() -> bool:
	return facility_carry_controller != null and facility_carry_controller.is_carrying()

func get_carried_facility_node() -> Node2D:
	return facility_carry_controller.get_carried_facility() if facility_carry_controller != null else null

func get_prototype_map_node() -> Node:
	return prototype_map

func get_level_flow_controller_for_blessings() -> Node:
	return _get_level_flow_controller()

func relocate_after_facility_snap(snapped_facility: Node2D) -> void:
	if not is_instance_valid(snapped_facility):
		return
	if _is_player_position_safe_after_facility_place(global_position):
		return
	var safe_position: Vector2 = _find_safe_player_position_after_facility_place(snapped_facility)
	if safe_position != Vector2.INF:
		global_position = safe_position
		if push_controller != null:
			push_controller.clamp_to_map_bounds()
		return
	var fallback_direction: Vector2 = global_position - snapped_facility.global_position
	if fallback_direction.length_squared() <= 0.0001:
		fallback_direction = aim_direction if aim_direction.length_squared() > 0.0001 else Vector2.DOWN
	global_position = _clamp_position_to_playable(global_position + fallback_direction.normalized() * 96.0)
	if push_controller != null:
		push_controller.clamp_to_map_bounds()

func is_item_push_debug_enabled() -> bool:
	return push_controller != null and push_controller.is_item_push_debug_enabled()

func _handle_pickup_drop() -> void:
	if _should_block_pickup_drop_for_interaction():
		return
	if interaction_controller != null:
		interaction_controller.handle_pickup_drop(aim_direction)

func _handle_interact() -> void:
	if preload("res://Scripts/Facilities/FacilityToolEffect.gd").use(self):
		return
	var focus: Node = interaction_controller.get_current_interaction_target() if interaction_controller != null else null
	if is_instance_valid(focus) and focus.has_method("can_take_plate_portion") and focus.can_take_plate_portion(self):
		focus.interact_with_player(self)
		return
	if _handle_facility_pickup_drop():
		return
	if interaction_controller != null:
		interaction_controller.handle_interact()

func _show_focused_ingredient_source_hint() -> void:
	if interaction_controller == null or not interaction_controller.has_method("get_current_interaction_target"):
		return
	var focus = interaction_controller.get_current_interaction_target()
	if is_instance_valid(focus) and focus.has_method("show_ingredient_source_hint"):
		focus.show_ingredient_source_hint()

func _should_lock_movement_for_interaction() -> bool:
	if preload("res://Scripts/Facilities/FacilityControlEffect.gd").rooted(self):
		return true
	if interaction_controller == null or not interaction_controller.has_method("get_current_interaction_target"):
		return false
	var target = interaction_controller.get_current_interaction_target()
	if not is_instance_valid(target) or not target.has_method("should_lock_player_movement"):
		return false
	return bool(target.should_lock_player_movement(self))

func _should_block_pickup_drop_for_interaction() -> bool:
	if _should_block_action_for_interaction():
		return true
	if has_meta("forage_consumed_pickup_drop_frame"):
		var consumed_frame: int = int(get_meta("forage_consumed_pickup_drop_frame", -1))
		if consumed_frame == Engine.get_process_frames():
			return true
	if interaction_controller == null or not interaction_controller.has_method("get_current_interaction_target"):
		return false
	var target = interaction_controller.get_current_interaction_target()
	if not is_instance_valid(target) or not target.has_method("should_block_player_pickup_drop"):
		return false
	return bool(target.should_block_player_pickup_drop(self))

func _should_block_action_for_interaction() -> bool:
	if preload("res://Scripts/Facilities/FacilityControlEffect.gd").rooted(self):
		return true
	if has_meta("forage_consumed_action_frame"):
		var consumed_frame: int = int(get_meta("forage_consumed_action_frame", -1))
		if consumed_frame == Engine.get_process_frames():
			return true
	if interaction_controller == null or not interaction_controller.has_method("get_current_interaction_target"):
		return false
	var target = interaction_controller.get_current_interaction_target()
	if not is_instance_valid(target) or not target.has_method("should_block_player_action"):
		return false
	return bool(target.should_block_player_action(self))

func _clamp_position_to_playable(candidate_position: Vector2) -> Vector2:
	var min_position: Vector2 = push_controller.get_player_map_min_position() if push_controller != null else movement_bounds.position + edge_padding
	var max_position: Vector2 = push_controller.get_player_map_max_position() if push_controller != null else movement_bounds.position + movement_bounds.size - edge_padding
	var clamped_position := candidate_position.clamp(min_position, max_position)
	if prototype_map != null:
		if prototype_map.has_method("clamp_point_to_playable_from"):
			clamped_position = prototype_map.clamp_point_to_playable_from(clamped_position, global_position, edge_padding)
		elif prototype_map.has_method("clamp_point_to_playable"):
			clamped_position = prototype_map.clamp_point_to_playable(clamped_position, edge_padding)
	return clamped_position

func _handle_facility_pickup_drop() -> bool:
	if is_instance_valid(get_carried_facility_node()):
		_try_place_carried_facility()
		return true
	if is_holding_item() or not _is_facility_rearrange_allowed():
		return false
	var target_facility: Node2D = _find_movable_facility_target()
	if target_facility == null:
		return false
	# Processing/cleaning at the selected work surface takes priority.
	var focus: Node = interaction_controller.get_current_interaction_target() if interaction_controller != null else null
	if is_instance_valid(focus) and focus.has_method("should_prioritize_hold_interaction") and focus.should_prioritize_hold_interaction(self):
		return false
	if is_instance_valid(focus) and focus != target_facility and focus.has_method("process_hold_interaction") and (not focus.has_method("get_hold_interaction_action") or focus.get_hold_interaction_action() == &"interact"):
		return false
	_pick_up_facility(target_facility)
	return true

func _find_movable_facility_target() -> Node2D:
	var interaction_origin: Vector2 = _get_interaction_origin()
	var safe_aim: Vector2 = aim_direction.normalized() if aim_direction.length_squared() > 0.0001 else Vector2.RIGHT
	var half_interaction_angle: float = deg_to_rad(interaction_angle_degrees * 0.5)
	var best_facility: Node2D
	var best_distance: float = INF
	var best_angle: float = INF

	for candidate in get_tree().get_nodes_in_group("movable_facilities"):
		if not is_instance_valid(candidate) or not (candidate is Node2D):
			continue
		if candidate is CanvasItem and not (candidate as CanvasItem).visible:
			continue
		if _is_daytime_facility_rearrange_active() and not _can_rearrange_facility_during_day(candidate):
			continue
		if candidate.has_method("can_be_moved_by_player") and not bool(candidate.can_be_moved_by_player(self)):
			continue

		var candidate_interaction_radius: float = _get_facility_interaction_radius(candidate as Node2D)
		var candidate_point: Vector2 = _get_facility_focus_point(candidate as Node2D, interaction_origin)
		var to_candidate: Vector2 = candidate_point - interaction_origin
		var candidate_distance: float = to_candidate.length()
		if candidate_distance > candidate_interaction_radius:
			continue
		if candidate_distance <= 0.001:
			return candidate as Node2D

		var candidate_angle: float = abs(safe_aim.angle_to(to_candidate.normalized()))
		if candidate_angle > half_interaction_angle:
			continue
		if candidate_distance < best_distance - 0.001 or (is_equal_approx(candidate_distance, best_distance) and candidate_angle < best_angle):
			best_distance = candidate_distance
			best_angle = candidate_angle
			best_facility = candidate as Node2D

	return best_facility

func _can_rearrange_facility_during_day(candidate: Node) -> bool:
	return candidate.is_in_group("cooking_stations") or candidate.is_in_group("storage_facilities") or candidate.is_in_group("table_facilities")

func _get_facility_focus_point(facility: Node2D, interaction_origin: Vector2) -> Vector2:
	var rect_method: StringName = &"get_facility_carry_rect_global" if facility.has_method("get_facility_carry_rect_global") else &"get_interaction_rect_global"
	if facility.has_method(rect_method):
		var rect_variant: Variant = facility.call(rect_method)
		if rect_variant is Rect2:
			var rect: Rect2 = rect_variant
			return Vector2(
				clampf(interaction_origin.x, rect.position.x, rect.position.x + rect.size.x),
				clampf(interaction_origin.y, rect.position.y, rect.position.y + rect.size.y)
			)
	return facility.global_position

func _get_facility_interaction_radius(facility: Node2D) -> float:
	var radius: float = interaction_radius
	if facility != null and facility.has_method("get_pickup_drop_radius"):
		radius = minf(radius, float(facility.get_pickup_drop_radius()))
	return radius

func _pick_up_facility(facility: Node2D) -> void:
	if facility_carry_controller != null:
		facility_carry_controller.pick_up(facility)

func _try_place_carried_facility() -> void:
	if facility_carry_controller == null:
		return
	var placed: Node2D = facility_carry_controller.try_place(_is_facility_rearrange_allowed())
	if is_instance_valid(placed):
		_eject_player_from_placed_facility_if_needed(placed)

func _eject_player_from_placed_facility_if_needed(placed_facility: Node2D) -> void:
	if not is_instance_valid(placed_facility):
		return
	if _is_player_position_safe_after_facility_place(global_position):
		return
	var safe_position: Vector2 = _find_safe_player_position_after_facility_place(placed_facility)
	if safe_position != Vector2.INF:
		global_position = safe_position
		if push_controller != null:
			push_controller.clamp_to_map_bounds()

func _find_safe_player_position_after_facility_place(placed_facility: Node2D) -> Vector2:
	var preferred_direction: Vector2 = global_position - placed_facility.global_position
	if preferred_direction.length_squared() <= 0.0001:
		preferred_direction = -aim_direction
	if preferred_direction.length_squared() <= 0.0001:
		preferred_direction = Vector2.DOWN
	preferred_direction = preferred_direction.normalized()

	var search_directions: Array[Vector2] = [
		preferred_direction,
		preferred_direction.rotated(PI * 0.25).normalized(),
		preferred_direction.rotated(-PI * 0.25).normalized(),
		preferred_direction.rotated(PI * 0.5).normalized(),
		preferred_direction.rotated(-PI * 0.5).normalized(),
		-preferred_direction,
		(-preferred_direction).rotated(PI * 0.25).normalized(),
		(-preferred_direction).rotated(-PI * 0.25).normalized()
	]

	for ring in range(facility_place_player_eject_rings + 1):
		var distance_offset: float = float(ring) * maxf(facility_place_player_eject_step, 1.0)
		for direction in search_directions:
			var candidate_position: Vector2 = global_position if ring == 0 else global_position + direction * distance_offset
			candidate_position = _clamp_position_to_playable(candidate_position)
			if _is_player_position_safe_after_facility_place(candidate_position):
				return candidate_position

	return Vector2.INF

func _is_player_position_safe_after_facility_place(candidate_position: Vector2) -> bool:
	var body_data: Dictionary = push_controller.get_body_collision_data_at_position(candidate_position) if push_controller != null else {}
	if body_data.is_empty():
		return false

	var body_shape := CircleShape2D.new()
	body_shape.radius = maxf(float(body_data.get("radius", 0.0)), 1.0)
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = body_shape
	query.transform = Transform2D(0.0, body_data.get("center", candidate_position))
	query.collision_mask = 4 | 8 | 16 | 32
	query.exclude = [get_rid()]
	var hits: Array[Dictionary] = get_world_2d().direct_space_state.intersect_shape(query, 16)
	return hits.is_empty()

func _is_night_rest_active() -> bool:
	var level_flow_controller: Node = _get_level_flow_controller()
	return level_flow_controller != null and level_flow_controller.has_method("is_night_rest_active") and bool(level_flow_controller.is_night_rest_active())

func _get_level_flow_controller() -> Node:
	level_refs = LevelRefs.find_from(self)
	if level_refs == null:
		return null
	return level_refs.get_level_flow_controller()

func _is_facility_rearrange_allowed() -> bool:
	if _is_night_rest_active():
		return true
	return _is_daytime_facility_rearrange_active()

func _is_daytime_facility_rearrange_active() -> bool:
	if level_refs == null:
		level_refs = LevelRefs.find_from(self)
	if level_refs == null:
		return false
	var level_flow_controller: Node = level_refs.get_level_flow_controller()
	if level_flow_controller == null or not level_flow_controller.has_method("get_current_level_state"):
		return false
	var state_value: int = int(level_flow_controller.get_current_level_state())
	return state_value in [
		LevelContext.LevelState.PREPARE_PHASE,
		LevelContext.LevelState.WAVE_ACTIVE,
		LevelContext.LevelState.WAVE_BREAK
	]

func _draw() -> void:
	if skill_controller != null:
		skill_controller.small.draw_feedback()
		skill_controller.big.draw_feedback()
	if storm_controller != null:
		storm_controller.draw_status()
	if facility_preview_controller != null:
		facility_preview_controller.draw_placement()

	if show_interaction_range:
		var origin: Vector2 = to_local(_get_interaction_origin())
		var half_angle: float = deg_to_rad(interaction_angle_degrees * 0.5)
		var base_angle: float = aim_direction.angle()
		var point_count: int = 28
		var sector_points := PackedVector2Array([origin])

		for i in range(point_count + 1):
			var t: float = float(i) / float(point_count)
			var angle: float = base_angle - half_angle + t * half_angle * 2.0
			sector_points.append(origin + Vector2.RIGHT.rotated(angle) * interaction_radius)

		draw_colored_polygon(sector_points, interaction_range_fill_color)
		draw_arc(origin, interaction_radius, 0.0, TAU, 72, interaction_range_circle_color, 2.0, true)
		draw_arc(origin, interaction_radius, base_angle - half_angle, base_angle + half_angle, point_count, interaction_range_edge_color, 3.0, true)
		draw_line(origin, origin + Vector2.RIGHT.rotated(base_angle - half_angle) * interaction_radius, interaction_range_edge_color, 2.0, true)
		draw_line(origin, origin + Vector2.RIGHT.rotated(base_angle + half_angle) * interaction_radius, interaction_range_edge_color, 2.0, true)

	if show_item_push_debug and is_instance_valid(item_push_collision_shape):
		var debug_direction: Vector2 = Vector2.ZERO
		if combat_controller != null and combat_controller.is_dash_active():
			debug_direction = velocity.normalized()
			if debug_direction.length_squared() <= 0.000001:
				debug_direction = combat_controller.get_dash_direction().normalized()
		var capsule_data: Dictionary = push_controller.get_active_push_capsule_data(debug_direction) if push_controller != null else {}
		if not capsule_data.is_empty():
			var local_center: Vector2 = to_local(capsule_data.get("center", global_position))
			var top_center: Vector2 = to_local(capsule_data.get("top", global_position))
			var bottom_center: Vector2 = to_local(capsule_data.get("bottom", global_position))
			var radius: float = float(capsule_data.get("radius", 0.0))
			var segment_axis: Vector2 = bottom_center - top_center
			if segment_axis.length_squared() > 0.000001:
				var normal: Vector2 = segment_axis.normalized().orthogonal() * radius
				var rect_points := PackedVector2Array([
					top_center + normal,
					bottom_center + normal,
					bottom_center - normal,
					top_center - normal
				])
				draw_colored_polygon(rect_points, item_push_debug_fill_color)
				draw_line(top_center + normal, bottom_center + normal, item_push_debug_outline_color, 2.0, true)
				draw_line(top_center - normal, bottom_center - normal, item_push_debug_outline_color, 2.0, true)
			draw_circle(top_center, radius, item_push_debug_fill_color)
			draw_circle(bottom_center, radius, item_push_debug_fill_color)
			draw_arc(top_center, radius, 0.0, TAU, 28, item_push_debug_outline_color, 2.0, true)
			draw_arc(bottom_center, radius, 0.0, TAU, 28, item_push_debug_outline_color, 2.0, true)

func _get_interaction_origin() -> Vector2:
	return global_position + interaction_origin_offset

func _can_damage_target_across_zones(target_position: Vector2) -> bool:
	if not is_instance_valid(prototype_map):
		_resolve_prototype_map()
	return ZoneInteractionQuery.can_points_interact(prototype_map, get_sort_origin(), target_position)

func _build_buff_indicator() -> void:
	if buff_indicator != null:
		return
	buff_indicator = PlayerBuffIndicator.new()
	buff_indicator.name = "BuffIndicator"
	buff_indicator.position = Vector2(0.0, -96.0)
	buff_indicator.z_index = 23
	add_child(buff_indicator)

func _update_buff_indicator() -> void:
	if buff_indicator == null:
		return

	var move_active: bool = false
	var move_progress: float = 1.0
	var cook_active: bool = false
	var cook_progress: float = 1.0
	var big_active: bool = false
	var big_progress: float = 1.0
	if skill_controller != null:
		if skill_controller.has_method("is_small_move_buff_active"):
			move_active = bool(skill_controller.is_small_move_buff_active())
		if skill_controller.has_method("get_small_move_buff_progress"):
			move_progress = float(skill_controller.get_small_move_buff_progress())
		if skill_controller.has_method("is_big_skill_buff_active"):
			big_active = bool(skill_controller.is_big_skill_buff_active())
		if skill_controller.has_method("get_big_skill_buff_progress"):
			big_progress = float(skill_controller.get_big_skill_buff_progress())
		cook_active = big_active
		cook_progress = big_progress
	if buff_indicator.has_method("set_buff_state"):
		buff_indicator.set_buff_state(move_active, move_progress, cook_active, cook_progress, big_active, big_progress)
