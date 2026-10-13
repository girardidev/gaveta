---
# gaveta-885f
title: 'Gaveta skill: how to use the MCP'
status: todo
type: task
created_at: 2026-10-12T18:07:03Z
updated_at: 2026-10-12T18:07:03Z
parent: gaveta-q2i5
blocked_by:
    - gaveta-txxh
    - gaveta-jgsl
---

Write `skills/gaveta/SKILL.md` (English; load `writing-for-agents` first). The description must trigger before any gaveta MCP call (mention list_folders, list_dir, read_file, stat, search, write_file, edit_file; shared folders, notes, Obsidian vault).

Content: start with list_folders; path formats (alias preferred); which tool for which job; paginate read_file with offset/limit; prefer edit_file over write_file for partial changes; never probe paths or bypass with .. or symlinks; macOS TCC errors mean ask the user; the agent cannot add folders, ask the user to run `gaveta add`.

## Todo
- [ ] Write SKILL.md reflecting the final tool set
- [ ] Link/copy into ~/.config/opencode/skills and ~/.claude/skills and test in a real session with the MCP on
- [ ] README mention
- [ ] Decide whether `gaveta install` should install the skill (follow-up bean if yes)
