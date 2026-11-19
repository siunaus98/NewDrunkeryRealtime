extends RefCounted

const AudioCue = preload("res://Scripts/Audio/AudioCue.gd")

## Work milestones are independent of the once-per-ingredient energy reward.
static func completed(player: Node, event: StringName) -> void:
	if is_instance_valid(player) and player.has_method("on_work_completed"):
		player.on_work_completed(event)
	if player is Node2D:
		var cue: StringName = &"serve" if event == &"serve" else (&"forage" if event == &"forage" else (&"order" if event == &"order" else &"complete"))
		AudioCue.at(player, cue, -0.5)
