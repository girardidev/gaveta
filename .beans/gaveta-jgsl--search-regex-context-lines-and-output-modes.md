---
# gaveta-jgsl
title: 'search: regex, context lines and output modes'
status: todo
type: feature
priority: high
created_at: 2026-10-12T18:07:03Z
updated_at: 2026-10-12T18:07:03Z
parent: gaveta-q2i5
---

Today search is literal-only, mixes file names and contents, and returns one line per match. Claude's Grep and rg-based GPT workflows expect regex, context and a files-only mode. Keep backward compatibility: existing params keep their meaning.

## Todo
- [ ] `regex: bool` (NSRegularExpression; invalid pattern gives invalidArgument)
- [ ] `context` (lines before/after, small max) returned with each content match
- [ ] `output`: `matches` (default), `files` (unique paths), `count`
- [ ] `target`: `names`, `content`, `both` (default), so Glob-like and Grep-like use are possible
- [ ] Keep 200-result cap, ignored dirs, symlink and binary skipping
- [ ] Tests for each option, plus regex vs literal escaping
- [ ] README and tool schema descriptions
