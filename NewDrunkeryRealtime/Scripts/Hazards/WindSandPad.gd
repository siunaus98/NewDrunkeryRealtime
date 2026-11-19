class_name WindSandPad
extends Node2D

enum State { BLUE_WARNING, READY }

@export var warning_duration: float = 2.0
@export var ready_duration: float = 7.0
@export var trigger_radius: float = 60.0
@export var jump_distance: float = 620.0
@export var jump_distance_randomness: float = 0.1
@export var retrigger_lock_duration: float = 0.35

var state: State = State.BLUE_WARNING
var state_remaining: float = 0.0
var direction: Vector2 = Vector2.RIGHT
var direction_index: int = 0
var retrigger_remaining: float = 0.0
var rng := RandomNumberGenerator.new()
var direction_is_configured: bool = false

func _ready() -> void:
	add_to_group("wind_sand_pads")
	rng.randomize()
	if not direction_is_configured:
		direction_index = rng.randi_range(0, 7)
		direction = Vector2.RIGHT.rotated(TAU * float(direction_index) / 8.0)
	state_remaining = maxf(warning_duration, 0.1)
	queue_redraw()

func _process(delta: float) -> void:
	state_remaining = maxf(state_remaining - delta, 0.0)
	retrigger_remaining = maxf(retrigger_remaining - delta, 0.0)
	if state == State.BLUE_WARNING and state_remaining <= 0.0:
		state = State.READY
		state_remaining = maxf(ready_duration, 0.1)
	elif state == State.READY and state_remaining <= 0.0:
		queue_free()
		return
	if state == State.READY and retrigger_remaining <= 0.0:
		for player in get_tree().get_nodes_in_group("player"):
			if not is_instance_valid(player) or not player is Node2D:
				continue
			if global_position.distance_to((player as Node2D).global_position) <= trigger_radius:
				_trigger_player(player)
				break
	queue_redraw()

func _trigger_player(player: Node) -> void:
	if not player.has_method("apply_wind_sand_jump"):
		return
	var distance := jump_distance * rng.randf_range(1.0 - jump_distance_randomness, 1.0 + jump_distance_randomness)
	if not bool(player.apply_wind_sand_jump(direction * distance)):
		retrigger_remaining = maxf(retrigger_lock_duration, 0.12)
		return
	retrigger_remaining = maxf(retrigger_lock_duration, 0.05)
	queue_free()

func configure_direction(new_direction_index: int) -> void:
	direction_index = posmod(new_direction_index, 8)
	direction = Vector2.RIGHT.rotated(TAU * float(direction_index) / 8.0)
	direction_is_configured = true

func _draw() -> void:
	var color := Color(0.22, 0.62, 0.98, 0.84) if state == State.BLUE_WARNING else Color(0.96, 0.72, 0.12, 0.94)
	var half_size := Vector2(58.0, 58.0)
	var rect := Rect2(-half_size, half_size * 2.0)
	draw_rect(rect, Color(color.r, color.g, color.b, 0.24), true)
	draw_rect(rect, color, false, 6.0)
	var arrow_end := direction.normalized() * 42.0
	draw_line(-arrow_end, arrow_end, color.lightened(0.18), 8.0)
	draw_line(arrow_end, arrow_end - direction.rotated(0.55) * 18.0, color.lightened(0.18), 8.0)
	draw_line(arrow_end, arrow_end - direction.rotated(-0.55) * 18.0, color.lightened(0.18), 8.0)
