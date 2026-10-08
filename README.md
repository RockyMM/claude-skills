# claude-skills

Claude Code skills and global rules shared between laptops.

## Install

```
git clone https://github.com/RockyMM/claude-skills.git ~/git/claude-skills
~/git/claude-skills/install.sh
```

`install.sh` symlinks `skills/claude-dev-pipeline/` into `~/.claude/skills/`, and its
`prime-directives.md` and `lean-plans-delegation-pipeline.md` into `~/.claude/rules/`. Anything
already at those paths is moved to `~/.claude-backup/<timestamp>/`.

Delete an old `~/.claude/skills/fable-dev-pipeline/` if the laptop has one; it triggers on the same
requests.

## Update

Edit the files here, commit and push. On the other laptop, `git pull`.

## claude.ai

Zip `skills/claude-dev-pipeline/` and upload it as a skill.
