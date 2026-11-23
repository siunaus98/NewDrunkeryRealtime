extends RefCounted

const MECHANISMS := {
	&"scarab": {"title": "圣甲虫 · 看住你的食材", "image": "res://ArtResource/Generated/Enemy/stealing_scarab.svg", "body": "圣甲虫会偷取料理区的地面食材与食材箱库存。\n\n入侵时留意提示，偷取的黄条结束前可以拦截。\n普通甲虫三次轻击或一次重击可击杀，并掉回赃物。\n逃跑的红色读条期间也能击杀，别让它带着食材离开。"},
	&"sandstorm": {"title": "风沙跳板 · 留意箭头方向", "image": "res://ArtResource/Tutorial/wind_pad.svg", "body": "战斗区会出现带箭头的风沙跳板。蓝色是预警，变成黄色后，踩上会沿箭头方向弹射。\n\n看清方向再决定借力赶路或绕开，途中遇到障碍会被挡停。\n跳跃会打断攻击蓄力，也可能把你带离采集点，别在忙碌时忽略脚下的箭头。"},
	&"quicksand": {"title": "流沙 · 尽快离开中心", "image": "res://ArtResource/Tutorial/quicksand.svg", "body": "流沙会拖拽并伤害停留其中的玩家。\n\n留意地面范围，提前绕行；被卷入时朝边缘移动并用冲刺脱离。\n采集可以中断，中断不会消耗采集点，不必为了完成读条硬吃伤害。"}
}
const BOSSES := {
	&"scarab": {"title": "蝎王 · 同时守住厨房", "image": "res://ArtResource/Generated/Enemy/scorpion_boss.svg", "body": "尾刺、横扫与跳砸都有预警，攻击后留出躲避空间。\n\n蝎王会召唤圣甲虫，携带赃物逃走的甲虫会为它回血。\n击败蝎王可暂停当天甲虫机制，并取得专属食材。"},
	&"sandstorm": {"title": "秃鹫 · 躲开风暴与俯冲", "image": "res://ArtResource/Generated/Enemy/vulture_boss.svg", "body": "观察风暴与落地范围，离开预警后再回身攻击。\n\n留意吹来的沙尘与跳板方向，避免被推入下一次攻击。\n击败秃鹫可取得风暴羽心，用于特殊客人的专属料理。"},
	&"quicksand": {"title": "沙虫 · 绕开流沙伏击", "image": "res://ArtResource/Generated/Enemy/sandworm_boss.svg", "body": "沙虫会制造更危险的流沙，观察地面预警后及时离开。\n\n保持移动，利用技能结束后的间隙靠近攻击。\n击败沙虫后取得沙虫晶髓，用于特殊客人的专属料理。"},
	&"monitor": {"title": "沙海终宴 · 巨蜥评审", "image": "res://ArtResource/Generated/Enemy/monitor_boss.svg", "body": "绕到背后攻击弱点，利用咬击、扑击后的空隙输出。\n\n在料理区标记处献上食物，半血后需要两份；漏交会损失食材箱库存。\n巨蜥把食物收回嘴里后才会眩晕，菜品还能直接造成伤害。\n被口水封锁的设施需按住 K 修理，拖延会摧毁台面食物并进入深度失控。"}
}

static func cards_for_day(group: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for id: Variant in group.get("map_mechanism_ids", []):
		if MECHANISMS.has(StringName(id)):
			result.append(MECHANISMS[StringName(id)].duplicate(true))
	var boss := StringName(group.get("boss_enhanced_map_mechanism_id", &""))
	if BOSSES.has(boss):
		result.append(BOSSES[boss].duplicate(true))
		result.append({"title": "特殊客人 · 营业后还有收尾", "image": "res://ArtResource/Restaurant/goddess_statue.svg", "body": "备菜期间通过女神像可前往 BOSS 战斗区，击败 BOSS 后记得带回专属食材。\n\n营业时间结束后，普通客人停止到店，特殊客人逐道点单。\n先接单，再按当前菜谱上菜；只显示当前一道及剩余道数。\n特殊客人有独立耐心，满足全部菜品后才能结束 BOSS 日。"})
	return result
