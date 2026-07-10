# Blueprint

**A structured PM thinking partner — from problem to developer-ready PRD.**

Blueprint is a set of Claude Code skills that guides product managers through four disciplined phases: validate the problem, estimate the impact, define the strategy, draft the PRD. Each phase builds on the last. The PRD assembles automatically from all prior work.

---

## Why Blueprint

Most PMs jump from idea to solution to spec. Blueprint forces the right sequence:

1. **Is this actually the right problem?** (Socratic questioning before any solutioning)
2. **How big is it?** (Impact estimation before prioritization)
3. **What's the strategy?** (Hard choices before features)
4. **What exactly gets built?** (PRD grounded in all of the above)

The result is a PRD that developers can read and build from without follow-up questions.

---

## Installation

```bash
git clone https://github.com/yourusername/blueprint.git
cd blueprint
bash install.sh
```

This copies the skills into `~/.claude/skills/` so they're available globally in Claude Code.

---

## Setup (optional but recommended)

Copy the context template to any project where you'll use Blueprint:

```bash
cp pm-context.yml.example /path/to/your/project/pm-context.yml
```

Fill in your company, product, user personas, and baseline metrics. Blueprint loads this automatically and uses it throughout all four phases — you won't have to re-explain your context in every session.

---

## Usage

Open Claude Code in your project directory and run:

```
/pm:init [feature-name]
```

Blueprint will guide you through the rest. Check where you are anytime with `/pm:status`.

---

## Commands

| Command | Phase | What it does |
|---|---|---|
| `/pm:init` | Setup | Initialize workspace, load context |
| `/pm:validate` | 1 · Validate | Socratic problem validation |
| `/pm:impact` | 2 · Impact | Quantify problem + solution value |
| `/pm:strategy` | 3 · Strategy | Strategic choices + Rumelt synthesis |
| `/pm:prd` | 4 · PRD | Assemble the developer-ready spec |
| `/pm:status` | Anytime | Show progress and what's next |

---

## What gets created

Each phase produces a markdown artifact in `.pm/<feature-name>/`:

```
.pm/
└── your-feature-name/
    ├── state.json          ← tracks phase completion and choices
    ├── problem.md          ← Phase 1: validated problem statement
    ├── impact.md           ← Phase 2: three-scenario impact estimate
    ├── strategy.md         ← Phase 3: Rumelt strategy kernel
    └── prd.md              ← Phase 4: full PRD
```

You can commit `.pm/` to version control — it's your working artifact trail.

---

## Phases in detail

### Phase 1 · Validate (`/pm:validate`)

Runs Socratic questioning across five dimensions: problem clarity, solution validation, success criteria, constraints, and strategic fit. Blueprint picks the 3–5 most important questions for your specific problem — not a checklist, a conversation.

Output: `problem.md` — specific problem statement, evidence, cost of inaction, success definition, explicit non-goals.

### Phase 2 · Impact (`/pm:impact`)

Walks through the impact formula:
`Impact = Users Affected × Current Action Rate × Expected Lift × Value per Action`

Estimates both the current problem cost and the expected solution value. Produces pessimistic / realistic / optimistic scenarios. Any data you don't have yet can be deferred with a [TBD] placeholder — the structure stays intact.

Output: `impact.md` — three-scenario estimate, ROI calculation, explicit assumptions, data gaps.

### Phase 3 · Strategy (`/pm:strategy`)

Uses Rumelt's Strategy Kernel (Diagnosis → Guiding Policy → Coherent Actions) as the framework. Blueprint presents five strategic choice questions (scope, target, approach, pace, measurement) with A/B/C options tailored to your specific situation. After each choice, Blueprint plays devil's advocate — you stick with it or reconsider. The final choices get synthesized into a coherent strategy, not a feature list.

Optional: web research on competitive landscape before strategic choices.

Output: `strategy.md` — diagnosis, guiding policy, 3-month roadmap, critical assumptions.

### Phase 4 · PRD (`/pm:prd`)

Assembles all prior work into a structured PRD:
- Overview & problem statement (from Phase 1)
- Business case (from Phase 2)
- Strategic direction (from Phase 3)
- User personas (from context + Phase 1)
- User stories
- Acceptance criteria (testable, specific)
- Success metrics with baselines and targets
- Scope (in + out)
- Regulatory/compliance callouts (if applicable)
- Open questions with owners

Output: `prd.md` — the developer-ready spec.

---

## Frameworks used

- **Socratic Questioning** — five question categories for problem validation
- **Impact Formula** — Users × Rate × Lift × Value, three-scenario approach
- **Rumelt's Strategy Kernel** — from *Good Strategy, Bad Strategy* by Richard Rumelt
- **Devil's Advocate** — structured pressure-testing before choices are locked

---

## Philosophy

Blueprint is a thinking partner, not a PRD generator. It does not write your spec for you from a prompt. It guides you through the work that makes a spec credible: validating the problem, quantifying the impact, making strategic tradeoffs explicit. The output reflects your thinking — Blueprint just makes sure you've done the thinking.
