---
name: claude-dev-pipeline
description: Use when starting a multi-phase feature or refactor that will be implemented via subagents (user says "use the pipeline", "normal plan", "resume the plan", "run the final gate", or kicks off work against a design + implementation-plan doc pair). Three sessions - an Opus xhigh planning session writes resumable design/plan docs; an Opus medium coordination session dispatches Sonnet/Opus implementers and Haiku workers and gives each increment dual review (coordinator + Codex gpt-5.6-terra high); a fresh Opus xhigh session runs the final whole-branch seam review with Codex gpt-6.1-sol before user QA. Fable only as an architecture/security advisor after Rade confirms. Encodes token-economy rules and the prime directives.
---

# Claude Dev Pipeline

The standing workflow for multi-phase backend work (proven on BEP-1877, BEP-1969/1967 legal-docs
as `fable-dev-pipeline`; remapped to the 5.5 model family 2026-10-08). Opus plans, coordinates and
reviews; subagents type; Codex provides external breadth. Plans are lean (decisions + file:line
pointers + traps), never near-final code — see `lean-plans-delegation-pipeline.md` in this skill's
directory.

## Prime directives

The five directives in `prime-directives.md` in this skill's directory apply to every stage and
every agent. Read the file when the skill loads. Paste the directives into every implementer and
reviewer brief.

## Sessions and roles

The design and plan docs hold the pipeline's state, so each stage runs in its own session. Your
own effort level is not visible to you: when the conversation does not make the stage clear, ask
Rade which stage this session is for. End each stage by giving Rade the command that starts the
next one.

| Stage | Start command, then say | Runs |
| --- | --- | --- |
| 1. Plan | `claude --model opus --effort xhigh` — "plan <ticket>" | research, interview, design.md + implementation-plan.md |
| 2. Coordinate | `claude --model opus --effort medium` — "resume the plan" | dispatch, per-increment review, status notes |
| 3. Final gate | `claude --model opus --effort xhigh` — "run the final gate" | whole-branch seam review, Codex sol, full verify |

A usage-limit kill or a laptop swap mid-stage is normal: start a new session of the same stage.

| Role | Model | Agent tool params |
| --- | --- | --- |
| Light investigation (Explore fan-out) | Haiku 5.5 | `model: haiku, effort: low` |
| Cross-repo / external research needing judgment | Sonnet 5.5 | `model: sonnet, effort: medium` |
| Implementer, default | Sonnet 5.5 | `model: sonnet, effort: medium` |
| Implementer, judgment-heavy task | Opus 5.5 | `model: opus, effort: medium` |
| Mechanical worker, one item class | Haiku 5.5 | `model: haiku, effort: low` |
| Architecture / security advisor | Fable 5.1 | `model: fable, effort: high` — only after Rade confirms |

Always pass `effort` explicitly; without it a subagent runs at its default.

## Stage 1 — Plan (Opus xhigh)

1. Fan out research where parallelizable, using the role table above. Read the load-bearing
   files yourself.
2. **Verify every integration seam the plan names** — actual call path, not assumed
   (grep the send site, the facade chain, the event listeners). A plan that says "find the
   MailService call site" when reality is a 4-class async event pipeline makes the implementer
   pay discovery tokens and causes plan drift. Verified facts go into the plan as
   "verified facts for the implementer" so nobody re-derives them.
3. Interview Rade on genuine decision points (AskUserQuestion), not on things the repo answers.
4. Write TWO resumable handover docs in the repo at `<repo>/docs/` — **untracked, never
   committed** (in-repo so read-only Codex can read them; guard: stage explicit paths only,
   never `git add .`/`git add docs`):
   - **design.md** — decisions, API contracts, corrections to any source handover, open items with owners.
   - **implementation-plan.md** — phases, what/where/order, traps ("STOP and escalate if X"),
     cross-cutting rules. Lean: pointers, not code. **Each task names its implementer model and
     effort** (see below); a Haiku task carries its per-item brief.
5. **Status notes in the plan doc are the pipeline's externalized state.** Update them after
   every increment (commits + hashes, review state, decisions, deviations) — not at session end.

### Choosing the implementer (planner decides per task)

- **Sonnet 5.5, medium** — the default. Follows a lean plan with pointers.
- **Opus 5.5, medium** — the task contains a decision the plan cannot make in advance: a design
  choice inside the task, a transaction or concurrency seam, call sites with differing semantics.
  Opus costs 2× Sonnet per token; one avoided fix round covers that.
- **Haiku 5.5, low** — many independent mechanical items (next section).
- Effort `high` only on a task the plan marks as hard.

## Haiku workers

For many independent items that each need reading but no design decision: OCR of an image batch,
applying one documented change pattern to N files, extracting fields from N documents, light
lookups ("which of these 40 classes override X").

- **A tool goes first.** Symbol renames, moves and signature changes go to the JetBrains
  `rename_refactoring` MCP (or the IDE / LSP); a change a regex states exactly goes to a
  `sed`/`rg` script. Haiku takes only what neither covers — YAML keys, docs, strings, comments
  that must be read to decide.
- **The brief is detailed on purpose.** One brief per item class, reused for every item: exact
  input, the transformation with one worked example, the output format, and the STOP rule (an
  item that does not fit the pattern is reported untouched, never improvised). This is the only
  place in the pipeline for superpowers-level detail, because it is written once and used N times.
- **One owner per file.** Each worker gets a disjoint set of files; two workers never edit one file.
- **Dispatch.** Up to ~10 workers as parallel Agent calls in one message. For more, batch several
  items per worker, or use the Workflow tool (load `workflow-authoring` first); the session's
  workflow size guideline still applies, so state the agent count and ask Rade to raise the
  guideline in `/config` when the batch needs it.
- **Each worker returns one line per item**: item, `done` / `skipped` / `stopped`, note.
- **Never merge Haiku output unchecked.** Use a deterministic check where one exists (compile,
  scoped tests, a grep for leftovers, schema validation). Where none exists (OCR, extraction),
  read a sample yourself — 10% or 5 items, whichever is more. A systematic error means fixing the
  brief and re-running the batch; patch single items only for one-off errors.

## Stage 2 — Implementation (Opus medium coordinator)

- One implementer subagent per phase/task, with the model and effort the plan names. The
  subagent gets: the plan section, the doc paths, repo-rules pointers, the prime directives,
  and the Stage-1 verified facts — not a re-explanation.
- **After a failed attempt, re-dispatch one tier up** (Haiku → Sonnet → Opus) and record it in
  the status notes.
- **Keep-alive has a shelf life.** Follow-ups via `SendMessage` to the live implementer are
  cheapest while the phase is hot (warm cache, small transcript). Every resume replays the FULL
  transcript — a late fix once cost ~400k tokens for 8 tool calls. Rules of thumb:
  - same phase, same day → message the live agent;
  - different work type (audit, sweep, unrelated fix) → fresh agent with a tight brief;
  - fat transcript + long gap + small task → fresh agent; re-briefing is cheaper than replay.
- Escalation contract: when a plan assumption fails (missing method, dependency clash,
  Not-Invented-Here temptation), the subagent STOPS and reports specifics; the coordinator
  resolves and messages back.
- **Checkpoint-commit before anything long-running.** Interruptions must never orphan work
  in the working tree.
- **Verification economy:** per phase, compile + SCOPED tests only (`-Dtest=` the touched
  areas). No full `./mvnw verify` per phase, and an implementer NEVER babysits/polls a long
  build — full verify runs exactly once, in Stage 3, in background or by the user
  (user-run is fine; they report results).

## Codex model ids — pass the full id, always

Short names fail. `-m sol` returns `400 The 'sol' model is not supported when using Codex with a
ChatGPT account`, and that mistake has recurred across sessions. Copy the id from this table;
never shorten it and never add or drop a version prefix. Verified on codex-cli 0.156.1, 2026-09-23; `gpt-6.1-sol` probed on codex-cli 0.159.0, 2026-10-05.

| Id              | Tier (Claude equivalent) | Pipeline role                       |
| --------------- | ------------------------ | ----------------------------------- |
| `gpt-6-astra`   | Fable                    | none assigned yet                   |
| `gpt-6.1-sol`   | Opus                     | final-gate whole-branch review      |
| `gpt-6-sol`     | Opus                     | superseded by `gpt-6.1-sol`         |
| `gpt-5.6-terra` | Sonnet                   | per-increment review, high effort   |
| `gpt-6-luna`    | Haiku                    | none assigned                       |

When a new model appears, probe it before writing it anywhere:
`codex exec --skip-git-repo-check --sandbox read-only -m <id> "Reply with the single word OK." < /dev/null`.

## Dual review — every increment, both reviewers, not either/or

1. **Coordinator in-session** (not delegable — it holds the session context): diff
   param-by-param against plan + design; repo conventions (`.claude/rules/`), test naming
   (`*IT`/`*Test`), spec-first rule, prime directives.
2. **Codex, model `gpt-5.6-terra`, high effort** — external breadth, costs nothing against
   Anthropic limits. Dispatch via CLI in a background shell (MCP times out on long reviews):
   write the prompt to a scratch file, then
   `codex exec --sandbox read-only -m gpt-5.6-terra -c 'model_reasoning_effort="high"' "$(cat prompt.md)" < /dev/null > review.log 2>&1` (background).
   - `< /dev/null` is required: without it a backgrounded `codex exec` stops at "Reading
     additional input from stdin".
   - Reviewing another repo from a worktree-isolated session: the harness refuses an inline
     command that names the other repo's path. Put the `codex exec -C <repo> ...` line in a
     scratchpad script and run `bash <script>`.
   - **The prompt must scope, or the review is noise:** instruct Codex to READ the design/plan
     docs from the repo first; enumerate (a) what the range should contain, (b) planned-but-unbuilt
     work ("do not flag its absence"), (c) settled decisions (do not re-litigate).
   - **agy (Antigravity CLI) is the exception: it cannot review headless.** `agy -p` runs
     in print mode, which denies every shell command not matched by an allow rule in
     `~/.gemini/antigravity-cli/settings.json` (`permissions.allow`, e.g. `command(git diff)`).
     It then prints only "no output produced". agy picks a different command on each run
     (`git grep … || echo`, `find …`), so adding allow rules one at a time never converges, and
     `--dangerously-skip-permissions` is refused by auto mode. Give Rade the interactive command to
     run in his terminal, and read the verdict from the terminal when he says it is done:
     `agy -i "$(cat <prompt>.md)" --model gemini-3.1-pro-high --mode plan`.
   - **Give the range as base and head SHAs (`<base>..<head>`), never an inlined diff.** The
     reviewer runs `git diff`/`git log`/`git show` itself and reads the surrounding code from the
     repo. An inlined diff shows only the changed hunks and pads the prompt.
   - **State that a clean verdict is a fully successful review.** Findings must cite a concrete,
     REACHABLE failing execution path and must check for an existing framework mechanism first.
   - **A fast-returning run is a FAILED run until the log proves otherwise** — check the log tail
     for actual findings. Known trap: the 5.6 models are `code_mode_only` and need the
     `codex-code-mode-host` binary (missing from the 0.144.0 cask; `brew upgrade --cask codex` fixes).
3. The coordinator adjudicates both (superpowers:receiving-code-review discipline), routes
   accepted fixes per the keep-alive rules above, and updates the plan-doc status notes.

## Fable advisor — only after Rade confirms

Fable 5.1 bills Rade's subscription as overage. Use it only for an architecture or security
question that Opus at xhigh could not settle — never for implementation, increment review or
research. Any stage may raise it.

1. Ask with AskUserQuestion, stating: the question, what Opus concluded and why that is not
   enough, and the expected size (files to read, one answer or a discussion). Options: dispatch
   Fable / proceed with Opus's answer / Rade decides. One approval covers one question.
2. Dispatch `model: fable, effort: high`, read-only (no edits). The brief carries the question,
   the doc paths, file pointers, and the decisions already settled; ask for a recommendation with
   reasoning and risks.
3. Give Rade Fable's answer together with your own assessment; the decision goes into design.md.

## Stage 3 — Final gate (fresh Opus xhigh session)

The session reads design.md, the plan with its status notes, and the range `<base>..<head>`. It
has no implementation transcript, so it judges the branch as an outside reviewer would.

- **Whole-branch review focused on seams**: interactions BETWEEN subagent deliverables —
  transaction boundaries, duplicated helpers, contract drift between phases, spec-vs-impl match,
  security surface as a whole, resource completeness, debris grep (TODO/FIXME/System.out).
- **Codex whole-branch review on `gpt-6.1-sol`** (the Opus tier, above terra — reserve it for
  this gate, `gpt-5.6-terra` stays the in-phase reviewer): same CLI dispatch and prompt
  discipline as above, docs-first, full scope-out list including everything settled during the
  phases, and ask for an explicit MERGE / DO-NOT-MERGE verdict. Still zero Anthropic cost.
  No additional Anthropic-side reviewer agent — adjudication stays with this session.
- Optional when the branch grew defensively: an **extra-safe sweep** (fresh `model: sonnet,
  effort: medium` agent lists every defensive addition with file:line + what mechanism already
  covers it, classified REDUNDANT / REAL-INVARIANT / PRODUCT-BEHAVIOR / BOUNDARY-VALIDATION;
  Rade rules keep/remove).
- Accepted fixes go to a fresh implementer with a tight brief; record them in the status notes.
- One full `./mvnw verify` on the final tip; state actual results (known-failure exclusions by
  name), never assert green without evidence. Then hand to the user for QA acceptance.

## Anti-patterns

- Writing implementation code into the plan docs. Detailed instructions belong only in Haiku
  per-item briefs.
- Running a stage at the wrong effort: planning at medium, or a long coordination at xhigh.
- Dispatching Fable without Rade's confirmation for that specific question.
- Haiku workers on a rename a refactoring tool does; two workers on one file; Haiku output
  merged without a check.
- Messaging a fat, cold agent for a small task (replay cost) — or spawning fresh mid-phase
  for what the hot implementer can do (re-brief cost). Both directions are real.
- Codex-only review (the coordinator's in-session review is mandatory, and vice versa).
- Review prompts without scope-outs — produces "findings" that are just the unbuilt plan.
- Guards/where-clauses duplicating what Hibernate/Spring/DB constraints guarantee.
- Tests asserting log output; tests of library internals (behavior PINS are fine).
- Hand-rolled implementations of solved algorithms.
- An implementer polling a long build instead of handing it off.
- Letting a subagent improvise around a broken plan assumption instead of stopping.
- `git add .` in a repo with untracked handover docs.
