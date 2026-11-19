extends Camera2D

@export var target_path: NodePath
@export var follow_speed: float = 8.0

var target: Node2D

func _ready() -> void:
	if not target_path.is_empty():
		target = get_node_or_null(target_path)

	if target:
		global_position = target.global_position

func _physics_process(delta: float) -> void:
	if not target:
		return

	var follow_weight := 1.0 - exp(-follow_speed * delta)
	global_position = global_position.lerp(target.global_position, follow_weight)
