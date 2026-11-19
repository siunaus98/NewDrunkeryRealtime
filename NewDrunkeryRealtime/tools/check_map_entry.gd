extends SceneTree

const PrototypeMap = preload("res://Scripts/Core/PrototypeMap.gd")

func _init() -> void:
	var map := PrototypeMap.new()
	map.position = Vector2(0.0, -256.0)
	root.add_child(map)
	await process_frame

	var points := [
		Vector2(2304.0, 560.0),
		Vector2(2304.0, 536.0),
		Vector2(2304.0, 520.0),
		Vector2(2304.0, 504.0),
		Vector2(2304.0, 488.0),
		Vector2(2048.0, 520.0),
		Vector2(2560.0, 520.0)
	]
	for point in points:
		print("entry_check ", point, " playable=", map.is_point_in_playable_area(point, Vector2(24.0, 24.0)), " battle=", map.is_point_in_battle_zone(point, Vector2(24.0, 24.0)))
	quit()
