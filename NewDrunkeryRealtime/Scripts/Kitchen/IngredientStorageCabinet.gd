@tool
extends StaticBody2D

const InteractionGeometry = preload("res://Scripts/Core/InteractionGeometry.gd")

const TestItemDefs = preload("res://Scripts/Kitchen/TestItemDefs.gd")
const LevelRefs = preload("res://Scripts/Core/LevelRefs.gd")

@export var front_collision_z: int = 0
@export var stored_item_id: StringName = TestItemDefs.MEAT_RED_ID
@export var pickup_distance: float = 172.0
@export var interaction_area_center: Vector2 = Vector2(0, -10)
@export var interaction_area_size: Vector2 = Vector2(136, 132)
@export var interaction_area_columns: int = 3
@export var interaction_area_rows: int = 3
@export var front_z: int = 0
@export var back_z: int = 3
@export var normal_modulate: Color = Color.WHITE
@export var highlight_modulate: Color = Color(1.18, 1.14, 0.98, 1.0)
@export var item_icon_normal_scale: Vector2 = Vector2(0.56, 0.56)
@export var item_icon_highlight_scale: Vector2 = Vector2(0.56, 0.56)
@export var show_interaction_debug: bool = false
@export var debug_area_fill_color: Color = Color(0.82, 0.68, 0.28, 0.12)
@export var debug_area_outline_color: Color = Color(0.94, 0.82, 0.38, 0.55)
@export var debug_point_fill_color: Color = Color(1.0, 0.96, 0.84, 0.95)
@export var debug_point_outline_color: Color = Color(0.94, 0.82, 0.38, 0.95)
@export var debug_point_radius: float = 5.0

@onready var cabinet_sprite: Sprite2D = $CabinetSprite
@onready var item_icon: Sprite2D = $ItemIcon
@onready var frozen_stock_label: Label = $FrozenStockLabel
@onready var fresh_stock_label: Label = $FreshStockLabel
@onready var sort_anchor: Marker2D = $SortAnchor
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

var player: Node2D
var storage_manager: Node
var level_refs: LevelRefs
var is_highlighted: bool = false
var menu_allowed_item_ids: Dictionary = {}
var menu_item_enabled: bool = true

func _ready() -> void:
	add_to_group("pickup_drop_targets")
	add_to_group("movable_facilities")
	add_to_group("storage_facilities")
	_update_player_reference()
	_resolve_storage_manager()
	_connect_storage_signals()
	_apply_visual_state()
	_refresh_content()
	queue_redraw()

func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		if show_interaction_debug:
			queue_redraw()
		return

	if not is_instance_valid(player):
		_update_player_reference()
	if storage_manager == null:
		_resolve_storage_manager()
		_connect_storage_signals()
	if show_interaction_debug:
		queue_redraw()

func set_menu_allowed_item_ids(item_ids: Array[StringName]) -> void:
	menu_allowed_item_ids.clear()
	for item_id in item_ids:
		menu_allowed_item_ids[item_id] = true
	_update_menu_visibility()
	_apply_visual_state()

func clear_menu_filter() -> void:
	menu_allowed_item_ids.clear()
	_update_menu_visibility()
	_apply_visual_state()

func _update_player_reference() -> void:
	player = get_tree().get_first_node_in_group("player") as Node2D

func _resolve_storage_manager() -> void:
	if Engine.is_editor_hint():
		return
	level_refs = LevelRefs.find_from(self)
	if level_refs != null:
		storage_manager = level_refs.get_storage_manager()

func _connect_storage_signals() -> void:
	if storage_manager == null:
		return
	if storage_manager.has_signal("stock_changed") and not storage_manager.stock_changed.is_connected(_on_storage_stock_changed):
		storage_manager.stock_changed.connect(_on_storage_stock_changed)
	if storage_manager.has_signal("inventory_changed") and not storage_manager.inventory_changed.is_connected(_on_storage_inventory_changed):
		storage_manager.inventory_changed.connect(_on_storage_inventory_changed)

func can_take_item(other_player: Node) -> bool:
	if not visible or not menu_item_enabled:
		return false
	if storage_manager == null:
		return false
	if storage_manager.get_available_stock(stored_item_id) <= 0:
		return false
	return other_player.has_method("can_pick_up_item") and other_player.can_pick_up_item(stored_item_id, TestItemDefs.PROCESS_STATE_NONE)

func is_scarab_steal_target() -> bool:
	# Boss ingredients are protected. Other sources follow menu/visibility
	# eligibility, independently of whether the player's hands are full.
	if not is_ordinary_stock_event_source():
		return false
	return not storage_manager.has_method("get_stock") or storage_manager.get_stock(stored_item_id) > 0

func is_ordinary_stock_event_source() -> bool:
	# Locked stone cabinets may retain hidden stock, but it is not part of
	# the restaurant's usable inventory for theft or voluntary event trades.
	return is_visible_in_tree() and menu_item_enabled and storage_manager != null and not TestItemDefs.is_boss_ingredient(stored_item_id)

func get_scarab_steal_reach() -> float:
	# Allow arrival tolerance around the four cardinal stand-off points.
	return 128.0

func get_scarab_approach_positions() -> Array[Vector2]:
	# Only cardinal sides are usable. Four occupied neighboring cells make
	# the cabinet inaccessible even when diagonal corners remain open.
	var positions: Array[Vector2] = []
	for offset: Vector2 in [Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT, Vector2.UP]:
		positions.append(global_position + offset * 112.0)
	return positions

func is_pickup_drop_focusable(other_player: Node) -> bool:
	if not visible:
		return false
	# Storage cabinets are also movable facilities.  Stone cabinets deliberately
	# have menu_item_enabled=false, but must still be focusable so the player can
	# see and use the K carry action near them.
	var holding_item: bool = other_player != null and other_player.has_method("is_holding_item") and bool(other_player.is_holding_item())
	return (can_receive_item(other_player) or can_take_item(other_player)) if holding_item else (can_take_item(other_player) or can_be_moved_by_player(other_player))

func can_receive_item(other_player: Node) -> bool:
	if not visible or not menu_item_enabled:
		return false
	if storage_manager == null:
		return false
	if other_player == null or not other_player.has_method("is_holding_item") or not other_player.is_holding_item():
		return false
	if not other_player.has_method("get_held_item_id") or not other_player.has_method("get_held_item_process_state"):
		return false
	if other_player.get_held_item_id() != stored_item_id:
		return false
	if TestItemDefs.normalize_process_state(other_player.get_held_item_process_state()) != TestItemDefs.PROCESS_STATE_NONE:
		return false
	if not _has_room_for_item():
		return false
	return true

func take_item_to_player(other_player: Node) -> bool:
	if not can_take_item(other_player):
		return false
	if storage_manager == null or not storage_manager.has_method("consume_stock"):
		return false
	if not other_player.has_method("pick_up_item"):
		return false

	var item_texture: Texture2D = TestItemDefs.get_item_texture(stored_item_id)
	var was_picked_up: Variant = other_player.pick_up_item(stored_item_id, item_texture, TestItemDefs.PROCESS_STATE_NONE)
	if not (was_picked_up is bool and was_picked_up):
		return false

	var should_consume := true
	if other_player.has_method("get_blessing_controller"):
		var blessing_runtime: RefCounted = other_player.get_blessing_controller()
		if blessing_runtime != null:
			should_consume = blessing_runtime.should_consume_storage_item()
	if should_consume and not storage_manager.consume_stock(stored_item_id, 1, &"fresh"):
		if other_player.has_method("clear_held_item"):
			other_player.clear_held_item()
		return false

	_refresh_content()
	return true

func receive_item_from_player(other_player: Node) -> bool:
	if not can_receive_item(other_player):
		return false
	if storage_manager == null or not storage_manager.has_method("add_stock"):
		return false
	if not _has_room_for_item():
		return false
	if not other_player.has_method("clear_held_item"):
		return false
	storage_manager.add_stock(stored_item_id, 1, &"fresh")
	other_player.clear_held_item()
	_refresh_content()
	return true

func get_interaction_button_prompt(other_player: Node) -> String:
	var keys: Array[String] = []
	var holding_item: bool = other_player != null and other_player.has_method("is_holding_item") and bool(other_player.is_holding_item())
	if holding_item:
		if can_receive_item(other_player):
			keys.append("J STORE")
		elif can_take_item(other_player):
			keys.append("J 装盘")
	else:
		if can_take_item(other_player):
			keys.append("J TAKE")
		# Manual facility carrying requires empty hands.
		if can_be_moved_by_player(other_player):
			keys.append("K MOVE")
	return " / ".join(keys)

func show_ingredient_source_hint() -> void:
	var SourceDefs = preload("res://Scripts/Core/IngredientSourceDefs.gd")
	var old_hint := get_node_or_null("IngredientSourceHint")
	if old_hint != null:
		old_hint.queue_free()
	var bubble := Label.new()
	bubble.name = "IngredientSourceHint"
	bubble.text = "%s来源\n%s" % [TestItemDefs.get_item_display_name(stored_item_id), SourceDefs.format_source_hint(stored_item_id)]
	bubble.position = Vector2(-145.0, -148.0)
	bubble.z_index = 40
	bubble.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bubble.add_theme_font_size_override("font_size", 20)
	bubble.add_theme_color_override("font_color", Color(1.0, 0.96, 0.82, 1.0))
	bubble.add_theme_color_override("font_shadow_color", Color(0.12, 0.06, 0.02, 0.95))
	bubble.add_theme_constant_override("shadow_offset_x", 2)
	bubble.add_theme_constant_override("shadow_offset_y", 2)
	add_child(bubble)
	get_tree().create_timer(3.0).timeout.connect(func() -> void:
		if is_instance_valid(bubble):
			bubble.queue_free()
	)

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

func can_be_moved_by_player(_other_player: Node) -> bool:
	return visible

func get_layout_footprint() -> Vector2i:
	return Vector2i(1, 1)

func get_facility_preview_data() -> Dictionary:
	if menu_item_enabled:
		return {}
	return {
		"body_size": Vector2(96.0, 76.0),
		"base_color": Color(0.25, 0.27, 0.29, 1.0),
		"accent_color": Color(0.18, 0.20, 0.21, 1.0),
		"outline_color": Color(0.10, 0.11, 0.12, 1.0),
		"facility_type": &"stone_cabinet"
	}

func reset_state() -> void:
	is_highlighted = false
	_apply_visual_state()
	queue_redraw()

func _refresh_content() -> void:
	_update_menu_visibility()
	if item_icon != null:
		item_icon.texture = TestItemDefs.get_item_texture(stored_item_id)
		item_icon.modulate = TestItemDefs.get_item_modulate(TestItemDefs.PROCESS_STATE_NONE, stored_item_id)

	var fresh_amount: int = 0
	var frozen_amount: int = 0
	if storage_manager != null:
		if storage_manager.has_method("get_fresh_stock"):
			fresh_amount = storage_manager.get_fresh_stock(stored_item_id)
		elif storage_manager.has_method("get_stock"):
			fresh_amount = storage_manager.get_stock(stored_item_id)
		if storage_manager.has_method("get_frozen_stock"):
			frozen_amount = storage_manager.get_frozen_stock(stored_item_id)
	if fresh_stock_label != null:
		fresh_stock_label.text = "鲜%d" % fresh_amount
	if frozen_stock_label != null:
		frozen_stock_label.text = "冻%d" % frozen_amount

func _apply_visual_state() -> void:
	_update_menu_visibility()
	var is_player_in_front: bool = _is_player_in_front()
	if cabinet_sprite != null:
		cabinet_sprite.visible = menu_item_enabled
		cabinet_sprite.modulate = highlight_modulate if is_highlighted else normal_modulate
		cabinet_sprite.z_index = front_z if is_player_in_front else back_z
	if item_icon != null:
		item_icon.visible = menu_item_enabled
		item_icon.scale = item_icon_highlight_scale if is_highlighted else item_icon_normal_scale
		item_icon.modulate = TestItemDefs.get_item_modulate(TestItemDefs.PROCESS_STATE_NONE, stored_item_id) * (highlight_modulate if is_highlighted else normal_modulate)
		item_icon.z_index = front_z + 1 if is_player_in_front else back_z + 1
	if frozen_stock_label != null:
		frozen_stock_label.visible = menu_item_enabled
		frozen_stock_label.z_index = front_z + 2 if is_player_in_front else back_z + 2
	if fresh_stock_label != null:
		fresh_stock_label.visible = menu_item_enabled
		fresh_stock_label.z_index = front_z + 2 if is_player_in_front else back_z + 2
	if collision_shape != null:
		collision_shape.disabled = false
		collision_shape.z_index = front_collision_z if is_player_in_front else back_z

func _is_player_in_front() -> bool:
	if player == null:
		return true
	var player_sort_origin: Vector2 = player.get_sort_origin() if player.has_method("get_sort_origin") else player.global_position
	return player_sort_origin.y > sort_anchor.global_position.y

func _on_storage_stock_changed(item_id: StringName, _new_amount: int) -> void:
	if item_id != stored_item_id:
		return
	_refresh_content()

func _on_storage_inventory_changed() -> void:
	_refresh_content()

func _has_room_for_item() -> bool:
	if storage_manager == null or not storage_manager.has_method("get_stock"):
		return false
	return storage_manager.get_stock(stored_item_id) < 99

func _update_menu_visibility() -> void:
	if menu_allowed_item_ids.is_empty():
		menu_item_enabled = true
	elif menu_allowed_item_ids.has(stored_item_id):
		menu_item_enabled = true
	else:
		menu_item_enabled = false
	if collision_shape != null:
		collision_shape.disabled = false
	var item_blocker_shape: CollisionShape2D = get_node_or_null("ItemBlocker/CollisionShape2D")
	if item_blocker_shape != null:
		item_blocker_shape.disabled = false

func _draw() -> void:
	if not menu_item_enabled:
		var stone_rect := Rect2(-48.0, -38.0, 96.0, 76.0)
		var stone := StyleBoxFlat.new()
		stone.bg_color = Color("89877a")
		stone.border_color = Color("5c6056")
		stone.set_border_width_all(3)
		stone.set_corner_radius_all(7)
		draw_style_box(stone, stone_rect)
		draw_polyline(PackedVector2Array([Vector2(-40, -26), Vector2(-26, -31), Vector2(27, -31), Vector2(39, -22)]), Color("c3bca3"), 3, true)
		draw_polyline(PackedVector2Array([Vector2(-9, -34), Vector2(-15, -13), Vector2(0, -4), Vector2(-8, 12), Vector2(3, 29)]), Color("5b6158"), 2.5, true)
		draw_line(Vector2(-15, -13), Vector2(-31, -5), Color("6c7061"), 2, true)
		draw_line(Vector2(7, 17), Vector2(35, 11), Color("b1ae96"), 2, true)
		return
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
