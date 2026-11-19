extends Node2D

var owner_player: Node
var is_trail: bool = false
var active: bool = true
var remaining: float = 0.0
var duration: float = 1.0
var speed_bonus: float = 0.0
var radius: float = 320.0
var trail_width: float = 96.0
var segments: Array[PackedVector2Array] = []

func _ready() -> void:
	add_to_group("small_skill_fields")
	# The map paints its floor at z=0; draw after it and below raised sprites.
	z_index = 0

func _process(delta: float) -> void:
	if not is_instance_valid(owner_player):
		queue_free()
		return
	if not owner_player.is_skill_gameplay_active():
		return
	if active:
		remaining = maxf(remaining - delta, 0.0)
		if remaining <= 0.0:
			queue_free()
	queue_redraw()

func activate_trail(lifetime: float) -> void:
	active = true
	duration = lifetime
	remaining = lifetime
	queue_redraw()

func add_motion(from: Vector2, to: Vector2) -> void:
	if from.distance_squared_to(to) < 0.01:
		return
	var a: Vector2 = to_local(from)
	var b: Vector2 = to_local(to)
	if not segments.is_empty():
		var last: PackedVector2Array = segments.back()
		var direction: Vector2 = (last[1] - last[0]).normalized()
		if last[1].distance_to(a) < 0.1 and direction.dot((b - a).normalized()) > 0.999:
			segments[segments.size() - 1] = PackedVector2Array([last[0], b])
			return
	segments.append(PackedVector2Array([a, b]))
	queue_redraw()

func get_bonus_at(point: Vector2) -> float:
	if not active or remaining <= 0.0 or is_queued_for_deletion():
		return 0.0
	var local_point: Vector2 = to_local(point)
	if not is_trail:
		if local_point.length_squared() > radius * radius:
			return 0.0
		return speed_bonus
	for segment: PackedVector2Array in segments:
		if local_point.distance_squared_to(Geometry2D.get_closest_point_to_segment(local_point, segment[0], segment[1])) <= trail_width * trail_width * 0.25:
			return speed_bonus
	return 0.0

static func get_movement_bonus(player: Node2D) -> float:
	var bonus: float = 0.0
	for field: Node in player.get_tree().get_nodes_in_group("small_skill_fields"):
		bonus = maxf(bonus, float(field.get_bonus_at(player.global_position)))
	return bonus

func _draw() -> void:
	var alpha: float = minf(remaining, 1.0) if active else 0.45
	var color: Color = Color(0.3, 0.88, 0.9, 0.22 * alpha) if active else Color(0.75, 0.76, 0.6, 0.16)
	var edge: Color = Color(0.55, 1.0, 0.95, 0.65 * alpha) if active else Color(0.85, 0.84, 0.6, 0.35)
	if not is_trail:
		draw_circle(Vector2.ZERO, radius, color)
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 80, edge, 3.0, true)
		draw_arc(Vector2.ZERO, radius - 9, 0.0, TAU, 80, Color(edge, edge.a * 0.35), 1.5, true)
		for index in range(12):
			var angle: float = float(index) * TAU / 12 + remaining * 0.12
			var at := Vector2.RIGHT.rotated(angle) * (radius - 18)
			draw_circle(at, 2.3, Color(edge, edge.a * 0.8))
		return
	for segment: PackedVector2Array in segments:
		draw_line(segment[0], segment[1], edge, trail_width + 3.0, true)
		draw_line(segment[0], segment[1], color, trail_width, true)
