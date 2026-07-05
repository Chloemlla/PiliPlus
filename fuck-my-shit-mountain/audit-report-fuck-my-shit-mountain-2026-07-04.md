# Fuck My Shit Mountain Audit Report

**Project:** fuck-my-shit-mountain  
**Audit mode:** full  
**Date:** 2026-07-04  
**Reviewer:** Codex GPT-5

---

## 1. Executive Summary

本项目是一个面向 AI 代码审计的 skill 包，核心资产是 `SKILL.md`、25 个专项审计 prompt、共享报告模板、评分/证据 rubrics、一个 Markdown/HTML 报告 linter 和一个 zip 打包脚本。整体结构清晰，依赖面很小，审计规则覆盖面很宽，适合作为可维护的提示词工具继续演进。

主要风险集中在“报告生成契约”和“验证工具”之间的不一致：skill 支持中文报告，但 `report_lint.py` 只识别英文 Markdown 标题和英文字段；full 模式要求全部 25 个维度，但 Markdown/HTML 模板对后几个维度的结构支持不完整；linter 对占位符、HTML 完整性和敏感值的检测也偏窄。这些问题不会直接造成运行时崩溃，但会让生成报告在发布前看似通过校验，实际缺章节、残留模板内容或无法支持本地化。

发布成熟度目前偏弱。仓库内没有可见测试、CI workflow、工具链版本声明或 release 产物校验；`package_skill.py` 会打包所有未排除文件，在 self-audit 场景下容易把生成的 `audit-report-*.md/html` 一起带进发布包。建议优先补齐 linter 覆盖、模板一致性和 CI 中的报告 fixture 测试。

### Score Dashboard

```
Security        ███████░░░  7.2  A   敏感信息处理规则明确，但 linter 只能识别少量 secret 形态，覆盖为 Medium。
Stability       ███████░░░  7.0  A   脚本逻辑短小直接，但 lint 误放行会影响报告可靠性，覆盖为 High。
Performance     █████████░  8.5  A   无重依赖或明显热路径，主要成本来自 full 模式人工/模型扫描，覆盖为 Medium。
Testing         ████░░░░░░  3.5  C   没有可见测试/CI，且 linter 本身缺少本地化和模板残留 fixture。
Maintainability ██████░░░░  6.4  B   文档和模板分层清楚，但多处维度清单重复后出现不一致。
Design          ██████░░░░  6.0  B   证据驱动设计方向正确，但输出语言、模板和校验契约未形成单一来源。
Release         █████░░░░░  4.8  C   打包、校验和发布流程缺少 CI、版本/产物完整性和 generated 文件防护。
─────────────────────────────────────
Overall         ██████░░░░  6.2  B
```

Each dimension scored 0.0-10.0. Higher = better. Scores are judgment-based, not formula-based. See `rubrics/scoring.md` for anchor descriptions.

### Finding Statistics

| Severity | Count | Confirmed | Suspected |
|----------|-------|-----------|-----------|
| Critical | 0 | 0 | 0 |
| High | 0 | 0 | 0 |
| Medium | 6 | 5 | 1 |
| Low | 2 | 2 | 0 |
| Info | 0 | 0 | 0 |
| **Total** | **8** | **7** | **1** |

## 2. Project Map

项目由 45 个文件组成，没有依赖目录、构建产物目录或二进制资产。主要入口是 `SKILL.md`，它定义输入收集、资源加载、覆盖策略、敏感信息处理、输出文件规则和最终自检。`prompts/` 下包含 `full` 及各专项审计模式；`references/report-format.md` 统一报告结构和 lint 要求；`rubrics/` 提供严重程度、置信度、证据、覆盖率、评分和设计原则标准；`templates/` 提供 Markdown/HTML 报告、issue card 和 remediation plan 模板；`scripts/report_lint.py` 校验生成报告；`scripts/package_skill.py` 负责 zip 打包；`agents/openai.yaml` 提供 UI metadata；`examples/` 提供项目类型示例。

数据流是：用户给出审计模式、报告语言和输出格式；AI 按 `SKILL.md` 加载 prompt、rubric 和模板；AI 扫描目标项目并生成报告；文件输出模式下运行 `scripts/report_lint.py`；如需分发 skill，维护者运行 `scripts/package_skill.py` 生成 zip。项目本身没有持久化层、后端 API、前端状态管理或运行时服务。主要安全边界是报告中可能出现的敏感信息，以及打包脚本是否会把本地生成文件带入发布包。

覆盖说明：本次使用 UTF-8 方式读取了全部 45 个文件，并使用 `rg --files -uu`、`Get-ChildItem -Recurse -File`、`Select-String` 和 `rg -n` 做了文件清单、模板/脚本行号、占位符、secret、CI/test、full 维度一致性等静态检查。未运行项目 build/test；本项目也没有可见 build/test 配置。目标目录及其直接父级不是 Git 仓库，未发现可读取的仓库级 CI workflow。

### Coverage Matrix

| Dimension | Coverage | Evidence inspected | Exclusions / limits |
|-----------|----------|--------------------|---------------------|
| Architecture | High | `SKILL.md`, `prompts/`, `references/`, `rubrics/`, `templates/`, `scripts/`, file inventory | 没有运行时插件宿主行为可执行验证 |
| Security | Medium | secret handling rules, `scripts/report_lint.py`, examples, templates | 未做真实 secret corpus fuzzing |
| Stability | High | `report_lint.py`, `package_skill.py`, fallback/error search | 未执行长时间或异常环境运行 |
| Performance | Medium | file sizes, dependency inventory, scripts | 未做 benchmark；项目规模较小 |
| Testing | High | file inventory, script entry points, README lint docs | 未运行测试；仓库内未发现测试 |
| Maintainability | High | all Markdown prompts/templates/rubrics, scripts | 只做静态检查 |
| Design | High | principles rubric, template/prompt contract, linter behavior | 未观察真实多模型生成表现 |
| Release | Medium | README packaging docs, `package_skill.py`, generated file rules | 未检查远端仓库 CI/release 设置 |
| Documentation | High | README, SKILL, references, templates, examples | 未对外部 marketplace 文档验证 |
| Configuration | High | `agents/openai.yaml`, README install paths, CLI args | 无运行时配置文件 |
| Observability | Not assessed | 项目无服务、job、metrics/logging runtime | 不适用 |
| Data Integrity | Not assessed | 项目无数据库、迁移、队列、持久状态 | 不适用 |
| Privacy | Medium | sensitive reporting rules and secret lint regex | 无真实 PII 数据流可验证 |
| Accessibility | Medium | `templates/audit-report.html` static structure | 未用浏览器/a11y tree 执行检查 |
| Supply Chain | Medium | `package_skill.py`, README packaging docs, file inventory | 无 CI/release provenance 可检查 |
| Cost | Not assessed | 项目无外部 API/model calling code | 模型 token 成本取决于宿主 AI，不在代码中 |
| AI Safety | Medium | prompt boundaries, skill resource-loading rules, report rules | 未做 prompt injection eval corpus |
| Fallback | High | fallback/default/error search across all files | 无运行时 fallback 可触发 |
| Testing Authenticity | High | absence of tests/CI, linter behavior | 未运行测试 |
| Type Safety | Medium | Python type hints, linter parsing logic | 无 mypy/pyright 配置或执行 |
| Frontend State | Not assessed | HTML 模板不是前端应用状态系统 | 不适用 |
| Backend API | Not assessed | 无 API handlers/endpoints | 不适用 |
| Dependency Weight | High | no dependency manifest; stdlib-only Python scripts | 无 lockfile 或 dependency tree 可审计 |
| Code Consistency | High | prompt/template naming, mode IDs, linter section IDs | 未运行格式化/lint |
| Comment Coverage | High | README/SKILL/comments/templates/scripts | 未检查 Git 历史中的 stale comments |

## 3. Top Risks

| # | Finding | Severity | Status | Summary |
|---|---------|----------|--------|---------|
| 1 | Chinese Markdown reports are not first-class in `report_lint.py` | Medium | Confirmed | Skill supports Chinese reports, but Markdown lint only recognizes English section names, finding headings, field labels, and severity table keys. |
| 2 | Placeholder lint misses most Markdown angle placeholders | Medium | Confirmed | The linter checks a narrow allowlist while the Markdown templates contain many other `<...>` placeholders. |
| 3 | Markdown full template omits Code Consistency and Comment Coverage sections | Medium | Confirmed | Full mode and linter require these sections, but the Markdown template stops its dedicated analysis blocks at Dependency Weight. |
| 4 | HTML template full-mode navigation and applicability rules conflict | Medium | Confirmed | The sidebar omits several full-mode dimension links, and the template says both to skip and not skip inapplicable dimensions. |
| 5 | No visible tests or CI protect executable scripts and templates | Medium | Confirmed | The repository contains executable Python logic and report contracts but no tests/workflows in the scanned tree. |
| 6 | Secret lint likely misses common raw token formats | Medium | Suspected | The regex only detects private key headers and key-name assignments, not raw provider tokens in prose/code blocks. |
| 7 | Packaging can include generated audit reports | Low | Confirmed | Reports are written to the audited project root, and the package script excludes `dist/` but not `audit-report-*` files. |
| 8 | Public report template conflicts with the professionalism rule | Low | Confirmed | The skill says generated output must be calm and professional, while scoring/template text includes emotional/profane grading labels. |

## 4. Detailed Findings

### Finding: Chinese Markdown reports are not first-class in `report_lint.py`

- Severity: Medium
- Confidence: High
- Category: Testing
- Status: Confirmed
- Affected area: Markdown report validation and localization
- Evidence:
  - File: `SKILL.md:22`, `README.md:20`, `README.md:61`, `scripts/report_lint.py:66-107`, `scripts/report_lint.py:190-240`
  - Function / Module: `lint_mode_sections`, `lint_markdown_findings`, `lint_markdown_stats`
  - Relevant behavior: The skill accepts Chinese as report language, but Markdown lint searches English section patterns such as `Architecture`, `Security`, `Testing Authenticity`; finding chunks must start with `### Finding:`; required fields must be `- Severity:`, `- Confidence:`, etc.; severity statistics are counted from English severity rows.
- Problem: A fully localized Chinese Markdown report can fail lint even if it is structurally complete. The opposite workaround is to keep English skeleton labels in a Chinese report, which weakens the requested report language contract.
- Why it matters: The required quality gate becomes unreliable for non-English users and can force agents into inconsistent bilingual output.
- Realistic failure scenario: A user requests `full, Chinese, md`; the generated report uses `## 安全问题` and `### 发现:` with Chinese field names; `report_lint.py --modes full` flags missing selected dimension sections and missing finding fields, blocking delivery or causing manual bypass.
- Minimal fix: Add localized aliases for section patterns, finding headings, required fields, and severity/stat labels, or define the template contract as bilingual and document that labels must remain English.
- Better long-term fix: Parse reports from a structured intermediate representation, then render localized Markdown/HTML from the same model and validate the structured data before rendering.
- Regression test suggestion: Add Chinese Markdown fixture reports for `full` and one focused mode; assert `report_lint.py --modes full` passes with Chinese headings and field labels.
- Estimated effort: 0.5-1 day

### Finding: Placeholder lint misses most Markdown angle placeholders

- Severity: Medium
- Confidence: High
- Category: Testing
- Status: Confirmed
- Affected area: Report completeness validation
- Evidence:
  - File: `scripts/report_lint.py:110-116`, `templates/audit-report.md:14`, `templates/audit-report.md:45-60`, `templates/audit-report.md:124`, `templates/remediation-plan.md:3-54`
  - Function / Module: `PLACEHOLDER_PATTERNS`, `lint_placeholders`
  - Relevant behavior: The linter only matches double-square-bracket placeholders and a short allowlist of angle placeholders such as project-name, date, count, and short-title tokens, while templates contain many other instructional angle placeholders.
- Problem: A generated Markdown report can retain template instructions or placeholder prose and still pass placeholder lint.
- Why it matters: The required lint gate is supposed to prevent incomplete deliverables. If it misses common template remnants, users may receive reports that look complete at a glance but still contain scaffolding.
- Realistic failure scenario: An agent fills scores and findings but leaves `<Principles that the codebase follows well - what is being done right>` in the report. The current placeholder regex does not necessarily catch that text, so the report can pass lint while shipping unfinished content.
- Minimal fix: Treat any remaining angle-bracket placeholder from known templates as a failure, with an allowlist for real HTML tags only when linting HTML.
- Better long-term fix: Move templates to one explicit placeholder syntax and ban instructional angle placeholders from Markdown templates.
- Regression test suggestion: Add failing fixtures containing representative leftover placeholders from `templates/audit-report.md` and `templates/remediation-plan.md`; assert lint fails with the placeholder text named.
- Estimated effort: 2-4 hours

### Finding: Markdown full template omits Code Consistency and Comment Coverage sections

- Severity: Medium
- Confidence: High
- Category: Maintainability
- Status: Confirmed
- Affected area: Markdown full report template
- Evidence:
  - File: `prompts/full-audit.md:54-55`, `prompts/full-audit.md:100`, `scripts/report_lint.py:57-58`, `scripts/report_lint.py:90-91`, `templates/audit-report.md:6`, `templates/audit-report.md:73-106`, `templates/audit-report.md:409`
  - Function / Module: Markdown report template and full-mode section contract
  - Relevant behavior: Full mode explicitly includes Code Consistency and Comment Coverage and the linter expects Markdown headings for both. The Markdown template mentions these modes in the audit-mode list, but its dedicated analysis blocks stop at `Dependency Weight Analysis`; there are no explicit Code Consistency or Comment Coverage analysis sections.
- Problem: The template and linter disagree about required full-mode output.
- Why it matters: Agents following the Markdown template can omit two full-mode dimensions, then fail lint or deliver incomplete coverage. Agents following the linter must invent sections not modeled in the template.
- Realistic failure scenario: A full Markdown report generated from `templates/audit-report.md` includes sections through Dependency Weight only. `report_lint.py --modes full` then reports missing `code-consistency` and `comment-coverage` sections.
- Minimal fix: Add Code Consistency Analysis and Comment Coverage Analysis blocks to `templates/audit-report.md`, mirroring the specialized prompt formats.
- Better long-term fix: Generate the section list from one shared mode registry used by `SKILL.md`, `full-audit.md`, templates, and `report_lint.py`.
- Regression test suggestion: Add a template completeness test that extracts full-mode section IDs from `report_lint.py` and asserts every ID appears in both Markdown and HTML template guidance.
- Estimated effort: 2-4 hours

### Finding: HTML template full-mode navigation and applicability rules conflict

- Severity: Medium
- Confidence: High
- Category: Maintainability
- Status: Confirmed
- Affected area: HTML report template
- Evidence:
  - File: `templates/audit-report.html:153-184`, `templates/audit-report.html:534-535`, `templates/audit-report.html:619-625`, `references/report-format.md:26`, `prompts/full-audit.md:100`
  - Function / Module: HTML sidebar and per-dimension section guidance
  - Relevant behavior: The HTML template comment lists full-mode dimensions through Comment Coverage, but the actual sidebar links stop at AI Safety before Principles/Fix Order. The same template says inapplicable dimensions should be skipped entirely, while later guidance says full mode must not skip any dimension and shared rules say inapplicable full-mode dimensions should be marked Not assessed.
- Problem: The HTML template gives contradictory instructions and an incomplete navigation skeleton for full mode.
- Why it matters: HTML reports can omit navigation for selected sections or skip required Not assessed sections, reducing coverage honesty and making the generated page harder to review.
- Realistic failure scenario: A pure prompt-tool project has no Backend API or Frontend State. One agent follows line 535 and skips those sections; another follows line 625 and includes them as Not assessed. Both behaviors are plausible from the same template.
- Minimal fix: Add sidebar links for all full-mode dimensions and change the skip guidance to "mark Not assessed with evidence" for full mode.
- Better long-term fix: Generate HTML navigation and section stubs from the same selected-mode registry used by the linter instead of embedding hand-maintained lists.
- Regression test suggestion: Add an HTML fixture for `full` and assert the nav and body contain all 25 dimension IDs plus `principles`, `top-risks`, `fix-order`, and quick wins.
- Estimated effort: 0.5 day

### Finding: No visible tests or CI protect executable scripts and templates

- Severity: Medium
- Confidence: High
- Category: Testing
- Status: Confirmed
- Affected area: `scripts/report_lint.py`, `scripts/package_skill.py`, report templates
- Evidence:
  - File: `scripts/report_lint.py:1-285`, `scripts/package_skill.py:1-76`, `README.md:115-122`
  - Function / Module: repository test and release validation surface
  - Relevant behavior: The repository includes executable Python validation and packaging logic and documents report linting, but the scanned file inventory contains no `tests/`, `.github/workflows/`, `pyproject.toml`, `pytest.ini`, `tox.ini`, or test files.
- Problem: The most important behavior of the skill is template correctness and report validation, yet there are no visible automated checks for the linter, templates, packaging exclusions, or localized output.
- Why it matters: Template and linter drift is already present. Without tests, future prompt/template edits can silently break full-mode coverage or localization.
- Realistic failure scenario: A maintainer updates `full-audit.md` with a new dimension but forgets to update `report_lint.py` and the templates. The package still ships because there is no CI fixture catching the mismatch.
- Minimal fix: Add pytest fixtures for Markdown/HTML lint success and failure cases, plus a packaging dry-run assertion for excluded files.
- Better long-term fix: Add a GitHub Actions workflow that runs the unit tests, report fixture lint, and package dry-run on every PR.
- Regression test suggestion: Create fixtures for full English MD, full Chinese MD, focused mode MD, full HTML, placeholder failure, secret failure, and missing-section failure.
- Estimated effort: 1-2 days

### Finding: Secret lint likely misses common raw token formats

- Severity: Medium
- Confidence: Medium
- Category: Security
- Status: Suspected
- Affected area: Sensitive information handling in generated reports
- Evidence:
  - File: `SKILL.md:86-90`, `SKILL.md:150`, `SKILL.md:165`, `scripts/report_lint.py:118-122`
  - Function / Module: `SECRET_PATTERNS`, `lint_secrets`
  - Relevant behavior: The skill forbids exposing secrets in reports. The linter detects private key headers and key-name assignments containing words like `api_key`, `token`, `secret`, or `password`, but it does not explicitly match common raw tokens without a nearby key name.
- Problem: Reports often quote code blocks, logs, or `.env` snippets. A raw provider token in prose or a code block can be sensitive even when it is not written as `secret = value`.
- Why it matters: The skill's sensitive information promise relies partly on lint. Narrow detection increases the chance that an unredacted token survives into the final report.
- Realistic failure scenario: An audit quotes a line containing a raw provider token from a config file without the variable name on the same line. The current secret patterns may not flag it, and the report is delivered with sensitive material intact.
- Minimal fix: Add explicit patterns for common token families and high-entropy strings in code blocks, with false-positive suppression for documented fake examples.
- Better long-term fix: Run secret scanning on extracted evidence before rendering and require redaction metadata for every sensitive finding.
- Regression test suggestion: Add lint fixtures containing raw token-like strings, private key blocks, fake examples, and redacted values; assert only the real unredacted cases fail.
- Estimated effort: 0.5-1 day

### Finding: Packaging can include generated audit reports

- Severity: Low
- Confidence: High
- Category: Release
- Status: Confirmed
- Affected area: Skill distribution package contents
- Evidence:
  - File: `SKILL.md:24-25`, `scripts/package_skill.py:13-24`, `scripts/package_skill.py:60-69`
  - Function / Module: `DEFAULT_EXCLUDES`, `iter_package_files`, `main`
  - Relevant behavior: The skill writes Markdown/HTML reports using the `audit-report-PROJECT-DATE.*` naming pattern in the audited project. The package script excludes README, `.git`, caches, and `dist/`, then writes every remaining file into the zip. It does not exclude generated audit reports.
- Problem: When the skill audits itself or when generated reports are left in the skill directory, those reports are eligible for distribution.
- Why it matters: Audit reports can contain internal paths, vulnerability details, or redacted-sensitive metadata. Shipping them inside a skill package is unnecessary release noise and may leak operational context.
- Realistic failure scenario: A maintainer runs a self-audit, keeps `audit-report-fuck-my-shit-mountain-2026-07-04.md` in the skill root, then runs `package_skill.py`; the generated report is included in the zip.
- Minimal fix: Add `audit-report-*.md`, `audit-report-*.html`, and any generated report output directory to `DEFAULT_EXCLUDES`.
- Better long-term fix: Package from an explicit manifest of runtime-required files instead of "all files except excludes".
- Regression test suggestion: Create a temporary skill dir with `audit-report-demo.md`; assert package dry-run excludes it.
- Estimated effort: 15-30 minutes

### Finding: Public report template conflicts with the professionalism rule

- Severity: Low
- Confidence: High
- Category: Documentation
- Status: Confirmed
- Affected area: Scoring rubric and report template wording
- Evidence:
  - File: `SKILL.md:10`, `SKILL.md:128`, `README.md:155-160`, `rubrics/scoring.md:14`, `rubrics/scoring.md:63`, `rubrics/scoring.md:87`, `rubrics/scoring.md:128`, `templates/audit-report.md:30`
  - Function / Module: scoring rubric and generated report copy
  - Relevant behavior: The skill says output must be calm, professional, and free of emotional language. The scoring rubric and Markdown report template include emotional/profane grading labels for the lowest score.
- Problem: The public-facing output rules and the public-facing report copy do not align.
- Why it matters: Users can request a professional audit report, but the template may embed wording that is unsuitable for customer, executive, or compliance-facing delivery.
- Realistic failure scenario: A generated report is shared with stakeholders and includes the template's lowest-score label. The report appears less neutral even when the findings are technically sound.
- Minimal fix: Replace public report labels with neutral wording such as "unacceptable", "critical debt", or "not release-ready"; keep the skill name only in internal metadata if desired.
- Better long-term fix: Separate brand/internal phrasing from generated report phrasing and add a style check that rejects emotional terms in report outputs.
- Regression test suggestion: Add a lint rule or fixture that fails if generated reports contain banned non-professional labels outside the project name.
- Estimated effort: 30-60 minutes

## 5. Architecture Concerns（架构关注点）

- Coverage: High
- Inspected evidence: `SKILL.md`, `prompts/`, `references/`, `rubrics/`, `templates/`, `scripts/`, `agents/`, `examples/`
- Exclusions / limits: 未执行宿主 agent 的真实 skill loading 流程

结构清晰：入口、prompt、rubric、template、script 分层明确。主要架构风险是 mode/section 清单分散维护，导致 full 模式在 prompt、Markdown template、HTML template 和 linter 之间出现漂移。相关发现：Finding 3、Finding 4。

## 6. Security Concerns（安全关注点）

- Coverage: Medium
- Inspected evidence: sensitive info rules, secret regex, examples and templates
- Exclusions / limits: 未运行 secret corpus fuzzing，未扫描外部历史提交

没有发现真实密钥。规则层面对敏感信息有明确约束，但 `report_lint.py` 的检测范围偏窄。相关发现：Finding 6。

## 7. Stability Concerns（稳定性关注点）

- Coverage: High
- Inspected evidence: `scripts/report_lint.py`, `scripts/package_skill.py`, fallback/default/error searches
- Exclusions / limits: 未进行异常文件系统或多平台执行验证

脚本控制流短小，没有明显 panic/未处理异常路径。主要稳定性问题是校验器可能放行残缺报告，让质量门失效。相关发现：Finding 1、Finding 2。

## 8. Performance Concerns（性能关注点）

- Coverage: Medium
- Inspected evidence: file inventory, script loops, dependency surface, template sizes
- Exclusions / limits: 未执行 benchmark；AI full scan 的 token/时间成本不在代码中控制

Python 脚本只遍历文件和文本，项目无重依赖，性能风险低。`templates/audit-report.html` 较大但属于模板资产，不是运行时热路径。

## 9. Testing Gaps（测试缺口）

- Coverage: High
- Inspected evidence: file inventory, README lint instructions, linter functions
- Exclusions / limits: 未运行测试；仓库内未发现测试可运行

测试是当前最弱维度。没有 fixture 覆盖 full 模式、中文报告、HTML 完整性、占位符残留、secret 扫描和 package dry-run。相关发现：Finding 1、Finding 2、Finding 5、Finding 6。

## 10. Maintainability Concerns（可维护性关注点）

- Coverage: High
- Inspected evidence: all prompts/templates/rubrics/scripts
- Exclusions / limits: 未检查长期提交历史

文档分层总体可读，但 full 维度清单在多个文件重复维护，已经产生不一致。相关发现：Finding 3、Finding 4。

## 11. Design / Principles Concerns（设计原则关注点）

- Coverage: High
- Inspected evidence: `rubrics/principles.md`, template contracts, linter contracts
- Exclusions / limits: 未观察真实用户生成样本

核心设计原则是证据驱动和结构化输出，这是正确方向。风险来自单一来源缺失：同一报告契约散落在 skill、prompt、template 和 linter 中。相关发现：Finding 1、Finding 3、Finding 4、Finding 8。

## 12. Release Concerns（发布关注点）

- Coverage: Medium
- Inspected evidence: README packaging docs, `package_skill.py`, generated output naming, file inventory
- Exclusions / limits: 目标目录及直接父级不是 Git 仓库，无法检查远端 release workflow

发布流程当前主要靠手工命令和排除列表。缺少 CI、版本声明、产物校验和 generated 文件防护。相关发现：Finding 5、Finding 7。

## 13. Documentation Analysis（文档分析）

- Coverage: High
- Inspected evidence: README, SKILL, report-format reference, templates, examples
- Exclusions / limits: 未验证外部安装平台实际行为

README 和 SKILL 覆盖安装、模式、报告结构和 lint，信息完整。主要问题是文档/模板互相矛盾：中文支持与英文-only lint、full 维度与模板缺节、专业输出规则与评分文案冲突。相关发现：Finding 1、Finding 3、Finding 8。

## 14. Configuration Safety Analysis（配置安全分析）

- Coverage: High
- Inspected evidence: `agents/openai.yaml`, CLI args in scripts, README install paths
- Exclusions / limits: 项目没有运行时环境变量或配置 schema

无生产配置、密钥配置或 feature flag。`agents/openai.yaml` 仅提供 display metadata 和默认 prompt，风险低。

## 15. Observability / Operability Analysis（可观测性/可运维性分析）

- Coverage: Not assessed
- Inspected evidence: file inventory and script entry points
- Exclusions / limits: 项目不是运行时服务，没有日志、指标、tracing、health check 或 alerting surface

不适用。建议若未来提供 CLI/服务化运行器，再补充结构化日志和错误码。

## 16. Data Integrity Analysis（数据完整性分析）

- Coverage: Not assessed
- Inspected evidence: file inventory, scripts
- Exclusions / limits: 无数据库、迁移、队列、缓存或持久化业务状态

不适用。唯一可变输出是生成报告和 zip 包，已在 Release/Supply Chain 中覆盖。

## 17. Privacy / Data Governance Analysis（隐私治理分析）

- Coverage: Medium
- Inspected evidence: sensitive handling rules, secret regex, examples
- Exclusions / limits: 无真实 PII 数据流或 telemetry surface

项目没有收集用户数据的运行时逻辑。隐私风险主要来自审计报告可能引用用户项目中的敏感信息。相关发现：Finding 6。

## 18. Accessibility / UX Correctness Analysis（可访问性/UX 正确性分析）

- Coverage: Medium
- Inspected evidence: `templates/audit-report.html`
- Exclusions / limits: 未用浏览器、键盘流或 accessibility tree 验证

HTML 模板使用语义标题和表格，但侧边栏导航不完整，Quick Wins 标题缺少可导航 id。相关发现：Finding 4。

## 19. Supply Chain / Reproducibility Analysis（供应链/可复现性分析）

- Coverage: Medium
- Inspected evidence: `package_skill.py`, README package instructions, file inventory
- Exclusions / limits: 无 lockfile、CI、签名、SBOM 或 release artifact 可检查

无第三方依赖，供应链攻击面小。但发布包内容由排除列表决定，容易纳入 generated 文件。相关发现：Finding 7。

## 20. Cost / Resource Economics Analysis（成本/资源经济性分析）

- Coverage: Not assessed
- Inspected evidence: scripts and prompts
- Exclusions / limits: 项目无外部 API/model 调用代码；AI token 成本由宿主模型调用决定

不适用。full 模式会消耗较多人工/模型上下文，但这属于使用策略而非本仓库运行时代码成本。

## 21. AI / LLM Safety Analysis（AI 安全分析）

- Coverage: Medium
- Inspected evidence: `SKILL.md`, prompts, sensitive handling, audit boundary rules
- Exclusions / limits: 未运行 prompt-injection eval corpus

skill 明确禁止默认修改被审计源代码，要求敏感值脱敏，并要求证据驱动。AI 安全风险主要是生成器可能按矛盾模板漏掉维度或输出不符合语言/脱敏约束。相关发现：Finding 1、Finding 4、Finding 6。

## 22. Fallback / Defensive Code Analysis（兜底/防御性代码分析）

- Coverage: High
- Inspected evidence: `rg` fallback/default/error search, scripts and prompts
- Exclusions / limits: 未执行异常 runtime

没有发现脚本吞错或静默 fallback。模板层面的“跳过不适用维度”属于报告契约兜底不一致，已在 Finding 4 覆盖。

## 23. Testing Authenticity Analysis（测试真实性分析）

- Coverage: High
- Inspected evidence: file inventory, linter behavior, README lint docs
- Exclusions / limits: 仓库内无测试可评估真实性

由于没有测试，无法形成真实回归信心。优先添加 fixture 测试，而不是只检查脚本能启动。相关发现：Finding 5。

## 24. Type Safety Analysis（类型安全分析）

- Coverage: Medium
- Inspected evidence: Python type hints in both scripts, regex parsing boundaries
- Exclusions / limits: 未运行 type checker；无 Python version metadata

脚本使用现代 Python 类型标注，代码可读。缺少工具链版本声明和 type-check CI，导致类型约束没有被自动验证。

## 25. Frontend State Analysis（前端状态分析）

- Coverage: Not assessed
- Inspected evidence: HTML template
- Exclusions / limits: 无组件树、状态 store、effect 或 client app

不适用。HTML 文件是静态报告模板，不是前端状态系统。

## 26. Backend API Analysis（后端 API 分析）

- Coverage: Not assessed
- Inspected evidence: file inventory
- Exclusions / limits: 无 API endpoint、handler、server 或 persistence adapter

不适用。

## 27. Dependency Weight Analysis（依赖权重分析）

- Coverage: High
- Inspected evidence: file inventory, Python imports
- Exclusions / limits: 无依赖 manifest 或 lockfile

项目无第三方运行时依赖，两个脚本均使用 Python 标准库。依赖重量风险低。

## 28. Code Consistency Analysis（代码一致性分析）

- Coverage: High
- Inspected evidence: mode IDs across SKILL, prompts, templates, linter
- Exclusions / limits: 未运行格式化工具

命名大体统一，但 full 模式维度列表在多个文件重复维护后出现漂移。相关发现：Finding 3、Finding 4。

## 29. Comment Coverage Analysis（注释覆盖分析）

- Coverage: High
- Inspected evidence: scripts comments/docstrings, template comments, README/SKILL docs
- Exclusions / limits: 未检查 Git 历史中的陈旧注释

模板注释丰富，但部分注释已经互相矛盾，例如 HTML full 模式的 skip/Do NOT skip 指令。相关发现：Finding 4。

---

## 30. Principles Compliance

总体上，项目遵循了“证据优先”“小工具低依赖”“模板化输出”的原则。主要违反点不是代码复杂度，而是契约重复导致的漂移，以及 lint gate 没有 fail-fast 地捕获已知模板问题。

### Principles Violated

| Principle | Violations | Severity | Affected Areas |
|-----------|------------|----------|----------------|
| DRY (4.1) | 2 | Medium | full mode section lists duplicated across prompt/template/linter |
| Fail-Fast (4.4) | 2 | Medium | placeholder lint and localized report lint do not fail on important invalid states |
| Principle of Least Surprise (3.1) | 2 | Medium | Chinese report support and full-mode output differ from actual lint/template behavior |
| Configuration Over Hardcoding (9.1) | 1 | Low | section IDs and required fields are hardcoded in several places without shared registry |

### Principles Respected

- Evidence-first reporting is consistently emphasized in `SKILL.md`, prompt files, and rubrics.
- Severity, confidence, coverage, and scoring are separated, which keeps audit judgment more defensible.
- Runtime dependency footprint is minimal: executable scripts use Python standard library only.
- The audit boundary is explicit: audit/report generation is separated from remediation implementation.

## 31. Recommended Fix Order

### Fix Immediately

No Critical or High findings were confirmed.

### Fix Before Stable Release

| # | Fix | Effort | Risk reduced |
|---|-----|--------|--------------|
| 1 | Add localized Markdown lint support or document an English-field contract | 0.5-1 day | Prevents Chinese reports from failing or becoming inconsistent |
| 2 | Expand placeholder lint and add failing fixtures | 2-4 hours | Prevents unfinished template text in delivered reports |
| 3 | Add missing Code Consistency and Comment Coverage Markdown sections | 2-4 hours | Restores full-mode coverage completeness |
| 4 | Fix HTML full-mode nav and Not assessed guidance | 0.5 day | Removes contradictory full-mode output behavior |
| 5 | Add CI fixture tests for linter/template/package behavior | 1-2 days | Prevents future drift |

### Schedule Later

| # | Fix | Effort |
|---|-----|--------|
| 1 | Broaden secret scanning with token-family fixtures and false-positive rules | 0.5-1 day |
| 2 | Move mode metadata into one shared registry used by prompts/templates/linter | 1-2 days |
| 3 | Add Python version/toolchain metadata and type-check job | 0.5 day |

### Ignore for Now

| # | Item | Reason |
|---|------|--------|
| 1 | Runtime observability | No service/runtime process exists |
| 2 | Backend API, persistence, frontend state | Not applicable to this skill package |

## 32. Quick Wins

| Quick win | Value | Effort |
|-----------|-------|--------|
| Add `audit-report-*.md` and `audit-report-*.html` to `DEFAULT_EXCLUDES` | Prevents generated report leakage in zip packages | 15-30 minutes |
| Add `id="quick-wins"` to the HTML Quick Wins heading and require it in lint | Restores section navigation/validation | 15 minutes |
| Replace public "shit mountain" score labels with neutral wording | Aligns generated output with professionalism rule | 30-60 minutes |
| Add two Chinese Markdown report fixtures | Makes the current localization gap executable | 1-2 hours |

## 33. Long-term Refactor Plan

Create a single mode registry, for example `modes.json`, containing mode ID, display names, score dimensions, Markdown section labels, HTML section IDs, applicability rules, and prompt path. Generate or validate `SKILL.md` tables, full prompt dimension lists, Markdown/HTML template section stubs, and `report_lint.py` maps from that registry. This reduces the current highest-maintenance area: repeated mode metadata across five files.

Testing strategy: add fixture-based tests that render or validate all selected modes from the registry, including `full`, a multi-mode selection, Chinese Markdown, and HTML. Release risk is moderate because template wording changes can affect existing report shape; mitigate by keeping current headings as aliases for one release.
