extends RefCounted

const AudioCue = preload("res://Scripts/Audio/AudioCue.gd")

const LOOSE_ITEM_SCENE := preload("res://Scenes/Restaurant/loose_item.tscn")
const PROCESS_STATE_MARK_SCENE := preload("res://Scripts/Kitchen/ProcessStateMark.gd")
const HeldItemBubbleView = preload("res://Scripts/UI/HeldItemBubbleView.gd")
const InteractionPromptView = preload("res://Scripts/UI/InteractionPromptView.gd")
const InteractionFocusQuery = preload("res://Scripts/Player/InteractionFocusQuery.gd")
const LevelRefs = preload("res://Scripts/Core/LevelRefs.gd")
const TestItemDefs = preload("res://Scripts/Kitchen/TestItemDefs.gd")
const CarryItemRules = preload("res://Scripts/Kitchen/CarryItemRules.gd")

var player: CharacterBody2D
var held_item_sprite: Sprite2D
var interaction_progress_bar: Node2D
var prompt_view: RefCounted
var push_controller: RefCounted

var held_item_id: StringName = &""
var held_item_process_state: StringName = TestItemDefs.PROCESS_STATE_NONE
var held_item_recipe_signature: String = ""
var held_item_payload: Dictionary = {}
var pickup_hold_requires_release: bool = false
var current_interaction_target_ref: WeakRef
var current_interaction_focus_data: Dictionary = {}
var floor_interaction_position: Vector2 = Vector2.ZERO
var hint_label: Label
var hint_generation: int = 0
var process_status_bubble: Panel
var held_item_bubble: RefCounted
var held_item_process_mark: Node2D

func setup(new_player: CharacterBody2D, new_held_item_sprite: Sprite2D, new_interaction_progress_bar: Node2D) -> void:
	player = new_player
	held_item_sprite = new_held_item_sprite
	interaction_progress_bar = new_interaction_progress_bar
	if held_item_sprite != null:
		held_item_sprite.visible = false
		_ensure_held_item_process_mark()
	_ensure_interaction_button_prompt()
	_ensure_process_status_bubble()

func show_hint(message: String) -> void:
	if not is_instance_valid(player):
		return
	if hint_label == null:
		hint_label = Label.new()
		hint_label.position = Vector2(-220, -225)
		hint_label.size = Vector2(440, 40)
		hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hint_label.add_theme_font_size_override("font_size", 22)
		hint_label.add_theme_color_override("font_outline_color", Color("221a13"))
		hint_label.add_theme_constant_override("outline_size", 6)
		hint_label.z_index = 150
		player.add_child(hint_label)
	hint_generation += 1
	var generation: int = hint_generation
	hint_label.text = message
	hint_label.show()
	await player.get_tree().create_timer(1.8).timeout
	if is_instance_valid(hint_label) and generation == hint_generation:
		hint_label.hide()

func set_push_controller(new_push_controller: RefCounted) -> void:
	push_controller = new_push_controller

func is_holding_item() -> bool:
	return held_item_id != &""

func can_pick_up_item(item_id: StringName = &"", process_state: StringName = TestItemDefs.PROCESS_STATE_NONE, payload: Dictionary = {}) -> bool:
	return not is_holding_item() or (held_item_id == TestItemDefs.PLATE_ID and (CarryItemRules.can_collect(held_item_payload, item_id, process_state, payload) or CarryItemRules.can_load_dish(held_item_payload, item_id, payload)))

func pick_up_item(item_id: StringName, item_texture: Texture2D, process_state: StringName = TestItemDefs.PROCESS_STATE_NONE, recipe_signature: String = "", payload: Dictionary = {}) -> bool:
	if is_holding_item():
		if not can_pick_up_item(item_id, process_state, payload):
			if held_item_id == TestItemDefs.PLATE_ID:
				show_hint("运输盘已满或该物品不能装盘")
			return false
		if CarryItemRules.can_load_dish(held_item_payload, item_id, payload):
			var dish_payload: Dictionary = payload.duplicate(true)
			dish_payload["uses_plate"] = true
			clear_held_item()
			return pick_up_item(item_id, item_texture, process_state, recipe_signature, dish_payload)
		var contents: Array = held_item_payload.get("items", [])
		contents.append(CarryItemRules.portion(item_id, process_state, recipe_signature, payload))
		held_item_payload["items"] = contents
		_update_held_item_process_mark()
		return true
	held_item_payload = payload.duplicate(true)

	held_item_id = item_id
	held_item_process_state = TestItemDefs.normalize_process_state(process_state)
	held_item_recipe_signature = recipe_signature
	if held_item_sprite != null:
		held_item_sprite.texture = TestItemDefs.get_world_item_texture(item_id, held_item_payload, item_texture)
		held_item_sprite.modulate = TestItemDefs.get_item_modulate(held_item_process_state)
		held_item_sprite.visible = held_item_sprite.texture != null
	_update_held_item_process_mark()
	return true

func set_held_item_payload(payload: Dictionary) -> void:
	held_item_payload = payload.duplicate(true)
	if held_item_sprite != null:
		held_item_sprite.texture = TestItemDefs.get_world_item_texture(held_item_id, held_item_payload, held_item_sprite.texture)
	_update_held_item_process_mark()

func get_held_item_payload() -> Dictionary:
	return held_item_payload.duplicate(true)

func get_held_item_id() -> StringName:
	return held_item_id

func get_held_item_texture() -> Texture2D:
	return held_item_sprite.texture if held_item_sprite != null else null

func get_held_item_process_state() -> StringName:
	return held_item_process_state

func get_held_item_recipe_signature() -> String:
	return held_item_recipe_signature

func clear_held_item() -> void:
	held_item_payload = {}
	held_item_id = &""
	held_item_process_state = TestItemDefs.PROCESS_STATE_NONE
	held_item_recipe_signature = ""
	if held_item_sprite != null:
		held_item_sprite.texture = null
		held_item_sprite.modulate = Color.WHITE
		held_item_sprite.visible = false
	_update_held_item_process_mark()

func _ensure_held_item_process_mark() -> void:
	if player == null or held_item_process_mark != null:
		return
	held_item_process_mark = PROCESS_STATE_MARK_SCENE.new()
	held_item_process_mark.name = "HeldItemProcessMark"
	held_item_process_mark.position = held_item_sprite.position
	held_item_process_mark.scale = held_item_sprite.scale
	held_item_process_mark.z_index = held_item_sprite.z_index + 1
	player.add_child(held_item_process_mark)
	held_item_process_mark.visible = false

func _update_held_item_process_mark() -> void:
	_update_process_status_bubble()
	if held_item_process_mark == null:
		return
	held_item_process_mark.position = held_item_sprite.position if held_item_sprite != null else Vector2.ZERO
	held_item_process_mark.scale = held_item_sprite.scale if held_item_sprite != null else Vector2.ONE
	if held_item_process_mark.has_method("set_process_state"):
		held_item_process_mark.call("set_item_data", held_item_id, held_item_process_state, held_item_payload, is_holding_item())

func _ensure_process_status_bubble() -> void:
	if player == null or process_status_bubble != null:
		return
	held_item_bubble = HeldItemBubbleView.new()
	held_item_bubble.setup(player)
	process_status_bubble = held_item_bubble.panel

func _update_process_status_bubble() -> void:
	if held_item_bubble != null:
		held_item_bubble.update(held_item_id, held_item_process_state, held_item_recipe_signature, held_item_payload)

func update_current_interaction_target(
	interaction_origin: Vector2,
	aim_direction: Vector2,
	interaction_radius: float,
	interaction_angle_degrees: float,
	floor_interaction_radius: float
) -> void:
	var safe_aim_direction: Vector2 = aim_direction.normalized() if aim_direction.length_squared() > 0.001 else Vector2.ZERO
	floor_interaction_position = interaction_origin + safe_aim_direction * floor_interaction_radius

	var result: Dictionary = InteractionFocusQuery.select_target(
		player, player.get_tree().get_nodes_in_group("pickup_drop_targets"), is_holding_item(),
		interaction_origin, aim_direction, interaction_radius, deg_to_rad(interaction_angle_degrees * 0.5)
	)
	_set_current_interaction_target(result.get("target"), result.get("focus_data", {}))

func handle_pickup_drop(aim_direction: Vector2) -> void:
	var target = _get_current_interaction_target_instance()
	if is_instance_valid(target):
		if is_holding_item():
			if held_item_id == TestItemDefs.PLATE_ID and target.has_method("can_take_item"):
				if target.can_take_item(player):
					if target.take_item_to_player(player):
						AudioCue.play_sfx(&"pickup", -4.0)
				elif target.has_method("receive_item_from_player") and not target.is_in_group("assembly_stations"):
					if target.receive_item_from_player(player):
						AudioCue.play_sfx(&"drop", -4.0)
				return
			if target.has_method("receive_item_from_player") and target.receive_item_from_player(player):
				AudioCue.play_sfx(&"drop", -4.0)
				if target.has_method("get_hold_interaction_action") and target.get_hold_interaction_action() == &"pickup_drop":
					pickup_hold_requires_release = true
				return
		else:
			if target.has_method("take_item_to_player") and target.take_item_to_player(player):
				AudioCue.play_sfx(&"pickup", -4.0)
				return
		return

	if is_holding_item():
		_drop_held_item_on_ground(aim_direction)

func handle_interact() -> void:
	var target = _get_current_interaction_target_instance()
	if not is_instance_valid(target):
		return

	if target.has_method("interact_with_player"):
		if target.interact_with_player(player):
			AudioCue.play_sfx(&"interaction", -8.0)

func update_interaction_progress_ui() -> void:
	if not is_instance_valid(interaction_progress_bar):
		return

	var target = _get_current_interaction_target_instance()
	if is_instance_valid(target) and target.has_method("get_interaction_progress_data"):
		var progress_data: Variant = target.get_interaction_progress_data(player)
		if progress_data is Dictionary and progress_data.get("visible", false):
			if progress_data.has("stage_boundaries"):
				interaction_progress_bar.set("stage_separator_color", Color(0.08, 0.04, 0.02, 0.96))
				interaction_progress_bar.call(
					"set_stage_state",
					true,
					progress_data.get("progress", 0.0),
					progress_data.get("stage_index", 0),
					progress_data.get("stage_progress", 0.0),
					progress_data.get("stage_boundaries", []),
					progress_data.get("stage_colors", []),
					progress_data.get("display_mode", &"split")
				)
			else:
				interaction_progress_bar.set_state(true, progress_data.get("progress", 0.0))
			interaction_progress_bar.set_maturity_icon(TestItemDefs.get_process_icon_texture(StringName(progress_data.get("process_state", &""))))
			_update_interaction_button_prompt()
			return

	interaction_progress_bar.set_state(false, 0.0)
	_update_interaction_button_prompt()

func update_held_interaction(delta: float) -> void:
	if preload("res://Scripts/Facilities/FacilityControlEffect.gd").rooted(player):
		return
	if not player.input_gate.is_pressed(&"pickup_drop"):
		pickup_hold_requires_release = false
	var target = _get_current_interaction_target_instance()
	if not is_instance_valid(target):
		return
	if not target.has_method("process_hold_interaction"):
		return
	var action: StringName = target.get_hold_interaction_action() if target.has_method("get_hold_interaction_action") else &"interact"
	# A fresh K press is handled by the player's just-pressed interaction path.
	# Skipping the held update on that same frame prevents tap + hold from
	# advancing a two-stage station twice (notably instant coarse/fine grind).
	if not player.input_gate.is_pressed(action) or player.input_gate.is_just_pressed(action) or (action == &"pickup_drop" and pickup_hold_requires_release):
		return
	if target.process_hold_interaction(player, delta) and not target.is_in_group("cooking_stations"):
		var cue: StringName = &"wash" if target.is_in_group("plate_sinks") else &"work_tick"
		AudioCue.work(target, cue)

func get_current_interaction_target():
	return _get_current_interaction_target_instance()

func clear_current_interaction_target_if_matches(target) -> void:
	var current_target = _get_current_interaction_target_instance()
	if target == null:
		return
	if current_target == null or current_target == target:
		_set_current_interaction_target(null)

func _set_current_interaction_target(new_target, focus_data: Dictionary = {}) -> void:
	var shutdown := preload("res://Scripts/Facilities/FacilityWorkPause.gd").effect_for(new_target)
	if shutdown != null:
		new_target = shutdown
	var current_target = _get_current_interaction_target_instance()
	var normalized_focus_data: Dictionary = focus_data if focus_data != null else {}
	if current_target == new_target and current_interaction_focus_data == normalized_focus_data:
		return

	if is_instance_valid(current_target):
		if current_target.has_method("set_pickup_drop_highlight"):
			current_target.set_pickup_drop_highlight(false)
		if current_target.has_method("set_pickup_drop_focus_data"):
			current_target.set_pickup_drop_focus_data(player, {})

	current_interaction_target_ref = weakref(new_target) if is_instance_valid(new_target) else null
	current_interaction_focus_data = normalized_focus_data

	var active_target = _get_current_interaction_target_instance()
	if is_instance_valid(active_target):
		if active_target.has_method("set_pickup_drop_highlight"):
			active_target.set_pickup_drop_highlight(true)
		if active_target.has_method("set_pickup_drop_focus_data"):
			active_target.set_pickup_drop_focus_data(player, current_interaction_focus_data)
	_update_interaction_button_prompt()

func _ensure_interaction_button_prompt() -> void:
	if not is_instance_valid(player) or prompt_view != null:
		return
	prompt_view = InteractionPromptView.new()
	prompt_view.setup(player)

func _update_interaction_button_prompt() -> void:
	_ensure_interaction_button_prompt()
	if prompt_view != null:
		prompt_view.update_prompt(_get_interaction_button_prompt_text(), _get_prompt_bottom_row_y(38.0))

func _get_prompt_bottom_row_y(key_height: float) -> float:
	if process_status_bubble != null and process_status_bubble.visible:
		var gap: float = 6.0
		return process_status_bubble.position.y - gap - key_height
	return -154.0

func _get_interaction_button_prompt_text() -> String:
	if player != null and player.has_method("is_carrying_facility") and bool(player.is_carrying_facility()):
		return "K 放置"
	if held_item_id == &"bear_trap":
		return "J 放下 / K 布置捕兽夹"
	var target = _get_current_interaction_target_instance()
	if not is_instance_valid(target):
		return ""
	if target.has_method("get_interaction_button_prompt"):
		return String(target.get_interaction_button_prompt(player))
	var parts: Array[String] = []
	if _can_current_target_pickup_drop(target):
		parts.append("J")
	if target.has_method("interact_with_player"):
		parts.append("K")
	return " / ".join(parts)

func _can_current_target_pickup_drop(target: Node) -> bool:
	if not is_instance_valid(target):
		return false
	if held_item_id == TestItemDefs.PLATE_ID and target.has_method("can_take_item") and target.can_take_item(player):
		return true
	if is_holding_item():
		return target.has_method("receive_item_from_player") and target.has_method("can_receive_item") and bool(target.can_receive_item(player))
	return target.has_method("take_item_to_player") and target.has_method("can_take_item") and bool(target.can_take_item(player))

func _get_current_interaction_target_instance():
	if current_interaction_target_ref == null:
		return null
	var target = current_interaction_target_ref.get_ref()
	if not is_instance_valid(target):
		current_interaction_target_ref = null
		current_interaction_focus_data = {}
		return null
	return target

func _drop_held_item_on_ground(aim_direction: Vector2) -> void:
	var level_refs: LevelRefs = LevelRefs.find_from(player)
	var parent_node: Node = level_refs.get_runtime_root() if level_refs != null else (player.get_tree().current_scene if player.get_tree().current_scene != null else player.get_parent())
	if parent_node == null:
		return

	var dropped_item: Node2D = LOOSE_ITEM_SCENE.instantiate()
	parent_node.add_child(dropped_item)
	if dropped_item.has_method("setup_item"):
		dropped_item.setup_item(held_item_id, get_held_item_texture(), held_item_process_state, held_item_recipe_signature, held_item_payload)

	var resolved_drop: Dictionary = _find_safe_ground_drop_position(
		dropped_item,
		floor_interaction_position,
		aim_direction,
	)
	if not resolved_drop.get("valid", false):
		dropped_item.queue_free()
		return
	dropped_item.global_position = resolved_drop.get("position", floor_interaction_position)
	if push_controller != null and push_controller.has_method("ignore_pushable_item_temporarily"):
		push_controller.ignore_pushable_item_temporarily(dropped_item, 0.16)
	if resolved_drop.has("player_position"):
		player.global_position = resolved_drop.get("player_position", player.global_position)
		if push_controller != null and push_controller.has_method("clamp_to_map_bounds"):
			push_controller.clamp_to_map_bounds()
	_ensure_player_not_stuck_after_drop(dropped_item, aim_direction)

	clear_held_item()
	AudioCue.play_sfx(&"drop", -4.0)

func _ensure_player_not_stuck_after_drop(
	dropped_item: Node2D,
	aim_direction: Vector2
) -> void:
	if not is_instance_valid(dropped_item):
		return
	if push_controller == null:
		return
	if not dropped_item.has_method("get_push_center") or not dropped_item.has_method("get_push_radius"):
		return

	var item_center: Vector2 = dropped_item.get_push_center()
	var item_radius: float = float(dropped_item.get_push_radius())
	if not _does_circle_overlap_player_body_at_position(item_center, item_radius + 2.0, player.global_position):
		return

	var body_data: Dictionary = push_controller.get_body_collision_data()
	var body_center: Vector2 = body_data.get("center", player.global_position)
	var body_radius: float = float(body_data.get("radius", 20.0))
	var separation_direction: Vector2 = item_center - body_center
	if separation_direction.length_squared() <= 0.000001:
		separation_direction = aim_direction if aim_direction.length_squared() > 0.000001 else Vector2.DOWN
	if separation_direction.length_squared() <= 0.000001:
		separation_direction = Vector2.DOWN
	separation_direction = separation_direction.normalized()
	var current_distance: float = body_center.distance_to(item_center)
	var target_distance: float = body_radius + item_radius + 4.0
	var push_distance: float = maxf(target_distance - current_distance, 0.0)
	if push_distance > 0.0 and dropped_item.has_method("apply_player_push"):
		dropped_item.apply_player_push(separation_direction, 0.0, Vector2.ZERO, separation_direction * push_distance)

func _find_safe_ground_drop_position(
	dropped_item: Node2D,
	desired_position: Vector2,
	aim_direction: Vector2
) -> Dictionary:
	if push_controller == null:
		return {}
	if not is_instance_valid(dropped_item):
		return {}
	if not dropped_item.has_method("get_push_center") or not dropped_item.has_method("get_push_radius"):
		return {"valid": true, "position": desired_position}

	var preferred_direction: Vector2 = aim_direction.normalized() if aim_direction.length_squared() > 0.000001 else Vector2.DOWN
	var lateral_direction: Vector2 = preferred_direction.orthogonal()
	var search_directions: Array[Vector2] = [
		Vector2.ZERO,
		lateral_direction,
		-lateral_direction,
		-preferred_direction,
		(-preferred_direction + lateral_direction).normalized(),
		(-preferred_direction - lateral_direction).normalized(),
		preferred_direction,
		(preferred_direction + lateral_direction).normalized(),
		(preferred_direction - lateral_direction).normalized()
	]
	var item_radius: float = float(dropped_item.get_push_radius())
	var ring_step: float = item_radius + 10.0

	for ring in range(4):
		var distance_offset: float = ring_step * float(ring)
		for direction in search_directions:
			var candidate_position: Vector2 = desired_position if ring == 0 or direction == Vector2.ZERO else desired_position + direction * distance_offset
			var candidate_result: Dictionary = _evaluate_ground_drop_position(dropped_item, candidate_position, aim_direction)
			if candidate_result.get("valid", false):
				return candidate_result

	return {"valid": false}

func _evaluate_ground_drop_position(
	dropped_item: Node2D,
	candidate_position: Vector2,
	aim_direction: Vector2
) -> Dictionary:
	if push_controller == null:
		return {}
	dropped_item.global_position = candidate_position
	if dropped_item.has_method("_clamp_to_map_bounds"):
		dropped_item._clamp_to_map_bounds()

	if not dropped_item.has_method("get_push_center") or not dropped_item.has_method("get_push_radius"):
		return {
			"valid": true,
			"position": dropped_item.global_position,
			"player_position": player.global_position
		}

	_try_push_overlapping_ground_items(dropped_item, aim_direction)
	if not _is_ground_drop_position_clear_of_obstacles(dropped_item):
		return {}

	var item_center: Vector2 = dropped_item.get_push_center()
	var item_radius: float = float(dropped_item.get_push_radius())
	if not _does_circle_overlap_player_body_at_position(item_center, item_radius + 4.0, player.global_position):
		return {
			"valid": true,
			"position": dropped_item.global_position,
			"player_position": player.global_position
		}

	var body_data: Dictionary = push_controller.get_body_collision_data()
	var body_center: Vector2 = body_data.get("center", player.global_position)
	var body_radius: float = float(body_data.get("radius", 20.0))
	var separation_direction: Vector2 = item_center - body_center
	if separation_direction.length_squared() <= 0.000001:
		separation_direction = aim_direction if aim_direction.length_squared() > 0.000001 else Vector2.DOWN
	separation_direction = separation_direction.normalized()
	var target_distance: float = body_radius + item_radius + 4.0
	var current_distance: float = body_center.distance_to(item_center)
	if dropped_item.has_method("apply_player_push"):
		dropped_item.apply_player_push(
			separation_direction,
			0.0,
			Vector2.ZERO,
			separation_direction * maxf(target_distance - current_distance, 0.0)
		)
		dropped_item._clamp_to_map_bounds()
		if not _is_ground_drop_position_clear_of_obstacles(dropped_item):
			return {}
		item_center = dropped_item.get_push_center()
		if not _does_circle_overlap_player_body_at_position(item_center, item_radius + 4.0, player.global_position):
			return {
				"valid": true,
				"position": dropped_item.global_position,
				"player_position": player.global_position
			}

	return {}

func _is_ground_drop_position_clear_of_obstacles(dropped_item: Node2D) -> bool:
	if push_controller == null:
		return true
	if not dropped_item.has_method("get_push_center") or not dropped_item.has_method("get_push_radius"):
		return true

	var item_center: Vector2 = dropped_item.get_push_center()
	var item_radius: float = float(dropped_item.get_push_radius())

	var query_shape := CircleShape2D.new()
	query_shape.radius = item_radius + 0.1
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = query_shape
	query.transform = Transform2D(0.0, item_center)
	query.collision_mask = 1 | 4 | 8 | 16
	query.exclude = [dropped_item.get_rid(), player.get_rid()]
	var overlaps: Array[Dictionary] = player.get_world_2d().direct_space_state.intersect_shape(query, 12)
	return overlaps.is_empty()

func _try_push_overlapping_ground_items(dropped_item: Node2D, aim_direction: Vector2) -> void:
	if not is_instance_valid(dropped_item):
		return
	if not dropped_item.has_method("get_push_center") or not dropped_item.has_method("get_push_radius"):
		return

	var dropped_center: Vector2 = dropped_item.get_push_center()
	var dropped_radius: float = float(dropped_item.get_push_radius())
	var fallback_direction := -aim_direction.normalized() if aim_direction.length_squared() > 0.001 else Vector2.DOWN

	for _pass in range(3):
		var moved_any := false
		for item in player.get_tree().get_nodes_in_group("pushable_items"):
			if not is_instance_valid(item) or item == dropped_item:
				continue
			if not item.has_method("get_push_center") or not item.has_method("get_push_radius") or not item.has_method("apply_player_push"):
				continue

			var item_center: Vector2 = item.get_push_center()
			var item_radius: float = float(item.get_push_radius())
			var offset: Vector2 = item_center - dropped_center
			var distance: float = offset.length()
			var required_distance: float = dropped_radius + item_radius + 2.0
			if distance >= required_distance:
				continue

			var push_direction: Vector2 = offset.normalized() if distance > 0.001 else fallback_direction
			var separation_motion := push_direction * (required_distance - distance + 4.0)
			var before_position: Vector2 = item_center
			item.apply_player_push(push_direction, 0.0, Vector2.ZERO, separation_motion)
			if item.get_push_center().distance_to(before_position) > 0.1:
				moved_any = true
		if not moved_any:
			return

func _does_circle_overlap_player_body_at_position(
	circle_center: Vector2,
	circle_radius: float,
	player_position: Vector2
) -> bool:
	if push_controller == null:
		return false
	var body_data: Dictionary = push_controller.get_body_collision_data_at_position(player_position)
	if body_data.is_empty():
		return false

	var body_center: Vector2 = body_data.get("center", player_position)
	var body_radius: float = float(body_data.get("radius", 0.0))
	var min_distance: float = body_radius + circle_radius
	return circle_center.distance_squared_to(body_center) <= min_distance * min_distance

