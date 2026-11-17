---
status: accepted
---

# Coarse Anchors only reopen, they never count

An Anchor that names only an app or only a host (identifier `app:<bundle>|` with no window title, or `web:<host>` with no path or query) is **coarse**. A coarse Anchor reopens the app or page and nothing else: it is not Engagement, it attributes no time, and it is ignored when looking for shared Anchors. Anchors with a window title or a path stay exact.

Engagement and time attribution count Activity from the moment an Anchor was added (`addedAt`), not earlier. Adding an Anchor in the app is Engagement like any edit; an Agent adding one is not (ADR 0008). Whether an Anchor is coarse is derived from its identifier at query time, so existing Loops change with the rule and nothing is migrated.

We chose this over treating every Anchor alike because "Slack" or "Claude" is shared by unrelated Loops and any visit would end every Loose End that mentions it. Cost: Activity before an Anchor was added is not credited to it, so remembering a Loop late leaves that earlier time as Unfocused time, and open Loops may become Loose Ends sooner after the rule lands. The Agent path stores coarse URLs and flags them (`coarse: true`) instead of refusing them.
