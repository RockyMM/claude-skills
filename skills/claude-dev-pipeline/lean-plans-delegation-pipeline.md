# Lean plans + delegation pipeline (all projects)

Rade explicitly rejected the superpowers:writing-plans format (checkbox TDD micro-steps, complete code in every step) as "too detailed, nearly 1-1 copy of the final code, so what's the purpose then?" — especially wasteful for refactors where the code already exists in the repo.

**Why:** the planner's output tokens are the expensive ones (Opus 5.5 at xhigh); the planner writing near-final code in a plan so Sonnet can transcribe it is backwards. Also plans that duplicate existing code add no information over precise pointers.

**How to apply:** Plans = decisions + precise file:line pointers + traps/judgment calls; implementers do the typing. The one exception is a Haiku worker brief: it is written once for a class of item and reused N times, so it carries superpowers-level detail. Established pipeline (worked well on a multi-phase backend feature; remapped to the 5.5 family 2026-10-08):

1. Opus 5.5 at xhigh investigates and designs (planning session)
2. Lean plan (decisions, pointers, traps — not code); each task names its implementer model and effort
3. An Opus 5.5 medium coordination session dispatches ONE implementer per task (Sonnet 5.5 by default, Opus 5.5 for judgment-heavy tasks, Haiku 5.5 workers for mechanical per-item work)
4. The coordinator reviews the diff itself, param-by-param (no separate reviewer subagent per task)
5. Endgame, whole branch: a fresh Opus xhigh session does the whole-branch review itself AND dispatches a Codex code review (model `gpt-6.1-sol` for this merge gate; `gpt-5.6-terra` high effort for in-phase increment reviews — full ids only, short names like `sol` are rejected; table in the claude-dev-pipeline skill) plus a Gemini review via agy; never Codex alone
6. User does final QA acceptance

Fable 5.1 is an architecture/security advisor only, dispatched after Rade confirms each question (it bills as subscription overage).

Follow-up questions to a still-loaded implementer agent are cheaper than re-briefing anyone — prefer SendMessage to the existing agent over dispatching a fresh one. **Shelf-life caveat (2026-07-10 retro):** a resume replays the agent's full transcript at cold-cache prices — a late small fix once cost ~400k tokens for 8 tool calls. Same phase + same day → message the live agent; long gap, fat transcript, or different work type → fresh agent with a tight brief.

The full evolved pipeline (prime directives incl. trust-the-framework/Not-Invented-Here, review-prompt scoping contract, verification economy, interruption resilience) lives in the installed `claude-dev-pipeline` skill (`~/.claude/skills/claude-dev-pipeline/SKILL.md`) — invoke it for any multi-phase feature/refactor.

Source: repo `RockyMM/claude-skills`, `skills/claude-dev-pipeline/`; `~/.claude/rules/` holds a symlink to it. Edit it in the repo.

Origin: a project memory, made global on 2026-07-03 after a superpowers-style plan was written against this preference.
