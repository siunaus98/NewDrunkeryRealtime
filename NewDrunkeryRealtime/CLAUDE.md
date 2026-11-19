# NewDrunkeryRealtime 项目说明（AI协作参考）

本文档给AI助手（Claude等）在这个项目里工作时快速建立上下文，避免每次对话都要重新摸索架构和约定。内容基于对代码库的实际分析，如果和`Docs/`目录下的纪要文档冲突，优先以`Docs/新对话交接说明_2026-10-05.md`为准；该交接文档未覆盖的历史背景再参考`Docs/新对话交接说明_2026-09-20.md`、`Docs/新对话交接说明_2026-09-11.md`和`Docs/当前原型进度纪要.md`。

## 项目是什么

独立游戏，类似"胡闹厨房 + 弹幕/幸存者式战斗"的结合：白天在料理区做菜接单、在战斗区打怪拿肉，夜晚花钱强化、选择次日订单组。当前是**即时制原型**，替代了旧版回合制卡牌方向。

- 引擎：Godot 4.7，Forward Plus 渲染
- 语言：GDScript
- 视口：1920x1080，canvas_items 缩放
- 入口场景：`Scenes/Main/game_start.tscn`（标题/开局选择） -> `Scenes/Main/main.tscn`（主场景）
- 本地校验：`tools/validate_godot.sh`（默认用 Steam 版 Godot，可用 `GODOT_BIN` 环境变量覆盖路径）

## 核心架构约定（写代码前必须知道）

### 1. 没有 autoload/全局单例

`project.godot` 里没有 `[autoload]` 段，整个项目不用全局单例。跨场景传递“开局配置”这类一次性数据靠 `SceneTree.set_meta()/get_meta()`（例如 `GameStartController` 写入 `run_setup`，`Main.gd` 读出后清除）。**不要**为了图方便新增 autoload，这不是项目现在的做法。

### 2. LevelRefs 是服务定位器，不是 autoload

`Scripts/Core/LevelRefs.gd` 是场景内的一个节点（不是单例），通过 `@export var xxx_path: NodePath` 声明对其他关键系统节点（player/order_manager/storage_manager/battle_manager/...）的路径引用，并提供 `get_xxx()` getter。

任何脚本要拿系统级节点，统一调用静态方法：

```gdscript
const LevelRefs = preload("res://Scripts/Core/LevelRefs.gd")
var refs: LevelRefs = LevelRefs.find_from(self)
var player: Node = refs.get_player()
```

`find_from()` 会沿场景树向上找名为 `"LevelRefs"` 的节点，也会回退到 `current_scene`（这个回退是刻意保留的安全网，原型阶段不要清掉）。**新增系统级节点引用时，优先加进 `LevelRefs`，而不是让脚本自己硬编码 `get_node("../XXX")` 或 `get_parent().get_parent()...`。**

### 3. 玩家子系统用 Controller 对象组合，不是子节点

`RealtimePlayer.gd` 把自己的职责拆成几个 `RefCounted`（不是 `Node`）子对象：`PlayerInteractionController`、`PlayerCombatController`、`PlayerSkillController`、`PlayerPushController`。这些对象：

- 在 `_ready()` 里 `XXXController.new()` 创建
- 用 `.setup(self, ...其他引用..., config: Dictionary)` 做依赖注入
- 在 `_process`/`_physics_process` 里被宿主手动调用 `.tick(delta)` 之类的方法驱动
- **不挂在场景树上**，纯粹是逻辑对象

这是这个项目自己的组合方式，和 Godot 官方推荐的“拆成子节点+信号”不同。**如果要给玩家加新子系统，遵循这个 Controller 对象模式，不要改成子节点方案**，否则会和现有架构不一致。

`LevelFlowController.gd` 同理拆分给了 `RunSetupController.gd`（开局/reset执行逻辑）和 `RunOverlayController.gd`（结算/调试文本/全屏UI），各自职责边界见下方“目录结构”。

### 4. 状态机用 enum + match，不是继承

关卡流程状态机在 `LevelContext.gd`（`enum LevelState`），战斗内部状态机在具体敌人脚本里（如 `BulletHellEnemy.gd` 的 `enum AttackState`），驱动方式统一是 `match state:` 分支，不用策略类或继承层级。

### 5. 游戏数据是硬编码字典表，不是 Resource/.tres

`BlessingDefs.gd`、`OrderGroupDefs.gd`、`TestItemDefs.gd` 都是 `RefCounted + class_name`，用 `static func` 返回 `Array[Dictionary]`/`Dictionary` 字面量，ID 用 `StringName`（`&"xxx"`）。项目目前完全没有用 `.tres` 资源做数据驱动配置。**这是现状记录，不是最佳实践建议**——如果后续内容量变大到需要美术/策划直接编辑数据，可以考虑迁移到 Resource，但不要在没有讨论的情况下擅自改变这个模式。

### 6. 信号连接要防重复

连接信号前，项目里的惯例是先判断再连，例如 `LevelFlowController._connect_existing_signals()` 的写法：

```gdscript
if target.has_signal("order_completed") and not target.is_connected("order_completed", callable):
    target.connect("order_completed", callable)
```

新代码里手动连接信号时保持这个防御性写法。

## 目录结构说明

```
Scripts/
  Core/       主流程、关卡状态、场景引用（Main, LevelContext, LevelFlowController, LevelRefs, RunProgressionState, RunSetupController, PrototypeMap, SmoothFollowCamera）
  Player/     玩家本体与各Controller（RealtimePlayer + Player*Controller + 相关视觉指示器）
  Enemies/    各类敌人、预警特效、投射物
  Battle/     战斗管理、掉落
  Kitchen/    仓库、桌子、料理台、组合台、地面食材
  Orders/     订单定义、订单管理、上菜口
  Restaurant/ 夜晚交互物（商人/任务书等）
  Progression/祝福定义、夜晚商店
  UI/         各类HUD与界面控制器
  Tools/      开发辅助脚本（导出工具、乱码扫描）
```

**长期状态 vs 关卡内状态的划分**（近期刚做的拆分，别混淆）：
- `RunProgressionState.gd`：跨天持续存在的长期数据——金币、经验、等级、天数、夜晚商店永久购买记录和已拥有祝福。
- `LevelContext.gd`：本关运行时状态——关卡状态、当前订单组、当前波次、声望、危险倒计时。

`Main.gd`、`PrototypeMap.gd`、`LevelFlowController.gd`、`LevelContext.gd`、`RunSetupController.gd` 目前刻意留在 `Core/` 没有继续拆分/搬移——这是有意为之的“暂停结构优化”，不要在没有明确收益的情况下继续搬家制造 churn。

## 命名与代码风格

详细规范见 `Docs/代码风格与命名规范.md`。最重要的几条：

- 类型标注严格：几乎所有 `var`、函数参数、返回值都写类型，`-> void:` 也不省略。
- 文件名/类名 PascalCase，变量/方法 snake_case，私有方法 `_` 前缀（私有字段不强制），常量 SCREAMING_SNAKE_CASE。
- 信号命名是“事件已发生”的状态化描述（如 `order_completed`、`defeated`），不是祈使动词；处理函数统一 `_on_<signal_name>`。
- `@export` 变量靠命名前缀分组（如 `attack_*`、`dash_*`），不用注释分隔；也没有 `#region` 分区。
- 缩进用 Tab。

## 中文文本：这是踩过坑的地方，务必遵守

项目是中文语境开发：代码标识符/注释是英文，但玩家可见的UI文案、字符串常量是中文。**项目已经反复出现中文乱码回流的问题**，专门有一份硬约束文档：`Docs/文本与场景修改硬约束.md`。核心原则（原文摘录）：

> 先把它当"源文件污染或场景结构风险"处理，而不是先当普通文案错字处理。

具体来说，改中文文本时：
1. 如果某段中文已经明显乱码/引号异常/字面量断裂，**不要局部替换补丁**，整段或整文件重写。
2. 改完之后不能只看游戏运行结果正常就认为没问题，要检查源文件实际内容。
3. `@export` 默认字符串、`.tscn` 里的 `text=`/`display_name`、调试提示文案都要一起检查，不只检查运行时会被覆盖的 label。
4. 改 `.tscn` 后要确认节点树没被截断、`@onready`/`get_node()` 路径仍然对得上。
5. 每轮文本/场景改动后至少跑一次 `godot --headless --quit` 和 `--headless --import --quit` 做冒烟验证。
6. 功能修复和文本清理尽量分轮做，不要在同一轮里来回穿插，避免噪音。

当前高风险文件（中文密度高+玩家可见+容易被场景实例和脚本默认值双重覆盖）：`Scenes/Main/main.tscn`、`LevelFlowController.gd`、`OrderHud.gd`、`RunOverlayController.gd`、`RunStatusHud.gd`、`NightShopController.gd`、`NightRestInteractable.gd`、`IngredientStorageCabinet.gd`。改这些文件时格外小心。

## 命名易混淆的地方（别误删/误改）

`Test*` 前缀的脚本（`TestTable.gd`、`TestCooker.gd`、`TestItemDefs.gd`、`TestServingCounter.gd`）**不是单元测试**，是原型阶段的占位实现命名，项目里没有任何单元测试框架。其中 `TestItemDefs.gd` 尤其容易被误判为可删测试代码——实际上它是**全局共享的核心数据表**（食材/菜品显示名、纹理、配方定义），几乎每个模块都 `preload` 它。改动或重命名它之前先确认调用面。防御塔原型已按既定方向删除，不再属于当前脚本集合。

`LevelFlowController.gd` 曾经的 `_sync_context_progression_from_state()` 空同步入口已在第三阶段清理；不要重新添加这种没有实际同步行为的流程转发。

## 现有设计文档索引

`Docs/` 目录下已有的纪要文档，写代码或做设计决策前建议先看相关的一份，避免和已有共识冲突：

- `当前原型进度纪要.md`：历史信息最完整的一份，记录此前实现进度、设计共识和技术债；当前事实仍以最新交接说明为准。
- `新对话交接说明_2026-10-05.md`：当前权威交接快照，区分已实现内容、已确认方向、自动验证结果和未完成事项；新对话必须优先阅读。
- `新对话交接说明_2026-09-20.md`：上一版交接快照，仅用于追溯历史状态。
- `新对话交接说明_2026-09-11.md`：上一版交接快照，仅用于追溯历史状态。
- `文本与场景修改硬约束.md`：中文文本/编码/场景修改的硬性规则（见上一节）。
- `即时制转型方案讨论纪要.md`：从回合制卡牌转向即时制的决策背景。
- `技能设计讨论纪要.md`：技能系统设计讨论。
- `精英与BOSS机制池草案.md`：精英/BOSS机制设计草案。
- `食材推动手感调整纪要.md`：玩家与地面食材推动/冲刺手感调整记录——**这部分手感已调到阶段性稳定，不建议不经讨论就改动玩家与地面食材的基础推动几何**，容易连带破坏拾取/放下/冲刺表现。

## 当前已知技术债（简版，详见进度纪要第7节）

- 输入系统：`TAB`切换订单靠物理按键硬编码兜底，不是最终方案，涉及 `Main.gd`。
- `LooseItem.gd` 链式推动曾出现低概率 stack overflow，现有访问集合、深度 / 硬上限和诊断输出已补充长链 / 环形阻挡回归；如果玩家手感需要调整，应单独修改推动几何并复测该专项。
- `test_table.tscn` 的旧无效 UID 警告已通过当前导入元数据复核确认不再复现；如果未来再次出现，应先检查对应资源的 `.import` 文件，不要直接重写场景 UID。
