extends RefCounted

const InteractionProgressBar = preload("res://Scripts/Player/InteractionProgressBar.gd")
const TestItemDefs = preload("res://Scripts/Kitchen/TestItemDefs.gd")

var station_bar: Node2D
var normal_fill: Color
var overcook_fill: Color

func setup(parent: Node2D, config: Dictionary) -> void:
	# The station owns the visual nodes' lifetime; this view owns their updates.
	station_bar = InteractionProgressBar.new()
	station_bar.name = "StationProgressBar"
	station_bar.z_index = 100
	parent.add_child(station_bar)
	station_bar.position = config.station_progress_offset
	station_bar.size = config.station_progress_size
	station_bar.background_color = config.station_progress_background_color
	station_bar.border_color = config.station_progress_border_color
	station_bar.border_width = 3.0
	station_bar.stage_separator_color = config.stage_separator_color
	normal_fill = config.station_progress_fill_color
	overcook_fill = config.station_overcook_fill_color

func update_station(data: Dictionary) -> void:
	if not is_instance_valid(station_bar):
		return
	if not bool(data.get("visible", false)):
		station_bar.set_state(false, 0.0)
		return
	var progress: float = float(data.get("progress", 0.0))
	if bool(data.get("overcooking", false)):
		station_bar.fill_color = overcook_fill
		station_bar.set_state(true, progress)
	elif data.has("display_mode"):
		station_bar.set_stage_state(true, progress, int(data.stage_index), float(data.stage_progress), data.stage_thresholds, data.stage_colors, data.display_mode)
	else:
		station_bar.fill_color = normal_fill
		station_bar.set_state(true, progress)
	station_bar.set_maturity_icon(TestItemDefs.get_process_icon_texture(StringName(data.get("process_state", &""))), Vector2(128, 128))

