# Fuck My Shit Mountain Audit Report

**Project:** PiliPlus  
**Audit mode:** architecture + data-integrity（关键功能链路静态复核）  
**Date:** 2026-07-09  
**Reviewer:** Codex（GPT-5）

---

## 1. Executive Summary / 执行摘要

PiliPlus 是一个功能面较大的跨平台 Flutter/GetX Bilibili 客户端。当前代码已经形成页面/控制器、HTTP/gRPC、播放器、下载服务和本地持久化等基本分区，并且近期为 Android 增加了 MMKV 热存储、持久化 codec 和相应测试。问题不在于“完全没有分层”，而在于分层边界经常被全局静态对象、双向 import 和页面直接写数据库绕过，导致功能修改、存储迁移和失败恢复的影响范围难以控制。

本次最严重的问题集中在数据迁移与不变量：MMKV 解码失败后会把已经过期的 Hive 快照重新当作权威来源，可能覆盖迁移后的新数据；MMKV 批量替换和批量写入没有原子性；设置导入仅检查 JSON section 是否为 Map，能够把越界枚举和非法列表持久化到启动关键路径；账户导入允许非规范 key，刷新和删除流程又没有清除别名记录，可能造成账号重复或删除后复活。

架构方面，排除生成代码和复制的 Flutter 框架源码后，静态 import 图仍发现 47 个直接双向依赖对；`GStorage` 被 61 个文件引用，其中 50 个位于页面层。大量写入没有统一等待和失败处理，使新的 MMKV 错误契约无法可靠传递到 UI。结论是：项目功能仍可持续演进，但在继续扩展存储后端或播放器功能前，应先修复迁移恢复、批量写入、导入校验和核心依赖环。

### Score Dashboard

```text
Security        Not assessed   本次范围明确排除独立安全审查
Stability       ████░░░░░░  4.2  C   MMKV 失败回退、非原子写入和导入不变量会造成持久化错误；覆盖 High
Performance     Not assessed   本次范围明确排除性能审查
Testing         Not assessed   仅把现有测试作为证据，不对测试维度单独评分
Maintainability █████░░░░░  4.6  C   47 个直接依赖环、61 个 GStorage 消费文件和多个超大核心模块扩大变更半径；覆盖 High
Design          ████░░░░░░  4.4  C   全局裸 Box、UI→存储直写和异步错误丢失削弱边界契约；覆盖 High
Release         █████░░░░░  5.0  B   已有 MMKV codec、迁移测试和 CI 门禁，但迁移回滚与损坏恢复仍不安全；覆盖 High
─────────────────────────────────────
Overall         █████░░░░░  4.6  C   仅平均本次已评估的 4 个维度
```

每项评分范围为 0.0–10.0，分数越高越好。未评估维度不计入 Overall。

### Finding Statistics

| Severity | Count | Confirmed | Suspected |
|----------|-------|-----------|-----------|
| Critical | 0 | 0 | 0 |
| High | 4 | 4 | 0 |
| Medium | 8 | 7 | 1 |
| Low | 0 | 0 | 0 |
| Info | 0 | 0 | 0 |
| **Total** | **12** | **11** | **1** |

## 2. Project Map / 项目地图

- 启动入口：`lib/main.dart` 依次初始化应用目录、CrashReporter、`GStorage`、下载/临时目录、缓存、GetX 服务、HTTP 客户端、账号和平台能力。
- UI 与状态：`lib/pages/**` 以 GetX controller + view 为主，视频、播放器、音频、设置、直播等核心模块同时管理 UI 状态、网络请求、持久化和导航。
- 网络边界：`lib/http/**` 和 `lib/grpc/**` 访问 Bilibili HTTP/gRPC；`Request`、`Accounts` 和 `LoginUtils` 之间存在静态双向依赖。
- 播放与下载：`lib/plugin/pl_player/**`、`lib/pages/video/**`、`lib/pages/audio/**`、`lib/services/download/**` 处理播放状态、历史心跳、缓存与媒体导出。
- 持久化：非 Android 或 MMKV 不可用时使用 Hive CE；Android 上 `userInfo`、`localCache`、`setting`、`historyWord`、`video`、`watchProgress`、`reply` 迁移到 MMKV；账户 metadata 保留在 Hive，敏感字段放在独立加密 sidecar 文件；设置通过本地文件或 WebDAV 导入导出。
- 主要数据流：页面/控制器 → 静态 HTTP/gRPC → `LoadingState` / Rx 状态 → UI；页面/控制器也可直接访问 `GStorage` 的裸 `Box`，绕过统一的数据访问层。

审查基准为干净的 `main` / `origin/main`，HEAD `13fbb9884`。建立了 1565 个项目文件的清单，其中约 1303 个 Dart 文件；详细源码检查重点覆盖手写业务代码、Android MMKV bridge、持久化测试和 CI。生成的 protobuf 文件、复制的 Flutter 框架实现、二进制资源和构建产物未逐行审查。根据仓库要求，没有在本地运行 Flutter、Dart、Gradle、构建、analyze 或 test；运行时结论均按静态证据定级。

### Coverage Matrix

| Dimension | Coverage | Evidence inspected | Exclusions / limits |
|-----------|----------|--------------------|---------------------|
| Architecture | High | 文件清单、启动/路由、47 个直接 import 环、GetX 状态、HTTP/gRPC、播放器、服务、61 个 `GStorage` 消费文件 | 未逐行审查生成代码和复制的 Flutter 框架源码；未运行应用 |
| Data Integrity | High | Hive/MMKV Dart 与 Java bridge、迁移 marker、codec、批量写入、设置/账户导入、secret sidecar、WebDAV、crash store、相关测试 | 未执行故障注入、磁盘损坏、进程终止或真实设备迁移测试 |
| Functional Correctness | Medium | 启动、Cookie 同步、通用列表加载、音频心跳、设置恢复、账户切换、媒体导出关键路径 | 未连接真实 Bilibili/WebDAV 服务，未执行 Flutter widget/integration 测试 |

## 3. Top Risks / 最高优先级风险

1. **High — MMKV 解码失败会用旧 Hive 快照覆盖新数据。** 迁移完成后只写 MMKV，但失败回退仍把关闭后保留的 Hive 当作权威来源。
2. **High — MMKV 批量写入和整箱替换不是原子操作。** 中途失败可留下部分持久化、旧内存缓存或已清空的 box。
3. **High — 设置导入缺少 per-key schema 与范围校验。** 非法枚举 index、错误类型或短列表可在下次启动触发 RangeError/TypeError。
4. **High — 账户导入没有规范化持久化 key。** 别名记录不会被 `refresh` 清除，删除只删规范 key，账号可能重复或复活。
5. **Medium — 数据库错误 Future 在大量调用点被忽略。** UI 已改变但磁盘写入失败时，用户只能在重启后发现设置、进度或缓存回退。
6. **Medium — 核心模块存在大量直接双向依赖。** `storage↔storage_pref`、`accounts↔mine/controller`、`http/init↔http/user` 等环把启动、UI、网络和持久化绑在一起。
7. **Medium — 裸 `Box` 暴露给页面层。** 50 个页面文件直接依赖 `GStorage`，数据库 schema 和错误策略没有单一所有者。
8. **Medium — secret sidecar 原地覆盖。** 进程终止或磁盘错误可能破坏最后一份有效凭据文件，损坏 key 还能阻止应用启动。
9. **Medium — WebDAV 备份先删除旧文件再上传。** 上传失败会同时失去本次备份和上一份可恢复备份。
10. **Medium — 通用数据控制器异常后永久保持 loading 锁。** 一次解析异常即可让同一 controller 后续刷新全部直接返回。
11. **Medium — WebView Cookie 同步 URL 和异步完成契约可疑。** URL 字符串包含空格，并且启动/登录成功路径都没有等待 Cookie 写入。
12. **Medium — 音频回退 seek 后心跳水位不重置。** 服务端历史可能长时间停留在 seek 前的较大进度。

## 4. Detailed Findings / 详细发现

### Finding: MMKV 解码失败会回灌过期 Hive 快照并覆盖新数据

- Severity: High
- Confidence: High
- Category: Stability
- Status: Confirmed
- Subtype: MigrationSafety / BackupRestore
- Affected area: Android `GStorage` Hive→MMKV 迁移与损坏恢复
- Invariant at risk: 迁移完成后的最新 MMKV 数据不得被旧存储快照静默覆盖。
- Evidence:
  - File: `lib/utils/android/android_mmkv_box.dart:32-64`
  - Function / Module: `openAndroidMmkvBackedBox`
  - Relevant behavior: marker 为 `1` 时先读取 MMKV；只要 `tryLoadFromMmkv()` 返回 false，就重新打开 Hive，并调用 `replaceAllFrom(hive.toMap())` 覆盖 MMKV；首次迁移成功后只关闭 Hive，没有删除、重命名或继续同步 Hive。
  - File: `lib/utils/android/android_mmkv_box.dart:93-115`
  - Function / Module: `AndroidMmkvBackedBox.tryLoadFromMmkv`
  - Relevant behavior: 任意 entry 解码异常都会被 catch 并折叠为 false，触发上述旧 Hive 回退。
- Problem: 迁移完成后，运行期 `put/delete` 只更新 MMKV，磁盘上的 Hive 数据逐渐过期。MMKV 某个 entry 因损坏、codec 演进或不兼容值而无法解码时，代码会把过期 Hive 整箱写回 MMKV，丢弃迁移后的所有新设置、缓存、观看进度或回复数据。
- Why it matters: 这是持久化来源所有权错误；恢复路径本身会制造数据丢失，并且用户无法知道发生了回滚。
- Realistic failure scenario: 用户迁移后使用数周，修改大量设置和观看进度；一次 app 更新改变 codec，或 MMKV 单条记录损坏；下次启动解码失败，应用用数周前的 Hive 快照重建 MMKV，表面仍能启动，但新数据全部消失。
- Minimal fix: marker 已完成时，MMKV 解码失败不得自动采用 legacy Hive；应隔离损坏 box、保留原文件、返回可诊断的恢复状态，或从明确的 MMKV last-known-good 备份恢复。仅在 marker 不存在时允许 Hive→MMKV 迁移。
- Better long-term fix: 引入带版本、校验和、状态（copying/verified/committed）的迁移记录；成功后把 legacy Hive 重命名为只读、带时间戳的迁移备份，并设定明确保留期与人工恢复流程。
- Regression test suggestion: 先从 Hive 迁移值 A，再只向 MMKV 写入值 B；人为破坏一个 MMKV entry 后重新打开，断言实现不会用 Hive 的 A 覆盖 B，并保留可恢复的损坏数据。
- Estimated effort: 1–2 天

### Finding: MMKV 批量写入和整箱替换缺少原子性

- Severity: High
- Confidence: High
- Category: Stability
- Status: Confirmed
- Subtype: TransactionBoundary
- Affected area: Android MMKV `putAll`、`deleteAll`、迁移/恢复整箱替换
- Invariant at risk: 一个逻辑批次必须全部成功或保持原状态，内存缓存必须与持久化内容一致。
- Evidence:
  - File: `lib/utils/android/android_mmkv_box.dart:234-254`
  - Function / Module: `AndroidMmkvBackedBox.putAll`
  - Relevant behavior: 逐条调用 native `putRaw`，只有全部成功后才更新 `_cache`；第 N 条失败时，前 N-1 条已经持久化，但内存仍是旧状态。
  - File: `lib/utils/android/android_mmkv_box.dart:291-305`
  - Function / Module: `AndroidMmkvBackedBox.deleteAll`
  - Relevant behavior: 逐条删除并修改 cache，但事件在循环完成后才发送；中途失败时调用者收到错误，而部分删除已经生效且监听者没有收到对应事件。
  - File: `android/app/src/main/java/com/chloemlla/piliplus/AndroidMmkv.java:68-84`
  - Function / Module: `AndroidMmkv.replaceBox`
  - Relevant behavior: 先 `clearAll()`，再逐条 encode；任一 encode 失败直接返回 false，没有恢复旧 box。
- Problem: Dart 层和 Java 层都把多步持久化暴露为一个看似单次的 Future/bool，但没有事务、staging 或补偿。失败后的真实状态取决于失败位置。
- Why it matters: 设置导入、迁移和多字段配置依赖批量更新。部分成功会制造跨字段不变量破坏，并让当前会话与重启后的状态不同。
- Realistic failure scenario: `putAll` 写入窗口尺寸和位置时第二条 native 写失败；当前内存仍显示两条旧值，MMKV 已保存第一条新值；重启后窗口尺寸更新而位置未更新。更严重时，`replaceBox` 清空旧 box 后只恢复一部分数据。
- Minimal fix: 对 `putAll/deleteAll` 预先保存受影响旧值，失败时执行补偿并验证；整箱替换使用临时 MMKV box，完整写入、读取校验后再切换 marker/box id。
- Better long-term fix: 把存储 backend 契约升级为显式 atomic batch API，并让 Hive 与 MMKV adapter 共享同一套事务语义和故障注入测试。
- Regression test suggestion: fake backend 在第 2 次写入/删除时失败，断言持久化、cache、watch events 均保持旧状态；对 `replaceBox` 断言失败后旧内容仍完整可读。
- Estimated effort: 1–2 天

### Finding: 设置导入只校验 section 形状，非法值可持久化并阻断启动

- Severity: High
- Confidence: High
- Category: Stability
- Status: Confirmed
- Subtype: InvariantValidation
- Affected area: 本地设置导入、WebDAV 恢复、启动主题与窗口初始化
- Invariant at risk: 所有持久化设置必须满足既定类型、枚举范围、列表长度和跨字段约束。
- Evidence:
  - File: `lib/utils/storage.dart:125-173`
  - Function / Module: `GStorage.importAllJsonSettings`、`validateSettingsSection`
  - Relevant behavior: 导入前只验证 `setting` 和 `video` 是 Map，随后清空 box 并 `putAll`；没有 schema version、key allowlist、类型或范围校验。
  - File: `lib/utils/storage_pref.dart:89-100,364-368,734-735,968-998`
  - Function / Module: `Pref.memberTab/themeType/schemeVariant/customColor/windowSize/audioPlayMode`
  - Relevant behavior: 多个 getter 直接用持久化整数索引 enum，或直接读取列表的 `[0]`、`[1]`。
  - File: `lib/main.dart:187-190,254-256`
  - Function / Module: 桌面窗口初始化、`MyApp.getAllTheme`
  - Relevant behavior: 启动期间立即消费 `windowSize`、`customColor` 和 `schemeVariant`。
- Problem: rollback 只能处理写入异常，不能识别“写入成功但语义非法”的数据。非法备份会被完整保存，并在下一次 getter 被访问时触发类型转换或越界异常。
- Why it matters: 导入/恢复是外部输入边界。一次损坏、旧版本或人工编辑的备份可以让应用下次启动在主题或窗口初始化阶段崩溃。
- Realistic failure scenario: WebDAV 文件包含 `schemeVariant: 999` 或只有一个元素的 `windowSize`；恢复提示成功；用户重启后在 `FlexSchemeVariant.values[999]` 或 `size[1]` 处崩溃，且普通 UI 无法进入以重置设置。
- Minimal fix: 在清空任何 box 前，对已知 key 执行类型、枚举范围、数值范围和列表长度校验；拒绝未知 schema version，并验证启动关键 getter 可以从候选快照安全构造。
- Better long-term fix: 用版本化 typed DTO 表示设置备份，提供逐版本 migration，并把 `Pref` 的动态读取集中到带默认值和校验的 codec 层。
- Regression test suggestion: 覆盖越界 enum、错误 bool/string 类型、短 `windowSize`、未知 schema version，断言导入失败且原 box 快照保持不变。
- Estimated effort: 1–2 天

### Finding: 账户导入允许别名 key，删除后账号可从残留记录复活

- Severity: High
- Confidence: High
- Category: Stability
- Status: Confirmed
- Subtype: InvariantValidation / Reconciliation
- Affected area: 登录信息导入、`Accounts.refresh`、账号删除
- Invariant at risk: 每个登录账号必须且只能以 `DedeUserID` 派生的 `secretKey` 保存一条记录。
- Evidence:
  - File: `lib/pages/about/view.dart:239-249`
  - Function / Module: “导入/导出登录信息” `onImport`
  - Relevant behavior: 直接保留输入 JSON 的任意 map key，并将其写入 `Accounts.account`；没有检查 key 是否等于 `LoginAccount.secretKey`。
  - File: `lib/utils/accounts.dart:41-60`
  - Function / Module: `Accounts.refresh`
  - Relevant behavior: 为有效账号追加 `validAccounts[a.secretKey] = a`，但只删除无效 key，不删除有效但非规范的原 key。
  - File: `lib/utils/accounts/account.dart:83-91`
  - Function / Module: `LoginAccount.secretKey`、`delete`
  - Relevant behavior: 删除时仅执行 `_box.delete(_midStr)`，不会删除导入时的别名 key。
- Problem: refresh 看似在规范化 key，实际只是新增规范记录。别名和规范记录可同时存在，并且不同记录的 account type 会按 Hive 迭代顺序覆盖内存状态。
- Why it matters: 账号持久化存在重复源，删除、切换和导出结果不再可预测，用户可能无法真正移除某个账号。
- Realistic failure scenario: 导入文件用 `backup-account` 作为 key，但 Cookie 中 mid 为 `123`；refresh 新增 key `123` 但保留 `backup-account`。用户删除账号只删除 `123`，下次启动 `backup-account` 再次被读出并重新生成 `123`，账号“复活”。
- Minimal fix: 导入时拒绝或立即重写 key 不匹配的记录；refresh 应收集所有非规范 key，在成功写入规范 map 后删除别名，并对同一 mid 的多条记录采用明确冲突策略。
- Better long-term fix: 为账户仓储提供 `replaceValidatedAccounts` 原子 API，隐藏 Hive key，并把账号 metadata、secret sidecar 和运行时 account mode 作为一个一致性单元管理。
- Regression test suggestion: 导入别名 key，执行 refresh、delete、重新初始化，断言 box 中始终只有规范 key，删除后不会恢复。
- Estimated effort: 4–8 小时

### Finding: 持久化错误通过 Future 返回，但大量调用点没有等待或处理

- Severity: Medium
- Confidence: High
- Category: Stability
- Status: Confirmed
- Subtype: BoundaryContract
- Affected area: 设置、观看进度、搜索历史、回复缓存、窗口状态
- Evidence:
  - File: `lib/utils/android/android_mmkv_box.dart:212-227,234-254,274-305,312-352`
  - Function / Module: MMKV `put/putAll/delete/deleteAll/clear/flush`
  - Relevant behavior: native 失败会以 `Future.error(StateError)` 或 `UnsupportedError` 返回。
  - File: `lib/pages/video/controller.dart:322-327`
  - Function / Module: 视频观看进度写入
  - Relevant behavior: `watchProgress.put(...)` 未 await，写入失败不会反馈到进度逻辑。
  - File: `lib/pages/search/controller.dart:179,228-237`
  - Function / Module: 搜索历史持久化
  - Relevant behavior: `put/delete` 未等待。
  - File: `lib/pages/main/view.dart:138-164`
  - Function / Module: 桌面窗口状态持久化
  - Relevant behavior: 最大化、位置、尺寸写入均未统一处理失败。
- Problem: Hive 时代形成的 fire-and-forget 调用习惯与新 MMKV adapter 的显式失败契约不匹配。静态搜索发现 `GStorage` 分散在 61 个文件中，直接持久化变更调用大量存在于页面和 controller。
- Why it matters: UI 和内存状态通常先改变；当 native 存储不可写、值不受 codec 支持或 box 已关闭时，错误可能成为未处理异步异常，用户只会在重启后发现数据没有保存。
- Realistic failure scenario: 磁盘/原生 MMKV 写入失败时，播放器仍更新内存进度，设置页仍显示新值；应用重启后全部回退，且没有可定位的错误记录或用户提示。
- Minimal fix: 对观看进度、账号、设置导入和多字段配置等关键写入统一 await；对于刻意后台写入，使用显式 `unawaited` + 中央错误处理、日志和必要的 UI 回滚。
- Better long-term fix: 增加 typed repository/use-case 层，让调用者只能使用返回明确结果的领域方法，不再直接拿到 `Box`。
- Regression test suggestion: fake backend 强制 `put` 失败，断言关键 UI 不显示保存成功、内存状态被回滚或标记为未持久化，并记录可诊断错误。
- Estimated effort: 2–4 天（按关键路径分批）

### Finding: 核心模块存在 47 个直接双向 import 对

- Severity: Medium
- Confidence: High
- Category: Maintainability
- Status: Confirmed
- Subtype: DependencyDirection
- Affected area: 启动、账户、网络、存储、页面模型、播放器
- Evidence:
  - File: `lib/utils/accounts.dart:1-6` 与 `lib/pages/mine/controller.dart:4-17`
  - Function / Module: Accounts ↔ MineController
  - Relevant behavior: 持久化/账号工具层导入页面 controller 并直接写 `MineController.anonymity`，页面 controller 同时反向依赖 Accounts。
  - File: `lib/utils/storage.dart:18` 与 `lib/utils/storage_pref.dart:43-59`
  - Function / Module: GStorage ↔ Pref
  - Relevant behavior: storage 初始化依赖 Pref 决定 reply box，Pref 的静态 Box 又依赖 GStorage 已完成初始化。
  - File: `lib/http/init.dart:10-16` 与 `lib/http/user.dart:2-17`
  - Function / Module: Request ↔ UserHttp / Accounts / LoginUtils
  - Relevant behavior: 网络底座导入具体 endpoint 和账号流程，具体 endpoint 又反向导入网络底座。
  - File: `lib/models/common/home_tab_type.dart:1-15`
  - Function / Module: `HomeTabType`
  - Relevant behavior: model enum 直接 import 多个页面、controller、Flutter Widget 和 GetX service locator。
- Problem: PowerShell 静态 import 图在排除生成 protobuf 和复制的 Flutter 源码后仍发现 47 个直接双向依赖对。部分 UI 内部环可以局部接受，但核心存储、账号、网络和 model→page 依赖破坏了稳定依赖方向。
- Why it matters: 静态初始化顺序、测试替换和模块重构都依赖隐含约定；在任意一端新增 static field 或启动副作用，都可能触发 `LateInitializationError`、半初始化状态或大范围编译影响。
- Realistic failure scenario: 为 `Pref` 新增一个启动时读取的 getter，该 getter 在 `GStorage.init` 完成 box 赋值前被间接触发；存储初始化失败并导致 `main` 退出。类似风险也存在于 Accounts/MineController 的静态状态。
- Minimal fix: 优先切断 4 个核心环：Accounts 通过事件/服务通知 UI；Pref 只依赖注入的 SettingsStore；HTTP endpoint 依赖 RequestPort；model enum 不再构造页面 Widget。
- Better long-term fix: 采用 feature-first 分区和单向依赖：UI → application/use-case → repository/HTTP port → adapter；以 CI 脚本阻止新增跨层反向 import。
- Regression test suggestion: 在 CI 中运行 import-boundary 检查，至少禁止 `lib/utils/**` import `lib/pages/**`、`lib/models/**` import `lib/pages/**`，并维护核心环数量只能下降。
- Estimated effort: 首批 3–5 天，完整治理需迭代进行

### Finding: GStorage 暴露裸 Box，数据库 schema 没有单一所有者

- Severity: Medium
- Confidence: High
- Category: Maintainability
- Status: Confirmed
- Subtype: ModuleBoundary / StateOwnership
- Affected area: 本地设置、缓存、观看进度、回复和用户信息
- Evidence:
  - File: `lib/utils/storage.dart:24-30`
  - Function / Module: `GStorage`
  - Relevant behavior: 7 个 `Box` 作为公共 static 字段直接暴露。
  - File: `lib/pages/setting/**`、`lib/pages/video/**`、`lib/pages/search/**`、`lib/pages/download/**`
  - Function / Module: 页面和 controller 持久化调用
  - Relevant behavior: 静态搜索确认 61 个文件引用 `GStorage`，其中 50 个在 `lib/pages/**`；页面直接决定 key、value 类型、await 策略和删除行为。
  - File: `lib/utils/storage_key.dart`
  - Function / Module: `SettingBoxKey` / `VideoBoxKey` / `LocalCacheKey`
  - Relevant behavior: key 常量集中，但类型、默认值、迁移和不变量分散在 `Pref` 与各调用点。
- Problem: `GStorage` 同时承担初始化、后端选择、迁移、导入导出和全局服务定位，但不拥有具体数据的写入规则。新增 MMKV 后端必须兼容所有历史调用和动态值，导致 codec 与错误语义难以封闭。
- Why it matters: 修改一个 key、value 类型或持久化后端需要跨 50 个页面文件搜索，容易出现只修一个入口、遗漏另一个入口的功能回归。
- Realistic failure scenario: 将某个 setting 从 int index 改为 enum name 时，设置页写入已更新，但播放器 controller 仍按旧 int 写入；不同入口交替覆盖，最终在 Pref getter 处崩溃。
- Minimal fix: 先为 `SettingsStore`、`WatchProgressStore`、`ReplyCacheStore`、`AccountRepository` 建立窄接口；新增代码不得直接访问 Box，旧调用按风险逐步迁移。
- Better long-term fix: 每个 bounded feature 拥有 typed persistence contract、schema version 和 migration；`GStorage` 只负责组合 backend，不再作为业务 API。
- Regression test suggestion: 为每个 typed store 增加 round-trip 和非法值测试，并用静态检查禁止页面层新增 `GStorage.*.put/delete`。
- Estimated effort: 1–2 周，适合增量重构

### Finding: 账户和设置 secret 文件原地覆盖，损坏后没有 last-known-good 恢复

- Severity: Medium
- Confidence: High
- Category: Stability
- Status: Confirmed
- Subtype: BackupRestore
- Affected area: `AccountSecretStore`、`SettingSecretStore`
- Evidence:
  - File: `lib/utils/accounts/account_secret_store.dart:106-112,122-162`
  - Function / Module: `_readOrCreateKey`、`_load`、`_save`
  - Relevant behavior: key 和加密数据使用 `writeAsStringSync(..., flush: true)` 直接写目标文件；数据解码失败后把文件重命名为 corrupt 并清空内存，没有备份恢复。
  - File: `lib/utils/setting_secret_store.dart:59-65,75-115`
  - Function / Module: 同名方法
  - Relevant behavior: 使用相同的原地写入和损坏清空策略。
  - File: `lib/utils/storage.dart:34-36`
  - Function / Module: `GStorage.init`
  - Relevant behavior: 两个 secret store 在启动关键路径同步初始化；key 文件读取异常会直接向上抛出。
- Problem: `flush: true` 不能提供跨崩溃的替换原子性。目标文件可能在 truncate 后、完整内容落盘前损坏；key 文件损坏时 `_readOrCreateKey` 没有 quarantine/recovery，整个 `GStorage.init` 会失败。
- Why it matters: 一次中断写入可以让所有账号凭据或 WebDAV 密码不可恢复；key 损坏还可能导致应用启动后立即退出。
- Realistic failure scenario: 更新 refresh token 时应用被系统终止，`account_secrets.json.enc` 只写入半段；下次启动 `_load` 将文件标为 corrupt 并清空 secrets，Hive metadata 随后被判无效并删除，所有账号退出。
- Minimal fix: 写入同目录临时文件，flush 后重新读取/解密验证，再以原子 rename 替换；保留一份 `.bak`。key 创建也使用 exclusive temp + atomic rename，并对非法 key 提供恢复提示。
- Better long-term fix: 使用平台凭据存储保存主密钥，并实现带 generation/checksum 的双文件提交协议，启动时选择最后一个完整 generation。
- Regression test suggestion: 模拟截断 temp/目标文件、非法 key 和 rename 失败，断言上一版本仍可读取，且应用不会静默删除全部 metadata。
- Estimated effort: 1 天

### Finding: WebDAV 备份先删除最后一份可恢复文件

- Severity: Medium
- Confidence: High
- Category: Stability
- Status: Confirmed
- Subtype: BackupRestore
- Affected area: 设置 WebDAV 备份
- Evidence:
  - File: `lib/pages/webdav/webdav.dart:57-76`
  - Function / Module: `WebDav.backup`
  - Relevant behavior: 先尝试 `_client.remove(path)`，忽略删除异常，然后才 `_client.write(path, data)`；没有临时文件、rename、版本或 checksum。
- Problem: 备份更新把“删除旧备份”和“上传新备份”分成两个不可回滚的远程操作。
- Why it matters: 备份系统最重要的不变量是失败不能破坏上一份可恢复数据；当前实现恰好在网络最容易失败的窗口移除了旧版本。
- Realistic failure scenario: 旧备份删除成功后网络断开或 WebDAV 配额已满，write 失败；用户看到“备份失败”，但服务器上的上一份有效备份也已消失。
- Minimal fix: 上传到同目录临时文件，校验长度/可选 checksum 后使用 WebDAV move/rename 覆盖正式文件；若服务器不支持原子 move，至少保留 timestamp 版本并在成功后清理旧版本。
- Better long-term fix: 保留最近 2–3 个版本和 manifest，restore 时验证 JSON schema、checksum 与平台兼容性后再应用。
- Regression test suggestion: fake WebDAV 在上传阶段失败，断言旧正式文件仍存在且内容未变；成功路径再断言临时文件被清理。
- Estimated effort: 2–4 小时

### Finding: 通用列表与数据 controller 在异常后永久保留 isLoading 锁

- Severity: Medium
- Confidence: High
- Category: Stability
- Status: Confirmed
- Subtype: BoundaryContract
- Affected area: 使用 `CommonDataController` / `CommonListController` 的列表和详情功能
- Evidence:
  - File: `lib/pages/common/common_data_controller.dart:9-24`
  - Function / Module: `CommonDataController.queryData`
  - Relevant behavior: `isLoading = true` 后直接 await `customGetData` 并调用 handler，只有正常走到函数尾部才设回 false，没有 try/finally。
  - File: `lib/pages/common/common_list_controller.dart:22-57`
  - Function / Module: `CommonListController.queryData`
  - Relevant behavior: 同样依赖正常返回；解析、cast 或 `customHandleResponse` 抛异常时不会释放锁。
- Problem: HTTP wrapper 虽然常把 Dio 错误转换成 `LoadingState.Error`，但 JSON 字段变化、model cast、controller 自定义处理和存储访问仍可能抛异常。基类把一次异常转化为永久的“正在加载”状态。
- Why it matters: 这是所有继承 controller 的共享功能故障模式；用户重试、下拉刷新和加载更多都会被入口的 `if (isLoading) return` 静默拒绝。
- Realistic failure scenario: API 某条数据字段类型变化，`customHandleResponse` 抛 TypeError；当前请求报错后 `isLoading` 保持 true，用户反复刷新没有任何请求，只有离开页面重建 controller 才恢复。
- Minimal fix: 用 try/catch/finally 包裹完整请求和 handler；finally 无条件释放 `isLoading`，catch 转换成可展示的 `LoadingState.Error` 并保留原异常诊断。
- Better long-term fix: 把请求状态建模为显式状态机，区分 initial/loading/refreshing/loadingMore/error，避免共享 bool 同时承担互斥和 UI 状态。
- Regression test suggestion: fake controller 第一次 `customGetData` 抛异常、第二次成功，断言第二次 refresh 确实执行且 loading 状态恢复。
- Estimated effort: 2–4 小时

### Finding: WebView Cookie 同步 URL 含空格且调用方不等待完成

- Severity: Medium
- Confidence: Medium
- Category: Stability
- Status: Suspected
- Subtype: BoundaryContract
- Affected area: 登录成功后的 WebView 登录态同步
- Evidence:
  - File: `lib/utils/login_utils.dart:21-42`
  - Function / Module: `LoginUtils.setWebCookie`
  - Relevant behavior: WebUri 使用 `'${isWindows ? 'https://' : ''} ${cookie.domain}'`，scheme/domain 中间固定包含一个空格；函数返回 `Future.wait`。
  - File: `lib/http/init.dart:40-45`
  - Function / Module: `Request.setCookie`
  - Relevant behavior: `Accounts.refresh()` 和 `LoginUtils.setWebCookie()` 均未 await，且方法本身返回 void。
  - File: `lib/utils/login_utils.dart:47-52`
  - Function / Module: `LoginUtils.onLoginMain`
  - Relevant behavior: 登录成功处理再次 fire-and-forget 调用 `setWebCookie(account)`。
- Problem: Cookie URL 很可能被解析为带 `%20` 的 host 或无效相对 URI；即使平台容忍该字符串，调用方仍在 Cookie 完成前继续启动或显示“登录成功”。本次未运行平台 WebView，因此运行时结果标为 Suspected。
- Why it matters: HTTP API 登录成功但 WebView 仍匿名，会表现为部分页面反复要求登录，且时序问题难以稳定复现。
- Realistic failure scenario: 用户完成 Cookie 登录，toast 已显示成功并立即打开 WebView；CookieManager 仍在异步写入或因错误 URL 拒绝写入，页面以未登录状态加载。
- Minimal fix: 使用固定合法 origin，例如 `WebUri('https://www.bilibili.com/')`，domain 仍通过独立参数传递；把 `setCookie` 改为 `Future<void>` 并在启动和登录成功路径 await、处理单个 Cookie 错误。
- Better long-term fix: 抽象 `WebCookieSyncService`，返回结构化结果并允许测试；HTTP 登录态与 WebView 登录态建立明确的同步状态，而不是隐式副作用。
- Regression test suggestion: 使用 fake CookieManager 断言 URL 没有空格、host 合法，并断言登录成功回调发生在所有 Cookie Future 完成之后。
- Estimated effort: 1–2 小时

### Finding: 音频向后 seek 不重置心跳水位，观看历史可能停留在旧进度

- Severity: Medium
- Confidence: High
- Category: Stability
- Status: Confirmed
- Subtype: StateOwnership / FunctionalCorrectness
- Affected area: 音频播放历史心跳
- Evidence:
  - File: `lib/pages/audio/controller.dart:94,198-239`
  - Function / Module: `_heartDuration`、`makeHeartBeat`
  - Relevant behavior: playing/status 只有在 `progress - _heartDuration` 分别达到 5/2 秒时才发送，并把 `_heartDuration` 更新为当前进度。
  - File: `lib/pages/audio/controller.dart:248-249`
  - Function / Module: `onSeek`
  - Relevant behavior: seek 只调用 `player.seek(duration)`，没有重置或调整 `_heartDuration`。
  - File: `lib/pages/audio/controller.dart:715-744`
  - Function / Module: 换分P/换歌曲
  - Relevant behavior: 只有换 track 时才把 `_heartDuration` 设为 0。
- Problem: `_heartDuration` 同时被当作节流时间戳和当前 track 的单调进度水位，但播放进度并非单调；向后 seek 会让差值长期为负数。
- Why it matters: 服务端观看历史可能继续显示 seek 前的较大进度，用户退出后再次播放会从错误位置恢复。
- Realistic failure scenario: 心跳已发送到 20 分钟，用户回退到 5 分钟继续听；直到再次播放超过 20 分钟前，playing/status 心跳都不再发送，服务端一直保留 20 分钟。
- Minimal fix: seek 完成时若目标小于 `_heartDuration`，重置水位并立即发送一次 status heartbeat；将节流计时与业务 progress 分成两个字段。
- Better long-term fix: 建立统一 PlaybackHistoryReporter，显式处理 play/pause/seek/track-change/completed 事件，视频与音频共享相同状态机。
- Regression test suggestion: 先发送 progress=1200，再 seek 到 300，断言立即发送 300，随后 305 可以正常继续节流发送。
- Estimated effort: 1–2 小时

## 5. Architecture Concerns / 架构问题

- Coverage: High
- Inspected evidence: 项目文件清单、入口与路由、GetX controller、HTTP/gRPC、播放器/音频、服务定位、直接 import 图、`GStorage` 调用分布
- Exclusions / limits: 未逐行审查生成 protobuf 和复制的 Flutter 框架源码；未执行运行时依赖初始化

主要架构风险不是目录缺失，而是所有权不稳定：页面、controller、utils、model、HTTP 和 storage 之间存在大量双向依赖；`Accounts` 直接控制页面 Rx 状态，model enum 直接构造页面 Widget，`GStorage` 把 backend 细节暴露给页面层。系统仍有可复用的 controller、service 和 HTTP 封装，但这些抽象经常被静态访问绕过。

建议按风险切断边界，而不是重写：先把账户 UI 通知、SettingsStore、WatchProgressStore、WebCookieSync 和 PlaybackHistoryReporter 独立出来；之后为新增功能设置 import boundary 门禁。

## 6. Stability Concerns / 稳定性与功能正确性

- Coverage: High（数据链路）/ Medium（真实平台功能）
- Inspected evidence: MMKV/Hive 迁移、设置/账户导入、WebDAV、secret sidecar、通用 controller、Cookie 同步、音频心跳
- Exclusions / limits: 未运行真实 Android/iOS/Windows WebView、Bilibili API、WebDAV 或磁盘故障注入

稳定性高风险集中在“失败后的状态”：迁移回退可能丢新数据，批量写入失败后 cache 与磁盘不一致，导入成功后可能保存语义非法数据，异步写入失败通常没有 UI 补偿。通用 controller 和音频心跳则显示同一模式：使用一个简单 bool/int 同时表达多个状态，遇到异常或非单调事件后无法自恢复。

## 7. Maintainability Concerns / 可维护性问题

- Coverage: High
- Inspected evidence: import 图、文件规模、直接存储调用、核心模块依赖数量
- Exclusions / limits: 未使用完整 Dart analyzer dependency graph；统计基于 package import 静态解析

需要优先关注的结构信号：`lib/plugin/pl_player/view/view.dart` 2420 行、`lib/pages/video/view.dart` 2020 行、`lib/plugin/pl_player/controller.dart` 1797 行、`lib/pages/video/controller.dart` 1631 行、`lib/utils/storage_pref.dart` 1057 行。文件大小本身不是 bug，但这些文件同时承担 UI、状态机、持久化、网络、导航和平台逻辑，并与周边模块形成直接 import 环，因此已经产生真实的变更半径和测试困难。

## 8. Design / Principles Concerns / 设计原则问题

- Coverage: High
- Inspected evidence: 依赖方向、状态所有权、错误传播、持久化事务、导入边界
- Exclusions / limits: 仅报告会影响功能正确性和可演进性的原则问题，不评价纯风格

主要原则缺口是 Dependency Rule、Explicit Dependencies、Fail-Fast、Don't Swallow Errors、Single Responsibility 和事务边界。特别是 `Box` 的 Future 错误契约没有贯穿调用方，说明 adapter 虽然更换了，application boundary 没有同步升级。

## 9. Release Concerns / 数据迁移发布问题

- Coverage: High
- Inspected evidence: MMKV migration marker、codec、迁移测试、GitHub workflow 中的 analyze/test 门禁
- Exclusions / limits: 未审查独立供应链/签名/发布流程；未执行真实升级、降级或损坏恢复

正面证据是当前仓库已经提交 MMKV backend 注入、model codec 和首次/重复打开的单元测试，CI 也运行 `flutter analyze` 与 `flutter test`。剩余发布风险在迁移失败策略：marker 只表达“v1 已迁移”，没有 copying/verified/committed 状态、checksum、回滚策略或损坏恢复来源。上线前应补齐失败注入和旧 Hive 非权威测试。

## 10. Data Integrity Analysis / 数据完整性分析

- Coverage: High
- Inspected evidence: `GStorage`、Hive/MMKV、Android Java bridge、账户 metadata/secret、设置导入导出、WebDAV、crash store、相关测试
- Exclusions / limits: 未在真实文件系统上模拟进程 kill、磁盘满、MMKV CRC 损坏和 WebDAV 非原子服务器行为

### Integrity Summary

| Subtype | Count | Invariants at Risk | Recommended Action |
|---------|-------|-------------------|-------------------|
| TransactionBoundary | 1 | 批量操作全成或全不成 | staging + rollback + failure injection |
| Idempotency | 0 | 未发现本范围内可直接定级问题 | 保持 |
| ConcurrencyConsistency | 0 | 未发现跨进程并发写证据 | 保持 MMKV single-process 约束 |
| MigrationSafety | 1 | 新 MMKV 数据不能被旧 Hive 覆盖 | marker 状态机 + 非权威 legacy 策略 |
| InvariantValidation | 2 | 设置类型/范围、账户规范 key | typed schema + canonical replace |
| BackupRestore | 2 | secret last-known-good、WebDAV 上一备份 | atomic replace + 版本保留 |
| Reconciliation | 1 | 页面状态、cache 与磁盘写入结果一致 | 统一写入结果与错误处理 |

## 11. Functional Correctness Analysis / 关键功能正确性

- Coverage: Medium
- Inspected evidence: 启动、账号 Cookie、通用列表加载、音频心跳、设置恢复、账号导入/删除、媒体导出
- Exclusions / limits: 没有执行真实 UI、网络、平台插件或外部服务

本次确认两个广泛功能模式和两个具体功能问题：通用 controller 异常后无法再次加载；音频向后 seek 后心跳不再更新；WebView Cookie URL/时序高度可疑；持久化 Future 未等待导致“当前看似成功、重启后回退”。这些问题都可以通过小范围状态机或边界修复解决，无需重写功能模块。

## 12. Principles Compliance / 工程原则合规

### Principles Violated

| Principle | Violations | Severity | Affected Areas |
|-----------|------------|----------|----------------|
| Dependency Rule | 系统性 | Medium | Accounts、Mine、HTTP、Pref、models/pages |
| Explicit Dependencies | 系统性 | Medium | `GStorage`、`Request`、`Accounts`、Get.find |
| Single Responsibility | 多处 | Medium | 视频、播放器、设置、request utils |
| Fail-Fast | 2 | High | 设置导入、账户导入 |
| Don't Swallow Errors | 多处 | Medium | fire-and-forget storage、Cookie、心跳、silent catches |
| Transaction Boundary | 2 | High | MMKV batch、replaceBox |
| State Ownership | 多处 | Medium | Accounts/Mine、Box/UI、音频 heartbeat |

### Principles Respected

- MMKV 代码已经抽出 `AndroidMmkvStoreBackend`，允许使用内存 backend 做迁移/codec 单测。
- `UserInfoData` 和 `RuleFilter` 使用显式 codec，避免把 Hive adapter 对象直接塞进 JSON。
- 设置导入已增加写入异常时的 snapshot rollback，并从导出中移除 WebDAV 密码。
- 账户与设置 secret 已从普通 Hive 值中分离，并使用 AEAD 加密与损坏隔离。
- crash report history 有数量上限、重复过滤和多目录冗余保存。
- GitHub workflow 已包含 `flutter analyze` 与 `flutter test`，近期 MMKV、secret、crash 和网络策略均增加了测试。

## 13. Architecture Analysis / 架构分析

### Architecture Summary

| Subtype | Count | Affected Areas | Recommended Action |
|---------|-------|----------------|-------------------|
| ModuleBoundary | 2 | GStorage、model→page | 增加 typed store；model 不构造 Widget |
| DependencyDirection | 1（系统性） | 47 个直接双向 import 对 | 先切断 storage/accounts/http 核心环 |
| StateOwnership | 3 | Accounts/Mine、Box/UI、audio heartbeat | 建立事件与领域状态机 |
| BoundaryContract | 3 | storage Future、Cookie、common controller | 统一结果、await 与 finally |
| EvolutionRisk | 2 | MMKV migration、视频/播放器大模块 | 版本化迁移；按职责拆分热点 |

整体推荐采用“边界修复优先”的渐进方案：第一阶段保证数据不丢；第二阶段让页面不再直接写裸 Box；第三阶段通过事件/ports 切断核心 import 环；最后再拆分视频和播放器大模块。当前证据不支持全量重写。

## 14. Recommended Fix Order / 推荐修复顺序

### Fix Immediately

1. 修改 MMKV marker 已完成后的解码失败策略，禁止用旧 Hive 自动覆盖。
2. 为 MMKV `putAll/deleteAll/replaceBox` 增加失败原子性或可靠补偿。
3. 设置导入在清空前执行完整 schema/type/range 校验。
4. 账户导入和 refresh 强制 canonical key，并清理 alias。

### Fix Before Stable Release

1. secret sidecar 改为 temp + verify + atomic rename + backup。
2. WebDAV 使用临时上传/rename 或版本化备份。
3. 关键存储写入统一 await 和错误补偿。
4. 通用 controller 使用 try/finally 释放 loading 锁。
5. 修正并等待 WebView Cookie 同步。
6. 音频 seek 时重置/上报 heartbeat。

### Schedule Later

1. 用 typed repository 替代页面直接访问 `GStorage`。
2. 切断 Accounts/Mine、Storage/Pref、Request/UserHttp 等核心依赖环。
3. 按播放状态机、持久化、网络、UI 分拆视频/播放器超大模块。

### Ignore for Now

- 本次未发现仅属于风格、且不影响功能/架构/数据完整性的事项需要列入修复计划。

## 15. Quick Wins / 快速收益项

| Quick win | Expected value | Effort |
|-----------|----------------|--------|
| settings import 增加 `schemaVersion` 和 5 个启动关键 key 校验 | 防止恢复后无法启动 | 2–4 小时 |
| account import 拒绝 key 与 `secretKey` 不一致 | 防止账号重复/复活 | 1–2 小时 |
| WebDAV 改为先写 `.tmp` 再 move | 保留最后一份可恢复备份 | 2–4 小时 |
| common controller 加 try/finally | 一次修复大量列表卡死路径 | 1–2 小时 |
| Cookie URL 去空格并 await | 修复 WebView 登录态竞态 | 1–2 小时 |
| `onSeek` 重置 heartbeat 水位 | 修复音频历史进度错误 | 1 小时 |
| 为 MMKV fake backend 增加第 N 次写失败测试 | 快速暴露部分提交问题 | 2–4 小时 |

## 16. Long-term Refactor Plan / 长期重构计划

1. **数据安全阶段**：先实现版本化迁移状态机、atomic batch、导入 schema、last-known-good 备份。风险是兼容旧数据；测试以升级、损坏、部分失败和回滚为核心。
2. **存储边界阶段**：引入 `SettingsStore`、`AccountRepository`、`WatchProgressStore`、`ReplyCacheStore`，新功能禁止直接访问 `Box`。风险是双轨期间行为不一致；通过 contract tests 保证 Hive/MMKV 等价。
3. **依赖方向阶段**：Accounts 通过事件通知 UI，HTTP endpoint 依赖 request port，model 不再引用页面。风险是 GetX 生命周期变化；通过启动和账号切换集成测试保护。
4. **热点拆分阶段**：把视频/播放器按 playback state、controls、history、download/export、platform integration 拆分。风险是交互回归；先建立事件序列测试再移动代码。
