class_name MapMechanismDefs
extends RefCounted

## Map mechanisms are deliberately data-only for now. Their runtime rules will
## be added after the day-unlock/Boss pairing template is validated.
const SCARAB: StringName = &"scarab"
const SANDSTORM: StringName = &"sandstorm"
const QUICKSAND: StringName = &"quicksand"

const MECHANISM_IDS: Array[StringName] = [SCARAB, SANDSTORM, QUICKSAND]

const DEFINITIONS := {
	SCARAB: {
		"id": SCARAB,
		"display_name": "圣甲虫",
		"description": "地图机制占位：圣甲虫的具体运行规则待定义。"
	},
	SANDSTORM: {
		"id": SANDSTORM,
		"display_name": "沙尘暴",
		"description": "地图机制占位：沙尘暴的具体运行规则待定义。"
	},
	QUICKSAND: {
		"id": QUICKSAND,
		"display_name": "流沙",
		"description": "地图机制占位：流沙的具体运行规则待定义。"
	}
}

static func get_definition(mechanism_id: StringName) -> Dictionary:
	return DEFINITIONS.get(mechanism_id, {}).duplicate(true)

static func get_display_name(mechanism_id: StringName) -> String:
	return String(get_definition(mechanism_id).get("display_name", String(mechanism_id)))

static func get_all_ids() -> Array[StringName]:
	return MECHANISM_IDS.duplicate()
