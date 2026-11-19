@tool
extends StaticBody2D

const AudioCue = preload("res://Scripts/Audio/AudioCue.gd")

const InteractionGeometry = preload("res://Scripts/Core/InteractionGeometry.gd")

const TestItemDefs = preload("res://Scripts/Kitchen/TestItemDefs.gd")
const CarryItemRules = preload("res://Scripts/Kitchen/CarryItemRules.gd")
const ProcessStateMark = preload("res://Scripts/Kitchen/ProcessStateMark.gd")
const LevelRefs = preload("res://Scripts/Core/LevelRefs.gd")

@export var front_lower_z: int = 0
@export var front_top_z: int = 0
@export var front_item_z: int = 0
@export var back_lower_z: int = 2
@export var back_top_z: int = 3
@export var back_item_z: int = 4
@export var pickup_distance: float = 210.0
@export var interaction_area_center: Vector2 = Vector2(0, -100)
@export var interaction_area_size: Vector2 = Vector2(900, 400)
@export var interaction_area_columns: int = 13
@export var interaction_area_rows: int = 4
@export var normal_modulate: Color = Color.WHITE
@export var highlight_modulate: Color = Color(1.22, 1.18, 1.0, 1.0)
@export var item_normal_scale: Vector2 = Vector2(0.56, 0.56)
@export var item_highlight_scale: Vector2 = Vector2(0.56, 0.56)
@export var max_items: int = 6
@export var item_span_width: float = 760.0
@export var item_row_y: float = -28.0
@export var show_interaction_debug: bool = false
@export var debug_area_fill_color: Color = Color(0.5, 0.86, 1.0, 0.12)
@export var debug_area_outline_color: Color = Color(0.58, 0.92, 1.0, 0.62)
@export var debug_point_fill_color: Color = Color(0.9, 0.98, 1.0, 0.95)
@export var debug_point_outline_color: Color = Color(0.58, 0.92, 1.0, 0.95)
@export var debug_point_radius: float = 6.0

@onready var lower_sprite: Sprite2D = $LowerSprite
@onready var top_sprite: Sprite2D = $TopSprite
@onready var item_layer: Node2D = $ItemLayer
@onready var item_anchor: Marker2D = $ItemLayer/ItemAnchor
@onready var item_sprites: Node2D = $ItemLayer/ItemSprites
@onready var sort_anchor: Marker2D = $SortAnchor

var player: Node2D
var is_highlighted: bool = false
var stored_items: Array[Dictionary] = []
var level_refs: LevelRefs
var level_flow_controller: Node

func _ready() -> void:
	add_to_group("pickup_drop_targets")
	add_to_group("assembly_stations")
	_update_player_reference()
	_resolve_level_flow_controller()
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
	if level_flow_controller == null:
		_resolve_level_flow_controller()

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
	if preload("res://Scripts/Facilities/FacilityWorkPause.gd").is_paused(self):
		return false
	if stored_items.is_empty():
		return false
	var nearest_item: Dictionary = _get_nearest_item_for_player(other_player)
	var item_id: StringName = StringName(nearest_item.get("item_id", &""))
	if CarryItemRules.needs_plate(item_id) and not bool(Dictionary(nearest_item.get("payload", {})).get("uses_plate", false)):
		if not CarryItemRules.is_collecting(other_player):
			return false
	return other_player.has_method("can_pick_up_item") and other_player.can_pick_up_item(nearest_item.get("item_id", &""), nearest_item.get("process_state", TestItemDefs.PROCESS_STATE_NONE), nearest_item.get("payload", {}))

func is_pickup_drop_focusable(_other_player: Node) -> bool:
	return true

func can_receive_item(other_player: Node) -> bool:
	if preload("res://Scripts/Facilities/FacilityWorkPause.gd").is_paused(self):
		return false
	if not other_player.has_method("is_holding_item") or not other_player.is_holding_item():
		return false
	if not other_player.has_method("get_held_item_id"):
		return false

	var held_item_id: StringName = other_player.get_held_item_id()
	if held_item_id == TestItemDefs.PLATE_ID:
		return false
	if held_item_id == TestItemDefs.SEASONING_BOX_ID:
		return int(CarryItemRules.payload_from(other_player).get("servings", 0)) > 0 and stored_items.size() < max_items and _has_only_assembly_components()
	if CarryItemRules.is_plate(held_item_id):
		return false
	if not TestItemDefs.is_supported_item(held_item_id):
		return false
	if held_item_id == TestItemDefs.TRASH_ID:
		return false
	if TestItemDefs.is_dish(held_item_id) and not TestItemDefs.is_assembly_component(held_item_id):
		return stored_items.is_empty()

	return stored_items.size() < max_items and _has_only_assembly_components()

func take_item_to_player(other_player: Node) -> bool:
	if not can_take_item(other_player):
		return false
	if not other_player.has_method("pick_up_item"):
		return false

	var nearest_item: Dictionary = _get_nearest_item_for_player(other_player)
	if nearest_item.is_empty():
		return false

	var was_picked_up: Variant = other_player.pick_up_item(
		nearest_item.get("item_id", &""),
		nearest_item.get("texture", null),
		nearest_item.get("process_state", TestItemDefs.PROCESS_STATE_NONE),
		String(nearest_item.get("recipe_signature", "")),
		nearest_item.get("payload", {})
	)
	if was_picked_up is bool and was_picked_up:
		var item_index: int = int(nearest_item.get("index", -1))
		if item_index >= 0 and item_index < stored_items.size():
			stored_items.remove_at(item_index)
			_update_item_visual()
		return true
	return false

func receive_item_from_player(other_player: Node) -> bool:
	if not can_receive_item(other_player):
		if CarryItemRules.is_collecting(other_player) and other_player.has_method("show_hint"):
			other_player.show_hint("组合台空间不足或盘内没有食材")
		return false
	var payload: Dictionary = CarryItemRules.payload_from(other_player)
	if other_player.get_held_item_id() == TestItemDefs.SEASONING_BOX_ID:
		stored_items.append(CarryItemRules.portion(TestItemDefs.SEASONING_BOX_ID, &"", "", payload))
		payload["servings"] = int(payload.servings) - 1
		other_player.clear_held_item()
		if int(payload.servings) > 0:
			other_player.pick_up_item(TestItemDefs.SEASONING_BOX_ID, TestItemDefs.get_item_texture(TestItemDefs.SEASONING_BOX_ID), &"", "", payload)
		_update_item_visual()
		return true

	var held_item_id: StringName = other_player.get_held_item_id()
	var item_texture: Texture2D = null
	if other_player.has_method("get_held_item_texture"):
		item_texture = other_player.get_held_item_texture()
	if item_texture == null:
		item_texture = TestItemDefs.get_item_texture(held_item_id)

	var item_process_state: StringName = TestItemDefs.PROCESS_STATE_NONE
	if other_player.has_method("get_held_item_process_state"):
		item_process_state = TestItemDefs.normalize_process_state(other_player.get_held_item_process_state())

	stored_items.append({
		"item_id": held_item_id,
		"texture": item_texture,
		"process_state": item_process_state,
		"payload": payload.duplicate(true),
		"recipe_signature": String(other_player.get_held_item_recipe_signature()) if other_player.has_method("get_held_item_recipe_signature") else ""
	})

	if other_player.has_method("clear_held_item"):
		other_player.clear_held_item()

	_update_item_visual()
	return true

func interact_with_player(other_player: Node) -> bool:
	if preload("res://Scripts/Facilities/FacilityWorkPause.gd").is_paused(self):
		return false
	if _is_night_rest_active():
		if level_flow_controller != null and level_flow_controller.has_method("handle_night_rest_interaction"):
			level_flow_controller.handle_night_rest_interaction(&"task_book")
			return true
		return false
	if CarryItemRules.is_collecting(other_player) and not Array(CarryItemRules.payload_from(other_player).get("items", [])).is_empty():
		return _unload_plate(other_player)
	if other_player.has_method("is_holding_item") and other_player.is_holding_item() and not CarryItemRules.is_collecting(other_player):
		return false
	if stored_items.is_empty() or not _has_only_assembly_components():
		return false

	var input_items := stored_items.duplicate(true)
	var recipe_result: Dictionary = _find_matching_order_recipe()
	if recipe_result.is_empty():
		recipe_result = TestItemDefs.find_matching_recipe(stored_items, false)
	if recipe_result.is_empty():
		recipe_result = TestItemDefs.find_matching_recipe_with_alternate_completion(stored_items)
	if recipe_result.is_empty():
		var refund_item := _get_blessing_assembly_refund(other_player, false, &"", input_items)
		stored_items.clear()
		stored_items.append(TestItemDefs.get_trash_item_data())
		AudioCue.at(self, &"failure", -7.0)
		if not refund_item.is_empty() and stored_items.size() < max_items:
			stored_items.append(refund_item)
		_update_item_visual()
		return true

	stored_items.clear()
	stored_items.append({
		"item_id": recipe_result.get("output_item_id", &""),
		"texture": recipe_result.get("output_texture", null),
		"process_state": recipe_result.get("output_process_state", TestItemDefs.PROCESS_STATE_NONE),
		"recipe_signature": String(recipe_result.get("recipe_signature", ""))
	})
	var refund_item := _get_blessing_assembly_refund(other_player, true, StringName(recipe_result.get("output_item_id", &"")), input_items)
	preload("res://Scripts/Player/UltimateEnergyRules.gd").award(other_player, &"assemble")
	AudioCue.at(self, &"complete", -3.0)
	if not refund_item.is_empty() and stored_items.size() < max_items:
		stored_items.append(refund_item)
	_update_item_visual()
	return true

func _unload_plate(other_player: Node) -> bool:
	var payload: Dictionary = CarryItemRules.payload_from(other_player)
	var contents: Array = payload.get("items", [])
	if contents.is_empty() or stored_items.size() + contents.size() > max_items or not _has_only_assembly_components():
		return false
	for entry: Dictionary in contents:
		if not TestItemDefs.is_assembly_component(StringName(entry.get("item_id", &""))):
			return false
	for entry: Dictionary in contents:
		stored_items.append(entry.duplicate(true))
	payload["items"] = []
	other_player.set_held_item_payload(payload)
	_update_item_visual()
	return true

func _get_blessing_assembly_refund(other_player: Node, success: bool, output_id: StringName, input_items: Array) -> Dictionary:
	if other_player == null or not other_player.has_method("get_blessing_controller"):
		return {}
	var blessing_runtime: RefCounted = other_player.get_blessing_controller()
	return blessing_runtime.on_assembly_result(success, output_id, input_items) if blessing_runtime != null else {}

func get_interaction_rect_global() -> Rect2:
	return InteractionGeometry.world_rect(global_transform, interaction_area_center, interaction_area_size)

func get_pickup_drop_positions() -> Array[Vector2]:
	return InteractionGeometry.grid_points(global_transform, interaction_area_center, interaction_area_size, interaction_area_columns, interaction_area_rows)

func get_pickup_drop_radius() -> float:
	return pickup_distance

func set_pickup_drop_highlight(active: bool) -> void:
	is_highlighted = active
	lower_sprite.modulate = highlight_modulate if active else normal_modulate
	top_sprite.modulate = highlight_modulate if active else normal_modulate
	_update_item_visual()

func can_be_moved_by_player(_other_player: Node) -> bool:
	return false

func destroy_surface_food() -> void:
	var plates: Array[Dictionary] = []
	for item: Dictionary in stored_items:
		if bool(item.get("payload", {}).get("uses_plate", false)):
			plates.append({"item_id": TestItemDefs.DIRTY_PLATE_ID, "payload": {}, "process_state": &"", "recipe_signature": ""})
	stored_items.assign(plates)
	_update_item_visual()

func should_prioritize_hold_interaction(_other_player: Node) -> bool:
	return true

func get_interaction_button_prompt(other_player: Node) -> String:
	if preload("res://Scripts/Facilities/FacilityWorkPause.gd").is_paused(self):
		return ""
	if _is_night_rest_active():
		return "K TASK"
	if other_player != null and other_player.has_method("is_holding_item") and other_player.is_holding_item():
		if CarryItemRules.is_collecting(other_player):
			if not Array(CarryItemRules.payload_from(other_player).get("items", [])).is_empty():
				return "K 放入盘内全部食材"
			return "J 取食材 / K 组合" if _has_only_assembly_components() and not stored_items.is_empty() else ("J 装盘" if can_take_item(other_player) else "")
		if can_receive_item(other_player):
			return "J PLACE"
		return ""
	if can_take_item(other_player):
		return "J TAKE"
	if not stored_items.is_empty():
		return "K 组合 / J 取食材" if _has_only_assembly_components() else "需要空净盘取走料理"
	return ""

func get_layout_footprint() -> Vector2i:
	return Vector2i(3, 2)

func _resolve_level_flow_controller() -> void:
	if Engine.is_editor_hint():
		return
	level_refs = LevelRefs.find_from(self)
	if level_refs != null:
		level_flow_controller = level_refs.get_level_flow_controller()

func _is_night_rest_active() -> bool:
	if level_flow_controller == null or not level_flow_controller.has_method("is_night_rest_active"):
		return false
	return bool(level_flow_controller.is_night_rest_active())

func _get_nearest_item_for_player(other_player: Node) -> Dictionary:
	if stored_items.is_empty() or other_player == null:
		return {}

	var origin: Vector2 = global_position
	if other_player.has_method("get_interaction_origin_world"):
		origin = other_player.get_interaction_origin_world()
	elif other_player is Node2D:
		origin = other_player.global_position

	var aim: Vector2 = Vector2.RIGHT
	if other_player.has_method("get_aim_direction_world"):
		aim = other_player.get_aim_direction_world()
	if aim.length_squared() <= 0.0001:
		aim = Vector2.RIGHT
	aim = aim.normalized()

	var best_item: Dictionary = {}
	var best_angle: float = INF
	var best_distance: float = INF

	for i in range(stored_items.size()):
		var item_data: Dictionary = stored_items[i]
		var item_position: Vector2 = _get_item_local_position(i, stored_items.size())
		var item_global_position: Vector2 = item_layer.to_global(item_position)
		var to_item: Vector2 = item_global_position - origin
		var distance: float = to_item.length()
		if distance <= 0.001:
			item_data["index"] = i
			return item_data

		var angle: float = abs(aim.angle_to(to_item.normalized()))
		if angle < best_angle - 0.001 or (is_equal_approx(angle, best_angle) and distance < best_distance):
			best_angle = angle
			best_distance = distance
			best_item = item_data.duplicate()
			best_item["index"] = i

	return best_item

func _get_item_local_position(item_index: int, item_count: int) -> Vector2:
	# Use the same layout for drawing and targeted pickup. Six full-size portions
	# occupy two rows rather than being shrunk into a narrow horizontal strip.
	var columns: int = mini(item_count, 3)
	var rows: int = ceili(float(item_count) / 3.0)
	var row: int = item_index / 3
	var columns_in_row: int = mini(item_count - row * 3, columns)
	var step_x: float = item_span_width / 3.0
	var step_y: float = 80.0 / maxf(absf(item_layer.global_scale.y), 0.001)
	return Vector2((float(item_index % 3) - float(columns_in_row - 1) * 0.5) * step_x,
		item_row_y + (float(row) - float(rows - 1) * 0.5) * step_y)

func _has_only_assembly_components() -> bool:
	for item_data in stored_items:
		if not TestItemDefs.is_assembly_component(item_data.get("item_id", &"")):
			return false
	return true

func _find_matching_order_recipe() -> Dictionary:
	var order_manager: Node = level_refs.get_order_manager() if level_refs != null else null
	if order_manager == null or not order_manager.has_method("get_active_orders"):
		return {}
	for order_data in order_manager.get_active_orders():
		if not (order_data is Dictionary):
			continue
		var dish_item_id := StringName(order_data.get("dish_item_id", &""))
		if TestItemDefs.is_barrel_drink(dish_item_id):
			continue
		var recipe_items: Array = order_data.get("recipe_items", [])
		if not TestItemDefs.matches_recipe(stored_items, recipe_items):
			continue
		return {
			"output_item_id": dish_item_id,
			"output_process_state": TestItemDefs.PROCESS_STATE_NONE,
			"output_texture": TestItemDefs.get_item_texture(dish_item_id),
			"recipe_signature": TestItemDefs.get_recipe_signature(stored_items)
		}
	return {}

func _update_item_visual() -> void:
	for child in item_sprites.get_children():
		child.queue_free()

	var count: int = stored_items.size()
	for i in range(count):
		var item_data: Dictionary = stored_items[i]
		var sprite := Sprite2D.new()
		sprite.texture = TestItemDefs.get_world_item_texture(StringName(item_data.get("item_id", &"")), item_data.get("payload", {}), item_data.get("texture", null))
		sprite.position = _get_item_local_position(i, count)
		sprite.scale = _get_item_local_scale(item_highlight_scale if is_highlighted else item_normal_scale)
		var state_modulate: Color = TestItemDefs.get_item_modulate(item_data.get("process_state", TestItemDefs.PROCESS_STATE_NONE), item_data.get("item_id", &""))
		sprite.modulate = state_modulate * (highlight_modulate if is_highlighted else normal_modulate)
		item_sprites.add_child(sprite)
		var process_mark: Node2D = ProcessStateMark.new()
		process_mark.name = "ProcessStateMark"
		process_mark.z_index = 1
		sprite.add_child(process_mark)
		process_mark.call("set_process_state", item_data.get("process_state", TestItemDefs.PROCESS_STATE_NONE), true)

func _get_item_local_scale(target_world_scale: Vector2) -> Vector2:
	var inherited_scale: Vector2 = item_sprites.global_scale
	var x_scale: float = inherited_scale.x
	var y_scale: float = inherited_scale.y
	if absf(x_scale) <= 0.0001:
		x_scale = 1.0
	if absf(y_scale) <= 0.0001:
		y_scale = 1.0
	return Vector2(target_world_scale.x / x_scale, target_world_scale.y / y_scale)

func reset_state() -> void:
	stored_items.clear()
	is_highlighted = false
	set_pickup_drop_highlight(false)
	_update_item_visual()

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
