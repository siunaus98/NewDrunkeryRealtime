extends Node2D

## Ordinary actor presentation only. Boss animation remains in its controllers.
var actor: CharacterBody2D
var sprite: Sprite2D
var origin: Vector2
var phase: float = 0.0

static func attach(host: Node) -> void:
	if host.get_node_or_null("EnemyPresentation") != null or not host is CharacterBody2D:
		return
	var effect: Node2D = load("res://Scripts/Enemies/EnemyPresentation.gd").new()
	effect.name = "EnemyPresentation"
	effect.actor = host
	effect.sprite = host.get_node_or_null("Sprite2D")
	if effect.sprite == null:
		return
	effect.origin = effect.sprite.offset
	effect.z_index = -1
	host.add_child(effect)

func _process(delta: float) -> void:
	if not is_instance_valid(actor) or not is_instance_valid(sprite):
		return
	if not actor.is_processing() or not actor.is_physics_processing():
		return
	phase += delta
	# Hit and attack controllers own their transformations while active.
	var feedback: Tween = actor.get("feedback_tween")
	if feedback != null and feedback.is_running():
		sprite.offset = origin
		return
	var state: Variant = actor.get("attack_state")
	if state != null and int(state) != 0:
		sprite.offset = origin
		return
	var moving: bool = actor.velocity.length_squared() > 100
	# Offset belongs to presentation; position remains owned by hit/attack tweens.
	var bob: float = -absf(sin(phase * 9.0)) * 3.5 if moving else sin(phase * 2.3) * 1.3
	sprite.offset = origin + Vector2(0, bob / maxf(absf(sprite.scale.y), 0.001))

func _draw() -> void:
	if sprite == null or sprite.texture == null:
		return
	var extent := sprite.get_rect().size * sprite.scale.abs()
	var center := sprite.position + Vector2(0, extent.y * 0.36)
	draw_set_transform(center, 0, Vector2(1, 0.28))
	draw_circle(Vector2.ZERO, extent.x * 0.37, Color(0.18, 0.16, 0.12, 0.16))
	draw_circle(Vector2.ZERO, extent.x * 0.25, Color(0.18, 0.16, 0.12, 0.1))
	draw_set_transform(Vector2.ZERO)
