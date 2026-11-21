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
		"description": "营业中会缓慢进入料理区，偷取地面食材或食材柜库存。进入料理区时会提示；普通日最多同时一只，偷取读条期间可攻击，逃跑读条也可击杀。"
	},
	SANDSTORM: {
		"id": SANDSTORM,
		"display_name": "沙尘暴",
		"description": "周期性风沙会改变战斗区路线并制造短暂的移动压力。"
	},
	QUICKSAND: {
		"id": QUICKSAND,
		"display_name": "流沙",
		"description": "战斗区会出现流沙区域，站立过久会被拖拽并受到伤害。"
	}
}

static func get_definition(mechanism_id: StringName) -> Dictionary:
	return DEFINITIONS.get(mechanism_id, {}).duplicate(true)

static func get_display_name(mechanism_id: StringName) -> String:
	return String(get_definition(mechanism_id).get("display_name", String(mechanism_id)))

static func get_all_ids() -> Array[StringName]:
	return MECHANISM_IDS.duplicate()
