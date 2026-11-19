extends Node2D

## A non-solid, temporary offering space. Inventory remains recoverable until
## the preparation deadline; captured food belongs to the tongue afterward.
const Food = preload("res://Scripts/Enemies/MonitorFoodAccess.gd")
const Cargo = preload("res://Scripts/Facilities/FacilityItems.gd")
var stored: Dictionary = {}
var head: Node2D
var locked := false
var highlighted := false
var icon: Sprite2D

func _ready() -> void:
	add_to_group("pickup_drop_targets")
	add_to_group("facility_layout_blockers")
	add_to_group("monitor_feeding_spots")
	z_index = 4
	icon = Sprite2D.new()
	icon.position.y = -12
	icon.scale = Vector2.ONE * 0.75
	add_child(icon)

func _process(_delta: float) -> void:
	icon.visible = not stored.is_empty()
	if not stored.is_empty():
		icon.texture = Food.Items.get_world_item_texture(StringName(stored.item_id), stored.get("payload", {}))
		icon.modulate = Food.Items.get_item_modulate(StringName(stored.get("process_state", &"")))
	queue_redraw()

func get_monitor_food_entries() -> Array:
	return [] if stored.is_empty() else [stored]

func set_monitor_food(_slot: int, item: Dictionary) -> void:
	stored = item

func is_pickup_drop_focusable(_player: Node) -> bool:
	return not locked

func can_receive_item(player: Node) -> bool:
	return not locked and stored.is_empty() and Food.edible(Cargo.held(player))

func receive_item_from_player(player: Node) -> bool:
	if not can_receive_item(player):
		return false
	stored = Cargo.held(player)
	player.clear_held_item()
	return true

func can_take_item(player: Node) -> bool:
	return not locked and not stored.is_empty() and player.can_pick_up_item(StringName(stored.item_id), StringName(stored.get("process_state", &"")), stored.get("payload", {}))

func take_item_to_player(player: Node) -> bool:
	if not can_take_item(player) or not Cargo.give(player, stored):
		return false
	if Cargo.Carry.take_leaves_box(player, StringName(stored.item_id), stored.get("payload", {})):
		stored.payload.servings = int(stored.payload.servings) - 1
	else:
		stored = {}
	return true

func get_interaction_rect_global() -> Rect2:
	return Rect2(global_position - Vector2(52, 52), Vector2(104, 104))

func get_pickup_drop_radius() -> float:
	return 170.0

func get_layout_block_margin_cells() -> int:
	return 0

func get_layout_footprint() -> Vector2i:
	return Vector2i.ONE

func set_pickup_drop_highlight(value: bool) -> void:
	highlighted = value
	queue_redraw()

func get_interaction_button_prompt(player: Node) -> String:
	if locked:
		return "投喂已结算"
	if can_receive_item(player):
		return "J 放入投喂物"
	return "J 取回投喂物" if can_take_item(player) else "放入食材或菜品 · 空缺会激怒巨蜥"

func release_food() -> void:
	if not stored.is_empty():
		Cargo.drop(get_parent(), global_position, stored)
		stored = {}

func _draw() -> void:
	var color := Color("f4ce75") if not stored.is_empty() else Color("ef907d")
	draw_rect(Rect2(-57, -57, 114, 114), Color(color, 0.23 if highlighted else 0.12))
	draw_rect(Rect2(-57, -57, 114, 114), color, false, 4, true)
	var progress: float = head.remaining / maxf(head.lock_duration, 0.01) if is_instance_valid(head) else 0.0
	draw_arc(Vector2.ZERO, 48, -PI / 2, -PI / 2 + TAU * clampf(progress, 0, 1), 40, color, 5, true)
	var text := "投喂 %d秒" % ceili(head.remaining) if is_instance_valid(head) and not locked else ""
	var at := Vector2(-ThemeDB.fallback_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 23).x / 2, -70)
	draw_string_outline(ThemeDB.fallback_font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 23, 5, Color("513420"))
	draw_string(ThemeDB.fallback_font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 23, Color("fff0b2"))
