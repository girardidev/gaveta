---
# gaveta-txxh
title: Add edit_file tool (exact string replace)
status: todo
type: feature
priority: high
created_at: 2026-10-12T18:07:03Z
updated_at: 2026-10-12T18:07:03Z
parent: gaveta-q2i5
---

New MCP tool `edit_file` in WriteTools, only exposed while a readwrite folder is active (same gating as write_file).

Contract: `path`, then either `old_string`/`new_string` (+ optional `replace_all`) or `edits: [{old_string,new_string}]` applied in order to the same file, atomically (all or nothing, single write).

## Todo
- [ ] FileTools.editFile: resolveAllowed(path, access: .write), regular file only, UTF-8 only, binary refused
- [ ] Fail when old_string is not found or matches more than once (unless replace_all); error says how many matches
- [ ] Reject empty old_string and old_string == new_string
- [ ] Resulting content within the 1 MB limit; preserve permissions, atomic write like write_file
- [ ] Register in ToolHandler/availableTools with the same writable gating and an activity log entry (no contents logged)
- [ ] Tests: unique match, no match, multiple matches, replace_all, multi-edit rollback, read-only folder denied, path escape denied
- [ ] README tool table
