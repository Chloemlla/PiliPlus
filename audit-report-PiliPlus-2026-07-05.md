# Fuck My Shit Mountain Audit Report

**Project:** PiliPlus  
**Audit mode:** full  
**Date:** 2026-07-05  
**Reviewer:** Codex GPT-5

---

## 1. Executive Summary

PiliPlus 是一个跨平台 Flutter 第三方 Bilibili 客户端，主要代码集中在 `lib/`，包含网络请求、账号 Cookie / access key 管理、视频播放、离线下载、WebView 登录/浏览、WebDAV 设置备份、桌面和移动端发布脚本。项目功能面很大，手写 Dart 文件约 1164 个，另有大量生成的 gRPC 代码和复制/改写的 Flutter 组件代码。整体工程不是不可维护，但已经进入“发布风险高于功能风险”的阶段：凭据保护、TLS 绕过、测试缺失、CI 供应链和大模块复杂度是当前最需要处理的风险。

最大问题是安全与发布边界偏松：登录 Cookie、access key、refresh token 和 WebDAV 凭据以 Hive 普通 box 持久化；代理开关会隐式接受坏证书；CI 使用宽权限发布 token，并从 tag / mutable URL 引入构建工具。稳定性方面，Cookie 导入、设置恢复、弹幕离线下载和多个 silent catch 路径都存在真实失败模式。测试方面，仓库没有 `test/` 或 `integration_test/`，CI 也没有 `flutter analyze` / `flutter test` 门禁，这让上述风险几乎只能靠人工回归发现。

亮点是项目已有较清晰的功能目录、集中化的 `Request` 网络层、统一的 Hive 存储入口、跨平台构建脚本和 lockfile；很多 HTTP 调用也设置了基础超时。下一阶段不建议重写，而应先收紧凭据/TLS/CI/测试这几个边界，再逐步拆分视频播放、设置、下载等大模块。

### Remediation Progress

- [ ] 1. Stop storing account/WebDAV secrets in plain Hive; introduce a platform `SecretStore` and exclude secrets from settings export.
- [x] 2. Remove automatic TLS bypass from proxy mode; keep bad-certificate behavior behind an explicit, audited switch.
- [x] 3. Reduce GitHub Actions permissions from `write-all`; pin high-risk actions/tools and add checksums for downloaded release tools.
- [x] 4. Move `piliplus-release.jks` out of the repository working tree and add a local/CI secret scan.
- [x] 5. Add `flutter analyze` and `flutter test` CI gates with the correct Flutter 3.44.4 toolchain.
- [ ] 6. Add tests for Cookie parsing, settings import rollback, TLS/proxy config, WebDAV restore and download segment scheduling.
- [x] 7. Make settings import/restore validate schema before clearing current data.
- [ ] 8. Limit download danmaku concurrency and persist per-segment progress.
- [x] 9. Disable mixed content in normal WebView flows.
- [ ] 10. Split video/player/settings large files along service/state/view boundaries.
- [ ] 11. Replace dynamic API response access with typed parsers and structured errors.
- [x] 12. Document Flutter SDK patch ownership and reduce toolchain mutation.
- [x] 13. Add log redaction and safe issue-report export.
- [x] 14. Pin Git dependency refs to lockfile commits.

### Score Dashboard

```
Security        █████░░░░░  5.2  B   本地凭据明文持久化、代理绕过 TLS 和 WebView 混合内容在中等覆盖下构成真实账号风险。
Stability       ██████░░░░  5.8  B   网络层有超时，但 Cookie 强制解包、设置恢复清空后导入和 silent catch 会放大故障。
Performance     ██████░░░░  6.4  B   主要性能风险集中在离线下载弹幕一次性并发请求和大型 UI/播放器模块，覆盖为中等。
Testing         ██░░░░░░░░  1.5  D   仓库没有测试目录，CI 没有 analyze/test 门禁，关键路径缺少真实回归保护。
Maintainability █████░░░░░  4.8  C   多个手写文件超过 1000 行，播放器、视频页和设置模块承担过多职责。
Design          █████░░░░░  5.0  B   项目有集中入口和分层迹象，但 SRP、Fail-Fast、Least Privilege 和 DRY 边界被多处违反。
Release         █████░░░░░  4.7  C   多平台构建齐全，但 CI 权限、工具校验、测试门禁和可复现发布仍不足。
─────────────────────────────────────
Overall         █████░░░░░  4.8  C
```

Each dimension scored 0.0-10.0. **Higher = better.** Scores are judgment-based, not formula-based. See `rubrics/scoring.md` for anchor descriptions.

### Finding Statistics

| Severity | Count | Confirmed | Suspected |
|----------|-------|-----------|-----------|
| Critical | 0 | 0 | 0 |
| High | 4 | 4 | 0 |
| Medium | 11 | 9 | 2 |
| Low | 0 | 0 | 0 |
| Info | 0 | 0 | 0 |
| **Total** | **15** | **13** | **2** |

## 2. Project Map

PiliPlus 的运行入口是 `lib/main.dart`，初始化顺序为 Flutter binding、MediaKit、应用目录、Hive 存储、下载/临时目录、缓存、GetX 服务、全局 `HttpOverrides`、平台特定窗口/屏幕设置、`Request` 单例和账号 Cookie 刷新。网络边界集中在 `lib/http/init.dart` 的 Dio 单例和 `lib/utils/accounts/account_manager/account_mgr.dart` 的账号拦截器。账号状态由 `lib/utils/accounts.dart` 和 `lib/utils/accounts/account.dart` 持有，登录 Cookie/access key/refresh token 存在 Hive `account` box，设置与 WebDAV 凭据存在 Hive `setting` box。

UI 和业务逻辑主要位于 `lib/pages/**`，播放器在 `lib/plugin/pl_player/**`，下载服务在 `lib/services/download/**`，WebView 在 `lib/pages/webview/view.dart` 和登录极验 WebView。持久化包括 Hive、下载目录、缓存、日志 JSON 文件、WebDAV 远端备份。外部接口包括 Bilibili HTTP/gRPC、Bilibili WebView 页面、WebDAV、GitHub release API、SponsorBlock、文件选择器、相册保存、权限和平台原生能力。

审计重点检查了手写 Dart 源码、账号/网络/存储/WebView/下载/日志路径、Android/iOS/macOS/Windows/Linux 发布配置、GitHub Actions、依赖清单、lockfile 和 README。排除项包括 `lib/grpc/**` 生成代码、`lib/common/widgets/flutter/**` 的大段 Flutter 复制代码的逐行语义审查、二进制素材、截图、字体、平台构建产物和 lockfile 的完整漏洞数据库审计。尝试运行 `flutter analyze`，但本机 Flutter 为 3.41.2，项目要求 3.44.4，且命令 120 秒超时；`fvm` 未安装，因此静态分析结果未纳入结论。

### Coverage Matrix

| Dimension | Coverage | Evidence inspected | Exclusions / limits |
|-----------|----------|--------------------|---------------------|
| Architecture | Medium | `lib/main.dart`, `lib/http/init.dart`, `lib/utils/accounts.dart`, `lib/services/download/**`, large-file inventory | 未逐行审查全部 1164 个手写 Dart 文件 |
| Security | Medium | 账号存储、TLS/代理、WebView、CI secrets、Android manifest、WebDAV | 未做动态 MITM、移动端取证或第三方漏洞扫描 |
| Stability | Medium | Cookie 导入、Dio 错误处理、设置恢复、下载、silent catch 搜索 | 未完成 `flutter analyze` 和设备运行验证 |
| Performance | Medium | 下载弹幕并发、播放器/视频页大文件、缓存/下载路径 | 未做性能 profiling 或真实长视频压测 |
| Testing | High | `test/`、`integration_test/`、CI workflow、测试关键字搜索 | 无测试目录可进一步抽样 |
| Maintainability | Medium | 文件行数、模块布局、设置/视频/播放器/下载路径 | 未做完整复杂度工具统计 |
| Design | Medium | SRP、Fail-Fast、Least Privilege、DRY、配置边界 | 原则分析基于代表性高风险路径 |
| Release | High | `.github/workflows/**`, `lib/scripts/*.ps1`, Android/iOS/macOS/Linux/Windows 配置 | 未实际构建所有平台 |
| Documentation | Medium | `README.md`, `tool/README.md`, workflow 和脚本文档线索 | 未验证所有截图和用户声明 |
| Configuration | Medium | `analysis_options.yaml`, `pubspec.yaml`, `storage_pref.dart`, 设置页面 | 未运行所有配置组合 |
| Observability | Medium | `services/logger.dart`, `JsonFileHandler`, 日志页面、debugPrint 搜索 | 未触发真实 crash report |
| Data Integrity | Medium | Hive 导入/导出、WebDAV restore、下载 entry/index 写入 | 未做断电/并发恢复测试 |
| Privacy | Medium | Cookie、WebDAV 凭据、搜索历史、日志、用户信息缓存 | 未审查所有模型字段的隐私分类 |
| Accessibility | Low | Flutter UI 结构抽样、WebView/设置/日志页面 | 未进行屏幕阅读器、键盘和小屏实测 |
| Supply Chain | High | `pubspec.yaml`, `pubspec.lock`, GitHub Actions, AppImage 下载 | 未查询 CVE 数据库 |
| Cost | Medium | 下载并发、日志/缓存、外部 API 请求 | 未观测真实流量或后端成本 |
| AI-Safety | Not assessed | 搜索未发现自有 LLM prompt、agent、RAG、工具调用边界 | 仅有 Bilibili “AI 总结/翻译”相关模型数据，不构成自有 AI 系统 |
| Fallback | Medium | `catch (_) {}`, `try/catch` 搜索、默认值和恢复路径 | 未逐个审查 302 个候选点 |
| Testing-Authenticity | High | 测试目录和 CI 搜索 | 无测试可评估真实性，只能确认缺口 |
| Type-Safety | Medium | `!` 强制解包、dynamic/Map 搜索、Cookie 模型 | 未做 Dart analyzer 全量结果 |
| Frontend-State | Medium | GetX controller/view 抽样、大组件和状态初始化 | 未做 UI 交互 race 动态验证 |
| Backend-API | Not assessed | 项目是 Flutter 客户端，没有自有服务端 endpoint | 仅审查了客户端 API 调用边界 |
| Dependency-Weight | Medium | 直接依赖、Git override、生成代码和复制框架代码 | 未计算 APK/IPA/桌面包实际体积 |
| Code-Consistency | Medium | lint 配置、导入/错误处理/存储模式、silent catch 搜索 | 未做格式化 diff 或自动 lint 完成结果 |
| Comment-Coverage | Medium | TODO/FIXME/ignore 搜索、README 和脚本注释 | 未逐个审查所有 public API doc |

## 3. Top Risks

| Rank | Finding | Severity | Summary |
|------|---------|----------|---------|
| 1 | 登录与 WebDAV 凭据以普通 Hive box 持久化 | High | 本地文件或备份被读取即可取得 Cookie、access key、refresh token 和 WebDAV 凭据。 |
| 2 | 代理设置会隐式关闭 TLS 证书验证 | High | 用户只开启代理就会接受坏证书，登录态请求可被中间人截获。 |
| 3 | CI/release token 权限过宽且供应链未固定到不可变来源 | High | 构建 workflow 使用 `write-all`，多个 actions/tools 通过 tag 或 mutable URL 引入。 |
| 4 | 没有测试目录和 CI 测试门禁 | High | 登录、Cookie、下载、设置恢复、发布脚本等关键路径没有自动回归保护。 |
| 5 | WebView 注入 Cookie 同时允许 mixed content | Medium | 带登录态的 WebView 允许 HTTP 子资源，提升页面链路被劫持时的账号风险。 |
| 6 | Cookie 模型对必需字段强制解包 | Medium | 不完整 Cookie 或异常恢复数据会在账号刷新/切换时触发运行时异常。 |
| 7 | 离线下载弹幕分片无并发上限 | Medium | 长视频会一次性发出大量 gRPC 请求并聚合到内存，造成卡顿、限流或失败。 |
| 8 | 设置导入/恢复先清空再写入且缺少 schema 校验 | Medium | 损坏的剪贴板/文件/WebDAV 数据可能清空本地设置后导入失败。 |
| 9 | 多个 Git 分支依赖和 mutable release 工具削弱可复现性 | Medium | lockfile 有 commit，但 manifest 仍声明 `main`/`dev`/`master` 等可变 ref。 |
| 10 | CI 直接 patch Flutter SDK | Medium | 构建结果依赖脚本对工具链工作区的状态修改，升级和复现成本高。 |
| 11 | 视频/播放器/设置模块文件过大 | Medium | 多个 1000-2000 行手写文件承担 UI、状态、业务和 I/O 多重职责。 |
| 12 | Silent catch 和默认兜底隐藏真实故障 | Medium | 网络激活、连接池重置、下载目录读取等失败路径缺少日志/指标/用户可见处理。 |
| 13 | 工作区根目录存在未跟踪 release keystore | Medium | `.gitignore` 已覆盖，但本地敏感发布材料仍位于仓库根目录，误传或备份泄露会影响发布可信度。 |
| 14 | 日志和错误反馈缺少敏感字段脱敏边界 | Medium | 用户复制或提交日志时，错误详情可能携带请求参数、路径或账号上下文。 |
| 15 | 客户端 API 调用缺少统一输入/响应契约校验 | Medium | 外部字段变化或网络错误 map 可能在 UI/controller 深层触发 null crash 或混乱提示。 |

## 4. Detailed Findings

### Finding: 登录与 WebDAV 凭据以普通 Hive box 持久化

- Severity: High
- Confidence: High
- Category: Security
- Status: Confirmed
- Affected area: 账号系统、本地存储、WebDAV 设置
- Evidence:
  - File: `lib/utils/storage.dart:27-58`, `lib/utils/accounts/account_adapter.dart:25-35`, `lib/utils/accounts/cookie_jar_adapter.dart:10-15`, `lib/pages/webdav/view.dart:130-136`
  - Function / Module: `GStorage.init`, `LoginAccountAdapter.write`, `BiliCookieJarAdapter.write`, `WebDavSettingPage`
  - Relevant behavior: Hive 使用普通 `openBox` 打开 `account` 和 `setting`；账号适配器直接写入 Cookie jar、access key、refresh token；WebDAV 页面把 URI、用户名、密码直接写入 setting box。
- Problem: 登录态和远端备份凭据没有使用 Android Keystore、iOS Keychain、macOS Keychain、Windows Credential Locker 或桌面等价安全存储，也没有对 Hive box 加密。
- Why it matters: 本地文件、非加密设备备份、调试导出或恶意同机进程读取应用数据后，可以复用用户 Bilibili 登录态或 WebDAV 凭据。
- Realistic failure scenario: 用户在共享电脑或 root/jailbreak 设备上运行应用，攻击者读取应用 support 目录下的 Hive 文件，恢复 Cookie/access key 后执行点赞、评论、私信或账号设置操作。
- Minimal fix: 将 `LoginAccount` 的 Cookie/access key/refresh token 和 WebDAV password 迁移到平台安全存储；Hive 中只保留账号 ID、非敏感偏好和安全存储引用 key。
- Better long-term fix: 引入 `SecretStore` 抽象，按平台实现安全存储、迁移、轮换和清除；为导出/备份显式排除敏感字段。
- Regression test suggestion: 增加 `SecretStore` fake 的单元测试，断言 `GStorage.exportAllSettings()` 和 Hive setting/account box 不包含 Cookie、access key、refresh token、WebDAV password。
- Estimated effort: 2-4 天

### Finding: 代理设置会隐式关闭 TLS 证书验证

- Severity: High
- Confidence: High
- Category: Security
- Status: Confirmed
- Affected area: 网络层、代理配置、TLS 验证
- Evidence:
  - File: `lib/http/init.dart:148-155`, `lib/http/init.dart:160-173`, `lib/pages/setting/models/extra_settings.dart:587-598`, `lib/pages/setting/widgets/switch_item.dart:72-78`
  - Function / Module: `Request._createPool`, `_showProxyDialog`, `SetSwitchItem.switchChange`
  - Relevant behavior: 启用系统代理时，HTTP/1.1 adapter 设置 `badCertificateCallback = true`，HTTP/2 connection manager 设置 `onBadCertificate = true`；单独的“禁用 SSL 证书验证”开关有确认弹窗，但代理开关没有等价确认。
- Problem: “设置代理”和“禁用证书验证”被耦合，用户只是想配置代理也会隐式接受任意证书。
- Why it matters: 代理服务、公共 Wi-Fi 或被劫持的网络可以伪造 Bilibili/API/WebDAV/GitHub 证书，读取或篡改带 Cookie 的请求。
- Realistic failure scenario: 用户为调试或网络加速启用代理，代理端返回自签证书；客户端仍发送登录态请求，中间人记录 Cookie 或修改接口响应。
- Minimal fix: 代理配置不得自动关闭证书校验；将证书绕过保留为独立高级开关，并在每次开启代理时保持默认 TLS 验证。
- Better long-term fix: 支持用户导入自定义 CA 或按 host pinning 调试证书，避免全局接受坏证书。
- Regression test suggestion: 对 `_createPool` 增加单元测试或集成测试，断言 `enableSystemProxy=true` 且 `badCertificateCallback=false` 时不会设置 bad certificate callback。
- Estimated effort: 0.5-1 天

### Finding: CI/release token 权限过宽且供应链未固定到不可变来源

- Severity: High
- Confidence: High
- Category: Release
- Status: Confirmed
- Affected area: GitHub Actions 发布流程
- Evidence:
  - File: `.github/workflows/build.yml:55-92`, `.github/workflows/build.yml:133-184`, `.github/workflows/linux_x64.yml:190-232`
  - Function / Module: `Build` workflow, Linux AppImage packaging
  - Relevant behavior: Android job和 reusable workflow 调用使用 `permissions: write-all`；release 使用第三方 action tag；Linux workflow 从 `continuous` URL 下载 `appimagetool-x86_64.AppImage` 并直接执行，没有 checksum 或签名校验。
- Problem: 发布 token 权限大于实际需要，构建工具来源可变且未校验。
- Why it matters: 一旦 workflow 中的构建脚本、第三方 action、可变下载工具或依赖链被污染，攻击者更容易写 release、上传工件或篡改发布资产。
- Realistic failure scenario: 上游 action tag 被移动或 continuous AppImage 被替换，workflow 在具有写权限的上下文中执行恶意代码并发布被污染的安装包。
- Minimal fix: 将默认权限改为只读，只在 release job 授予 `contents: write`；将高风险 actions pin 到 commit SHA；AppImage 工具下载固定版本并校验 SHA256。
- Better long-term fix: 引入 SLSA provenance、artifact checksum、签名和最小权限环境分离，PR 构建与 release 构建使用不同 workflow 和 token。
- Regression test suggestion: 增加 workflow lint 检查，拒绝 `permissions: write-all`、未 pin action 和无 checksum 的外部二进制下载。
- Estimated effort: 1-2 天

### Finding: 没有测试目录和 CI 测试门禁

- Severity: High
- Confidence: High
- Category: Testing
- Status: Confirmed
- Affected area: 测试体系、CI、关键回归路径
- Evidence:
  - File: repository inventory, `.github/workflows/build.yml:116-121`, `.github/workflows/win_x64.yml:57-60`
  - Function / Module: GitHub Actions build workflows
  - Relevant behavior: `test/` 和 `integration_test/` 目录不存在；workflow 只执行平台 build/package，没有 `flutter analyze`、`flutter test` 或关键路径集成测试。
- Problem: 登录、Cookie、网络拦截器、设置导入/恢复、下载队列、WebView 和发布脚本没有自动化回归保护。
- Why it matters: 当前发现的安全和稳定性问题都属于容易被 UI 手测遗漏的边界路径；没有测试门禁会让修复和后续重构风险很高。
- Realistic failure scenario: 开发者修改账号存储或请求拦截器后，Android release 能构建成功，但 Cookie 登录、WebDAV 恢复或下载续传在用户设备上失败。
- Minimal fix: 先添加 `flutter analyze` 和少量纯 Dart 单元测试，覆盖账号 Cookie 解析、设置导入事务、TLS 配置、下载分片调度。
- Better long-term fix: 建立分层测试策略：核心逻辑单测、HTTP fake 集成测试、WebView/登录关键 E2E 冒烟、发布 workflow 强制门禁。
- Regression test suggestion: CI 中新增 `flutter analyze`、`flutter test`，并添加至少一个失败 Cookie、损坏设置 JSON、长视频下载调度的回归测试。
- Estimated effort: 3-5 天起步

### Finding: WebView 注入 Cookie 同时允许 mixed content

- Severity: Medium
- Confidence: Medium
- Category: Security
- Status: Suspected
- Affected area: WebView 登录态浏览
- Evidence:
  - File: `lib/utils/login_utils.dart:21-44`, `lib/pages/webview/view.dart:171-183`, `lib/pages/webview/view.dart:318-349`
  - Function / Module: `LoginUtils.setWebCookie`, `WebviewPage`
  - Relevant behavior: 应用把账号 Cookie 写入 `flutter_inappwebview` CookieManager；WebView 启用 JavaScript，并设置 `mixedContentMode: MixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW`。
- Problem: 登录态 WebView 允许 HTTP mixed content，降低了页面资源完整性边界。
- Why it matters: 如果被打开页面、跳转链或第三方资源引入 HTTP 内容，攻击者可以在同一页面环境中影响脚本或资源，增加账号态操作风险。
- Realistic failure scenario: 用户打开一个包含 HTTP 子资源的 Bilibili 相关页面，公共网络中的攻击者篡改该子资源，诱导页面发起带 Cookie 的请求或跳转到恶意外链。
- Minimal fix: 默认使用 `MIXED_CONTENT_NEVER_ALLOW`；仅对明确需要的可信页面临时放开，并记录原因。
- Better long-term fix: WebView 增加 allowlist、外链确认、Cookie 注入范围控制和页面类型隔离，登录/风控 WebView 与普通浏览 WebView 分离。
- Regression test suggestion: Widget/integration 测试构造 WebView settings，断言普通 WebView 不允许 mixed content，只有明确 allowlist 场景例外。
- Estimated effort: 0.5-1 天

### Finding: Cookie 模型对必需字段强制解包

- Severity: Medium
- Confidence: High
- Category: Stability
- Status: Confirmed
- Affected area: Cookie 登录、账号恢复、账号模式切换
- Evidence:
  - File: `lib/utils/accounts/account.dart:77-105`, `lib/pages/login/controller.dart:140-183`, `lib/utils/accounts.dart:36-46`
  - Function / Module: `LoginAccount.csrf`, `LoginAccount._midStr`, `LoginPageController.loginByCookie`, `Accounts.refresh`
  - Relevant behavior: `LoginAccount` 通过 `domainCookies['bilibili.com']!['/']!['bili_jct']!` 和 `DedeUserID` 强制解包并 `int.parse`；Cookie 登录只过滤可解析 Cookie 片段，没有显式验证必需字段。
- Problem: 不完整、过期或格式异常的 Cookie 可以构造出 `LoginAccount`，随后在访问 `mid/csrf` 或刷新账号模式时抛出运行时异常。
- Why it matters: 登录态恢复是启动关键路径，运行时异常会阻止用户进入应用或切换账号，并且错误信息对用户不可操作。
- Realistic failure scenario: 用户手动粘贴只含 `SESSDATA` 的 Cookie，接口短暂返回成功或恢复数据中缺字段；账号保存后下次启动 `Accounts.refresh()` 访问 `mid` 崩溃。
- Minimal fix: 在 `LoginAccount` 构造前验证 `DedeUserID`、`bili_jct`、必要 Cookie domain/path 和 mid 数字格式；失败时返回明确错误。
- Better long-term fix: 将 `LoginAccount` 改为不可构造非法状态的 factory，返回 `Result<LoginAccount, AccountParseError>`。
- Regression test suggestion: 添加 Cookie 登录单测，覆盖缺 `DedeUserID`、缺 `bili_jct`、非数字 mid、空 Cookie 四种场景。
- Estimated effort: 0.5-1 天

### Finding: 离线下载弹幕分片无并发上限

- Severity: Medium
- Confidence: High
- Category: Performance
- Status: Confirmed
- Affected area: 离线下载、弹幕获取、gRPC 请求
- Evidence:
  - File: `lib/services/download/download_service.dart:300-331`, `lib/pages/danmaku/controller.dart:32-40`
  - Function / Module: `DownloadService.downloadDanmaku`, `PlDanmakuController.segmentLength`
  - Relevant behavior: 根据视频总时长按 6 分钟分片计算 `seg`，然后用 `Future.wait` 一次性发起 `1..seg` 的全部 `DmGrpc.dmSegMobile` 请求，并把所有结果合并到内存对象后写文件。
- Problem: 并发量与视频时长线性增长，没有请求并发上限、失败重试预算或流式写入。
- Why it matters: 长视频、合集课程或弱网络会触发大量同时请求，造成 UI 卡顿、内存峰值、接口限流或整批失败。
- Realistic failure scenario: 用户下载数小时课程视频，应用一次性发起几十个弹幕分片请求；部分请求超时导致整次弹幕下载失败，视频进入失败状态或反复重试。
- Minimal fix: 使用固定并发队列，例如 3-5 个分片并发；每个分片独立失败记录，成功分片先落盘。
- Better long-term fix: 为离线下载建立任务调度器，支持并发限制、指数退避、进度持久化、断点恢复和可观测状态。
- Regression test suggestion: 使用 fake `DmGrpc` 测试 2 小时视频时最大并发不超过设定值，且单个分片失败不会丢弃已成功分片。
- Estimated effort: 1-2 天

### Finding: 设置导入/恢复先清空再写入且缺少 schema 校验

- Severity: Medium
- Confidence: High
- Category: Stability
- Status: Confirmed
- Affected area: 设置导入、WebDAV restore、数据恢复
- Evidence:
  - File: `lib/utils/storage.dart:80-96`, `lib/pages/webdav/webdav.dart:87-94`, `lib/common/widgets/dialog/export_import.dart:117-138`
  - Function / Module: `GStorage.importAllJsonSettings`, `WebDav.restore`, `importFromLocalFile`
  - Relevant behavior: 导入时直接 `setting.clear().then((_) => setting.putAll(map[setting.name]))` 和 `video.clear().then(...)`，没有先验证 map schema、key 存在、类型正确或写入可完成。
- Problem: 导入是破坏性操作，但没有事务、备份、schema 校验或回滚。
- Why it matters: 损坏的剪贴板 JSON、错误文件或 WebDAV 远端旧格式会清空当前设置，然后在 `putAll` 时失败或写入不完整数据。
- Realistic failure scenario: 用户从 WebDAV 恢复一个缺少 `setting` 字段的旧备份，`setting.clear()` 已完成，随后 `putAll(null)` 抛错，用户偏好丢失。
- Minimal fix: 导入前完整解析并验证 `setting`、`video` 两个 map；写入前创建本地快照，失败时恢复。
- Better long-term fix: 为设置导入引入版本号、迁移器和原子替换流程，支持 dry-run 预览。
- Regression test suggestion: 添加损坏 JSON、缺字段、类型错误、部分写入失败的测试，断言原设置保持不变。
- Estimated effort: 1 天

### Finding: 多个 Git 分支依赖和 mutable release 工具削弱可复现性

- Severity: Medium
- Confidence: High
- Category: Release
- Status: Confirmed
- Affected area: 依赖和发布供应链
- Evidence:
  - File: `pubspec.yaml:41-174`, `pubspec.yaml:176-226`, `pubspec.lock:95-1222`, `.github/workflows/linux_x64.yml:190-195`
  - Function / Module: Flutter dependency manifest, Linux AppImage packaging
  - Relevant behavior: manifest 中多个依赖使用 `ref: main`、`develop`、`dev`、`master`、`mod`、`const`；lockfile 有 28 个 `resolved-ref`；Linux workflow 下载 continuous AppImage 工具执行。
- Problem: lockfile 当前固定了 commit，但 manifest 仍声明可变分支，后续 `pub upgrade` 或 lockfile 变更会引入未经审查的上游代码；发布工具也没有固定版本和校验。
- Why it matters: 客户端处理登录态、Cookie、WebView 和本地文件，依赖污染会直接影响用户账号和发布包可信度。
- Realistic failure scenario: 某个 fork 依赖的 `dev` 分支被 force-push，维护者更新 lockfile 后 CI 正常构建，但新依赖引入恶意网络拦截或数据外传。
- Minimal fix: 对 Git 依赖改用 commit SHA 或受保护 tag；为 AppImage 工具固定 release 版本并校验 SHA256。
- Better long-term fix: 建立依赖升级 PR 模板、SBOM、依赖 diff 审查和周期性安全扫描。
- Regression test suggestion: CI 增加脚本检查 `pubspec.yaml` 中是否存在 `ref: main/master/dev/develop` 和未校验外部二进制下载。
- Estimated effort: 1-2 天

### Finding: CI 直接 patch Flutter SDK

- Severity: Medium
- Confidence: High
- Category: Release
- Status: Confirmed
- Affected area: 构建脚本、Flutter toolchain reproducibility
- Evidence:
  - File: `lib/scripts/patch.ps1:63-122`, `.github/workflows/build.yml:80-84`, `.github/workflows/win_x64.yml:29-31`
  - Function / Module: `patch.ps1`, build workflows
  - Relevant behavior: 脚本 `Set-Location $env:FLUTTER_ROOT` 后执行 `git reset --hard HEAD`、`git revert`、`git apply`，将项目 patch 应用到 Flutter SDK 工作区。
- Problem: 构建结果依赖对本地/CI Flutter SDK 的可变修改，而不是依赖标准版本或项目内 vendored patch。
- Why it matters: Flutter 升级、CI cache、patch 冲突或本地 SDK 状态都可能影响构建结果；失败时也难以判断是应用代码还是工具链 patch 引起。
- Realistic failure scenario: CI 升级到新的 Flutter 3.44.x patch 版本，某个 SDK patch 仍能部分 apply，但改变行为，导致 Windows 或 Android 包运行时 UI 选择/弹窗异常。
- Minimal fix: 对每个 patch 增加版本/commit 校验和失败即停；不要在未验证目标 SDK revision 时继续构建。
- Better long-term fix: 尽量上游化 patch 或维护明确的 Flutter fork/submodule；构建从固定 toolchain artifact 拉取。
- Regression test suggestion: CI 先检查 `$FLUTTER_ROOT` revision 等于 `.fvmrc`/预期 commit，再 dry-run apply patch 并输出 patch 统计。
- Estimated effort: 1-3 天

### Finding: 视频、播放器、设置模块文件过大

- Severity: Medium
- Confidence: High
- Category: Maintainability
- Status: Confirmed
- Affected area: 视频页、播放器、设置、HTTP API 模块
- Evidence:
  - File: `lib/plugin/pl_player/view/view.dart:1-2279`, `lib/pages/video/widgets/header_control.dart:1-2030`, `lib/pages/video/view.dart:1-1976`, `lib/plugin/pl_player/controller.dart:1-1527`, `lib/pages/setting/models/extra_settings.dart:1-1227`
  - Function / Module: PL player, video page, settings model
  - Relevant behavior: 多个手写文件超过 1000 行，同时包含 UI 构建、状态读写、业务规则、网络/文件操作和平台差异处理。
- Problem: 单文件职责过多，违反 SRP 1.1 和 File Size Limit 1.2。
- Why it matters: 播放器和视频页是核心工作流，大文件会让 bug 定位、测试隔离和功能修改成本显著增加。
- Realistic failure scenario: 修改全屏手势或下载按钮时需要同时理解播放器状态、设置持久化、弹幕、截图、UI 控件和平台分支，容易引入回归。
- Minimal fix: 先按低风险边界拆出纯函数/小服务：设置读写 adapter、播放器命令、弹幕选项、下载按钮状态、WebView/路由动作。
- Better long-term fix: 建立 feature 层结构：view、controller、service、state model、pure domain helpers，并为每个 helper 补单测。
- Regression test suggestion: 拆分前先添加播放器状态转换和设置动作的单元测试，确保重构不改变行为。
- Estimated effort: 1-2 周分阶段

### Finding: Silent catch 和默认兜底隐藏真实故障

- Severity: Medium
- Confidence: High
- Category: Stability
- Status: Confirmed
- Affected area: 网络激活、连接池重置、下载目录读取、WebDAV 备份
- Evidence:
  - File: `lib/http/init.dart:62-101`, `lib/http/init.dart:179-195`, `lib/services/download/download_service.dart:89-104`, `lib/pages/webdav/webdav.dart:65-76`
  - Function / Module: `Request.buvidActive`, `_resetAdaptersForNetworkChange`, `_readDownloadDirectory`, `WebDav.backup`
  - Relevant behavior: 多处 `catch (_) {}` 或 catch 后只返回失败状态，没有结构化日志、错误上下文或可恢复动作。
- Problem: 失败被吞掉后系统继续运行，调用者无法区分“成功、跳过、部分失败、数据损坏”。
- Why it matters: 网络连接池、账号激活、下载索引和远端备份都是排障关键路径；静默失败会导致用户看到空列表、登录异常或备份缺失但缺少根因。
- Realistic failure scenario: 下载目录中某个 `entry.json` 损坏，读取时被静默跳过，用户以为下载消失；没有日志说明哪个文件损坏，也无法修复。
- Minimal fix: 对每个 catch 至少记录模块、文件/URL、异常类型和可恢复动作；对预期可忽略错误加注释说明。
- Better long-term fix: 定义统一 `Result` / `LoadingState` 错误类型，区分用户提示、诊断日志和自动恢复。
- Regression test suggestion: 构造损坏下载 entry、连接池重置异常和 WebDAV remove 失败，断言错误被记录且用户状态明确。
- Estimated effort: 2-4 天

### Finding: 工作区根目录存在未跟踪 release keystore

- Severity: Medium
- Confidence: Medium
- Category: Release
- Status: Suspected
- Affected area: Android 发布签名材料、本地开发工作区
- Evidence:
  - File: `piliplus-release.jks`, `.gitignore:76-77`, `setup-android-signing.ps1:202-250`, `android/app/build.gradle.kts:40-55`
  - Function / Module: Android signing setup
  - Relevant behavior: 工作区根目录存在 `piliplus-release.jks`，`git ls-files` 未显示该文件被跟踪，`.gitignore` 覆盖 `*.jks`；签名脚本会生成同名 keystore 并编码为临时文本文件。
- Problem: 虽然未提交到 Git，但敏感发布材料放在仓库根目录，容易被手动压缩、备份、误传或 IDE/脚本收集。
- Why it matters: 如果这是实际发布 keystore，泄露会破坏 Android 包升级链可信度，通常需要轮换签名策略或迁移发布身份。
- Realistic failure scenario: 开发者把整个工作区打包发给协作者或上传到云盘，未注意根目录的 `.jks` 文件，导致 release 签名材料外泄。
- Minimal fix: 将 keystore 移出仓库目录，使用系统凭据库或专用 secrets 目录；脚本只引用外部路径。
- Better long-term fix: 发布签名仅在受控 CI secret 中解码到短生命周期临时目录，并在 job 结束后清理；本地脚本生成后自动提示移动到仓库外。
- Regression test suggestion: 增加 pre-commit/CI secret scan，拒绝 `.jks`、`keystore_base64.txt`、`key.properties` 出现在仓库工作区或 artifact。
- Estimated effort: 0.5 天

### Finding: 日志和错误反馈缺少敏感字段脱敏边界

- Severity: Medium
- Confidence: Medium
- Category: Security
- Status: Confirmed
- Affected area: Crash 日志、本地日志页面、错误复制
- Evidence:
  - File: `lib/services/logger.dart:19-31`, `lib/utils/json_file_handler.dart:80-86`, `lib/pages/setting/pages/logs.dart:51-89`, `lib/pages/setting/pages/logs.dart:279-372`
  - Function / Module: `LoggerUtils.getLogsPath`, `JsonFileHandler._processReport`, `LogsPage.copyLogs`, `_ReportCard`
  - Relevant behavior: Catcher report 以 JSON 行写到 `.pili_logs.json`；日志页面展示并复制错误详情、设备信息、应用信息和堆栈；未看到对 Cookie、URL query、用户标识、WebDAV URI 等敏感字段的统一脱敏器。
- Problem: 错误对象和堆栈可能包含请求 URL、参数、用户输入或路径，日志复制功能会把这些信息直接放入剪贴板。
- Why it matters: 用户提交 issue 或转发日志时，可能无意泄露账号、路径、设备和隐私上下文。
- Realistic failure scenario: 某个网络请求异常把完整 URL 或 WebDAV 配置带入 error message，用户点击“复制日志”提交到公开 issue。
- Minimal fix: 在写入和复制日志前统一 redaction，覆盖 Cookie、access key、csrf、WebDAV 用户名/路径、手机号、邮箱和本地绝对路径。
- Better long-term fix: 建立结构化错误模型，区分用户可分享 report 和本地诊断 report，默认复制脱敏版。
- Regression test suggestion: 构造包含 Cookie、csrf、URL token、WebDAV URI 的 fake report，断言日志文件和复制文本中敏感值被替换为 `<redacted>`。
- Estimated effort: 1-2 天

### Finding: 客户端 API 调用缺少统一输入/响应契约校验

- Severity: Medium
- Confidence: High
- Category: Maintainability
- Status: Confirmed
- Affected area: HTTP API client、动态 JSON 模型、错误处理
- Evidence:
  - File: `lib/http/init.dart:257-309`, `lib/models/dynamics/result.dart:984-1252`, `lib/pages/login/controller.dart:621-628`, `lib/http/video.dart:1043-1050`
  - Function / Module: `Request.get/post`, dynamic JSON parsing, login account setup
  - Relevant behavior: 网络层返回原始 `Response`，错误时构造 `{message: ...}` map；多处业务代码直接访问嵌套 JSON、dynamic 字段和 `!` 字段。
- Problem: API 边界没有统一 schema 校验和 typed error contract，导致调用方分散处理 `code/data/message/null` 组合。
- Why it matters: Bilibili API 字段变化或网络层错误 map 会在深层 UI/controller 中表现为 null crash 或错误提示混乱。
- Realistic failure scenario: 登录接口返回缺少 `token_info` 或字段类型变化，controller 某处 `data['cookie_info']['cookies']` 访问失败，用户只看到泛化 toast。
- Minimal fix: 为高风险 API 封装 typed response parser，失败返回结构化错误，而不是让 UI/controller 直接消费 dynamic map。
- Better long-term fix: 将 `Request` 层分为 transport、API client、domain result 三层，所有外部 JSON 只在 client 层解析和验证。
- Regression test suggestion: 使用 fake Dio response 覆盖缺字段、字段类型错误、业务 code 非 0、网络错误四类响应。
- Estimated effort: 3-7 天分批

## 5. Architecture Concerns / 架构问题

- Coverage: Medium
- Inspected evidence: `lib/main.dart`, `lib/http/init.dart`, `lib/utils/accounts.dart`, `lib/pages/**`, `lib/plugin/pl_player/**`, large-file inventory
- Exclusions / limits: 未逐行审查所有页面和模型；生成 gRPC 代码排除

架构上有集中入口和基础分层：`http/` 做 API，`utils/accounts` 做账号，`services/download` 做下载，`pages/` 做 UI。主要问题是边界仍然偏“页面驱动”：UI controller 能直接写 Hive、发网络请求、解析 dynamic JSON、操作下载和路由。视频、播放器和设置几个核心模块已经形成高耦合热点。

| Subtype | Count | Affected Areas | Recommended Action |
|---------|-------|----------------|-------------------|
| ModuleBoundary | 3 | 视频页、播放器、设置 | 拆出服务和纯状态模型 |
| DependencyDirection | 1 | UI/controller 直接依赖存储和网络 | 引入 API client/service 边界 |
| StateOwnership | 2 | Accounts/GStorage/GetX 状态 | 明确账号和设置 source of truth |
| BoundaryContract | 3 | API JSON、Cookie、设置导入 | 添加 schema/result 类型 |
| EvolutionRisk | 2 | Flutter SDK patch、Git 分支依赖 | 固定工具链和依赖来源 |

Relevant findings: 登录凭据持久化、Cookie 强制解包、设置导入先清空、大模块过大、客户端 API 缺少契约校验。

## 6. Security Concerns / 安全问题

- Coverage: Medium
- Inspected evidence: 账号存储、TLS/代理、WebView、日志、CI secrets、Android manifest、WebDAV
- Exclusions / limits: 未做动态攻击复现、CVE 扫描或移动端安全测试

安全风险集中在本地凭据和传输边界。当前没有发现硬编码远端 API token，但登录态和 WebDAV 凭据的本地保护不足，代理与证书绕过的实现会显著放大账号风险。日志脱敏和 WebView mixed content 也需要在稳定发布前收紧。

| Finding | Severity | Status | Affected Surface |
|---------|----------|--------|------------------|
| 登录与 WebDAV 凭据以普通 Hive box 持久化 | High | Confirmed | 本地账号/设置 |
| 代理设置会隐式关闭 TLS 证书验证 | High | Confirmed | 网络层 |
| WebView 注入 Cookie 同时允许 mixed content | Medium | Suspected | WebView |
| 日志和错误反馈缺少敏感字段脱敏边界 | Medium | Confirmed | 日志/反馈 |

Verified: Android `allowBackup=false` 有助于降低备份面；`.jks` 被 `.gitignore` 覆盖且未被 Git 跟踪。

## 7. Stability Concerns / 稳定性问题

- Coverage: Medium
- Inspected evidence: Dio wrapper、账号刷新、Cookie 登录、WebDAV restore、下载服务、silent catch 搜索
- Exclusions / limits: `flutter analyze` 未完成，未做设备端崩溃复现

稳定性基础有一定保障：Dio 设置了 10 秒连接/接收超时，WebDAV 设置了 12 秒超时，下载有暂停状态。但关键输入边界缺少 fail-fast，多个 catch 会吞掉诊断信息，设置恢复也不是事务式。

| Finding | Severity | Status | Failure Mode |
|---------|----------|--------|--------------|
| Cookie 模型对必需字段强制解包 | Medium | Confirmed | 不完整 Cookie 触发运行时异常 |
| 设置导入/恢复先清空再写入且缺少 schema 校验 | Medium | Confirmed | 损坏备份导致设置丢失 |
| Silent catch 和默认兜底隐藏真实故障 | Medium | Confirmed | 失败不可诊断 |
| 客户端 API 调用缺少统一输入/响应契约校验 | Medium | Confirmed | 字段变化导致深层错误 |

## 8. Performance Concerns / 性能问题

- Coverage: Medium
- Inspected evidence: 下载弹幕、播放器大文件、缓存/下载路径、HTTP 请求模式
- Exclusions / limits: 未做 profiling、帧率测试、包体积分析

性能风险不是普遍性算法问题，而是集中在少数高负载流程。离线下载弹幕的全量并发是最明确的问题；播放器和视频页大文件也会间接造成渲染和状态更新难以优化。

| Finding | Severity | Workload where this matters |
|---------|----------|-----------------------------|
| 离线下载弹幕分片无并发上限 | Medium | 长视频、课程、多任务离线下载 |
| 视频、播放器、设置模块文件过大 | Medium | 高频 UI 状态变化、全屏播放、弹幕/手势 |

## 9. Testing Gaps / 测试缺口

- Coverage: High
- Inspected evidence: `test/`、`integration_test/`、CI workflow、测试关键字搜索
- Exclusions / limits: 仓库没有测试可进一步评估质量

当前测试信心很低。没有测试目录，没有 CI 测试命令，发布 workflow 以构建成功作为主要门禁。对于一个处理登录、Cookie、本地文件、WebView、下载和多平台发布的客户端，这个缺口应当优先修复。

| Priority | Missing test area | Failure it would catch |
|----------|-------------------|------------------------|
| Must add | Cookie/account parsing | 不完整 Cookie 崩溃 |
| Must add | Settings import/restore | 损坏备份清空设置 |
| Must add | TLS/proxy config | 代理隐式关闭证书验证 |
| Should add | Download segmentation | 长视频无界并发 |
| Should add | WebView settings | mixed content/Cookie 注入边界 |
| Should add | Release workflow lint | 宽权限、未 pin action、无 checksum 下载 |

## 10. Maintainability Concerns / 可维护性问题

- Coverage: Medium
- Inspected evidence: 文件行数、目录结构、设置/播放器/视频/下载路径
- Exclusions / limits: 未运行复杂度工具，未逐个函数统计圈复杂度

维护性主要问题是规模和职责。复制的 Flutter 控件和生成代码本身可以接受，但手写业务文件也有多个超过 1000 行，且 UI、状态、存储、网络、平台分支混在一起。

| Finding | Severity | Affected Areas |
|---------|----------|----------------|
| 视频、播放器、设置模块文件过大 | Medium | `pl_player`, `pages/video`, `setting/models` |
| 客户端 API 调用缺少统一输入/响应契约校验 | Medium | `http/**`, `pages/login`, dynamic models |
| Silent catch 和默认兜底隐藏真实故障 | Medium | 网络、下载、WebDAV |

## 11. Design / Principles Concerns / 设计原则问题

- Coverage: Medium
- Inspected evidence: `rubrics/principles.md` 对照 SRP、Fail-Fast、Least Privilege、DRY、Configuration
- Exclusions / limits: 仅报告造成真实风险的原则问题

主要原则违例不是格式或命名，而是安全/稳定边界：Secret 未最小权限保存、代理隐式放宽 TLS、导入流程不 fail-fast、大文件多职责。

| Principle | Violations | Severity | Affected Areas |
|-----------|------------|----------|----------------|
| Single Responsibility 1.1 | 1 | Medium | 视频/播放器/设置大模块 |
| File Size Limit 1.2 | 1 | Medium | 多个 1000+ 行文件 |
| Fail-Fast 4.4 | 3 | Medium | Cookie、设置导入、API JSON |
| Least Privilege 4.6 | 3 | High | 凭据存储、CI 权限、WebView Cookie |
| Configuration Over Hardcoding 9.1 | 1 | Medium | TLS/代理策略 |
| Timeout Every External Call 10.4 | 0 material | Info | Dio/WebDAV 已有基础超时 |

## 12. Release Concerns / 发布问题

- Coverage: High
- Inspected evidence: `.github/workflows/**`, `lib/scripts/build.ps1`, `lib/scripts/patch.ps1`, Android signing, `.fvmrc`
- Exclusions / limits: 未实际构建各平台 artifact

发布流程覆盖平台多，但门禁和来源完整性不足。`flutter analyze` 在本机因版本不匹配/耗时未完成，说明本地环境也需要更明确的工具链约束。

| Finding | Severity | Release risk |
|---------|----------|--------------|
| CI/release token 权限过宽且供应链未固定到不可变来源 | High | 污染 release artifact |
| 没有测试目录和 CI 测试门禁 | High | 构建成功但关键功能坏 |
| CI 直接 patch Flutter SDK | Medium | 构建不可复现 |
| 工作区根目录存在未跟踪 release keystore | Medium | 发布签名材料误泄露 |

## 13. Documentation Analysis / 文档分析

- Coverage: Medium
- Inspected evidence: `README.md`, `tool/README.md`, `setup-android-signing.ps1`, workflows
- Exclusions / limits: 未核验所有功能截图和下载说明

README 对功能覆盖很充分，但更像用户展示页，缺少开发/测试/发布/回滚的操作文档。签名脚本有交互式说明，但 README 未清晰说明 release 签名、CI secret、Flutter 版本、测试命令和本地构建前置条件。

| Subtype | Count | Affected Docs | Recommended Action |
|---------|-------|---------------|-------------------|
| UserDocs | 0 | README | 保持现状 |
| OperatorDocs | 2 | 发布/签名/回滚 | 添加 release runbook |
| DeveloperDocs | 2 | 本地 setup/test/build | 添加 Flutter/FVM/patch 说明 |
| ApiDocs | 1 | HTTP/API contract | 说明 API client 错误模型 |
| DecisionRecord | 2 | Flutter SDK patch、Git fork deps | 添加 ADR |
| StaleDocs | 1 | `description: A new Flutter project` | 更新 pubspec 描述 |

## 14. Observability / Operability Analysis / 可观测性分析

- Coverage: Medium
- Inspected evidence: `services/logger.dart`, `utils/json_file_handler.dart`, `pages/setting/pages/logs.dart`, catch/debugPrint 搜索
- Exclusions / limits: 未触发真实 crash 或检查线上反馈流程

项目有本地日志和日志页面，这是正向基础。但日志缺少结构化事件、错误分类和敏感字段脱敏；多个关键失败路径没有写入日志。

| Subtype | Count | Critical Signals Missing | Recommended Action |
|---------|-------|--------------------------|-------------------|
| Logging | 2 | 下载索引损坏、连接池重置失败 | 记录上下文和恢复动作 |
| Metrics | 1 | 下载分片并发/失败率 | 本地计数或诊断状态 |
| Tracing | 1 | 请求/下载关联 ID | 轻量 correlation ID |
| HealthCheck | 0 | 客户端不适用 | Not assessed |
| Alerting | 0 | 客户端不适用 | Not assessed |
| Runbook | 1 | 发布失败处理 | 文档补充 |
| Debuggability | 2 | 日志脱敏、错误分类 | 安全复制日志 |

## 15. Configuration Safety Analysis / 配置安全分析

- Coverage: Medium
- Inspected evidence: `storage_pref.dart`, `storage_key.dart`, 设置页面、`analysis_options.yaml`, `pubspec.yaml`
- Exclusions / limits: 未逐个设置项做类型和范围校验

配置通过 Hive 和 `Pref` getter 集中访问，但缺少 schema/version/range validation。特别是 TLS、WebDAV、导入设置、代理和缓存大小等高影响配置需要更强边界。

| Subtype | Count | Affected Keys / Files | Recommended Action |
|---------|-------|-----------------------|-------------------|
| SchemaValidation | 2 | setting/video import, Cookie fields | 导入前校验 |
| UnsafeDefault | 0 | 主要默认值未见高危 | 保持审查 |
| EnvironmentSeparation | 1 | CI/dev build flags | 明确 dev/release |
| SecretConfig | 2 | WebDAV password, account tokens | 迁移安全存储 |
| FeatureFlag | 1 | TLS bypass | 独立高危开关 |
| ConfigDocs | 2 | WebDAV/release | 补文档 |

## 16. Data Integrity Analysis / 数据完整性分析

- Coverage: Medium
- Inspected evidence: Hive import/export、WebDAV restore、下载 entry/index 写入、watch progress 删除
- Exclusions / limits: 未模拟断电或并发写入

数据完整性最主要问题是导入恢复的原子性。下载 entry 写入也缺少校验和损坏恢复提示，但目前证据更偏诊断缺口。

| Subtype | Count | Invariants at Risk | Recommended Action |
|---------|-------|-------------------|-------------------|
| TransactionBoundary | 1 | 设置导入要么全成功要么不改变 | 加事务/快照回滚 |
| Idempotency | 1 | WebDAV backup remove/write | 使用临时文件再 rename |
| ConcurrencyConsistency | 1 | 下载状态 | 保持 lock 并补测试 |
| MigrationSafety | 1 | 设置版本 | 添加版本迁移器 |
| InvariantValidation | 2 | Cookie 必需字段、setting schema | 加校验 |
| BackupRestore | 1 | WebDAV restore | dry-run + rollback |
| Reconciliation | 1 | 下载 entry 损坏 | 增加修复/提示 |

## 17. Privacy / Data Governance Analysis / 隐私治理分析

- Coverage: Medium
- Inspected evidence: 账号 Cookie、用户信息缓存、搜索历史、WebDAV、日志、README 功能
- Exclusions / limits: 未逐个模型字段建立 PII 清单

客户端处理用户账号、搜索历史、观看进度、下载记录、WebDAV 账号和日志。当前没有数据清单、保留策略或日志脱敏边界。隐私风险与安全风险重叠，优先处理本地凭据和日志。

| Subtype | Count | Affected Data | Recommended Action |
|---------|-------|---------------|-------------------|
| DataInventory | 1 | Cookie、历史、下载、日志 | 建立本地数据清单 |
| Minimization | 1 | 日志/错误复制 | 默认脱敏 |
| AccessBoundary | 1 | 本地凭据 | 安全存储 |
| Retention | 1 | `.pili_logs.json`, 搜索历史 | 增加清理/保留说明 |
| Deletion | 1 | logout 清理范围 | 覆盖安全存储和 WebView |
| Export | 1 | settings export | 排除敏感字段 |
| TelemetryPrivacy | 1 | crash report | redaction |

## 18. Accessibility / UX Correctness Analysis / 可访问性与 UX 正确性分析

- Coverage: Low
- Inspected evidence: Flutter 页面抽样、WebView/设置/日志页面、按钮/对话框用法
- Exclusions / limits: 未做键盘、读屏、动态字体、小屏实测

项目是 Flutter 客户端，理论上有可访问性要求。本次未发现可直接定级的可访问性 bug，但低覆盖下不能认为干净。后续应优先检查登录、设置、播放器控制、WebView 和下载列表的语义标签、焦点、触控尺寸和错误状态。

| Subtype | Count | Affected Workflows | Recommended Action |
|---------|-------|-------------------|-------------------|
| SemanticStructure | Not assessed | 登录/播放器 | 用 Flutter semantics 测试 |
| KeyboardFocus | Not assessed | 桌面端 WebView/设置 | 桌面键盘遍历 |
| ResponsiveVisual | Not assessed | 播放器/大屏/小屏 | 截图测试 |
| ErrorState | 1 | 设置恢复/登录 | 错误更明确 |
| LoadingState | 1 | 下载/WebDAV | 防重复操作 |
| UXStateCorrectness | 1 | 导入恢复 | dry-run 和回滚提示 |

## 19. Supply Chain / Reproducibility Analysis / 供应链分析

- Coverage: High
- Inspected evidence: `pubspec.yaml`, `pubspec.lock`, `.github/workflows/**`, `lib/scripts/patch.ps1`
- Exclusions / limits: 未查询漏洞库和 license 数据库

供应链风险较突出：依赖大量 fork，Git branch ref 多，workflow action 和工具下载未固定到不可变校验。lockfile 是正向控制，但 manifest 和 workflow 仍需收紧。

| Subtype | Count | Affected Surface | Recommended Action |
|---------|-------|------------------|-------------------|
| DependencyProvenance | 1 | Git branch deps | 改 SHA/tag |
| Reproducibility | 2 | Flutter SDK patch, build time/version | 固定工具链 |
| CIIntegrity | 1 | `permissions: write-all` | 最小权限 |
| ArtifactProvenance | 2 | release assets | checksum/sign/SBOM |
| RegistryHygiene | 1 | fork dependencies | 依赖审查策略 |

## 20. Cost / Resource Economics Analysis / 成本分析

- Coverage: Medium
- Inspected evidence: 下载弹幕、WebDAV、日志、缓存、外部 API 请求
- Exclusions / limits: 客户端项目，无服务端账单；未测真实流量

成本更多表现为用户设备资源、网络请求和远端 API 限流。离线下载的无界分片请求是最明确成本点。

| Subtype | Count | Cost Driver | Recommended Action |
|---------|-------|-------------|-------------------|
| UnboundedWork | 1 | gRPC 请求、内存 | 并发上限 |
| ExternalApiCost | 1 | Bilibili/WebDAV/GitHub | retry budget |
| LLMCost | Not assessed | 无自有 LLM | Not assessed |
| InfrastructureSizing | Not assessed | 客户端 | Not assessed |
| ObservabilityCost | 1 | 本地日志增长 | 保留策略 |
| CostVisibility | 1 | 下载任务 | 显示分片/失败统计 |

## 21. AI / LLM Safety Analysis / AI 安全分析

- Coverage: Not assessed
- Inspected evidence: `pubspec.yaml`、`lib/models_new/video/video_ai_conclusion/**`、全局 AI/LLM/RAG/prompt 搜索
- Exclusions / limits: 未发现自有 prompt、模型调用、RAG、agent 工具执行或 LLM 输出驱动动作

项目 README 提到 AI 原声翻译，源码也有 Bilibili AI 总结相关模型，但本次未发现应用自身构造 prompt、调用模型 API、执行工具或做 RAG 检索的边界。因此 AI safety 不作为本次评分维度的直接风险来源。

| Subtype | Count | Boundary Crossed | Recommended Action |
|---------|-------|------------------|-------------------|
| PromptInjection | Not assessed | 无自有 prompt | Not assessed |
| ToolAuthorization | Not assessed | 无模型工具 | Not assessed |
| RAGLeakage | Not assessed | 无 RAG | Not assessed |
| ModelFallback | Not assessed | 无模型 fallback | Not assessed |
| OutputValidation | Not assessed | 无模型输出决策 | Not assessed |
| EvalGap | Not assessed | 无 AI policy | Not assessed |
| AbuseCost | Not assessed | 无 LLM 成本 | Not assessed |

## 22. Fallback / Defensive Code Analysis / 兜底分析

- Coverage: Medium
- Inspected evidence: `catch (_)`, 默认值、错误返回、`try/catch` 搜索
- Exclusions / limits: 未逐个审查全部 302 个候选点

项目有大量合理的 UI 容错，但关键边界的 silent fallback 需要被收紧。尤其是账号、网络连接池、下载目录和 WebDAV 操作。

| Subtype | Count | KeepWithAlert | FailFast | Remove |
|---------|-------|---------------|----------|--------|
| SilentFallback | 4 | 2 | 2 | 0 |
| EmptyCatch | 3 | 1 | 2 | 0 |
| CompatibilityBranch | 2 | 2 | 0 | 0 |
| SilentCorrection | 1 | 1 | 0 | 0 |
| DefensiveGuess | 2 | 1 | 1 | 0 |

Key action: 对所有核心 catch 添加日志和状态，不要求每个 catch 都弹 toast。

## 23. Testing Authenticity Analysis / 测试真实性分析

- Coverage: High
- Inspected evidence: 测试目录、CI、测试关键字搜索
- Exclusions / limits: 无测试可抽样

### Confidence Assessment

| Test Area | Real Confidence | Risk | Action |
|-----------|-----------------|------|--------|
| Unit tests | None | 纯逻辑回归无法自动发现 | Add |
| Widget tests | None | 登录/设置/播放器 UI 回归依赖手测 | Add |
| Integration tests | None | WebView、下载、账号切换无端到端信心 | Add selectively |
| CI checks | Low | 只有 build/package，缺少 analyze/test | Add gates |

### Valuable Tests

当前未发现项目自有测试。

### Suspicious Tests

无测试，无法评估 over-mocking 或 brittle tests。

### Missing Tests

Cookie 解析、账号模式切换、WebDAV restore、设置导入、TLS/proxy 配置、下载分片调度、日志脱敏、release workflow lint。

## 24. Type Safety Analysis / 类型安全分析

- Coverage: Medium
- Inspected evidence: `!` 强制解包、dynamic/Map 搜索、账号模型、登录 controller、API response
- Exclusions / limits: analyzer 未完成，未逐个 dynamic 审查

类型系统被 dynamic JSON、强制解包和 late 字段削弱。最需要优先修的是外部输入边界：Cookie、API response、设置导入。

| Subtype | Count | Critical | High | Medium | Low |
|---------|-------|----------|------|--------|-----|
| UnsafeBlock | 0 | 0 | 0 | 0 | 0 |
| TypeAssertion | 1 | 0 | 0 | 1 | 0 |
| InputBoundary | 3 | 0 | 0 | 3 | 0 |
| OutputLeak | 1 | 0 | 0 | 1 | 0 |
| BooleanTrap | Not fully assessed | 0 | 0 | 0 | 0 |
| StringlyTyped | 2 | 0 | 0 | 2 | 0 |
| ErrorType | 1 | 0 | 0 | 1 | 0 |

## 25. Frontend State Analysis / 前端状态分析

- Coverage: Medium
- Inspected evidence: GetX controllers/views、播放器状态、下载服务、设置 UI、大文件 inventory
- Exclusions / limits: 未运行 UI race 测试或内存 profiling

项目使用 GetX 和全局 storage/service。局部状态很多但不是问题本身；问题在大页面/controller 同时承担状态、业务和 I/O，导致状态来源难以测试。

| Subtype | Count | Affected Components |
|---------|-------|---------------------|
| ComponentSize | 4 | video view, header control, player view, settings |
| StateDuplication | 1 | Accounts + CookieManager + Hive |
| PropDrilling | Not assessed | 未系统检查 |
| EffectChain | 1 | timers/request polling |
| UIBusinessCoupling | 3 | login, video, settings |
| DOMasState | 0 | Flutter 不适用 |
| RequestState | 2 | loading/toast patterns |
| RenderPerf | 1 | player/video large rebuild risk |

## 26. Backend API Analysis / 后端 API 分析

- Coverage: Not assessed
- Inspected evidence: 项目结构、HTTP client 文件
- Exclusions / limits: PiliPlus 没有自有后端服务、endpoint handler、数据库或 server-side auth

该维度对本项目不直接适用。报告中相关问题已转入客户端 API contract、Security、Stability、Type Safety 维度。

| Subtype | Count | Affected Endpoints |
|---------|-------|--------------------|
| ApiConsistency | Not assessed | 无自有 endpoint |
| Validation | Not assessed | 客户端输入边界另列 |
| Auth | Not assessed | 客户端账号边界另列 |
| NplusOne | Not assessed | 无数据库 |
| Caching | Not assessed | 客户端缓存另列 |
| ErrorResponse | Not assessed | 客户端错误模型另列 |
| BusinessLogic | Not assessed | 无服务端 |
| DataFlow | Not assessed | 无服务端 |

## 27. Dependency Weight Analysis / 依赖重量分析

- Coverage: Medium
- Inspected evidence: `pubspec.yaml`, `pubspec.lock`, 文件规模、生成代码和复制 Flutter widget
- Exclusions / limits: 未计算实际包体积、transitive count 和 license 冲突

依赖数量和 Git fork 很多，但项目功能也确实覆盖多媒体、WebView、下载、桌面、移动端和图像处理。当前不建议大规模移除依赖，优先治理 Git fork 的 provenance 和复制框架代码的维护策略。

### Dependency Scoreboard

| Dependency | Status | Weight | Transitives | Used For | Recommended Action |
|------------|--------|--------|-------------|----------|-------------------|
| `flutter_inappwebview` Git override | Heavy but used | High | Not measured | WebView/login | Keep, pin source |
| `media_kit` Git overrides | Heavy but core | High | Not measured | video playback | Keep, pin source |
| multiple UI forks | Risky | Medium | Not measured | patched behavior | AuditTransitives |
| `lib/common/widgets/flutter/**` copied code | Heavy local code | High | N/A | patched widgets | Document ownership |

## 28. Code Consistency Analysis / 代码一致性分析

- Coverage: Medium
- Inspected evidence: `analysis_options.yaml`, error handling patterns, storage access, imports, catch/default searches
- Exclusions / limits: `flutter analyze` 未完成，未做全量 lint diff

项目启用了不少 lint rule，这是正向基础。但错误处理、API response、存储写入和 catch 策略不一致。部分路径返回 `LoadingState`，部分返回 raw `Response` 或 dynamic map，UI 层也有直接解析外部 JSON 的模式。

| Subtype | Count | Evidence | Recommended Action |
|---------|-------|----------|-------------------|
| NamingConvention | 1 | `subtitleBgOpaticy` key typo | 迁移/兼容说明 |
| ImportOrganization | Not assessed | analyzer 未完成 | 依赖 lint |
| ErrorHandlingConsistency | 3 | raw Response, toast, silent catch | 统一 Result |
| PatternUniformity | 2 | storage/network in UI | service 边界 |
| FileStructure | 2 | large files | 分阶段拆分 |
| Boilerplate | 1 | repeated setting dialogs | 抽公共设置输入模型 |

## 29. Comment Coverage Analysis / 注释覆盖分析

- Coverage: Medium
- Inspected evidence: TODO/FIXME/HACK/ignore 搜索、README、脚本注释、复杂路径抽样
- Exclusions / limits: 未逐个 public API 检查 doc comment

注释问题不是“注释少”，而是高风险设计缺少维护说明。Flutter SDK patch、Git fork 依赖、Cookie 存储策略、WebView Cookie 注入和设置导入格式都需要更明确的 rationale 和操作文档。

| Subtype | Count | Evidence | Recommended Action |
|---------|-------|----------|-------------------|
| MissingDoc | 4 | Secret storage, settings schema, SDK patch, release | 补开发文档 |
| StaleComment | 1 | `pubspec.yaml` 默认描述 | 更新 |
| NoiseComment | Not material | 多数不影响风险 | 不优先 |
| MissingModuleDoc | 3 | account/download/request | 加模块说明 |
| PoorInlineComment | 1 | silent catch 无原因 | 注释或日志 |
| NotSelfDocumenting | 2 | large video/player modules | 拆分优先于加注释 |

---

## 30. Principles Compliance

项目遵循了一些有价值的工程原则：网络层有统一 Dio 单例，设置读访问集中在 `Pref`，账号模式有单一 `Accounts` 入口，跨平台构建流程有专门 workflow，依赖 lockfile 已提交。这些基础值得保留。

主要违例集中在高影响边界：Least Privilege 被本地明文凭据、宽 CI 权限、Cookie 注入 WebView 打破；Fail-Fast 被 Cookie 强制解包和设置导入破坏；SRP 和文件大小纪律在视频/播放器/设置模块上明显不足。

### Principles Violated

| Principle | Violations | Severity | Affected Areas |
|-----------|------------|----------|----------------|
| Single Responsibility (1.1) | 1 | Medium | 视频/播放器/设置 |
| File Size Limit (1.2) | 1 | Medium | 1000+ 行手写文件 |
| Fail-Fast (4.4) | 3 | Medium | Cookie、设置导入、API response |
| Least Privilege (4.6) | 3 | High | 凭据、CI、WebView |
| Don't Swallow Errors (6.1) | 1 | Medium | silent catch |
| Configuration Over Hardcoding (9.1) | 1 | High | TLS/代理策略 |
| Unbounded Resources (10.2) | 1 | Medium | 弹幕下载并发 |

### Principles Respected

集中网络入口、基础超时、lockfile、平台 workflow、Hive 存储入口、GetX service 注册、Android backup 禁用、`.gitignore` 覆盖签名材料。

---

## 31. Architecture Analysis

### Architecture Summary

| Subtype | Count | Affected Areas | Recommended Action |
|---------|-------|----------------|-------------------|
| ModuleBoundary | 3 | video/player/settings | 拆服务和纯函数 |
| DependencyDirection | 1 | UI -> storage/network | 引入 API client/domain service |
| StateOwnership | 2 | account/settings | 明确 source of truth |
| BoundaryContract | 3 | Cookie/settings/API JSON | schema/result |
| EvolutionRisk | 2 | SDK patch/Git deps | 固定版本和 ADR |

架构修复应从边界开始：SecretStore、SettingsImporter、DownloadScheduler、ApiClient parser。不要先做大规模目录重排。

## 32. Documentation Analysis

### Documentation Summary

| Subtype | Count | Affected Docs | Recommended Action |
|---------|-------|---------------|-------------------|
| UserDocs | 0 | README | 保持功能说明 |
| OperatorDocs | 2 | release/signing | 添加 runbook |
| DeveloperDocs | 2 | local setup/test | 添加 FVM/Flutter/analyze/test |
| ApiDocs | 1 | API error contract | 补客户端契约 |
| DecisionRecord | 2 | forks/patches | 添加 ADR |
| StaleDocs | 1 | pubspec description | 更新 |

## 33. Privacy / Data Governance Analysis

### Privacy Summary

| Subtype | Count | Affected Data | Recommended Action |
|---------|-------|---------------|-------------------|
| DataInventory | 1 | Cookie、历史、下载、日志 | 数据清单 |
| Minimization | 1 | 日志复制 | 脱敏 |
| AccessBoundary | 1 | 凭据 | 安全存储 |
| Retention | 1 | 日志/历史 | 保留策略 |
| Deletion | 1 | logout | 完整清理 |
| Export | 1 | settings export | 排除 secret |
| TelemetryPrivacy | 1 | crash report | redaction |

## 34. Accessibility / UX Correctness Analysis

### Accessibility Summary

| Subtype | Count | Affected Workflows | Recommended Action |
|---------|-------|-------------------|-------------------|
| SemanticStructure | Not assessed | 登录/设置/播放器 | 加 Semantics 测试 |
| KeyboardFocus | Not assessed | 桌面端 | 键盘巡检 |
| ResponsiveVisual | Not assessed | 移动/桌面 | 截图测试 |
| ErrorState | 1 | 登录/恢复 | 更明确错误 |
| LoadingState | 1 | 下载/WebDAV | 防重复操作 |
| UXStateCorrectness | 1 | restore | dry-run + rollback |

## 35. Supply Chain / Reproducibility Analysis

### Supply Chain Summary

| Subtype | Count | Affected Surface | Recommended Action |
|---------|-------|------------------|-------------------|
| DependencyProvenance | 1 | Git branch deps | pin SHA/tag |
| Reproducibility | 2 | SDK patch/build metadata | 固定工具链 |
| CIIntegrity | 1 | workflow token | 最小权限 |
| ArtifactProvenance | 2 | release assets | checksum/sign/SBOM |
| RegistryHygiene | 1 | fork deps | 依赖审查 |

## 36. Cost / Resource Economics Analysis

### Cost Summary

| Subtype | Count | Cost Driver | Recommended Action |
|---------|-------|-------------|-------------------|
| UnboundedWork | 1 | gRPC/内存 | 并发上限 |
| ExternalApiCost | 1 | Bilibili/WebDAV | retry budget |
| LLMCost | Not assessed | 无 | Not assessed |
| InfrastructureSizing | Not assessed | 客户端 | Not assessed |
| ObservabilityCost | 1 | 本地日志 | 保留策略 |
| CostVisibility | 1 | 下载任务 | 诊断状态 |

## 37. AI / LLM Safety Analysis

### AI Safety Summary

| Subtype | Count | Boundary Crossed | Recommended Action |
|---------|-------|------------------|-------------------|
| PromptInjection | Not assessed | 无自有 LLM | Not assessed |
| ToolAuthorization | Not assessed | 无模型工具 | Not assessed |
| RAGLeakage | Not assessed | 无 RAG | Not assessed |
| ModelFallback | Not assessed | 无模型 fallback | Not assessed |
| OutputValidation | Not assessed | 无模型输出决策 | Not assessed |
| EvalGap | Not assessed | 无 AI eval 需求 | Not assessed |
| AbuseCost | Not assessed | 无 LLM 成本 | Not assessed |

## 38. Observability / Operability Analysis

### Signal Summary

| Subtype | Count | Critical Signals Missing | Recommended Action |
|---------|-------|--------------------------|-------------------|
| Logging | 2 | 下载索引、连接池 | 结构化日志 |
| Metrics | 1 | 下载分片/失败率 | 本地诊断 |
| Tracing | 1 | 请求关联 | correlation id |
| HealthCheck | Not assessed | 客户端 | Not assessed |
| Alerting | Not assessed | 客户端 | Not assessed |
| Runbook | 1 | release | 文档 |
| Debuggability | 2 | 日志脱敏/分类 | 安全复制 |

## 39. Configuration Safety Analysis

### Configuration Summary

| Subtype | Count | Affected Keys / Files | Recommended Action |
|---------|-------|-----------------------|-------------------|
| SchemaValidation | 2 | setting/video/Cookie | schema |
| UnsafeDefault | 0 | 未见高危默认 | 保持审查 |
| EnvironmentSeparation | 1 | dev/release | 文档 |
| SecretConfig | 2 | account/WebDAV | SecretStore |
| FeatureFlag | 1 | TLS bypass | 高危开关隔离 |
| ConfigDocs | 2 | WebDAV/release | 补文档 |

## 40. Data Integrity Analysis

### Integrity Summary

| Subtype | Count | Invariants at Risk | Recommended Action |
|---------|-------|-------------------|-------------------|
| TransactionBoundary | 1 | 设置导入原子性 | 快照回滚 |
| Idempotency | 1 | WebDAV backup | temp + rename |
| ConcurrencyConsistency | 1 | 下载状态 | 测试 lock |
| MigrationSafety | 1 | 设置版本 | migrator |
| InvariantValidation | 2 | Cookie/schema | validate |
| BackupRestore | 1 | WebDAV restore | dry-run |
| Reconciliation | 1 | 下载 entry | 修复提示 |

## 41. Fallback / Defensive Code Analysis

### Fallback Summary

| Subtype | Count | KeepWithAlert | FailFast | Remove |
|---------|-------|---------------|----------|--------|
| SilentFallback | 4 | 2 | 2 | 0 |
| EmptyCatch | 3 | 1 | 2 | 0 |
| CompatibilityBranch | 2 | 2 | 0 | 0 |
| SilentCorrection | 1 | 1 | 0 | 0 |
| DefensiveGuess | 2 | 1 | 1 | 0 |

## 42. Type Safety Analysis

### Summary

| Subtype | Count | Critical | High | Medium | Low |
|---------|-------|----------|------|--------|-----|
| UnsafeBlock | 0 | 0 | 0 | 0 | 0 |
| TypeAssertion | 1 | 0 | 0 | 1 | 0 |
| InputBoundary | 3 | 0 | 0 | 3 | 0 |
| OutputLeak | 1 | 0 | 0 | 1 | 0 |
| BooleanTrap | Not fully assessed | 0 | 0 | 0 | 0 |
| StringlyTyped | 2 | 0 | 0 | 2 | 0 |
| ErrorType | 1 | 0 | 0 | 1 | 0 |

## 43. Frontend State Analysis

### Summary

| Subtype | Count | Affected Components |
|---------|-------|-------------------|
| ComponentSize | 4 | video/player/settings |
| StateDuplication | 1 | Accounts/CookieManager/Hive |
| PropDrilling | Not assessed | 未系统检查 |
| EffectChain | 1 | timers/polling |
| UIBusinessCoupling | 3 | login/video/settings |
| DOMasState | 0 | Flutter 不适用 |
| RequestState | 2 | loading/toast |
| RenderPerf | 1 | player/video |

## 44. Backend API Analysis

### Summary

| Subtype | Count | Affected Endpoints |
|---------|-------|-------------------|
| ApiConsistency | Not assessed | 无自有后端 |
| Validation | Not assessed | 客户端 API parser 另列 |
| Auth | Not assessed | 客户端账号另列 |
| NplusOne | Not assessed | 无数据库 |
| Caching | Not assessed | 客户端缓存另列 |
| ErrorResponse | Not assessed | 客户端错误模型另列 |
| BusinessLogic | Not assessed | 无服务端 |
| DataFlow | Not assessed | 无服务端 |

## 45. Dependency Weight Analysis

### Dependency Scoreboard

| Dependency | Status | Weight | Transitives | Used For | Recommended Action |
|------------|--------|--------|-------------|----------|-------------------|
| `flutter_inappwebview` fork | Heavy but used | High | Not measured | WebView | Keep, pin |
| `media_kit` fork set | Heavy but core | High | Not measured | playback | Keep, pin |
| `webdav_client` Git | Used | Medium | Not measured | backup | Pin |
| copied Flutter widgets | Heavy local | High | N/A | patched UI | Document owner |

## 46. Code Consistency Analysis

| Subtype | Count | Affected Pattern | Recommended Action |
|---------|-------|------------------|-------------------|
| NamingConvention | 1 | setting key typo | migrate |
| ImportOrganization | Not assessed | analyzer timeout | rerun with 3.44.4 |
| ErrorHandlingConsistency | 3 | raw Response/toast/silent catch | Result |
| PatternUniformity | 2 | storage/network in UI | service |
| FileStructure | 2 | large files | split |
| Boilerplate | 1 | setting dialogs | extract model |

## 47. Comment Coverage Analysis

| Subtype | Count | Affected Area | Recommended Action |
|---------|-------|---------------|-------------------|
| MissingDoc | 4 | secrets/import/patch/release | module docs |
| StaleComment | 1 | pubspec description | update |
| NoiseComment | Not material | comments | no action |
| MissingModuleDoc | 3 | account/download/request | add overview |
| PoorInlineComment | 1 | silent catch | explain/log |
| NotSelfDocumenting | 2 | large modules | split |

---

## 48. Recommended Fix Order

### Fix Immediately

1. Stop storing account/WebDAV secrets in plain Hive; introduce a platform `SecretStore` and exclude secrets from settings export.
2. Remove automatic TLS bypass from proxy mode; keep bad-certificate behavior behind an explicit, audited switch.
3. Reduce GitHub Actions permissions from `write-all`; pin high-risk actions/tools and add checksums for downloaded release tools.
4. Move `piliplus-release.jks` out of the repository working tree and add a local/CI secret scan.

### Fix Before Stable Release

1. Add `flutter analyze` and `flutter test` CI gates with the correct Flutter 3.44.4 toolchain.
2. Add tests for Cookie parsing, settings import rollback, TLS/proxy config, WebDAV restore and download segment scheduling.
3. Make settings import/restore validate schema before clearing current data.
4. Limit download danmaku concurrency and persist per-segment progress.
5. Disable mixed content in normal WebView flows.

### Schedule Later

1. Split video/player/settings large files along service/state/view boundaries.
2. Replace dynamic API response access with typed parsers and structured errors.
3. Document Flutter SDK patch ownership and reduce toolchain mutation.
4. Add log redaction and safe issue-report export.

### Ignore for Now

No need for a full rewrite, server-style health checks, enterprise telemetry stack, or broad dependency replacement before the higher-risk release blockers are addressed.

## 49. Quick Wins

| Quick win | Value | Effort |
|-----------|-------|--------|
| Change proxy mode to keep certificate validation enabled | Removes high-risk MITM path | 1-2 hours |
| Add workflow permission lint and replace `write-all` | Reduces CI blast radius | 1-2 hours |
| Add Cookie required-field validation before `LoginAccount` | Prevents common login crash | 2-4 hours |
| Add schema dry-run for settings import | Prevents settings loss | 2-4 hours |
| Add log redaction helper and use it in copy logs | Prevents accidental issue leakage | 2-4 hours |
| Add CI `flutter analyze` with pinned 3.44.4 | Immediate quality gate | 1-3 hours after toolchain setup |
| Cap danmaku segment concurrency | Prevents burst request/load failures | 0.5-1 day |

## 50. Long-term Refactor Plan

1. Secret boundary: introduce `SecretStore`, migrate account/WebDAV secrets, add export redaction and logout cleanup tests. Risk is migration data loss; test with old/new Hive fixtures.
2. API boundary: create typed API clients for login, settings backup, download URL, danmaku and user info. Risk is behavior drift; test with captured/fake responses.
3. Download scheduler: replace direct `Future.wait` with bounded queue and persisted segment progress. Risk is queue state bugs; test pause/resume/failure.
4. UI module split: start with `pl_player` and `pages/video`, extracting pure state and command services before changing layout. Risk is high because player is central; protect with controller tests and smoke tests.
5. Release hardening: pin dependencies/tools, add SBOM/checksums/signing, separate PR and release permissions. Risk is CI friction; roll out as warnings first, then blocking checks.
