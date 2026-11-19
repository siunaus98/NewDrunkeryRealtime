extends Node2D

const AudioCue = preload("res://Scripts/Audio/AudioCue.gd")

const Effects = preload("res://Scripts/Facilities/FacilityControlEffect.gd")
const TRAP_DAMAGE := 300
const PLAYER_TRAP_DAMAGE := 60
var kind: StringName = &"magic_net"
var direction := Vector2.RIGHT
var source: WeakRef
var life := 1.0
var travel := 0.0
var sprite: Sprite2D
var owner_clear := false

static func use(player: Node2D) -> bool:
	var id: StringName = player.get_held_item_id()
	if id not in [&"magic_net", &"bear_trap"]:
		return false
	if not player.is_skill_gameplay_active():
		return true
	var effect: Node2D = load("res://Scripts/Facilities/FacilityToolEffect.gd").new()
	effect.kind = id
	effect.direction = player.get_aim_direction_world().normalized()
	effect.source = weakref(player)
	effect.life = 1.0 if id == &"magic_net" else 999999.0
	var point: Vector2 = player.global_position + effect.direction * 65
	var reference: Node = preload("res://Scripts/Core/LevelRefs.gd").find_from(player)
	var map: Node = reference.get_prototype_map() if reference != null else null
	if map != null and (not map.is_point_in_playable_area(point, Vector2(20, 20)) or map.is_segment_blocked_by_dune_wall(player.global_position, point)):
		player.show_hint("前方没有放置空间")
		effect.free()
		return true
	var query := PhysicsRayQueryParameters2D.create(player.global_position, point, 4 | 16)
	if not player.get_world_2d().direct_space_state.intersect_ray(query).is_empty():
		player.show_hint("前方有设施阻挡")
		effect.free()
		return true
	player.get_parent().add_child(effect)
	effect.global_position = point
	player.clear_held_item()
	AudioCue.at(player, &"drop", -4.0)
	return true

func _ready() -> void:
	add_to_group("facility_tool_effects")
	sprite = Sprite2D.new()
	sprite.texture = load("res://ArtResource/Facilities/%s.svg" % kind)
	sprite.rotation = direction.angle()
	add_child(sprite)

func _physics_process(delta: float) -> void:
	life -= delta
	if life <= 0:
		queue_free()
		return
	if kind == &"magic_net":
		var motion := direction * 700 * delta
		var query := PhysicsRayQueryParameters2D.create(global_position, global_position + motion, 4 | 16)
		if not get_world_2d().direct_space_state.intersect_ray(query).is_empty():
			AudioCue.at(self, &"impact", -5.0)
			queue_free()
			return
		global_position += motion
		travel += motion.length()
	if source.get_ref() == null or global_position.distance_to(source.get_ref().global_position) > 70:
		owner_clear = true
	for group in ["enemies", "scarab_enemies", "player"]:
		for target: Node2D in get_tree().get_nodes_in_group(group):
			if target == source.get_ref() and (kind == &"magic_net" or not owner_clear):
				continue
			if target.global_position.distance_to(global_position) > 48 or target.get("is_dead") == true:
				continue
			if kind == &"magic_net":
				if target.is_in_group("bosses"):
					continue
				Effects.attach(target, 5.0, 5.0)
			else:
				var temporary := target.is_in_group("bosses") or target.is_in_group("player")
				Effects.attach(target, 0.0 if temporary else 2.0, 0.0, 0.25 if temporary else 0.6, 6.0 if temporary else 0.0, not temporary)
				if target.is_in_group("player") and target.has_method("take_damage"):
					target.take_damage(PLAYER_TRAP_DAMAGE, direction, &"trap")
				elif target.has_method("receive_hit"):
					target.receive_hit(TRAP_DAMAGE, direction)
			AudioCue.at(self, &"impact", -5.0)
			queue_free()
			return
