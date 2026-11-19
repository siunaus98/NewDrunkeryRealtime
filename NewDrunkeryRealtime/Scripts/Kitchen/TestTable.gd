@tool
extends StaticBody2D

const InteractionGeometry = preload("res://Scripts/Core/InteractionGeometry.gd")

const TestItemDefs = preload("res://Scripts/Kitchen/TestItemDefs.gd")
const CarryItemRules = preload("res://Scripts/Kitchen/CarryItemRules.gd")
const ProcessStateMark = preload("res://Scripts/Kitchen/ProcessStateMark.gd")

@export var front_lower_z: int = 0
@export var front_top_z: int = 0
@export var front_item_z: int = 0
@export var back_lower_z: int = 2
@export var back_top_z: int = 3
@export var back_item_z: int = 4
@export var pickup_distance: float = 190.0
@export var interaction_area_center: Vector2 = Vector2(0, -120)
@export var interaction_area_size: Vector2 = Vector2(620, 288)
@export var interaction_area_columns: int = 5
@export var interaction_area_rows: int = 3
@export var normal_modulate: Color = Color.WHITE
@export var highlight_modulate: Color = Color(1.22, 1.18, 1.0, 1.0)
@export var meat_normal_scale: Vector2 = Vector2(2.666667, 2.666667)
@export var meat_highlight_scale: Vector2 = Vector2(2.666667, 2.666667)
@export var show_interaction_debug: bool = false
@export var debug_area_fill_color: Color = Color(0.24, 0.92, 0.76, 0.12)
@export var debug_area_outline_color: Color = Color(0.42, 1.0, 0.86, 0.55)
@export var debug_point_fill_color: Color = Color(0.9, 1.0, 0.96, 0.95)
@export var debug_point_outline_color: Color = Color(0.24, 0.92, 0.76, 0.95)
@export var debug_point_radius: float = 7.0

@onready var lower_sprite: Sprite2D = $LowerSprite
@onready var top_sprite: Sprite2D = $TopSprite
@onready var item_layer: Node2D = $ItemLayer
@onready var item_anchor: Marker2D = $ItemLayer/ItemAnchor
@onready var meat_sprite: Sprite2D = $ItemLayer/MeatSprite
@onready var sort_anchor: Marker2D = $SortAnchor
var process_state_mark: Node2D

var player: Node2D
var has_item: bool = false
var item_id: StringName = TestItemDefs.TEST_ITEM_ID
var item_texture: Texture2D
var item_process_state: StringName = TestItemDefs.PROCESS_STATE_NONE
var item_recipe_signature: String = ""
var item_payload: Dictionary = {}
var is_highlighted: bool = false

func _ready() -> void:
	add_to_group("pickup_drop_targets")
	add_to_group("movable_facilities")
	add_to_group("table_facilities")
	add_to_group("kitchen_resettable")
	_update_player_reference()
	process_state_mark = ProcessStateMark.new()
	process_state_mark.name = "ProcessStateMark"
	item_layer.add_child(process_state_mark)
	process_state_mark.position = meat_sprite.position
	process_state_mark.z_index = meat_sprite.z_index + 1
	_apply_front_sorting()
	_update_item_visual()
	queue_redraw()

func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		if show_interaction_debug:
			queue_redraw()
		return

	if not is_instance_valid(player):
		_update_player_reference()
		if not is_instance_valid(player):
			return

	var player_sort_origin: Vector2 = _get_player_sort_origin()
	if player_sort_origin.y > sort_anchor.global_position.y:
		_apply_front_sorting()
	else:
		_apply_back_sorting()

	if show_interaction_debug:
		queue_redraw()

func _update_player_reference() -> void:
	player = get_tree().get_first_node_in_group("player") as Node2D

func _get_player_sort_origin() -> Vector2:
	if player.has_method("get_sort_origin"):
		return player.get_sort_origin()
	return player.global_position

func _apply_front_sorting() -> void:
	lower_sprite.z_index = front_lower_z
	top_sprite.z_index = front_top_z
	item_layer.z_index = front_item_z

func _apply_back_sorting() -> void:
	lower_sprite.z_index = back_lower_z
	top_sprite.z_index = back_top_z
	item_layer.z_index = back_item_z

func can_take_item(other_player: Node) -> bool:
	return has_item and other_player.has_method("can_pick_up_item") and other_player.can_pick_up_item(item_id, item_process_state, item_payload)

func is_pickup_drop_focusable(_other_player: Node) -> bool:
	return true

func can_receive_item(other_player: Node) -> bool:
	if has_item:
		return CarryItemRules.can_put_into_plate(other_player, item_id, item_payload)
	return (
		not has_item
		and other_player.has_method("is_holding_item")
		and other_player.is_holding_item()
		and other_player.has_method("get_held_item_id")
		and TestItemDefs.is_supported_item(other_player.get_held_item_id())
	)

func take_item_to_player(other_player: Node) -> bool:
	if not can_take_item(other_player):
		return false
	if not other_player.has_method("pick_up_item"):
		return false

	var leave_box: bool = CarryItemRules.take_leaves_box(other_player, item_id, item_payload)
	var was_picked_up: Variant = other_player.pick_up_item(item_id, item_texture, item_process_state, item_recipe_signature, item_payload)
	if was_picked_up is bool and was_picked_up:
		if leave_box:
			item_payload["servings"] = int(item_payload.servings) - 1
			_update_item_visual()
			return true
		has_item = false
		item_id = TestItemDefs.TEST_ITEM_ID
		item_texture = null
		item_process_state = TestItemDefs.PROCESS_STATE_NONE
		item_recipe_signature = ""
		_update_item_visual()
		return true
	return false

func receive_item_from_player(other_player: Node) -> bool:
	if not can_receive_item(other_player):
		return false
	if has_item:
		if not CarryItemRules.put_into_plate(other_player, item_id, item_payload):
			return false
		_update_item_visual()
		return true

	item_payload = CarryItemRules.payload_from(other_player).duplicate(true)
	item_id = other_player.get_held_item_id()
	if other_player.has_method("get_held_item_texture"):
		item_texture = other_player.get_held_item_texture()
	if item_texture == null:
		item_texture = TestItemDefs.get_item_texture(item_id)
	if other_player.has_method("get_held_item_process_state"):
		item_process_state = TestItemDefs.normalize_process_state(other_player.get_held_item_process_state())
	else:
		item_process_state = TestItemDefs.PROCESS_STATE_NONE
	item_recipe_signature = String(other_player.get_held_item_recipe_signature()) if other_player.has_method("get_held_item_recipe_signature") else ""
	if other_player.has_method("clear_held_item"):
		other_player.clear_held_item()

	has_item = true
	_update_item_visual()
	return true

func get_interaction_button_prompt(other_player: Node) -> String:
	var prompts: Array[String] = []
	if other_player != null and other_player.has_method("is_holding_item") and other_player.is_holding_item():
		if can_receive_item(other_player):
			prompts.append("J 放入盘中" if has_item else "J 放下")
		elif can_take_item(other_player):
			prompts.append("J 装盘")
		return " / ".join(prompts)
	if can_take_item(other_player):
		prompts.append("J 拿起")
	if can_take_plate_portion(other_player):
		prompts.append("K 取出最后一份")
	if can_be_moved_by_player(other_player):
		prompts.append("K 搬起")
	return " / ".join(prompts)

func reset_state() -> void:
	item_payload = {}
	has_item = false
	item_id = TestItemDefs.TEST_ITEM_ID
	item_texture = null
	item_process_state = TestItemDefs.PROCESS_STATE_NONE
	item_recipe_signature = ""
	is_highlighted = false
	set_pickup_drop_highlight(false)
	_update_item_visual()

func get_pickup_drop_positions() -> Array[Vector2]:
	return InteractionGeometry.grid_points(global_transform, interaction_area_center, interaction_area_size, interaction_area_columns, interaction_area_rows)

func get_interaction_rect_global() -> Rect2:
	return InteractionGeometry.world_rect(global_transform, interaction_area_center, interaction_area_size)

func get_pickup_drop_radius() -> float:
	return pickup_distance

func set_pickup_drop_highlight(active: bool) -> void:
	is_highlighted = active
	lower_sprite.modulate = highlight_modulate if active else normal_modulate
	top_sprite.modulate = highlight_modulate if active else normal_modulate
	_update_item_visual()

func can_be_moved_by_player(_other_player: Node) -> bool:
	return not has_item

func can_take_plate_portion(other_player: Node) -> bool:
	return has_item and CarryItemRules.can_take_last_portion(other_player, item_id, item_payload)

func interact_with_player(other_player: Node) -> bool:
	if not has_item or not CarryItemRules.take_last_portion(other_player, item_id, item_payload):
		return false
	_update_item_visual()
	return true

func get_layout_footprint() -> Vector2i:
	return Vector2i(1, 1)

func _update_item_visual() -> void:
	meat_sprite.visible = has_item
	meat_sprite.texture = TestItemDefs.get_world_item_texture(item_id, item_payload, item_texture)
	meat_sprite.scale = meat_highlight_scale if is_highlighted else meat_normal_scale
	var state_modulate: Color = TestItemDefs.get_item_modulate(item_process_state, item_id)
	meat_sprite.modulate = state_modulate * (highlight_modulate if is_highlighted else normal_modulate)
	if is_instance_valid(process_state_mark):
		process_state_mark.scale = meat_sprite.scale
		process_state_mark.call("set_item_data", item_id, item_process_state, item_payload, has_item)

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
