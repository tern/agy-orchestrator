---
name: model-router
description: Routes software-engineering subtasks from Agy to Claude Code or Codex workers using Haiku 4.5, Sonnet 5, Opus 5, GPT-5.6 Luna, Terra, or Sol with cost-aware escalation and isolated execution.
---

# Model Router

Use `agy-exec` as the only cross-provider execution entry point. Do not invoke `claude` or `codex` directly unless diagnosing the bridge.

## Routing policy

Choose the cheapest model that is likely to succeed.

| Work type | First choice | Alternate | Escalation |
|---|---|---|---|
| file discovery, grep plan, docs, repetitive checks | luna | haiku | terra |
| quick codebase analysis, tests, triage | haiku | luna | sonnet |
| normal implementation/refactor/debug | sonnet | terra | opus/sol |
| OpenAI-family implementation/review | terra | sonnet | sol |
| difficult architecture or ambiguous failure | opus | sol | cross-review |
| difficult reasoning / cross-file verification | sol | opus | cross-review |

## Mandatory cost controls

1. Do not use Opus or Sol for basic search, formatting, boilerplate, or routine tests.
2. Escalate because of complexity, failed verification, or an unresolved blocker—not merely because a task is large.
3. Prefer at most one expensive expert call per unresolved problem before re-planning.
4. Default maximum concurrent external workers: 4.
5. If a cheap worker succeeds and verification passes, stop escalating.

## Delegation format & Bottom Statusline

Dispatch with `invoke_subagent`, setting **TypeName to the route name** (`haiku`, `sonnet`,
`opus`, `luna`, `terra`, `sol`). Each route has its own worker agent, and Agy's bottom
statusline renders TypeName — so this is what makes it read `Agent(sonnet)` rather than a
generic label. TypeName must match `--model` in the command:

```json
invoke_subagent({
  "Subagents": [
    {
      "TypeName": "sonnet",
      "Role": "Claude Sonnet (主力實作)",
      "Model": "flash_lite",
      "Prompt": "請使用 run_command 執行以下這一條命令，不要執行其他任何命令：\nagy-exec --model sonnet --mode edit --role implementation --task \"Objective: implement token refresh. Scope: src/auth and tests/auth. Constraints: preserve public API. Verification: run targeted auth tests.\"\n\n這條命令會跑數分鐘，第一次 status 一定是 RUNNING，那是正常的。請持續以 manage_task 輪詢，直到 log 最後一行出現 ===== AGY_WORKER_END exit=... ===== 為止，再把完整 log 原文回傳給 orchestrator。在哨符出現前不得回報結果，不得自行執行任務，不得用自己的觀察補寫報告。"
    }
  ]
})
```

Do not pass `--isolation shared` for `--mode edit`. Omit `--isolation` so `agy-exec`
creates a detached worktree; reserve `shared` for inspect-only tasks that must see the
live working tree, or for non-Git directories.

Every delegated task prompt to `agy-exec` must state:
- Objective
- Relevant files/directories if known
- Constraints
- Whether modification is allowed (`--mode inspect` or `--mode edit`)
- Expected output
- Verification method

## Worker report validity

`agy-worker` is a `flash_lite` dispatch runner. Its strongest failure mode is impatience:
it sees `RUNNING`, decides the command is too slow, does the task itself with its own
`run_command`, and sends that back as if the routed model had produced it. A fabricated
"review passed" reads exactly like a real one.

A worker report counts as real only when it contains:
- `===== AGY_WORKER_END exit=0 =====` (always the final line of a completed run);
- a TypeName matching the `--model` route you dispatched;
- the `🚀 [agy-worker] Starting:` banner naming the model you actually routed to;
- an `AGY_WORKER_GIT_DIFF` block, for edit tasks.

Anything else is an incomplete delegation. Re-dispatch or request the full task log.
Never integrate, commit, or mark a review as passed on an unsentineled report.

## Parallelism

Parallelize only independent workstreams. Good examples:
- Luna maps relevant files while Haiku maps tests.
- Sonnet implements one independent module while Terra reviews another.
- Two reviewers independently inspect a proposed architecture.

Do not parallelize workers that will edit the same files unless they are in isolated worktrees and the parent will manually select/merge one result.

## Escalation ladder

Default:

`Luna/Haiku -> Sonnet/Terra -> Opus/Sol`

If Sonnet authored important code, prefer Terra or Sol for independent review. If Terra authored important code, prefer Sonnet or Opus for review. Cross-family review is preferred for critical changes.

## Result contract and budget

Each run writes `result.json` (path echoed as `===== AGY_WORKER_RESULT <path> =====`).
Control decisions come from it — `ok`, `exit`, `stop_reason`, `changed_files`,
`diff_path`, `cost_usd`, `turns` — while the prose report carries the findings. A worker
can write a convincing report about work it never did; it cannot fake a non-zero `exit`.

Pass `--task-id <id>` on every call belonging to the same goal. Spend accumulates per
task-id against `AGY_TASK_BUDGET_USD`; each call is clamped to the remaining balance and
`agy-exec` exits 3 when the budget is gone. Escalating through five routes under one
task-id therefore costs at most the task budget, not five per-call budgets.

If `result.json` reports `reason: budget_exhausted` and `exit: 3`, the provider never
started. Keep the same task-id: wait only when another worker for it is still running,
then reassess after its reservation is released. Otherwise stop and ask the user to reduce
scope or raise `AGY_TASK_BUDGET_USD`; do not re-dispatch or create a new task-id merely to
bypass the cap.

Integrate edit work with `agy-exec apply <run-id>` (add `--check` to dry-run). It
three-way merges the preserved diff and stops on conflict.

## Completion gate

Before reporting success, confirm:
- every worker report you relied on carried the `AGY_WORKER_END` sentinel;
- every result.json you acted on had `ok: true` and the route you dispatched;
- intended change exists;
- relevant tests/build/checks ran where feasible;
- no unexplained new diff remains;
- any external-worker diff was reviewed before integration;
- unresolved risks are stated explicitly.
