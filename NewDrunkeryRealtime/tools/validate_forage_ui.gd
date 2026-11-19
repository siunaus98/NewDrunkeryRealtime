extends SceneTree

const ForagePoint = preload("res://Scripts/Forage/ForagePoint.gd")
const FORAGE_POINT_SCENE = preload("res://Scenes/Forage/forage_point.tscn")

func _init() -> void:
	var point: Node = FORAGE_POINT_SCENE.instantiate()
	root.add_child(point)
	var failures: Array[String] = []
	point.state = ForagePoint.ForageState.IDLE
	if point.get_interaction_button_prompt(null) != "K 采集":
		failures.append("空闲采集点没有显示K采集")
	point.state = ForagePoint.ForageState.SEARCHING
	if not point.get_interaction_button_prompt(null).is_empty():
		failures.append("搜寻进度中玩家头顶仍显示交互按钮")
	point.state = ForagePoint.ForageState.SELECTING
	if not point.get_interaction_button_prompt(null).is_empty():
		failures.append("选择收获时玩家头顶仍显示交互按钮")
	var slots: Array[Dictionary] = point._get_key_slots(4)
	var keys: Array[int] = []
	for slot in slots:
		keys.append(int(slot.get("key_code", 0)))
	for expected_key in [KEY_W, KEY_A, KEY_S, KEY_D]:
		if expected_key not in keys:
			failures.append("采集QTE缺少WASD按键：%d" % expected_key)
	if failures.is_empty():
		print("Forage UI rules OK: quantity cards, spacing, WASD, and prompt states.")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)
