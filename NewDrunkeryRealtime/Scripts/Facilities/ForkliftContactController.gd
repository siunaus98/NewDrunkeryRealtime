extends RefCounted

## Vehicle contacts own both sides of a collision. Enemy attack-radius checks
## must not charge the driver separately or apply their normal contact stun.
const RAM_DAMAGE: int = 50
const CONTACT_DAMAGE: int = 10
const CONTACT_INTERVAL: float = 0.6
const PUSH_DISTANCE: float = 80.0
const PUSH_DURATION: float = 0.18

var vehicle: StaticBody2D
var cooldowns: Dictionary = {}
var pushes: Dictionary = {}

func setup(body: StaticBody2D) -> void:
	vehicle = body

func tick(delta: float) -> void:
	for id: int in cooldowns.keys():
		cooldowns[id] = float(cooldowns[id]) - delta
		if float(cooldowns[id]) <= 0.0:
			cooldowns.erase(id)
	for id: int in pushes.keys():
		var data: Dictionary = pushes[id]
		var enemy: Node2D = data.target.get_ref()
		if not is_instance_valid(enemy) or enemy.is_queued_for_deletion() or enemy.get("is_dead") == true:
			pushes.erase(id)
			continue
		var previous: float = float(data.elapsed) / PUSH_DURATION
		data.elapsed = minf(float(data.elapsed) + delta, PUSH_DURATION)
		var current: float = float(data.elapsed) / PUSH_DURATION
		# Ease out the impulse and sweep every step, retaining wall collisions.
		var distance: float = PUSH_DISTANCE * (pow(1.0 - previous, 2) - pow(1.0 - current, 2))
		if enemy is PhysicsBody2D:
			enemy.move_and_collide(data.direction * distance)
		if current >= 1.0:
			pushes.erase(id)

func check_contacts() -> void:
	var shape := RectangleShape2D.new()
	shape.size = Vector2(116, 116)
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = vehicle.global_transform
	query.collision_mask = 2
	for hit: Dictionary in vehicle.get_world_2d().direct_space_state.intersect_shape(query, 32):
		touch(hit.collider)

func touch(body: Object) -> bool:
	if not body is Node2D or not body.is_in_group("enemies") or body.get("is_dead") == true or body.is_queued_for_deletion():
		return false
	if not is_instance_valid(vehicle.driver) or vehicle.health <= 0:
		return false
	var id: int = body.get_instance_id()
	if cooldowns.has(id) or not body.has_method("receive_hit"):
		return false
	var direction: Vector2 = vehicle.global_position.direction_to(body.global_position)
	if direction.is_zero_approx():
		direction = vehicle.direction
	var contact: Variant = body.get("contact_damage")
	var damage: int = maxi(int(contact), 1) if contact != null and int(contact) > 0 else CONTACT_DAMAGE
	# Commit both amounts together, even when either participant dies. Each
	# enemy has one shared cooldown for this pair, never a global vehicle gate.
	cooldowns[id] = CONTACT_INTERVAL
	vehicle.take_damage(damage, -direction, &"contact")
	body.receive_hit(RAM_DAMAGE, direction)
	if body.get("is_dead") != true:
		pushes[id] = {"target": weakref(body), "direction": direction, "elapsed": 0.0}
	return true
