# Research: which apps allow thread-exact Anchors (Cursor, Claude, Slack)

Issue: #141. Sourced findings only; no decisions. Researched 2026-11-17.

Legend: **[verified-doc]** stated by the vendor's official documentation; **[verified-local]** observed on this Mac (Claude.app 5.11492.5, Slack.app 4.53.276; Cursor is **not installed** here); **[unverified]** from a secondary source, a user report, or inferred, not confirmed.

## 1. What unfocused reads today

Source: `Sources/Unfocused/ContextReader.swift`, `Sources/UnfocusedCore/MessageAnchors.swift`, `Sources/UnfocusedCore/AppAnchors.swift`, `docs/DECISIONS.md`. (ADR 0009 is not present in this worktree's `docs/adr/`, which ends at 0006; its rules were not read.)

- Apple Events (Automation permission) are used only for Safari, Chrome, Mail and Finder (`scriptedApps`).
- Accessibility (`AXIsProcessTrusted`): the focused window's `AXTitle` and `AXDocument`.
- **Slack** (`com.tinyspeck.slackmacgap`): window title parsed by `Anchor.slackWindow` (formats "general (Channel) - Acme - Slack", "Slack | general | Acme"), identifier `slack-window:<workspace>/<conversation>`, which is conversation-level, not thread-level. During a Capture only, a Slack message link on the clipboard is parsed by `Anchor.slackLink`: `https://<ws>.slack.com/archives/<C…>/p<ts>[?thread_ts=…]`, identifier `slack:<workspace>/<channel>[/<thread_ts>]`, reopened by opening that https link. The clipboard is never read in the background.
- **Cursor** and **Claude** (desktop): no app-specific code. They hit the default branch: `AXDocument` if present, else `Anchor.appWindow(bundleID, appName, windowTitle)`, i.e. the app plus the window title.
- Notion and Todoist: same clipboard-link pattern as Slack (`Anchor.copiedLink`). Obsidian: window title parsed into an `obsidian://open?vault=&file=` link.
- The "copied link" pattern is the repo's existing way to get an exact identifier from an app with no scripting.

## 2. Slack

Local facts **[verified-local]**: bundle ID `com.tinyspeck.slackmacgap`; `CFBundleURLTypes` registers scheme `slack`; `Info.plist` has no `NSAppleScriptEnabled` and no `OSAScriptingDefinition`, and Resources has no `.sdef`. So no scripting dictionary was found.

| Channel | What it yields | Source / status |
|---|---|---|
| Window title (AX `AXTitle`) | Conversation name and workspace name; not IDs, not the thread. Exact title format is Slack's and not documented by Slack. | Parsed in the repo; format **[unverified]** against any Slack doc (none found). |
| Accessibility tree | Contents not inspected. Slack is an Electron app; Electron documents that third-party assistive technology can enable the accessibility tree by setting `AXManualAccessibility` on the app element. Whether the tree exposes channel/thread IDs is **[unverified]**. | Electron docs https://www.electronjs.org/docs/latest/tutorial/accessibility **[verified-doc]** for the attribute; Slack tree contents **[unverified]**. |
| AppleScript | No scripting dictionary found locally. | **[verified-local]** |
| URL scheme `slack://` | Documented forms: `slack://open[?team=T…]`, `slack://channel?team=T…&id=C…`, `slack://user?team=T…&id=U…`, `slack://file?team=T…&id=F…`, `slack://share-file?...`, `slack://app?team=T…&id=A…[&tab=home|about|messages]`. IDs only (no names or subdomains); unrecognized paths fall back to `slack://open`. The page documents no message- or thread-level `slack://` form and no `thread_ts`. | https://docs.slack.dev/interactivity/deep-linking/ **[verified-doc]** |
| Message permalink (https) | `https://<ws>.slack.com/archives/<channel>/p<ts-without-dot>`; threaded reply: `...?thread_ts=<parent ts>&cid=<channel>`. The `p` segment is the message itself; `thread_ts` is the top-level message. Produced by Slack's "Copy link" in the UI (secondary source) and by the Web API `chat.getPermalink` (arguments `token`, `channel`, `message_ts`; page lists no required scopes beyond a valid token). | https://docs.slack.dev/reference/methods/chat.getPermalink **[verified-doc]**; "Copy link" in the UI **[unverified]** (only seen via third-party posts). |
| Identifier stability | A message `ts` is documented as "essentially the ID of the message, guaranteed unique within the context of a channel or conversation". Channel IDs (`C…`), team IDs (`T…`) are the IDs the deep-link docs use. The workspace subdomain in permalinks can differ from the team ID; the docs say `slack://` does not accept subdomains. | https://docs.slack.dev/messaging/retrieving-messages/ **[verified-doc]**; stability over time (renames, archiving) not stated in the pages read: **[unverified]**. |
| Web app URL | `https://app.slack.com/client/<T…>/<C…>` per a Salesforce doc example; Slack's own page does not cover it. | https://developer.salesforce.com/docs/atlas.en-us.236.0.api_action.meta/api_action/actions_obj_slack.htm **[unverified]** (third party). |
| Own files/logs | `~/Library/Application Support/Slack` exists on this Mac. Contents not read; no Slack documentation of a stable on-disk format found. | **[unverified]** |
| Slack Web API (read current conversation) | The documented API acts on a token for a workspace; it has no notion of "what the desktop client is showing". Using it would need an OAuth token (a credential the app does not hold today). | Inferred from the method docs; **[unverified]** as a statement about the desktop client. |

Cost summary: window title needs Accessibility (already requested); clipboard link needs no permission but needs the user to Copy link; `slack://channel` identifiers need IDs that the window title does not provide.

## 3. Claude (desktop app and claude.ai)

Local facts **[verified-local]**: bundle ID `com.anthropic.claudefordesktop`; `CFBundleURLTypes` registers `claude` (plus an `msauth.…` MSAL scheme); `Info.plist` has no `NSAppleScriptEnabled` or `OSAScriptingDefinition`, no `.sdef` in Resources. `~/Library/Application Support/Claude` contains Chromium-style stores (`IndexedDB`, `Local Storage`, `Session Storage`) and Claude-specific folders (`claude-code-sessions`, `local-agent-mode-sessions`, etc.); contents not read.

| Channel | What it yields | Source / status |
|---|---|---|
| URL scheme `claude://` (Desktop) | `claude://claude.ai/new[?q=]`; **`claude://claude.ai/chat/{conversation-id}` opens an existing chat by ID** (missing/invalid ID opens recent chats); **`claude://claude.ai/project/{project-id}` opens an existing project**; `claude://code/new[?q|prompt, folder, file]`; `claude://cowork/new[?q, folder, file]`. `q` is truncated at about 14,000 characters; values must be URL-encoded; folders passed in a link always trigger a confirmation dialog; the OS launches the app if it is not running. macOS, Windows and Linux. | https://support.claude.com/en/articles/14729294-open-claude-desktop-with-a-link **[verified-doc]** |
| Resume a Code session | `claude://resume?session=<uuid>` was reported as printed by Claude itself and as working from Terminal. No official documentation found. | GitHub issue reports found via search; **[unverified]** |
| `claude-cli://open` | Opens Claude Code in a terminal: `q` (max 5,000 chars), `cwd`, `repo` (owner/name). Does not open an existing session. | https://code.claude.com/docs/en/deep-links **[verified-doc]** |
| VS Code extension | `vscode://anthropic.claude-code/open` (parameters on a separate page, not read). | Mentioned in https://code.claude.com/docs/en/deep-links; **[unverified]** details |
| claude.ai in a browser | The conversation ID is in the page URL (`/chat/<id>`, consistent with the Desktop link format above). unfocused already reads the front browser tab URL for Safari and Chrome. That claude.ai URLs look like `https://claude.ai/chat/<uuid>` is inferred from the deep-link format, not stated by an official page. | **[unverified]** for the exact URL shape |
| Window title / AX (Desktop) | Not inspected (Claude Desktop not running a conversation during this research). It is a Chromium-based app, so the Electron accessibility note applies. Whether the title carries the conversation title or an ID is **[unverified]**. | **[unverified]** |
| AppleScript | No dictionary found locally. | **[verified-local]** |
| Own files | See above; no official documentation of a stable format found. | **[unverified]** |

Findings: an identifier that reopens a specific chat or project exists and is documented (conversation-id, project-id). How to *read* the current conversation's ID from the running Desktop app is not documented anywhere found. Stability of the ID: not stated in the pages read.

## 4. Cursor

Local facts: Cursor is **not installed** on this Mac, so nothing about its bundle, `Info.plist`, scripting or window titles was verified locally. `~/Library/Application Support/Cursor` exists (contents not read).

| Channel | What it yields | Source / status |
|---|---|---|
| URL scheme `cursor://anysphere.cursor-deeplink/` | Only three documented link types: `prompt` (`text`), `command` (`name`, `text`), `rule` (`name`, `text`); web equivalents `https://cursor.com/link/{prompt,command,rule}`. The page documents none that open an existing chat, agent, workspace or file. Max URL length 10,000 characters; recipient must confirm. | https://cursor.com/docs/reference/deeplinks **[verified-doc]** |
| Open-existing-chat link | A forum thread asks for a way to open an empty chat in the Agents window scoped to a chosen workspace; the search found no evidence it exists. | forum.cursor.com thread (user request); **[unverified]** |
| Files/folders (VS Code lineage) | VS Code documents `vscode://file/{path}[:line:col]` and CLI `-g file:line[:col]`, `-r`. Cursor is a VS Code fork, but the VS Code page may not match Cursor; whether `cursor://file/...` works is not stated in Cursor's docs read here. | https://code.visualstudio.com/docs/configure/command-line **[verified-doc]** for VS Code; for Cursor **[unverified]** |
| Window title | VS Code has a `window.title` setting with variables; the VS Code docs pages fetched here did not list it (the page said to use "Open Default Settings (JSON)"). Default title format and whether Cursor changes it: **[unverified]**. | **[unverified]** |
| Accessibility tree | Cursor is Electron-based, so `AXManualAccessibility` applies per the Electron docs; what the tree exposes (open file path, chat title) is **[unverified]**. | Electron docs **[verified-doc]** for the attribute |
| AppleScript | Not checked (app not installed). | **[unverified]** |
| Own files | VS Code-style per-workspace state under `Application Support/Cursor`; VS Code docs pages read say only that UI state is stored and restored per workspace and do not document the on-disk location. Chat history storage format: not documented in sources found. | **[unverified]** |

Findings: a documented Cursor deep link to an existing conversation or workspace was not found. Chat/agent identifiers: none documented.

## 5. Cross-cutting facts (Apple and Electron)

- Accessibility API: `AXUIElementCopyAttributeValue` reads attributes such as `kAXTitleAttribute` and `kAXDocumentAttribute` (already used in the repo); access needs the Accessibility permission (`AXIsProcessTrusted`), which the app already requests. The Apple developer page for `AXUIElement.h` could not be read in full by the fetch tool, so statements about it beyond the repo's own use are **[unverified]**.
- Electron / Chromium apps (Slack, Claude Desktop, Cursor): the documented way for an external assistive tool to turn on the accessibility tree is setting `AXManualAccessibility` on the application element. Secondary reports say the tree can be empty on the first read and builds asynchronously, and that `AXEnhancedUserInterface` is an undocumented alternative with side effects. https://www.electronjs.org/docs/latest/tutorial/accessibility **[verified-doc]** for `AXManualAccessibility`; the rest **[unverified]**.
- Apple Events: an app is scriptable only if it ships a scripting dictionary; neither Slack nor Claude does by the `Info.plist` and Resources check above. Automation permission is per target app (as in the repo's `scriptedApps`).

## 6. Summary table

| App | Documented way to obtain an exact id | Documented way to reopen it | Gap |
|---|---|---|---|
| Slack | Copied message link (channel ID + message `ts` + optional `thread_ts`); `chat.getPermalink` via API | https link (the repo does this); `slack://channel?team&id` for channels/DMs (IDs only) | Reading current channel/thread from the running app without user action: nothing documented |
| Claude (Desktop, claude.ai) | Conversation ID and project ID appear in the documented link formats | `claude://claude.ai/chat/{id}`, `claude://claude.ai/project/{id}` | How to read the active conversation ID: nothing documented |
| Cursor | None documented | None documented for existing chats; `prompt`/`command`/`rule` links only create new content | Both read and reopen |

## 7. Not done / open

- Slack and Claude Desktop accessibility trees and window titles were not inspected live; Cursor was not available at all.
- Issues #8 and #113 could not be read (the GitHub CLI call returned nothing), so the `slack://` identifier agreed in #113 was not cross-checked.
- Local on-disk stores were listed but not opened, to avoid reading private conversation data.
