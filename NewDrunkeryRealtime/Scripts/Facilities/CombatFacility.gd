extends "res://Scripts/Facilities/FacilityBase.gd"

var cooldown := 0.0

func _ready() -> void:
	super._ready()
	allows_battle_placement = true
	if facility_type == &"ballista":
		refresh_direction_art()

func can_take_item(player: Node) -> bool:
	return active() and facility_type == &"trap_rack" and not player.is_holding_item() and is_day()

func take_item_to_player(player: Node) -> bool:
	if not can_take_item(player):
		return false
	if not Cargo.give(player, {"item_id": &"bear_trap"}):
		return false
	queue_free()
	return true

func _process(delta: float) -> void:
	super._process(delta)
	if not active() or not is_day() or facility_type != &"ballista":
		return
	cooldown = maxf(cooldown - delta * efficiency(), 0)
	if cooldown > 0:
		return
	cooldown = 2.5
	var bolt: Node2D = preload("res://Scripts/Facilities/BallistaBolt.gd").new()
	bolt.direction = direction
	bolt.ignored.append(get_rid())
	get_parent().add_child(bolt)
	bolt.global_position = global_position + direction * 70
	AudioCue.at(self, &"enemy_shoot", -6.0)

func get_interaction_button_prompt(_player: Node) -> String:
	return "J 取一次性捕兽夹 / 手持K放置 / K 搬起" if facility_type == &"trap_rack" else "固定方向自动射击 / K 搬起 / L 转向"
