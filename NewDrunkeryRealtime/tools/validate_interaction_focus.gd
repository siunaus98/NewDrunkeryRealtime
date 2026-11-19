extends SceneTree

const Query = preload("res://Scripts/Player/InteractionFocusQuery.gd")
const Controller = preload("res://Scripts/Player/PlayerInteractionController.gd")
const Items = preload("res://Scripts/Kitchen/TestItemDefs.gd")
var failures: int = 0

class FocusPlayer extends CharacterBody2D:
	func get_held_item_id() -> StringName: return &""

class PointTarget extends Node2D:
	var points: Array = []
	var take: bool = true
	var receive: bool = false
	var radius: float = 200.0
	var custom_radius: float = 0.0
	var highlighted: bool = false
	func can_take_item(_player: Node) -> bool: return take
	func can_receive_item(_player: Node) -> bool: return receive
	func get_pickup_drop_radius() -> float: return radius
	func get_player_interaction_radius() -> float: return custom_radius
	func get_pickup_drop_positions() -> Array: return points
	func set_pickup_drop_highlight(active: bool) -> void: highlighted = active

class RectTarget extends PointTarget:
	var rect: Rect2 = Rect2(80, -10, 20, 20)
	func get_interaction_rect_global() -> Rect2: return rect

class CustomTarget extends RectTarget:
	var data: Dictionary = {"valid": true, "distance": 60.0, "angle": 0.0, "slot_index": 2}
	var focused: Dictionary = {}
	func evaluate_pickup_drop_focus(_player: Node, _origin: Vector2, _aim: Vector2, _radius: float, _angle: float) -> Dictionary: return data
	func set_pickup_drop_focus_data(_player: Node, value: Dictionary) -> void: focused = value

func _initialize() -> void:
	call_deferred("_run")

func _check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func _select(player: CharacterBody2D, candidates: Array, holding: bool = false) -> Dictionary:
	return Query.select_target(player, candidates, holding, Vector2.ZERO, Vector2.RIGHT, 100.0, PI / 4.0)

func _run() -> void:
	var player := FocusPlayer.new()
	root.add_child(player)
	var near := PointTarget.new()
	near.points = [Vector2(50, 20)]
	var far := PointTarget.new()
	far.points = [Vector2(80, 0)]
	root.add_child(near)
	root.add_child(far)
	_check(_select(player, [far, near]).get("target") == near, "Distance takes priority over aim alignment.")
	near.points = [Vector2(80, 0).rotated(0.2)]
	_check(_select(player, [near, far]).get("target") == far, "Equal distances use aim alignment.")
	near.points = far.points
	_check(_select(player, [near, far]).get("target") == near, "Exact ties retain candidate order.")
	near.visible = false
	_check(_select(player, [near, far]).get("target") == far, "Hidden targets are excluded.")
	near.visible = true
	near.receive = true
	_check(_select(player, [far, near], true).get("target") == near, "Fallback eligibility follows held-item state.")
	near.points = [Vector2(120, 0)]
	_check(_select(player, [near]).is_empty(), "Default player radius limits selection.")
	near.custom_radius = 150.0
	_check(_select(player, [near]).get("target") == near, "Positive custom radius overrides player radius.")
	near.radius = 110.0
	_check(_select(player, [near]).is_empty(), "Facility radius still caps custom radius.")
	near.points = [Vector2(-40, 0)]
	_check(_select(player, [near]).is_empty(), "Points behind aim are excluded.")
	near.points = [Vector2.ZERO]
	var custom := CustomTarget.new()
	root.add_child(custom)
	_check(_select(player, [custom, near]).get("target") == near, "Coincident point remains an immediate winner.")
	var result: Dictionary = _select(player, [custom, far])
	_check(result.get("focus_data") == custom.data and custom.focused.is_empty() and not custom.highlighted, "Query preserves slot metadata without committing focus.")
	custom.data = {}
	_check(_select(player, [custom]).is_empty(), "Invalid custom focus must not fall back to its rectangle.")
	var rect := RectTarget.new()
	root.add_child(rect)
	_check(_select(player, [rect]).get("target") == rect, "Rectangle nearest edge is selectable.")
	var wall := StaticBody2D.new()
	wall.collision_layer = 4
	wall.position = Vector2(40, 0)
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(10, 80)
	shape.shape = box
	wall.add_child(shape)
	root.add_child(wall)
	await physics_frame
	await physics_frame
	_check(_select(player, [rect]).is_empty(), "Obstacle blocks rectangle focus.")
	wall.reparent(rect)
	_check(_select(player, [rect]).get("target") == rect, "Candidate's own collision children do not block focus.")
	wall.queue_free()
	custom.data = {"valid": true, "distance": 60.0, "angle": 0.0, "slot_index": 2}
	custom.add_to_group("pickup_drop_targets")
	var controller := Controller.new()
	controller.player = player
	controller.update_current_interaction_target(Vector2.ZERO, Vector2.RIGHT, 100.0, 90.0, 60.0)
	_check(controller.get_current_interaction_target() == custom and custom.highlighted and custom.focused.get("slot_index") == 2, "Controller commits target, highlight and slot together.")
	custom.visible = false
	controller.update_current_interaction_target(Vector2.ZERO, Vector2.RIGHT, 100.0, 90.0, 60.0)
	_check(controller.get_current_interaction_target() == null and not custom.highlighted and custom.focused.is_empty(), "Losing eligibility clears highlight and slot data.")
	custom.visible = true
	controller.update_current_interaction_target(Vector2.ZERO, Vector2.RIGHT, 100.0, 90.0, 60.0)
	custom.queue_free()
	await process_frame
	_check(controller.get_current_interaction_target() == null and controller.current_interaction_focus_data.is_empty(), "Deleted targets clear weak references and focus data.")
	for node in [near, far, rect, player]:
		node.queue_free()
	await process_frame
	if failures == 0:
		print("PASS: focus ordering, eligibility, radius, point/rectangle/custom precedence, physics occlusion, slot metadata and focus lifecycle.")
	quit(0 if failures == 0 else 1)
