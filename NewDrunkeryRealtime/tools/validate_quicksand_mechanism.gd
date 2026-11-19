extends SceneTree

const QuicksandHazard = preload("res://Scripts/Hazards/QuicksandHazard.gd")
const QuicksandMechanismController = preload("res://Scripts/Core/QuicksandMechanismController.gd")
const MapMechanismDefs = preload("res://Scripts/Core/MapMechanismDefs.gd")

func _init() -> void:
	var hazard := QuicksandHazard.new()
	root.add_child(hazard)
	hazard.radius = 300.0
	hazard.lifetime = 2.0
	_assert(hazard.get_hazard_radius() == 300.0, "Quicksand radius must be configurable.")
	_assert(hazard.suction_speed <= 300.0, "Quicksand pull must leave dash escape possible.")
	_assert(hazard.has_method("_physics_process"), "Quicksand must update its pull on the physics tick.")
	hazard.queue_free()

	var controller := QuicksandMechanismController.new()
	root.add_child(controller)
	controller.configure_for_level({"map_mechanism_ids": [MapMechanismDefs.QUICKSAND]})
	_assert(controller.active, "The controller must activate when quicksand is an active map mechanism.")
	controller.configure_for_level({"map_mechanism_ids": []})
	_assert(not controller.active, "The controller must deactivate when quicksand is absent.")

	print("Quicksand mechanism rules OK: configurable hazard and activation state.")
	quit(0)

func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
