---
status: proposed
---

# Coarse Anchors only reopen; Anchors count from when they were added

Activity reaches a Loop only through its Anchors: Core matches the Activity identifier to the Anchor identifier when it is asked (`lastEngagement`, `attributedActivity`, `silentSwitchSuggestion`, `loop(anchoredAt:)`). Every Anchor is treated the same, however little it says. We decide that a **coarse Anchor**, one that names only an app or a site, still reopens it but no longer counts as Engagement, attracts no time, and is never a shared Anchor. Every Anchor counts only for Activity from the moment it was added. Agents can't send coarse links. The rule lives in Core, and existing data needs no migration.

Context: issue #124. This changes one rule of ADR 0008 (see below) and the matching user story 16 of spec #109.

## What the code does today

- An Anchor matches Activity only when the identifiers are exactly equal. Coarseness therefore depends on what the context reader can see:
  - `Anchor.appWindow` builds `app:<bundle ID>|<window title>`. Without Accessibility, or with an empty window title, every Anchor and every piece of Activity in that app is `app:<bundle ID>|`. One such Anchor then claims **all** time in the app and ends the Loose End on any visit.
  - Apps whose window title never changes behave the same way with Accessibility on. **Unsure:** whether the Claude desktop app's window title is always "Claude". It can't be checked from the code and needs a check on a Mac.
  - `Anchor.webPage` with no path and no query (`web:claude.ai`, `web:app.slack.com`) is the same for a site.
  - `slackWindow` (`slack-window:<workspace>/<conversation>`) names the conversation, not the thread. `firefoxWindow` and `notionWindow` name a page by its title. These are not coarse: they name a spot, even if not always the most exact one.
- Adding an Anchor claims earlier Activity. `lastEngagement` takes the latest `activity.lastSeen` for any of the Loop's identifiers, regardless of `anchor.addedAt`. `attributedActivity` does the same for past days, so a Recap can change after the fact.
- Exact Slack thread Anchors (`slack:<workspace>/<channel>/<ts>`, from a copied link) and Notion or Todoist links copied in the app are only made during a Capture. The background reader never reads the clipboard (`ContextReader.read(prompting: false)`), so Activity never has these identifiers. These Anchors never count as Engagement and never attract time from the Slack, Notion or Todoist app. A Notion or Todoist link opened in Safari or Chrome does match, as `web:`.

## Can URL-scheme Anchors (#113) match Activity?

- #113 isn't built: Core has no Anchor kind for `slack://`, `obsidian://` or `notion://` links yet. Its spec gives the identifier as a normalised scheme, host or target, path and query.
- Activity identifiers come only from the background reader: `web:`, `firefox:`, `obsidian:<vault>/<note>`, `slack-window:`, `mail:`, `file:`, `notion-window:` and `app:`. None of them start with a URL scheme. **So no: as #113 is specified, a URL-scheme Anchor never equals an Activity identifier.** It would reopen the exact spot but never count as Engagement and never attract time.
- Obsidian is the one case where both sides name the same spot. `obsidianWindow` already makes `obsidian:<vault>/<note>` with an `obsidian://open?vault=…&file=…` link. If #113 maps such links to that identifier, they match. **Unsure:** a `file` parameter that includes a folder (`Projects/Weekly plan`) or `.md` may not equal the note name in the window title. That needs recorded window titles from a vault with folders.
- Slack can't be mapped. `slack://channel?team=T…&id=C…` names the team by ID, while Activity knows only the workspace and conversation names from the window title.

## Decision

- **What makes an Anchor coarse.** An Anchor is coarse when it names only its Source and no spot inside it:
  - an app Anchor whose window part is empty or is just the app's name;
  - a web page with no path and no query;
  - a URL-scheme Anchor (#113) with no target beyond the app or host, for example a vault without a note.
- **Where the rule lives.** The rule is part of Core's `Anchor`, as a property derived from the stored fields, next to `webPage` and `appWindow` (ADR 0005). It's not a stored flag, so existing Anchors get it without a migration and the rule can be sharpened later. Core's queries use it; the app shell only shows it.
- **What a coarse Anchor does.** It is still offered and kept: "Open Claude" is a useful way back into a Loop. But it only reopens. It is ignored by:
  - Engagement (`lastEngagement`), so visiting the app never ends a Loose End;
  - time attribution, so time there goes to the Focused Loop by the Focus rule, or is Unfocused time;
  - the Switch Focus banner and the "You're here" badge (`silentSwitchSuggestion`, `loop(anchoredAt:)`);
  - shared-Anchor detection (below).
- **Anchors count from when they were added.** An Anchor matches only Activity from its `addedAt` on. A stretch that started earlier counts from `addedAt`. This applies to Anchors the user adds and to Anchors an Agent adds, for Engagement and for time:
  - When the user adds an Anchor, that is an edit and already Engagement, so nothing is lost.
  - When an Agent adds one, it never ends a Loose End through Activity the user had there before. It ends one only through the user's later visits.
  - Recaps of past days don't change when an Anchor is added today.
- **Agents (#109).** `capture_loop` and `add_anchor` refuse coarse links with a typed error, turned into a message asking for the exact thread, page or note. An Agent can usually get that link. A reopen-only Anchor from an Agent adds noise and no information. The user can still add a coarse Anchor in the app.
- **One spot, one identifier.** If a URL-scheme Anchor (#113) names a spot a context reader already sees, it uses that reader's identifier, as `obsidian:<vault>/<note>` does. Otherwise it is exact but never seen in Activity, and the UI must not suggest it counts as Engagement.

## Consequences

- **ADR 0008 changes.** "Activity the user had at that spot before still counts" no longer holds, for the user's Anchors as for an Agent's. The rest of ADR 0008 stands: adding an Anchor by an Agent is not Engagement.
- **Shared Anchors (ADR 0008).** `capture_loop` only checks Anchors that are not coarse. Since Agents can't send coarse ones, "Slack" or "Claude" can no longer block a Capture. In the app, `loop(anchoredAt:)` returns no Loop for a coarse Anchor, so the panel doesn't present "Slack" as being in some Loop.
- **Existing Loops and Anchors.** This is a rule change, with no migration. Every Anchor already has `addedAt` (since migration `v5-anchors`), and coarseness is derived. After the update:
  - Loops kept fresh only by a coarse Anchor or by Activity from before an Anchor existed may become Loose Ends. That is the point: they weren't being worked on. The release notes say so, and the Tie-off is where the user deals with them.
  - Time per Loop in past Recaps can go down where it came from coarse Anchors or from before an Anchor was added.
- **Edit Loop and the panel** need to show that a coarse Anchor only reopens. `DESIGN.md` gets that wording in the PR that builds it.
- **Glossary.** Engagement now says "since it was added" and excludes coarse Anchors; **Coarse Anchor** is a new term.
- **Not decided here:** making Slack threads visible to Activity. That needs a better Slack reader, not an Anchor rule.

## Considered options

- **Treat every Anchor alike (today):** one coarse Anchor claims all time in an app and keeps a Loop from ever becoming a Loose End. That is the problem in #124.
- **Don't offer coarse Anchors at all:** rejected. Without Accessibility the app Anchor is all there is, and "reopen Claude" is still a useful way back. It would also leave existing Loops with Anchors the app no longer offers.
- **Store a coarse flag when an Anchor is added:** rejected. It needs a migration for existing Anchors and freezes today's rule into the data.
- **Detect coarseness from use (an identifier seen under many unrelated Loops):** rejected. It's hard to explain, changes over time, and still guesses.
- **Count earlier Activity for time but not for Engagement:** rejected. Two rules for one match are harder to explain, and past Recaps would still change after the fact.
- **Count earlier Activity only for Anchors the user adds:** rejected. The user's own addition is already Engagement, so the exception gains nothing and keeps two rules.
- **Accept coarse links from Agents as reopen-only Anchors:** harmless after this ADR, but an Agent can almost always send the exact link, and refusing tells it so.
