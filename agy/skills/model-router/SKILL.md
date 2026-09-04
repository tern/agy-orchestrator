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

## Delegation format

Every delegated task must state:
- Objective
- Relevant files/directories if known
- Constraints
- Whether modification is allowed (`--mode inspect` or `--mode edit`)
- Expected output
- Verification method

Example:

```bash
agy-exec --model sonnet --mode edit --role implementation \
  --task "Objective: implement token refresh. Scope: src/auth and tests/auth. Constraints: preserve public API. Verification: run targeted auth tests."
```

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

## Completion gate

Before reporting success, confirm:
- intended change exists;
- relevant tests/build/checks ran where feasible;
- no unexplained new diff remains;
- any external-worker diff was reviewed before integration;
- unresolved risks are stated explicitly.
