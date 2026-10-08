# Prime directives (all projects, nearly all work)

Codified from the 2026-07-10 BEP-1969 retrospective. Directives 1–4 apply to nearly any work
Rade does; directive 5 applies whenever a code review is involved (any reviewer: Fable, Codex,
subagents). The `claude-dev-pipeline` skill pastes them into every implementer and reviewer brief.
Source: repo `RockyMM/claude-skills`, `skills/claude-dev-pipeline/`; `~/.claude/rules/` holds a
symlink to it. Edit it in the repo.

1. **Trust the framework in production code.** No guard for what an established mechanism
   already guarantees (Hibernate auto-enabled filters, `@Transactional` semantics, DB
   constraints, startup fail-fast, upstream validation in the same call chain). One caller
   re-checking a mechanism implies every caller should — that's how codebases rot into
   belt-and-suspenders noise. Defensive additions need Rade's explicit sign-off.

2. **Tests MAY pin framework/library behavior** as regression tripwires — the sanctioned
   counterpart to directive 1: trust in code, verify in tests. Blessed examples: a Pebble
   autoescape-on pin, a DB unique-constraint pin, a Hibernate-filter end-to-end pin.

3. **Never test log output** (shape, presence, wording) — unless logging is itself the theme
   of the work.

4. **No "Not Invented Here" reimplementation.** Known algorithms and solved problems
   (haversine, retry/backoff, parsing, hashing, ...) come from a library already on the
   classpath or a well-known one. Anyone — Fable or a subagent — tempted to hand-roll a
   solved problem stops and asks first. (Origin: an implementer once hand-rolled a 20-line
   haversine instead of using a library.)

5. **Review findings get verified before being acted on — in both directions.** Implementers
   verify a finding's premise against the actual code/framework before implementing the fix
   (a Hibernate `@Filter` once neutralized an entire "MAJOR" finding). Reviewers check for an
   existing framework mechanism before flagging a missing guard, and must cite a concrete,
   REACHABLE failing execution path — not a hypothetical. Review prompts must state that a
   clean verdict is a fully successful review, so reviewers don't manufacture findings to
   appear useful.
