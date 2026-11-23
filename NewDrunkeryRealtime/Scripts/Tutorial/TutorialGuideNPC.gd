extends Node2D

var tutorial: Node
var speech_label: Label
var halo_time := 0.0
var highlighted := false

func _ready() -> void:
	z_index = 14
	# Compact one-cell mascot. The drawing itself is intentionally simple and
	# round so the guide reads as a cute floating chibi, not a miniature adult.
	scale = Vector2.ONE * 0.72
	speech_label = Label.new()
	speech_label.text = "小沙"
	speech_label.position = Vector2(-105, 53)
	speech_label.size = Vector2(210, 30)
	speech_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	speech_label.add_theme_font_size_override("font_size", 14)
	speech_label.add_theme_color_override("font_color", Color("fff0b6"))
	speech_label.add_theme_color_override("font_outline_color", Color("4b3425"))
	speech_label.add_theme_constant_override("outline_size", 5)
	add_child(speech_label)
	queue_redraw()

func _process(delta: float) -> void:
	halo_time += delta
	queue_redraw()

func _draw() -> void:
	draw_set_transform(Vector2(0, 28))
	var bob := sin(halo_time * 2.2) * 2.0
	var face := Vector2(0, -42 + bob)
	# A tiny halo is the only angel cue; the silhouette is a round mascot.
	draw_arc(face + Vector2(0, -52), 18.0, PI + 0.15, TAU - 0.15, 24, Color("f4d879"), 4, true)
	# Two floating ball hands.
	draw_circle(Vector2(-48, -25 + bob), 13.0, Color("f3c6a2"))
	draw_circle(Vector2(48, -25 + bob), 13.0, Color("f3c6a2"))
	draw_arc(Vector2(-48, -25 + bob), 13.0, 0, TAU, 20, Color("76554b"), 2.5, true)
	draw_arc(Vector2(48, -25 + bob), 13.0, 0, TAU, 20, Color("76554b"), 2.5, true)
	# Soft bean body tucked under the head.
	draw_colored_polygon(PackedVector2Array([Vector2(-25, -13 + bob), Vector2(25, -13 + bob), Vector2(31, 18 + bob), Vector2(-31, 18 + bob)]), Color("9bc8bd"))
	draw_arc(Vector2(0, 2 + bob), 31.0, 0, PI, 20, Color("67534c"), 3, true)
	# Oversized sparkling eyes, blush and a tiny happy mouth.
	draw_circle(face + Vector2(-17, 0), 13.0, Color("fff9e9"))
	draw_circle(face + Vector2(17, 0), 13.0, Color("fff9e9"))
	draw_circle(face + Vector2(-14, 2), 6.5, Color("4c4a55"))
	draw_circle(face + Vector2(14, 2), 6.5, Color("4c4a55"))
	draw_circle(face + Vector2(-16, -2), 2.4, Color.WHITE)
	draw_circle(face + Vector2(12, -2), 2.4, Color.WHITE)
	draw_circle(face + Vector2(-29, 16), 5.0, Color("ef9c9c"))
	draw_circle(face + Vector2(29, 16), 5.0, Color("ef9c9c"))
	draw_arc(face + Vector2(0, 15), 7.0, 0.15, PI - 0.15, 12, Color("9b5e68"), 2.5, true)
	# Round head outline last, with a small top tuft.
	draw_circle(face, 43.0, Color("f3c6a2"))
	draw_arc(face, 43.0, 0, TAU, 40, Color("67534c"), 3, true)
	draw_colored_polygon(PackedVector2Array([Vector2(-13, -82 + bob), Vector2(0, -96 + bob), Vector2(13, -82 + bob), Vector2(0, -75 + bob)]), Color("d4e1c7"))
	# Redraw eyes over the head fill.
	draw_circle(face + Vector2(-17, 0), 13.0, Color("fff9e9"))
	draw_circle(face + Vector2(17, 0), 13.0, Color("fff9e9"))
	draw_circle(face + Vector2(-14, 2), 6.5, Color("4c4a55"))
	draw_circle(face + Vector2(14, 2), 6.5, Color("4c4a55"))
	draw_circle(face + Vector2(-16, -2), 2.4, Color.WHITE)
	draw_circle(face + Vector2(12, -2), 2.4, Color.WHITE)
	draw_circle(face + Vector2(-29, 16), 5.0, Color("ef9c9c"))
	draw_circle(face + Vector2(29, 16), 5.0, Color("ef9c9c"))
	draw_arc(face + Vector2(0, 15), 7.0, 0.15, PI - 0.15, 12, Color("9b5e68"), 2.5, true)
	if highlighted:
		draw_arc(Vector2.ZERO, 62.0 + sin(halo_time * 4.0) * 4.0, 0, TAU, 36, Color("ffe18b"), 3, true)

func is_pickup_drop_focusable(_player: Node) -> bool:
	return true

func get_pickup_drop_radius() -> float:
	return 180.0

func get_interaction_rect_global() -> Rect2:
	return Rect2(global_position - Vector2(54, 100), Vector2(108, 140))

func get_pickup_drop_positions() -> Array[Vector2]:
	return [global_position]

func get_interaction_button_prompt(_player: Node) -> String:
	return ""

func interact_with_player(_player: Node) -> bool:
	return false

func set_pickup_drop_highlight(active: bool) -> void:
	highlighted = active
	queue_redraw()

func set_current_hint(_text: String) -> void:
	if speech_label != null:
		speech_label.text = "小沙"
