extends Node2D

## Item contents, portion counts and physical processing marks.
const TestItemDefs = preload("res://Scripts/Kitchen/TestItemDefs.gd")

@export var process_state: StringName = TestItemDefs.PROCESS_STATE_NONE
var item_id: StringName = &""
var payload: Dictionary = {}
var count_label: Label
## Size of the visible X relative to the parent item sprite.
@export_range(8.0, 48.0, 1.0) var mark_half_size: float = 20.0
@export_range(1.0, 12.0, 1.0) var outline_width: float = 7.0
@export_range(1.0, 8.0, 1.0) var line_width: float = 3.0

const MARK_OUTLINE_COLOR := Color(0.18, 0.07, 0.04, 0.96)
const MARK_LINE_COLOR := Color(1.0, 0.82, 0.28, 1.0)
const GRIND_COARSE_BADGE_COLOR := Color("8a5836")
const GRIND_FINE_BADGE_COLOR := Color("101014")
const GRIND_BADGE_OUTLINE_COLOR := Color("302217")

func set_process_state(new_process_state: StringName, has_item: bool = true) -> void:
	process_state = TestItemDefs.normalize_process_state(new_process_state)
	visible = has_item and process_state == TestItemDefs.PROCESS_STATE_CUT
	queue_redraw()

func set_item_data(new_item_id: StringName, state: StringName, data: Dictionary, has_item: bool = true) -> void:
	item_id = new_item_id
	payload = data.duplicate(true)
	process_state = TestItemDefs.normalize_process_state(state)
	if item_id == TestItemDefs.SEASONING_BOX_ID:
		process_state = TestItemDefs.normalize_process_state(StringName(payload.get("process_state", process_state)))
	visible = has_item
	if count_label == null:
		count_label = Label.new()
		count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		count_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		count_label.add_theme_color_override("font_color", Color.WHITE)
		count_label.add_theme_color_override("font_outline_color", Color("302217"))
		add_child(count_label)
	var is_seasoning: bool = item_id == TestItemDefs.SEASONING_BOX_ID
	count_label.position = Vector2(-80, 40) if is_seasoning else Vector2(-55, 44)
	count_label.size = Vector2(160, 76) if is_seasoning else Vector2(110, 40)
	count_label.add_theme_font_size_override("font_size", 56 if is_seasoning else 32)
	count_label.add_theme_constant_override("outline_size", 10 if is_seasoning else 6)
	count_label.text = ""
	if item_id == TestItemDefs.SEASONING_BOX_ID:
		count_label.text = str(int(payload.get("servings", 0)))
	elif item_id == TestItemDefs.PLATE_ID:
		count_label.text = "%d/6" % Array(payload.get("items", [])).size()
	queue_redraw()

func _ready() -> void:
	set_process_state(process_state)

func _draw() -> void:
	if item_id == TestItemDefs.SEASONING_BOX_ID:
		var texture: Texture2D = TestItemDefs.get_item_texture(StringName(payload.get("item_id", &"")))
		if texture != null:
			draw_texture_rect(texture, Rect2(-42, -34, 84, 72), false)
		_draw_grind_box_badge()
		return
	elif item_id == TestItemDefs.PLATE_ID:
		var entries: Array = payload.get("items", [])
		for i in range(entries.size()):
			var texture: Texture2D = TestItemDefs.get_item_texture(StringName(entries[i].get("item_id", &"")))
			if texture != null:
				draw_texture_rect(texture, Rect2(Vector2(-42 + (i % 3) * 28, -25 + (i / 3) * 28), Vector2(28,28)), false, TestItemDefs.get_item_modulate(StringName(entries[i].get("process_state", &""))))
	if process_state != TestItemDefs.PROCESS_STATE_CUT:
		return
	# Keep the source sprite completely intact and draw a compact, high-contrast
	# X over its centre. The dark under-stroke keeps the mark readable on both
	# light and dark pixel-art ingredients.
	var diagonal := Vector2(mark_half_size, mark_half_size)
	draw_line(-diagonal, diagonal, MARK_OUTLINE_COLOR, outline_width, true)
	draw_line(Vector2(-mark_half_size, mark_half_size), Vector2(mark_half_size, -mark_half_size), MARK_OUTLINE_COLOR, outline_width, true)
	draw_line(-diagonal, diagonal, MARK_LINE_COLOR, line_width, true)
	draw_line(Vector2(-mark_half_size, mark_half_size), Vector2(mark_half_size, -mark_half_size), MARK_LINE_COLOR, line_width, true)

func _draw_grind_box_badge() -> void:
	# Printed on the box so storage can be identified without a floating bubble.
	var grind_state: StringName = process_state
	if grind_state not in [TestItemDefs.PROCESS_STATE_GRIND_COARSE, TestItemDefs.PROCESS_STATE_GRIND_FINE]:
		return
	var badge_color: Color = GRIND_COARSE_BADGE_COLOR if grind_state == TestItemDefs.PROCESS_STATE_GRIND_COARSE else GRIND_FINE_BADGE_COLOR
	var badge_rect := Rect2(20, -38, 42, 38)
	draw_rect(badge_rect, GRIND_BADGE_OUTLINE_COLOR, true)
	draw_rect(Rect2(23, -35, 36, 32), badge_color, true)
	var icon: Texture2D = TestItemDefs.get_process_icon_texture(grind_state)
	if icon != null:
		draw_texture_rect(icon, Rect2(25, -33, 32, 28), false)
	# A second, larger color stripe remains readable when the icon is scaled down.
	draw_rect(Rect2(-38, 25, 76, 7), badge_color, true)
