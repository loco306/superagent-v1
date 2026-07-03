# Multi-Agent Swarm — Deployment Architecture

> **Status: BINDING.** This is the versioned source-of-truth context artifact the SuperAgent
> loads at the start of every run. `CLAUDE.md` references it; every agent (lead, subagents,
> Grok) operates under it. Improvements to *process* are made by editing this file via the
> self-improvement loop (never editing the permission boundary or the success metric).

The formula for deploying multiple agents that swarm a task, **create more agents when
needed**, **improve themselves over time**, and accomplish the most. "The most" is not a
function of agent count — it is a function of decomposition quality, verification
independence, how cleanly results merge, and **how fast the system learns from its own
verified outcomes**.

---

## The Core Primitives (necessary, not sufficient)

| Primitive | What it does | Why it matters |
|---|---|---|
| **Loops** | The agent self-continues instead of waiting for input | Removes the human from the turn-by-turn cycle |
| **Plan / decompose first** | Decompose the goal before acting (this is the THINKING step — *not* Claude Code's permission plan-mode; you boot autonomous and act immediately) | Prevents N agents from forming N different interpretations of the task |
| **Dynamic workflows** | The agent chooses its next action from current state | The difference between an agent and a fixed script |
| **Multiple agents** | Parallelism + specialization | Throughput — scale as wide as the work parallelizes |
| **Spawning** | Agents create sub-agents by **calling the spawn tool** | Lets the system size its own crew to the work |
| **Self-improvement** | The system rewrites its own process from verified results | Compounding gains — each run makes the next run better |

The first four are the foundation. **Spawning** scales the crew; **self-improvement**
compounds quality. Two control pieces keep all of it from going wrong.

---

## The Two Pieces That Complete It

### 1. Independent Verifier (the writer/checker split)
The single highest-leverage component. The agent doing the work **cannot** be the agent
judging the work.

- Agents working toward a goal without an *independent* grader reinforce each other's
  reasoning instead of catching it.
- The verifier runs on **different instructions / different framing** so it does not reason
  into the same blind spot.
- Verify against **objective criteria** — tests pass, schema validates, a rule holds —
  never against the swarm's own confidence.
- **The verifier is also the engine of self-improvement:** its pass/fail signal is the
  ground truth the system learns from (see Self-Improvement below).

### 2. Orchestrator + Verifiable Stopping Condition
Swarms do not self-organize. Something must **decompose** the goal, **route** subtasks,
**merge** results, **resolve conflicts**, and enforce a **verifiable stopping condition**
per agent. Without an orchestrator, more agents = more chaos, not more output.

---

## The Full Formula

```
Plan mode (decompose)
        ↓
Orchestrator (route + merge)  ←──────────────┐
        ↓                                     │
Spawn specialized agents in parallel loops    │
   (CALL the spawn tool — do not simulate)    │
        ↓                                     │
Independent verifier (grade vs objective criteria)
        ↓                                     │
Dynamic re-planning from verified results     │
        ↓                                     │
Capture what worked → SELF-IMPROVE ───────────┘
   (update the versioned context artifact)
        ↓
Stop on verified condition
```

The loop back from **self-improve → orchestrator** is what makes the system get better
every run instead of repeating the same mistakes.

---

## Operating Principles

- **Scale agents to the work — and verify independently.** Spawn as many as the task genuinely
  needs; what makes them *effective* (not merely numerous) is independent verification — a swarm that
  grades its own work is worse than a smaller one that's checked. So scale freely, but pair the
  spawning with independent verification that scales with it.
- **Swarms fail in correlated ways.** Agents sharing one base model and framing share blind
  spots — they can be wrong *together*. Independent verification breaks the correlation.
- **Autonomy raises the stakes, not just the speed.** More agents + more autonomy + more
  self-modification = more surface for fast, expensive mistakes. The verifier, the gate, and
  versioned rollback matter *more* as you scale, not less.
- **Fail safe.** On agent error, timeout, or bad input, the loop halts — it does not keep
  running on stale or corrupted state, and it does not learn from a corrupted cycle.
- **Measure output per unit risk and cost**, not per unit activity.

---

## One-Line Summary

The formula is *loops + plan mode + dynamic workflows + multiple agents* **plus independent
verification, plus an orchestrator with verifiable stopping conditions, plus disciplined
spawning (every agent scoped + verified), plus guarded self-improvement.** The last four convert a swarm from impressive to
effective and compounding.

---

# Agent Spawning — Agents That Create Agents

Agents create more agents by **calling a spawn tool** — as many as the work needs (the only ceiling
is Claude Code's own: 16 concurrent / depth 5 / 1000 per run). The parent
does not write code that becomes an agent — it **invokes the tool**, and the orchestration
layer instantiates the sub-agent.

## Calling the Tool (read this first)

> **To create a sub-agent, CALL the spawn tool.** Do not describe, narrate, plan,
> or simulate spawning in prose — that produces nothing. Spawning happens **only** when the
> tool is actually invoked. The same rule applies to the other control tools:
> - To verify work → **call the verify tool** (never self-grade in prose).
> - To request an irreversible action → **call the approval tool** (never act
>   directly).
> - To record a learned improvement → **call the update-context tool** (never keep it in
>   transient memory — if it isn't written, it didn't happen).
>
> If a required tool is unavailable, **halt and report** — do not work around a missing
> control by faking it in text.

### Tool mapping in THIS deployment (Claude × Grok NEXUS)

| Spec control tool | Concrete invocation here | Never substitute with |
|---|---|---|
| `spawn_agent` | Claude **Task tool** (parallel subagents) · `grok -p "<self-contained sub-task>"` (peer co-builder) | Prose describing a "subagent" |
| `verify` | An **independent** checker subagent on different framing · Grok cross-vendor review · an objective command (tests/`node --check`/schema) | Self-grading in your own narration |
| `request_approval` | **Halt and ask the user** before any irreversible external action (you boot autonomous — there is NO plan-mode gate, so YOU must stop and surface it) | Acting directly on an irreversible external action |
| `update_context` | Append to `./LEARNINGS.md` (verified lessons) · edit this `SWARM_ARCHITECTURE.md` (process changes) | A lesson "remembered" only in session |

## The Spawn Tool Contract

Every spawn call must carry these fields. None are optional.

```
spawn_agent({
  role:               // what this agent IS (its identity = its scope)
  task:               // the specific outcome it owns
  context:            // only the slice it needs — not the parent's whole context
  stopping_condition: // the objective check that means "done"
  depth:              // current tree depth (auto-incremented, capped)
  budget:             // token/time ceiling for this agent + its descendants
})
```

A spawned agent gets its **own clean context window** — that is the point of spawning
rather than cramming work into one agent. Isolation keeps each agent's reasoning sharp and
lets them run in parallel.

## Patterns

- **Orchestrator–worker** — lead decomposes, **calls the spawn tool** once per independent
  subtask, merges results. The default.
- **Recursive decomposition** — a worker whose slice is still too big **calls the spawn
  tool** itself; the tree fans out until tasks are executable, then collapses back up.
- **Writer/checker spawn** — the parent spawns a worker *and* **calls the spawn tool again**
  for a separate verifier of that worker's output.

## Merge-Back

Sub-agents return results to the parent. The parent synthesizes, resolves conflicts, decides
what is next (including whether to call the spawn tool again), and **feeds the verified
result into the self-improvement step**. Results flow up; authority stays at the top.

---

## Tuned Defaults (set from this deployment's profile)

> Profile: **mixed workloads** (code / research / monitoring) · **human gate on irreversible
> actions** · priority order **speed > accuracy > cost > traceability** · **dual-brain Grok floor:
> ≥25% (target 25–50%) of substantive work per run is Grok's** (design / components / code
> suggestions+critique / review — substantial owned work, not gratuitous pings).

### 1. Workload is mixed → spawn by task type, not one rule for all

| Spawned agent type | Parallelize? | Verification |
|---|---|---|
| **Code / build** | Yes, aggressively | Independent checker runs tests/schema before merge; **Grok also suggests + criticizes the code** and agents take the best pieces to converge on the most accurate code |
| **Design / UI / creative** | **Grok leads** (creative prospecting + aesthetic) | Grok owns the look so it's *extremely* good, AND verifies the UI works correctly (states/interactions/responsiveness); independent agent confirms behavior |
| **Research / data** | Yes, aggressively | Cross-check across ≥2 independent sources; verifier flags single-source claims |
| **Monitoring / analysis** | Yes | Verifier confirms the signal against raw state before it propagates |

Rule: **any agent producing an artifact another agent or a human will act on gets an
independent verifier** (call the verify tool). Pure read/observe agents may skip it.

### 2. Human gate on irreversible actions → spawning cannot bypass the gate
- Spawned agents inherit a **hard permission boundary**: no descendant holds an authority
  the parent did not have. **Spawning never escalates privilege. Self-improvement never
  escalates privilege.**
- Any action that **spends money, places an order, writes to production, or sends an
  external message** → the agent **calls the approval tool and stops.** A human approves
  before it executes.
- The gate lives at the **execution boundary**, not inside an agent's judgment — so it holds
  no matter how deep the tree or how confident (or how "improved") the agent.

### 3. Priority is speed-first → bias toward parallel, no artificial cap

| Cap | Default | Why |
|---|---|---|
| **Max spawn depth** | no artificial cap (Claude Code hard ceiling = 5) | Spawn as deep as the work needs |
| **Max concurrent agents** | **no artificial cap — as many as the task needs** (Claude Code hard ceiling = 16) | More agents on parallelizable work is the goal; user monitors live |
| **Per-run budget** | none (was the API-priced `--max-budget-usd`; removed — it didn't reflect subscription usage) | Bounded only by wall-clock timeout + the subscription rate-limit window |
| **Total per run** | Claude Code hard ceiling = 1000 | The real fork-bomb backstop |
| **Spawn requires** | role + scope + stopping condition | The quality bar — an agent with none of these is not created (this stays) |

Accuracy is #2, so the verifier requirement is **not** traded for speed — parallelism scales
throughput, the verifier protects correctness, they run together.

### 4. Traceability is #4 but not zero → log the spawn tree
Log every spawn and every self-improvement (who/what/result/cost/version) so a bad run is
reconstructable and any change is reversible.

---

# Self-Improvement — The System That Rewrites Its Own Process

This is the compounding engine: the swarm learns from its own **verified** outcomes and
gets better every run. Done right, it is the highest-leverage capability in the stack. Done
wrong, it is the fastest way to drift. The difference is entirely in the guardrails — so the
emphasis here is **aggressive improvement inside hard rails.**

## The Core Self-Improvement Loop

```
Run → Verifier grades against the FIXED external metric
    → Capture: what passed, what failed, why (CALL update_context)
    → Propose a process change (better prompt / routing / signal weighting)
    → A SEPARATE agent verifies the proposed change is actually better
    → Version it, apply it, keep the old version for rollback
    → Next run uses the improved process
```

The system improves by **editing its own context/instructions artifact** — the persistent
"source of truth" every agent reads at the start of a run (this file + `LEARNINGS.md`).
Improvement = better instructions for next time, captured in a file, not vibes held in a
session.

## What Agents Are Allowed to Improve (and what they are NOT)

| Allowed to self-improve | Never self-modifiable |
|---|---|
| Prompts / instructions / role definitions | Its own permission boundary |
| Routing logic (which agent gets which task) | The human approval gate |
| Signal weighting / prioritization heuristics | The success metric it is graded against |
| Decomposition strategy | Claude Code's hard limits + the per-spawn scope/stopping-condition discipline |
| Output format / verification checks | Its own ability to disable the verifier |

**The one rule that prevents everything from going wrong:** an agent may improve its
**process**, never its **permissions** and never its **scorecard.** A system that can edit
the metric it is judged by will "improve" by making the metric easier to hit — that is
reward hacking, and it looks exactly like progress until it isn't.

## The Fixed External Metric (anti-reward-hacking)

- Success is graded against a metric the agents **cannot read, reach, or alter** — it lives
  outside the swarm.
- Improvement is only accepted when it moves that fixed metric, verified by an independent
  agent — not when an agent *claims* it improved.
- If "improvement" optimizes for *more output / more signals / faster passes* rather than
  *better verified outcomes*, the metric is wrong — tighten it. A self-improving loop will
  find and exploit a loose metric every time.

## Capture, Version, Roll Back

- Every accepted improvement is **written to the versioned context artifact** (call
  update_context) with a note on *why*. If it isn't written, the learning is lost on the
  next clean context.
- Every version is kept. A change that looks good locally but degrades global results gets
  **rolled back to the prior version** — no self-improvement is permanent until it has
  survived multiple verified runs.
- Self-modifications that touch anything near the gate or permissions are **proposed only**
  → they go through the approval tool for a human before taking effect.

## Self-Improvement Failure Modes (and the guardrail for each)

- **Reward hacking** — agent optimizes the metric instead of the goal. → Fixed external
  metric the agent cannot alter.
- **Drift** — small "improvements" compound into a system optimizing the wrong thing. →
  Independent verification of every change + versioned rollback.
- **Learning from a bad cycle** — the loop "improves" off a corrupted/error run. → Fail-safe
  halt; only **verified, clean** runs feed the improvement step.
- **Silent capability creep** — self-improvement quietly expands what an agent can do. →
  Permissions and the gate are in the never-self-modifiable column, full stop.
- **Unversioned change** — a regression with no way back. → Every change written, versioned,
  and reversible via update_context.

---

## Spawning Failure Modes

- **Runaway spawning** — recursion run amok could fork-bomb into hundreds of agents. → Claude Code's
  own hard ceiling (1000 total · depth 5 · 16 concurrent per run) is the backstop, plus the user
  monitors live and interrupts (Esc) if needed. No artificial cap — spawning as many as the task needs
  is intended; every spawn still requires role + scope + stopping condition (the quality bar).
- **Correlated failure at scale** — a wrong premise seeds every descendant. → Independent
  verification with different framing.
- **Privilege creep** — a deep agent able to act without the gate. → Inherited permission
  boundary; gate at the execution boundary.
- **Lost observability** — an untraceable tree. → The spawn + improvement log.
