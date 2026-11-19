extends Node2D

var root_remaining := 0.0
var vulnerable_remaining := 0.0
var slow_remaining := 0.0
var slow_duration := 1.0
var slow_factor := 1.0
var permanent_factor := 1.0

static func attach(target: Node, root_seconds: float, vulnerable: float = 0.0, slow: float = 1.0, slow_seconds: float = 0.0, permanent: bool = false) -> void:
	if target.has_method("is_control_immune") and target.is_control_immune():
		return
	var effect: Node = target.get_node_or_null("FacilityControlEffect")
	if effect == null:
		effect = load("res://Scripts/Facilities/FacilityControlEffect.gd").new()
		effect.name = "FacilityControlEffect"
		target.add_child(effect)
	effect.root_remaining = maxf(effect.root_remaining, root_seconds)
	effect.vulnerable_remaining = maxf(effect.vulnerable_remaining, vulnerable)
	if permanent:
		effect.permanent_factor = minf(effect.permanent_factor, slow)
	else:
		effect.slow_factor = minf(effect.slow_factor, slow)
		effect.slow_remaining = maxf(effect.slow_remaining, slow_seconds)
		effect.slow_duration = maxf(effect.slow_duration, slow_seconds)

static func rooted(target: Node) -> bool:
	var effect: Node = target.get_node_or_null("FacilityControlEffect")
	return effect != null and not effect.is_queued_for_deletion() and effect.root_remaining > 0

static func speed(target: Node) -> float:
	var effect: Node = target.get_node_or_null("FacilityControlEffect")
	if effect == null:
		return 1.0
	if effect.is_queued_for_deletion():
		return 1.0
	if effect.root_remaining > 0:
		return 0.0
	return minf(effect.permanent_factor, lerpf(1.0, effect.slow_factor, clampf(effect.slow_remaining / effect.slow_duration, 0, 1)))

static func damage(target: Node, amount: int) -> int:
	var effect: Node = target.get_node_or_null("FacilityControlEffect")
	return roundi(amount * 1.5) if effect != null and not effect.is_queued_for_deletion() and effect.vulnerable_remaining > 0 else amount

static func hit_weight(target: Node) -> float:
	var effect: Node = target.get_node_or_null("FacilityControlEffect")
	return 1.5 if effect != null and not effect.is_queued_for_deletion() and effect.vulnerable_remaining > 0 else 1.0

func _process(delta: float) -> void:
	root_remaining = maxf(root_remaining - delta, 0)
	vulnerable_remaining = maxf(vulnerable_remaining - delta, 0)
	slow_remaining = maxf(slow_remaining - delta, 0)
	queue_redraw()
	if root_remaining <= 0 and vulnerable_remaining <= 0 and slow_remaining <= 0 and permanent_factor >= 1:
		queue_free()

func _draw() -> void:
	var parent_scale: Vector2 = get_parent().global_scale
	scale = Vector2.ONE / parent_scale
	var color := Color("81d7d0") if root_remaining > 0 else Color("ba986a")
	draw_arc(Vector2(0, 12), 38, 0, TAU, 24, color, 4, true)
	if root_remaining > 0:
		for x in [-24, 0, 24]:
			draw_line(Vector2(x, -35), Vector2(-x, 28), color, 3)
