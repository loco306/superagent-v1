# ⚡ SUPERAGENT V1 — a multi-agent operating model for Claude Code

SUPERAGENT V1 is not an app — it is an **operating model you install into a Claude
Code workspace**. Drop these files into a directory, open Claude Code there, and the
session becomes SUPERAGENT: a lead orchestrator that takes a single `/goal`, splits it
into fine independent pieces, builds them with a parallel subagent swarm, folds in a
second AI vendor (Grok) for design diversity, verifies the assembled result end-to-end,
and logs what it learned — every time.

```
                YOU ── /goal (one command)
                       │
   GROK ──►┌───────────▼───────────────┐
 (design/  │        CLAUDE LEAD          │  the only persistent agent
  approach) │ Approach Gate → decompose → FINE, INDEPENDENT pieces
           └───────────┬───────────────┘
                       │ spawn ALL at once (only if work splits)
  ┌────────────────────┼─────────────────────┐   ┌─ GROK (diversity, non-blocking) ─┐
  ▼     ▼     ▼     ▼   ▼   CLAUDE BUILD SWARM │   ▼  design · research               │
 bldA  bldB  bldC  bldD bldE  (parallel ·      │      (its OWN subagents)            │
  each a DIFFERENT piece · +self-test)          │   └──────────┬──────────────────────┘
           └──────┬──────┘                                     │ fold in (NEVER block)
                  ▼ assemble                                    │
   ┌──── VERIFIER (functional + usability) ────┐ ◄─────────────┘
   │ runs end-to-end · works · not confusing · fixes · loop until clean
   └──────────────┬────────────────────────────┘
                  ▼
              MERGE ──► deliverable ──► self-improve (LEARNINGS.md)
```

## Core ideas

1. **One persistent lead, disposable workers.** Only the lead agent (strongest model)
   persists. It gates the approach, decomposes the goal, judges, verifies, merges.
   Everything else is a parallel, single-purpose subagent that dies when its piece ships.
2. **Model tiering.** Orchestration/verification on the strongest model; builders on a
   mid-tier model; web-scan/search subagents on the cheapest model. Capability where it
   matters, tokens saved where it doesn't.
3. **A second vendor is a feature.** Grok fires on every goal (design/approach up front,
   review at the end) as a **non-blocking** diversity brain with a real 25–50% share of
   the work. Cross-vendor disagreement surfaces blind spots single-vendor swarms miss.
4. **Fine, independent decomposition.** Pieces split by file/module/component so up to
   16 builders run at once with no cross-talk; each self-tests before handing back.
5. **Verification is a separate agent.** The verifier never built anything, so it has no
   incentive to believe the code works. It runs the deliverable end-to-end for both
   function (works, no errors) and usability (not confusing), looping fixes until clean.
6. **Self-improvement is mandatory.** Every clean run appends a dated lesson plus an
   `INTENT | SHIPPED | MATCH` line to `LEARNINGS.md`, which the lead re-reads at the
   start of the next goal. The process file itself (`CLAUDE.md`) is editable by the
   agent — it improves its own process, never its permissions.

## Files

```
CLAUDE.md                    the operating model — loaded automatically by Claude Code
SWARM_ARCHITECTURE.md        deep-dive on the swarm design and its rationale
orchestrator_directives.md   standing orders for the lead agent
.claude/commands/goal.md     the /goal slash command (lean fast-path variant)
LEARNINGS.md                 self-improvement log (starts empty — the agent fills it)
cleanup.ps1                  archives transient run artifacts so the root stays clean
mcps/agent-browser/          tool schemas for the agent-browser MCP (browser automation)
.gitignore                   keeps run scratch (terminals/, tmp/, agent-tools/) out of git
```

## Setup

1. Clone into a working directory.
2. Install [Claude Code](https://claude.com/claude-code) and open a session in the
   directory — `CLAUDE.md` is picked up automatically.
3. Optional, for the Grok share: install a Grok CLI reachable as `grok` on PATH. The
   convention is prompt-by-file (`grok --prompt-file <tmp>`) to survive shell quoting.
   Without it, the swarm still runs single-vendor.
4. Give it a goal: `/goal build me X`.

## Safety gate

Reversible workspace work (files/code/tests) runs autonomously. The model requires an
explicit STOP-and-ask before any irreversible external action: spending money, placing
orders, writing to production, or sending external messages.

---

*SUPERAGENT V2 — a one-click launcher that boots the Claude CLI itself as the agent
framework — lives in its own repo: `superagent-v2`.*
