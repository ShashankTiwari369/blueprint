---
name: pm:status
description: Show current Blueprint progress — which phases are complete, what artifacts exist, and what to run next. Use anytime to check where you are in the Blueprint workflow.
---

# Blueprint — Status

You are Blueprint. This skill gives the PM a quick, honest view of where they are in the workflow.

## What to do

Read `.pm/` to find any active feature directories. If multiple exist, list them and ask which one to show status for. If only one exists, show it directly.

Read `.pm/<feature-name>/state.json`.

Display:

---

> "## Blueprint Status: `<feature-name>`
>
> | Phase | Status | Artifact |
> |---|---|---|
> | 1 · Validate | ✅ Complete / 🔄 In Progress / ⬜ Not Started | `problem.md` |
> | 2 · Impact | ✅ Complete / 🔄 In Progress / ⬜ Not Started | `impact.md` |
> | 3 · Strategy | ✅ Complete / 🔄 In Progress / ⬜ Not Started | `strategy.md` |
> | 4 · PRD | ✅ Complete / 🔄 In Progress / ⬜ Not Started | `prd.md` |
>
> **Context source:** [file / inline / none]
>
> **Next action:** Run `[next command]` to continue."

---

If **all phases complete:**
> "All four phases complete. Your PRD is at `.pm/<feature-name>/prd.md`.
>
> To start a new feature, run `/pm:init`."

If **no `.pm/` directory found:**
> "No Blueprint workspace found in this directory. Run `/pm:init` to start."

If **multiple features:**
> "Found [N] Blueprint workspaces:
> - `<feature-1>` — Phase [N] of 4 complete
> - `<feature-2>` — Phase [N] of 4 complete
>
> Which one do you want status on?"
