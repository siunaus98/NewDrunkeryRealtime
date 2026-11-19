extends "res://Scripts/Enemies/MonitorTongueController.gd"

const Pause = preload("res://Scripts/Facilities/FacilityWorkPause.gd")
@export var pause_duration: float = 10.0
@export var frenzy_shutdown_duration: float = 30.0

func tick(delta: float, can_start: bool) -> void:
	if active():
		for branch: Dictionary in branches:
			if _target_valid(branch.target):
				branch.target.position = _station_position(branch.target.source.get_ref())
	super.tick(delta, can_start)

func _station_position(station: Node2D) -> Vector2:
	var carrier: WeakRef = station.get_meta("facility_carrier") if station.has_meta("facility_carrier") else null
	var actor: Node2D = carrier.get_ref() if carrier != null else null
	return actor.global_position + Vector2(0, -60) if is_instance_valid(actor) else station.global_position

func _get_options() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var kitchen: Rect2 = boss.prototype_map.get_kitchen_zone_bounds()
	for station: Node in get_tree().get_nodes_in_group("pickup_drop_targets"):
		if not station is Node2D or not station.is_visible_in_tree() or station.is_queued_for_deletion() or not kitchen.has_point(station.global_position) or Pause.is_paused(station):
			continue
		if not (station.is_in_group("cooking_stations") or station.is_in_group("drink_barrels") or station.is_in_group("plate_sinks") or station.is_in_group("assembly_stations") or station.is_in_group("production_facilities") or (station.get("facility_type") == &"fire_furnace")):
			continue
		var busy := false
		if station.is_in_group("cooking_stations"):
			busy = station.has_item
		elif station.is_in_group("drink_barrels"):
			busy = station.queued_fill_count > 0
		elif station.is_in_group("plate_sinks"):
			busy = station.dirty_plates > 0
		elif station.is_in_group("assembly_stations"):
			busy = not station.stored_items.is_empty()
		else:
			busy = not station.stored.is_empty()
		result.append({"source": weakref(station), "position": station.global_position, "busy": busy})
	return result

func _target_priority(target: Dictionary) -> int:
	return 1 if target.busy else 0

func _target_count() -> int:
	return 1

func _target_valid(target: Dictionary) -> bool:
	var station: Node2D = target.source.get_ref()
	return is_instance_valid(station) and not station.is_queued_for_deletion() and (station.is_visible_in_tree() or station.has_meta("facility_carrier"))

func _resolve_branches() -> void:
	for branch: Dictionary in branches:
		if not bool(branch.cancelled) and _target_valid(branch.target):
			var duration := frenzy_shutdown_duration if boss.current_health * 2 < boss.max_health else Pause.DEEP_DURATION
			var station: Node2D = branch.target.source.get_ref()
			Pause.attach(station, boss, pause_duration, duration)
			if station.has_meta("facility_carrier"):
				var actor: Node = station.get_meta("facility_carrier").get_ref()
				if is_instance_valid(actor):
					actor.show_hint("搬运中的设施已附着口水 · 放下后可修理")

func mouth() -> Vector2:
	return boss.sprite.to_global(Vector2(66, -43))

func tongue_color() -> Color:
	return Color("6b9eb2")

func status_text() -> String:
	match phase:
		Phase.LOCK:
			return "干扰头 · 蓄力吐液 · 无法打断"
		Phase.EXTEND:
			return "干扰头 · 喷吐口水 · 无法打断"
		Phase.RETRACT:
			return "干扰头 · 吐液结束"
	return ""

func _draw() -> void:
	if not active() or not is_instance_valid(boss):
		return
	for branch: Dictionary in branches:
		if branch.cancelled:
			continue
		var target := to_local(Vector2(branch.target.position))
		if phase == Phase.LOCK:
			draw_circle(target, 48, Color(0.3, 0.7, 0.4, 0.22))
			draw_arc(target, 52, -PI / 2, -PI / 2 + TAU * (1 - remaining / lock_duration), 36, Color("b0d893"), 7, true)
		elif phase == Phase.EXTEND:
			var point := to_local(tip(0))
			var back := (to_local(mouth()) - point).normalized()
			draw_circle(point, 24, Color("426f52"))
			draw_circle(point, 18, Color("95c780"))
			draw_circle(point + Vector2(-5, -5), 6, Color("deedb1"))
			for index in range(3):
				draw_circle(point + back * (30 + index * 18), 9 - index * 2, Color("95c780"))
