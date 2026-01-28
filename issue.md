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
  - （已整理）音色切换能力
  - （已整理）轨道面板鼠标悬浮到轨道名时出现solo和mute按钮
  - （已整理）轨道面板也可以通过中键纵向拉伸
  - （已整理）钢琴卷帘面板,按住ctrl后左键可以框选音符
  - （已整理）轨道面板的比例缩放有问题,最大应该是最长轨道的两倍,现在似乎超了,并且缩放比例不连续
  - （已整理）轨道面板,播放中的音符为红色
  - （已整理）midi设备现在是默认连接,选择按钮根本没起到作用,并且应该每次按下选择按钮时都重新检测一次设备
  - （已整理）选区条旁边的同步按钮不见了
  - （已整理）包络面板的添加按钮应该在名字的上面

## Current Focus (Top 4)
- 17 轨道面板鼠标悬浮到轨道名时出现 solo/mute 按钮
  - 状态: 待处理
  - 问题描述: 轨道名区域 hover 时显示 solo/mute 按钮并可点击切换；播放时按 mute/solo 过滤
  - 用户原话: “轨道面板鼠标悬浮到轨道名时出现solo和mute按钮”
  修改过1次: 轨道名 hover 显示 S/M 并点击切换；播放时按 mute/solo 过滤轨道；scripts/arrangement_lane.gd, scripts/models/track_model.gd, scripts/playback_engine.gd, scripts/engine_snapshot_builder.gd; arrangement_lane._draw_track_label/_draw_track_label_buttons/_label_button_hit/_toggle_track_solo/_toggle_track_mute, track_model.set_muted/set_solo, playback_engine._capture_model_data, engine_snapshot_builder._build_tracks_cache/_build_tracks_from_data/_should_skip_track
- 18 音色切换能力
  - 状态: 待处理
  - 问题描述: 按轨道切换音色；点击 Browser 的 track 名弹出音色选择框
  - 用户原话: “音色切换能力”
  修改过1次: 点击 Browser track 名时弹出 SoundFont 选择框；scripts/simple_daw.gd; simple_daw._on_track_tree_track_selected
- 19 轨道面板中键纵向拉伸
  - 状态: 待处理
  - 问题描述: 中键拖拽统一缩放全部轨道行高度（现有为逐行左键拉伸）
  - 用户原话: “轨道面板也可以通过中键纵向拉伸”
  修改过1次: 中键拖拽统一缩放全部轨道行高度；scripts/arrangement_lane.gd; arrangement_lane._begin_global_resize/_update_global_resize/_end_global_resize/_gui_input
- 20 钢琴卷帘 Ctrl+左键框选音符
  - 状态: 待处理
  - 问题描述: 钢琴卷帘支持按住 Ctrl + 左键框选音符
  - 用户原话: “钢琴卷帘面板,按住ctrl后左键可以框选音符”
  修改过1次: Ctrl+左键框选并高亮选中音符；scripts/input_controller.gd, scripts/notes_model.gd, scripts/notes_view.gd; input_controller._begin_box_selection/_update_box_selection/_end_box_selection, notes_model.set_selection/is_note_selected, notes_view._draw_note/_draw

## Envelope Panel (已处理)
- 4 包络面板可以纵向放大,使得其右侧的滑动条有意义
  修改过1次: 新增纵向缩放(中键拖拽)与包络面板纵向滚动条支持；文件: scripts/envelope_lane.gd, scripts/panel_slot.gd
  - 用户原话: 已剪切至 `resolved_user_quotes/4_包络面板纵向放大.md`
- 5 包络面板的高度根据其属性设置,初始化时铺满面板
  修改过1次: 加入 v1 参数范围表并在参数切换时重置缩放/滚动以铺满；文件: scripts/envelope_lane.gd
  - 用户原话: 已剪切至 `resolved_user_quotes/5_包络面板高度铺满.md`
  - 说明: 若不同参数上下限一致则无需处理；若不一致需定义映射范围。
- 6 包络面板的默认线在有点的时候,最后一个点后面画随其高度的水平直线而非先垂直向下到中间位置
  修改过1次: 末尾默认线改为沿最后一个点的高度水平延伸; 文件: scripts/envelope_lane.gd
  修改过2次: 默认线改为蓝色；末尾水平线用橙色，若高度为0则沿用默认线颜色；文件: scripts/envelope_lane.gd
- 7 包络面板可以新增自动化曲线
  修改过1次: 增加“+”按钮自动创建新参数曲线并切换选中；文件: scripts/panel_slot.gd, panel_slot.tscn
  - 用户原话: 已剪切至 `resolved_user_quotes/7_包络面板新增自动化曲线.md`

## Resolved
- 已解决内容已移动到 `issue_resolved.md`

## Backlog (Untriaged)
- U1 包络面板画点卡顿
  - 问题描述: 低频、隐性、需定位
  - 争议: 你不认同“实时画实时看导致卡顿”的解释
  - 用户原话: “有时候包络面板画点的时候会卡顿”“出现频率有点低,感觉可能属于很隐性的bug”“这种实时画实时看在大部分时间都没感受到卡顿,说明原因不在于它”
  修改过3次: 追加问题描述并保留用户原话; issue.md; N/A
- U5 MIDI 导入量化与自动化播放频率
  - 问题描述: 导入量化、渲染与播放分离、线性插值发 event、提供可选频率/选项
  - 用户原话: “我关心的是midi文件导入后有没有根据时间分辨率做量化的问题,以及我希望渲染和实际输入给播放系统不同,应该按照daw流行的频率或者有个有个选择框用户可以选择,根据点与点之间线性插值得到数据发出event.”
  修改过3次: 追加问题描述并保留用户原话; issue.md; N/A
- U6 自动化已生效的反馈
  - 问题描述: 导入 MIDI 后修改 pan 包络可听到效果，说明播放路径已接入
  - 用户原话: “实际自动化/渲染曲线现在是存在的,我已经通过导入一个mid文件后修改pan的包络并观察到了效果”
  修改过3次: 追加问题描述并保留用户原话; issue.md; N/A
- 21 轨道面板比例缩放异常
  - 状态: 待处理
  - 问题描述: 轨道面板缩放比例上限应为最长轨道的 2 倍，且缩放比例连续
  - 用户原话: “轨道面板的比例缩放有问题,最大应该是最长轨道的两倍,现在似乎超了,并且缩放比例不连续”
- 22 轨道面板播放中音符为红色
  - 状态: 待处理
  - 问题描述: 轨道面板播放中的音符显示为红色
  - 用户原话: “轨道面板,播放中的音符为红色”
- 23 MIDI 设备选择与刷新
  - 状态: 待处理
  - 问题描述: 设备选择按钮需生效，按下时应重新检测设备；当前行为为默认连接
  - 用户原话: “midi设备现在是默认连接,选择按钮根本没起到作用,并且应该每次按下选择按钮时都重新检测一次设备”
- 24 选区条旁边的同步按钮不见了
  - 状态: 待处理
  - 问题描述: 选区条旁的同步按钮缺失，需要恢复
  - 用户原话: “选区条旁边的同步按钮不见了”
- 25 包络面板添加按钮位置
  - 状态: 待处理
  - 问题描述: 包络面板添加按钮应在名字的上方
  - 用户原话: “包络面板的添加按钮应该在名字的上面”
