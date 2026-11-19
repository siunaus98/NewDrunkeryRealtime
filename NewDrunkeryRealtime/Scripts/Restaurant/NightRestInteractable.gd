@tool
extends StaticBody2D

const InteractionGeometry = preload("res://Scripts/Core/InteractionGeometry.gd")
const BossTravel = preload("res://Scripts/Restaurant/BossArenaTravel.gd")

signal night_rest_interacted(interaction_type: StringName)

const LevelRefs = preload("res://Scripts/Core/LevelRefs.gd")

@export var interaction_type: StringName = &"merchant"
@export var display_name: String = "夜间休整点"
@export var show_name_label: bool = true
@export var always_visible: bool = false
@export var movable_by_player: bool = false
@export var layout_footprint: Vector2i = Vector2i(1, 1)
@export var sprite_texture: Texture2D
@export var sprite_offset: Vector2 = Vector2(0, -44)
@export var sprite_scale: Vector2 = Vector2(0.42, 0.42)
@export var collision_size: Vector2 = Vector2(88, 104)
@export var collision_offset: Vector2 = Vector2(0, 6)
@export var sort_anchor_offset: Vector2 = Vector2(0, 28)
@export var pickup_distance: float = 170.0
@export var interaction_area_center: Vector2 = Vector2(0, -8)
@export var interaction_area_size: Vector2 = Vector2(138, 132)
@export var interaction_area_columns: int = 3
@export var interaction_area_rows: int = 3
@export var front_z: int = 0
@export var back_z: int = 3
@export var normal_modulate: Color = Color.WHITE
@export var highlight_modulate: Color = Color(1.14, 1.1, 0.98, 1.0)
@export var show_interaction_debug: bool = false
@export var debug_area_fill_color: Color = Color(0.76, 0.64, 0.28, 0.1)
@export var debug_area_outline_color: Color = Color(0.94, 0.84, 0.46, 0.64)
@export var debug_point_fill_color: Color = Color(1.0, 0.96, 0.86, 0.94)
@export var debug_point_outline_color: Color = Color(0.94, 0.84, 0.46, 0.94)
@export var debug_point_radius: float = 5.0

@onready var interaction_sprite: Sprite2D = $InteractionSprite
@onready var name_label: Label = $NameLabel
@onready var sort_anchor: Marker2D = $SortAnchor
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var item_blocker_collision_shape: CollisionShape2D = $ItemBlocker/CollisionShape2D

var player: Node2D
var level_flow_controller: Node
var level_refs: LevelRefs
var is_highlighted: bool = false
var is_carried: bool = false
var initially_enabled: bool = true

func _ready() -> void:
	initially_enabled = visible
	add_to_group("pickup_drop_targets")
	add_to_group("facility_layout_blockers")
	if movable_by_player:
		add_to_group("movable_facilities")
		add_to_group("table_facilities")
	_update_player_reference()
	_resolve_level_flow_controller()
	_refresh_scene_visuals()
	queue_redraw()

func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		_refresh_scene_visuals()
		if show_interaction_debug:
			queue_redraw()
		return

	if not is_instance_valid(player):
		_update_player_reference()
	if level_flow_controller == null:
		_resolve_level_flow_controller()
	_update_presence_state()
	_apply_visual_state()
	_update_name_label()
	if show_interaction_debug:
		queue_redraw()

func is_pickup_drop_focusable(other_player: Node) -> bool:
	if other_player == null:
		return false
	return visible and (movable_by_player or _is_night_rest_active())

func can_take_item(_other_player: Node) -> bool:
	return interaction_type == &"blessing_statue" and (_can_claim_blessing() or _can_claim_skill_upgrade() or BossTravel.current_boss(self) != null)

func can_receive_item(_other_player: Node) -> bool:
	return interaction_type == &"blessing_statue" and BossTravel.current_boss(self) != null

func receive_item_from_player(other_player: Node) -> bool:
	return can_receive_item(other_player) and BossTravel.travel(self, other_player)

func take_item_to_player(_other_player: Node) -> bool:
	if not can_take_item(_other_player):
		return false
	if BossTravel.current_boss(self) != null:
		return BossTravel.travel(self, _other_player)
	_trigger_interaction()
	return true

func get_interaction_button_prompt(_other_player: Node) -> String:
	var prompts: Array[String] = []
	if interaction_type == &"blessing_statue" and BossTravel.current_boss(self) != null:
		prompts.append("J 传送至BOSS战斗区")
	if interaction_type == &"blessing_statue" and (_can_claim_blessing() or _can_claim_skill_upgrade()):
		prompts.append("J 祈福")
	if movable_by_player:
		prompts.append("K 搬起")
	elif _is_night_rest_active():
		prompts.append("K 交互")
	return " / ".join(prompts)

func interact_with_player(_other_player: Node) -> bool:
	if not _is_night_rest_active():
		return false
	if interaction_type == &"blessing_statue" and movable_by_player:
		return false
	_trigger_interaction()
	return true

func can_be_moved_by_player(_other_player: Node) -> bool:
	return movable_by_player and visible

func set_facility_carried(active: bool) -> void:
	is_carried = active
	_update_presence_state()

func get_layout_footprint() -> Vector2i:
	return layout_footprint

func get_facility_move_cost(_target_position: Vector2) -> int:
	return 0

func can_afford_facility_move(_target_position: Vector2) -> bool:
	return true

func spend_facility_move_cost(_target_position: Vector2) -> bool:
	return true

func get_facility_preview_data() -> Dictionary:
	return {
		"body_size": collision_size,
		"base_color": Color(0.72, 0.69, 0.62, 1.0),
		"accent_color": Color(1.0, 0.84, 0.42, 1.0),
		"outline_color": Color(0.12, 0.09, 0.06, 1.0),
		"facility_type": interaction_type
	}

func get_pickup_drop_positions() -> Array[Vector2]:
	return InteractionGeometry.grid_points(global_transform, interaction_area_center, interaction_area_size, interaction_area_columns, interaction_area_rows)

func get_interaction_rect_global() -> Rect2:
	return InteractionGeometry.world_rect(global_transform, interaction_area_center, interaction_area_size)

func get_pickup_drop_radius() -> float:
	return pickup_distance

func set_pickup_drop_highlight(active: bool) -> void:
	is_highlighted = active
	_apply_visual_state()
	queue_redraw()

func reset_state() -> void:
	is_highlighted = false
	is_carried = false
	_apply_visual_state()
	queue_redraw()

func _trigger_interaction() -> void:
	night_rest_interacted.emit(interaction_type)
	if level_flow_controller != null and level_flow_controller.has_method("handle_night_rest_interaction"):
		level_flow_controller.handle_night_rest_interaction(interaction_type)

func _can_claim_skill_upgrade() -> bool:
	return _is_night_rest_active() and level_flow_controller != null and level_flow_controller.progression_state != null and level_flow_controller.progression_state.has_pending_skill_upgrade()

func _can_claim_blessing() -> bool:
	return (
		_is_night_rest_active()
		and level_flow_controller != null
		and level_flow_controller.has_method("get_blessing_points")
		and int(level_flow_controller.get_blessing_points()) > 0
	)

func _resolve_level_flow_controller() -> void:
	if Engine.is_editor_hint():
		return
	level_refs = LevelRefs.find_from(self)
	if level_refs != null:
		level_flow_controller = level_refs.get_level_flow_controller()

func _update_player_reference() -> void:
	player = get_tree().get_first_node_in_group("player") as Node2D

func _is_night_rest_active() -> bool:
	if level_flow_controller == null or not level_flow_controller.has_method("is_night_rest_active"):
		return false
	return bool(level_flow_controller.is_night_rest_active())

func _should_be_visible_for_current_state() -> bool:
	if not initially_enabled:
		return false
	if is_carried:
		return false
	if always_visible:
		return true
	if level_flow_controller == null or not level_flow_controller.has_method("should_show_night_rest_objects"):
		return Engine.is_editor_hint()
	return bool(level_flow_controller.should_show_night_rest_objects())

func _refresh_scene_visuals() -> void:
	if interaction_sprite != null:
		interaction_sprite.texture = sprite_texture
		interaction_sprite.position = sprite_offset
		interaction_sprite.scale = sprite_scale
	if name_label != null:
		name_label.visible = show_name_label
		_update_name_label()
	if sort_anchor != null:
		sort_anchor.position = sort_anchor_offset
	if collision_shape != null:
		var shape := collision_shape.shape as RectangleShape2D
		if shape != null:
			shape.size = collision_size
		collision_shape.position = collision_offset
	if item_blocker_collision_shape != null:
		var blocker_shape := item_blocker_collision_shape.shape as RectangleShape2D
		if blocker_shape != null:
			blocker_shape.size = collision_size
		item_blocker_collision_shape.position = collision_offset
	_update_presence_state()
	_apply_visual_state()

func _update_name_label() -> void:
	if name_label == null:
		return
	name_label.visible = show_name_label
	if not show_name_label:
		return
	name_label.text = display_name
	if interaction_type == &"blessing_statue" and level_flow_controller != null and level_flow_controller.has_method("get_blessing_points"):
		name_label.text = display_name + (" · 待选技能升级" if _can_claim_skill_upgrade() else " · 祝福点 %d" % int(level_flow_controller.get_blessing_points()))

func _update_presence_state() -> void:
	var should_show: bool = _should_be_visible_for_current_state()
	visible = should_show
	if collision_shape != null:
		collision_shape.disabled = not should_show
	if item_blocker_collision_shape != null:
		item_blocker_collision_shape.disabled = not should_show

func _apply_visual_state() -> void:
	var in_front: bool = _is_player_in_front()
	if interaction_sprite != null:
		interaction_sprite.modulate = highlight_modulate if is_highlighted else normal_modulate
		interaction_sprite.z_index = front_z if in_front else back_z
	if name_label != null:
		name_label.modulate = Color(1.0, 0.95, 0.84, 1.0) if is_highlighted else Color(0.94, 0.92, 0.88, 0.92)
		name_label.z_index = front_z + 1 if in_front else back_z + 1

func _is_player_in_front() -> bool:
	if player == null:
		return true
	var player_sort_origin: Vector2 = player.get_sort_origin() if player.has_method("get_sort_origin") else player.global_position
	return player_sort_origin.y > sort_anchor.global_position.y

func _draw() -> void:
	if not show_interaction_debug:
		return

	var area_rect := Rect2(interaction_area_center - interaction_area_size * 0.5, interaction_area_size)
	draw_rect(area_rect, debug_area_fill_color, true)
	draw_rect(area_rect, debug_area_outline_color, false, 2.0)

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


