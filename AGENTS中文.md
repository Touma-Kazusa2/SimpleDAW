# AGENTS中文.md

## 目的
- 提供本仓库内自动化修改与审阅的项目级规则。

## 编码
- 所有文件读写以及 PowerShell 命令一律使用 UTF-8（例如 `Get-Content -Encoding UTF8`、`Set-Content -Encoding UTF8`）。
- 若出现乱码，先用 UTF-8 重新读取再编辑。

## 项目概览
- 主场景：`simple_daw.tscn`（见 `project.godot`）。
- 核心调度：`scripts/simple_daw.gd`（UI 绑定、面板槽、选区条、播放、导入/导出）。
- 播放引擎：`scripts/playback_engine.gd`（实时事件调度/chase；使用 `scripts/engine_core.gd`、`scripts/engine_snapshot_builder.gd`、`scripts/midi_player_sink.gd`）。
- 钢琴卷帘模块：`piano_roll.tscn` 及 `scripts/main.gd`、`scripts/input_controller.gd`、`scripts/notes_model.gd`、`scripts/notes_view.gd`、`scripts/grid.gd`、`scripts/playhead.gd`、`scripts/piano_keyboard.gd`。
- 多面板槽：`scripts/panel_slot.gd`（模式切换、滚动同步、轨道面板、3D、评论/包络）。
- 轨道面板：`scripts/arrangement_lane.gd`。
- 包络/评论：`scripts/envelope_lane.gd`、`scripts/comment_lane.gd`，模型在 `scripts/envelope_model.gd`。
- 数据模型：`scripts/models/*`（project/track/clip/automation/transport）。
- MIDI 导入导出：`scripts/midi_importer.gd`、`scripts/midi_exporter.gd`，插件在 `addons/midi/*`。
- Soundfont 路由：`scripts/soundfont_manager.gd`（按轨道 soundfont 复用 bank/播放器）。
- 3D 面板：`scripts/three_d_panel.gd`。

## 维护
- 修改代码后，考虑“项目概览”是否需要更新（新增/改名文件、入口变化）。
- 若概览有实质变化，需同步更新 `AGENTS.md` 与 `AGENTS中文.md`。

## 编辑
- 尽量做最小、局部的修改；避免无关的格式化。
- 注释简洁，仅在确实提升理解时添加。
- 除非明确要求，否则保持现有风格与约定。
- 用户确认需求后，先说明计划改动点与涉及文件，再开始修改。

## 安全
- 未经明确要求，不运行破坏性命令。
- 不删除或回退与当前任务无关的改动。

## 测试
- 若执行测试，说明使用的命令及结果。
- 若未执行测试，说明原因。

## 同步规则
- 每次修改 `AGENTS.md` 时，同步修改 `AGENTS中文.md`（若不存在则创建）。
