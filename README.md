# Gaveta

Share specific folders on your Mac with AI agents, and nothing else.

Gaveta ("drawer" in Portuguese) is a macOS utility. You share a folder from the terminal (`gaveta add ~/Projects/site`), a menu bar icon shows what is shared, and agents such as Claude Desktop, Claude Code, Cursor and OpenCode connect to Gaveta's MCP server. They can list, read and search files **inside** those folders. Outside the drawer, nothing.

100% local: no network, no telemetry, no Node, Python or Electron.

## Requirements

- macOS 14 or later
- Swift 6 (Xcode 16 or later) to build

## Installation

### From a release (recommended)

1. Download `Gaveta-<version>.zip`, unzip it and drag `Gaveta.app` to `/Applications`.
2. Open it once; the tray icon appears in the menu bar.
3. Install the `gaveta` command so it is on your PATH:

   ```sh
   /Applications/Gaveta.app/Contents/Helpers/gaveta install
   ```

   This links `/usr/local/bin/gaveta` to the copy inside the app, so updating the app updates the command. If macOS denies the write, the command prints the exact `sudo` line to run. `gaveta uninstall` removes the link.

Check it works with `gaveta list`.

### From source

```sh
git clone <this repository> && cd gaveta

swift build -c release
.build/release/gaveta install      # or: sudo ln -sf "$PWD/.build/release/gaveta" /usr/local/bin/gaveta

Scripts/make-app.sh                # produces build/Gaveta.app (ad-hoc signed, for local use)
open build/Gaveta.app
```

An ad-hoc signed app runs on the machine that built it. To run it elsewhere, use a notarized release (below).

## Usage

Gaveta keeps everything in `~/Library/Application Support/Gaveta/folders.json`. The CLI writes to it; the app and the MCP server read it. Changes take effect immediately, with no need to restart the agent.

```sh
gaveta add ~/Projects/site                  # read-only, alias "site"
gaveta add ~/Notes --alias notes --write    # read and write
gaveta list                                 # or: gaveta list --json
gaveta pause site                           # the agent loses access immediately
gaveta resume site
gaveta remove site                          # by alias or by path
gaveta config claude-desktop                # JSON configuration for a client
gaveta install                              # link the command into /usr/local/bin
```

The menu bar app lists the folders with their access badge, opens a folder in Finder, pauses and resumes it with a switch, copies each client's MCP configuration, and can launch at login. It does **not** add folders: that is done from the terminal only, by design.

### What `gaveta add` refuses

- a path that does not exist or is not a folder
- `/`, your entire home folder (`~`), `/System`, `/Library` and `~/Library`, including everything inside them
- a folder already covered by another shared folder (folder inside a folder)
- a duplicate or invalid alias (no `/`, not starting with `.` or `~`, up to 64 characters)

Exception: Obsidian vaults in iCloud, at `~/Library/Mobile Documents/iCloud~md~obsidian/Documents/<vault>`, can be shared.

If you share a folder that contains one that is already shared, Gaveta warns you and accepts it.

## Connecting an agent

Generate the JSON for your client and paste it into the indicated file (the hint on where to paste it goes to stderr):

| Client | Command | Where to paste |
|---|---|---|
| Claude Desktop | `gaveta config claude-desktop` | `~/Library/Application Support/Claude/claude_desktop_config.json` |
| Claude Code | `gaveta config claude-code` or `claude mcp add gaveta -- /usr/local/bin/gaveta mcp` | the project's `.mcp.json` |
| Cursor | `gaveta config cursor` | `~/.cursor/mcp.json` |
| OpenCode | `gaveta config opencode` | `~/.config/opencode/opencode.json` |

Example (Claude Desktop and Cursor):

```json
{
  "mcpServers": {
    "gaveta": {
      "command": "/usr/local/bin/gaveta",
      "args": ["mcp"]
    }
  }
}
```

Restart the client after editing its configuration. `gaveta config` uses `/usr/local/bin/gaveta` when that link exists. You can also copy the configuration from the app's menu.

## MCP tools

Paths can be absolute, start with `~`, or use the alias: `site/src/index.html`.

| Tool | What it does |
|---|---|
| `list_folders` | Aliases, paths and access mode of the shared folders. |
| `list_dir` | Lists a directory (`recursive` up to depth 3, `include_hidden`). Up to 1,000 entries. |
| `read_file` | Reads a UTF-8 text file, up to 1 MB per call. Use `offset` and `limit` (in lines) to page through. Binary files are refused. |
| `stat` | Type, size, dates, permissions and whether it is writable. |
| `search` | Searches text in file names and contents (`folder`, `glob`, `case_sensitive`). Up to 200 results. Skips `.git`, `node_modules`, `.DS_Store`, symlinks and binaries. |
| `write_file` | Creates or overwrites a text file (up to 1 MB). **Only exists while a `--write` folder is active** and only writes inside such folders. |

Paused folders behave as if they did not exist.

## Security

Every tool goes through a single function, `resolveAllowed`, in `GavetaCore`. It:

1. expands the alias or `~`;
2. resolves the path with `realpath` (`..` and symlinks);
3. compares path components, never string prefixes (`/a/site2` does not pass for `/a/site`);
4. for writes, requires a `readwrite` folder and validates the already-resolved parent directory;
5. denies by default on any doubt or error.

In practice: `../`, symlinks pointing outside, decomposed Unicode paths and look-alike folder names do not escape the drawer. A corrupted `folders.json` denies everything instead of allowing it. A nonexistent path outside the folders gets the same access-denied answer as any other, so the agent cannot discover what exists on disk.

Gaveta does not use the App Sandbox, because the sandbox would prevent the CLI from granting access to folders. The protection is the policy above, covered by tests.

### Log

Every call is recorded in `~/Library/Logs/Gaveta/mcp.log` (date, tool, path and outcome). File contents are never logged. The server writes nothing to stdout besides the protocol.

## macOS privacy (TCC)

Folders such as **Desktop**, **Documents**, **Downloads**, external volumes and **iCloud Drive** (including Obsidian vaults) are protected by macOS. Sharing the folder with Gaveta is not enough: when the agent tries to read it, macOS shows a privacy prompt.

The prompt goes to the **app that runs `gaveta mcp`**, not to Gaveta:

- Claude Desktop, Cursor, etc.: the app itself.
- Claude Code and OpenCode: the terminal where you run them (Terminal, iTerm, Ghostty...).

If you denied it by mistake, change it in **System Settings › Privacy & Security › Files & Folders** (or **Full Disk Access**). Without the permission, reads fail with a message explaining this.

## Releasing

Distribution is outside the App Store, signed with a Developer ID and notarized by Apple. You need:

1. **An Apple Developer Program membership** (paid, US$ 99/year): <https://developer.apple.com/programs/>.
2. **Your Team ID**: <https://developer.apple.com/account> › Membership details.
3. **A "Developer ID Application" certificate**: in Xcode, Settings › Accounts › your team › Manage Certificates › **+** › *Developer ID Application*. Check it with `security find-identity -v -p codesigning`; the identity looks like `Developer ID Application: Your Name (TEAMID)`.
4. **A notarization profile**, created once with an [app-specific password](https://support.apple.com/102654):

   ```sh
   xcrun notarytool store-credentials "gaveta-notary" \
       --apple-id you@example.com --team-id TEAMID --password <app-specific-password>
   ```

5. **A bundle identifier you control**, in reverse-DNS form, e.g. `io.github.<your-user>.gaveta` or `com.<your-domain>.gaveta`.

Then:

```sh
export SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)"
export BUNDLE_ID="io.github.you.gaveta"
export NOTARY_PROFILE="gaveta-notary"

Scripts/release.sh --check   # verifies identity and profile without building
Scripts/release.sh           # universal build, sign, notarize, staple -> dist/Gaveta-<version>.zip
```

The version comes from the `VERSION` file (a test keeps it in sync with the server version).

## Development

```sh
swift test                  # tests (Swift Testing)
Scripts/make-app.sh debug   # builds build/Gaveta.app from a debug build
```

```
Sources/
  GavetaCore/   model, atomic JSON, resolveAllowed, file tools
  GavetaMCP/    MCP server (stdio) on top of the official SDK
  GavetaCLI/    the `gaveta` executable
  GavetaApp/    menu bar app (SwiftUI MenuBarExtra)
```

Try it with the MCP Inspector:

```sh
npx @modelcontextprotocol/inspector gaveta mcp
```
