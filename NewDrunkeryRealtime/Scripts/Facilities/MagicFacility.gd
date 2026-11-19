extends "res://Scripts/Facilities/FacilityBase.gd"

var blessing_time := 0.0
var healing_cooldowns: Dictionary = {}
var last_day := false

func destroy_surface_food() -> void:
	super.destroy_surface_food()
	blessing_time = 0

func _ready() -> void:
	super._ready()
	allows_battle_placement = facility_type in [&"net_rack", &"healing_spring"]
	last_day = is_day()

func _process(delta: float) -> void:
	super._process(delta)
	var day := is_day()
	if day != last_day:
		healing_cooldowns.clear()
	last_day = day
	for id: int in healing_cooldowns:
		healing_cooldowns[id] = maxf(float(healing_cooldowns[id]) - delta, 0)
	if active() and day and blessing_time > 0:
		blessing_time = maxf(blessing_time - delta * efficiency(), 0)
		if blessing_time <= 0 and not stored.is_empty():
			stored.payload["flame_blessed"] = true
			AudioCue.at(self, &"complete", -5.0)
	status.text = "%d" % ceili(blessing_time) if blessing_time > 0 else ("◆" if not stored.is_empty() else "")

func can_receive_item(player: Node) -> bool:
	if preload("res://Scripts/Facilities/FacilityWorkPause.gd").is_paused(self):
		return false
	if not active() or not stored.is_empty() or not is_day():
		return false
	var item := Cargo.held(player)
	if facility_type == &"fire_furnace":
		return not item.is_empty() and Cargo.Items.is_dish(StringName(item.item_id)) and not bool(item.payload.get("flame_blessed", false))
	if facility_type == &"duplicator":
		return Cargo.copyable(item)
	return false

func receive_item_from_player(player: Node) -> bool:
	if not can_receive_item(player):
		return false
	var cost := 2 if facility_type == &"fire_furnace" else 3
	if not pay(player, cost):
		return false
	stored = Cargo.held(player)
	if facility_type == &"fire_furnace":
		player.clear_held_item()
		blessing_time = 6.0
	else:
		# The original stays in hand. Metadata, including the once-only energy
		# marker, is inherited; a small seasoning box never grows on copying.
		if StringName(stored.item_id) == Cargo.Items.SEASONING_BOX_ID:
			stored.payload.servings = mini(int(stored.payload.get("servings", 0)), 4)
	return true

func can_take_item(player: Node) -> bool:
	if not active():
		return false
	if not stored.is_empty():
		return blessing_time <= 0 and super.can_take_item(player)
	return not player.is_holding_item() and facility_type in [&"flyer", &"water_dispenser", &"net_rack", &"healing_spring"]

func take_item_to_player(player: Node) -> bool:
	if not stored.is_empty():
		return super.take_item_to_player(player) if blessing_time <= 0 else false
	if not can_take_item(player):
		return false
	match facility_type:
		&"flyer":
			var reference: Node = refs()
			var flow: Node = reference.get_level_flow_controller() if reference != null else null
			if flow == null or not flow.can_summon_flyer_customer():
				player.show_hint("没有可接待的空窗口")
				return false
			if not pay(player, 1):
				return false
			return flow.summon_flyer_customer()
		&"water_dispenser", &"net_rack":
			if not pay(player, 1 if facility_type == &"water_dispenser" else 2):
				return false
			return Cargo.give(player, {"item_id": &"ice_water" if facility_type == &"water_dispenser" else &"magic_net"})
		&"healing_spring":
			var id := player.get_instance_id()
			if float(healing_cooldowns.get(id, 0)) > 0:
				player.show_hint("泉水冷却 %d秒" % ceili(healing_cooldowns[id]))
				return false
			if player.combat_controller.current_health >= player.get_current_max_health() or not pay(player, 2):
				return false
			player.combat_controller.heal(player.get_current_max_health())
			healing_cooldowns[id] = 180.0
			return true
	return false

func get_interaction_button_prompt(_player: Node) -> String:
	if preload("res://Scripts/Facilities/FacilityWorkPause.gd").is_paused(self):
		return ""
	match facility_type:
		&"flyer": return "J 招揽客人 · 1魔力 / K 搬起"
		&"water_dispenser": return "J 取冰水 · 1魔力 / K 搬起"
		&"net_rack": return "J 取魔网 · 2魔力 / K 搬起"
		&"healing_spring": return "J 完全治疗 · 2魔力 / K 搬起"
		&"fire_furnace": return "J 放入/取出菜品 · 祝福2魔力 / K 搬起"
	return "J 复制食材 · 3魔力 / J 取复制品 / K 搬起"

func reset_state() -> void:
	super.reset_state()
	healing_cooldowns.clear()
	last_day = is_day()
