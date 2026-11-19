extends Area2D

const InteractionGeometry = preload("res://Scripts/Core/InteractionGeometry.gd")

const TestItemDefs = preload("res://Scripts/Kitchen/TestItemDefs.gd")
const LevelRefs = preload("res://Scripts/Core/LevelRefs.gd")

@export var move_drag: float = 860.0
@export var max_lifetime: float = 18.0
@export var edge_padding: Vector2 = Vector2(24.0, 24.0)
@export var collect_radius: float = 18.0
@export var attract_radius: float = 150.0
@export var attract_speed: float = 360.0
@export var normal_scale: Vector2 = Vector2(0.42, 0.42)
@export var collected_scale: Vector2 = Vector2(0.55, 0.55)

@onready var sprite: Sprite2D = $Sprite2D

var item_id: StringName = &""
var velocity: Vector2 = Vector2.ZERO
var movement_bounds: Rect2 = Rect2()
var lifetime_remaining: float = 0.0
var storage_manager: Node
var player: Node2D
var level_refs: LevelRefs
var is_collected: bool = false
var attract_range_multiplier: float = 1.0

func _ready() -> void:
	add_to_group("battle_drops")
	lifetime_remaining = max_lifetime
	_resolve_storage_manager()
	_resolve_player()
	_refresh_visual()

func _physics_process(delta: float) -> void:
	if is_collected:
		return

	lifetime_remaining = maxf(lifetime_remaining - delta, 0.0)
	if lifetime_remaining <= 0.0:
		queue_free()
		return

	global_position += velocity * delta
	velocity = velocity.move_toward(Vector2.ZERO, move_drag * delta)
	_apply_player_attraction(delta)
	_clamp_to_bounds()
	_try_collect_with_player_capsule()

func setup_drop(new_item_id: StringName, new_velocity: Vector2, new_bounds: Rect2, new_attract_range_multiplier: float = 1.0) -> void:
	item_id = new_item_id
	velocity = new_velocity
	movement_bounds = new_bounds
	attract_range_multiplier = maxf(new_attract_range_multiplier, 1.0)
	_refresh_visual()

func _resolve_storage_manager() -> void:
	level_refs = LevelRefs.find_from(self)
	if level_refs != null:
		storage_manager = level_refs.get_storage_manager()

func _resolve_player() -> void:
	var found_player: Node = get_tree().get_first_node_in_group("player")
	if found_player is Node2D:
		player = found_player

func _refresh_visual() -> void:
	if not is_instance_valid(sprite):
		return

	sprite.texture = TestItemDefs.get_item_texture(item_id)
	sprite.modulate = TestItemDefs.get_item_modulate(TestItemDefs.PROCESS_STATE_NONE, item_id)
	sprite.scale = normal_scale if not is_collected else collected_scale

func _clamp_to_bounds() -> void:
	if movement_bounds.size.x <= 0.0 or movement_bounds.size.y <= 0.0:
		return

	var min_pos: Vector2 = movement_bounds.position + edge_padding
	var max_pos: Vector2 = movement_bounds.position + movement_bounds.size - edge_padding
	var clamped_position: Vector2 = global_position.clamp(min_pos, max_pos)
	if clamped_position == global_position:
		return

	if not is_equal_approx(clamped_position.x, global_position.x):
		velocity.x *= -0.22
	if not is_equal_approx(clamped_position.y, global_position.y):
		velocity.y *= -0.22
	global_position = clamped_position

func _try_collect_with_player_capsule() -> void:
	if is_collected:
		return
	if not is_instance_valid(player):
		_resolve_player()
	if not is_instance_valid(player):
		return
	if not player.has_method("get_item_push_capsule_data"):
		return

	var capsule: Variant = player.get_item_push_capsule_data()
	if not (capsule is Dictionary) or capsule.is_empty():
		return

	var capsule_top: Vector2 = capsule.get("top", Vector2.ZERO)
	var capsule_bottom: Vector2 = capsule.get("bottom", Vector2.ZERO)
	var capsule_radius: float = float(capsule.get("radius", 0.0))
	var closest_point: Vector2 = InteractionGeometry.closest_point_on_segment(global_position, capsule_top, capsule_bottom)
	var contact_distance: float = capsule_radius + collect_radius
	if global_position.distance_to(closest_point) > contact_distance:
		return

	_collect_into_storage()

func _apply_player_attraction(delta: float) -> void:
	if not is_instance_valid(player):
		_resolve_player()
	if not is_instance_valid(player):
		return
	var target_position: Vector2 = player.global_position
	if player.has_method("get_sort_origin"):
		target_position = player.get_sort_origin()
	var to_player := target_position - global_position
	if to_player.length_squared() <= 0.001 or to_player.length() > attract_radius * attract_range_multiplier:
		return
	velocity = velocity.move_toward(to_player.normalized() * attract_speed, attract_speed * 4.0 * maxf(delta, 0.0))

func _collect_into_storage() -> void:
	if storage_manager == null or not is_instance_valid(storage_manager):
		_resolve_storage_manager()

	if storage_manager != null and storage_manager.has_method("add_stock"):
		storage_manager.add_stock(item_id, 1, &"fresh")

	is_collected = true
	monitoring = false
	set_deferred("monitoring", false)
	visible = false
	queue_free()
