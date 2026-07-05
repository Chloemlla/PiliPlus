---
name: fuck-my-shit-mountain
description: Use when the user asks for a comprehensive codebase audit or structured repository health report across multiple quality dimensions such as architecture, design, security, stability, performance, testing, maintainability, release readiness, documentation, observability, configuration safety, data integrity, privacy, accessibility, supply chain, cost, AI/LLM safety, frontend state, backend API design, dependency weight, code consistency, or comment coverage.
---

# Fuck My Shit Mountain — Skill Definition

## Purpose

Guide AI to perform an evidence-based, professional code audit of a software project. Despite the irreverent name, the output must be冷静 (calm), professional, actionable, and free of emotional language.

## Required Inputs Before Auditing

Before reading code, determine whether the user has already supplied all required inputs. Ask only for missing items, in one concise message, and wait for the answer before auditing. Do not re-ask items that are already explicit in the request.

Required inputs:

1. **Audit modes** — Accepted values: `full`, `architecture`, `security`, `stability`, `performance`, `testing`, `maintainability`, `design`, `release`, `documentation`, `observability`, `configuration`, `data-integrity`, `privacy`, `accessibility`, `supply-chain`, `cost`, `ai-safety`, `fallback`, `testing-authenticity`, `type-safety`, `frontend-state`, `backend-api`, `dependency-weight`, `code-consistency`, `comment-coverage`.
   - If the user picks `full`, do all dimensions.
   - If the user picks multiple modes, merge the audit areas from each selected prompt. Use the most specific finding format rules.
   - If audit modes are missing, the setup question must include the complete supported mode list above and mention that `full` is the recommended default for a broad audit. Keep the list compact and show the options every time mode selection is requested.
2. **Report language** — The language used in the final report, such as English or Chinese. The programming language is inferred from the repository and is not a substitute for this answer.
3. **Output format** — Accepted values: `md`, `html`, `both`, `stdout`.
   - `md` — Save as `audit-report-<project>-<date>.md`.
   - `html` — Save as `audit-report-<project>-<date>.html`.
   - `both` — Save both files.
   - `stdout` — Print the report in the conversation only.
   - If `md`, `html`, or `both` is requested, write the file(s) after generating the report. For HTML output, read `templates/audit-report.html`, copy its **exact CSS and HTML structure**, include the sections and score items required for the selected modes, and replace the content with actual audit data. Do not use placeholder variables; generate complete, self-contained HTML.

If the user says something like "audit this project" without any of the required inputs, ask all three in one message and include the supported mode list. If the user says "full, Chinese, html", proceed without another setup question.

## How It Works

1. The user invokes the skill and the AI collects only the missing required inputs.
2. The AI loads the corresponding prompt(s) from `prompts/`. If multiple modes are selected, merge the audit areas from each.
3. The AI loads `references/report-format.md` for shared required-context, report template, coverage, HTML, and lint rules.
4. The AI loads the required rubrics:
   - `rubrics/severity.md` for severity labels.
   - `rubrics/confidence.md` for confidence labels.
   - `rubrics/evidence.md` for evidence quality and minimum evidence thresholds.
   - `rubrics/coverage.md` for dimension coverage confidence and reporting limits.
   - `rubrics/scoring.md` for score dashboards and grade anchors.
   - `rubrics/principles.md` when producing full, architecture, maintainability, design, documentation, frontend-state, backend-api, type-safety, configuration, data-integrity, accessibility, or principles-related findings.
5. The AI audits the codebase using the coverage strategy below.
6. Each finding is recorded using `templates/issue-card.md`.
7. Results are assembled using `templates/audit-report.md` or `templates/audit-report.html`, depending on the requested output format.
8. If output-to-file was requested, the AI writes the report to disk.
9. For generated `md`, `html`, or `both` output, run the skill's `scripts/report_lint.py` with `python3 <skill-dir>/scripts/report_lint.py --modes <selected-modes> <report-file>` when the script is available. Fix lint failures before delivering the report. For `stdout`, apply the same checks manually.
10. If remediation planning is requested, the AI uses `templates/remediation-plan.md`.
11. If implementation is requested separately, the AI fixes code only after the audit/report step is complete.

## Mode vs Dimension Model

- **Selectable modes** are user-facing audit entry points. Each mode maps to one prompt file in `prompts/`.
- **Full dimensions** are the sections covered by `full` mode. Full mode covers all selectable focused dimensions and marks project-inapplicable dimensions as Not assessed.
- Focused modes may affect multiple score dimensions. For example, `configuration` can affect Security, Stability, and Release.
- If a dimension is only conditionally relevant, such as `frontend-state`, `accessibility`, or `ai-safety`, inspect for applicability first and mark it Not assessed with evidence when the project lacks that surface.

## Resource Loading

- Load only the prompt files for the selected modes.
- Load `references/report-format.md` before producing any report. Focused prompt files intentionally omit repeated setup and template rules.
- Load examples from `examples/` only for calibration when the user asks for examples or the report shape is unclear. Do not copy their findings into a real audit.
- Do not load large generated or vendored files into context unless the selected mode specifically requires them.

## Audit Boundary

By default, this skill audits and reports. It may create requested report files, but it must not change application source code, tests, configuration, or dependencies unless the user explicitly asks for remediation implementation.

## Coverage Strategy

Be exhaustively systematic over in-scope project files, not literally every byte in the repository.

1. Start with a file inventory using fast project-aware search such as `rg --files`.
2. Build a project map before writing findings: entry points, main modules, architecture boundaries, data flow, state ownership, persistence, data integrity boundaries, privacy-sensitive data, external interfaces, security boundaries, AI/model surfaces, observability surfaces, configuration sources, tests, CI, release files, and dependency manifests.
3. Treat first-party source, tests, scripts, CI/config, migrations, dependency manifests, and documentation that describes behavior as in scope.
4. Exclude by default: `.git`, dependency folders (`node_modules`, `vendor` unless first-party vendored code must be audited), build artifacts (`dist`, `build`, `target`, `out`, `coverage`, `.next`, `.nuxt`), generated files, minified bundles, binary assets, cache folders, and lockfiles unless the selected mode needs dependency or release evidence.
5. For large repositories, prioritize high-risk areas first: auth, input boundaries, persistence, data integrity, privacy-sensitive data, AI/model tool boundaries, concurrency, network/file-system access, error handling, observability gaps, build/release config, supply-chain surfaces, cost drivers, and critical user workflows.
6. Assign coverage confidence per selected dimension using `rubrics/coverage.md`: High, Medium, Low, or Not assessed.
7. Include a short coverage note in the report, usually in Project Map or Executive Summary: inspected areas, excluded path categories, important commands run, and any time or access limits.
8. Include a coverage matrix in the report with one row per selected dimension: dimension, coverage confidence, inspected evidence, exclusions/limits.
9. If a file or area could not be inspected, say so explicitly. Do not imply complete coverage when coverage was partial.

## Sensitive Information Handling

If the audit discovers secrets, tokens, private keys, `.env` values, credentials, database dumps, or similarly sensitive material:

- Do not print the full secret in the report, terminal output, commit message, or conversation.
- Identify the path, variable/key name, secret type, and risk. Redact values as `<redacted>` or show at most a minimal prefix/suffix when necessary for disambiguation.
- Recommend rotation when exposure is plausible.
- Treat sensitive files as evidence of risk without copying their contents into the generated report.

## Modes

| Mode | Prompt | Focus |
|------|--------|-------|
| `full` | `prompts/full-audit.md` | All dimensions + principles |
| `architecture` | `prompts/architecture-audit.md` | Module boundaries, dependency direction, state ownership |
| `security` | `prompts/security-audit.md` | Security risks |
| `stability` | `prompts/stability-audit.md` | Reliability & errors |
| `performance` | `prompts/performance-audit.md` | Realistic bottlenecks |
| `testing` | `prompts/testing-audit.md` | Test quality & gaps |
| `maintainability` | `prompts/maintainability-audit.md` | Complexity, coupling, principles |
| `design` | `prompts/design-audit.md` | Engineering principles and design risk |
| `release` | `prompts/release-audit.md` | Release readiness |
| `documentation` | `prompts/documentation-audit.md` | Docs accuracy, setup, operator/developer guidance |
| `observability` | `prompts/observability-audit.md` | Logging, metrics, tracing, health checks, alerting |
| `configuration` | `prompts/configuration-audit.md` | Config validation, defaults, feature flags, env separation |
| `data-integrity` | `prompts/data-integrity-audit.md` | Transactions, idempotency, migrations, invariants |
| `privacy` | `prompts/privacy-audit.md` | PII, minimization, retention, deletion, data governance |
| `accessibility` | `prompts/accessibility-audit.md` | Keyboard, focus, semantics, responsive and UX states |
| `supply-chain` | `prompts/supply-chain-audit.md` | Provenance, reproducibility, CI integrity, signing |
| `cost` | `prompts/cost-audit.md` | Resource economics, budgets, external API and LLM costs |
| `ai-safety` | `prompts/ai-safety-audit.md` | Prompt injection, tool auth, RAG leakage, evals, cost abuse |
| `fallback` | `prompts/fallback-audit.md` | Silent fallback, catch, defensive guessing |
| `testing-authenticity` | `prompts/testing-authenticity-audit.md` | Real confidence vs green checkmarks |
| `type-safety` | `prompts/type-safety-audit.md` | Unsafe blocks, assertions, boundary types |
| `frontend-state` | `prompts/frontend-state-audit.md` | Component size, state, effects, coupling |
| `backend-api` | `prompts/backend-api-audit.md` | API design, validation, data access patterns |
| `dependency-weight` | `prompts/dependency-weight-audit.md` | Overweight deps, build toolchain |
| `code-consistency` | `prompts/code-consistency-audit.md` | Naming, imports, patterns, style uniformity |
| `comment-coverage` | `prompts/comment-coverage-audit.md` | Doc quality, stale comments, missing docs |

## Scoring

Full audits produce a **score dashboard** with 7 dimension scores (0.0–10.0) and an overall score. Focused audits score only the relevant dimensions and mark unrelated dimensions as not assessed when the template needs that context.

- **Higher = better.** 10 = clean / production-ready. 0 = shit mountain / unacceptable. Do not reverse this.
- Scores are **judgment-based**, not mechanical deductions. The AI evaluates evidence holistically per dimension.
- Each score must have a **one-sentence justification** referencing the strongest evidence and the coverage confidence when it limits the conclusion.
- A letter grade (S/A/B/C/D/F) provides an at-a-glance health indicator.
- Scores supplement detailed findings — they do not replace them.

## Rules (Non-negotiable)

1. Every finding MUST include concrete evidence (file, function, behavior).
2. Separate **Confirmed** issues from **Suspected** issues.
3. Do not exaggerate severity — map to `rubrics/severity.md`.
4. Do not recommend rewrites unless local fixes are clearly insufficient.
5. Prefer the smallest practical fix that reduces real risk.
6. Do not produce generic advice. Every finding must tie to a realistic failure scenario.
7. Do not complain about style unless it creates a demonstrable maintainability or correctness risk.
8. If evidence is insufficient, say so. Do not fabricate findings.
9. Every finding MUST include a regression test suggestion.
10. Every finding MUST include an estimated effort.
11. Check violations of engineering principles using `rubrics/principles.md` — focus on violations that create real risk, not minor style quarrels.
12. **Be exhaustively systematic.** Search all in-scope first-party areas, not just the obvious hotspots. Use the coverage strategy above and document exclusions honestly.
13. **Do not be a yes-man.** Do not suppress findings because the user seems confident, or because you want to be agreeable. Your job is to identify real risks objectively, regardless of who wrote the code or what the user expects to hear. If the code has problems, say so.
14. **Use the skill's template format, not the project's style.** The report MUST follow `templates/audit-report.md` (or `templates/audit-report.html` for HTML output). For HTML output: copy the **exact CSS and HTML structure** from the template (stat cards, selected-dimension score rows, top risks table, detailed findings, per-dimension sections with tables+checklists, design principles when applicable, fix order tables, quick wins grid). Only replace content — keep all HTML classes, CSS variables, and section ordering intact. Do NOT invent new section structures. Do NOT copy formatting, structure, or style from markdown files inside the audited project.
15. Do not expose secrets. Report sensitive findings with redaction as described above.
16. Do not modify audited code unless the user explicitly requests implementation, not just an audit.

## Final Self-Check

Before delivering the report, verify:

- Required inputs are known and the report uses the requested language and output format.
- The selected prompt(s), required rubrics, and report template were followed.
- The report contains a project map, coverage note, coverage matrix, score dashboard, finding statistics, top risks, detailed findings, relevant dimension sections, principles compliance when applicable, fix order, and quick wins.
- Each selected dimension has coverage confidence, inspected evidence, and exclusions/limits.
- Every finding has severity, confidence, status, evidence, realistic failure scenario, minimal fix, regression test suggestion, and estimated effort.
- Confirmed and Suspected issues are separated or clearly labeled.
- Score direction is correct: 10.0 is best and 0.0 is worst.
- HTML reports are complete, self-contained, and contain no placeholder variables.
- No full secrets, tokens, private keys, passwords, or sensitive dumps appear in the output.
- `scripts/report_lint.py` passes for generated file output, or its checks were applied manually for stdout output.
