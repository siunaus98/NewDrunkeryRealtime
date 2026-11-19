extends Node2D

var boss_owner: Node2D
var radius: float = 110.0
var elapsed: float = 0.0
var emerge_duration: float = 0.18
var hold_duration: float = 0.2
var retract_duration: float = 0.25
var pool_delay: float = 0.45

func _ready() -> void:
	add_to_group("sandworm_tail_strikes")

func _physics_process(delta: float) -> void:
	if not is_instance_valid(boss_owner) or boss_owner.is_dead or boss_owner.is_queued_for_deletion():
		queue_free()
		return
	elapsed += delta
	if elapsed >= emerge_duration + hold_duration + retract_duration + pool_delay:
		if boss_owner.level_refs != null:
			var controller: Node = boss_owner.level_refs.get_quicksand_mechanism_controller()
			if controller != null:
				controller.spawn_tail_quicksand(boss_owner, global_position, radius)
		queue_free()
	queue_redraw()

func _draw() -> void:
	var height_ratio := clampf(elapsed / emerge_duration, 0.0, 1.0)
	if elapsed > emerge_duration + hold_duration:
		height_ratio = 1.0 - clampf((elapsed - emerge_duration - hold_duration) / retract_duration, 0.0, 1.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.35))
	draw_circle(Vector2.ZERO, radius * 0.65, Color("38262a"))
	draw_arc(Vector2.ZERO, radius * 0.8, 0.0, TAU, 32, Color("d4a45b"), 8.0)
	draw_set_transform(Vector2.ZERO)
	if height_ratio <= 0.0:
		return
	# The base stays on the surface; the segmented tail grows upward and retracts.
	var height := 185.0 * height_ratio
	var points := PackedVector2Array([Vector2(-38, 0), Vector2(-32, -height * 0.45), Vector2(-10, -height * 0.85), Vector2(22, -height), Vector2(12, -height * 0.65), Vector2(36, -height * 0.3), Vector2(40, 0)])
	draw_colored_polygon(points, Color("ce984f"))
	points.append(points[0])
	draw_polyline(points, Color("332329"), 7.0, true)
	for i in range(1, 4):
		var y := -height * float(i) * 0.19
		draw_line(Vector2(-25.0 + i * 4.0, y), Vector2(27.0 - i * 3.0, y - 4.0), Color("916043"), 6.0)
	draw_line(Vector2(-6, -height * 0.73), Vector2(19, -height * 0.96), Color("fff0b8"), 6.0)
