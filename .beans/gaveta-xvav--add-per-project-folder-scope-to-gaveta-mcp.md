---
# gaveta-xvav
title: Add per-project folder scope to gaveta mcp
status: completed
type: feature
priority: normal
created_at: 2026-10-23T15:41:05Z
updated_at: 2026-10-23T15:47:49Z
---

OpenSpec change: add-project-folder-scope. Let each project's MCP config list which shared folders (aliases) the server exposes, narrowing folders.json.

## Summary of Changes

- Added `FolderScope` and `FolderStore.policy(home:scope:)` (GavetaCore): scope only narrows `folders.json`.
- `ToolHandler` carries the scope; `isWriteEnabled` uses the scoped policy; unresolved aliases are reported to stderr and the log.
- `gaveta mcp --folder <alias>` and `gaveta config <client> --folder <alias>` (snippets and the Claude Code hint carry the scope).
- Tests for core, handler and client config; README documents per-project registration.
