---
status: proposed
---

# Agents Capture Loops and add Anchors

Building on ADR 0007, an Agent can Capture Loops and add Anchors to them, through the same `unfocused-mcp` binary, once the user has allowed it with a third switch. The binary writes through Core directly, and the running app picks up those changes. Close, Let go, Reopen and Focus stay in the app, because each is a conscious decision the user makes in the moment.

Scenario: in the morning the user picks their three priorities for the day with an Agent, perhaps in their Obsidian daily note. The Agent makes sure each one exists as an Open Loop and adds the Anchors where the work lives: the Slack thread, the Notion page, the note itself. When the user opens the panel, the Loops are already there. The priorities stay in the planning tool (ADR 0001); unfocused mirrors the work as Loops with Anchors back to it.

## Domain rules

- A Loop an Agent Captures on the user's request is a **Capture**, not a Candidate, because the user asked for it. Candidates stay for what unfocused infers on its own.
- An Agent adding an Anchor is not **Engagement**. It's bookkeeping, not work on the Loop, so it never hides a Loose End. Activity the user had at that spot before still counts, because that was the user's own work.
- Every change an Agent makes shows up in the Loop's history, marked as made by an Agent, so the user can always tell which Loops and Anchors they added themselves.
- "Priority for today" gets no term in unfocused. A Loop is something the user committed to, whatever the day.

## Tools and Core changes

- **`capture_loop(title, anchors, people)`:**
  - It deduplicates by Anchor. If one of the Anchors already belongs to an Open Loop, it returns that Loop and adds any missing Anchors, so running the morning routine twice changes nothing.
  - If the Anchor only belongs to a Closed or Let go Loop, it returns that Loop with its state and changes nothing. The Agent tells the user, who decides whether to Reopen it in the app.
  - Today `Core.loop(anchoredAt:)` returns Closed and Let go Loops too, so this needs an explicit rule in Core.
- **`add_anchor(loop, anchor)`:**
  - Core needs an Agent path that doesn't count as Engagement. Today `Core.addAnchor` marks the Loop as edited, which is Engagement.
- **History:**
  - Loop events gain an origin (user or Agent) and an "Anchor added" change. Today only Captured, Closed, Let go and Reopened are recorded, and adding an Anchor isn't recorded at all.
  - This needs a migration, and the panel's Loop detail needs a way to show which changes came from an Agent.
- **Anchors from URLs:**
  - Agents mostly send links. Web pages work today.
  - `obsidian://`, `slack://` or `notion://` links need a new kind of Anchor that opens any URL with a scheme. Today app Anchors only reopen the app.

## Writing from two processes

- Only the app migrates. The binary refuses to write when the schema doesn't match its Core, as it does for reads (ADR 0007).
- Both the app and the binary:
  - set a busy timeout;
  - start write transactions as `.immediate`, so a read that turns into a write never fails with `SQLITE_BUSY_SNAPSHOT`.
- After each write, the binary posts the Darwin notification `com.stefanhoth.unfocused.changed` (`notify_post`), and the running app refreshes when it receives it.
  - Today the app refreshes only after its own changes, and GRDB's observation doesn't see writes from other processes, so the notification is needed.
  - The notification carries no data and no authentication. A forged one only causes an extra refresh.

## Consent and safety

- A third switch, **Agent can Capture Loops**, off by default. It only works while Agent access is on.
- Write tools are only listed while the switch is on.
- The limits of ADR 0007 still apply: the switch is consent, not a security boundary.
- Prompt injection matters more once an Agent can write. A crafted page could make an Agent Capture Loops the user never asked for. The limits:
  - Agents can only add. They can't Close, Let go, delete, rename or Focus.
  - Every Agent change is marked in the Loop's history.
  - At worst the user ends up with unwanted Loops they Let go.

## Considered options

- **Writes routed through the running app (XPC):** keeps a single writer, but fails when the app is closed and adds IPC between two binaries. Writing through Core keeps the rules in one place, and SQLite handles two writers.
- **Agent writes become Candidates the user accepts:** safer against prompt injection, but the user already asked the Agent, so accepting again is friction for nothing. Candidates are also not built yet.
- **Let Agents Close or Let go:** rejected. Both are conscious decisions the user makes, and one injected instruction could quietly remove Loops.
