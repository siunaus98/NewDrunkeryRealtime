extends Node2D

@export var size: Vector2 = Vector2(96.0, 12.0)
@export var background_color: Color = Color(0.12, 0.08, 0.06, 0.78)
@export var fill_color: Color = Color(1.0, 0.74, 0.28, 0.95)
@export var border_color: Color = Color(0.34, 0.18, 0.08, 0.95)
@export var border_width: float = 2.0
@export var stage_separator_color: Color = Color(0.08, 0.06, 0.05, 0.96)
@export var stage_separator_width: float = 4.0

var progress: float = 0.0
var is_active: bool = false
var display_mode: StringName = &"single"
var stage_index: int = 0
var stage_progress: float = 0.0
var stage_boundaries: Array = []
var stage_colors: Array = []
var maturity_icon: TextureRect

func set_maturity_icon(texture: Texture2D, icon_size: Vector2 = Vector2(24, 24)) -> void:
	if maturity_icon == null:
		maturity_icon = TextureRect.new()
		maturity_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		maturity_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		maturity_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		add_child(maturity_icon)
	maturity_icon.texture = texture
	maturity_icon.size = icon_size
	maturity_icon.position = Vector2(size.x * 0.5 + size.y * 0.25, -icon_size.y * 0.5)
	maturity_icon.visible = texture != null

func _ready() -> void:
	visible = false

func set_state(active: bool, new_progress: float) -> void:
	if maturity_icon != null:
		maturity_icon.hide()
	is_active = active
	progress = clampf(new_progress, 0.0, 1.0)
	display_mode = &"single"
	stage_index = 0
	stage_progress = progress
	stage_boundaries.clear()
	stage_colors.clear()
	visible = is_active
	queue_redraw()

func set_stage_state(
	active: bool,
	new_progress: float,
	new_stage_index: int,
	new_stage_progress: float,
	new_stage_boundaries: Array = [],
	new_stage_colors: Array = [],
	new_display_mode: StringName = &"split"
) -> void:
	if maturity_icon != null:
		maturity_icon.hide()
	is_active = active
	progress = clampf(new_progress, 0.0, 1.0)
	stage_index = maxi(new_stage_index, 0)
	stage_progress = clampf(new_stage_progress, 0.0, 1.0)
	stage_boundaries = new_stage_boundaries.duplicate()
	stage_colors = new_stage_colors.duplicate()
	display_mode = new_display_mode
	visible = is_active
	queue_redraw()

func _draw() -> void:
	if not is_active:
		return

	var rect := Rect2(Vector2(-size.x * 0.5, -size.y * 0.5), size)
	if display_mode == &"stage_single":
		_draw_stage_single(rect)
		return
	if display_mode == &"segmented":
		_draw_segmented(rect)
		return
	if display_mode == &"split":
		_draw_split(rect)
		return

	draw_rect(rect, background_color, true)

	if progress > 0.0:
		var fill_rect := Rect2(rect.position, Vector2(rect.size.x * progress, rect.size.y))
		draw_rect(fill_rect, fill_color, true)

	draw_rect(rect, border_color, false, border_width)

func _draw_stage_single(rect: Rect2) -> void:
	draw_rect(rect, background_color, true)

	if stage_progress > 0.0:
		var fill_rect := Rect2(rect.position, Vector2(rect.size.x * stage_progress, rect.size.y))
		draw_rect(fill_rect, _get_stage_color(stage_index), true)

	draw_rect(rect, border_color, false, border_width)

func _draw_segmented(rect: Rect2) -> void:
	var boundaries := _get_normalized_boundaries()
	var segment_count: int = boundaries.size() - 1
	if segment_count <= 0:
		draw_rect(rect, background_color, true)
		draw_rect(rect, border_color, false, border_width)
		return

	for index in range(segment_count):
		var start: float = boundaries[index]
		var end: float = boundaries[index + 1]
		var segment_rect := Rect2(
			rect.position.x + rect.size.x * start,
			rect.position.y,
			rect.size.x * (end - start),
			rect.size.y
		)
		draw_rect(segment_rect, background_color, true)

		var segment_progress: float = _get_segment_progress(start, end)
		if segment_progress > 0.0:
			draw_rect(
				Rect2(segment_rect.position, Vector2(segment_rect.size.x * segment_progress, segment_rect.size.y)),
				_get_stage_color(index),
				true
			)

		if index > 0:
			draw_line(
				Vector2(segment_rect.position.x, rect.position.y),
				Vector2(segment_rect.position.x, rect.end.y),
				stage_separator_color,
				stage_separator_width
			)

	draw_rect(rect, border_color, false, border_width)

func _draw_split(rect: Rect2) -> void:
	draw_rect(rect, background_color, true)
	var boundaries := _get_normalized_boundaries()
	for index in range(boundaries.size() - 1):
		var start: float = boundaries[index]
		var end: float = boundaries[index + 1]
		var segment_progress: float = _get_segment_progress(start, end)
		if segment_progress <= 0.0:
			continue
		var segment_rect := Rect2(
			rect.position.x + rect.size.x * start,
			rect.position.y,
			rect.size.x * (end - start) * segment_progress,
			rect.size.y
		)
		draw_rect(segment_rect, _get_stage_color(index), true)

	for index in range(1, boundaries.size() - 1):
		var x: float = rect.position.x + rect.size.x * boundaries[index]
		draw_line(
			Vector2(x, rect.position.y),
			Vector2(x, rect.end.y),
			stage_separator_color,
			stage_separator_width
		)

	draw_rect(rect, border_color, false, border_width)

func _get_normalized_boundaries() -> Array[float]:
	var result: Array[float] = [0.0]
	for boundary in stage_boundaries:
		var normalized_boundary: float = clampf(float(boundary), 0.0, 1.0)
		if normalized_boundary > result.back() and normalized_boundary < 1.0:
			result.append(normalized_boundary)
	if result.back() < 1.0:
		result.append(1.0)
	return result

func _get_segment_progress(start: float, end: float) -> float:
	if progress <= start:
		return 0.0
	if progress >= end:
		return 1.0
	return clampf((progress - start) / maxf(end - start, 0.001), 0.0, 1.0)

func _get_stage_color(index: int) -> Color:
	if index >= 0 and index < stage_colors.size() and stage_colors[index] is Color:
		return stage_colors[index]
	return fill_color
