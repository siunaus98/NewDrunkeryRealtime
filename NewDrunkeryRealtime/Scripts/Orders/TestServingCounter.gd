@tool
extends StaticBody2D

const CarryItemRules = preload("res://Scripts/Kitchen/CarryItemRules.gd")

const TestItemDefs = preload("res://Scripts/Kitchen/TestItemDefs.gd")
const LevelRefs = preload("res://Scripts/Core/LevelRefs.gd")

const SCREEN_EDGE_PROMPT_GROUP := "serving_counter_screen_edge_prompts"
const SPECIAL_GUEST_PROMPT_COLOR := Color(1.0, 0.25, 0.28, 1.0)

@export var front_lower_z: int = 0
@export var front_top_z: int = 0
@export var back_lower_z: int = 2
@export var back_top_z: int = 3
@export var pickup_distance: float = 220.0
@export var slot_count: int = 5
@export var slot_number_offset: int = 0
@export var slot_span_width: float = 845.0
@export var slot_size: Vector2 = Vector2(150, 190)
@export var slot_center_y: float = 9.0
@export var layout_footprint_cells: Vector2i = Vector2i(0, 0)
@export var movable_by_player: bool = false
@export var highlight_fill_color: Color = Color(1.0, 0.9, 0.4, 0.28)
@export var highlight_outline_color: Color = Color(1.0, 0.94, 0.72, 0.95)
@export var marker_y: float = 68.0
@export var marker_radius: float = 48.0
@export var marker_fill_color: Color = Color(0.88, 0.68, 0.14, 0.98)
@export var marker_outline_color: Color = Color(1.0, 0.88, 0.42, 1.0)
@export var marker_text_color: Color = Color(0.25, 0.16, 0.02, 1.0)
@export var marker_font_size: int = 46
@export var order_prompt_offset: Vector2 = Vector2(0.0, -172.0)
@export var order_prompt_icon_size: Vector2 = Vector2(112.0, 112.0)
@export var order_prompt_bar_size: Vector2 = Vector2(164.0, 22.0)
@export var order_prompt_ready_color: Color = Color(1.0, 0.78, 0.22, 1.0)
@export var order_prompt_active_color: Color = Color(0.36, 0.92, 0.55, 1.0)
@export var screen_edge_prompt_margin: float = 96.0
@export var screen_edge_prompt_size: Vector2 = Vector2(188.0, 82.0)

@onready var lower_sprite: Sprite2D = $LowerSprite
@onready var top_sprite: Sprite2D = $TopSprite
@onready var sort_anchor: Marker2D = $SortAnchor
@onready var highlight_layer: Node2D = $HighlightLayer
@onready var marker_layer: Node2D = $MarkerLayer

var player: Node2D
var is_highlighted: bool = false
var focused_slot_index: int = -1
var slot_polygons: Array[Polygon2D] = []
var slot_outlines: Array[Line2D] = []
var order_target_slot_index: int = -1
var delivered_slot_index: int = -1
var slot_marker_positions: Array[Vector2] = []
var level_refs: LevelRefs
var prompt_layer: Node2D
var screen_edge_prompt_layer: CanvasLayer
var waiting_order_by_slot: Dictionary = {}
var active_order_by_slot: Dictionary = {}
var prompt_fill_by_slot: Dictionary = {}
var screen_edge_prompt_by_slot: Dictionary = {}

func _ready() -> void:
	add_to_group("serving_counters")
	add_to_group("pickup_drop_targets")
	add_to_group("facility_layout_blockers")
	if movable_by_player:
		add_to_group("movable_facilities")
	_update_player_reference()
	_rebuild_slot_marker_positions()
	_ensure_highlight_nodes()
	_ensure_prompt_layer()
	_ensure_screen_edge_prompt_layer()
	_apply_readable_overlay_scale()
	_connect_order_manager_signals()
	_apply_front_sorting()
	_update_marker_layer()
	_update_prompt_layer()
	queue_redraw()

func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		_rebuild_slot_marker_positions()
		_update_marker_layer()
		queue_redraw()
		return

	if not is_instance_valid(player):
		_update_player_reference()
		if not is_instance_valid(player):
			return
	_connect_order_manager_signals()

	var player_sort_origin: Vector2 = _get_player_sort_origin()
	if player_sort_origin.y > sort_anchor.global_position.y:
		_apply_front_sorting()
	else:
		_apply_back_sorting()

	_update_prompt_positions()
	_update_screen_edge_prompt_positions()
	queue_redraw()

func _update_player_reference() -> void:
	player = get_tree().get_first_node_in_group("player") as Node2D

func _get_player_sort_origin() -> Vector2:
	if player != null and player.has_method("get_sort_origin"):
		return player.get_sort_origin()
	return player.global_position if player != null else global_position

func _apply_front_sorting() -> void:
	lower_sprite.z_index = front_lower_z
	top_sprite.z_index = front_top_z
	highlight_layer.z_index = front_top_z + 1
	marker_layer.z_index = front_top_z + 2
	if prompt_layer != null:
		prompt_layer.z_index = front_top_z + 3
	_apply_readable_overlay_scale()

func _apply_back_sorting() -> void:
	lower_sprite.z_index = back_lower_z
	top_sprite.z_index = back_top_z
	highlight_layer.z_index = back_top_z + 1
	marker_layer.z_index = back_top_z + 2
	if prompt_layer != null:
		prompt_layer.z_index = back_top_z + 3
	_apply_readable_overlay_scale()

func is_pickup_drop_focusable(_other_player: Node) -> bool:
	return true

func interact_with_player(_other_player: Node) -> bool:
	if focused_slot_index < 0:
		return false
	var order_manager: Node = _get_order_manager()
	if order_manager == null:
		return false
	# Orders use a short held interaction so action-speed effects have a real,
	# visible target. The held path below performs the actual progress.
	return order_manager.has_method("process_take_order_at_slot")

func process_hold_interaction(other_player: Node, delta: float) -> bool:
	if focused_slot_index < 0:
		return false
	var order_manager: Node = _get_order_manager()
	if order_manager == null or not order_manager.has_method("process_take_order_at_slot"):
		return false
	return bool(order_manager.process_take_order_at_slot(_get_global_slot_number(focused_slot_index), delta, other_player))

func get_interaction_progress_data(_other_player: Node) -> Dictionary:
	if focused_slot_index < 0:
		return {}
	var order_manager: Node = _get_order_manager()
	if order_manager == null or not order_manager.has_method("get_take_order_action_progress"):
		return {}
	return order_manager.get_take_order_action_progress(_get_global_slot_number(focused_slot_index))

func can_receive_item(other_player: Node) -> bool:
	if not other_player.has_method("is_holding_item") or not other_player.is_holding_item():
		return false
	if not other_player.has_method("get_held_item_id"):
		return false
	var held_item_id: StringName = other_player.get_held_item_id()
	if held_item_id == &"ice_water":
		var manager: Node = _get_order_manager()
		return manager != null and focused_slot_index >= 0 and manager.can_offer_water(_get_global_slot_number(focused_slot_index))
	if not TestItemDefs.is_dish(held_item_id):
		return false
	var order_manager: Node = _get_order_manager()
	if order_manager == null or (order_manager.has_method("has_active_order") and not order_manager.has_active_order()):
		return false
	if focused_slot_index < 0 or not order_manager.has_method("get_active_order_for_delivery"):
		return false
	if TestItemDefs.is_dessert(held_item_id):
		return order_manager.can_offer_dessert(_get_global_slot_number(focused_slot_index), held_item_id, other_player.get_held_item_recipe_signature())
	return not _get_delivery_order(other_player).is_empty()

func get_interaction_button_prompt(other_player: Node) -> String:
	if other_player != null and can_receive_item(other_player):
		return "J SERVE"
	if focused_slot_index >= 0 and waiting_order_by_slot.has(focused_slot_index):
		return "K ORDER"
	return ""

func receive_item_from_player(other_player: Node) -> bool:
	if not can_receive_item(other_player):
		return false
	if other_player.get_held_item_id() == &"ice_water":
		if _get_order_manager().offer_water(_get_global_slot_number(focused_slot_index)):
			other_player.clear_held_item()
			return true
		return false
	var delivery_order: Dictionary = _get_delivery_order(other_player)
	var delivery_payload: Dictionary = CarryItemRules.payload_from(other_player)
	var returns_plate: bool = bool(CarryItemRules.payload_from(other_player).get("uses_plate", false))
	var dessert := TestItemDefs.is_dessert(other_player.get_held_item_id())
	var order_manager: Node = _get_order_manager()
	if dessert and not order_manager.offer_dessert(_get_global_slot_number(focused_slot_index), other_player.get_held_item_id(), other_player.get_held_item_recipe_signature(), delivery_payload):
		return false

	if other_player.has_method("clear_held_item"):
		other_player.clear_held_item()
	if returns_plate:
		other_player.pick_up_item(TestItemDefs.DIRTY_PLATE_ID, TestItemDefs.get_item_texture(TestItemDefs.DIRTY_PLATE_ID))

	if order_manager != null and order_manager.has_method("complete_current_order"):
		preload("res://Scripts/Player/PlayerWorkEvents.gd").completed(other_player, &"serve")
		if not dessert:
			order_manager.complete_current_order(
				_get_global_slot_number(focused_slot_index),
				true,
				String(delivery_order.get("order_id", "")),
				delivery_payload
			)
	_update_marker_layer()
	queue_redraw()
	return true

func _held_item_matches_order(other_player: Node) -> bool:
	return not _get_delivery_order(other_player).is_empty()

func _get_delivery_order(other_player: Node) -> Dictionary:
	if other_player == null or focused_slot_index < 0 or not other_player.has_method("get_held_item_id"):
		return {}
	var order_manager: Node = _get_order_manager()
	if order_manager == null or not order_manager.has_method("get_active_order_for_delivery"):
		return {}
	var signature: String = String(other_player.get_held_item_recipe_signature()) if other_player.has_method("get_held_item_recipe_signature") else ""
	return order_manager.get_active_order_for_delivery(_get_global_slot_number(focused_slot_index), other_player.get_held_item_id(), signature)

func get_pickup_drop_radius() -> float:
	return pickup_distance

func get_player_interaction_radius() -> float:
	return pickup_distance

func set_pickup_drop_highlight(active: bool) -> void:
	is_highlighted = active
	if not active:
		focused_slot_index = -1
	_update_highlight_visual()
	queue_redraw()

func set_pickup_drop_focus_data(_other_player: Node, focus_data: Dictionary) -> void:
	focused_slot_index = int(focus_data.get("slot_index", -1))
	_update_highlight_visual()
	queue_redraw()

func can_be_moved_by_player(_other_player: Node) -> bool:
	return movable_by_player

func get_layout_footprint() -> Vector2i:
	if layout_footprint_cells.x > 0 and layout_footprint_cells.y > 0:
		return layout_footprint_cells
	return Vector2i(maxi(slot_count, 1), 1)

func evaluate_pickup_drop_focus(_other_player: Node, interaction_origin: Vector2, aim_direction: Vector2, interaction_radius: float, half_interaction_angle: float) -> Dictionary:
	var best_slot_index: int = -1
	var best_angle: float = INF
	var best_distance: float = INF
	var safe_aim: Vector2 = aim_direction.normalized() if aim_direction.length_squared() > 0.0001 else Vector2.RIGHT

	for i in range(slot_count):
		var slot_rect: Rect2 = _get_slot_rect_local(i)
		var slot_rect_global: Rect2 = _local_rect_to_global(slot_rect)
		var nearest_point := Vector2(
			clampf(interaction_origin.x, slot_rect_global.position.x, slot_rect_global.position.x + slot_rect_global.size.x),
			clampf(interaction_origin.y, slot_rect_global.position.y, slot_rect_global.position.y + slot_rect_global.size.y)
		)
		var to_slot: Vector2 = nearest_point - interaction_origin
		var slot_distance: float = to_slot.length()
		if slot_distance > interaction_radius:
			continue

		if slot_distance <= 0.001:
			return {
				"valid": true,
				"angle": 0.0,
				"distance": 0.0,
				"slot_index": i
			}

		var slot_angle: float = abs(safe_aim.angle_to(to_slot.normalized()))
		if slot_angle > half_interaction_angle:
			continue

		if slot_angle < best_angle - 0.001 or (is_equal_approx(slot_angle, best_angle) and slot_distance < best_distance):
			best_angle = slot_angle
			best_distance = slot_distance
			best_slot_index = i

	if best_slot_index == -1:
		return {}

	return {
		"valid": true,
		"angle": best_angle,
		"distance": best_distance,
		"slot_index": best_slot_index
	}

func set_order_target_slot(slot_index: int) -> void:
	var local_slot_index: int = slot_index - slot_number_offset
	if local_slot_index < 0 or local_slot_index >= slot_count:
		order_target_slot_index = -1
	else:
		order_target_slot_index = local_slot_index
	_update_marker_layer()
	queue_redraw()

func get_order_target_slot() -> int:
	return order_target_slot_index

func _get_global_slot_number(local_slot_index: int) -> int:
	return max(local_slot_index + slot_number_offset + 1, 1)

func _get_order_manager() -> Node:
	if Engine.is_editor_hint():
		return null
	level_refs = LevelRefs.find_from(self)
	if level_refs != null:
		return level_refs.get_order_manager()
	return null

func _connect_order_manager_signals() -> void:
	var order_manager: Node = _get_order_manager()
	if order_manager == null:
		return
	if order_manager.has_signal("waiting_orders_changed") and not order_manager.waiting_orders_changed.is_connected(_on_waiting_orders_changed):
		order_manager.waiting_orders_changed.connect(_on_waiting_orders_changed)
	if order_manager.has_signal("orders_changed") and not order_manager.orders_changed.is_connected(_on_active_orders_changed):
		order_manager.orders_changed.connect(_on_active_orders_changed)
	if order_manager.has_signal("waiting_order_progress_changed") and not order_manager.waiting_order_progress_changed.is_connected(_on_waiting_order_progress_changed):
		order_manager.waiting_order_progress_changed.connect(_on_waiting_order_progress_changed)
	if order_manager.has_signal("order_progress_changed") and not order_manager.order_progress_changed.is_connected(_on_order_progress_changed):
		order_manager.order_progress_changed.connect(_on_order_progress_changed)

func _get_order_hud() -> Node:
	if Engine.is_editor_hint():
		return null
	level_refs = LevelRefs.find_from(self)
	if level_refs != null:
		return level_refs.get_order_hud()
	return null

func _get_slot_rect_local(slot_index: int) -> Rect2:
	var clamped_count: int = max(slot_count, 1)
	var step: float = slot_span_width / float(clamped_count)
	var left_x: float = -slot_span_width * 0.5
	var center_x: float = left_x + step * (float(slot_index) + 0.5)
	return Rect2(Vector2(center_x - slot_size.x * 0.5, slot_center_y - slot_size.y * 0.5), slot_size)

func _get_slot_center_local(slot_index: int) -> Vector2:
	var slot_rect: Rect2 = _get_slot_rect_local(slot_index)
	return slot_rect.position + slot_rect.size * 0.5

func _local_rect_to_global(local_rect: Rect2) -> Rect2:
	var top_left := to_global(local_rect.position)
	var top_right := to_global(local_rect.position + Vector2(local_rect.size.x, 0.0))
	var bottom_left := to_global(local_rect.position + Vector2(0.0, local_rect.size.y))
	var bottom_right := to_global(local_rect.position + local_rect.size)
	var min_x := minf(top_left.x, minf(top_right.x, minf(bottom_left.x, bottom_right.x)))
	var max_x := maxf(top_left.x, maxf(top_right.x, maxf(bottom_left.x, bottom_right.x)))
	var min_y := minf(top_left.y, minf(top_right.y, minf(bottom_left.y, bottom_right.y)))
	var max_y := maxf(top_left.y, maxf(top_right.y, maxf(bottom_left.y, bottom_right.y)))
	return Rect2(Vector2(min_x, min_y), Vector2(max_x - min_x, max_y - min_y))

func _ensure_highlight_nodes() -> void:
	if slot_polygons.size() == slot_count and slot_outlines.size() == slot_count:
		_update_highlight_visual()
		return

	for child in highlight_layer.get_children():
		child.queue_free()
	slot_polygons.clear()
	slot_outlines.clear()

	for i in range(slot_count):
		var polygon := Polygon2D.new()
		polygon.visible = false
		polygon.color = highlight_fill_color
		highlight_layer.add_child(polygon)
		slot_polygons.append(polygon)

		var outline := Line2D.new()
		outline.visible = false
		outline.width = 2.0
		outline.default_color = highlight_outline_color
		outline.closed = true
		highlight_layer.add_child(outline)
		slot_outlines.append(outline)

	_update_highlight_visual()

func _update_highlight_visual() -> void:
	if slot_polygons.is_empty() or slot_outlines.is_empty():
		return

	for i in range(slot_count):
		var is_slot_visible: bool = is_highlighted and i == focused_slot_index
		var slot_rect: Rect2 = _get_slot_rect_local(i)
		var points := PackedVector2Array([
			slot_rect.position,
			slot_rect.position + Vector2(slot_rect.size.x, 0.0),
			slot_rect.position + slot_rect.size,
			slot_rect.position + Vector2(0.0, slot_rect.size.y)
		])

		slot_polygons[i].polygon = points
		slot_polygons[i].visible = is_slot_visible
		slot_polygons[i].color = highlight_fill_color

		var outline_points := points
		outline_points.append(points[0])
		slot_outlines[i].points = outline_points
		slot_outlines[i].visible = is_slot_visible
		slot_outlines[i].default_color = highlight_outline_color

func _rebuild_slot_marker_positions() -> void:
	slot_marker_positions.clear()
	for i in range(slot_count):
		var center: Vector2 = _get_slot_center_local(i)
		slot_marker_positions.append(Vector2(center.x, marker_y))

func _update_marker_layer() -> void:
	if marker_layer == null or not marker_layer.has_method("configure"):
		return
	marker_layer.configure(
		slot_marker_positions,
		order_target_slot_index,
		delivered_slot_index,
		marker_radius,
		marker_fill_color,
		marker_outline_color,
		marker_text_color,
		marker_font_size,
		slot_number_offset
	)

func _ensure_prompt_layer() -> void:
	if prompt_layer != null:
		return
	prompt_layer = Node2D.new()
	prompt_layer.name = "OrderPromptLayer"
	add_child(prompt_layer)
	_apply_readable_overlay_scale()

func _apply_readable_overlay_scale() -> void:
	var readable_scale := Vector2(
		1.0 / global_scale.x if absf(global_scale.x) > 0.001 else 1.0,
		1.0 / global_scale.y if absf(global_scale.y) > 0.001 else 1.0
	)
	if marker_layer != null:
		marker_layer.scale = readable_scale
	if prompt_layer != null:
		prompt_layer.scale = readable_scale

func _ensure_screen_edge_prompt_layer() -> void:
	if Engine.is_editor_hint() or is_instance_valid(screen_edge_prompt_layer):
		return
	screen_edge_prompt_layer = CanvasLayer.new()
	screen_edge_prompt_layer.name = "ServingCounterScreenEdgePrompts"
	screen_edge_prompt_layer.layer = 42
	screen_edge_prompt_layer.add_to_group(SCREEN_EDGE_PROMPT_GROUP)
	add_child(screen_edge_prompt_layer)

func _on_waiting_orders_changed(order_list: Array) -> void:
	waiting_order_by_slot.clear()
	for order_data in order_list:
		if not (order_data is Dictionary):
			continue
		var local_slot_index: int = int(order_data.get("target_slot", -1)) - slot_number_offset - 1
		if local_slot_index >= 0 and local_slot_index < slot_count:
			var current: Dictionary = waiting_order_by_slot.get(local_slot_index, {})
			var candidate_index := int(order_data.get("customer_order_index", order_data.get("special_guest_index", 0)))
			var current_index := int(current.get("customer_order_index", current.get("special_guest_index", 999999)))
			if current.is_empty() or candidate_index < current_index:
				waiting_order_by_slot[local_slot_index] = order_data.duplicate(true)
	_update_prompt_layer()
	queue_redraw()

func _on_active_orders_changed(order_list: Array) -> void:
	active_order_by_slot.clear()
	for order_data in order_list:
		if not (order_data is Dictionary):
			continue
		var local_slot_index: int = int(order_data.get("target_slot", -1)) - slot_number_offset - 1
		if local_slot_index >= 0 and local_slot_index < slot_count:
			active_order_by_slot[local_slot_index] = order_data.duplicate(true)
	_update_prompt_layer()
	queue_redraw()

func _update_prompt_layer() -> void:
	if prompt_layer == null:
		return
	for child in prompt_layer.get_children():
		child.queue_free()
	prompt_fill_by_slot.clear()

	for i in range(slot_count):
		var prompt_data: Dictionary = {}
		var is_waiting: bool = waiting_order_by_slot.has(i)
		var is_active: bool = active_order_by_slot.has(i)
		if is_active:
			prompt_data = active_order_by_slot[i]
		elif is_waiting:
			prompt_data = waiting_order_by_slot[i]
		else:
			continue
		_add_order_prompt(i, prompt_data, is_waiting)
	_update_screen_edge_prompt_layer()

func _add_order_prompt(slot_index: int, order_data: Dictionary, is_waiting: bool) -> void:
	var root := Node2D.new()
	root.set_meta("slot_index", slot_index)
	root.position = _get_order_prompt_local_position(slot_index)
	prompt_layer.add_child(root)

	if not is_waiting:
		prompt_fill_by_slot[slot_index] = _add_order_patience_bar(root, order_data, false)
		return

	var halo := ColorRect.new()
	halo.position = Vector2(-order_prompt_icon_size.x * 0.5 - 12.0, -order_prompt_icon_size.y * 0.5 - 34.0)
	halo.size = order_prompt_icon_size + Vector2(24.0, 56.0)
	halo.color = Color(0.04, 0.035, 0.02, 0.88)
	root.add_child(halo)

	var request_icon := Label.new()
	request_icon.position = Vector2(-order_prompt_icon_size.x * 0.5, -order_prompt_icon_size.y * 0.5 - 4.0)
	request_icon.size = order_prompt_icon_size
	request_icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	request_icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	request_icon.add_theme_font_size_override("font_size", 78)
	request_icon.text = "!"
	request_icon.modulate = SPECIAL_GUEST_PROMPT_COLOR if bool(order_data.get("special_guest", false)) else Color(1.0, 0.95, 0.18, 1.0)
	root.add_child(request_icon)

	var key_label := Label.new()
	key_label.position = Vector2(-64.0, -order_prompt_icon_size.y * 0.5 - 34.0)
	key_label.size = Vector2(128.0, 26.0)
	key_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	key_label.add_theme_font_size_override("font_size", 24 if is_waiting else 17)
	key_label.text = "K ORDER" if is_waiting else "ORDER"
	key_label.modulate = _get_order_prompt_color(order_data, is_waiting)
	root.add_child(key_label)

	prompt_fill_by_slot[slot_index] = _add_order_patience_bar(root, order_data, true)

func _add_order_patience_bar(root: Node, order_data: Dictionary, is_waiting: bool) -> ColorRect:
	var frame := ColorRect.new()
	frame.position = Vector2(-order_prompt_bar_size.x * 0.5, order_prompt_icon_size.y * 0.5 + 6.0) if is_waiting else Vector2(-order_prompt_bar_size.x * 0.5, -order_prompt_bar_size.y * 0.5)
	frame.size = order_prompt_bar_size
	frame.color = Color(0.08, 0.07, 0.05, 0.95)
	root.add_child(frame)

	var fill := ColorRect.new()
	fill.position = Vector2.ZERO
	fill.size = Vector2(order_prompt_bar_size.x * _get_prompt_patience_ratio(order_data, is_waiting), order_prompt_bar_size.y)
	fill.color = _get_order_prompt_color(order_data, is_waiting)
	frame.add_child(fill)
	return fill

func _get_order_prompt_color(order_data: Dictionary, is_waiting: bool) -> Color:
	if bool(order_data.get("special_guest", false)):
		return SPECIAL_GUEST_PROMPT_COLOR
	return order_prompt_ready_color if is_waiting else order_prompt_active_color

func _on_waiting_order_progress_changed(order_id: String, time_remaining: float, patience_duration: float) -> void:
	_update_order_progress(order_id, time_remaining, patience_duration, true)

func _on_order_progress_changed(order_id: String, time_remaining: float, patience_duration: float) -> void:
	_update_order_progress(order_id, time_remaining, patience_duration, false)

func _update_order_progress(order_id: String, time_remaining: float, patience_duration: float, is_waiting: bool) -> void:
	var orders_by_slot: Dictionary = waiting_order_by_slot if is_waiting else active_order_by_slot
	for slot_index in orders_by_slot.keys():
		var order_data: Dictionary = orders_by_slot[slot_index]
		if String(order_data.get("order_id", "")) != order_id:
			continue
		var remaining_key := "order_take_time_remaining" if is_waiting else "time_remaining"
		order_data[remaining_key] = time_remaining
		var fill: ColorRect = prompt_fill_by_slot.get(slot_index, null)
		if fill != null and is_instance_valid(fill):
			fill.size.x = order_prompt_bar_size.x * clampf(time_remaining / maxf(patience_duration, 0.001), 0.0, 1.0)
		return

func _update_prompt_positions() -> void:
	if prompt_layer == null:
		return
	for child in prompt_layer.get_children():
		var prompt_root: Node2D = child as Node2D
		if prompt_root != null:
			var slot_index := int(prompt_root.get_meta("slot_index", -1))
			if slot_index >= 0:
				prompt_root.position = _get_order_prompt_local_position(slot_index)

func _get_order_prompt_local_position(slot_index: int) -> Vector2:
	var slot_global_position: Vector2 = to_global(_get_slot_center_local(slot_index))
	var outward_direction: Vector2 = _get_counter_outward_direction(slot_global_position)
	var desired_global_position: Vector2 = slot_global_position + outward_direction * maxf(order_prompt_icon_size.y * 0.74, 76.0)
	return prompt_layer.to_local(desired_global_position) if prompt_layer != null else to_local(desired_global_position)

func _get_counter_outward_direction(slot_global_position: Vector2) -> Vector2:
	var center: Vector2 = _get_kitchen_center_global()
	var direction: Vector2 = slot_global_position - center
	if direction.length_squared() <= 0.001:
		direction = global_position - center
	if direction.length_squared() <= 0.001:
		direction = Vector2.DOWN
	if absf(direction.x) > absf(direction.y):
		return Vector2.RIGHT if direction.x > 0.0 else Vector2.LEFT
	return Vector2.DOWN if direction.y > 0.0 else Vector2.UP

func _get_kitchen_center_global() -> Vector2:
	level_refs = LevelRefs.find_from(self)
	if level_refs != null:
		var prototype_map: Node = level_refs.get_prototype_map()
		if prototype_map != null and prototype_map.has_method("get_kitchen_zone_bounds"):
			var kitchen_bounds: Rect2 = prototype_map.get_kitchen_zone_bounds()
			return kitchen_bounds.get_center()
	return Vector2(2304.0, 1280.0)

func _update_screen_edge_prompt_layer() -> void:
	if Engine.is_editor_hint():
		return
	_ensure_screen_edge_prompt_layer()
	if not is_instance_valid(screen_edge_prompt_layer):
		return

	for child in screen_edge_prompt_layer.get_children():
		child.queue_free()
	screen_edge_prompt_by_slot.clear()
	if waiting_order_by_slot.is_empty():
		return

	var viewport := get_viewport()
	if viewport == null:
		return
	var visible_rect: Rect2 = viewport.get_visible_rect()
	var camera: Camera2D = viewport.get_camera_2d()
	var viewport_center: Vector2 = visible_rect.size * 0.5

	for slot_index in waiting_order_by_slot.keys():
		var local_slot_index := int(slot_index)
		var order_data: Dictionary = waiting_order_by_slot[local_slot_index]
		var slot_world_position: Vector2 = to_global(_get_slot_center_local(local_slot_index))
		var slot_screen_position: Vector2 = _world_to_screen_position(slot_world_position, viewport, camera)
		var prompt_root: Control = _add_screen_edge_prompt(slot_screen_position, viewport_center, visible_rect, order_data, _get_global_slot_number(local_slot_index))
		prompt_root.visible = not _is_screen_position_visible(slot_screen_position, visible_rect)
		screen_edge_prompt_by_slot[local_slot_index] = prompt_root
	_layout_all_screen_edge_prompts(visible_rect)

func _world_to_screen_position(world_position: Vector2, viewport: Viewport, _camera: Camera2D) -> Vector2:
	return viewport.get_canvas_transform() * world_position

func _is_screen_position_visible(screen_position: Vector2, visible_rect: Rect2) -> bool:
	var padded_size := visible_rect.size - Vector2(screen_edge_prompt_margin * 2.0, screen_edge_prompt_margin * 2.0)
	if padded_size.x <= 0.0 or padded_size.y <= 0.0:
		return visible_rect.has_point(screen_position)
	var padded_rect := Rect2(Vector2(screen_edge_prompt_margin, screen_edge_prompt_margin), padded_size)
	return padded_rect.has_point(screen_position)

func _add_screen_edge_prompt(
	raw_screen_position: Vector2,
	viewport_center: Vector2,
	visible_rect: Rect2,
	order_data: Dictionary,
	gate_number: int
) -> Control:
	var direction: Vector2 = raw_screen_position - viewport_center
	if direction.length_squared() <= 0.001:
		direction = Vector2.UP
	direction = direction.normalized()

	var clamped_position := _clamp_screen_edge_prompt_position(raw_screen_position, visible_rect)
	var root := Control.new()
	root.position = clamped_position - screen_edge_prompt_size * 0.5
	root.size = screen_edge_prompt_size
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.set_meta("desired_center", clamped_position)
	root.set_meta("screen_edge", _get_screen_edge(direction))
	screen_edge_prompt_layer.add_child(root)

	var panel := Panel.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.04, 0.025, 0.9)
	style.border_color = _get_order_prompt_color(order_data, true)
	style.border_width_left = 3
	style.border_width_top = 3
	style.border_width_right = 3
	style.border_width_bottom = 3
	style.corner_radius_top_left = 22
	style.corner_radius_top_right = 22
	style.corner_radius_bottom_left = 22
	style.corner_radius_bottom_right = 22
	panel.add_theme_stylebox_override("panel", style)
	root.add_child(panel)

	var arrow := Label.new()
	arrow.position = Vector2(10.0, 14.0)
	arrow.size = Vector2(36.0, 34.0)
	arrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	arrow.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	arrow.add_theme_font_size_override("font_size", 28)
	arrow.text = _get_edge_arrow_text(direction)
	arrow.modulate = _get_order_prompt_color(order_data, true)
	root.add_child(arrow)

	var request_icon := Label.new()
	request_icon.position = Vector2(48.0, 5.0)
	request_icon.size = Vector2(54.0, 58.0)
	request_icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	request_icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	request_icon.add_theme_font_size_override("font_size", 52)
	request_icon.text = "!"
	request_icon.modulate = _get_order_prompt_color(order_data, true)
	root.add_child(request_icon)

	var label := Label.new()
	label.position = Vector2(108.0, 10.0)
	label.size = Vector2(64.0, 26.0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 18)
	label.text = "Gate"
	label.modulate = Color(1.0, 0.94, 0.72, 0.9)
	root.add_child(label)

	var number := Label.new()
	number.position = Vector2(108.0, 36.0)
	number.size = Vector2(64.0, 32.0)
	number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	number.add_theme_font_size_override("font_size", 28)
	number.text = str(gate_number)
	number.modulate = _get_order_prompt_color(order_data, true)
	root.add_child(number)

	var tail := Polygon2D.new()
	tail.name = "BubbleTail"
	tail.polygon = _get_edge_prompt_tail_points(direction)
	tail.color = Color(0.05, 0.04, 0.025, 0.96)
	tail.z_index = -1
	root.add_child(tail)
	return root

func _update_screen_edge_prompt_positions() -> void:
	if not is_instance_valid(screen_edge_prompt_layer) or screen_edge_prompt_by_slot.is_empty():
		return
	var viewport := get_viewport()
	if viewport == null:
		return
	var visible_rect: Rect2 = viewport.get_visible_rect()
	var camera: Camera2D = viewport.get_camera_2d()
	var viewport_center: Vector2 = visible_rect.size * 0.5
	for slot_index in screen_edge_prompt_by_slot.keys():
		var prompt_root: Control = screen_edge_prompt_by_slot.get(slot_index, null)
		if prompt_root == null or not is_instance_valid(prompt_root):
			continue
		var slot_world_position: Vector2 = to_global(_get_slot_center_local(int(slot_index)))
		var slot_screen_position: Vector2 = _world_to_screen_position(slot_world_position, viewport, camera)
		prompt_root.visible = not _is_screen_position_visible(slot_screen_position, visible_rect)
		if not prompt_root.visible:
			continue
		var clamped_position := _clamp_screen_edge_prompt_position(slot_screen_position, visible_rect)
		prompt_root.position = clamped_position - screen_edge_prompt_size * 0.5
		var direction: Vector2 = slot_screen_position - viewport_center
		if direction.length_squared() <= 0.001:
			direction = Vector2.UP
		direction = direction.normalized()
		prompt_root.set_meta("desired_center", clamped_position)
		prompt_root.set_meta("screen_edge", _get_screen_edge(direction))
		var arrow: Label = prompt_root.get_child(1) as Label if prompt_root.get_child_count() > 1 else null
		if arrow != null:
			arrow.text = _get_edge_arrow_text(direction)
		var tail: Polygon2D = prompt_root.get_node_or_null("BubbleTail") as Polygon2D
		if tail != null:
			tail.polygon = _get_edge_prompt_tail_points(direction)
	_layout_all_screen_edge_prompts(visible_rect)

func _layout_all_screen_edge_prompts(visible_rect: Rect2) -> void:
	var prompts_by_edge: Dictionary = {
		&"left": [],
		&"right": [],
		&"top": [],
		&"bottom": []
	}
	for prompt_canvas in get_tree().get_nodes_in_group(SCREEN_EDGE_PROMPT_GROUP):
		if not is_instance_valid(prompt_canvas) or prompt_canvas.is_queued_for_deletion():
			continue
		for child in prompt_canvas.get_children():
			var prompt_root := child as Control
			if prompt_root == null or prompt_root.is_queued_for_deletion() or not prompt_root.visible:
				continue
			var edge := StringName(prompt_root.get_meta("screen_edge", &""))
			if not prompts_by_edge.has(edge):
				continue
			var edge_prompts: Array = prompts_by_edge[edge]
			edge_prompts.append(prompt_root)
			prompts_by_edge[edge] = edge_prompts

	for edge in prompts_by_edge.keys():
		_layout_screen_edge_prompt_group(prompts_by_edge[edge], StringName(edge), visible_rect)

func _layout_screen_edge_prompt_group(prompts: Array, edge: StringName, visible_rect: Rect2) -> void:
	if prompts.is_empty():
		return
	var is_vertical: bool = edge in [&"left", &"right"]
	prompts.sort_custom(func(first: Control, second: Control) -> bool:
		var first_center: Vector2 = first.get_meta("desired_center", first.position + first.size * 0.5)
		var second_center: Vector2 = second.get_meta("desired_center", second.position + second.size * 0.5)
		return (first_center.y if is_vertical else first_center.x) < (second_center.y if is_vertical else second_center.x)
	)

	var axis_length: float = visible_rect.size.y if is_vertical else visible_rect.size.x
	var next_start: float = screen_edge_prompt_margin
	var prompt_gap: float = 14.0
	for prompt_root in prompts:
		var control := prompt_root as Control
		var desired_center: Vector2 = control.get_meta("desired_center", control.position + control.size * 0.5)
		var prompt_extent: float = control.size.y if is_vertical else control.size.x
		var desired_axis: float = desired_center.y if is_vertical else desired_center.x
		var arranged_center: float = maxf(desired_axis, next_start + prompt_extent * 0.5)
		control.set_meta("arranged_axis", arranged_center)
		next_start = arranged_center + prompt_extent * 0.5 + prompt_gap

	var available_end: float = axis_length - screen_edge_prompt_margin
	var overflow: float = maxf(next_start - prompt_gap - available_end, 0.0)
	for prompt_root in prompts:
		var control := prompt_root as Control
		var arranged_axis: float = float(control.get_meta("arranged_axis", 0.0)) - overflow
		var desired_center: Vector2 = control.get_meta("desired_center", control.position + control.size * 0.5)
		if is_vertical:
			control.position = Vector2(desired_center.x - control.size.x * 0.5, arranged_axis - control.size.y * 0.5)
		else:
			control.position = Vector2(arranged_axis - control.size.x * 0.5, desired_center.y - control.size.y * 0.5)

func _get_screen_edge(direction: Vector2) -> StringName:
	if absf(direction.x) > absf(direction.y):
		return &"right" if direction.x > 0.0 else &"left"
	return &"bottom" if direction.y > 0.0 else &"top"

func _clamp_screen_edge_prompt_position(raw_screen_position: Vector2, visible_rect: Rect2) -> Vector2:
	var half_size := screen_edge_prompt_size * 0.5
	var minimum := Vector2(screen_edge_prompt_margin, screen_edge_prompt_margin) + half_size
	var maximum := visible_rect.size - Vector2(screen_edge_prompt_margin, screen_edge_prompt_margin) - half_size
	return Vector2(
		clampf(raw_screen_position.x, minimum.x, maxf(minimum.x, maximum.x)),
		clampf(raw_screen_position.y, minimum.y, maxf(minimum.y, maximum.y))
	)

func _get_edge_prompt_tail_points(direction: Vector2) -> PackedVector2Array:
	var center := screen_edge_prompt_size * 0.5
	if absf(direction.x) > absf(direction.y):
		if direction.x > 0.0:
			return PackedVector2Array([Vector2(screen_edge_prompt_size.x - 4.0, center.y - 13.0), Vector2(screen_edge_prompt_size.x + 22.0, center.y), Vector2(screen_edge_prompt_size.x - 4.0, center.y + 13.0)])
		return PackedVector2Array([Vector2(4.0, center.y - 13.0), Vector2(-22.0, center.y), Vector2(4.0, center.y + 13.0)])
	if direction.y > 0.0:
		return PackedVector2Array([Vector2(center.x - 13.0, screen_edge_prompt_size.y - 4.0), Vector2(center.x, screen_edge_prompt_size.y + 22.0), Vector2(center.x + 13.0, screen_edge_prompt_size.y - 4.0)])
	return PackedVector2Array([Vector2(center.x - 13.0, 4.0), Vector2(center.x, -22.0), Vector2(center.x + 13.0, 4.0)])

func _get_edge_arrow_text(direction: Vector2) -> String:
	if absf(direction.x) > absf(direction.y):
		return ">" if direction.x > 0.0 else "<"
	return "v" if direction.y > 0.0 else "^"

func _get_prompt_patience_ratio(order_data: Dictionary, is_waiting: bool) -> float:
	if is_waiting:
		var duration: float = maxf(float(order_data.get("order_take_patience_duration", 1.0)), 0.001)
		return clampf(float(order_data.get("order_take_time_remaining", duration)) / duration, 0.0, 1.0)
	var cook_duration: float = maxf(float(order_data.get("patience_duration", 1.0)), 0.001)
	return clampf(float(order_data.get("time_remaining", cook_duration)) / cook_duration, 0.0, 1.0)

func reset_state() -> void:
	is_highlighted = false
	focused_slot_index = -1
	order_target_slot_index = -1
	delivered_slot_index = -1
	waiting_order_by_slot.clear()
	active_order_by_slot.clear()
	set_pickup_drop_highlight(false)
	_update_marker_layer()
	_update_prompt_layer()
	queue_redraw()
