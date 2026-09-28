# 性能审查与优化清单（2026-09-28）

> 依据 `verified-methodology.md` §二完整工作流与 `code-audit-methodology.md` 七类雷达，对 `lib/` 全量（1463 个 Dart 文件）做静态性能审查。
> 本仓库已相当成熟：`analysis_options.yaml` 已开启 `prefer_const_constructors` / `prefer_const_declarations` / `prefer_const_literals_to_create_immutables` / `use_named_constants`；`MediaQuery` 大量使用精细化访问器（`sizeOf`/`paddingOf` 22 处）；网络图片普遍带 `memCacheWidth/Height`（86 处）；弹幕过滤规则的正则在加载期一次性预编译。因此可落地的**安全**优化项数量有限，本文档只收录经逐处核查、行为等价、零风险的项，宁缺毋滥。
>
> 最终正确性以 GitHub Actions 为准（禁止本地构建/测试）。

## 判定原则

- 只做行为等价的优化，不夹带重构、不改语义。
- 每条含：编号、文件+行号、类别、问题、修法、状态。
- 收尾对照本清单逐条核对去向。

---

## A. 精细化 MediaQuery 访问（减少重建范围）

`MediaQuery.of(context)` 会订阅整个 `MediaQueryData`，任一指标（键盘、方向、字体缩放……）变化都会触发该 widget 重建。改用精细化访问器只订阅真正用到的那一项。

- [x] **A1** `lib/pages/danmaku_highlight/view.dart:350`
  - 类别：C-生命周期/重建范围
  - 问题：`MediaQuery.of(context).viewInsets.bottom` 订阅整份 MediaQuery
  - 修法：改为 `MediaQuery.viewInsetsOf(context).bottom`
  - 状态：已修

- [x] **A2** `lib/pages/danmaku_highlight/view.dart:475`
  - 类别：C-生命周期/重建范围
  - 问题：`MediaQuery.of(context).padding.bottom` 订阅整份 MediaQuery
  - 修法：改为 `MediaQuery.paddingOf(context).bottom`
  - 状态：已修

- [x] **A3** `lib/pages/download_manager/view.dart:238`
  - 类别：C-生命周期/重建范围
  - 问题：`MediaQuery.of(context).padding.bottom` 订阅整份 MediaQuery
  - 修法：改为 `MediaQuery.paddingOf(context).bottom`
  - 状态：已修

## B. 正则预编译（避免重复编译同一常量模式）

`RegExp(...)` 每次求值都会重新编译。将**常量模式**的内联正则提为 `static final`，与本仓库既有约定一致（`app_scheme.dart` 的 `uriDigitRegExp`、`danmaku_rule.dart` 的 `_regExp` 都已是 `static final`）。

- [x] **B1** `lib/services/download_manager_service.dart:315`
  - 类别：B-资源/重复计算
  - 问题：`_extractBvid` 每次调用都编译 `RegExp(r'BV\w+')`
  - 修法：提为 `static final _bvidRegExp`
  - 状态：已修

- [x] **B2** `lib/utils/app_scheme.dart` 多处深链解析内联正则
  - 类别：B-资源/重复计算
  - 问题：`^/detail/cv(\d+)`、`/pl(\d+)`、`/rl(\d+)`、`cv(\d+)`、`/au(\d+)`、`lists/(\d+)`、`relation/([a-z]+)`、`/ml(\d+)` 等常量模式在解析每条深链时现编译
  - 修法：全部提为 `static final`，复用既有静态正则风格
  - 状态：已修

- [x] **B3** `lib/services/synapse_ip_verification.dart:76`
  - 类别：B-资源/重复计算
  - 问题：`_normalizeFingerprint` 每次编译 `RegExp(r'^[a-zA-Z0-9_-]+$')`
  - 修法：提为 `static final _fingerprintRegExp`
  - 状态：已修

---

## 未采纳（记录理由，避免下次重复排查）

- `lib/models/user/danmaku_rule.dart` / `danmaku_rule_adapter.dart`：弹幕过滤正则已在规则加载期一次性编译，`remove()` 热路径复用，无需改动。
- `lib/common/widgets/image/network_img_layer.dart`：已带 `memCacheWidth/Height` 与缩略图 URL 归一，图片层已优化。
- `lib/pages/video/reply/widgets/reply_item_grpc.dart:776`、`header_control.dart` 的内联正则：均在 `onTap`/校验器/下载回调中，非渲染热路径，且部分为动态拼接，收益极低，保持不动以免夹带风险。
- 大范围 `const` 化 / `RepaintBoundary` 铺设：linter 已强制 `const`，盲目加 `RepaintBoundary` 可能反而增加层合成开销，非行为等价，不在本轮范围。
