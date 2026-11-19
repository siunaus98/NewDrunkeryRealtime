extends CanvasLayer

const Defs = preload("res://Scripts/Progression/NightEventDefs.gd")
const CARD_SIZE: Vector2 = Vector2(202, 76)
const GAP: float = 12.0

var cards: Dictionary = {}

func _ready() -> void:
	layer = 42

func update_targets(targets: Dictionary) -> void:
	for id: StringName in cards.keys():
		if not targets.has(id):
			cards[id].free()
			cards.erase(id)
	var rect: Rect2 = get_viewport().get_visible_rect()
	# Keep cards clear of the right-hand resource HUD and the bottom hotbar.
	var safe: Rect2 = rect.grow_individual(-64, -260, -250, -170)
	var center: Vector2 = safe.get_center()
	var reach: Vector2 = (safe.size * 0.5 - CARD_SIZE * 0.5).max(Vector2.ONE)
	var edges: Dictionary = {&"left": [], &"right": [], &"top": [], &"bottom": []}
	for id: StringName in targets:
		if not cards.has(id):
			cards[id] = _create_card(id)
		var card: Control = cards[id]
		var npc: Node2D = targets[id]
		var point: Vector2 = npc.get_global_transform_with_canvas() * Vector2(0, -48)
		card.visible = npc.is_visible_in_tree() and not rect.has_point(point)
		if not card.visible:
			continue
		var direction: Vector2 = point - center
		var ratio: Vector2 = direction / reach
		var position_on_edge: Vector2 = center + direction / maxf(absf(ratio.x), absf(ratio.y))
		var edge: StringName
		if absf(ratio.x) > absf(ratio.y):
			edge = &"right" if direction.x > 0 else &"left"
		else:
			edge = &"bottom" if direction.y > 0 else &"top"
		card.position = position_on_edge - CARD_SIZE * 0.5
		var arrow: Polygon2D = card.get_node("Arrow")
		arrow.position = CARD_SIZE * 0.5
		if edge in [&"left", &"right"]:
			arrow.position.x += (CARD_SIZE.x * 0.5 + 12) * signf(direction.x)
		else:
			arrow.position.y += (CARD_SIZE.y * 0.5 + 12) * signf(direction.y)
		arrow.rotation = direction.angle()
		edges[edge].append(card)
	for edge: StringName in edges:
		_arrange_cards(edges[edge], edge in [&"left", &"right"], safe)

func _create_card(id: StringName) -> Control:
	var card: Panel = Panel.new()
	card.size = CARD_SIZE
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color("302c29")
	style.border_color = Color("e5bd72")
	style.set_border_width_all(3)
	style.set_corner_radius_all(10)
	preload("res://Scripts/UI/AtelierStyle.gd").finish(style)
	card.add_theme_stylebox_override("panel", style)
	add_child(card)
	var portrait: TextureRect = TextureRect.new()
	portrait.position = Vector2(8, 4)
	portrait.size = Vector2(52, 68)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.texture = load("res://ArtResource/Events/%s.svg" % id)
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(portrait)
	var label: Label = Label.new()
	label.position = Vector2(64, 8)
	label.size = Vector2(132, 60)
	label.text = "%s\n! 可交谈" % Defs.TITLES[id]
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_color", Color("ffe1a0"))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(label)
	var arrow: Polygon2D = Polygon2D.new()
	arrow.name = "Arrow"
	arrow.polygon = PackedVector2Array([Vector2(15, 0), Vector2(-10, -11), Vector2(-10, 11)])
	arrow.color = Color("ffe1a0")
	card.add_child(arrow)
	return card

func _arrange_cards(group: Array, vertical: bool, rect: Rect2) -> void:
	if group.is_empty():
		return
	group.sort_custom(func(a: Control, b: Control) -> bool:
		return a.position.y < b.position.y if vertical else a.position.x < b.position.x)
	var extent: float = CARD_SIZE.y if vertical else CARD_SIZE.x
	var next_start: float = rect.position.y if vertical else rect.position.x
	for card: Control in group:
		var desired: float = card.position.y if vertical else card.position.x
		var start: float = maxf(desired, next_start)
		if vertical:
			card.position.y = start
		else:
			card.position.x = start
		next_start = start + extent + GAP
	var end: float = rect.end.y if vertical else rect.end.x
	var overflow: float = maxf(next_start - GAP - end, 0.0)
	for card: Control in group:
		if vertical:
			card.position.y -= overflow
		else:
			card.position.x -= overflow
