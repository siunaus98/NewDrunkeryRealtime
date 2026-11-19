extends SceneTree

const WindSandPad = preload("res://Scripts/Hazards/WindSandPad.gd")
const WindSandMechanismController = preload("res://Scripts/Core/WindSandMechanismController.gd")
const MapMechanismDefs = preload("res://Scripts/Core/MapMechanismDefs.gd")

func _init() -> void:
	var pad := WindSandPad.new()
	root.add_child(pad)
	_assert(pad.direction_index >= 0 and pad.direction_index < 8, "Wind-sand pad direction must use eight directions.")
	_assert(is_equal_approx(pad.jump_distance, 620.0), "Wind-sand pad jump distance must be configurable.")
	_assert(pad.retrigger_lock_duration > 0.0, "Wind-sand pad retrigger protection must remain enabled.")
	pad.configure_direction(3)
	_assert(pad.direction_index == 3, "A pad direction must be fixed before it appears.")
	pad.queue_free()

	var controller := WindSandMechanismController.new()
	root.add_child(controller)
	controller.configure_for_level({"map_mechanism_ids": [MapMechanismDefs.SANDSTORM]})
	_assert(controller.active, "The controller must activate when sandstorm is an active map mechanism.")
	controller.configure_for_level({"map_mechanism_ids": []})
	_assert(not controller.active, "The controller must deactivate when sandstorm is absent.")

	print("Wind-sand pad rules OK: eight-way direction, jump distance, and activation state.")
	quit(0)

func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
