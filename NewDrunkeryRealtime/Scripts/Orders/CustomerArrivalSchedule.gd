extends RefCounted

# Two consecutive gaps share a fixed budget. An early arrival is followed
# by a later one, so randomness cannot drift into sustained bursts or droughts.
var rng := RandomNumberGenerator.new()
var mean_interval: float = 20.0
var remaining: float = 0.0
var paired_interval: float = -1.0

func reset(customers_per_minute: float = 3.0, seed_value: int = -1) -> void:
	mean_interval = 60.0 / maxf(customers_per_minute, 0.1)
	remaining = 0.0
	paired_interval = -1.0
	if seed_value < 0:
		rng.randomize()
	else:
		rng.seed = seed_value

func tick(delta: float) -> bool:
	remaining = maxf(remaining - maxf(delta, 0.0), 0.0)
	return remaining <= 0.0

func arrived() -> void:
	if paired_interval >= 0.0:
		remaining = paired_interval
		paired_interval = -1.0
	else:
		var spread := 0.7 if rng.randf() < 0.1 else 0.5
		remaining = mean_interval * rng.randf_range(1.0 - spread, 1.0 + spread)
		paired_interval = mean_interval * 2.0 - remaining
