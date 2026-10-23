## 1. Core scope model

- [x] 1.1 Add `FolderScope` in `GavetaCore` (set of NFC-normalized aliases, `matches(_ folder:)`, `unresolved(in folders:)`)
- [x] 1.2 Add `FolderStore.policy(home:scope:)` that passes only active, in-scope folders to `AccessPolicy`
- [x] 1.3 Tests in `GavetaCoreTests`: intersection, paused folder, unshared alias, Unicode alias, absolute and `~` paths outside the scope denied, nil scope unchanged

## 2. MCP server

- [x] 2.1 Give `ToolHandler` an optional `FolderScope` and use the scoped policy in `dispatch`
- [x] 2.2 Make `isWriteEnabled()` derive from the scoped policy instead of `store.load()`
- [x] 2.3 Report unresolved scope aliases at startup to stderr and `ActivityLog` without failing
- [x] 2.4 Tests in `ToolHandlerTests`: `list_folders`, `search` without `folder`, out-of-scope path and alias denied, `write_file` listed only with an in-scope `readwrite` folder, alias added after startup becomes visible

## 3. CLI and client config

- [x] 3.1 Add repeatable `--folder` option to `Mcp` and pass the scope to `GavetaServer.runStdio`
- [x] 3.2 Add `folders` parameter to `ClientConfig.json` and emit `--folder <alias>` after `mcp` for every client
- [x] 3.3 Add repeatable `--folder` option to `Config` and include it in the Claude Code `claude mcp add` hint
- [x] 3.4 Tests in `ClientConfigTests`: snippet with scope for each client, snippet without scope unchanged

## 4. Docs

- [x] 4.1 Document per-project registration and the narrowing-only rule in `README.md` (connecting an agent, security)
- [x] 4.2 Run `swift test` and fix regressions
