extends SceneTree

const ZoneQuery = preload("res://Scripts/Core/ZoneInteractionQuery.gd")
var failures: int = 0

class FakeMap extends Node:
	var zones: Dictionary = {}

	func get_zone_for_point(point: Vector2) -> StringName:
		return StringName(zones.get(point, &"none"))

	func can_zones_interact(zone_a: StringName, zone_b: StringName) -> bool:
		if zone_a == &"none" or zone_b == &"none":
			return true
		return zone_a == zone_b

class FakeTarget extends Node2D:
	var sort_origin: Vector2 = Vector2.ZERO

	func get_sort_origin() -> Vector2:
		return sort_origin

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func _init() -> void:
	var map := FakeMap.new()
	map.zones[Vector2.ZERO] = &"battle"
	map.zones[Vector2.RIGHT] = &"battle"
	map.zones[Vector2.DOWN] = &"kitchen"
	map.zones[Vector2.LEFT] = &"none"
	_check(ZoneQuery.can_points_interact(map, Vector2.ZERO, Vector2.RIGHT), "Points in the same zone must interact.")
	_check(not ZoneQuery.can_points_interact(map, Vector2.ZERO, Vector2.DOWN), "Battle and kitchen points must remain separated.")
	_check(ZoneQuery.can_points_interact(map, Vector2.ZERO, Vector2.LEFT), "None-zone fallback must remain interactable.")
	var target := FakeTarget.new()
	target.global_position = Vector2(50, 50)
	target.sort_origin = Vector2(12, 34)
	_check(ZoneQuery.get_node_point(target) == Vector2(12, 34), "Targets with sort origins must use that origin.")
	_check(ZoneQuery.get_node_point(null) == Vector2.ZERO, "Missing targets must return a safe zero point.")
	var no_map := Node.new()
	_check(ZoneQuery.can_points_interact(no_map, Vector2.ZERO, Vector2.ONE), "Maps without zone queries must allow interaction.")
	target.free()
	map.free()
	no_map.free()
	if failures == 0:
		print("PASS: shared zone interaction query preserves same-zone, cross-zone, none-zone and fallback behavior.")
	quit(0 if failures == 0 else 1)
