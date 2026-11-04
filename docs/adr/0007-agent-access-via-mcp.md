---
status: proposed
---

# Read-only Agent access through a separate MCP binary

Users want to ask an Agent (Claude, ChatGPT, a local model) about their Loops and Activity. unfocused offers this through `unfocused-mcp`, a separate executable that speaks the Model Context Protocol over stdio and reads the database through Core. The user has to allow it in Settings first. It only reads. Capturing through an Agent is a separate decision (ADR 0008), because reading alone leaves the app and Core unchanged and avoids the risks of a second writer and of a model changing data.

## Shape

- A new executable target `unfocused-mcp` that depends only on `UnfocusedCore` (ADR 0005).
- It ships in the bundle (`Contents/MacOS/unfocused-mcp`). The cask links it onto `PATH`, so an Agent is set up with e.g. `claude mcp add unfocused -- unfocused-mcp`.
- The Agent's app starts it as a child process and talks over stdin/stdout. There's no port, no socket and no listener in the app. Protocol messages go to stdout only; logs go to the rotating log file and stderr.
- It needs no system permissions: no Accessibility, no Apple Events.

## Opening the database

- A new `UnfocusedDatabase.openReadOnly(at:)` opens with GRDB's `readonly` configuration, following GRDB's guide on sharing a database between processes.
  - It never creates the file or its folder.
  - It never migrates; only the app does.
- It works whether or not the app is running, including when SQLite has removed the `-wal` and `-shm` files after the app's last connection closed. A contract test covers that case.
- The binary checks the schema with GRDB's `hasCompletedMigrations` and `hasBeenSuperseded`, and answers with an error instead of reading when:
  - there's no database because unfocused was never opened ("open unfocused once");
  - the app hasn't finished migrating yet ("open unfocused once to update");
  - the dev build has migrated the shared database past the installed binary ("update unfocused").

## Consent

- **Settings → Agent access**, off by default. It's one explicit switch, like the command line switch in Obsidian's settings.
- Activity is a second switch, off by default. It holds window titles, pages and conversations, which reveal far more than Loops.
- The switches live in the `setting` table and are checked on every call, so turning access off applies immediately.
- While access is off, the tools are still listed, but every call answers with how to turn access on in Settings. That way the Agent can tell the user what to do.
- Settings says plainly that answers go to the app that calls unfocused, and that a remote model sends them on to its provider's servers. With a local model, everything stays on the Mac.
- This doesn't change ADR 0002. unfocused itself still talks to no server. Like "Copy as Markdown", the user hands their data to a tool they chose, through a feature they turned on.
- Every call is logged with its time, the Agent's name (from the MCP `clientInfo`) and the tool. Settings shows when and by which Agent access was last used.
- The switch is consent, not a security boundary. Any process running as the user can read the SQLite file directly, and an Agent with shell access could even flip the switch in the database. The switch ensures unfocused itself never hands out data the user didn't agree to share.
- Loop titles, Anchor titles and Activity reach the model verbatim, so a crafted page title can try to steer the Agent (prompt injection). Read-only access limits the harm to what the Agent itself can do with what it reads. Tool descriptions say that results are data, not instructions.

## Tools

The tools are read-only: each is marked with `readOnlyHint` and answers from existing Core queries. Their names and descriptions use glossary terms.

- Loops:
  - `list_loops(state)`
  - `search_open_loops(query)`
  - `focused_loop`
  - `get_loop(id)`, which combines Anchors, People, Where I left off, the Loop's history and its past Focus
  - `loose_ends`
  - `loops_involving(person)`, which resolves the name through `searchPeople` first
- Activity (behind the second switch):
  - `activity(from, to)` as attributed stretches
  - `unfocused_time(from, to)`
  - `time_spent(loop, from, to)`
  - `work_log(loop, from, to)`
  - `recap(day | week)` as the existing Markdown

## Considered options

- **MCP server inside the app (HTTP or socket):** rejected. It needs the app running, opens a listener in an app that promises not to talk to servers, and stdio is what local MCP clients start by default.
- **Official Swift MCP SDK (`modelcontextprotocol/swift-sdk`, 0.9 at the time of writing):** not yet. It's pre-1.0 and pulls in swift-nio, swift-log, an EventSource client and a branch-pinned DocC plugin. A tools-only server needs `initialize` (with protocol version negotiation), `notifications/initialized`, `tools/list`, `tools/call` and `ping`. That fits in a small JSON-RPC layer of our own behind one seam. Revisit when the SDK reaches 1.0.
- **Export files instead of MCP:** static, so an Agent can't ask follow-up questions.

## Consequences

- Signing:
  - `scripts/build-app.sh` and `scripts/sign-app.sh` sign `unfocused-mcp` before the bundle, inside out, with the hardened runtime and no entitlements.
  - The release checklist verifies the bundle with `codesign --verify --strict`.
  - The release checklist also checks whether Gatekeeper asks separately for the binary when it's started through the cask's `PATH` link.
- The cask gains a `binary` stanza, and the release workflow builds the second product.
- The binary gets contract tests from recorded JSON-RPC requests and responses, run against an in-memory database, plus the read-only opening cases above.
- `DESIGN.md` gains the Agent access part of Settings. The glossary's _Avoid_ "client" applies to domain language; "MCP client" stays as the protocol term in technical docs.
- Spec #1 lists "a CLI and data export" as out of scope for v1. This ADR moves Agent access to a milestone after v1.
