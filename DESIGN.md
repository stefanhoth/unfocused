# Design

How unfocused looks, reads and behaves. Every screen and every UI change follows this file. The flows below define what goes where; the visual language and words serve them.

- Domain words come from [GLOSSARY.md](GLOSSARY.md). Smaller calls are logged in [docs/DECISIONS.md](docs/DECISIONS.md).
- Change this file in the same PR as a UI change that departs from it, or the change doesn't land.
- Shared values live in `Sources/Unfocused/Style.swift`; use them instead of literals.

## Principles

1. **Finish before you start.** Ending a Loop is always closer at hand than starting one. Capturing a new Loop takes ⌘↩, never plain ↩: the extra key is deliberate friction. While Focused, Close Loop is the first action shown.
2. **The Focused Loop comes first.** When a Loop is Focused, the panel is about that Loop. Switching to another one is a deliberate step (↓ or typing), never the first thing offered.
3. **Calm, never judgmental.** Unfocused time is reported, not scolded. Let go is a legitimate outcome, not a failure. Normal actions never look like errors: no red for anything the user meant to do.
4. **Keyboard-first, keys visible.** Every action has one key, shown as a keycap where the action applies. One action has one name and one key everywhere.
5. **Every action answers.** The user sees what happened (a confirmation, a notice, an animation), and anything that ends a Loop can be undone right there.
6. **Never lose the user's place.** Text fields have the cursor when they appear. Where I left off is asked before anything else can take the screen away.
7. **Say what it means.** UI words are the glossary's words. Where a term is abstract (Owed, Waiting), the label says it in plain language and the glossary term sits in the tooltip.

## Surfaces

| Surface | Purpose | Material |
|---|---|---|
| **Panel** (⌃Space by default) | Capture, Focus, switch, get back into a Loop, leave a Loop | Liquid Glass, floating |
| **Focus notice** | Confirms a Focus change for ~2 s | Glass, bottom center above the Dock |
| **Switch Focus banner** | "Looks like you're on …" after a dwell in another Loop's Anchor | Glass, top right |
| **Tie-off** | Walk the Loose Ends one at a time | Glass, floating |
| **Main window** | Sidebar: **Work** (Loops, People), **Look back** (Recap, Activity), **App** (Settings). ⌘, opens it at Settings | Solid |
| **Edit Loop** (⌘E) | Title, Where I left off, People, Anchors in one place | Solid |
| **Menu bar item** | Open-loop glyph; with a dot and the title (up to 18 characters) while Focused | Template image |

Glass is for floating chrome only. Anything with a lot of text to read (windows, forms) stays solid.

## Flows

### Open the panel, unfocused

- **Top to bottom:** search field (cursor in it), a chip for where you are (app icon and title), then a list/detail split, then the key hints.
- **Nothing is selected** when the panel opens. ↓ selects the first Loop; typing selects the best match. With nothing selected, ↩ does nothing.
- **Rows:** title, aging mark, Loose End or follow-up line, how long ago it was last worked on ("now", "5m", "3h", "2d", "3w"), and a **You're here** badge when the window in front is one of the Loop's Anchors.
- **Detail of the selected Loop** (what you need to get back in): title, "Last worked on …", Where I left off as readable text in its own box, Loose End line, "Last seen in …", the Loop's actions as keycaps, People, Anchors with app icons.
- **Footer:** only panel-wide keys. ↑↓ Choose, ⌘↩ Capture new, ⌥↩ Add here (when a window is in front), @ Person, esc Hide.

### Capture

- Type, then ⌘↩. With no match, an outlined row reads 'Capture "…"' with ⌘↩ on the right and a plus in the logo gradient.
- Related Loops ("Add to an existing Loop instead?") appear under the field. ⌘1–⌘3 adds the current window and the mentioned People to that Loop instead.
- Several Loose Ends add one quiet line: "N Loose Ends are older than this idea." Capture is never blocked.
- `@Name` adds a Person. ⇥ switches who's waiting.

### Focus a Loop, or switch

- ↩ on a row Focuses it.
- Switching from another Loop asks **Where did you leave off?** first, in a freshly shown panel, and opens the new Loop's Anchors only after the answer (↩) or skip (esc). Otherwise those apps would take the screen away before the question is answered.
- The Focus notice fades in at the bottom: "Focused · <Loop>", plus Where I left off when there is one.

### While Focused

- **The Focused Loop fills the top of the panel:**
  - "Focused · for 12m", with the mark and "Focused" in the logo gradient;
  - ⌘U Unfocus at the right of that line, since it changes your state, not the Loop;
  - the title large, then Where I left off and Anchors;
  - its actions: ⌘C Close Loop, ⌘O Open Anchors, ⌘E Edit.
- The search field sits **below** it ("Switch to another Loop…").
- **Footer:** ↓ Switch, ⌘↩ Capture new, esc Hide.
- Typing or ↓ animates into the list: the Focused Loop collapses into a slim strip on top (logo-gradient tint), and the search moves up. ↑ past the first row goes back.
- **Let go is not offered here.** Letting go of what you chose to Focus on takes Unfocus first.

### Leave a Loop: Where did you leave off?

- **Largest first:** "Leaving", then the Loop's title large.
- With a last note, it shows in its own box at reading size, followed by "Anything new?" and a field that says "Type a new note, or ↩ to keep the last one". The hint reads **↩ Keep** until you type, then **↩ Save**.
- esc skips. Close Loop and Let go never ask; a finished or let-go Loop needs no note.

### Close Loop and Let go

- **Close Loop (⌘C)** means the Loop is finished: you closed the loop. **Let go (⌘L)** means you consciously decided not to finish it. Both are endings and both are fine.
- The row animates out and a confirmation slides in above the key hints for 4 s, with **⌘Z Undo** (reopens the Loop):
  - **Close Loop:** "✓ Closed …" in the logo gradient, with a soft sound.
  - **Let go:** "Let go of …", neutral and silent.
- From the Focused view, the panel stays open, shows the confirmation and returns to the list.
- With nothing selected, ⌘L says "Select a Loop first: ↓" instead of doing nothing. ⌘C copies text as usual.

### Edit a Loop (⌘E)

- One solid window for the title, Where I left off, People and Anchors. Changes save as you go; esc or Done closes it.
- **People:** add by name, with suggestions from the People list; the direction in plain words ("They're waiting on me" / "I'm waiting on them"); Remove as a text button.
- **Anchors:** rename (only the shown title changes, not the spot it opens or matches), Open, Remove. Text buttons, never icon-only controls for actions.

### People

- The People section explains itself in one line, and each person's open Loops are grouped into **They're waiting on you** and **You're waiting on them**, plus Closed or let go.
- Chips read "Ada · waiting on me" / "Ada · I'm waiting".

### Interruptions and Welcome back

- Sleep ends Focus; idle (30 min by default) or a screen lock pauses it.
- On return: **Welcome back**, with ↩ Continue, ⌘C Close Loop, ⌘L Let go, ⌘U Unfocus, esc Ask me later.

### Switch Focus banner

- After 3 minutes without a break in another Open Loop's Anchor: "Looks like you're on <Loop>", with Switch Focus (prominent) and Not now. It never takes the keyboard. Not now silences it until the Focus changes.

### Tie-off

- One Loose End at a time, shown with the same summary as the panel's detail.
- Single keys, as keycaps on the buttons: F Focus (or Follow up with …), C Close Loop, L Let go, O Open Anchors, N Not now, esc Stop. ⌘Z takes back the last step and reopens a Loop that was Closed or let go.
- Focus here doesn't open the Loop's Anchors (those apps would take the keyboard from the Tie-off); O does.
- The end gets a bounce in the logo gradient, a sound, and a **Finish** button.

### Main window: Loops, People, Recap, Activity, Settings

- **Loops:** the detail is the same summary as the panel's (title and status, Where I left off, last seen, People, Anchors), with its actions as buttons (Focus, Close Loop, Let go, Edit…), then time worked on and history. Editing happens in Edit Loop, not inline. Close Loop and Let go confirm with Undo, as in the panel.
- **People:** a filter field and a one-line explanation above the list. Each name shows how many open Loops involve them. Deleting a person asks first, since it can't be undone.
- **Activity:** one day at a time with previous/next and Today. Figures (recorded, toward Loops, Unfocused time), a timeline, then entries grouped by hour, merged, with the app icon, the Loop chip and a short duration.
- **Recap:** day or week; Focus periods in the timeline use the logo gradient, Unfocused time is gray.
- **Settings:** a section like the others, not a window of its own, so everything the app keeps is one click away from it. ⌘, (from the menu or while the app is active) opens the main window there.

## Window rules

These are rules, not suggestions. A screen that breaks one doesn't ship. The ones code can check are enforced by `scripts/check-design.sh`, which `make lint` and CI run: no `List(selection:)`, no `HSplitView`, `NavigationSplitView` only for the main window's sidebar, no system accent color.

**Layout:**
- A section with a list and a detail is an `HStack`: the list at a **fixed width** (Loops 340, People 320), a `Divider`, then the detail filling the rest. No `HSplitView` and no `NavigationSplitView` inside a section: they drift, nest badly and clip the detail.
- What sits above a list (segmented control, filter field, explanation) is **outside** the scrolling area and never scrolls under the window's title.
- Every detail area has an empty state that says what to do ("Select a Loop to see where you left off").

**Lists and selection:**
- Lists use `SelectableList`, never `List(selection:)`. macOS draws `List` selection in the system accent color, which the app can't tint, so it can turn red. The same goes for the sidebar: plain rows with `Style.rowBackground`.
- **One row anatomy everywhere:**
  - leading: a mark (aging ring, app icon or the open-loop glyph);
  - middle: the title (primary), then one secondary line (Where I left off, Loose End, the Loop it counts toward);
  - trailing: one short fact in tertiary, monospaced ("2d", "8m", "2 open").
- Rows have 8 pt vertical padding inside a 10 pt list inset. ↑/↓ move the selection.
- A list that can grow past about 15 entries gets a filter field above it (People has one).

**Data views (Recap, Activity, and anything that shows time):**
- Top to bottom: figures first (`FigureCard`), then a timeline bar (logo gradient for time toward a Loop, gray for Unfocused time), then the details, grouped (by hour, by Loop or by kind), never as a raw log.
- Consecutive entries in the same place that count the same way are merged before showing.
- Durations are short (`Style.shortDuration`: "45s", "8m", "1h 5m"; the Recap uses "1h 5m" / "<1m"), never "8 min, 18 secs".
- Each entry names what it counted toward (a Loop chip with the open-loop mark) or "Unfocused", in that order of emphasis.

**Polish bar:** if a screen looks less finished than the Recap, it isn't done. Compare side by side before merging.

## Keys

| Key | Action | Where |
|---|---|---|
| ⌃Space (configurable) | Open the panel | anywhere |
| ↩ | Focus the selected Loop · Save/Keep a note · Continue | panel |
| ⌘↩ | Capture a new Loop (never plain ↩) | panel |
| ⌥↩ | Add the window in front to the selected Loop | panel |
| ⌘C | Close Loop (copies text when no Loop is selected) | panel, Welcome back |
| ⌘L | Let go | panel list, Welcome back |
| ⌘U | Unfocus | panel, Welcome back |
| ⌘O | Open Anchors | panel |
| ⌘E | Edit Loop | panel, Loops window |
| ⌘Z | Undo the last Close Loop or Let go | panel |
| ⌘R | Reopen the Closed or let-go Loop for the window in front | panel |
| ⌘1–⌘3 | Add to a related Loop instead of capturing | panel |
| ⇥ | Fill the window's title · complete a mention · switch who's waiting | panel |
| ↑ ↓ | Move through the list; ↓ leaves the Focused view, ↑ past the top returns | panel |
| esc | Hide · Skip · Ask me later · Stop | everywhere |

New keys must not collide with these or with text editing (⌘⌫ is taken by text fields; that's why Let go is ⌘L).

## Visual language

**Calm Glass:**
- Liquid Glass on floating chrome, with a 60% window-background backing (`Style.glassBacking`) so busy pages behind don't compete with text.
- No system window shadow on glass panels: macOS draws it from the window's rectangle. The panel draws its own shadow plus a crisp gradient edge with a tight halo (`GradientGlow`) inside a transparent margin (`Style.glowMargin`).

**Colors** (the system accent is never used for meaning, because a red accent turns every action into a warning):
- **Brand tint** (`Style.brand`, the icon's blue): cursor and controls.
- **Logo gradient** (`Style.logoGradient`, sky blue to peach): the glow, Focus states, Close Loop and the capture plus.
- **Orange** (`Style.looseEnd`): aging and Loose Ends only.
- **Green** (`Style.focus`): the Focus notice's ring.
- **Neutral**: Let go, hints and everything else.

**Type and space:**
- 22 pt search and note fields. Large titles where a Loop is the subject (26–28 pt semibold). Body text for notes the user must read. Captions only for secondary facts.
- Hierarchy comes from the system's primary, secondary and tertiary styles, never from opacity on text.
- Generous padding: panel content 22–32 pt from the edge.

**Shapes and controls:**
- Radii: panel 24, Tie-off 28, banner 18, rows 10.
- Selection is a quiet neutral fill with a hairline edge (`Style.rowBackground`).
- Keys are keycaps (`KeyHints`, `KeyHints.Keycap`) followed by a secondary-color label. The footer has a hairline on top.
- Anchors show their app's icon (`AppIcon`); SF Symbols at medium weight.
- **App icon:** frosted glass rounded square with an open ring, blue to peach (`Branding/AppIcon.png`). **Menu bar:** the open ring, as a template image.

## Words

- Glossary terms exactly, and one name per action:
  - **Close Loop**, never "Done" or "Complete";
  - **Let go**, never "Drop" or "Delete";
  - **Unfocus**, **Open Anchors**, **Edit**.
- Plain-language labels where a term is abstract: People directions read "They're waiting on me" / "I'm waiting on them".
- English everywhere, including dates, durations and relative times ("2 days ago", "just now" within a minute, through `Style.relative`). The app declares English as its only language (`CFBundleLocalizations`), so formatters speak English while keeping the user's region conventions (24-hour time, date order). Never mix in the system language.
- Say what will happen ("Open Anchors", not "Open"). Short, calm sentences; no exclamation marks, no blame.

## Motion and sound

- `.snappy` for state changes in the panel. With Reduce Motion, everything becomes a short fade, and the glow stops drifting.
- Sounds are rare and earned: a soft "Glass" for Close Loop (panel and Loops window) and at the end of a Tie-off. Inside a Tie-off, only the end makes a sound. Nothing else does.

## Feedback and timing

| What | How long |
|---|---|
| Focus notice | 1.6 s, 2.6 s with Where I left off |
| Close Loop / Let go confirmation | 4 s, with ⌘Z Undo |
| Switch Focus banner | after 3 min in another Loop's Anchor |
| Related-by-meaning suggestions | after a 400 ms pause in typing |

## Accessibility

- Every text field that appears has the cursor. The panel logs `Panel text field has the cursor: true/false` after each showing; the release checklist relies on it.
- The Focus notice is announced to VoiceOver. Reduce Motion is respected everywhere.
- Contrast comes from the glass backing and system text styles. Meaning never depends on color alone: every color comes with a word or a symbol.

## Checklist for a UI change

1. Which flow does it belong to, and does it keep that flow's order and keys?
2. Does it respect the principles, especially "finish before you start" and "the Focused Loop comes first"?
3. Glossary words, one name and one key per action, and plain language where needed?
4. Feedback for every action, and Undo for anything that ends a Loop?
5. Does the cursor land in the field? (`--show panel|left-off|tie-off|banner|focus-preview`, then check the log.)
6. Style tokens instead of literals; glass only on floating chrome; no system accent (no `List(selection:)`, no default sidebar selection)?
7. Window rules: fixed list width next to the detail, nothing scrolls under the title, one row anatomy, a filter for long lists, data views as figures → timeline → grouped details?
8. Does it look as finished as the Recap, side by side?
9. Reduce Motion, VoiceOver, and readable over a busy background?
10. This file updated if anything here changed.
