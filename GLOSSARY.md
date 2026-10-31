# unfocused

unfocused keeps track of work a knowledge worker has already started across their apps. It's not a todo app or project planner: it's about the moment of switching context, when the user picks what to put their attention on next and should see what they could finish instead of starting something new.

## Language

### Loops

**Loop**:
Anything the user has started or committed to that isn't closed yet, from a two-minute reply to a multi-week project. There is one concept for all sizes.
_Avoid_: Task, todo, project, thread, item

**Capture**:
The conscious act of turning something the user is looking at or thinking about into a Loop.
_Avoid_: Add, create, import

**Focus**:
The conscious switch of the user's attention into one Loop, which becomes the Focused Loop. At most one Loop is Focused at a time. Having none Focused means being unfocused.
_Avoid_: Activate, start, open, work on

**Engagement**:
Any sign that the user actually worked on a Loop: Focusing it, editing it, or being seen in one of its Anchors. Merely deciding to keep a Loop is not Engagement. Engagement restarts the countdown before a Loop becomes a Loose End.
_Avoid_: Touch, activity, update

**Where I left off**:
A short note, written when leaving a Loop, that says how to get back into it. It's shown the next time the Loop comes up.
_Avoid_: Note, resume note, next step, comment

**Anchor**:
A link from a Loop back to the exact spot where the work lives, such as a Slack conversation, a Mail message, a web page or a file. A Loop has zero or more Anchors.
_Avoid_: Link, reference, attachment

**Source**:
The app or system an Anchor points into, such as Slack, Mail or Todoist.
_Avoid_: Integration, app, origin

**Candidate**:
A Loop that unfocused suggests from observed activity. It only becomes a Loop once the user accepts it.
_Avoid_: Suggestion, draft, inferred loop

### Loop states

**Open**:
A Loop that still needs the user's attention at some point.

**Closed**:
A Loop that was finished.
_Avoid_: Done, completed, resolved

**Let go**:
A Loop the user consciously decided not to finish: they let go of it. It's a legitimate outcome, not a failure, and the counterpart to Closing a Loop.
_Avoid_: Dropped, deleted, cancelled, abandoned

**Loose End**:
An Open Loop without Engagement for a number of active days (days the user actually used the Mac). unfocused derives it; the user never sets it.
_Avoid_: Stale, rotten, overdue, forgotten

### Activity

**Activity**:
The automatic record of what was in front of the user on this Mac (which app, window, page, conversation or document, and when). It never includes content or keystrokes.
_Avoid_: Trail, log, tracking, history, timeline

**Unfocused time**:
Activity that didn't go toward the Focused Loop: time spent elsewhere during Focus, and all time with no Loop Focused. It's reported plainly, not judged.
_Avoid_: Detour, distraction, wasted time

### Rituals

**Tie-off**:
A short, focused review in which the user goes through their Loose Ends one at a time and resolves each one or sets it aside with "Not now", which leaves it a Loose End.
_Avoid_: Review, triage, cleanup

**Recap**:
A summary of a day or week: which Loops were Closed, moved forward or Captured, and where the rest of the time went.
_Avoid_: Report, summary, journal, timesheet

### People

**Person**:
Someone involved in a Loop. Everyone in unfocused can be referred to as a Person.
_Avoid_: Contact, stakeholder, user

**Owed**:
The Loop's direction toward a Person who is waiting on the user.
_Avoid_: Assigned, my turn

**Waiting**:
The Loop's direction toward a Person the user is waiting on.
_Avoid_: Blocked, delegated, their turn
