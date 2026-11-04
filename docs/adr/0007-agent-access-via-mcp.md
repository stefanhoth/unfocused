---
status: proposed
---

# Agent access through a separate MCP binary over stdio

Users want to ask an AI Agent (Claude, ChatGPT, a local model) about their Loops and Activity, and later let it Capture Loops for them. unfocused offers this through `unfocused-mcp`, a separate executable that speaks the Model Context Protocol over stdio and works directly on the database through Core. The user turns it on explicitly in Settings. The first stage only reads. Capturing Loops with Anchors is the planned second stage, sketched below and decided in its own PR.

## Shape

- A new executable target `unfocused-mcp` that depends only on `UnfocusedCore` (ADR 0005), so it follows the same domain rules as the app.
- It ships inside the bundle (`Contents/MacOS/unfocused-mcp`) and is signed with the same certificate. The cask links it onto `PATH`, so a client is set up with e.g. `claude mcp add unfocused -- unfocused-mcp`.
- The MCP client starts it as a child process and talks over stdin/stdout. There's no port, no socket and no listener in the app, and reads work even when the app isn't running.
- It opens the database read-only (GRDB `readonly`), never migrates and refuses to answer if the schema doesn't match its Core ("open unfocused once to update"). Only the app migrates. The database is already in WAL mode (`DatabasePool`), so reads never block the app.

## Consent

- **Settings → Agent access**, off by default, works like Obsidian's command line switch: nothing answers until the user allows it once. Activity is a second switch, off by default, because it holds window titles, pages and conversations, which are far more revealing than Loops.
- The switches live in the database's `setting` table. The binary checks them on every request, so turning access off applies immediately. While access is off, every call answers with a pointer to Settings.
- Settings says plainly that answers go to the app that calls unfocused, and that a remote model (Claude, ChatGPT, …) sends them on to its provider's servers. With a local model, everything stays on the Mac.
- This doesn't change ADR 0002: unfocused itself still talks to no server. Like "Copy as Markdown", the user hands their data to a tool they chose, through a feature they had to turn on.
- The switch is consent, not a security boundary: any process running as the user can already read the SQLite file. It makes sure unfocused never hands out data the user didn't agree to share.

## Stage 1: reading

The tools map onto Core queries that already exist and use glossary terms in their names and descriptions:

- Loops: `list_loops(state)`, `search_loops(query)`, `focused_loop`, `get_loop(id)` (Anchors, People, Where I left off, Loop events, Focus sessions), `loose_ends`, `loops_involving(person)`.
- Activity (behind the second switch): `activity(from, to)` as attributed stretches, `unfocused_time(from, to)`, `time_spent(loop, from, to)`, `work_log(loop, from, to)`, `recap(day | week)` as the existing Markdown.

## Stage 2 (exploration): Capturing Loops through an Agent

Scenario: in the morning the user picks their three priorities for the day with an Agent, perhaps in their Obsidian daily note. The Agent makes sure each one exists as an Open Loop and adds the Anchors where the work lives: the Slack thread, the Notion page, the note itself. When the user opens the panel, the Loops are already there.

This fits ADR 0001 when the priorities stay in the planning tool. unfocused doesn't learn what a "priority" is. It mirrors the work as Loops with Anchors back to the source.

Sketch:

- Tools: `capture_loop(title, anchors, people)` and `add_anchor(loop, anchor)`. Focus, Close and Let go stay in the app, because each is a conscious act of the user in the moment.
- Idempotent by Anchor: Capturing with an Anchor that already belongs to an Open Loop returns that Loop instead of a duplicate (`Core.loop(anchoredAt:)`), so running the morning routine twice is harmless. Tool descriptions tell Agents to `search_loops` first.
- A third switch, "Agent can Capture Loops", under Agent access.
- Writing: the binary writes through Core directly (WAL plus a busy timeout handles two writers) and posts a Darwin notification (`notify_post`). The running app listens and refreshes. Today the app refreshes only after its own changes, and GRDB observation doesn't see writes from other processes, so the notification is required.
- Anchors from Agents: today an Anchor is a browser page or an app by bundle ID, and app Anchors only reopen the app. Agents will mostly send URLs: web pages work as they are, while `obsidian://`, `slack://` or `notion://` links need an Anchor that opens any URL with a scheme.

Domain answers (see `GLOSSARY.md`):

1. A Loop an Agent Captures on the user's request is a **Capture**, not a Candidate: the user asked for it. Candidates stay for what unfocused infers on its own.
2. An agent adding an Anchor is not **Engagement**. It's bookkeeping, not work on the Loop, so it never hides a Loose End.
3. Loop events record when a change came through an Agent, so the user can always tell which Loops and Anchors they added themselves.
4. "Priority for today" gets no term in unfocused. A Loop is something the user committed to, whenever and wherever, so planning the day stays in the planning tool (ADR 0001).

## Considered options

- **MCP server inside the app (HTTP or socket):** rejected. It needs the app running, opens a listener in an app that promises not to talk to servers, and stdio is what local MCP clients start by default.
- **Official Swift MCP SDK (`modelcontextprotocol/swift-sdk`, 0.9 at the time of writing):** not yet. It's pre-1.0 and pulls in swift-nio, swift-log, an EventSource client and a branch-pinned DocC plugin for features we don't need. Tools over stdio need only `initialize`, `tools/list`, `tools/call` and `ping`, which fit in a small JSON-RPC layer of our own behind one seam. Revisit when the SDK reaches 1.0.
- **Writes routed through the running app (XPC):** keeps a single writer process, but fails when the app is closed and adds IPC. Direct writes through Core keep the rules in one place.
- **Export files instead of MCP:** static, so an Agent can't ask follow-up questions or Capture.

## Consequences

- `scripts/build-app.sh`, the cask, the release workflow and `docs/release-checklist.md` gain the second binary.
- The binary gets contract tests from recorded JSON-RPC requests and responses, run against an in-memory database.
- `DESIGN.md` gains the Agent access part of Settings.
- Recording agent changes in Loop events needs a migration (stage 2).
- Spec #1 lists "a CLI and data export" as out of scope for v1. This ADR moves Agent access to a milestone after v1.
