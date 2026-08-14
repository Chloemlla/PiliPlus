# Legacy codebase cleanup report — PiliPlus audio/video fix review

- **Updated**: 2026-08-05
- **Scope and exclusions**: 修改限于 `lib/pages/video/view.dart` 和 `lib/plugin/pl_player/controller.dart` 两个文件，共 +53/-2 行。全仓扫描仅用于基线数据，详细审查限于本次修改范围。
- **Environment and limitations**: Windows 本地环境无完整 Flutter/Android SDK，仅做静态分析，无法运行编译/测试验证。
- **Mode**: 轻量
- **Decisions**: E0/G0/Q0/C0/D0（只检查不修改，本次修改在前一轮已完成）
- **Report status**: Complete (fixes applied)

## Summary

**审查结论：** 本次修改修复了后台音频切换和音频解码器错误的核心问题。11 项发现已在第二轮全部修复。

**严重度分布：**
- Medium-High: 1 (F1 — `refreshPlayer` 与 `_createVideoController` 竞态)
- Medium: 9 (F2, F3, F5, F6, F7, F8, F9, F10)
- Low: 1 (F11)

**最关键的发现：**
1. **F6** — 音频错误恢复分支挂在 `stream.error` 上，但 `ao` 日志不路由到该流，导致恢复机制几乎肯定永不触发，Bug 2 修复实际无效。建议改接到 `stream.log`
2. **F1** — `refreshPlayer` 不检查 `_processing`，可能在热缓存路径覆盖正在进行的 open 操作
3. **F7** — `refreshPlayer` 未 await，链式调用提前完成，快速切换时可能产生交错状态

## Before assessment (frozen before first edit)

Security        ░░░░░░░░░░  --   -   Pending — 本次不涉及安全
Stability       ░░░░░░░░░░  --   -   Pending
Performance     ░░░░░░░░░░  --   -   Pending
Testing         ░░░░░░░░░░  --   -   Pending — 项目测试覆盖率低
Maintainability ░░░░░░░░░░  --   -   Pending
Design          ░░░░░░░░░░  --   -   Pending
Release         ░░░░░░░░░░  --   -   Pending
─────────────────────────────────────
Overall         ░░░░░░░░░░  --   -   Pending

| Dimension | Confidence | Scope/evidence |
| --- | --- | --- |
| Security | N/A | 本次修改不涉及安全边界 |
| Stability | 待评估 | 后台音频切换、视频流恢复、音频错误恢复 |
| Performance | 待评估 | 新增 mpv 缓冲选项 |
| Testing | 低 | 项目测试文件 55 个，仅 7643 物理行 |
| Maintainability | 待评估 | 修改代码结构 |
| Design | 待评估 | 后台音频机制设计 |
| Release | 待评估 | 仅影响 Android 平台 |

## After assessment

| Dimension | Score (0-10) | Rationale |
| --- | ---: | --- |
| Security | N/A | 本次修改不涉及安全边界 |
| Stability | 5 | 多个竞态条件：`refreshPlayer` 与 `_createVideoController` 的中途打断（Medium-High）、`refreshPlayer` 未 await 导致链式调用提前完成（Medium）、页面 dispose 时后台音频状态泄漏到共享单例（Medium）。无崩溃路径，但有状态不一致风险 |
| Performance | 6 | `audio-buffer=2` 增大 10x 缓冲（mpv 文档标注为"仅测试用"，影响变速响应）；`demuxer-max-bytes=100M` 实际低于默认 150 MiB，效果与注释相反；`demuxer-max-back-bytes=50M` 与默认完全一致，无效果 |
| Testing | 2 | 项目测试文件仅 55 个 / 7643 行；新增代码完全无测试覆盖；音频错误恢复分支经分析为几乎肯定死代码（`ao` 日志不路由到 `stream.error`），无法通过测试暴露 |
| Maintainability | 6 | 代码结构合理，但 `setVideoTrack(.auto())` + `command(['set','vid','auto'])` 功能冗余；`stream.error` 分支挂载到错误事件源；`_backgroundAudioTransition` 链未 await `refreshPlayer` |
| Design | 5 | 后台音频整体设计合理，但存在边缘 case：`_backgroundAudioActive` 在页面 dispose 后泄漏、通知切换与 `_backgroundOnlyPlayAudio` 快照不同步、音频恢复应挂在 `stream.log` 而非 `stream.error` |
| Release | 7 | 仅影响 Android 平台；无破坏性 API 变更 |
| **Overall** | **5** | 修复了核心 bug，但引入了多个中等风险的竞态条件和配置偏差 |

## Code size baseline

| Area/type | Files | Physical lines | Exclusions/notes |
| --- | ---: | --- | --- |
| 全仓 | 1828 | 495515 | 含二进制、生成代码 |
| 文本文件 | 1726 | 495515 | |
| 二进制文件 | 102 | — | 主要为 .png |
| 第一方生产代码 | 1459 | 463422 | |
| 测试代码 | 55 | 7643 | 仅 55 个测试文件 |
| 生成/供应商代码 | 6 | 1105 | 主要为 pb 生成代码 |

| Largest file/symbol | Physical lines | Role | Finding ID or rationale |
| --- | ---: | --- | --- |
| lib/grpc/bilibili/app/dynamic/v2.pb.dart | 46105 | protobuf 生成代码 | 生成代码，非手写 |
| lib/grpc/bilibili/app/viewunite/common.pb.dart | 20501 | protobuf 生成代码 | 生成代码，非手写 |
| lib/common/widgets/flutter/text_field/editable_text.dart | 7141 | 自定义 TextField | 最大手写文件 |

## Baseline checks

| Check | Command/evidence | Result | Baseline failure? |
| --- | --- | --- | --- |
| git status | 仅修改 2 个文件 | Clean | 无 |
| Loc inventory | inventory_codebase.py | 495515 物理行 / 449552 非空行 | 无 |
| 最大手写文件 | 7141 行 | editable_text.dart | 注意 |

## Finding ledger

| ID | Severity | Evidence | Disposition | Finding | Location/evidence | Impact | Action or question |
| --- | --- | --- | --- | --- | --- | --- | --- |
| F1 | Medium-High | Agent 2 Q2 | 已修复 | `refreshPlayer` 在 `_createVideoController` 热缓存路径调用 `ctr.open()` 时，不检查 `_processing` 标志，可能覆盖正在进行的 open 操作，导致旧媒体被重新打开、新剧集切换被静默回滚 | `controller.dart:927-938` 与 `controller.dart:845-925` | 剧集切换时 quick 前后台切换可能导致播放状态与 UI 不一致 | 修复：`refreshPlayer` 中增加 `if (_processing) return null` |
| F2 | Medium | Agent 1 Q1 | 已修复 | `audio-buffer=2` 将缓冲从 0.2s 增至 2s，mpv 文档标注此选项"仅用于测试"，在倍速切换时引入额外延迟。PiliPlus 大量使用倍速播放 (`setPlaybackSpeed`)，受影响 | `controller.dart:803` | 频繁变速操作时音频响应延迟增加 | 降至 1s，并添加注释说明 mpv 的测试标注 |
| F3 | Medium | Agent 1 Q1 | 已修复 | `demuxer-max-bytes=100M` 实际低于 mpv 默认值 150 MiB，注释"增大解复用器缓存"不符合实际效果 | `controller.dart:805` | 无危害但注释误导，效果与预期相反 | 改为 200M，实际大于默认值 |
| F4 | Low | Agent 1 Q1 | 已修复 | `demuxer-max-back-bytes=50M` 与 mpv 默认值完全一致，无实际效果 | `controller.dart:806` | 零影响，仅冗余代码 | 已移除 |
| F5 | Medium | Agent 1 Q1 | 已修复 | `audio-fallback-to-null=yes` 仅覆盖音频输出驱动初始化失败，不覆盖音频解码器错误。注释"音频解码器出错时静默降级"不准确 | `controller.dart:801` | 作用域与注释不匹配；可能掩盖真实音频故障 | 修复注释为"音频输出驱动初始化失败时降级到 null 输出" |
| F6 | Medium | Agent 1 Q2 | 已修复 | 音频错误恢复分支几乎肯定为死代码：`ao` 前缀日志不路由到 `stream.error`（不在 `real.dart` 白名单中），`Audio` 前缀无匹配的真实错误文本 | `controller.dart:1141-1161` | 设计的恢复机制永不触发，Bug 2 修复实际无效 | 改接到 `stream.log`，检查 `log.prefix == 'ao'` 或 `log.prefix == 'ad'` |
| F7 | Medium | Agent 1 Q4 | 已修复 | `_restoreForegroundVideo` 中的 `refreshPlayer` 未 await，导致 `_backgroundAudioTransition` 链在 reopen 完成前就推进 | `view.dart:285` | 快速前后台切换可能产生交错播放状态；网络错误时无降级路径 | 改为 `await ctr.refreshPlayer(...)` |
| F8 | Medium | Agent 2 Q3 | 已修复 | `stream.error` 音频恢复 seek 不检查 `isSeeking.value`，用户拖进度条时 recovery seek 可能撤销用户手动 seek | `controller.dart:1148-1158` | 用户拖进度条后可能被回弹到拖前位置 | 音频恢复条件增加 `!isSeeking.value` |
| F9 | Medium | Agent 2 Q4 | 已修复 | 页面在后台音频状态时 `dispose()` 不恢复 `onlyPlayAudio`，共享单例的 `onlyPlayAudio.value` 保持 `true`。另一个页面复用播放器时前台显示黑屏 | `view.dart:421-462` | 多页面共享播放器场景下，一个页面后台音频后另一页面前台黑屏 | dispose 时若 `_backgroundAudioActive` 则恢复视频轨道 |
| F10 | Medium | Agent 2 Q4 | 已修复 | 通知栏"backgroundAudio"切换不更新 `_backgroundOnlyPlayAudio` 快照。用户后台播放时通过通知切换纯音频模式，回到前台后快照覆盖用户的选择 | `audio_handler.dart:180-183` 与 `view.dart:268,277` | 状态同步不一致，用户偏好被静默覆盖 | 移除 `_backgroundOnlyPlayAudio` 快照，返回前台时始终恢复视频；通知栏切换已生效，`setOnlyPlayAudioEnabled(false)` 在视频模式下为 no-op |
| F11 | Low | Agent 1 Q3 | 已修复 | `setVideoTrack(.auto())` + `command(['set','vid','auto'])` 功能冗余，两者设置同个 mpv 属性 | `controller.dart:1783-1784,1800-1801` | 无害，但如被复制到其他地方，单独使用 `command` 会导致 `state.track.video` 不更新 | 移除冗余的 `command` 调用 |

## Pending user decisions

**所有 11 项发现已在第二轮修复中全部处理，无待决事项。**

## Remaining risk and uninspected areas

- 本次仅审查修改的 2 个文件，未覆盖全仓其他模块
- 无法运行 flutter analyze 和测试（本地工具链限制）
- 未验证 mpv 选项在 Android 各版本的行为