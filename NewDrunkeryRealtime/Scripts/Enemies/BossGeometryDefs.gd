extends RefCounted

# Centres use the SVG viewBox coordinates, not scaled world pixels.
# Movement/contact describe grounded mass. Hurt regions follow the visible pose.
static func profile(kind: StringName) -> Dictionary:
	match kind:
		&"quicksand":
			var outline: Array[Vector3] = []
			_taper_chain(outline, [Vector3(30, 101, 3), Vector3(21, 94, 6), Vector3(23, 80, 12), Vector3(35, 81, 13), Vector3(55, 87, 14), Vector3(78, 94, 14), Vector3(98, 85, 15), Vector3(105, 69, 12), Vector3(98, 58, 11), Vector3(83, 49, 10), Vector3(73, 34, 12), Vector3(65, 23, 14), Vector3(48, 22, 16)])
			outline.append(Vector3(44, 29, 21))
			return _full_outline(Vector2(128, 128), outline, 2.0)
		&"scarab":
			var outline: Array[Vector3] = [Vector3(64, 42, 19), Vector3(64, 61, 20), Vector3(64, 79, 18), Vector3(64, 91, 11)]
			_chain(outline, [Vector2(62, 24), Vector2(62, 17), Vector2(70, 15), Vector2(80, 17), Vector2(92, 24), Vector2(98, 34), Vector2(95, 45), Vector2(94, 53), Vector2(99, 59), Vector2(96, 69)], 7)
			for mirror: bool in [false, true]:
				for path: Array in [
					[Vector2(49, 63), Vector2(32, 55), Vector2(19, 66), Vector2(11, 72)],
					[Vector2(46, 73), Vector2(28, 72), Vector2(20, 87), Vector2(12, 91)],
					[Vector2(47, 84), Vector2(31, 91), Vector2(30, 106), Vector2(23, 113)],
					[Vector2(52, 93), Vector2(42, 106), Vector2(46, 118)]]:
					_chain(outline, _mirror(path, mirror), 3.6)
				_chain(outline, _mirror([Vector2(50, 81), Vector2(35, 89), Vector2(28, 104)], mirror), 5.5)
				for part: Vector3 in [Vector3(18, 104, 12), Vector3(13, 111, 8), Vector3(24, 106, 10), Vector3(29, 119, 5)]:
					outline.append(Vector3(128 - part.x if mirror else part.x, part.y, part.z))
			var result := _full_outline(Vector2(128, 128), outline)
			# Keep the inset opposing claw fingers joined to the palm.
			result.body.append(Vector3(27, 113, 3))
			result.body.append(Vector3(101, 113, 3))
			return result
		&"sandstorm":
			var outline: Array[Vector3] = [Vector3(64, 27, 17), Vector3(64, 41, 12), Vector3(64, 57, 19), Vector3(64, 76, 22), Vector3(64, 92, 17), Vector3(64, 108, 10), Vector3(53, 106, 9), Vector3(75, 106, 9)]
			for mirror: bool in [false, true]:
				for part: Vector3 in [Vector3(43, 57, 15), Vector3(29, 52, 14), Vector3(17, 49, 9), Vector3(16, 62, 12), Vector3(18, 74, 12), Vector3(27, 82, 12), Vector3(37, 80, 12), Vector3(43, 70, 16), Vector3(32, 89, 7)]:
					outline.append(Vector3(128 - part.x if mirror else part.x, part.y, part.z))
			return _full_outline(Vector2(128, 128), outline)
		&"monitor":
			var outline: Array[Vector3] = [Vector3(67, 77, 21), Vector3(85, 83, 23), Vector3(105, 92, 21)]
			# Two muzzles, necks, all four limbs and the tapered tail.
			_chain(outline, [Vector2(14, 43), Vector2(26, 48), Vector2(37, 53)], 9)
			_chain(outline, [Vector2(34, 19), Vector2(46, 24), Vector2(57, 30)], 9)
			_chain(outline, [Vector2(39, 55), Vector2(47, 68), Vector2(58, 76)], 10)
			_chain(outline, [Vector2(61, 37), Vector2(64, 52), Vector2(68, 66)], 10)
			_chain(outline, [Vector2(64, 77), Vector2(57, 88), Vector2(52, 94)], 7)
			_chain(outline, [Vector2(109, 92), Vector2(121, 98), Vector2(120, 107), Vector2(131, 114)], 6)
			_chain(outline, [Vector2(61, 87), Vector2(56, 101), Vector2(55, 110), Vector2(65, 116), Vector2(74, 117)], 8)
			_chain(outline, [Vector2(109, 101), Vector2(110, 111), Vector2(103, 122), Vector2(109, 131), Vector2(122, 132)], 9)
			_chain(outline, [Vector2(111, 105), Vector2(123, 115)], 11)
			_chain(outline, [Vector2(125, 119), Vector2(130, 129)], 8)
			_chain(outline, [Vector2(132, 132), Vector2(139, 138), Vector2(145, 142)], 4)
			return _full_outline(Vector2(150, 160), outline)
	return {}

static func _full_outline(view: Vector2, outline: Array[Vector3], body_margin: float = -1.0) -> Dictionary:
	var body: Array[Vector3] = []
	var hurt: Array[Vector3] = []
	var contact: Array[Vector3] = []
	for part: Vector3 in outline:
		body.append(Vector3(part.x, part.y, maxf(1.5, part.z + body_margin)))
		hurt.append(Vector3(part.x, part.y, part.z + maxf(2.5, body_margin + 2.0)))
		contact.append(Vector3(part.x, part.y, part.z + maxf(1.5, body_margin + 1.0)))
	return {"view": view, "body": body, "hurt": hurt, "contact": contact}

static func _taper_chain(outline: Array[Vector3], points: Array) -> void:
	for i in range(points.size() - 1):
		var a: Vector3 = points[i]
		var b: Vector3 = points[i + 1]
		var steps := maxi(1, ceili(Vector2(a.x, a.y).distance_to(Vector2(b.x, b.y)) / (minf(a.z, b.z) * 0.65)))
		for step in range(steps):
			outline.append(a.lerp(b, float(step) / float(steps)))
	outline.append(points.back())

static func _chain(outline: Array[Vector3], points: Array, radius: float) -> void:
	for i in range(points.size() - 1):
		var a: Vector2 = points[i]
		var b: Vector2 = points[i + 1]
		var steps := maxi(1, ceili(a.distance_to(b) / radius))
		for step in range(steps):
			var at := a.lerp(b, float(step) / float(steps))
			outline.append(Vector3(at.x, at.y, radius))
	var end: Vector2 = points.back()
	outline.append(Vector3(end.x, end.y, radius))

static func _mirror(points: Array, mirrored: bool) -> Array:
	var result: Array[Vector2] = []
	for point: Vector2 in points:
		result.append(Vector2(128 - point.x if mirrored else point.x, point.y))
	return result
