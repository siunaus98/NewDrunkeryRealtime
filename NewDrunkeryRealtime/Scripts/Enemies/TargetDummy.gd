extends Node2D

@export var max_health: int = 50
@export var hit_radius: float = 42.0
@export var respawn_delay: float = 0.8

@onready var sprite: Sprite2D = $Sprite2D
@onready var health_label: Label = $HealthLabel

var current_health: int
var is_dead: bool = false
var feedback_tween: Tween

func _ready() -> void:
	add_to_group("damageables")
	current_health = max_health
	_update_health_label()

func receive_hit(damage: int, hit_direction: Vector2 = Vector2.ZERO) -> void:
	if is_dead:
		return

	current_health = max(current_health - damage, 0)
	_update_health_label()
	_play_hit_feedback(hit_direction)

	if current_health <= 0:
		_die()

func get_hit_position() -> Vector2:
	return global_position

func get_hit_radius() -> float:
	return hit_radius

func _update_health_label() -> void:
	preload("res://Scripts/UI/HealthBar.gd").update_overhead(health_label, current_health, max_health)

func _play_hit_feedback(hit_direction: Vector2) -> void:
	if feedback_tween:
		feedback_tween.kill()

	var original_position := position
	var knockback := hit_direction.normalized() * 12.0 if hit_direction.length_squared() > 0.001 else Vector2.ZERO
	sprite.modulate = Color(1.0, 0.55, 0.45, 1.0)
	sprite.scale = Vector2(1.12, 1.12)
	position = original_position + knockback

	feedback_tween = create_tween()
	feedback_tween.set_parallel(true)
	feedback_tween.tween_property(sprite, "modulate", Color.WHITE, 0.12)
	feedback_tween.tween_property(sprite, "scale", Vector2.ONE, 0.12)
	feedback_tween.tween_property(self, "position", original_position, 0.12)

func _die() -> void:
	is_dead = true
	visible = false
	await get_tree().create_timer(respawn_delay).timeout
	current_health = max_health
	is_dead = false
	visible = true
	_update_health_label()
