# Demo audio

本目录是可直接运行的基础音频包：6 首配乐、46 个短音效（其中 4 首场景音乐循环，2 首结算音乐单次播放）。全部由
`tools/generate_demo_audio.py` 离线合成，未使用下载素材、商业歌曲或第三方采样。
音色为合成的拨弦、笛声、铃声、低音与手鼓，并非真实乐器录音。

| 文件 | 使用场景 | 时长 / 节奏 |
| --- | --- | --- |
| music_title.wav | 主界面、选人 | 55.38 秒 / 104 BPM，轻快明亮 |
| music_success.wav | 营业成功结算 | 20.87 秒，单次播放 |
| music_end.wav | 营业结束/失败结算 | 26.67 秒，单次播放 |
| music_night.wav | 夜间备战与结算后的选择 | 75.79 秒 / 76 BPM，舒缓拨弦与笛声 |
| music_day.wav | 普通关备菜、营业 | 51.43 秒 / 112 BPM，沙漠小调与轻打击乐 |
| music_boss.wav | 小 BOSS、最终 BOSS 关 | 45.71 秒 / 126 BPM，低音与更密集的手鼓 |

后三首使用相关的音阶、拨弦与打击乐保持沙漠地区的一致性；各曲为 24 小节，
带分层与音色变化。混响尾音已循环折回，播放时设完整采样范围循环。

音效包括：菜单移动、确认、取消、分页与刷新；取放物品及设施、工作节奏、
切磨洗烤、加工完成、料理成功/失败、接待与上菜、购买、事件；
轻重攻击、命中、受伤、冲刺、小技能、大招、敌人射击/倒下、冲击、BOSS 提示与吐液。
料理台、采集、点单、上菜和酿酒使用更具力度的独立反馈。NPC 音效采用项目内保存的 CC0 参考录音并按角色身份区分：商人与游商使用金币叮当，箱中魔鬼使用邪笑，炉火精灵使用火焰呼呼声，瓷娃娃使用玻璃声，刻碑师使用石块撞击，沙灵使用呜呼声，赌徒使用骰子声，恶作剧之神使用低频虚空声。参考素材文件以 `ref_npc_*.wav` 保存，AudioManager 会优先加载这些短片段。

NPC 参考录音来源（均为 Freesound CC0）：

- 商人/游商：Coin Shower — Qvantor，<https://cdn.freesound.org/previews/878/878613_19512113-lq.mp3>
- 箱中魔鬼：Evil_chuckle — remarknl，<https://cdn.freesound.org/previews/197/197411_468380-lq.mp3>
- 炉火精灵：fire-whoosh — hnhnh，<https://cdn.freesound.org/previews/244/244926_3983630-lq.mp3>
- 瓷娃娃：Glass bell — PaperMacheToothPicksSeaAnenome，<https://cdn.freesound.org/previews/728/728699_15827690-lq.mp3>
- 刻碑师：Rock impact — kevinklang，<https://cdn.freesound.org/previews/843/843548_14469752-lq.mp3>
- 沙灵：Joyful Wouhouh — Sadiquecat，<https://cdn.freesound.org/previews/801/801291_5287430-lq.mp3>
- 赌徒：Dice Rolling on Table — Flem0527，<https://cdn.freesound.org/previews/629/629982_12715066-lq.mp3>
- 恶作剧之神：dark ambient — ilmari_freesound，<https://cdn.freesound.org/previews/716/716563_12458758-lq.mp3>

## 调整与替换

- 暂停菜单中可分别调整音乐与音效音量，以 20% 为一档，0% 静音；选择自动保存到
  `user://audio_settings.cfg`，切换场景保留设置。
- `Scripts/Audio/AudioManager.gd` 集中管理目录、总线、混音、0.65 秒交叉淡化及
  20 个音效播放通道。重复音效有最短间隔，超额声音直接略过，不打断已有声音。
- 玩法通过 `Scripts/Audio/AudioCue.gd` 派发声音；设施、敌人与加工声仅在屏幕附近
  播放，工作声有独立节奏。关键客人、事件、BOSS 到来等提示不受屏幕范围限制。
- 替换同名 WAV 后由 Godot 重新导入即可，不需要逐个修改玩法代码。增加目录项时
  同步更新 AudioManager 的 ID 列表。音乐导入保留立体声与完整循环，不做自动归一化。
- 使用 Python + NumPy 运行 `python tools/generate_demo_audio.py` 可确定性重建全部资源；
  游戏运行时只播放预先渲染好的 PCM，不实时合成音乐。

## 验证

`godot --headless --path . --script tools/validate_audio.gd` 验证全部资源、循环端点、
主界面/选人/夜晚/普通日/BOSS/结算切换、失败交互静音、成功取物、工作节奏、受伤、
鼠标确认、音效数量上限、去重、静音与快速切曲后的单曲播放。
听感、音乐疲劳感和最终响度仍应结合真实游玩进一步调整。
