# NewDrunkeryRealtime

沙漠题材的合作料理肉鸽游戏，融合实时料理经营、战斗采集和局内成长。目前处于可玩 Demo 的系统整合与体验测试阶段。

## 当前内容

- 料理区与战斗区，以及食材采集、加工、组合、装盘、上菜和盘子清洗流程。
- 普通、精英和 BOSS 特殊客人；精英与 BOSS 客人逐道点单，甜品可额外招待。
- 声望、金币、经验、技能、祝福、全局强化和随机负面效果。
- 三个小 BOSS、最终 BOSS，以及对应机制、特殊食材与料理。
- 夜间 NPC 事件、设施商店、设施图鉴与基础音乐音效。

当前优先测试逐道点单、接单与上菜、剩余道数和耐心值，以及二级菜单、图鉴、商店、事件与升级界面的字体和布局。合作玩法的完整联机能力尚未在此说明中验收。

当前版本为方便快速查看机制与 BOSS 的营业前说明卡，临时采用每天 **5 秒备菜＋20 秒营业**，BOSS 特殊客人的收尾流程保留。正常时长配置仍保留在 `LevelFlowController.gd`，将 `BRIEFING_PREVIEW_SHORT_DAYS` 设为 `false` 即可恢复。

## 运行

使用 **Godot 4.7**；当前本机已验证版本为 **4.7.2 Steam**。项目默认使用 Forward+ 渲染。

1. 克隆仓库，在 Godot 项目管理器中导入 `NewDrunkeryRealtime/project.godot`。
2. 首次打开时等待 Godot 导入素材。
3. 按 F6 可运行当前场景；按 F5 运行项目，从标题界面开始。

Windows PowerShell 命令行启动示例（按本机安装位置修改 `$godotExe`）：

```powershell
$godotExe = 'D:\steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe'
& $godotExe --path .\NewDrunkeryRealtime
```

如果 Forward+ 启动异常，可临时使用兼容模式，不必修改项目配置：

```powershell
& $godotExe --path .\NewDrunkeryRealtime --rendering-method gl_compatibility
```

沙宴巨蜥测试入口：

```powershell
& $godotExe --path .\NewDrunkeryRealtime --rendering-method gl_compatibility -- --test-monitor
```

启动前确认只保留一个 `NewDrunkeryRealtime (DEBUG)` 实例，避免音乐叠加。已有 `NewDrunkeryRealtime/试玩沙宴巨蜥.cmd` 也可启动测试，但其中的引擎路径为本机固定路径。

## 基本操作

| 按键 | 功能 |
| --- | --- |
| WASD / 方向键 | 移动 |
| J | 拾取 / 放下 |
| K | 交互 |
| L | 攻击 |
| 空格 | 冲刺 |
| U / I | 小技能 / 大招 |
| Tab | 切换订单显示 |
| Esc | 暂停菜单（含图鉴） |

具体设施操作以游戏内提示为准。

## 验证

项目提供独立的 Godot 验证脚本。在仓库根目录运行，例如：

```powershell
& $godotExe --headless --path .\NewDrunkeryRealtime --script res://tools/validate_customer_orders.gd
& $godotExe --headless --path .\NewDrunkeryRealtime --script res://tools/validate_elite_customers_and_desserts.gd
& $godotExe --headless --path .\NewDrunkeryRealtime --script res://tools/validate_order_flow.gd
& $godotExe --headless --path .\NewDrunkeryRealtime --script res://tools/validate_order_target_sync.gd
```

这四项订单回归在首次入库准备时已通过。自动检查不替代实际游玩的体验、字体与布局验收。其余专项脚本见 `NewDrunkeryRealtime/tools/`。

## 目录

```text
NewDrunkeryRealtime/
  project.godot   Godot 项目配置
  Scripts/       游戏逻辑与界面脚本
  Scenes/        场景
  ArtResource/   美术资源
  Audio/         音乐、音效及来源说明
  Data/          游戏数据
  Docs/          设计文档、开发记录与约定
  tools/         验证与资源生成工具
```

Godot 缓存、本地存档、测试日志、历史备份、调试截图与导出产物由 `.gitignore` 排除；资源的 `.uid` 和 `.import` 配置保留在版本管理中。当前资源规模使用普通 Git，无需 Git LFS。

## 素材与许可

本仓库已公开供查看与协作，目前未授予项目整体的开源使用许可。第三方音频的来源与许可记录见 [音频说明](NewDrunkeryRealtime/Audio/README.md)；第三方素材仍遵循各自许可。
