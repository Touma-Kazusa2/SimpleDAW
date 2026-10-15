# Issue Tracker

## 工作规则
- 每次只有在和用户沟通过后,才能增删改动改动"工作规则"(不管之前有没有提到过要做哪些修改)
- 用户可能随时改动此文件；每次写入前都要先读取。
- 对难度较高的改进或实现,可以索要对解决问题有帮助的资源(主要是上网可以下载的资源,例如参考项目代码,规范等)。
- 修改代码完成后，在问题条目下方写：`修改过n+1次: 思路; 代码文件;涉及的函数名`。
- 工作流程:
  - 先整理/分组/合并/拆分/格式化问题与功能。
  - 整理时必须同时保留“问题描述”和“用户原话”，并明确标注“用户原话”。
  - 已解决问题的“用户原话”需剪切到 `resolved_user_quotes/` 下，以问题概括命名，并在条目中引用该文件。
  - 如果问题描述模糊,要求用户详细说明
  - 从未修复/待实现中选择最优先或最关联的 4 项。
  - 阅读代码找明显原因: 若未发现，或遭到用户反驳,暂时搁置.当要继续处理未找到原因的问题时,让用户补充更多文字描述,若还是不能确定原因,建议在哪个函数下面插入 print 进行调试,以此获得更多信息。
  - 若有合适修改方案，先与用户沟通确认。
  - 用户确认需求后，先说明计划改动点/大致代码/涉及文件，再开始修改。
  - 若方案有争议，先记录到该文件；除非全部都有争议，否则继续推进已达成一致的项。

## 用户随手记（原始输入）
- 你可以随时把零散想法写在这里；我会整理并转移到对应分组，并标记“已整理”。
  - 钢琴卷帘面板音符被播放是,不仅会膨胀,还拥有白框(跟随着音符膨胀)

## Current Focus (Top 4)
- 28 空格播放逻辑
  - 状态: 待处理
  - 问题描述: 按空格优先播放活动面板；若活动面板不可播放则播放非活动面板；若都不可播放则把非活动面板切到轨道面板并播放
  - 用户原话: “现在只有全屏后能直接按空格播放,然后再退出全屏也可以,但是如果不进入全屏一次就不行,我想要的是按下空格,如果活动面板可以播放,则播放,如果不可以,则播放非活动面板,如果都不可以就把非活动面板切换成轨道面板并播放”
  修改过1次: 空格播放按可播放面板选择目标并必要时切换到轨道面板; scripts/simple_daw.gd; simple_daw._toggle_transport_playback/_resolve_space_play_slot/_slot_can_play/_play_from_slot/_resolve_playback_mode_for_slot/_get_playhead_start_beats_for_slot
  修改过2次: roll/piano/step 仅在 active clip 有音符时可播放，空 clip 回退到轨道面板; scripts/simple_daw.gd; simple_daw._slot_can_play
  修改过3次: 空格捕获改为 _input 并避开文本输入焦点，避免需全屏才生效; scripts/simple_daw.gd; simple_daw._input/_is_text_input_focused
- 29 轨道面板播放头可拖动
  - 状态: 待处理
  - 问题描述: 播放头支持拖动，且可拖拽时鼠标样式要变化
  - 用户原话: “轨道面板的播放头应该可以拖动”
  修改过2次: 播放头拖动+修复参数重名警告; scripts/arrangement_lane.gd, scripts/panel_slot.gd, scripts/simple_daw.gd; arrangement_lane._try_begin_playhead_drag/_update_playhead_drag/_gui_input, panel_slot._on_arrangement_playhead_drag_started/_on_arrangement_playhead_time_changed, simple_daw._on_arrangement_playhead_drag_started/_on_arrangement_playhead_time_changed
  修改过3次: 播放头可拖拽区域 hover 时切换鼠标样式; scripts/arrangement_lane.gd; arrangement_lane._is_playhead_hovered/_try_begin_playhead_drag/_end_playhead_drag/_gui_input
- 20 钢琴卷帘 Ctrl+左键框选音符
  - 状态: 待处理
  - 问题描述: 钢琴卷帘支持按住 Ctrl + 左键框选音符
  - 用户原话: “钢琴卷帘面板,按住ctrl后左键可以框选音符”
  修改过1次: Ctrl+左键框选并高亮选中音符; scripts/input_controller.gd, scripts/notes_model.gd, scripts/notes_view.gd; input_controller._begin_box_selection/_update_box_selection/_end_box_selection, notes_model.set_selection/is_note_selected, notes_view._draw_note/_draw
- 27 切换 MIDI 后部分轨道不发声
  - 状态: 暂缓（用户排查中）
  - 问题描述: 导入/切换 MIDI 后偶发部分轨道无声音，复现不稳定，需要更多信息
  - 用户原话: “有时候切换mid文件后,会出现一些轨道不发声的问题,并且复现切换不一定会出现问题,总之不知道为什么”
  修改过1次: 非发声轨道灰化; scripts/arrangement_lane.gd; arrangement_lane._draw_tracks/_draw_track_clips/_draw_clip_label/_draw_clip_notes/_draw_external_drag_preview/_dim_color/_is_track_solo/_is_track_muted/_has_any_solo_track

## Backlog (Other Open)
- U5 MIDI 导入量化与自动化播放频率
  - 状态: 待处理
  - 问题描述: 导入量化、渲染与播放分离、线性插值发 event、提供可选频率/选项
  - 用户原话: “我关心的是midi文件导入后有没有根据时间分辨率做量化的问题,以及我希望渲染和实际输入给播放系统不同,应该按照daw流行的频率或者有个有个选择框用户可以选择,根据点与点之间线性插值得到数据发出event.”
  修改过3次: 追加问题描述并保留用户原话; issue.md; N/A
- U6 自动化已生效的反馈
  - 状态: 待处理
  - 问题描述: 导入 MIDI 后修改 pan 包络可听到效果，说明播放路径已接入
  - 用户原话: “实际自动化/渲染曲线现在是存在的,我已经通过导入一个mid文件后修改pan的包络并观察到了效果”
  修改过3次: 追加问题描述并保留用户原话; issue.md; N/A
- U1 包络面板画点卡顿
  - 状态: 待处理
  - 问题描述: 低频、隐性、需定位
  - 争议: 你不认同“实时画实时看导致卡顿”的解释
  - 用户原话: “有时候包络面板画点的时候会卡顿”“出现频率有点低,感觉可能属于很隐性的bug”“这种实时画实时看在大部分时间都没感受到卡顿,说明原因不在于它”
  修改过3次: 追加问题描述并保留用户原话; issue.md; N/A

## Resolved
- 已解决内容已移动到 `issue_resolved.md`
