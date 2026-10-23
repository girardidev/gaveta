## ADDED Requirements

### Requirement: MCP server accepts a folder scope
The `gaveta mcp` command SHALL accept a repeatable `--folder <alias>` option. When at least one is given, the server SHALL expose only the shared folders whose alias is listed.

#### Scenario: Scope limits the visible folders
- **WHEN** `folders.json` has active folders `site`, `notes` and `docs` and the server starts with `--folder site --folder notes`
- **THEN** `list_folders` returns only `site` and `notes`

#### Scenario: No scope keeps current behavior
- **WHEN** the server starts without `--folder`
- **THEN** every active folder in `folders.json` is exposed

### Requirement: Scope only narrows access
The effective folders SHALL be the intersection of the active folders in `folders.json` and the aliases in the scope. A scope MUST NOT grant access to a folder that is not shared or is paused.

#### Scenario: Unshared alias in scope
- **WHEN** the scope lists `secrets` and no folder with alias `secrets` exists in `folders.json`
- **THEN** no tool can read any path of such a folder

#### Scenario: Paused folder in scope
- **WHEN** the scope lists `notes` and `notes` is paused
- **THEN** `notes` behaves as nonexistent, as it does without a scope

### Requirement: Scope applies to every path form
Path resolution SHALL evaluate absolute paths, `~` paths and `alias/sub/path` paths only against the folders in scope, and MUST deny any other path with the same answer used for paths outside the shared folders.

#### Scenario: Absolute path of an out-of-scope folder
- **WHEN** the scope is `site` and a tool is called with the absolute path of the shared folder `notes`
- **THEN** the call fails with the access-denied answer

#### Scenario: Alias of an out-of-scope folder
- **WHEN** the scope is `site` and a tool is called with `notes/todo.md`
- **THEN** the call fails with the access-denied answer

#### Scenario: Search without folder
- **WHEN** the scope is `site` and `search` is called without `folder`
- **THEN** only files inside `site` are searched

### Requirement: Write tool follows the scope
`write_file` SHALL be offered only while at least one active `readwrite` folder is in scope.

#### Scenario: Writable folder outside the scope
- **WHEN** `notes` is `readwrite`, `site` is read-only and the scope is `site`
- **THEN** `write_file` is not listed in the available tools

#### Scenario: Writable folder in scope
- **WHEN** `notes` is `readwrite` and the scope is `notes`
- **THEN** `write_file` is listed and writes inside `notes` succeed

### Requirement: Unresolved scope aliases are reported, not fatal
For each alias in the scope that does not match an active shared folder at startup, the server SHALL write a warning to stderr and record it in the activity log, and SHALL keep running. The server MUST NOT write the warning to stdout.

#### Scenario: Typo in alias
- **WHEN** the server starts with `--folder sitee` and no folder `sitee` is active
- **THEN** a warning naming `sitee` is written to stderr, the server starts, and `list_folders` returns no folders

#### Scenario: Folder becomes active later
- **WHEN** the scope lists `docs`, `docs` is added after startup
- **THEN** `docs` becomes visible without restarting the server

### Requirement: Client configuration carries the scope
`gaveta config <client>` SHALL accept the same repeatable `--folder <alias>` option and SHALL emit each alias as `--folder <alias>` arguments after `mcp` in the generated snippet for every supported client.

#### Scenario: OpenCode snippet with scope
- **WHEN** the user runs `gaveta config opencode --folder site --folder notes`
- **THEN** the command in the snippet is `[<executable>, "mcp", "--folder", "site", "--folder", "notes"]`

#### Scenario: Snippet without scope
- **WHEN** the user runs `gaveta config cursor`
- **THEN** the snippet is identical to the one produced before this change
