extends RefCounted

const Defs = preload("res://Scripts/Player/SmallSkillDefs.gd")
const Field = preload("res://Scripts/Player/SmallSkillField.gd")
const LevelRefs = preload("res://Scripts/Core/LevelRefs.gd")
const WORK_EVENTS: Array[StringName] = [&"collect", &"cut", &"grind_coarse", &"grind_fine", &"serve", &"wash", &"order", &"repair"]
const MAGIC_FLASH_DURATION: float = 0.6

var player: CharacterBody2D
var variant_id: StringName = Defs.BASE
var definition: Dictionary = {}
var cooldown_remaining: float = 0.0
var cooldown_duration: float = 15.0
var buff_remaining: float = 0.0
var buff_duration: float = 2.0
var speed_bonus: float = 0.4
var kitchen_empowered: bool = false
var magic_feedback_delta: int = 0
var magic_flash_remaining: float = 0.0
var direction_wait_remaining: float = 0.0
var direction_waiting: bool = false
var locked_direction: Vector2 = Vector2.ZERO
var direction_grace_remaining: float = 0.0
var field: Node2D
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var base_config: Dictionary = {}

func setup(host: CharacterBody2D, config: Dictionary) -> void:
	player = host
	base_config = config.duplicate(true)
	rng.randomize()
	set_variant(Defs.BASE)

func set_variant(id: StringName) -> void:
	reset_temporary_state()
	definition = Defs.get_definition(id)
	variant_id = StringName(definition.id)
	if variant_id == Defs.BASE:
		definition["cooldown"] = float(base_config.get("small_cooldown", definition.cooldown))
		definition["cost"] = int(base_config.get("small_magic_cost", definition.cost))
		definition["bonus"] = float(base_config.get("small_speed_multiplier", 1.0 + float(definition.bonus))) - 1.0
		definition["duration"] = float(base_config.get("small_speed_duration", definition.duration))
	cooldown_duration = float(definition.cooldown)

func tick(delta: float, cooldown_rate: float) -> void:
	cooldown_remaining = maxf(cooldown_remaining - delta * cooldown_rate, 0.0)
	magic_flash_remaining = maxf(magic_flash_remaining - delta, 0.0)
	if direction_waiting:
		direction_wait_remaining = maxf(direction_wait_remaining - delta, 0.0)
		if direction_wait_remaining <= 0.0:
			direction_waiting = false
	if variant_id == Defs.DIRECTION and direction_grace_remaining > 0.0:
		direction_grace_remaining = maxf(direction_grace_remaining - delta, 0.0)
	if kitchen_empowered and not is_in_kitchen():
		_end_buff()
	elif buff_remaining > 0.0:
		buff_remaining = maxf(buff_remaining - delta, 0.0)
		if buff_remaining <= 0.0:
			_end_buff()

func try_activate(cooldown_multiplier: float) -> bool:
	if not player.is_skill_gameplay_active() or cooldown_remaining > 0.0:
		return false
	if variant_id == Defs.FIELD and not is_in_kitchen():
		player.show_hint("加速区域只能在料理区释放")
		return false
	var cost: int = int(definition.cost)
	if not player.try_spend_magic(cost):
		return false
	# A refreshed work skill can replace its current short buff.
	_end_buff()
	cooldown_duration = maxf(float(definition.cooldown) * cooldown_multiplier, 0.01)
	cooldown_remaining = cooldown_duration
	speed_bonus = float(definition.bonus)
	buff_duration = float(definition.duration)
	var magic_delta: int = 0
	if variant_id == Defs.RANDOM:
		speed_bonus = float(rng.randi_range(roundi(float(definition.random_bonus_min) * 100.0), roundi(float(definition.random_bonus_max) * 100.0))) / 100.0
		buff_duration = float(rng.randi_range(roundi(float(definition.random_duration_min) * 10.0), roundi(float(definition.random_duration_max) * 10.0))) / 10.0
		magic_delta = rng.randi_range(-1, 1)
		magic_feedback_delta = player.adjust_skill_magic(magic_delta)
		magic_flash_remaining = MAGIC_FLASH_DURATION if magic_feedback_delta != 0 else 0.0
		player.show_hint("移速 +%d%%\n持续 %.1f 秒" % [roundi(speed_bonus * 100.0), buff_duration])
	elif variant_id == Defs.KITCHEN:
		kitchen_empowered = is_in_kitchen()
		if kitchen_empowered:
			speed_bonus *= 2.0
			buff_duration *= 2.0
	var blessing: RefCounted = player.get_blessing_controller()
	if blessing != null:
		buff_duration *= blessing.get_low_cost_skill_duration_multiplier(cost)
	buff_remaining = buff_duration
	if variant_id == Defs.DIRECTION:
		direction_grace_remaining = buff_duration
	match variant_id:
		Defs.FIELD:
			_spawn_field(false)
			if player.get_tree().get_nodes_in_group("player").size() > 1:
				field.speed_bonus = float(definition.team_bonus)
				field.duration = float(definition.team_duration)
			field.remaining = field.duration
			buff_remaining = 0.0
		Defs.DIRECTION:
			direction_waiting = true
			direction_wait_remaining = float(definition.direction_wait)
			locked_direction = Vector2.ZERO
		Defs.TRAIL:
			_spawn_field(true)
	player.queue_redraw()
	return true

func before_motion(input_direction: Vector2) -> void:
	if variant_id == Defs.KITCHEN and kitchen_empowered and not is_in_kitchen():
		_end_buff()
	if variant_id != Defs.DIRECTION or buff_remaining <= 0.0 or input_direction.is_zero_approx():
		return
	if direction_waiting:
		locked_direction = Vector2(signf(input_direction.x), signf(input_direction.y)).normalized()
		direction_waiting = false
		player.queue_redraw()
	elif not locked_direction.is_zero_approx() and direction_grace_remaining <= 0.0 and not _is_allowed_direction(input_direction):
		# Cancel before the host calculates this frame's movement speed.
		_end_buff()
		player.queue_redraw()

func after_motion(input_direction: Vector2, from: Vector2, to: Vector2, expected_distance: float) -> void:
	if variant_id == Defs.KITCHEN and kitchen_empowered and not is_in_kitchen():
		_end_buff()
	if buff_remaining <= 0.0:
		return
	var motion: Vector2 = to - from
	if variant_id == Defs.TRAIL and is_instance_valid(field):
		field.add_motion(from, to)
	if variant_id != Defs.DIRECTION or locked_direction.is_zero_approx() or input_direction.is_zero_approx():
		return
	var requested: Vector2 = input_direction.normalized()
	# Compare against the original direction, never against the last frame.
	if not _is_allowed_direction(requested):
		if direction_grace_remaining <= 0.0:
			_end_buff()
		return
	var progressed: bool = motion.dot(requested) > maxf(expected_distance * 0.75, 0.01)
	var moved_forward: bool = not motion.is_zero_approx() and motion.normalized().dot(locked_direction) >= cos(PI / 4.0) - 0.001
	if progressed and moved_forward:
		buff_remaining = buff_duration

func _is_allowed_direction(direction: Vector2) -> bool:
	return direction.normalized().dot(locked_direction) >= cos(PI / 4.0) - 0.001

func on_work_completed(event: StringName) -> void:
	if variant_id != Defs.WORK or not player.is_skill_gameplay_active() or event not in WORK_EVENTS:
		return
	cooldown_remaining = 0.0

func get_personal_bonus() -> float:
	if buff_remaining <= 0.0 or (kitchen_empowered and not is_in_kitchen()):
		return 0.0
	return speed_bonus

func is_in_kitchen() -> bool:
	var refs: Node = LevelRefs.find_from(player)
	var map: Node = refs.get_prototype_map() if refs != null else null
	return map != null and map.is_point_in_kitchen_zone(player.get_sort_origin())

func reset_temporary_state() -> void:
	if is_instance_valid(field):
		field.queue_free()
	field = null
	cooldown_remaining = 0.0
	buff_remaining = 0.0
	kitchen_empowered = false
	magic_feedback_delta = 0
	magic_flash_remaining = 0.0
	direction_waiting = false
	locked_direction = Vector2.ZERO
	direction_grace_remaining = 0.0

func draw_feedback() -> void:
	_draw_magic_flash()
	_draw_direction()

func _draw_magic_flash() -> void:
	if magic_flash_remaining <= 0.0:
		return
	var progress: float = 1.0 - magic_flash_remaining / MAGIC_FLASH_DURATION
	var tint: Color = Color("4ab7ff") if magic_feedback_delta > 0 else Color("ff5058")
	var center := Vector2(0, -38)
	tint.a = (1.0 - progress) * 0.25
	player.draw_circle(center, 58.0 + progress * 14.0, tint)
	tint.a = (1.0 - progress) * 0.9
	for i in range(7):
		var x: float = -48.0 + float(i) * 16.0
		var from: Vector2 = center + Vector2(x, 20.0 - progress * 80.0 + sin(float(i) * 2.0) * 18.0)
		player.draw_line(from, from + Vector2(0, -18.0), tint, 4.0, true)

func _draw_direction() -> void:
	if variant_id != Defs.DIRECTION or buff_remaining <= 0.0:
		return
	var direction: Vector2 = locked_direction
	if direction.is_zero_approx():
		return
	var start: Vector2 = Vector2(0, -34) + direction * 56.0
	var tip: Vector2 = start + direction * 46.0
	var color := Color("ffe27a")
	player.draw_line(start, tip, Color("493b24"), 10.0, true)
	player.draw_line(start, tip, color, 5.0, true)
	player.draw_colored_polygon(PackedVector2Array([tip + direction * 12.0, tip - direction * 9.0 + direction.orthogonal() * 12.0, tip - direction * 9.0 - direction.orthogonal() * 12.0]), color)

func _end_buff() -> void:
	if variant_id == Defs.TRAIL and is_instance_valid(field) and not field.active:
		field.activate_trail(float(definition.trail_duration))
	buff_remaining = 0.0
	kitchen_empowered = false
	direction_waiting = false
	locked_direction = Vector2.ZERO
	direction_grace_remaining = 0.0

func _spawn_field(trail: bool) -> void:
	if is_instance_valid(field):
		field.queue_free()
	field = Field.new()
	field.owner_player = player
	field.is_trail = trail
	field.active = not trail
	field.speed_bonus = speed_bonus
	field.duration = buff_duration
	field.remaining = buff_duration
	field.radius = float(definition.get("radius", 320.0))
	field.trail_width = float(definition.get("trail_width", 96.0))
	var refs: Node = LevelRefs.find_from(player)
	refs.get_runtime_root().add_child(field)
	field.global_position = player.global_position
