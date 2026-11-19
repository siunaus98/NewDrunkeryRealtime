extends RefCounted

## Shared presentation tokens. Warning and maturity colours stay in their views.
const PANEL := Color("283b39f5")
const GOLD := Color("c4a573")
const LIGHT := Color("f3e7cb")
const SELECTED := Color("465e57")

static func finish(style: StyleBoxFlat, selected: bool = false) -> StyleBoxFlat:
	style.bg_color = SELECTED if selected else PANEL
	style.border_color = Color("f4d796") if selected else GOLD
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.shadow_color = Color(0.08, 0.07, 0.06, 0.25)
	style.shadow_size = 6
	style.shadow_offset = Vector2(0, 3)
	return style

static func panel(selected: bool = false) -> StyleBoxFlat:
	return finish(StyleBoxFlat.new(), selected)
