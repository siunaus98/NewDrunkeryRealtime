@tool
extends StaticBody2D

const AudioCue = preload("res://Scripts/Audio/AudioCue.gd")

const BARREL_TEXTURE = preload("res://ArtResource/Kitchen/drink_barrel.svg")
const InteractionGeometry = preload("res://Scripts/Core/InteractionGeometry.gd")

const TestItemDefs = preload("res://Scripts/Kitchen/TestItemDefs.gd")
const CarryItemRules = preload("res://Scripts/Kitchen/CarryItemRules.gd")
const UltimateBoost = preload("res://Scripts/Player/UltimateFacilityBoost.gd")

@export var footprint: Vector2i = Vector2i(2, 1)
@export var body_size: Vector2 = Vector2(238.0, 96.0)
# Only reserve the barrel's own two-cell footprint. Adjacent cells remain
# available for storage or support facilities so players can build a compact
# supply-box -> standing-space -> barrel brewing loop.
@export var interaction_block_margin_cells: int = 0
@export var outline_color: Color = Color(0.10, 0.055, 0.025, 1.0)
@export var fill_duration: float = 3.6
@export var servings_per_fill: int = 2
@export var max_servings: int = 3
@export var pickup_distance: float = 160.0
@export var interaction_area_center: Vector2 = Vector2(0.0, -10.0)
@export var interaction_area_size: Vector2 = Vector2(258.0, 132.0)
@export var interaction_area_columns: int = 4
@export var interaction_area_rows: int = 2
@export var normal_modulate: Color = Color.WHITE
@export var highlight_modulate: Color = Color(1.2, 1.16, 0.92, 1.0)

@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var item_blocker_shape: CollisionShape2D = $ItemBlocker/CollisionShape2D

var fill_progress: float = 0.0
var serving_count: int = 0
var is_highlighted: bool = false
var extra_servings_per_fill: int = 0
var queued_fill_count: int = 0
var current_drink_item_id: StringName = &""

func _ready() -> void:
	add_to_group("facility_layout_blockers")
	add_to_group("pickup_drop_targets")
	add_to_group("drink_barrels")
	_apply_shape()
	queue_redraw()

func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		_apply_shape()
		queue_redraw()
	else:
		_advance_fill(_delta)

func get_layout_footprint() -> Vector2i:
	return footprint

func get_layout_block_margin_cells() -> int:
	return interaction_block_margin_cells

func is_pickup_drop_focusable(other_player: Node) -> bool:
	if preload("res://Scripts/Facilities/FacilityWorkPause.gd").is_paused(self):
		return true
	return can_take_item(other_player) or can_receive_item(other_player)

func can_take_item(other_player: Node) -> bool:
	if preload("res://Scripts/Facilities/FacilityWorkPause.gd").is_paused(self):
		return false
	if not visible or serving_count <= 0 or current_drink_item_id == &"":
		return false
	if other_player == null or not other_player.has_method("can_pick_up_item"):
		return false
	return other_player.can_pick_up_item(current_drink_item_id, TestItemDefs.PROCESS_STATE_NONE)

func take_item_to_player(other_player: Node) -> bool:
	if not can_take_item(other_player):
		return false
	if not other_player.has_method("pick_up_item"):
		return false
	var picked_up: Variant = other_player.pick_up_item(
		current_drink_item_id,
		TestItemDefs.get_item_texture(current_drink_item_id),
		TestItemDefs.PROCESS_STATE_NONE
	)
	if picked_up is bool and picked_up:
		serving_count = maxi(serving_count - 1, 0)
		_clear_batch_if_empty()
		queue_redraw()
		return true
	return false

func can_receive_item(_other_player: Node) -> bool:
	return _can_insert_input(_other_player)

func receive_item_from_player(other_player: Node) -> bool:
	if not _can_insert_input(other_player):
		return false
	var plate_index: int = _plate_input_index(other_player)
	var input_id: StringName = StringName(Array(CarryItemRules.payload_from(other_player).get("items", []))[plate_index].get("item_id", &"")) if plate_index >= 0 else other_player.get_held_item_id()
	var target_drink_id := TestItemDefs.get_barrel_drink_for_input(input_id)
	if not other_player.has_method("clear_held_item"):
		return false
	if current_drink_item_id == &"":
		current_drink_item_id = target_drink_id
	queued_fill_count += 1
	preload("res://Scripts/Player/UltimateEnergyRules.gd").award(other_player, &"barrel")
	if plate_index >= 0:
		CarryItemRules.remove_plate_portion(other_player, plate_index)
	else:
		other_player.clear_held_item()
	queue_redraw()
	return true

func interact_with_player(other_player: Node) -> bool:
	if _can_insert_input(other_player):
		return receive_item_from_player(other_player)
	return _can_fill(other_player)

func process_hold_interaction(other_player: Node, delta: float) -> bool:
	if not _can_fill(other_player):
		return false
	return true

func get_interaction_progress_data(other_player: Node) -> Dictionary:
	if fill_progress > 0.0 and _can_fill(other_player):
		return {
			"visible": true,
			"progress": fill_progress / maxf(fill_duration, 0.01)
		}
	return {}

func get_interaction_button_prompt(other_player: Node) -> String:
	if preload("res://Scripts/Facilities/FacilityWorkPause.gd").is_paused(self):
		return ""
	if CarryItemRules.is_collecting(other_player) and can_take_item(other_player):
		return "J 装盘"
	if _can_insert_input(other_player):
		return "J PLACE"
	if can_take_item(other_player):
		return "J TAKE"
	return ""

func get_pickup_drop_positions() -> Array[Vector2]:
	return InteractionGeometry.grid_points(global_transform, interaction_area_center, interaction_area_size, interaction_area_columns, interaction_area_rows)

func get_interaction_rect_global() -> Rect2:
	var local_rect := Rect2(interaction_area_center - interaction_area_size * 0.5, interaction_area_size)
	var top_left := to_global(local_rect.position)
	var bottom_right := to_global(local_rect.position + local_rect.size)
	return Rect2(top_left, bottom_right - top_left).abs()

func get_pickup_drop_radius() -> float:
	return pickup_distance

func set_pickup_drop_highlight(active: bool) -> void:
	is_highlighted = active
	modulate = highlight_modulate if active else normal_modulate
	queue_redraw()

func reset_state() -> void:
	fill_progress = 0.0
	serving_count = 0
	queued_fill_count = 0
	current_drink_item_id = &""
	is_highlighted = false
	modulate = normal_modulate
	queue_redraw()

func set_extra_servings_per_fill(amount: int) -> void:
	extra_servings_per_fill = maxi(amount, 0)

func destroy_surface_food() -> void:
	reset_state()

func _can_fill(other_player: Node) -> bool:
	if preload("res://Scripts/Facilities/FacilityWorkPause.gd").is_paused(self):
		return false
	if not visible or serving_count >= max_servings or queued_fill_count <= 0:
		return false
	if other_player != null and other_player.has_method("is_holding_item") and other_player.is_holding_item():
		return false
	return TestItemDefs.is_barrel_drink(current_drink_item_id)

func _advance_fill(delta: float) -> void:
	if preload("res://Scripts/Facilities/FacilityWorkPause.gd").is_paused(self):
		return
	if not _can_fill(null):
		return
	# Brewing bubbles continue throughout the fill instead of only sounding on
	# the completion frame. AudioCue.work applies a cadence so this remains a
	# small number of pooled voices even during long brews.
	AudioCue.work(self, &"brew")
	fill_progress = minf(fill_progress + maxf(delta, 0.0) * _get_nearby_support_fill_multiplier() * UltimateBoost.get_multiplier(self), maxf(fill_duration, 0.01))
	queue_redraw()
	if fill_progress < fill_duration:
		return
	fill_progress = 0.0
	AudioCue.at(self, &"complete", -2.0)
	var total_servings_per_fill: int = maxi(servings_per_fill + extra_servings_per_fill, 1)
	serving_count = mini(serving_count + total_servings_per_fill, maxi(max_servings + extra_servings_per_fill, 1))
	queued_fill_count = maxi(queued_fill_count - 1, 0)
	_clear_batch_if_empty()
	queue_redraw()

func _plate_input_index(other_player: Node) -> int:
	if not CarryItemRules.is_collecting(other_player):
		return -1
	var entries: Array = CarryItemRules.payload_from(other_player).get("items", [])
	for i in range(entries.size()):
		var drink_id: StringName = TestItemDefs.get_barrel_drink_for_input(StringName(entries[i].get("item_id", &"")))
		if drink_id != &"" and (current_drink_item_id == &"" or current_drink_item_id == drink_id) and TestItemDefs.is_raw_state(StringName(entries[i].get("process_state", &""))):
			return i
	return -1

func _can_insert_input(other_player: Node) -> bool:
	if preload("res://Scripts/Facilities/FacilityWorkPause.gd").is_paused(self):
		return false
	if CarryItemRules.is_collecting(other_player):
		return visible and queued_fill_count < 3 and _plate_input_index(other_player) >= 0
	if not visible or other_player == null:
		return false
	if not other_player.has_method("is_holding_item") or not other_player.is_holding_item():
		return false
	if not other_player.has_method("get_held_item_id") or not other_player.has_method("get_held_item_process_state"):
		return false
	var input_id: StringName = other_player.get_held_item_id()
	var target_drink_id := TestItemDefs.get_barrel_drink_for_input(input_id)
	return (
		target_drink_id != &""
		and (current_drink_item_id == &"" or current_drink_item_id == target_drink_id)
		and TestItemDefs.is_raw_state(other_player.get_held_item_process_state())
		and queued_fill_count < 3
	)

func _clear_batch_if_empty() -> void:
	if serving_count <= 0 and queued_fill_count <= 0 and fill_progress <= 0.0:
		current_drink_item_id = &""

func _get_nearby_support_fill_multiplier() -> float:
	return preload("res://Scripts/Core/SupportFacilityAuraQuery.gd").get_work_multiplier(get_tree(), global_position, &"get_barrel_fill_speed_multiplier")

func _apply_shape() -> void:
	var shape := RectangleShape2D.new()
	shape.size = body_size
	if collision_shape != null:
		collision_shape.shape = shape
	if item_blocker_shape != null:
		item_blocker_shape.shape = shape

func _draw() -> void:
	draw_texture_rect(BARREL_TEXTURE, Rect2(Vector2(-body_size.x * 0.5, -72), Vector2(body_size.x, 144)), false)
	var icon: Texture2D = TestItemDefs.get_item_texture(current_drink_item_id)
	if icon != null:
		draw_texture_rect(icon, Rect2(Vector2(-36.0, -38.0), Vector2(64.0, 64.0)), false)
	if serving_count > 0:
		draw_circle(Vector2(40.0, 25.0), 18.0, outline_color)
		draw_circle(Vector2(40.0, 25.0), 15.0, Color("f3dfb0"))
		var font: Font = ThemeDB.fallback_font
		var count_text: String = str(serving_count)
		var text_width: float = font.get_string_size(count_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x
		draw_string(font, Vector2(40.0 - text_width * 0.5, 33.0), count_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, outline_color)
	if queued_fill_count > 0 and _can_fill(null):
		var brew_ratio: float = clampf(fill_progress / maxf(fill_duration, 0.01), 0.0, 1.0)
		var brew_rect := Rect2(Vector2(-body_size.x * 0.38, body_size.y * 0.5 + 10.0), Vector2(body_size.x * 0.76, 10.0))
		draw_rect(brew_rect, outline_color, true)
		draw_rect(Rect2(brew_rect.position + Vector2(2.0, 2.0), Vector2((brew_rect.size.x - 4.0) * brew_ratio, brew_rect.size.y - 4.0)), Color("edc97e"), true)
