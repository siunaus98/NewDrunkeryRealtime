@tool
extends StaticBody2D

const LevelRefs = preload("res://Scripts/Core/LevelRefs.gd")

const TYPE_CONVEYOR: StringName = &"conveyor"
const TYPE_LAMP: StringName = &"lamp"

@export var facility_type: StringName = TYPE_CONVEYOR
@export var display_name: String = "支援设施"
@export var footprint: Vector2i = Vector2i(1, 1)
@export var body_size: Vector2 = Vector2(104.0, 104.0)
@export var pickup_distance: float = 132.0
@export var aura_radius: float = 280.0
@export var movement_speed_multiplier: float = 1.18
@export var conveyor_speed: float = 230.0
@export var cook_speed_multiplier: float = 1.2
@export var base_color: Color = Color(0.42, 0.36, 0.28, 1.0)
@export var accent_color: Color = Color(0.95, 0.72, 0.28, 1.0)
@export var aura_color: Color = Color(0.8, 0.9, 1.0, 0.16)
@export var outline_color: Color = Color(0.08, 0.055, 0.035, 1.0)
@export var highlight_modulate: Color = Color(1.18, 1.14, 0.92, 1.0)
@export var show_aura: bool = true
@export var conveyor_direction: int = 1

@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var item_blocker_shape: CollisionShape2D = $ItemBlocker/CollisionShape2D

var is_highlighted: bool = false
var is_carried: bool = false
var aura_multiplier: float = 1.0
var art_sprite: Sprite2D
var art_type: StringName = &""

func _ready() -> void:
	add_to_group("support_facilities")
	add_to_group("movable_facilities")
	add_to_group("pickup_drop_targets")
	add_to_group("table_facilities")
	add_to_group("facility_layout_blockers")
	if facility_type == TYPE_CONVEYOR:
		add_to_group("conveyor_facilities")
	_apply_shape()
	art_sprite = Sprite2D.new()
	add_child(art_sprite)
	_refresh_art()
	_apply_visual_state()
	queue_redraw()

func _refresh_art() -> void:
	if art_sprite == null:
		return
	var art_path := "res://ArtResource/Facilities/%s.svg" % facility_type
	if art_type != facility_type and ResourceLoader.exists(art_path):
		art_sprite.texture = load(art_path)
		art_type = facility_type
		art_sprite.position.y = -14
	art_sprite.flip_h = facility_type == TYPE_CONVEYOR and conveyor_direction < 0

func _process(delta: float) -> void:
	_refresh_art()
	if Engine.is_editor_hint():
		_apply_shape()
	elif facility_type == TYPE_CONVEYOR and not is_carried:
		_apply_conveyor_motion(delta)
	_apply_visual_state()
	queue_redraw()

func can_be_moved_by_player(_other_player: Node) -> bool:
	return visible

func is_pickup_drop_focusable(_other_player: Node) -> bool:
	return visible

func can_take_item(_other_player: Node) -> bool:
	return false

func can_receive_item(_other_player: Node) -> bool:
	return false

func get_interaction_button_prompt(_other_player: Node) -> String:
	return "K 搬起"

func set_facility_carried(active: bool) -> void:
	is_carried = active
	_apply_shape()
	queue_redraw()

func rotate_carried_facility() -> void:
	if facility_type != TYPE_CONVEYOR:
		return
	conveyor_direction *= -1
	_refresh_art()
	queue_redraw()

func get_layout_footprint() -> Vector2i:
	return footprint

func get_pickup_drop_radius() -> float:
	return pickup_distance

func get_pickup_drop_positions() -> Array[Vector2]:
	return [global_position]

func get_interaction_rect_global() -> Rect2:
	return Rect2(global_position - body_size * 0.5, body_size)

func set_pickup_drop_highlight(active: bool) -> void:
	is_highlighted = active
	_apply_visual_state()
	queue_redraw()

func get_support_facility_type() -> StringName:
	return facility_type

func get_support_aura_radius() -> float:
	return aura_radius * aura_multiplier

func set_aura_multiplier(multiplier: float) -> void:
	aura_multiplier = maxf(multiplier, 0.01)
	queue_redraw()

func get_movement_speed_multiplier() -> float:
	return 1.0

func get_cook_speed_multiplier() -> float:
	return cook_speed_multiplier if facility_type == TYPE_LAMP else 1.0

func get_barrel_fill_speed_multiplier() -> float:
	return cook_speed_multiplier if facility_type == TYPE_LAMP else 1.0

func reset_state() -> void:
	is_highlighted = false
	is_carried = false
	_apply_visual_state()
	queue_redraw()

func _apply_shape() -> void:
	if facility_type == TYPE_CONVEYOR:
		footprint = Vector2i(2, 1)
		body_size = Vector2(244.0, 104.0)
	var shape := RectangleShape2D.new()
	shape.size = body_size
	if collision_shape != null:
		collision_shape.shape = shape
		collision_shape.disabled = facility_type == TYPE_CONVEYOR and not is_carried
	if item_blocker_shape != null:
		item_blocker_shape.shape = shape
		item_blocker_shape.disabled = facility_type == TYPE_CONVEYOR and not is_carried

func _apply_visual_state() -> void:
	modulate = highlight_modulate if is_highlighted else Color.WHITE

func _draw() -> void:
	if show_aura and not is_carried and facility_type != TYPE_CONVEYOR:
		var effective_aura_radius: float = get_support_aura_radius()
		draw_circle(Vector2.ZERO, effective_aura_radius, aura_color)
		draw_arc(Vector2.ZERO, effective_aura_radius, 0.0, TAU, 48, Color(aura_color.r, aura_color.g, aura_color.b, minf(aura_color.a * 2.6, 0.55)), 4.0, true)

	if art_sprite != null and art_sprite.texture != null:
		return
	var rect := Rect2(-body_size * 0.5, body_size)
	draw_rect(rect, outline_color, true)
	draw_rect(rect.grow(-8.0), base_color, true)

	match facility_type:
		TYPE_CONVEYOR:
			_draw_conveyor(rect)
		TYPE_LAMP:
			_draw_lamp(rect)
		_:
			draw_rect(rect.grow(-24.0), accent_color, true)

func _draw_conveyor(rect: Rect2) -> void:
	var belt_rect := Rect2(rect.position + Vector2(14.0, 22.0), Vector2(rect.size.x - 28.0, rect.size.y - 44.0))
	draw_rect(belt_rect, accent_color.darkened(0.35), true)
	var roller_count: int = 7
	for x in range(roller_count):
		var center_x := belt_rect.position.x + 16.0 + float(x) * ((belt_rect.size.x - 32.0) / float(maxi(roller_count - 1, 1)))
		draw_circle(Vector2(center_x, 0.0), 9.0, outline_color)
		draw_circle(Vector2(center_x, 0.0), 4.5, accent_color)
	var direction_sign: float = -1.0 if conveyor_direction < 0 else 1.0
	draw_colored_polygon([
		Vector2(62.0 * direction_sign, -26.0),
		Vector2(98.0 * direction_sign, 0.0),
		Vector2(62.0 * direction_sign, 26.0),
		Vector2(68.0 * direction_sign, 8.0),
		Vector2(-88.0 * direction_sign, 8.0),
		Vector2(-88.0 * direction_sign, -8.0),
		Vector2(68.0 * direction_sign, -8.0)
	], accent_color)

func _apply_conveyor_motion(delta: float) -> void:
	var direction_sign: float = -1.0 if conveyor_direction < 0 else 1.0
	var motion: Vector2 = Vector2(direction_sign * conveyor_speed * maxf(delta, 0.0), 0.0)
	if motion.length_squared() <= 0.000001:
		return
	var belt_rect: Rect2 = get_conveyor_rect_global()
	for player_node in get_tree().get_nodes_in_group("player"):
		if player_node is Node2D and belt_rect.has_point((player_node as Node2D).global_position):
			if player_node.has_method("apply_conveyor_motion"):
				player_node.apply_conveyor_motion(motion * preload("res://Scripts/Core/SupportFacilityAuraQuery.gd").get_cook_multiplier(get_tree(), player_node.global_position))
	for item in get_tree().get_nodes_in_group("pushable_items"):
		if item is Node2D and belt_rect.has_point((item as Node2D).global_position):
			if item.has_method("apply_conveyor_motion"):
				item.apply_conveyor_motion(motion * preload("res://Scripts/Core/SupportFacilityAuraQuery.gd").get_cook_multiplier(get_tree(), item.global_position))

func get_conveyor_rect_global() -> Rect2:
	return Rect2(global_position - body_size * 0.5, body_size)

func get_facility_preview_data() -> Dictionary:
	return {
		"body_size": body_size,
		"base_color": base_color,
		"accent_color": accent_color,
		"outline_color": outline_color,
		"facility_type": facility_type
	}

func _draw_lamp(rect: Rect2) -> void:
	draw_rect(Rect2(Vector2(-8.0, -8.0), Vector2(16.0, 54.0)), outline_color, true)
	draw_rect(Rect2(Vector2(-4.0, -4.0), Vector2(8.0, 48.0)), accent_color.darkened(0.25), true)
	draw_colored_polygon([
		Vector2(-34.0, -36.0),
		Vector2(34.0, -36.0),
		Vector2(48.0, 6.0),
		Vector2(-48.0, 6.0)
	], outline_color)
	draw_colored_polygon([
		Vector2(-26.0, -28.0),
		Vector2(26.0, -28.0),
		Vector2(36.0, -2.0),
		Vector2(-36.0, -2.0)
	], accent_color)
	draw_rect(Rect2(Vector2(-34.0, 42.0), Vector2(68.0, 12.0)), outline_color, true)

