extends Node2D

const AudioCue = preload("res://Scripts/Audio/AudioCue.gd")

const Food = preload("res://Scripts/Enemies/MonitorFoodAccess.gd")
const Cargo = preload("res://Scripts/Facilities/FacilityItems.gd")
enum Phase { IDLE, LOCK, EXTEND, RETRACT }

@export var interval: float = 18.0
@export var lock_duration: float = 2.5
@export var extend_duration: float = 1.8
@export var retract_duration: float = 1.5
var boss: CharacterBody2D
var phase: Phase = Phase.IDLE
var remaining: float = 0.0
var cooldown: float = 8.0
var branches: Array[Dictionary] = []

func setup(host: CharacterBody2D) -> void:
	boss = host
	z_index = 12

func _process(_delta: float) -> void:
	queue_redraw()

func active() -> bool:
	return phase != Phase.IDLE

func blocks_boss() -> bool:
	return active()

func tick(delta: float, can_start: bool) -> void:
	if not active():
		cooldown = maxf(cooldown - delta, 0.0)
		if can_start and cooldown <= 0.0:
			begin()
		return
	remaining = maxf(remaining - delta, 0.0)
	if phase != Phase.RETRACT:
		for branch: Dictionary in branches:
			if not bool(branch.cancelled) and not _target_valid(branch.target):
				branch.cancelled = true
	if remaining > 0.0:
		return
	match phase:
		Phase.LOCK:
			AudioCue.at(boss, &"spit", -4.0)
			phase = Phase.EXTEND
			remaining = extend_duration
		Phase.EXTEND:
			_clear_hits()
			_resolve_branches()
			phase = Phase.RETRACT
			remaining = retract_duration
		Phase.RETRACT:
			finish()

func begin() -> bool:
	if active() or not is_instance_valid(boss.prototype_map):
		return false
	var options := _get_options()
	options.shuffle()
	options.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return _target_priority(a) > _target_priority(b))
	branches.clear()
	var count := _target_count()
	for target: Dictionary in options:
		branches.append({"target": target, "cancelled": false, "food": {}})
		if branches.size() >= count:
			break
	if branches.is_empty():
		cooldown = 2.0
		return false
	phase = Phase.LOCK
	remaining = lock_duration
	boss.velocity = Vector2.ZERO
	return true

func _get_options() -> Array[Dictionary]:
	return Food.candidates(get_tree(), boss.prototype_map.get_kitchen_zone_bounds())

func _target_priority(target: Dictionary) -> int:
	# Prefer prepared food, but allow a raw ingredient when nothing is ready.
	return Food.quality(target.item)

func _target_count() -> int:
	return 2 if boss.current_health * 2 < boss.max_health else 1

func _target_valid(target: Dictionary) -> bool:
	return Food.valid(target)

func _resolve_branches() -> void:
	var targets: Array[Dictionary] = []
	for branch: Dictionary in branches:
		targets.append({} if bool(branch.cancelled) else branch.target)
	var food := Food.consume_many(targets)
	for index in branches.size():
		branches[index].food = food[index]

func finish() -> void:
	_clear_hits()
	branches.clear()
	phase = Phase.IDLE
	cooldown = interval
	boss.attack_remaining = maxf(boss.attack_remaining, 1.0)

func release_captured_food() -> void:
	for branch: Dictionary in branches:
		if not Dictionary(branch.food).is_empty():
			Cargo.drop(boss.get_parent(), branch.target.position, branch.food)
	finish()

func _clear_hits() -> void:
	# Tongues are visual threats only. Rescue is performed at the bound facility.
	return

func mouth() -> Vector2:
	return boss.sprite.to_global(Vector2(-130, -64))

func tip(index: int) -> Vector2:
	var point: Vector2 = branches[index].target.position
	var progress := 1.0 - remaining / maxf(extend_duration if phase == Phase.EXTEND else retract_duration, 0.001)
	return mouth().lerp(point, progress if phase == Phase.EXTEND else 1.0 - progress)

func hit_position(index: int) -> Vector2:
	if phase != Phase.EXTEND or index >= branches.size() or bool(branches[index].cancelled):
		return Vector2(1e8, 1e8)
	return tip(index)

func status_text() -> String:
	match phase:
		Phase.LOCK:
			return "偷食头 · 吐舌锁定 %d 份食物 · 无法打断" % branches.size()
		Phase.EXTEND:
			return "偷食头 · 伸舌 · 无法打断"
		Phase.RETRACT:
			return "偷食头 · 收舌 · 无法打断"
	return ""

func tongue_color() -> Color:
	return Color("d76c82")

func _draw() -> void:
	if not active() or not is_instance_valid(boss):
		return
	if phase == Phase.LOCK:
		var start := to_local(mouth())
		var progress := 1.0 - remaining / lock_duration
		draw_line(start, start + Vector2(0, 25 + 12 * sin(remaining * 12)), Color("513420"), 19, true)
		draw_line(start, start + Vector2(0, 25 + 12 * sin(remaining * 12)), tongue_color(), 11, true)
		var bar := Rect2(to_local(boss.global_position) + Vector2(-80, -190), Vector2(160, 12))
		draw_rect(bar.grow(3), Color("513420"))
		draw_rect(bar, Color("9c536f"))
		bar.size.x *= progress
		draw_rect(bar, Color("f3c35a"))
	for index in branches.size():
		var branch: Dictionary = branches[index]
		var target: Vector2 = to_local(branch.target.position)
		if bool(branch.cancelled):
			draw_line(target - Vector2(22, 22), target + Vector2(22, 22), Color("e2cfb2"), 5, true)
			draw_line(target - Vector2(-22, 22), target + Vector2(-22, 22), Color("e2cfb2"), 5, true)
			continue
		if phase == Phase.LOCK:
			var progress := 1.0 - remaining / lock_duration
			draw_circle(target, 48, Color(0.8, 0.12, 0.25, 0.2))
			draw_arc(target, 52, -PI / 2, -PI / 2 + TAU * progress, 36, Color("f3c35a"), 7, true)
			for ray in range(4):
				var direction := Vector2.RIGHT.rotated(ray * PI / 2)
				draw_line(target + direction * 58, target + direction * 78, Color("eb6977"), 5, true)
		else:
			var start := to_local(mouth())
			var end := to_local(tip(index))
			draw_line(start, end, Color("513420"), 22, true)
			draw_line(start, end, tongue_color().darkened(0.25) if phase == Phase.RETRACT else tongue_color(), 14, true)
			draw_circle(end, 18, tongue_color().lightened(0.3))
			var item: Dictionary = branch.food
			if not item.is_empty() and phase == Phase.RETRACT:
				var texture: Texture2D = Food.Items.get_world_item_texture(StringName(item.item_id), item.get("payload", {}))
				if texture != null:
					draw_texture_rect(texture, Rect2(end - Vector2(32, 32), Vector2(64, 64)), false)
