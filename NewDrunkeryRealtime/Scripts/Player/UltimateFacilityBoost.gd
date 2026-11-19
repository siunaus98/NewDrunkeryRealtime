extends Node2D

## Local to a facility: no global scan in automatic processing, and moving
## the facility carries both its modifier and its feedback with it.
const NODE_NAME := "UltimateFacilityBoost"
var source_ref: WeakRef
var multiplier: float = 1.0
var remaining: float = 0.0
var outline: Rect2 = Rect2(-58, -68, 116, 112)

static func attach(station: Node2D, source: Node, factor: float, seconds: float) -> Node2D:
	var effect: Node2D = load("res://Scripts/Player/UltimateFacilityBoost.gd").new()
	effect.name = NODE_NAME + str(source.get_instance_id())
	effect.source_ref = weakref(source)
	effect.multiplier = factor
	effect.remaining = seconds
	station.add_child(effect)
	return effect

static func get_multiplier(station: Node) -> float:
	var result := 1.0
	for child: Node in station.get_children():
		if child.is_in_group("ultimate_facility_boosts") and not child.is_queued_for_deletion() and child.remaining > 0.0 and child.source_ref.get_ref() != null:
			result = maxf(result, child.multiplier)
	return result

static func is_eligible(station: Node) -> bool:
	return is_instance_valid(station) and station is Node2D and (station.is_in_group("cooking_stations") or station.is_in_group("drink_barrels") or station.is_in_group("plate_sinks") or station.is_in_group("production_facilities"))

func _ready() -> void:
	add_to_group("ultimate_facility_boosts")
	z_index = 24
	# Draw in world pixels even on older scaled cooker scenes.
	var parent_scale: Vector2 = get_parent().global_scale
	scale = Vector2(1.0 / maxf(absf(parent_scale.x), 0.001), 1.0 / maxf(absf(parent_scale.y), 0.001))
	var station: Node2D = get_parent()
	if station.has_method("get_layout_footprint"):
		var footprint: Vector2i = station.get_layout_footprint()
		outline.size.x = float(footprint.x) * 128.0 - 12.0
		outline.position.x = -outline.size.x / 2.0
	queue_redraw()

func _process(_delta: float) -> void:
	# The skill controller owns the timer, including pauses and day resets.
	if source_ref.get_ref() == null or remaining <= 0.0:
		queue_free()
	else:
		queue_redraw()

func _draw() -> void:
	var phase: float = remaining * 1.8
	for index in range(6):
		var t: float = fposmod(phase * 0.15 + float(index) / 6.0, 1.0)
		var at := outline.position + Vector2(outline.size.x * float(index) / 5.0, outline.size.y * (1.0 - t))
		draw_circle(at, 1.5 + sin(t * PI) * 1.2, Color(1, 0.86, 0.55, sin(t * PI) * 0.7))
	draw_rect(outline, Color(1.0, 0.78, 0.24, 0.12), true)
	draw_rect(outline, Color("ffe490"), false, 3.0, true)
	var text := "×%s · %d秒" % [str(multiplier), ceili(remaining)]
	var at := outline.position + Vector2(0, -9)
	draw_string_outline(ThemeDB.fallback_font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 19, 5, Color("3f301e"))
	draw_string(ThemeDB.fallback_font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 19, Color("fff0b2"))
