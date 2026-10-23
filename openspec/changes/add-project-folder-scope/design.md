## Context

`folders.json` is the single registry shared by the CLI, the menu bar app and the MCP server. `ToolHandler.dispatch` builds an `AccessPolicy` from all folders on every call (`store.policy`), and `resolveAllowed` is the only place that decides whether a path may be touched. `isWriteEnabled()` is the exception: it reads `store.load()` directly to decide whether `write_file` is offered.

Users register `gaveta mcp` per project in files such as `.mcp.json` or `opencode.json`, which are often committed. Those files can already pass arguments to the command, so the project config is the natural place for a folder list.

## Goals / Non-Goals

**Goals:**
- Let a project's MCP config name the aliases it may see.
- Keep `resolveAllowed` the single choke point; no tool needs to know about scopes.
- Make it impossible for a project config to widen access beyond `folders.json`.
- Keep the generated client snippets in sync (`gaveta config`).

**Non-Goals:**
- Per-project access mode downgrade (e.g. `notes:ro`). Possible later; the `--folder` value format is kept a plain alias so it can be extended.
- A `.gaveta.json` project file or working-directory discovery.
- Showing per-project scopes in the menu bar app.
- Changing the `folders.json` format or how folders are added.

## Decisions

### Scope is a repeatable `--folder <alias>` option on `gaveta mcp`

The list lives in the client's own config (`args`), which is where the user wants it. Alternatives:
- Env var (`GAVETA_FOLDERS`): equivalent, but hidden in `env` and harder to read in a diff.
- `.gaveta.json` in the project root: one source for all clients, but stdio servers have no reliable working directory, and discovery adds an implicit, surprising input to a security boundary.

A repeatable option is also what `ArgumentParser` handles natively and avoids deciding on a separator for alias lists.

### Intersection, never union

Effective folders = active folders in `folders.json` whose alias is in the scope. The registry stays the authority, so a committed `.mcp.json` from an untrusted repo cannot grant access to anything. Paused folders stay invisible even if listed.

### Filter where the policy is built

Add a `FolderScope` value type in `GavetaCore` (a set of NFC-normalized aliases) and `FolderStore.policy(home:scope:)`, which passes only the matching folders to `AccessPolicy`. Because `evaluate`, `expand`, `activeFolders` and `displayPath` only iterate `folders`, absolute and `~` paths outside the scope are denied with the same `outsideAllowedFolders` answer as any other outside path, and `list_folders` and `search` follow without changes.

Alias matching uses `precomposedStringWithCanonicalMapping`, the same normalization `AccessPolicy.expand` applies.

Alternative considered: filtering inside `ToolHandler` per tool. Rejected because it spreads the boundary across tools and breaks the "one function decides" property documented in the README.

### `isWriteEnabled` goes through the scoped policy

It currently reads `store.load()` directly, which would offer `write_file` to a project whose scope has only read-only folders when some other folder is `readwrite`. It will derive the answer from the scoped policy instead. The 1-second watcher in `GavetaServer` already calls it, so notifications keep working.

### Unknown or paused aliases: warn, do not fail

An empty or partial result is already the safe outcome (deny by default), and failing startup would make a transient state (a paused folder) break the whole MCP connection. The server writes one line per unresolved alias to stderr at startup and records it in `ActivityLog`. Because `folders.json` is reloaded per call, a folder that is added or resumed later becomes visible without restart, still only if its alias is in the scope.

### No flag means no scope

Without `--folder`, behavior is identical to today, so existing configs keep working.

### `gaveta config <client> --folder ...`

`ClientConfig.json(for:executable:)` gains a `folders: [String]` parameter that appends `--folder <alias>` pairs to the command arguments for every client format. The Claude Code `claude mcp add` hint includes them too. The menu bar app keeps calling it with no folders.

## Risks / Trade-offs

- [A typo in an alias silently exposes nothing] → stderr warning at startup and an `ActivityLog` entry; `list_folders` shows what is actually visible.
- [Scope is set by the client config, so a user can edit it to widen to any shared alias] → acceptable: the user already controls what is in `folders.json`, and the feature limits accidental over-sharing and untrusted repos, not the user.
- [Aliases are the key and cannot be renamed today] → if rename is ever added, scopes referencing the old alias go silently empty; the warning covers this.
- [Duplicate aliases cannot exist (`add` rejects them)] → no ambiguity in matching.
- [Restart needed to change scope] → scope is process arguments; changing it follows the client's normal "restart after editing config" flow.
