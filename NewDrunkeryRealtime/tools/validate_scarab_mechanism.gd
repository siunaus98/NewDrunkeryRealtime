extends SceneTree

const ScarabEnemy = preload("res://Scripts/Enemies/ScarabEnemy.gd")
const ScarabMechanismController = preload("res://Scripts/Core/ScarabMechanismController.gd")
const MapMechanismDefs = preload("res://Scripts/Core/MapMechanismDefs.gd")

class TestIngredient:
	extends Node2D

	func _ready() -> void:
		add_to_group("loose_items")

	func get_item_id() -> StringName:
		return &"meat_red"

	func is_scarab_steal_target() -> bool:
		return true

class TestEmptyCabinet:
	extends Node2D

	func is_scarab_steal_target() -> bool:
		return false

func _init() -> void:
	var scarab := ScarabEnemy.new()
	root.add_child(scarab)
	scarab.max_stolen_items_min = 2
	scarab.max_stolen_items_max = 2
	# The first three hit events kill a scarab; a heavy hit kills it immediately.
	scarab.receive_hit(1)
	scarab.receive_hit(1)
	_assert(not scarab.is_dead, "A scarab must survive two light attacks.")
	scarab.receive_hit(1)
	_assert(scarab.is_dead, "A scarab must die after three light attacks.")

	var escaped := ScarabEnemy.new()
	root.add_child(escaped)
	_assert(is_equal_approx(escaped.escape_duration, 8.0), "Scarab escape casting should use the eight-second base duration.")
	escaped.stolen_limit = 2
	escaped.add_stolen_item(&"ingredient_a")
	_assert(escaped.get_stolen_count() == 1, "A scarab should track stolen items.")
	escaped.add_stolen_item(&"ingredient_b")
	_assert(escaped.get_state() == ScarabEnemy.State.ESCAPING_TO_CORNER, "Reaching the stolen-item limit must start the escape-to-corner phase.")
	escaped.set_escape_target(Vector2(64.0, 0.0))
	_assert(escaped.get_action_progress() == 0.0, "The escape progress bar must remain empty while the scarab is moving to its corner.")
	var cast_started := ScarabEnemy.new()
	root.add_child(cast_started)
	cast_started.stolen_limit = 1
	cast_started.add_stolen_item(&"ingredient_a")
	cast_started.set_escape_target(cast_started.global_position)
	cast_started._physics_process(0.0)
	_assert(cast_started.get_state() == ScarabEnemy.State.ESCAPING, "The escape cast must begin only after the scarab reaches its corner.")
	# The walk to the corner remains attackable; only the red escape cast is
	# protected. This guards against an intermittent hit target becoming
	# impossible to kill during the transition.
	var escaping_walk := ScarabEnemy.new()
	root.add_child(escaping_walk)
	escaping_walk.stolen_limit = 1
	escaping_walk.add_stolen_item(&"ingredient_a")
	escaping_walk.receive_charged_hit(1)
	_assert(escaping_walk.is_dead, "A scarab must remain killable while walking to its escape corner.")
	var protected_cast := ScarabEnemy.new()
	root.add_child(protected_cast)
	protected_cast.stolen_limit = 1
	protected_cast.add_stolen_item(&"ingredient_a")
	protected_cast.set_escape_target(protected_cast.global_position)
	protected_cast._physics_process(0.0)
	protected_cast.receive_charged_hit(1)
	_assert(not protected_cast.is_dead, "The red escape cast must remain uninterruptible.")

	var controller := ScarabMechanismController.new()
	root.add_child(controller)
	_assert(is_equal_approx(controller.navigation_cell_size, 32.0), "Scarab navigation must use a configurable grid cell size.")
	_assert(is_equal_approx(controller.navigation_clearance, 34.0), "Scarab navigation must reserve clearance around blockers.")
	controller.start_business()
	_assert(is_zero_approx(controller.spawn_remaining), "Business start must request the first scarab immediately.")
	controller.configure_for_level({"map_mechanism_ids": [MapMechanismDefs.SCARAB]})
	_assert(controller.active, "The controller must activate when scarab is an active map mechanism.")
	controller.configure_for_level({"map_mechanism_ids": []})
	_assert(not controller.active, "The controller must deactivate when scarab is absent.")
	# A direct runtime actor must retain the ScarabEnemy script. Movement against
	# the real scene physics space is covered by validate_scarab_runtime.gd.
	var spawned_scarab := ScarabEnemy.new()
	root.add_child(spawned_scarab)
	_assert(spawned_scarab.has_signal("steal_action_finished"), "Runtime scarabs must expose the theft-completion signal.")
	_assert(spawned_scarab.steal_reach >= 104.0, "Scarab steal range must clear the enlarged body and cabinet collision footprint.")

	var ingredient := TestIngredient.new()
	_assert(controller._is_player_interactable(ingredient), "An eligible ingredient must remain a scarab target even while the player is carrying an item.")
	var empty_cabinet := TestEmptyCabinet.new()
	_assert(not controller._is_player_interactable(empty_cabinet), "An empty ingredient cabinet must not be a scarab target.")
	ingredient.free()
	empty_cabinet.free()

	print("Scarab mechanism rules OK: activation, runtime script binding, target selection, combat thresholds, theft tracking, and escape trigger.")
	_cleanup_test_nodes()
	await process_frame
	quit(0)

func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)

func _cleanup_test_nodes() -> void:
	for child in root.get_children():
		if is_instance_valid(child):
			child.queue_free()
