extends "res://Scripts/UI/OrderGroupSelectController.gd"

const Defs = preload("res://Scripts/Progression/RunModifierDefs.gd")
var mode: StringName = &"offer"

func _init() -> void:
	card_font_scale = 1.4

func open_offers(offers: Array[Dictionary]) -> void:
	mode = &"offer"
	var cards: Array[Dictionary] = []
	for buff in offers:
		cards.append({"display_name": buff.title, "description": buff.description,
			"badge_text": "%s强度 · 持续整局" % Defs.tier_name(int(buff.tier)),
			"detail_text": "确认后随机附加一个同强度的全局负面效果。\n\n代价未知，选择不可撤销。"})
	set_order_groups(cards)
	prepare_for_open()
	overlay_title_label.text = "全局强化 · 未知的代价"
	overlay_body_label.text = "选择一项强化，随后揭示随机代价。强化与代价都会保留到本局结束。"
	overlay_hint_label.text = "A/D：选择    J/空格或点击：确认"

func show_reveal(pair: Dictionary) -> void:
	mode = &"reveal"
	set_order_groups([_pair_card(pair)])
	prepare_for_open()
	overlay_title_label.text = "契约已生效"
	overlay_body_label.text = "收益与代价均已确定。夜间可在组合台查看本局累计效果。"
	overlay_hint_label.text = "J/空格或点击：进入夜间备战"

func show_history(history: Array[Dictionary]) -> void:
	mode = &"history"
	var cards: Array[Dictionary] = []
	for pair in history:
		cards.append(_pair_card(pair))
	if cards.is_empty():
		cards.append({"display_name": "尚未签订契约", "description": "第一天营业结束、选完菜单后，开始选择全局强化。", "detail_text": ""})
	set_order_groups(cards)
	prepare_for_open()
	overlay_title_label.text = "本局全局强化与代价"
	overlay_body_label.text = "每份契约独立叠加，作用于之后所有营业日。特殊客人的独立耐心计时不受影响。"
	overlay_hint_label.text = "A/D：浏览    K/J/空格：返回夜间"

func _pair_card(pair: Dictionary) -> Dictionary:
	return {"display_name": pair.buff.title,
		"badge_text": "第%d夜 · %s强度" % [int(pair.day_index), Defs.tier_name(int(pair.buff.tier))],
		"description": "强化：%s\n\n代价：%s\n%s" % [pair.buff.description, pair.debuff.title, pair.debuff.description],
		"detail_text": "持续到本局结束"}
