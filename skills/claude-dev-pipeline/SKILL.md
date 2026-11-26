---
name: claude-dev-pipeline
description: Use when starting a multi-phase feature or refactor that will be implemented via subagents (user says "use the pipeline", "normal plan", "resume the plan", "run the final gate", or kicks off work against a design + implementation-plan doc pair). Three sessions - an Opus xhigh planning session writes resumable design/plan docs; an Opus medium coordination session dispatches Sonnet/Opus implementers and Haiku workers, gives each increment layered review (coordinator + Codex gpt-6.1-terra high + Gemini gemini-4-neon-high via agy), commits each phase before its review and amends the accepted fixes into it; a fresh Opus xhigh session runs the final whole-branch seam review with Codex gpt-6.2-sol and Gemini gemini-4-neon-xhigh before user QA. Fable only as an architecture/security advisor after Rade confirms. Encodes token-economy rules and the prime directives.
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
never shorten it and never add or drop a version prefix. Verified on codex-cli 0.156.1, 2026-09-23; `gpt-6.1-sol` probed on codex-cli 0.159.0, 2026-10-05;
`gpt-6.1-terra` probed on codex-cli 0.162.1, 2026-10-30; `gpt-6.2-sol` and `gpt-6.2-astra` probed on
codex-cli 0.172.0, 2026-11-24 (older CLIs reject the 6.2 models).

| Id              | Tier (Claude equivalent) | Pipeline role                          |
| --------------- | ------------------------ | -------------------------------------- |
| `gpt-6.2-astra` | Fable                    | UI/UX second opinion, on request only  |
| `gpt-6-astra`   | Fable                    | superseded by `gpt-6.2-astra`          |
| `gpt-6.2-sol`   | Opus                     | final-gate whole-branch review         |
| `gpt-6.1-sol`   | Opus                     | superseded by `gpt-6.2-sol`            |
| `gpt-6-sol`     | Opus                     | superseded by `gpt-6.2-sol`            |
| `gpt-6.1-terra` | Sonnet                   | per-increment review, high effort      |
| `gpt-5.6-terra` | Sonnet                   | superseded by `gpt-6.1-terra`          |
| `gpt-6-luna`    | Haiku                    | none assigned                          |

Gemini via agy. Pass the full slug, which embeds the effort (`gemini-4-neon-high`). A bare
`gemini-4-neon` resolves to the server's default effort (high on 2026-11-26), which can change.
Verified on agy 1.5.15, 2026-11-23. Tiers follow published benchmarks, not Google's labels: Neon
outscores Argon, and Carbon (the top Gemini 4 model) is not on this subscription.

| Model family        | Efforts in agy | Tier (Claude equivalent) | Pipeline role                             |
| ------------------- | -------------- | ------------------------ | ----------------------------------------- |
| `gemini-4-neon`     | low–xhigh      | Opus                     | `-high` per increment, `-xhigh` final gate |
| `gemini-4-argon`    | low–high       | Opus (older, lower)      | none assigned                             |
| `gemini-4-hydrogen` | low–xhigh      | Haiku                    | none assigned                             |
| `gemini-3.8-flash`  | low–high       | Haiku                    | superseded by `gemini-4-neon`             |

Before the first dispatch of a session, list what is installed. If a model is gone, report it
and ask; never silently substitute a neighbouring version.

```bash
python3 -c "import json,os;print(' '.join(m['slug'] for m in json.load(open(os.path.expanduser('~/.codex/models_cache.json')))['models']))"
agy models
```

Other Codex clients share `models_cache.json`. An older one rewrites it without the newest models:
the app-server daemon (which also serves the interactive `/model` picker) or the CLI bundled
in the ChatGPT app. If a model is missing, compare the versions in `codex app-server daemon version`,
run `codex app-server daemon update` if they differ, then probe the model.

When a new model appears, probe it before writing it anywhere:
`codex exec --skip-git-repo-check --sandbox read-only -m <id> "Reply with the single word OK." < /dev/null`.

## Layered review — every increment, every reviewer, not either/or

1. **Coordinator in-session** (not delegable — it holds the session context): diff
   param-by-param against plan + design; repo conventions (`.claude/rules/`), test naming
   (`*IT`/`*Test`), spec-first rule, prime directives.
2. **Codex, model `gpt-6.1-terra`, high effort** — external breadth, costs nothing against
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
- **State the working-tree situation:** which commits are in scope (the phase commit is always
  among them, see the commit gate), and whether uncommitted edits exist and should be reviewed.
  Reviewers act on this — one spotted an unstaged fix mid-review and adjusted its verdict.
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
- **Gemini** reads the real repo too, since it always runs with `--dangerously-skip-permissions`
  (see "Dispatching Gemini"): give it the SHA range like Codex, and point it at the same files.

Worked example (2026-09-07): a Keycloakify login page was ejected and customised. Given only the
diff, Gemini reported as its top merge blocker that the ejection had "dropped" the
`showTryAnotherWayLink` form, quoting stock code that does not exist in that file — the form lives
in the theme's own unchanged `Template.tsx`. It also flagged a condition that was byte-identical
to upstream. Codex, reading the repo, refuted both: two fabricated blockers from one missing file.

### Dispatching Codex

The CLI in a background shell (MCP times out on long reviews). Write the prompt to a scratch
file, then:
`codex exec --sandbox read-only -m gpt-6.1-terra -c 'model_reasoning_effort="high"' "$(cat prompt.md)" < /dev/null > review.log 2>&1` (background).

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
`~/.gemini/antigravity-cli/settings.json`, and adding allow rules one at a time never converges
(agy picks a different command on each run). Always pass `--dangerously-skip-permissions`, together
with `--mode plan --sandbox`: then it runs `git show`/`git diff`/`git grep` itself and reads the repo,
so the prompt carries the SHA range and doc paths, like the Codex prompt. Verified on agy 1.5.18,
2026-11-26: it ran git and left the tree untouched. The commit gate plus the `git status` comparison
after the run is the safety net, as for Codex.

```bash
agy --model gemini-4-neon-high --mode plan --sandbox --dangerously-skip-permissions \
  --output-format stream-json --print-timeout 60m --print "$(cat prompt.md)" \
  > agy-review.jsonl 2> agy-stderr.log
jq -r 'select(.event=="result") | .result | "status=\(.status) finished_reason=\(.finished_reason // "-") denied=\(.denied_actions // [] | length)"' agy-review.jsonl
jq -r 'select(.event=="result") | .result.response' agy-review.jsonl > agy-review.md
```

- Start it with the Bash tool's `run_in_background`; the harness notifies on exit, so there is no
  600 s cap and nothing to poll. Background, foreground and detached `nohup` runs all returned
  the full review (agy 1.5.18, 2026-11-26).
- A complete review is exit 0, `status=SUCCESS`, no `finished_reason`, non-empty `response`.
  Anything else is a failed run: read `agy-stderr.log` and re-dispatch.
- `denied` above 0, or stderr `no output produced — a tool required the "command" permission`,
  means a tool was auto-denied (still exit 0): the run lacked `--dangerously-skip-permissions`.
- `--print-timeout` defaults to unlimited; the 60m is a ceiling for a wedged background run.
  When it fires: exit 3, `finished_reason: print_timeout`, partial text in `response`.
- The first line (`init` event) carries `conversation_id` within seconds. If stdout is lost, the
  reply is the last `PLANNER_RESPONSE` without `tool_calls` in
  `~/.gemini/antigravity-cli/brain/<id>/.system_generated/logs/transcript_full.jsonl`.
- In plan mode a model can answer by writing `implementation_plan.md` under
  `~/.gemini/antigravity-cli/brain/<id>/` and printing only a link to it. Then `response` is not
  empty but holds no review: read that file, or tell the model to reply on stdout.
- Never `--continue`/`-c` (ambiguous "most recent"). Resume with `--conversation <id>` from the
  `init` line; `cache/last_conversations.json` keeps only the latest run per repo path.

## Commit gate — opens every phase review

A phase is committed before it is reviewed. An uncommitted phase turns a usage-limit kill or a
laptop swap into lost or half-applied work, and a dirty tree makes the next phase's diff
unreviewable: reviewers cannot tell phase N+1's changes from phase N's leftovers. A reviewer can
also edit files despite `--sandbox read-only` (Codex has); with the phase committed, `git status`
shows exactly what it touched and `git restore` undoes it without risk to the phase.

When the implementer reports and the repo's per-phase checks (lint, build, scoped tests) pass
with evidence:

1. `git status --short` — know exactly what will be staged, and confirm the handover docs are not
   among it.
2. **Stage explicit paths only.** Never `git add .` / `git add -A` / `git add docs`.
3. When the repo's formatter rewrites whole touched files (e.g. a Spotless ratchet), commit that
   formatting first and the change second, so the real diff stays readable. The branch needs only one
   formatting commit: a later phase may add another, and the coordinator squashes them into the first
   before the final gate (see "Before the final gate").
4. One commit per phase, message `<TICKET>: <what this phase delivered>`. Not "wip", not a squash
   of several phases.
5. Record the hash in the plan doc's status notes in the same turn.

Then review:

6. Save `git status --porcelain` before each external reviewer run and compare it afterwards. A
   reviewer's edits show as tracked changes; a file it created shows as a new untracked path. Do
   not `git clean` — the handover docs are untracked too. If anything changed, stop and tell
   Rade; he deals with the fallout.
7. Apply and adjudicate the review fixes, re-run the per-phase checks, and **amend them into the
   phase commit** (`git commit --amend`). After a push, fixes go in as a new commit instead —
   never rewrite pushed history. Update the hash in the status notes.

The phase is ACCEPTED when the amended commit passes its checks and the coordinator's review
found nothing outstanding. Only then does the next phase start.

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

## Before the final gate — reorganize the branch (coordinator)

The last coordinator step, before handing over: make the branch history readable for the gate's
reviewers and for Rade.

- Squash the formatting-only commits into one, placed before the first real commit that needs it
  (rebuild on a temporary branch with cherry-picks; `git diff <old tip> <new tip>` must be empty).
- Keep each phase's real commit as it is. Never rewrite other people's commits, and don't move commits
  across merge commits: leave a formatting commit that sits before a merge where it is.
- If the branch is pushed, this rewrite needs Rade's go and a `--force-with-lease` push. Record the
  old→new hash map in the plan's status notes, because review files cite the old hashes.

## Stage 3 — Final gate (fresh Opus xhigh session)

The session reads design.md, the plan with its status notes, and the range `<base>..<head>`. It
has no implementation transcript, so it judges the branch as an outside reviewer would.

- **Whole-branch review focused on seams**: interactions BETWEEN subagent deliverables —
  transaction boundaries, duplicated helpers, contract drift between phases, spec-vs-impl match,
  security surface as a whole, resource completeness, debris grep (TODO/FIXME/System.out).
- **Codex whole-branch review on `gpt-6.2-sol`** (the Opus tier, above terra — reserve it for
  this gate, `gpt-6.1-terra` stays the in-phase reviewer): same CLI dispatch and prompt
  discipline as above, docs-first, full scope-out list including everything settled during the
  phases, and ask for an explicit MERGE / DO-NOT-MERGE verdict. Still zero Anthropic cost.
- **Gemini whole-branch review on `gemini-4-neon-xhigh`** alongside sol, on the same scoped brief, unless the branch was
  trivial enough to skip Gemini in-phase. With `--dangerously-skip-permissions` it reviews the
  whole range itself, headless.
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
- Starting a phase while the previous one sits uncommitted or unreviewed, or letting an implementer
  commit.
- Reviewing an uncommitted phase: a reviewer's stray edits then mix with the phase's own.
- Messaging a fat, cold agent for a small task (replay cost) — or spawning fresh mid-phase
  for what the hot implementer can do (re-brief cost). Both directions are real.
- Codex-only review (the coordinator's in-session review is mandatory, and vice versa).
- Dropping the Gemini pass on anything beyond 1–2 trivial phases because "Codex already looked".
- Dispatching an external model by a remembered id without checking it is still installed, or
  silently falling back to a neighbouring version.
- Handing Gemini embedded files instead of the SHA range.
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
