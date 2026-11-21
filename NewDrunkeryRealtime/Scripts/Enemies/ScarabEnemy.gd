class_name ScarabEnemy
extends CharacterBody2D

const AudioCue = preload("res://Scripts/Audio/AudioCue.gd")

const BODY_TEXTURE = preload("res://ArtResource/Generated/Enemy/stealing_scarab.svg")

signal defeated(scarab: Node2D, stolen_items: Array[StringName], defeat_position: Vector2)
signal steal_action_finished(scarab: Node2D, target: Node, target_kind: StringName)
signal escape_finished(scarab: Node2D)

enum State { SEARCHING, STEALING, ESCAPING_TO_CORNER, ESCAPING }

@export var move_speed: float = 168.0
@export var hit_radius: float = 34.0
@export var steal_reach: float = 104.0
@export var escape_move_speed: float = 144.0
@export var escape_arrival_distance: float = 18.0
@export var escape_duration: float = 8.0
@export var max_stolen_items_min: int = 1
@export var max_stolen_items_max: int = 3

var state: State = State.SEARCHING
var current_target: Node
var current_target_kind: StringName = &""
var target_approach_position: Vector2 = Vector2.INF
var action_remaining: float = 0.0
var action_duration: float = 0.0
var escape_remaining: float = 0.0
var escape_target_position: Vector2 = Vector2.INF
var stolen_items: Array[StringName] = []
var stolen_limit: int = 2
var light_hits: float = 0.0
var is_dead: bool = false
var rng := RandomNumberGenerator.new()
var navigation_route: Array[Vector2] = []
var navigation_route_index: int = 0
var escape_navigation_route: Array[Vector2] = []
var escape_navigation_route_index: int = 0
var navigation_stuck_time: float = 0.0

func _ready() -> void:
	add_to_group("damageables")
	add_to_group("scarab_enemies")
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	z_index = 6
	rng.randomize()
	stolen_limit = rng.randi_range(maxi(max_stolen_items_min, 2), maxi(max_stolen_items_max, max_stolen_items_min))
	queue_redraw()

func _process(delta: float) -> void:
	if is_dead:
		return
	if state == State.STEALING:
		if not is_instance_valid(current_target) or not current_target.is_scarab_steal_target():
			clear_target()
			return
		action_remaining = maxf(action_remaining - delta, 0.0)
		if action_remaining <= 0.0:
			var target := current_target
			var target_kind := current_target_kind
			state = State.SEARCHING
			action_duration = 0.0
			steal_action_finished.emit(self, target, target_kind)
			if current_target == target:
				clear_target()
		queue_redraw()
	elif state == State.ESCAPING:
		escape_remaining = maxf(escape_remaining - delta, 0.0)
		if escape_remaining <= 0.0:
			# Mark the cast as spent before notifying the mechanism.  The node is
			# removed by the controller after the signal, so combat and cleanup see
			# one consistent terminal state.
			is_dead = true
			escape_finished.emit(self)
	queue_redraw()

func _physics_process(_delta: float) -> void:
	if preload("res://Scripts/Facilities/FacilityControlEffect.gd").rooted(self):
		velocity = Vector2.ZERO
		return
	if is_dead:
		velocity = Vector2.ZERO
		return
	if state == State.ESCAPING_TO_CORNER:
		if not escape_target_position.is_finite():
			velocity = Vector2.ZERO
			return
		var target_position := escape_target_position
		if escape_navigation_route_index < escape_navigation_route.size():
			target_position = escape_navigation_route[escape_navigation_route_index]
			if global_position.distance_to(target_position) <= 24.0:
				escape_navigation_route_index += 1
				if escape_navigation_route_index < escape_navigation_route.size():
					target_position = escape_navigation_route[escape_navigation_route_index]
				else:
					target_position = escape_target_position
		var to_escape_corner := target_position - global_position
		if escape_navigation_route_index >= escape_navigation_route.size() and to_escape_corner.length() <= escape_arrival_distance:
			velocity = Vector2.ZERO
			_begin_escape_cast()
			return
		velocity = to_escape_corner.normalized() * escape_move_speed
		var previous_escape_position := global_position
		velocity *= preload("res://Scripts/Facilities/FacilityControlEffect.gd").speed(self)
		move_and_slide()
		if global_position.distance_to(previous_escape_position) <= 0.5:
			navigation_stuck_time += _delta
		else:
			navigation_stuck_time = 0.0
		return
	if state != State.SEARCHING or current_target == null:
		velocity = Vector2.ZERO
		return
	if not is_instance_valid(current_target) or not (current_target is Node2D):
		velocity = Vector2.ZERO
		return
	var target_position := (current_target as Node2D).global_position
	var target_reach := get_current_target_reach()
	if current_target_kind in [&"cabinet", &"ground"] and target_approach_position.is_finite():
		target_position = target_approach_position
		target_reach = 6.0
	if global_position.distance_to(target_position) <= target_reach:
		velocity = Vector2.ZERO
		navigation_route_index = navigation_route.size()
		navigation_stuck_time = 0.0
		return
	var is_following_route := navigation_route_index < navigation_route.size()
	if navigation_route_index < navigation_route.size():
		target_position = navigation_route[navigation_route_index]
		if global_position.distance_to(target_position) <= 24.0:
			navigation_route_index += 1
			if navigation_route_index < navigation_route.size():
				target_position = navigation_route[navigation_route_index]
			else:
				target_position = target_approach_position if target_approach_position.is_finite() else (current_target as Node2D).global_position
			is_following_route = navigation_route_index < navigation_route.size()
	var to_target := target_position - global_position
	# Waypoints are navigation corners, not theft positions. The enlarged
	# collision body can be within theft range of a nearby corner while still
	# being far from the actual cabinet; only stop for the real target.
	if not is_following_route and to_target.length() <= target_reach:
		velocity = Vector2.ZERO
		navigation_stuck_time = 0.0
		return
	velocity = to_target.normalized() * move_speed
	var previous_position := global_position
	velocity *= preload("res://Scripts/Facilities/FacilityControlEffect.gd").speed(self)
	move_and_slide()
	if global_position.distance_to(previous_position) <= 0.5:
		navigation_stuck_time += _delta
	else:
		navigation_stuck_time = 0.0

func set_target(target: Node, target_kind: StringName, route: Array[Vector2] = [], approach: Vector2 = Vector2.INF) -> void:
	if is_dead or state != State.SEARCHING:
		return
	current_target = target
	current_target_kind = target_kind
	target_approach_position = approach
	navigation_route = route.duplicate()
	navigation_route_index = 0
	navigation_stuck_time = 0.0

func clear_target() -> void:
	if state in [State.SEARCHING, State.STEALING]:
		state = State.SEARCHING
		action_remaining = 0.0
		action_duration = 0.0
		target_approach_position = Vector2.INF
		current_target = null
		current_target_kind = &""
		navigation_route.clear()
		navigation_route_index = 0
		navigation_stuck_time = 0.0

func is_navigation_stuck() -> bool:
	return navigation_stuck_time >= 0.35

func is_reserving_cabinet(cabinet: Node) -> bool:
	return not is_dead and not is_queued_for_deletion() and state in [State.SEARCHING, State.STEALING] and current_target == cabinet and current_target_kind == &"cabinet" and is_instance_valid(cabinet) and not cabinet.is_queued_for_deletion() and cabinet.visible and cabinet.menu_item_enabled

func get_current_target_reach() -> float:
	if is_instance_valid(current_target) and current_target.has_method("get_scarab_steal_reach"):
		return maxf(float(current_target.get_scarab_steal_reach()), steal_reach)
	return steal_reach

func begin_steal(target: Node, target_kind: StringName, duration: float) -> bool:
	if is_dead or state != State.SEARCHING or target == null or not is_instance_valid(target):
		return false
	current_target = target
	current_target_kind = target_kind
	state = State.STEALING
	action_remaining = maxf(duration, 0.01)
	action_duration = action_remaining
	velocity = Vector2.ZERO
	queue_redraw()
	return true

func begin_escape() -> void:
	if is_dead:
		return
	state = State.ESCAPING_TO_CORNER
	current_target = null
	current_target_kind = &""
	target_approach_position = Vector2.INF
	navigation_route.clear()
	navigation_route_index = 0
	escape_navigation_route.clear()
	escape_navigation_route_index = 0
	action_remaining = 0.0
	action_duration = 0.0
	escape_remaining = 0.0
	escape_target_position = Vector2.INF
	velocity = Vector2.ZERO

func resume_searching() -> void:
	if is_dead or state not in [State.ESCAPING_TO_CORNER, State.ESCAPING] or get_stolen_count() >= stolen_limit:
		return
	state = State.SEARCHING
	escape_target_position = Vector2.INF
	escape_navigation_route.clear()
	escape_navigation_route_index = 0
	escape_remaining = 0.0
	navigation_stuck_time = 0.0
	velocity = Vector2.ZERO

func set_escape_target(target_position: Vector2, route: Array[Vector2] = []) -> void:
	if is_dead or state != State.ESCAPING_TO_CORNER:
		return
	escape_target_position = target_position
	escape_navigation_route = route.duplicate()
	escape_navigation_route_index = 0
	navigation_stuck_time = 0.0

func _begin_escape_cast() -> void:
	if is_dead or state != State.ESCAPING_TO_CORNER:
		return
	state = State.ESCAPING
	escape_remaining = maxf(escape_duration, 0.1)
	escape_target_position = Vector2.INF
	velocity = Vector2.ZERO

func receive_hit(_damage: int, _hit_direction: Vector2 = Vector2.ZERO) -> void:
	if is_dead:
		return
	# Escape casting is a warning state, not an invulnerability state. The
	# player must still be able to finish a scarab that is about to flee.
	light_hits += preload("res://Scripts/Facilities/FacilityControlEffect.gd").hit_weight(self)
	if light_hits >= 3:
		_die()

func receive_charged_hit(
	_damage: int,
	_hit_direction: Vector2 = Vector2.ZERO
) -> void:
	if is_dead:
		return
	_die()

func get_hit_position() -> Vector2:
	return global_position

func get_hit_radius() -> float:
	return hit_radius

func get_stolen_count() -> int:
	return stolen_items.size()

func add_stolen_item(item_id: StringName) -> void:
	if item_id == &"" or get_stolen_count() >= stolen_limit:
		return
	stolen_items.append(item_id)
	if get_stolen_count() >= stolen_limit:
		begin_escape()

func get_state() -> State:
	return state

func get_action_progress() -> float:
	if state == State.STEALING:
		return clampf(1.0 - action_remaining / maxf(action_duration, 0.001), 0.0, 1.0)
	if state == State.ESCAPING:
		return clampf(1.0 - escape_remaining / maxf(escape_duration, 0.001), 0.0, 1.0)
	return 0.0

func _die() -> void:
	if is_dead:
		return
	is_dead = true
	AudioCue.at(self, &"enemy_down", -6.0)
	state = State.SEARCHING
	velocity = Vector2.ZERO
	collision_layer = 0
	collision_mask = 0
	defeated.emit(self, stolen_items.duplicate(), global_position)
	queue_free()

func _draw() -> void:
	draw_texture_rect(BODY_TEXTURE, Rect2(-36, -40, 72, 72), false)
	if state == State.STEALING or state == State.ESCAPING:
		var bar_rect := Rect2(-58.0, -82.0, 116.0, 14.0)
		var fill_color := Color(0.96, 0.72, 0.16, 0.98) if state == State.STEALING else Color(0.96, 0.30, 0.18, 0.98)
		draw_rect(bar_rect, Color(0.08, 0.05, 0.04, 0.9), true)
		draw_rect(Rect2(bar_rect.position, Vector2(bar_rect.size.x * get_action_progress(), bar_rect.size.y)), fill_color, true)
		draw_rect(bar_rect, Color(1.0, 0.92, 0.66, 0.96), false, 2.0)
	elif state == State.ESCAPING_TO_CORNER:
		# The approach phase has no cast progress yet; the arrow makes its intent
		# readable without misleading the player into thinking the timer started.
		var direction := (escape_target_position - global_position).normalized() if escape_target_position.is_finite() else Vector2.ZERO
		if direction != Vector2.ZERO:
			draw_line(Vector2.ZERO, direction * 30.0, Color(1.0, 0.55, 0.18, 0.95), 4.0, true)
			draw_circle(direction * 34.0, 5.0, Color(1.0, 0.78, 0.25, 0.95))
