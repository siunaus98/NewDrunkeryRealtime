extends Node2D

var kind: StringName = &"sting"
var direction: Vector2 = Vector2.RIGHT
var radius: float = 180.0
var duration: float = 0.55
var elapsed: float = 0.0

func _ready() -> void:
	z_index = 6
	add_to_group("scorpion_skill_effects")
	if kind == &"summon":
		duration = 1.0

func _process(delta: float) -> void:
	elapsed += delta
	if elapsed >= duration:
		queue_free()
	queue_redraw()

func _draw() -> void:
	var progress := clampf(elapsed / duration, 0.0, 1.0)
	var gold := Color(1.0, 0.81, 0.35, 1.0 - progress)
	var light := Color(1.0, 0.96, 0.75, 1.0 - progress)
	match kind:
		&"bite":
			var tip := direction * radius
			for side in [-1, 1]:
				var jaw := direction.rotated(side * 0.75 * (1.0 - progress)) * radius
				draw_line(direction * 60.0, jaw, gold, 12.0 * (1.0 - progress) + 2.0, true)
				draw_line(jaw, tip, light, 5.0, true)
			for i in range(4):
				var point := direction * radius * (0.35 + i * 0.18)
				draw_line(point - direction.orthogonal() * 18, point + direction.orthogonal() * 18, gold, 4.0, true)
		&"sting":
			var tip := direction * radius
			var side := direction.orthogonal() * 22.0 * (1.0 - progress)
			draw_colored_polygon(PackedVector2Array([direction * 65.0 - side, tip, direction * 65.0 + side]), gold)
			draw_line(direction * 70.0, tip, light, 6.0, true)
			for i in range(3):
				var point := direction * (radius * (0.45 + i * 0.2))
				draw_line(point - direction.orthogonal() * 24.0, point + direction.orthogonal() * 24.0, gold, 4.0, true)
		&"sweep":
			var angle := direction.angle() - 1.3 + progress * 2.6
			draw_arc(Vector2.ZERO, radius, angle - 0.85, angle, 28, gold, 24.0 * (1.0 - progress) + 2.0, true)
			draw_arc(Vector2.ZERO, radius - 20.0, angle - 0.7, angle, 28, light, 5.0, true)
			draw_line(Vector2.RIGHT.rotated(angle) * 90.0, Vector2.RIGHT.rotated(angle) * radius, gold, 10.0, true)
		&"leap", &"emerge":
			draw_arc(Vector2.ZERO, radius * (0.25 + progress * 0.75), 0.0, TAU, 48, gold, 9.0 * (1.0 - progress) + 2.0, true)
			for i in range(12):
				var radial := Vector2.RIGHT.rotated(i * TAU / 12.0)
				draw_line(radial * radius * 0.2, radial * radius * (0.5 + progress * 0.5), gold, 4.0, true)
				draw_circle(radial * radius * (0.55 + progress * 0.45), 6.0 + progress * 12.0, Color(0.77, 0.55, 0.3, (1.0 - progress) * 0.7))
		&"summon":
			draw_arc(Vector2.ZERO, radius * (0.6 + progress * 0.4), 0.0, TAU, 48, Color(0.82, 0.45, 1.0, 1.0 - progress), 9.0, true)
			for i in range(4):
				var point := Vector2.RIGHT.rotated(i * TAU / 4.0) * radius
				draw_circle(point, 12.0, gold)
				for side in [-1, 1]:
					for leg in range(3):
						var offset := Vector2(side * 10, (leg - 1) * 7)
						draw_line(point + offset, point + offset + Vector2(side * 10, 5), gold, 3.0, true)
