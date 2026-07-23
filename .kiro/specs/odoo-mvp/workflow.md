# Workflow: Spec Conventions & Parallel Execution

Status: ACTIVE
Last updated: 2026-07-22

How this project is planned, specced, and executed. Read this before writing
`requirements.md`, task files, or fanning out worktrees. Companion to
`design.md` (architecture) and `docs/mvp_validation_playbook.md` (why this
exists / demand thesis).

## 1. Spec-Driven Process

All work flows from this spec directory — it is the persistent memory.
Agents must never depend on chat-thread context; if a decision matters, it
lives in a file here.

Order of artifacts:

1. `design.md` — architecture, built collaboratively, end-deliverable first (DONE)
2. `workflow.md` — this file (DONE)
3. `requirements.md` — numbered requirements + acceptance criteria (NEXT)
4. `tasks/` — one file per task (see §2)
5. `AGENTS.md` (repo root) — agent entry point
6. `docs/parallel-workflow.md` — condensed worktree rules for agents

Tooling decision: no spec-kit, no Task Master. Plain markdown, versioned in
git. Status tracking via per-task frontmatter (§2) — chosen specifically so
parallel worktrees never contend over a single tasks file.

## 2. Task File Convention

One task = one file in `.kiro/specs/odoo-mvp/tasks/`, named
`T<nn>-<slug>.md` (e.g. `T03-raw-vault-finance.md`). Frontmatter:

```yaml
---
id: T03
title: Raw vault - finance domain
wave: 2
worktree: finance
status: todo        # todo | in-progress | done | blocked
depends_on: [T01]   # task ids
owns:               # files/dirs this task may create or edit (and no others)
  - models/raw_vault/finance/
  - models/staging/stg_odoo__account_*.sql
---
```

Body: self-contained brief — context, what to build, references into
`design.md` sections, acceptance check. An agent must be able to complete
the task from this file + design.md alone, unattended.

Rules:
- A worktree edits ONLY its own task file's `status:` and the files in its
  `owns:` list. Nothing else. This is the module-ownership guarantee.
- `owns:` lists across all tasks in a wave must not overlap (verified when
  tasks are authored).
- Kill-switch rule: if an agent fails the same acceptance check twice, or
  needs a file outside its `owns:` list, it sets `status: blocked` with a
  note in the task body and STOPS. No workarounds, no scope creep.

## 3. Execution Environment

- **Planning**: Claude Code, in this repo.
- **Execution**: Orca (github.com/stablyai/orca) fans tasks across parallel
  git worktrees — up to ~10 concurrently. Worktree agents are OpenCode (or
  Claude Code); OpenCode agents read `AGENTS.md` at repo root, not
  CLAUDE.md. Work must be hand-off-able: launched, runs unattended,
  reviewed on completion.
- Lineage note: conventions here (waves, ownership map, kill switches)
  derive from Rho-Lall/riptide, kept as markdown conventions rather than
  installed tooling — Orca supplies the mechanics (worktree isolation,
  launching, monitoring).

## 4. Waves

Wave = group of tasks safe to run in parallel. Waves run in sequence;
tasks within a wave run concurrently, one worktree each.

| Wave | Content | Parallelism |
|---|---|---|
| 1 | `core` worktree: shared staging, core hubs/sats, conformed dims, shared seeds, source yml for shared tables | 1 |
| 2 | 6 domain worktrees: domain staging, raw vault, business vault, marts, reports | up to 6 |
| 3 | `assembly` worktree: dbt_project.yml config check, README, docs generation, cross-domain verification | 1 |

Merge order within a wave: any order (ownership map guarantees no
conflicts). Wave N+1 branches from the merged result of wave N.

## 5. MVP Acceptance Targets (feed into requirements.md)

- `dbt parse` green on the assembled branch (no warehouse connection;
  dummy profile is fine)
- `dbt docs generate --empty-catalog` succeeds; DAG matches design.md §4
  layout and §7 report catalog
- Every report view refs only its declared mart sources (design.md §7)
- All 28 report views exist; ~60 staging models per source map (design.md §5)
- README presents problem + architecture + early-access call-to-action
- Ownership check: no file owned by two tasks

## 6. Validation & Roadmap (after build)

Per `docs/mvp_validation_playbook.md`:

1. Publish docs site + README (this repo is public from day one)
2. Post to Odoo forums/Discord + dbt Community Slack (#show-and-tell)
3. Measure: 5–10 inbound messages / stars / issues from consulting shops or
   mid-market IT within ~a week = validated demand
4. Roadmap on validation: mock → real package (working SQL against Odoo
   17/18 schemas, driven by what hand-raisers actually run) → dbt Hub
   listing, possibly Odoo App Store. Extraction/sync stays out of scope;
   Fivetran/Airbyte assumed upstream.
