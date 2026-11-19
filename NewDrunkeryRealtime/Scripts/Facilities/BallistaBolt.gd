extends Node2D

const AudioCue = preload("res://Scripts/Audio/AudioCue.gd")

var direction := Vector2.RIGHT
var damage := 180
var life := 3.0
var ignored: Array[RID] = []

func _physics_process(delta: float) -> void:
	var end := global_position + direction * 850 * delta
	var query := PhysicsRayQueryParameters2D.create(global_position, end, 1 | 2 | 4 | 16, ignored)
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		AudioCue.at(self, &"impact", -7.0)
		var target: Node = hit.collider
		if target.has_method("take_damage"):
			target.take_damage(damage, direction, &"ballista")
		elif target.has_method("receive_hit"):
			target.receive_hit(damage, direction)
		queue_free()
		return
	global_position = end
	life -= delta
	if life <= 0:
		queue_free()
	queue_redraw()

func _draw() -> void:
	draw_line(-direction * 30, direction * 14, Color("513420"), 9)
	draw_line(-direction * 28, direction * 12, Color("d8b87a"), 4)
	draw_colored_polygon(PackedVector2Array([direction * 28, direction * 10 + direction.orthogonal() * 8, direction * 10 - direction.orthogonal() * 8]), Color("bad3cc"))
