extends SceneTree

const Math = preload("res://Scripts/Player/PlayerCombatMath.gd")
var failures: int = 0

func _initialize() -> void:
	_check(Math.current_attack_damage(100, 0.0, 1.0, 1.0) == 100, "Base attack damage must remain 100.")
	_check(Math.current_attack_damage(100, 10.0, 1.2, 0.65) == 86, "Attack formula must apply additive and multiplicative bonuses in order.")
	_check(Math.current_max_health(100, 0, 1.0, false) == 100, "Base health must remain 100.")
	_check(Math.current_max_health(100, 20, 1.1, true) == 152, "Guardian health multiplier must be applied after total health multiplier.")
	_check(is_equal_approx(Math.current_dash_cooldown(0.9, 0.5), 0.45), "Dash cooldown multiplier must be applied.")
	_check(is_equal_approx(Math.current_dash_cooldown(0.0, 0.0), 0.01), "Dash cooldown must keep its safety floor.")
	if failures == 0:
		print("PASS: player attack, health and dash cooldown formulas remain pure and stable.")
	quit(0 if failures == 0 else 1)

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
