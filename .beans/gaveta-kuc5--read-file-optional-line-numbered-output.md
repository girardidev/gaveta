---
# gaveta-kuc5
title: 'read_file: optional line-numbered output'
status: todo
type: task
created_at: 2026-10-12T18:07:03Z
updated_at: 2026-10-12T18:07:03Z
parent: gaveta-q2i5
---

read_file returns raw content plus startLine/endLine. Both models cite and edit by line number, so add `numbered: bool` (default false to keep current behavior) prefixing each line like `   12<tab>content`. Check ToolHandler output first; if lines are hard to reference there, consider making it the default.

## Todo
- [ ] Add parameter and implement
- [ ] Tests (offset > 1, truncation, last line without trailing newline)
- [ ] README
