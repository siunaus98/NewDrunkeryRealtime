extends Node2D

var remaining: float = 0.22
var direction := Vector2.RIGHT

static func emit_at(actor: Node2D, hit_direction: Vector2) -> void:
	if actor.get_parent() == null:
		return
	var effect: Node2D = load("res://Scripts/Enemies/HitSpark.gd").new()
	effect.direction = hit_direction.normalized() if hit_direction.length_squared() > 0.01 else Vector2.RIGHT
	actor.get_parent().add_child(effect)
	effect.global_position = actor.get_hit_position() if actor.has_method("get_hit_position") else actor.global_position
	effect.z_index = 18

func _process(delta: float) -> void:
	remaining -= delta
	if remaining <= 0:
		queue_free()
	else:
		queue_redraw()

func _draw() -> void:
	var t: float = 1.0 - remaining / 0.22
	var gold := Color(1, 0.82, 0.48, 1 - t)
	var light := Color(1, 0.97, 0.8, 1 - t)
	for index in range(7):
		var ray := direction.rotated(float(index) * TAU / 7)
		var reach: float = 16 + float(index % 3) * 8
		draw_line(ray * (5 + t * reach), ray * (11 + t * reach * 1.5), light if index % 2 == 0 else gold, 2.8 * (1 - t) + 0.5, true)
	draw_arc(Vector2.ZERO, 7 + 22 * t, 0, TAU, 32, Color(gold, (1 - t) * 0.45), 2, true)
