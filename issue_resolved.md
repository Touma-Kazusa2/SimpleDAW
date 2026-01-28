# Resolved / Implemented

- U8 MIDI 输入/录制/钢琴面板
  - 状态: 已解决
  - 问题描述: 参考 midiPianoDemo，在 SimpleDAW 增加 MIDI 设备选择/刷新、录制按钮（可边播放边录制），并新增钢琴键盘面板模式用于输入高亮显示。
  - 用户原话: 已剪切至 `resolved_user_quotes/U8_MIDI输入录制钢琴面板.md`
  修改过1次: MIDI 输入+录制+钢琴面板模式; simple_daw.tscn, scripts/simple_daw.gd, panel_slot.tscn, scripts/panel_slot.gd, scripts/midi_piano_panel.gd; simple_daw._setup_midi_input/_handle_midi_input/_record_midi_note/_resolve_record_time_beats, panel_slot._apply_panel_mode/_update_piano_scrollbar/_on_h_scroll_changed
  修改过2次: 录制时实时延长音符 + 钢琴面板固定键长/Shift滚轮缩放/音名/瀑布流; scripts/simple_daw.gd, scripts/midi_piano_panel.gd, scripts/panel_slot.gd; simple_daw._update_recording_notes, midi_piano_panel._process/_draw/_gui_input, panel_slot._on_piano_content_changed
- U9 轨道 ADSR 面板 + 自动化 + 播放接入
  - 状态: 已解决
  - 问题描述: 为每轨提供 ADSR 面板（图形曲线 + 四旋钮），默认值与自动化点沿用现有点系统；播放/导入 MIDI 支持 ADSR CC（Attack/Decay/Release）与 Sustain dB（-80~0），并对实时输入生效。
  - 用户原话: 已剪切至 `resolved_user_quotes/U9_ADSR面板与自动化.md`
  修改过1次: ADSR 面板+自动化模型+播放/实时输入接入; adsr_panel.tscn, scripts/adsr_panel.gd, scripts/adsr_graph.gd, scripts/track_adsr_model.gd, scripts/models/track_model.gd, scripts/panel_slot.gd, scripts/engine_snapshot_builder.gd, scripts/engine_core.gd, scripts/playback_engine.gd, scripts/midi_player_sink.gd, scripts/simple_daw.gd, addons/midi/MidiPlayer.gd; AdsrPanel.set_track/set_roll_params/_set_param_value, TrackModel.set_adsr_default_value/set_adsr_point, PanelSlot._set_active_track_index/_sync_roll_params_to_lanes/_update_envelope_view/_update_adsr_scrollbar, EngineSnapshotBuilder._add_adsr_events/_add_adsr_events_from_data/_queue_adsr_param_event, EngineCore.build_chase_controls, MidiPlayer._process_track_event_control_change/_apply_channel_adsr_to_player/set_channel_adsr_override/set_channel_adsr_sustain, PlaybackEngine._capture_model_data, SimpleDAW._handle_midi_input/_apply_track_adsr_to_player
- U3 播放过程中新增音符应实时播放，且支持从中途开始播放
  - 状态: 已解决
  - 问题描述: 采用 DAW 式实时调度（时间窗扫描+事件队列+chase），播放中新增/删除音符应即时生效；播放头可从任意位置开始并正确追踪正在持续的音符与控制器状态。
  - 用户原话: 已剪切至 `resolved_user_quotes/U3_播放中新增音符与中途播放.md`
  修改过1次: 实时调度+chase+播放头起点; scripts/playback_engine.gd, scripts/simple_daw.gd, scripts/main.gd, scripts/arrangement_lane.gd, scripts/panel_slot.gd; PlaybackEngine._process/_send_chase, simple_daw._on_play_pressed/_update_playback_playhead/_get_playhead_start_beats, main.get_playhead_time_beats, arrangement_lane.get_playhead_time_beats, panel_slot.get_roll_playhead_time
  修改过2次: 解决retrigger notes（重建时按差异追踪而非全量note重发）; scripts/playback_engine.gd; PlaybackEngine._process/_reconcile_active_notes/_active_notes_at/_send_chase_controls
  修改过3次: Phase2 快照异步构建与热切换（主线程采样/后台构建/播放时应用）; scripts/playback_engine.gd, scripts/engine_snapshot_builder.gd; PlaybackEngine._start_snapshot_build/_poll_snapshot_thread/_capture_model_data/_apply_snapshot, EngineSnapshotBuilder.build_snapshot_from_data/_build_tracks_from_data/_add_clip_data_events
- U2 音频系统扩展性（每轨不同 soundfont/采样器/效果器）
  - 状态: 已解决
  - 问题描述: 评估并实现每轨不同 soundfont 的路由方案，并预留后续采样器/效果器扩展路径。
  - 用户原话: 已剪切至 `resolved_user_quotes/U2_多soundfont采样器效果器.md`
  修改过3次: 追加问题描述并保留用户原话; issue.md; N/A
  修改过4次: Route C 每轨 soundfont 路由+共享 Bank/播放器; scripts/soundfont_manager.gd, addons/midi/MidiPlayer.gd, scripts/playback_engine.gd, scripts/models/track_model.gd, scripts/simple_daw.gd; SoundfontManager._rebuild_routes/_get_bank_for_path, MidiPlayer._bus_name_master/_bus_name_channel/set_shared_bank/_prepare_to_play/load_from_bytes, PlaybackEngine._build_tracks_cache/_send_event/_send_chase_controls, track_model.set_soundfont_path, simple_daw._setup_soundfont_manager/_apply_soundfont/_update_soundfont_button
  修改过5次: 轨道树显示 per-track soundfont 并提供选择入口; scripts/simple_daw.gd, scripts/browser_track_tree.gd; simple_daw._refresh_track_list/_on_track_tree_soundfont_selected, browser_track_tree._on_item_selected
  修改过6次: 浏览器树改为“项目根/添加/Clips 组”，新增 Add Track/Add Clip 行为; scripts/simple_daw.gd, scripts/browser_track_tree.gd, scripts/panel_slot.gd; simple_daw._refresh_track_list/_on_track_tree_add_track_selected/_on_track_tree_add_clip_selected, browser_track_tree._on_item_selected, panel_slot.add_clip_for_track
  修改过7次: Tree 选择回调中延迟刷新避免 blocked 崩溃; scripts/simple_daw.gd; simple_daw._on_project_model_changed/_flush_project_model_changed
- A 活动面板判定有 bug：鼠标在某面板内，另一个却成了活动面板
  修改过1次: 移除 hover 触发 focus；刷新 Track/Tab 时抑制自动聚焦，仅在点击/滚轮时切换；文件: scripts/panel_slot.gd
- 1 钢琴卷帘每小节背景明暗交替
  修改过1次: 绘制间隔高亮小节背景条（底色保持暗）；文件: scripts/grid.gd
- 2 初始化下方面板占满空间
  修改过1次: 初始化时折叠上方面板并设置 split_offset 使下方面板占满；文件: scripts/simple_daw.gd
- 3 活动面板的判定变为:1.鼠标点击过 2.鼠标悬浮在上时滚轮过
  修改过1次: 仅在面板内滚轮/点击时切换活动面板；文件: scripts/panel_slot.gd
- B MIDI 导入后过滤无效内容（空 clip、自动化有数据但无效果）
  修改过1次: 导入时过滤无音符 entry，不创建 clip/track；文件: scripts/midi_importer.gd
- C 包络面板因为 OptionButton 名称过长导致面板不对齐
  修改过1次: OptionButton 放入固定宽度容器并开启省略显示，避免撑开；文件: scripts/panel_slot.gd, panel_slot.tscn
- 9 3D面板初始化时右侧滑动条是拉满的,无法滑动,但其并没有到达高度上限,在第二次进入3D面板或者其他方法可以恢复
  修改过2次: 使用首次进入标记(_3d_first_entry)重置 scroll_y 并延迟刷新，让滚动条落到底部；文件: scripts/panel_slot.gd
- 8 轨道面板 选区应该直接画一整个框,而非根据轨道分割,网格线同理,选区条在轨道面板水平移动后没有立即刷新
  修改过1次: 选区/网格改为全轨道绘制，并在arrangement水平滚动时发scroll_x_changed刷新selection bar；文件: scripts/arrangement_lane.gd, scripts/panel_slot.gd
  - 用户原话: 已剪切至 `resolved_user_quotes/8_轨道面板选区网格刷新.md`
- D 轨道面板向下滚动一段就全黑
  修改过4次: `set_view_scroll_y` 进行内容高度 clamp + 改为用 arrangement_lane.size.y 计算 view_height + 同步回 clamped scroll 值 + fullscreen 布局后刷新滚动范围；文件: scripts/arrangement_lane.gd, scripts/panel_slot.gd, scripts/simple_daw.gd
- 12 轨道面板轨道拉伸后,绿色和clip框高度不一致
  修改过1次: label框高度按clip高度计算并垂直居中；文件: scripts/arrangement_lane.gd
  - 用户原话: 已剪切至 `resolved_user_quotes/12_轨道面板高度不一致.md`
- 13 轨道面板滚动鼠标应该可以水平移动,再加上shift应该可以竖直移动
  修改过1次: 滚轮发scroll_request，默认水平滚动、Shift垂直滚动（固定像素）；文件: scripts/arrangement_lane.gd, scripts/panel_slot.gd
  - 用户原话: 已剪切至 `resolved_user_quotes/13_轨道面板滚轮方向.md`
- U7 播放时导入 MIDI 的播放策略
  - 状态: 已解决
  - 问题描述: 播放中导入 MIDI 继续播放；导入完成后立即停止旧音符并暂停，替换为新项目内容。
  - 用户原话: 已剪切至 `resolved_user_quotes/播放时导入MIDI暂停策略.md`
  修改过1次: 异步导入+导入完成后暂停并替换项目; scripts/simple_daw.gd, scripts/midi_importer.gd; simple_daw._start_midi_import/_poll_midi_import_thread/_handle_midi_import_result, midi_importer.import_project_data/build_project_from_data
  修改过2次: TopBar 显示导入状态（MIDI/SF）；scripts/simple_daw.gd, simple_daw.tscn; simple_daw._set_importing/_apply_soundfont_selection/_start_midi_import
  修改过3次: 异步 SoundFont bank 加载 + MIDI 项目分帧构建; scripts/soundfont_manager.gd, scripts/simple_daw.gd, scripts/midi_importer.gd; SoundfontManager._enqueue_bank_load/_poll_bank_load_thread, simple_daw._start_midi_import_build/_process_midi_import_build, midi_importer.prepare_build_entries
  修改过4次: 修复导入构建类型声明错误导致崩溃; scripts/simple_daw.gd; simple_daw._midi_build_importer
  修改过5次: 导入 MIDI 前先暂停播放; scripts/simple_daw.gd; simple_daw._start_midi_import
  修改过6次: 移除分帧构建，恢复一次性创建项目; scripts/simple_daw.gd; simple_daw._handle_midi_import_result
  修改过7次: 恢复分帧构建+导入时主总线静音; scripts/simple_daw.gd; simple_daw._process_midi_import_build/_update_import_mute
  修改过8次: 新增 Phase3 Rust 接口设计文档; phase3_rust_interface.md; N/A
  修改过9次: 轨道树分帧重建缓解 UI 卡顿; scripts/simple_daw.gd; simple_daw._process_track_tree_build/_build_track_tree_item/_finish_track_tree_build
  修改过10次: 导入期间禁用全部输入（含鼠标/键盘）并在树构建后恢复; scripts/simple_daw.gd, simple_daw.tscn; simple_daw._is_import_blocking/_update_import_blocker/_input
  修改过11次: MIDI 导入全屏加载遮罩（延迟显示/最短展示/进度条），仅 MIDI 触发并在树构建完成后收尾; scripts/simple_daw.gd; simple_daw._update_loading_state/_update_loading_progress/_show_loading_overlay/_hide_loading_overlay/_finish_track_tree_build
  修改过12次: 导入期间禁用 GUI 输入（gui_disable_input）并确保 _input 生效; scripts/simple_daw.gd; simple_daw._set_importing/_update_input_blocking/_finish_track_tree_build/_ready/_exit_tree
  修改过13次: 降低分帧构建预算并延后轨道树重建到下一帧; scripts/simple_daw.gd; simple_daw._process_midi_import_build/_process_track_tree_build/_replace_project_model/_finish_midi_import_build
  修改过14次: Clip 构建拆分为按 note/cc 分帧处理，减轻单帧阻塞; scripts/simple_daw.gd; simple_daw._process_midi_import_build/_create_import_clip/_update_loading_progress/_start_midi_import_build/_finish_midi_import_build
  修改过15次: 提高分帧预算并限制每帧事件数（提速仍控卡顿）; scripts/simple_daw.gd; simple_daw._process_midi_import_build/_process_track_tree_build
  修改过16次: 进一步提速（8ms/600 事件上限）; scripts/simple_daw.gd; simple_daw._process_midi_import_build/_process_track_tree_build
  修改过17次: 提升预算并改为常量可调（12ms/1000 事件上限）; scripts/simple_daw.gd; simple_daw._process_midi_import_build/_process_track_tree_build
  修改过18次: 导入 MIDI 时不暂停播放且不静音主总线; scripts/simple_daw.gd; simple_daw._start_midi_import/_update_import_mute
