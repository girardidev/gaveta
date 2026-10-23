## Why

Every client that runs `gaveta mcp` sees all active shared folders. The only way to limit this is `gaveta pause`, which is global. Users who register the MCP server per project (in `.mcp.json`, `opencode.json`, ...) have no way to say "this project may only see `site` and `notes`".

## What Changes

- `gaveta mcp` accepts a repeatable `--folder <alias>` option. When present, the server exposes only those folders.
- The scope can only narrow access: effective folders are the intersection of the active folders in `folders.json` and the aliases listed by the project. It never grants access to a folder that is not shared or is paused.
- Without `--folder`, behavior is unchanged (all active folders).
- The scope applies to every tool, including path resolution (absolute and `~` paths outside the scope are denied like any other outside path), `list_folders`, `search`, and the availability of `write_file`.
- Aliases in `--folder` that are unknown or paused expose nothing and are reported on stderr and in the activity log; they do not fail startup.
- `gaveta config <client>` accepts the same `--folder` option and emits it in the generated snippet.

## Capabilities

### New Capabilities
- `project-folder-scope`: restricting the folders an MCP server instance exposes to a per-project list of aliases, and generating client configuration that carries that list.

### Modified Capabilities

## Impact

- `GavetaCore`: `AccessPolicy` / `FolderStore.policy` gain a scope filter; `ClientConfig.json` gains a folders parameter.
- `GavetaMCP`: `ToolHandler` carries the scope; `isWriteEnabled` and `list_folders` respect it; `ActivityLog` records the active scope.
- `GavetaCLI`: `Mcp` and `Config` commands gain `--folder`.
- README: document per-project registration.
- No change to `folders.json` format and no new dependencies.
