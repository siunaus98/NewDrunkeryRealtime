extends Node2D

## Kept as a visual/controller compatibility node. Tongues are no longer
## damageables; heavy attacks rescue the bound facility instead.
var controller: Node2D
var branch_index: int

func _ready() -> void:
	pass

func get_hit_position() -> Vector2:
	return controller.hit_position(branch_index)

func get_hit_radius() -> float:
	return 24.0

func receive_hit(_damage: int, _direction: Vector2 = Vector2.ZERO) -> void:
	pass

func receive_charged_hit(_damage: int, _direction: Vector2 = Vector2.ZERO) -> void:
	pass
