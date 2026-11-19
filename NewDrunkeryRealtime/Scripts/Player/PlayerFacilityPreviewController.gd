extends RefCounted

## Owns the visual representation of a carried facility and its placement preview.

const CarryController = preload("res://Scripts/Player/PlayerFacilityCarryController.gd")

var player: Node2D
var carry_controller: CarryController
var hand_preview_root: Node2D
var preview_body_offset: Vector2 = Vector2(0, -22)
var preview_tint_strength: float = 0.8
var preview_max_size: Vector2 = Vector2(132, 112)
var place_valid_color: Color = Color(1.0, 0.78, 0.22, 0.32)
var place_invalid_color: Color = Color(1.0, 0.18, 0.12, 0.34)
var place_outline_valid_color: Color = Color(1.0, 0.92, 0.48, 0.92)
var place_outline_invalid_color: Color = Color(1.0, 0.24, 0.16, 0.95)
var place_origin_color: Color = Color(0.22, 0.68, 1.0, 0.30)
var place_origin_outline_color: Color = Color(0.48, 0.9, 1.0, 0.86)

func setup(new_player: Node2D, new_carry_controller: CarryController, config: Dictionary) -> void:
	player = new_player
	carry_controller = new_carry_controller
	preview_body_offset = config.get("preview_body_offset", preview_body_offset)
	preview_max_size = config.get("preview_max_size", preview_max_size)
	preview_tint_strength = config.get("preview_tint_strength", preview_tint_strength)
	place_valid_color = config.get("place_valid_color", place_valid_color)
	place_invalid_color = config.get("place_invalid_color", place_invalid_color)
	place_outline_valid_color = config.get("place_outline_valid_color", place_outline_valid_color)
	place_outline_invalid_color = config.get("place_outline_invalid_color", place_outline_invalid_color)
	place_origin_color = config.get("place_origin_color", place_origin_color)
	place_origin_outline_color = config.get("place_origin_outline_color", place_origin_outline_color)
	# The visual child follows the player lifetime; this controller stays RefCounted.
	hand_preview_root = Node2D.new()
	hand_preview_root.name = "CarriedFacilityPreview"
	hand_preview_root.z_index = 23
	hand_preview_root.visible = false
	player.add_child(hand_preview_root)

func get_hand_preview_root() -> Node2D:
	return hand_preview_root

# Called only during the host player's _draw notification.
func draw_placement() -> void:
	if not is_instance_valid(carry_controller.get_carried_facility()) or carry_controller.get_placement_rect().size == Vector2.ZERO:
		return
	var preview_data_list: Array[Dictionary] = carry_controller.get_sprite_previews()
	_draw_origin_preview()
	var fill_color: Color = place_valid_color if carry_controller.can_place_facility() else place_invalid_color
	var outline_color: Color = place_outline_valid_color if carry_controller.can_place_facility() else place_outline_invalid_color
	if preview_data_list.is_empty():
		_draw_fallback_visual(carry_controller.get_placement_position(), fill_color, outline_color)
	else:
		_draw_sprite_preview(carry_controller.get_placement_position(), 1.0, fill_color)

func _on_preview_changed() -> void:
	player.queue_redraw()
	if carry_controller == null:
		return
	var carried_facility := carry_controller.get_carried_facility()
	var sprite_previews: Array[Dictionary] = carry_controller.get_sprite_previews()
	if not is_instance_valid(hand_preview_root):
		return

	for child in hand_preview_root.get_children():
		hand_preview_root.remove_child(child)
		child.queue_free()

	if not is_instance_valid(carried_facility) or sprite_previews.is_empty():
		if not is_instance_valid(carried_facility):
			hand_preview_root.visible = false
			return
		hand_preview_root.visible = true
		hand_preview_root.position = preview_body_offset
		_add_fallback_hand_preview(hand_preview_root)
		return

	hand_preview_root.visible = true
	hand_preview_root.position = preview_body_offset
	var preview_bounds: Rect2 = _get_preview_bounds()
	var preview_scale: float = _get_hand_preview_scale(preview_bounds)
	_add_hand_sprites(hand_preview_root, preview_scale)

func _add_fallback_hand_preview(parent: Node2D) -> void:
	var carried_facility := carry_controller.get_carried_facility()
	if not is_instance_valid(carried_facility):
		return
	var preview_data: Dictionary = {}
	if carried_facility.has_method("get_facility_preview_data"):
		preview_data = carried_facility.get_facility_preview_data()
	var source_size: Vector2 = preview_data.get("body_size", Vector2.ZERO)
	if source_size == Vector2.ZERO and carried_facility.has_method("get_interaction_rect_global"):
		var rect_variant: Variant = carried_facility.get_interaction_rect_global()
		if rect_variant is Rect2:
			source_size = rect_variant.size
	if source_size == Vector2.ZERO:
		source_size = Vector2(104.0, 104.0)
	var max_size: Vector2 = preview_max_size
	var preview_scale: float = minf(1.0, minf(max_size.x / maxf(source_size.x, 1.0), max_size.y / maxf(source_size.y, 1.0)))
	var half_size := source_size * preview_scale * 0.5
	var base_color: Color = preview_data.get("base_color", Color(0.42, 0.82, 1.0, 0.48))
	var outline_color: Color = preview_data.get("outline_color", Color(0.82, 0.96, 1.0, 0.95))
	var fill := Polygon2D.new()
	fill.polygon = PackedVector2Array([
		Vector2(-half_size.x, -half_size.y), Vector2(half_size.x, -half_size.y),
		Vector2(half_size.x, half_size.y), Vector2(-half_size.x, half_size.y)
	])
	fill.color = Color(base_color.r, base_color.g, base_color.b, 0.82)
	fill.position = Vector2.ZERO
	parent.add_child(fill)
	var outline := Line2D.new()
	outline.points = PackedVector2Array([
		Vector2(-half_size.x, -half_size.y), Vector2(half_size.x, -half_size.y),
		Vector2(half_size.x, half_size.y), Vector2(-half_size.x, half_size.y),
		Vector2(-half_size.x, -half_size.y)
	])
	outline.width = 4.0
	outline.default_color = outline_color
	parent.add_child(outline)
	if StringName(preview_data.get("facility_type", &"")) == &"stone_cabinet":
		var crack_color := Color(0.42, 0.44, 0.45, 0.95)
		for crack_points in [
			PackedVector2Array([Vector2(-34.0, -16.0), Vector2(-10.0, -25.0)]),
			PackedVector2Array([Vector2(6.0, -28.0), Vector2(32.0, -10.0)]),
			PackedVector2Array([Vector2(-28.0, 18.0), Vector2(18.0, 8.0)])
		]:
			var crack := Line2D.new()
			crack.points = crack_points
			crack.scale = Vector2.ONE * preview_scale
			crack.width = 4.0
			crack.default_color = crack_color
			parent.add_child(crack)

func _draw_origin_preview() -> void:
	var preview_data_list: Array[Dictionary] = carry_controller.get_sprite_previews()
	var original_position: Vector2 = carry_controller.get_original_position()
	var placement_size: Vector2 = carry_controller.get_placement_rect().size
	var origin_rect := Rect2(player.to_local(original_position) - placement_size * 0.5, placement_size)
	if preview_data_list.is_empty():
		_draw_fallback_visual(original_position, place_origin_color, place_origin_outline_color)
		return
	_draw_sprite_preview(original_position, 1.0, place_origin_color)
	player.draw_rect(origin_rect, place_origin_outline_color, false, 3.0)

func _draw_sprite_preview(anchor_position: Vector2, preview_scale_multiplier: float, tint_color: Color) -> void:
	var preview_data_list: Array[Dictionary] = carry_controller.get_sprite_previews()
	for preview_data in preview_data_list:
		var texture: Texture2D = preview_data.get("texture", null)
		if texture == null:
			continue
		var source_size: Vector2 = preview_data.get("source_size", Vector2.ZERO)
		if source_size.x <= 0.0 or source_size.y <= 0.0:
			continue
		var preview_scale: Vector2 = preview_data.get("scale", Vector2.ONE)
		preview_scale *= preview_scale_multiplier
		var draw_size := Vector2(source_size.x * absf(preview_scale.x), source_size.y * absf(preview_scale.y))
		var relative_position: Vector2 = preview_data.get("relative_position", Vector2.ZERO) * preview_scale_multiplier
		var sprite_offset: Vector2 = preview_data.get("offset", Vector2.ZERO)
		var draw_center: Vector2 = anchor_position + relative_position + sprite_offset * preview_scale
		var draw_rect := Rect2(player.to_local(draw_center) - draw_size * 0.5, draw_size)
		if bool(preview_data.get("flip_h", false)):
			draw_rect.size.x *= -1.0
			draw_rect.position.x += absf(draw_rect.size.x)
		if bool(preview_data.get("flip_v", false)):
			draw_rect.size.y *= -1.0
			draw_rect.position.y += absf(draw_rect.size.y)
		_draw_preview_texture(
			texture,
			draw_rect,
			bool(preview_data.get("region_enabled", false)),
			preview_data.get("region_rect", Rect2()),
			Color(1.0, 1.0, 1.0, 0.72)
		)
		var overlay_color := tint_color
		overlay_color.a *= clampf(preview_tint_strength, 0.0, 1.0)
		var silhouette_texture: Texture2D = preview_data.get("silhouette_texture", null)
		if silhouette_texture != null:
			_draw_preview_texture(
				silhouette_texture,
				draw_rect,
				bool(preview_data.get("silhouette_region_enabled", false)),
				preview_data.get("silhouette_region_rect", Rect2()),
				overlay_color
			)
		else:
			_draw_preview_texture(
				texture,
				draw_rect,
				bool(preview_data.get("region_enabled", false)),
				preview_data.get("region_rect", Rect2()),
				overlay_color
			)

func _draw_fallback_visual(anchor_position: Vector2, fill_color: Color, outline_color: Color) -> void:
	var carried_facility := carry_controller.get_carried_facility()
	if not is_instance_valid(carried_facility):
		return
	var body_size: Vector2 = Vector2(104.0, 104.0)
	var base_color: Color = Color(0.42, 0.36, 0.28, 1.0)
	var accent_color: Color = Color(0.95, 0.72, 0.28, 1.0)
	var facility_outline: Color = outline_color
	var preview_data: Dictionary = {}
	if carried_facility.has_method("get_facility_preview_data"):
		preview_data = carried_facility.get_facility_preview_data()
	if preview_data.has("body_size"):
		body_size = preview_data.get("body_size", body_size)
	else:
		var body_size_variant: Variant = carried_facility.get("body_size")
		if body_size_variant is Vector2:
			body_size = body_size_variant
	base_color = preview_data.get("base_color", base_color)
	accent_color = preview_data.get("accent_color", accent_color)
	facility_outline = preview_data.get("outline_color", facility_outline)
	var preview_scale: float = minf(1.0, minf(preview_max_size.x / maxf(body_size.x, 1.0), preview_max_size.y / maxf(body_size.y, 1.0)))
	var rect := Rect2(player.to_local(anchor_position) - body_size * preview_scale * 0.5, body_size * preview_scale)
	var tinted_base := base_color.lerp(fill_color, 0.45)
	var tinted_accent := accent_color.lerp(fill_color, 0.55)
	player.draw_rect(rect, tinted_base, true)
	player.draw_rect(rect.grow(-8.0 * preview_scale), tinted_accent, true)
	var facility_type: StringName = StringName(preview_data.get("facility_type", &""))
	var center := player.to_local(anchor_position)
	if facility_type == &"conveyor":
		var direction_sign: float = -1.0 if int(carried_facility.get("conveyor_direction")) < 0 else 1.0
		player.draw_line(center - Vector2(42.0 * direction_sign, 0.0) * preview_scale, center + Vector2(42.0 * direction_sign, 0.0) * preview_scale, fill_color.lightened(0.25), maxf(6.0 * preview_scale, 2.0))
		player.draw_colored_polygon(PackedVector2Array([
			center + Vector2(30.0 * direction_sign, -14.0) * preview_scale,
			center + Vector2(48.0 * direction_sign, 0.0) * preview_scale,
			center + Vector2(30.0 * direction_sign, 14.0) * preview_scale
		]), fill_color.lightened(0.35))
	elif facility_type == &"lamp":
		player.draw_colored_polygon(PackedVector2Array([
			center + Vector2(-24.0, -24.0) * preview_scale,
			center + Vector2(24.0, -24.0) * preview_scale,
			center + Vector2(34.0, 2.0) * preview_scale,
			center + Vector2(-34.0, 2.0) * preview_scale
		]), fill_color.lightened(0.3))
	elif facility_type == &"stone_cabinet":
		player.draw_line(center + Vector2(-34.0, -16.0) * preview_scale, center + Vector2(-10.0, -25.0) * preview_scale, Color(0.42, 0.44, 0.45, 0.95), maxf(4.0 * preview_scale, 2.0), true)
		player.draw_line(center + Vector2(6.0, -28.0) * preview_scale, center + Vector2(32.0, -10.0) * preview_scale, Color(0.18, 0.20, 0.21, 0.95), maxf(4.0 * preview_scale, 2.0), true)
		player.draw_line(center + Vector2(-28.0, 18.0) * preview_scale, center + Vector2(18.0, 8.0) * preview_scale, Color(0.16, 0.18, 0.19, 0.95), maxf(4.0 * preview_scale, 2.0), true)
	player.draw_rect(rect, facility_outline, false, maxf(3.0 * preview_scale, 2.0))

func _draw_preview_texture(texture: Texture2D, draw_rect: Rect2, region_enabled: bool, region_rect: Rect2, modulate: Color) -> void:
	if region_enabled:
		player.draw_texture_rect_region(texture, draw_rect, region_rect, modulate)
	else:
		player.draw_texture_rect(texture, draw_rect, false, modulate)

func _add_hand_sprites(parent: Node2D, preview_scale_multiplier: float) -> void:
	var layer_index: int = 0
	var preview_data_list: Array[Dictionary] = carry_controller.get_sprite_previews()
	for preview_data in preview_data_list:
		var texture: Texture2D = preview_data.get("texture", null)
		if texture == null:
			continue
		var relative_position: Vector2 = preview_data.get("relative_position", Vector2.ZERO) * preview_scale_multiplier
		var sprite_offset: Vector2 = preview_data.get("offset", Vector2.ZERO)
		var preview_scale: Vector2 = preview_data.get("scale", Vector2.ONE) * preview_scale_multiplier

		var base_sprite := Sprite2D.new()
		base_sprite.texture = texture
		base_sprite.region_enabled = bool(preview_data.get("region_enabled", false))
		base_sprite.region_rect = preview_data.get("region_rect", Rect2())
		base_sprite.offset = sprite_offset
		base_sprite.position = relative_position
		base_sprite.scale = preview_scale
		base_sprite.flip_h = bool(preview_data.get("flip_h", false))
		base_sprite.flip_v = bool(preview_data.get("flip_v", false))
		base_sprite.modulate = Color.WHITE
		base_sprite.z_index = layer_index * 2
		parent.add_child(base_sprite)

		layer_index += 1

func _get_preview_bounds() -> Rect2:
	var has_bounds: bool = false
	var bounds := Rect2()
	var preview_data_list: Array[Dictionary] = carry_controller.get_sprite_previews()
	for preview_data in preview_data_list:
		var source_size: Vector2 = preview_data.get("source_size", Vector2.ZERO)
		if source_size.x <= 0.0 or source_size.y <= 0.0:
			continue
		var preview_scale: Vector2 = preview_data.get("scale", Vector2.ONE)
		var draw_size := Vector2(source_size.x * absf(preview_scale.x), source_size.y * absf(preview_scale.y))
		var relative_position: Vector2 = preview_data.get("relative_position", Vector2.ZERO)
		var sprite_offset: Vector2 = preview_data.get("offset", Vector2.ZERO)
		var draw_center: Vector2 = relative_position + sprite_offset * preview_scale
		var sprite_rect := Rect2(draw_center - draw_size * 0.5, draw_size)
		if not has_bounds:
			bounds = sprite_rect
			has_bounds = true
		else:
			bounds = bounds.merge(sprite_rect)
	return bounds if has_bounds else Rect2()

func _get_hand_preview_scale(preview_bounds: Rect2) -> float:
	if preview_bounds.size.x <= 0.0 or preview_bounds.size.y <= 0.0:
		return 1.0
	var width_scale: float = preview_max_size.x / preview_bounds.size.x
	var height_scale: float = preview_max_size.y / preview_bounds.size.y
	return minf(1.0, minf(width_scale, height_scale))

