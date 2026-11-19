extends RefCounted

const AudioCue = preload("res://Scripts/Audio/AudioCue.gd")

## Owns carry state and commits placement. Geometry is read-only; the player
## supplies permissions and input; preview_changed notifies the visual controller.
const PlacementQuery = preload("res://Scripts/Player/FacilityPlacementQuery.gd")
signal preview_changed

var player: Node2D
var carried_facility: Node2D
var original_position: Vector2 = Vector2.ZERO
var original_visible: bool = true
var collision_states: Array[Dictionary] = []
var placement_rect: Rect2 = Rect2()
var placement_position: Vector2 = Vector2.ZERO
var can_place: bool = false
var sprite_previews: Array[Dictionary] = []

func setup(new_player: Node2D) -> void:
	player = new_player

func tick(rearrange_allowed: bool) -> void:
	if not is_instance_valid(player):
		return
	if not is_carrying():
		if not collision_states.is_empty() or can_place:
			_restore_collision_states()
			_clear_carry()
		return
	if not rearrange_allowed:
		cancel_carry()
		return
	refresh_placement()

func is_carrying() -> bool:
	return is_instance_valid(carried_facility)

func get_carried_facility() -> Node2D:
	return carried_facility

func get_original_position() -> Vector2:
	return original_position

func get_placement_rect() -> Rect2:
	return placement_rect

func get_placement_position() -> Vector2:
	return placement_position

func can_place_facility() -> bool:
	return can_place

func calculate_placement() -> Dictionary:
	if not is_carrying():
		return {"valid": false}
	return PlacementQuery.calculate(player, carried_facility)

func refresh_placement() -> void:
	var result := calculate_placement()
	placement_rect = result.get("rect", Rect2())
	placement_position = result.get("position", Vector2.ZERO)
	can_place = bool(result.get("valid", false))

func pick_up(facility: Node2D) -> bool:
	if is_carrying() or not is_instance_valid(facility):
		return false
	if facility.has_method("can_be_moved_by_player") and not facility.can_be_moved_by_player(player):
		return false
	carried_facility = facility
	facility.set_meta("facility_carrier", weakref(player))
	original_position = facility.global_position
	original_visible = facility.visible
	collision_states = _disable_facility_collision(facility)
	capture_preview(facility)
	if facility.has_method("set_facility_carried"):
		facility.set_facility_carried(true)
	if facility.has_method("set_pickup_drop_highlight"):
		facility.set_pickup_drop_highlight(false)
	facility.visible = false
	refresh_placement()
	preview_changed.emit()
	AudioCue.at(player, &"pickup", -5.0)
	return true

func try_place(rearrange_allowed: bool) -> Node2D:
	tick(rearrange_allowed)
	if not is_carrying() or not can_place:
		return null
	# tick() revalidates against current geometry immediately before commit.
	var placed := carried_facility
	_finish_carry(placement_position)
	AudioCue.at(player, &"drop", -3.0)
	return placed

func cancel_carry() -> void:
	_finish_carry(original_position)

func _finish_carry(position: Vector2) -> void:
	if is_carrying():
		carried_facility.remove_meta("facility_carrier")
		if carried_facility.has_method("set_facility_carried"):
			carried_facility.set_facility_carried(false)
		carried_facility.global_position = position
		carried_facility.visible = original_visible
	_restore_collision_states()
	_clear_carry()

func _clear_carry() -> void:
	carried_facility = null
	original_position = Vector2.ZERO
	original_visible = true
	collision_states.clear()
	placement_rect = Rect2()
	placement_position = Vector2.ZERO
	can_place = false
	clear_preview()
	preview_changed.emit()

func rotate_carried_facility() -> bool:
	if not is_carrying() or not carried_facility.has_method("rotate_carried_facility"):
		return false
	AudioCue.at(player, &"ui_tab", -5.0)
	carried_facility.rotate_carried_facility()
	capture_preview(carried_facility)
	refresh_placement()
	preview_changed.emit()
	return true

func capture_preview(facility: Node2D) -> void:
	clear_preview()
	if is_instance_valid(facility):
		_capture_facility_sprite_previews(facility, facility.global_position)

func clear_preview() -> void:
	sprite_previews.clear()

func _disable_facility_collision(root: Node) -> Array[Dictionary]:
	var saved_states: Array[Dictionary] = []
	_disable_facility_collision_recursive(root, saved_states)
	return saved_states

func _disable_facility_collision_recursive(node: Node, saved_states: Array[Dictionary]) -> void:
	if node is CollisionObject2D:
		var collision_object := node as CollisionObject2D
		saved_states.append({
			"node": collision_object,
			"collision_layer": collision_object.collision_layer,
			"collision_mask": collision_object.collision_mask
		})
		collision_object.collision_layer = 0
		collision_object.collision_mask = 0
	for child in node.get_children():
		_disable_facility_collision_recursive(child, saved_states)

func _restore_collision_states() -> void:
	for state in collision_states:
		var saved_node: Variant = state.get("node", null)
		if not is_instance_valid(saved_node):
			continue
		var node := saved_node as CollisionObject2D
		node.collision_layer = int(state.get("collision_layer", node.collision_layer))
		node.collision_mask = int(state.get("collision_mask", node.collision_mask))
	collision_states.clear()

func get_sprite_previews() -> Array[Dictionary]:
	return sprite_previews

func _capture_facility_sprite_previews(node: Node, facility_origin: Vector2) -> void:
	if node is Sprite2D:
		var sprite_node := node as Sprite2D
		if sprite_node.texture != null and sprite_node.visible:
			var source_size: Vector2 = sprite_node.region_rect.size if sprite_node.region_enabled else sprite_node.texture.get_size()
			if source_size.x > 0.0 and source_size.y > 0.0:
				var silhouette_texture: Texture2D = _create_facility_silhouette_texture(sprite_node.texture, sprite_node.region_enabled, sprite_node.region_rect)
				var uses_silhouette: bool = silhouette_texture != null
				sprite_previews.append({
					"texture": sprite_node.texture,
					"silhouette_texture": silhouette_texture,
					"relative_position": sprite_node.global_position - facility_origin,
					"offset": sprite_node.offset,
					"scale": sprite_node.global_scale,
					"source_size": source_size,
					"region_enabled": sprite_node.region_enabled,
					"region_rect": sprite_node.region_rect,
					"silhouette_region_enabled": false if uses_silhouette else sprite_node.region_enabled,
					"silhouette_region_rect": Rect2(Vector2.ZERO, source_size) if uses_silhouette else sprite_node.region_rect,
					"flip_h": sprite_node.flip_h,
					"flip_v": sprite_node.flip_v
				})
	for child in node.get_children():
		_capture_facility_sprite_previews(child, facility_origin)

func _create_facility_silhouette_texture(texture: Texture2D, region_enabled: bool, region_rect: Rect2) -> Texture2D:
	var source_image: Image = texture.get_image()
	if source_image == null or source_image.is_empty():
		return null
	var image_rect := Rect2i(Vector2i.ZERO, source_image.get_size())
	if region_enabled:
		var requested_rect := Rect2i(Vector2i(region_rect.position), Vector2i(region_rect.size))
		image_rect = requested_rect.intersection(image_rect)
	if image_rect.size.x <= 0 or image_rect.size.y <= 0:
		return null
	var silhouette_image := Image.create(image_rect.size.x, image_rect.size.y, false, Image.FORMAT_RGBA8)
	for y in range(image_rect.size.y):
		for x in range(image_rect.size.x):
			var source_color: Color = source_image.get_pixel(image_rect.position.x + x, image_rect.position.y + y)
			silhouette_image.set_pixel(x, y, Color(1.0, 1.0, 1.0, source_color.a))
	return ImageTexture.create_from_image(silhouette_image)

