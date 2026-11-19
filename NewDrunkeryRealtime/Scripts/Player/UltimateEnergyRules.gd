extends RefCounted

const CAPACITY: float = 400.0
const PASSIVE_PER_SECOND: float = 0.5
const PROCESS_REWARDED: String = "process_energy_rewarded"
const REWARDS: Dictionary = {
	&"light_hit": 1, &"heavy_hit": 4, &"kill": 10,
	&"forage": 6, &"process": 5, &"assemble": 8,
	&"serve": 10, &"order": 3, &"wash": 3, &"barrel": 2
}

static func award(player: Node, event: StringName) -> void:
	if is_instance_valid(player) and player.has_method("award_ultimate_energy"):
		player.award_ultimate_energy(event)

static func claim_processing(player: Node, payload: Dictionary) -> void:
	if bool(payload.get(PROCESS_REWARDED, false)):
		return
	payload[PROCESS_REWARDED] = true
	award(player, &"process")

static func award_team(tree: SceneTree, event: StringName) -> void:
	for player: Node in tree.get_nodes_in_group("player"):
		award(player, event)
