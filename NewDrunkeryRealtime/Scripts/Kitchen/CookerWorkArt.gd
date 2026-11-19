extends Node2D

## Display in world units even on legacy scaled cooker scenes.
var station: Node2D
var elapsed: float = 0
var previous_progress: float = 0
var dust_remaining: float = 0

func _ready() -> void:
	station = get_parent()
	var parent_scale := station.global_scale.abs()
	scale = Vector2.ONE / parent_scale.max(Vector2(0.001, 0.001))
	position = station.item_layer.position + station.item_sprite.position
	z_index = 7

func _process(delta: float) -> void:
	elapsed += delta
	dust_remaining = maxf(0, dust_remaining - delta)
	if station.has_item and station.process_progress > previous_progress:
		dust_remaining = 0.12
	previous_progress = station.process_progress
	if station.has_item:
		queue_redraw()
	elif visible:
		hide()
	visible = station.has_item

func _draw() -> void:
	if station == null or not station.has_item:
		return
	var family: StringName = preload("res://Scripts/Kitchen/TestItemDefs.gd").get_process_family(station.output_process_state)
	var paused: bool = preload("res://Scripts/Facilities/FacilityWorkPause.gd").is_paused(station)
	if family == &"roast" and ((station._is_auto_processing() and not paused) or station._is_overcooking()):
		var burnt: bool = station._is_overcooking()
		for index in range(3):
			var t: float = fposmod(elapsed * 0.45 + float(index) / 3, 1)
			var at := Vector2(float(index - 1) * 15 + sin(t * TAU + index) * 5, -10 - t * 34)
			var points := PackedVector2Array()
			for point in range(9):
				var p: float = float(point) / 8
				points.append(at + Vector2(sin(p * TAU) * 3, -p * 12))
			draw_polyline(points, Color(0.45, 0.36, 0.29, sin(t * PI) * 0.65) if burnt else Color(1, 0.94, 0.77, sin(t * PI) * 0.65), 2.2, true)
	elif dust_remaining > 0 and not paused:
		for index in range(5):
			var t: float = fposmod(elapsed * 1.3 + float(index) / 5, 1)
			var at := Vector2((float(index) - 2) * 11, -6 - sin(t * PI) * 12)
			draw_circle(at, 1.5, Color(0.95, 0.82, 0.57, sin(t * PI) * 0.7))
