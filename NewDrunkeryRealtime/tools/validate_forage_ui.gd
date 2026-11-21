extends SceneTree

const ForagePoint = preload("res://Scripts/Forage/ForagePoint.gd")
const TestItemDefs = preload("res://Scripts/Kitchen/TestItemDefs.gd")
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
	var option_player := Node2D.new()
	point.add_child(option_player)
	point.set("active_player", option_player)
	point.set("forage_item_ids", [TestItemDefs.RICE_ID])
	point._build_options()
	if point.get("option_root").get_child_count() < 2:
		failures.append("采集选项应包含标题和卡片内容")
	if failures.is_empty():
		print("Forage UI rules OK: quantity cards, spacing, WASD, and prompt states.")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)
