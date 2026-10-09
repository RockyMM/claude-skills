---
name: claude-dev-pipeline
description: Use when starting a multi-phase feature or refactor that will be implemented via subagents (user says "use the pipeline", "normal plan", "resume the plan", "run the final gate", or kicks off work against a design + implementation-plan doc pair). Three sessions - an Opus xhigh planning session writes resumable design/plan docs; an Opus medium coordination session dispatches Sonnet/Opus implementers and Haiku workers, gives each increment layered review (coordinator + Codex gpt-5.6-terra high + Gemini via agy) and commits each accepted phase; a fresh Opus xhigh session runs the final whole-branch seam review with Codex gpt-6.1-sol and Gemini before user QA. Fable only as an architecture/security advisor after Rade confirms. Encodes token-economy rules and the prime directives.
---

# Claude Dev Pipeline

The standing workflow for multi-phase backend work (proven on several multi-phase features as
`fable-dev-pipeline`; remapped to the 5.5 model family 2026-10-08). Opus plans, coordinates and
reviews; subagents type; Codex and Gemini provide external breadth. Plans are lean (decisions +
file:line pointers + traps), never near-final code — see `lean-plans-delegation-pipeline.md` in
this skill's directory.

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
| 2. Coordinate | `claude --model opus --effort medium` — "resume the plan" | dispatch, per-increment review, phase commits, status notes |
| 3. Final gate | `claude --model opus --effort xhigh` — "run the final gate" | whole-branch seam review, Codex sol + Gemini, full verify |

A usage-limit kill, a laptop swap or a sleep mid-stage is normal: start a new session of the same
stage. The docs and the per-phase commits are what make that cheap.

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
- **Implementers never commit.** They leave work in the tree and report; the coordinator owns
  the history (see the commit gate).
- **Never cite the handover docs from code.** The docs are untracked and local, so `D2`,
  `Phase 1b`, `FIX 5` or "per the plan" resolve to nothing for anyone reading the repo or a diff
  on GitHub. A bare ticket key is fine; it resolves in the tracker. A comment explains the
  mechanism itself instead of deferring to a document the reader cannot open. Same for commit
  messages and PR bodies.
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
- **A phase ends with a commit.** Never start phase N+1 with phase N uncommitted.
- **Phases in different repositories may run in parallel** when the design already settles the
  contract between them (API shape, field names, enum values) or they share none. One
  implementer per repo; each phase still gets its own review and its own commit in its own repo.
  Same-repo phases stay sequential. If either side finds the contract must change, it STOPS and
  the coordinator re-syncs both before they continue.
- **Verification economy:** per phase, compile + SCOPED tests only (`-Dtest=` the touched
  areas). No full `./mvnw verify` per phase, and an implementer NEVER babysits/polls a long
  build — full verify runs exactly once, in Stage 3, in background or by the user
  (user-run is fine; they report results).

## External model ids — pass the full id, always

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

Gemini via agy: `gemini-3.8-flash-high` for headless reviews, `gemini-3.1-pro-high` for
interactive ones. agy slugs embed the effort (`gemini-3.8-flash-high`, not `--effort high`).

Before the first dispatch of a session, list what is installed. If a model is gone, report it
and ask; never silently substitute a neighbouring version.

```bash
python3 -c "import json,os;print(' '.join(m['slug'] for m in json.load(open(os.path.expanduser('~/.codex/models_cache.json')))['models']))"
agy models
```

When a new model appears, probe it before writing it anywhere:
`codex exec --skip-git-repo-check --sandbox read-only -m <id> "Reply with the single word OK." < /dev/null`.

## Layered review — every increment, every reviewer, not either/or

1. **Coordinator in-session** (not delegable — it holds the session context): diff
   param-by-param against plan + design; repo conventions (`.claude/rules/`), test naming
   (`*IT`/`*Test`), spec-first rule, prime directives.
2. **Codex, model `gpt-5.6-terra`, high effort** — external breadth, costs nothing against
   Anthropic limits. See "Dispatching Codex" below.
3. **Gemini via agy** — an independent second opinion that catches a different class of thing
   than Codex. Default on; skip it only when the whole piece of work is 1–2 mechanically simple
   phases. Dispatch it in the same round as Codex, with the same settled-decisions list, and read
   the two side by side. See "Dispatching Gemini" below.
4. The coordinator adjudicates all of them (superpowers:receiving-code-review discipline),
   routes accepted fixes per the keep-alive rules above, and updates the plan-doc status notes.
   Two reviewers repeating a claim is not proof — verify the premise (prime directive 5).

### Review prompts

- **Scope, or the review is noise:** instruct the reviewer to READ the design/plan docs first;
  enumerate (a) what the range should contain, (b) planned-but-unbuilt work ("do not flag its
  absence"), (c) settled decisions (do not re-litigate).
- **Give a repo-reading reviewer the range as base and head SHAs (`<base>..<head>`), never an
  inlined diff.** It runs `git diff`/`git log`/`git show` itself and reads the surrounding code.
- **State the working-tree situation:** which commits are in scope, and whether uncommitted edits
  exist and should be reviewed. Reviewers act on this — one spotted an unstaged fix mid-review and
  adjusted its verdict.
- **State that a clean verdict is a fully successful review.** Findings must cite a concrete,
  REACHABLE failing execution path and must check for an existing framework mechanism first.
- **A fast-returning or empty run is a FAILED run until the output proves otherwise.** Check the
  log for actual findings; report a tool failure, never a clean verdict, when there are none.

### Reviewers need the repo, not a diff

A reviewer that sees only changed lines invents defects in the lines it cannot see. It reads
missing context as missing code and reports it with full confidence.

- **Codex** reads the real repo under `--sandbox read-only`. Say so in the prompt, and point it at
  the files worth comparing (`node_modules/<lib>` for an ejected or overridden framework file, the
  sibling repo for a shared file).
- **Headless Gemini** reads nothing, so the prompt carries the code: the complete post-change
  contents of every touched file, plus any file the change ejects, overrides, extends or relies on.
  A diff hunk is orientation, not evidence.

Worked example (2026-09-07): a Keycloakify login page was ejected and customised. Given only the
diff, Gemini reported as its top merge blocker that the ejection had "dropped" the
`showTryAnotherWayLink` form, quoting stock code that does not exist in that file — the form lives
in the theme's own unchanged `Template.tsx`. It also flagged a condition that was byte-identical
to upstream. Codex, reading the repo, refuted both: two fabricated blockers from one missing file.

### Dispatching Codex

The CLI in a background shell (MCP times out on long reviews). Write the prompt to a scratch
file, then:
`codex exec --sandbox read-only -m gpt-5.6-terra -c 'model_reasoning_effort="high"' "$(cat prompt.md)" < /dev/null > review.log 2>&1` (background).

- `< /dev/null` is required: without it a backgrounded `codex exec` stops at "Reading
  additional input from stdin".
- Reviewing another repo from a worktree-isolated session: the harness refuses an inline
  command that names the other repo's path. Put the `codex exec -C <repo> ...` line in a
  scratchpad script and run `bash <script>`.
- **Run `git status` after every Codex run.** Codex has hijacked reviews: it announced "the
  repo's code-review workflow", returned a generic template citing files that do not exist, and
  once its delegated reviewer edited two files despite `--sandbox read-only` before reverting
  them. Treat such a run as failed.
- Known trap: the 5.6 models are `code_mode_only` and need the `codex-code-mode-host` binary
  (missing from the 0.144.0 cask; `brew upgrade --cask codex` fixes).

### Dispatching Gemini (agy)

agy's print mode denies every shell command not matched by an allow rule in
`~/.gemini/antigravity-cli/settings.json` (`permissions.allow`, e.g. `command(git diff)`). Adding
allow rules one at a time never converges, because agy picks a different command on each run
(`git grep … || echo`, `find …`), and auto mode refuses `--dangerously-skip-permissions`. Two
ways to run it:

- **Headless, when the prompt can carry everything:** whole files (see above), design/plan
  excerpts, and an instruction not to use tools.

  ```bash
  agy --model gemini-3.8-flash-high --mode plan --sandbox --print-timeout 10m \
    --print "$(cat prompt.md)" > agy-review.md 2> agy-stderr.log
  test -s agy-review.md
  ```

  - Run it in the foreground, with the Bash tool's `timeout` at its 600000 ms maximum.
    Backgrounded, agy exits 0 with empty stdout. A short foreground smoke test succeeds, so it
    looks like a prompt-size problem when it is not.
  - `--print-timeout` defaults to 5m; raise it or the review dies mid-thought.
  - Exit 0 with empty stdout is not a review: check stderr and re-dispatch.
  - `--mode plan --sandbox` is the read-only posture.
  - Never `--continue`/`-c` (ambiguous "most recent"). Resume by the recorded `--conversation` id
    from `~/.gemini/antigravity-cli/cache/last_conversations.json`, keyed by repo path.
- **Interactive, when the reviewer must walk the repo** (too many files to embed, a whole-branch
  review): give Rade the command to run in his terminal, and read the verdict when he says it is
  done: `agy -i "$(cat <prompt>.md)" --model gemini-3.1-pro-high --mode plan`.

## Commit gate — closes every phase

A phase is not done until it is committed. The coordinator commits each ACCEPTED phase before the
next one starts. An uncommitted phase turns a usage-limit kill or a laptop swap into lost or
half-applied work, and a dirty tree makes the next phase's diff unreviewable: reviewers cannot
tell phase N+1's changes from phase N's leftovers.

A phase is ACCEPTED when the review fixes are applied and adjudicated, the repo's per-phase checks
(lint, build, scoped tests) pass with evidence, and the coordinator's review found nothing
outstanding. Then, in order:

1. `git status --short` — know exactly what will be staged, and confirm the handover docs are not
   among it.
2. **Stage explicit paths only.** Never `git add .` / `git add -A` / `git add docs`.
3. When the repo's formatter rewrites whole touched files (e.g. a Spotless ratchet), commit that
   formatting first and the change second, so the real diff stays readable.
4. One commit per phase, message `<TICKET>: <what this phase delivered>`. Not "wip", not a squash
   of several phases.
5. Record the hash in the plan doc's status notes in the same turn.

Commit, do not push, and do not open a PR unless Rade asks. Branch work stays local until the
final gate and his QA acceptance.

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
- **Gemini whole-branch review** alongside sol, on the same scoped brief, unless the branch was
  trivial enough to skip Gemini in-phase. A whole branch rarely fits in a headless prompt, so
  this one is usually interactive.
- No additional Anthropic-side reviewer agent — adjudication stays with this session.
- Optional when the branch grew defensively: an **extra-safe sweep** (fresh `model: sonnet,
  effort: medium` agent lists every defensive addition with file:line + what mechanism already
  covers it, classified REDUNDANT / REAL-INVARIANT / PRODUCT-BEHAVIOR / BOUNDARY-VALIDATION;
  Rade rules keep/remove).
- Accepted fixes go to a fresh implementer with a tight brief; commit them per the commit gate
  and record them in the status notes.
- One full `./mvnw verify` on the final tip; state actual results (known-failure exclusions by
  name), never assert green without evidence. Then hand to the user for QA acceptance.

## Anti-patterns

- Writing implementation code into the plan docs — or the reverse, leaking plan-doc identifiers
  (`D2`, `Phase 1b`, `FIX 5`) into code comments, commit messages or PR bodies. Detailed
  instructions belong only in Haiku per-item briefs.
- Running a stage at the wrong effort: planning at medium, or a long coordination at xhigh.
- Dispatching Fable without Rade's confirmation for that specific question.
- Haiku workers on a rename a refactoring tool does; two workers on one file; Haiku output
  merged without a check.
- Starting a phase while the previous one sits uncommitted, or letting an implementer commit.
- Messaging a fat, cold agent for a small task (replay cost) — or spawning fresh mid-phase
  for what the hot implementer can do (re-brief cost). Both directions are real.
- Codex-only review (the coordinator's in-session review is mandatory, and vice versa).
- Dropping the Gemini pass on anything beyond 1–2 trivial phases because "Codex already looked".
- Dispatching an external model by a remembered id without checking it is still installed, or
  silently falling back to a neighbouring version.
- Reporting an empty agy output or a suspiciously fast `codex exec` as a clean verdict.
- Review prompts without scope-outs — produces "findings" that are just the unbuilt plan.
- Handing a headless reviewer only a diff. It reports defects in the code it cannot see,
  especially where the change ejects or overrides a framework file.
- Guards/where-clauses duplicating what Hibernate/Spring/DB constraints guarantee.
- Tests asserting log output; tests of library internals (behavior PINS are fine).
- Hand-rolled implementations of solved algorithms.
- An implementer polling a long build instead of handing it off.
- Letting a subagent improvise around a broken plan assumption instead of stopping.
- `git add .` in a repo with untracked handover docs.
