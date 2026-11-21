extends CharacterBody2D

const InteractionGeometry = preload("res://Scripts/Core/InteractionGeometry.gd")

const TestItemDefs = preload("res://Scripts/Kitchen/TestItemDefs.gd")
const CarryItemRules = preload("res://Scripts/Kitchen/CarryItemRules.gd")
const LevelRefs = preload("res://Scripts/Core/LevelRefs.gd")

@export var initial_item_id: StringName = &""
@export var initial_process_state: StringName = TestItemDefs.PROCESS_STATE_NONE

@export var pickup_distance: float = 136.0
@export var interaction_area_center: Vector2 = Vector2(0, -6)
@export var interaction_area_size: Vector2 = Vector2(56, 56)
@export var interaction_area_columns: int = 3
@export var interaction_area_rows: int = 3
@export var collision_radius: float = 20.0
@export var movement_bounds: Rect2 = Rect2(Vector2.ZERO, Vector2(1792, 1152))
@export var edge_padding: Vector2 = Vector2(18, 18)
@export var immediate_move_substep_pixels: float = 4.0
@export var linear_drag: float = 1080.0
@export var high_speed_linear_drag: float = 3200.0
@export var high_speed_drag_threshold: float = 420.0
@export var max_slide_speed: float = 780.0
@export var player_push_speed_cap: float = 520.0
@export var attack_push_speed: float = 760.0
@export var attack_spin_speed: float = 19.5
@export var push_spin_factor: float = 0.00032
@export var push_spin_low_speed_multiplier: float = 0.16
@export var push_spin_speed_reference: float = 1512.0
@export var push_spin_speed_curve: float = 1.35
@export var angular_drag: float = 16.0
@export var max_spin_speed: float = 16.0
@export var push_position_factor: float = 1.0
@export var normal_scale: Vector2 = Vector2(0.56, 0.56)
@export var highlight_scale: Vector2 = Vector2(0.56, 0.56)
@export var normal_modulate: Color = Color.WHITE
@export var highlight_modulate: Color = Color(1.22, 1.18, 1.0, 1.0)
@export var show_interaction_debug: bool = false
@export var debug_area_fill_color: Color = Color(1.0, 0.72, 0.22, 0.18)
@export var debug_area_outline_color: Color = Color(1.0, 0.82, 0.42, 0.92)
@export var debug_point_fill_color: Color = Color(1.0, 0.95, 0.72, 0.95)
@export var debug_point_outline_color: Color = Color(1.0, 0.82, 0.42, 0.95)
@export var debug_point_radius: float = 4.0
@export var debug_collision_fill_color: Color = Color(1.0, 0.32, 0.26, 0.12)
@export var debug_collision_outline_color: Color = Color(1.0, 0.42, 0.38, 0.88)
@export var overlap_push_strength: float = 0.6
@export var overlap_epsilon: float = 0.1
@export var chain_push_max_depth: int = 3
@export var chain_push_hard_limit: int = 10
@export var chain_push_warning_depth: int = 6
@export var enable_chain_push_diagnostics: bool = true

@onready var sprite: Sprite2D = $Sprite2D
@onready var process_state_mark: Node2D = $ProcessStateMark
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

var item_id: StringName = &""
var item_texture: Texture2D
var item_process_state: StringName = TestItemDefs.PROCESS_STATE_NONE
var item_recipe_signature: String = ""
var item_payload: Dictionary = {}
var player: CharacterBody2D
var level_refs: LevelRefs
var spin_velocity: float = 0.0
var is_highlighted: bool = false
var _chain_push_warning_frames: Dictionary = {}

func _ready() -> void:
	add_to_group("pickup_drop_targets")
	add_to_group("damageables")
	add_to_group("pushable_items")
	add_to_group("loose_items")
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	safe_margin = 0.01
	_find_player()
	_refresh_collision_shape()
	_refresh_world_bounds()
	_apply_initial_item_state()
	_refresh_visual()
	set_pickup_drop_highlight(false)

func _process(_delta: float) -> void:
	if show_interaction_debug:
		queue_redraw()

func _physics_process(delta: float) -> void:
	if not is_instance_valid(player):
		_find_player()

	_apply_drag(delta)
	if velocity.length() > max_slide_speed:
		velocity = velocity.limit_length(max_slide_speed)

	move_and_slide()
	_resolve_overlaps()
	_clamp_to_map_bounds()
	_update_spin(delta)

func setup_item(new_item_id: StringName, new_item_texture: Texture2D, new_item_process_state: StringName = TestItemDefs.PROCESS_STATE_NONE, new_recipe_signature: String = "", payload: Dictionary = {}) -> void:
	item_payload = payload.duplicate(true)
	item_id = new_item_id
	item_texture = new_item_texture
	item_process_state = TestItemDefs.normalize_process_state(new_item_process_state)
	item_recipe_signature = new_recipe_signature
	_refresh_visual()

func _apply_initial_item_state() -> void:
	if initial_item_id == &"":
		return

	item_id = initial_item_id
	item_process_state = TestItemDefs.normalize_process_state(initial_process_state)
	if item_texture == null and TestItemDefs.is_supported_item(item_id):
		item_texture = TestItemDefs.get_item_texture(item_id)

func can_take_item(target_player: Node) -> bool:
	return not is_queued_for_deletion() and item_id != &"" and target_player.has_method("can_pick_up_item") and target_player.can_pick_up_item(item_id, item_process_state, item_payload)

func is_pickup_drop_focusable(target_player: Node) -> bool:
	# Invalid plate contents still consume J focus instead of dropping the plate.
	return not is_queued_for_deletion() and (item_id == TestItemDefs.PLATE_ID or can_take_item(target_player) or can_receive_item(target_player) or CarryItemRules.is_collecting(target_player))

func can_take_plate_portion(target_player: Node) -> bool:
	return not is_queued_for_deletion() and CarryItemRules.can_take_last_portion(target_player, item_id, item_payload)

func interact_with_player(target_player: Node) -> bool:
	if is_queued_for_deletion() or not CarryItemRules.take_last_portion(target_player, item_id, item_payload):
		return false
	_update_item_visual()
	return true

func is_scarab_steal_target() -> bool:
	return visible and TestItemDefs.is_ingredient(item_id) and not TestItemDefs.is_boss_ingredient(item_id)

func can_receive_item(target_player: Node) -> bool:
	return not is_queued_for_deletion() and CarryItemRules.can_put_into_plate(target_player, item_id, item_payload)

func take_item_to_player(target_player: Node) -> bool:
	if not can_take_item(target_player):
		return false
	if not target_player.has_method("pick_up_item"):
		return false

	var leave_box: bool = CarryItemRules.take_leaves_box(target_player, item_id, item_payload)
	var was_picked_up: Variant = target_player.pick_up_item(item_id, item_texture, item_process_state, item_recipe_signature, item_payload)
	if was_picked_up is bool and was_picked_up:
		if leave_box:
			item_payload["servings"] = int(item_payload.servings) - 1
			_update_item_visual()
			return true
		queue_free()
		return true
	return false

func receive_item_from_player(target_player: Node) -> bool:
	if not can_receive_item(target_player) or not CarryItemRules.put_into_plate(target_player, item_id, item_payload):
		return false
	_update_item_visual()
	return true

func get_interaction_button_prompt(target_player: Node) -> String:
	if can_receive_item(target_player):
		return "J 放入盘中"
	if can_take_plate_portion(target_player):
		return "J 拿起整盘 / K 取出最后一份"
	return "J TAKE" if can_take_item(target_player) else ""

func receive_hit(_damage: int, hit_direction: Vector2 = Vector2.ZERO) -> void:
	var push_direction: Vector2 = hit_direction.normalized() if hit_direction.length_squared() > 0.001 else Vector2.RIGHT
	velocity = (velocity + push_direction * attack_push_speed).limit_length(max_slide_speed)
	spin_velocity = clampf(spin_velocity + attack_spin_speed * _get_spin_sign(push_direction), -max_spin_speed, max_spin_speed)

func get_hit_position() -> Vector2:
	return to_global(interaction_area_center)

func get_hit_radius() -> float:
	return collision_radius

func get_item_id() -> StringName:
	return item_id

func get_item_process_state() -> StringName:
	return item_process_state

func get_pickup_drop_positions() -> Array[Vector2]:
	return InteractionGeometry.grid_points(global_transform, interaction_area_center, interaction_area_size, interaction_area_columns, interaction_area_rows)

func get_interaction_rect_global() -> Rect2:
	return InteractionGeometry.world_rect(global_transform, interaction_area_center, interaction_area_size)

func get_pickup_drop_position() -> Vector2:
	return to_global(interaction_area_center)

func get_pickup_drop_radius() -> float:
	return pickup_distance

func set_pickup_drop_highlight(active: bool) -> void:
	is_highlighted = active
	_update_item_visual()

func _refresh_visual() -> void:
	if not is_instance_valid(sprite):
		return

	sprite.texture = item_texture
	_update_item_visual()

func _update_item_visual() -> void:
	if not is_instance_valid(sprite):
		return

	sprite.texture = TestItemDefs.get_world_item_texture(item_id, item_payload, item_texture)
	sprite.scale = highlight_scale if is_highlighted else normal_scale
	var state_modulate: Color = TestItemDefs.get_item_modulate(item_process_state, item_id)
	sprite.modulate = state_modulate * (highlight_modulate if is_highlighted else normal_modulate)
	if is_instance_valid(process_state_mark):
		process_state_mark.scale = sprite.scale
		if process_state_mark.has_method("set_process_state"):
			process_state_mark.call("set_item_data", item_id, item_process_state, item_payload, item_id != &"")

func _refresh_collision_shape() -> void:
	if not is_instance_valid(collision_shape):
		return

	var shape := collision_shape.shape as CircleShape2D
	if shape:
		shape.radius = collision_radius
	collision_shape.position = interaction_area_center

func _refresh_world_bounds() -> void:
	level_refs = LevelRefs.find_from(self)
	if level_refs == null:
		return

	var prototype_map: Node = level_refs.get_prototype_map()
	if prototype_map != null and prototype_map.has_method("get_world_bounds"):
		movement_bounds = prototype_map.get_world_bounds()

func _find_player() -> void:
	var found_player: Node = get_tree().get_first_node_in_group("player")
	if found_player is CharacterBody2D:
		player = found_player

func _apply_drag(delta: float) -> void:
	var current_speed: float = velocity.length()
	var applied_drag: float = linear_drag
	if current_speed > high_speed_drag_threshold:
		var threshold_range: float = maxf(max_slide_speed - high_speed_drag_threshold, 0.001)
		var high_speed_ratio: float = clampf((current_speed - high_speed_drag_threshold) / threshold_range, 0.0, 1.0)
		applied_drag = lerpf(linear_drag, high_speed_linear_drag, high_speed_ratio)

	velocity = velocity.move_toward(Vector2.ZERO, applied_drag * delta)
	spin_velocity = move_toward(spin_velocity, 0.0, angular_drag * delta)

func _update_spin(delta: float) -> void:
	rotation += spin_velocity * delta

func _clamp_to_map_bounds() -> void:
	var item_center: Vector2 = to_global(interaction_area_center)
	var min_pos: Vector2 = movement_bounds.position + edge_padding
	var max_pos: Vector2 = movement_bounds.position + movement_bounds.size - edge_padding
	var clamped_center: Vector2 = item_center.clamp(min_pos, max_pos)
	if clamped_center != item_center:
		_move_with_collision(clamped_center - item_center)

func _resolve_overlaps() -> void:
	var own_center: Vector2 = get_push_center()
	var min_distance: float = collision_radius * 2.0

	for candidate in get_tree().get_nodes_in_group("pushable_items"):
		if candidate == self or not is_instance_valid(candidate):
			continue
		if candidate.get_instance_id() < get_instance_id():
			continue
		if not candidate.has_method("get_push_center") or not candidate.has_method("get_push_radius"):
			continue

		var other_center: Vector2 = candidate.get_push_center()
		var other_radius: float = float(candidate.get_push_radius())
		var target_distance: float = collision_radius + other_radius
		var offset: Vector2 = other_center - own_center
		var distance: float = offset.length()
		if distance >= target_distance - overlap_epsilon:
			continue

		var direction: Vector2
		if distance <= 0.0001:
			var angle_seed: float = float(get_instance_id() % 360)
			direction = Vector2.RIGHT.rotated(deg_to_rad(angle_seed))
		else:
			direction = offset / distance

		var overlap_amount: float = maxf(target_distance - distance, 0.0)
		var separation: Vector2 = direction * overlap_amount * 0.5 * overlap_push_strength
		_move_with_collision(-separation)
		if candidate.has_method("_move_with_collision"):
			candidate._move_with_collision(separation)
		if candidate.has_method("_clamp_to_map_bounds"):
			candidate._clamp_to_map_bounds()
		own_center = get_push_center()

func _get_spin_sign(direction: Vector2) -> float:
	if absf(direction.x) >= 0.01:
		return signf(direction.x)
	return 1.0

func get_push_center() -> Vector2:
	return to_global(interaction_area_center)

func get_push_radius() -> float:
	return collision_radius

func apply_player_push(
	push_direction: Vector2,
	push_amount: float,
	player_velocity: Vector2,
	separation_motion: Vector2 = Vector2.ZERO,
	chain_depth: int = 0,
	pushed_item_ids: Dictionary = {}
) -> void:
	if push_direction.length_squared() <= 0.000001 or (push_amount <= 0.0 and separation_motion.length_squared() <= 0.000001):
		return
	if _should_abort_chain_push(chain_depth, pushed_item_ids, "apply_player_push"):
		return

	if separation_motion.length_squared() > 0.000001:
		var chain_ids: Dictionary = pushed_item_ids
		if chain_ids.is_empty():
			chain_ids = {get_instance_id(): true}
		elif not chain_ids.has(get_instance_id()):
			chain_ids = chain_ids.duplicate()
			chain_ids[get_instance_id()] = true
		_move_with_collision(
			separation_motion * push_position_factor,
			true,
			chain_depth + 1,
			chain_ids
		)
		_clamp_to_map_bounds()

	velocity = (velocity + push_direction.normalized() * push_amount).limit_length(player_push_speed_cap)
	var spin_source: float = maxf(push_amount, separation_motion.length() * 26.0)
	var speed_ratio: float = clampf(player_velocity.length() / maxf(push_spin_speed_reference, 0.001), 0.0, 1.0)
	var speed_weight: float = lerpf(push_spin_low_speed_multiplier, 1.0, pow(speed_ratio, push_spin_speed_curve))
	var push_spin_impulse: float = minf(spin_source * push_spin_factor * speed_weight, 0.16)
	spin_velocity = clampf(spin_velocity + push_spin_impulse * _get_spin_sign(player_velocity), -max_spin_speed, max_spin_speed)

func apply_conveyor_motion(motion: Vector2) -> void:
	if motion.length_squared() <= 0.000001:
		return
	_move_with_collision(motion, true)
	_clamp_to_map_bounds()

func _move_with_collision(motion: Vector2, allow_chain_push: bool = false, chain_depth: int = 0, pushed_item_ids: Dictionary = {}) -> bool:
	if motion.length_squared() <= 0.000001:
		return false
	if allow_chain_push and _should_abort_chain_push(chain_depth, pushed_item_ids, "_move_with_collision"):
		return false

	var max_component: float = maxf(absf(motion.x), absf(motion.y))
	var step_size: float = maxf(immediate_move_substep_pixels, 0.001)
	var steps: int = max(1, int(ceil(max_component / step_size)))
	var step_motion: Vector2 = motion / float(steps)
	var moved_any: bool = false

	for _i in range(steps):
		if _try_move_axis(Vector2(step_motion.x, 0.0), allow_chain_push, chain_depth, pushed_item_ids):
			moved_any = true
		if _try_move_axis(Vector2(0.0, step_motion.y), allow_chain_push, chain_depth, pushed_item_ids):
			moved_any = true

	return moved_any

func _try_move_axis(axis_motion: Vector2, allow_chain_push: bool = false, chain_depth: int = 0, pushed_item_ids: Dictionary = {}) -> bool:
	if axis_motion.length_squared() <= 0.000001:
		return false
	if allow_chain_push and _should_abort_chain_push(chain_depth, pushed_item_ids, "_try_move_axis"):
		return false

	if test_move(global_transform, axis_motion):
		if allow_chain_push and chain_depth < chain_push_max_depth:
			var chain_ids: Dictionary = pushed_item_ids
			if chain_ids.is_empty():
				chain_ids = {get_instance_id(): true}
			elif not chain_ids.has(get_instance_id()):
				chain_ids = chain_ids.duplicate()
				chain_ids[get_instance_id()] = true

			var push_attempts: int = 0
			while push_attempts < 2 and _push_blocking_items_for_axis(axis_motion, chain_depth, chain_ids):
				if not test_move(global_transform, axis_motion):
					global_position += axis_motion
					return true
				push_attempts += 1
		return false

	global_position += axis_motion
	return true

func _push_blocking_items_for_axis(axis_motion: Vector2, chain_depth: int, pushed_item_ids: Dictionary) -> bool:
	var push_direction: Vector2 = axis_motion.normalized()
	if push_direction.length_squared() <= 0.000001:
		return false
	if _should_abort_chain_push(chain_depth, pushed_item_ids, "_push_blocking_items_for_axis"):
		return false

	var own_center: Vector2 = get_push_center()
	var own_radius: float = get_push_radius()
	var moved_any: bool = false
	var push_passes: int = 0
	var max_push_passes: int = 4
	while push_passes < max_push_passes:
		var push_queue: Array[Dictionary] = _build_item_push_queue(axis_motion, own_center, own_radius, pushed_item_ids)
		if push_queue.is_empty():
			break

		var moved_this_pass: bool = false
		var front_actual_shift: float = -1.0
		var front_axis_position: float = 0.0
		var front_radius: float = 0.0
		for queue_index in range(push_queue.size() - 1, -1, -1):
			var push_entry: Dictionary = push_queue[queue_index]
			var candidate: Node = push_entry.get("item")
			if not is_instance_valid(candidate):
				continue
			var candidate_radius: float = float(push_entry.get("radius", 0.0))
			var candidate_axis_position: float = float(push_entry.get("axis_position", 0.0))
			var required_axis_shift: float = float(push_entry.get("required_axis_shift", 0.0))
			var propagated_axis_shift: float = required_axis_shift
			if front_actual_shift >= 0.0:
				var gap_to_front: float = front_axis_position - candidate_axis_position - candidate_radius - front_radius
				propagated_axis_shift = minf(propagated_axis_shift, front_actual_shift + maxf(gap_to_front, 0.0))
			front_axis_position = candidate_axis_position
			front_radius = candidate_radius
			if propagated_axis_shift <= 0.001:
				front_actual_shift = 0.0
				continue
			var next_chain_ids: Dictionary = pushed_item_ids.duplicate()
			next_chain_ids[candidate.get_instance_id()] = true
			var separation_motion: Vector2 = push_direction * minf(propagated_axis_shift + 0.08, axis_motion.length() + own_radius * 0.42)
			var previous_center: Vector2 = candidate.get_push_center()
			if candidate.has_method("apply_player_push"):
				var inherited_velocity: Vector2 = velocity
				if inherited_velocity.length_squared() <= 0.000001:
					inherited_velocity = push_direction * player_push_speed_cap
				var inherited_push_force: float = minf(player_push_speed_cap * 0.22, separation_motion.length() * 20.0)
				candidate.apply_player_push(
					push_direction,
					inherited_push_force,
					inherited_velocity,
					separation_motion,
					chain_depth,
					next_chain_ids
				)
			var moved_center: Vector2 = candidate.get_push_center()
			var actual_axis_shift: float = maxf((moved_center - previous_center).dot(push_direction), 0.0)
			front_actual_shift = actual_axis_shift
			if actual_axis_shift <= 0.001:
				continue
			moved_this_pass = true
			moved_any = true

		if not moved_this_pass:
			break
		push_passes += 1

	return moved_any

func _should_abort_chain_push(chain_depth: int, pushed_item_ids: Dictionary, stage: String) -> bool:
	var visited_count: int = pushed_item_ids.size()
	if chain_depth >= chain_push_hard_limit or visited_count > chain_push_hard_limit * 3:
		_report_chain_push_diagnostic("abort", stage, chain_depth, visited_count, pushed_item_ids)
		return true
	if chain_depth >= chain_push_warning_depth or visited_count > chain_push_warning_depth * 2:
		_report_chain_push_diagnostic("warn", stage, chain_depth, visited_count, pushed_item_ids)
	return false

func _report_chain_push_diagnostic(level: String, stage: String, chain_depth: int, visited_count: int, pushed_item_ids: Dictionary) -> void:
	if not enable_chain_push_diagnostics:
		return

	var current_frame: int = Engine.get_process_frames()
	var dedupe_key: String = "%s:%s:%d:%d" % [level, stage, chain_depth, visited_count]
	var last_frame: int = int(_chain_push_warning_frames.get(dedupe_key, -999999))
	if current_frame - last_frame < 20:
		return
	_chain_push_warning_frames[dedupe_key] = current_frame

	var visited_ids: Array = pushed_item_ids.keys()
	visited_ids.sort()
	var sample_ids: Array = []
	var max_sample: int = min(visited_ids.size(), 8)
	for i in range(max_sample):
		sample_ids.append(str(visited_ids[i]))

	var message: String = "LooseItem chain push %s at %s | depth=%d visited=%d self=%d sample=[%s]" % [
		level,
		stage,
		chain_depth,
		visited_count,
		get_instance_id(),
		", ".join(sample_ids)
	]
	if level == "abort":
		push_warning(message)
	else:
		print(message)

func _build_item_push_queue(axis_motion: Vector2, own_center: Vector2, own_radius: float, pushed_item_ids: Dictionary) -> Array[Dictionary]:
	var push_direction: Vector2 = axis_motion.normalized()
	if push_direction.length_squared() <= 0.000001:
		return []

	var future_center: Vector2 = own_center + axis_motion
	var current_axis_position: float = own_center.dot(push_direction)
	var target_axis_position: float = future_center.dot(push_direction) + own_radius
	var candidate_entries: Dictionary = {}
	var search_queue: Array[Dictionary] = []

	for candidate in get_tree().get_nodes_in_group("pushable_items"):
		if candidate == self or not is_instance_valid(candidate):
			continue
		if pushed_item_ids.has(candidate.get_instance_id()):
			continue
		if not candidate.has_method("get_push_center") or not candidate.has_method("get_push_radius") or not candidate.has_method("_move_with_collision"):
			continue

		var candidate_center: Vector2 = candidate.get_push_center()
		var candidate_radius: float = float(candidate.get_push_radius())
		var contact_distance: float = own_radius + candidate_radius
		var closest_point_on_sweep: Vector2 = InteractionGeometry.closest_point_on_segment(candidate_center, own_center, future_center)
		var sweep_distance: float = candidate_center.distance_to(closest_point_on_sweep)
		if sweep_distance > contact_distance + 0.5:
			continue

		var candidate_axis_position: float = candidate_center.dot(push_direction)
		if candidate_axis_position + candidate_radius < current_axis_position - maxf(own_radius * 0.1, 0.5):
			continue

		var candidate_entry := {
			"item": candidate,
			"center": candidate_center,
			"radius": candidate_radius,
			"axis_position": candidate_axis_position,
			"contact_distance": contact_distance
		}
		candidate_entries[candidate.get_instance_id()] = candidate_entry
		search_queue.append(candidate_entry)

	while not search_queue.is_empty():
		var source_entry: Dictionary = search_queue.pop_back()
		var source_center: Vector2 = source_entry.get("center", Vector2.ZERO)
		var source_radius: float = float(source_entry.get("radius", 0.0))

		for candidate in get_tree().get_nodes_in_group("pushable_items"):
			if candidate == self or not is_instance_valid(candidate):
				continue
			var candidate_id: int = candidate.get_instance_id()
			if pushed_item_ids.has(candidate_id) or candidate_entries.has(candidate_id):
				continue
			if not candidate.has_method("get_push_center") or not candidate.has_method("get_push_radius") or not candidate.has_method("_move_with_collision"):
				continue

			var candidate_center: Vector2 = candidate.get_push_center()
			var candidate_radius: float = float(candidate.get_push_radius())
			var candidate_axis_position: float = candidate_center.dot(push_direction)
			if candidate_axis_position + candidate_radius < current_axis_position - maxf(own_radius * 0.2, 1.0):
				continue
			var neighbor_distance: float = source_center.distance_to(candidate_center)
			var neighbor_limit: float = source_radius + candidate_radius + maxf(axis_motion.length(), 6.0)
			if neighbor_distance > neighbor_limit:
				continue

			var expanded_entry := {
				"item": candidate,
				"center": candidate_center,
				"radius": candidate_radius,
				"axis_position": candidate_axis_position,
				"contact_distance": own_radius + candidate_radius
			}
			candidate_entries[candidate_id] = expanded_entry
			search_queue.append(expanded_entry)

	if candidate_entries.is_empty():
		return []

	var sorted_candidates: Array = candidate_entries.values()
	sorted_candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.get("axis_position", 0.0)) < float(b.get("axis_position", 0.0))
	)

	var push_queue: Array[Dictionary] = []
	for candidate_entry in sorted_candidates:
		var candidate_radius: float = float(candidate_entry.get("radius", 0.0))
		target_axis_position += candidate_radius
		var required_axis_shift: float = maxf(target_axis_position - float(candidate_entry.get("axis_position", 0.0)), 0.0)
		candidate_entry["required_axis_shift"] = required_axis_shift
		push_queue.append(candidate_entry)
		target_axis_position += candidate_radius

	return push_queue

func _draw() -> void:
	if not show_interaction_debug:
		return

	var area_rect := Rect2(interaction_area_center - interaction_area_size * 0.5, interaction_area_size)
	draw_rect(area_rect, debug_area_fill_color, true)
	draw_rect(area_rect, debug_area_outline_color, false, 2.0)
	draw_circle(interaction_area_center, collision_radius, debug_collision_fill_color)
	draw_arc(interaction_area_center, collision_radius, 0.0, TAU, 28, debug_collision_outline_color, 2.0, true)

	var columns: int = max(interaction_area_columns, 1)
	var rows: int = max(interaction_area_rows, 1)
	var top_left: Vector2 = interaction_area_center - interaction_area_size * 0.5

	for y in range(rows):
		var y_ratio: float = 0.5 if rows == 1 else float(y) / float(rows - 1)
		for x in range(columns):
			var x_ratio: float = 0.5 if columns == 1 else float(x) / float(columns - 1)
			var local_position := top_left + Vector2(interaction_area_size.x * x_ratio, interaction_area_size.y * y_ratio)
			draw_circle(local_position, debug_point_radius, debug_point_fill_color)
			draw_arc(local_position, debug_point_radius, 0.0, TAU, 20, debug_point_outline_color, 2.0, true)
