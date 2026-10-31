# Microcopy Pattern Library — Words That Make Interfaces Work

Microcopy is the small text that guides users through an interface: button labels, error messages, tooltips, empty states, confirmation dialogs, and loading indicators. It is often written last but read first. Good microcopy reduces support tickets, increases conversion, prevents errors, and builds trust. This reference provides reusable patterns for every state an interface can be in.

---

## 1. Action Verb Matrix

The verb on a button or link is the user's contract with the system. Choosing the right verb sets accurate expectations about what will happen.

### Create — Bringing something new into existence

| Verb | Use When | Tone | Example |
|---|---|---|---|
| Create | Generic creation of a new entity | Neutral | "Create project" |
| Add | Appending to an existing collection | Neutral | "Add team member" |
| New | Shorthand for creation in toolbars | Terse | "New document" |
| Compose | Writing a message or email | Focused | "Compose message" |
| Start | Initiating a process or session | Active | "Start free trial" |
| Generate | System creates something on the user's behalf | Technical | "Generate report" |
| Upload | Transferring a file from local to remote | Specific | "Upload photo" |
| Import | Bringing in data from an external source | Specific | "Import contacts" |
| Record | Capturing audio or video | Specific | "Record voice memo" |

### Modify — Changing something that exists

| Verb | Use When | Tone | Example |
|---|---|---|---|
| Edit | Opening a form to change fields | Neutral | "Edit profile" |
| Update | Saving changes to an existing record | Neutral | "Update settings" |
| Change | Switching from one option to another | Direct | "Change password" |
| Rename | Changing only the name | Specific | "Rename file" |
| Move | Changing location in a hierarchy | Spatial | "Move to folder" |
| Resize | Changing dimensions | Specific | "Resize image" |
| Replace | Substituting one thing for another | Direct | "Replace file" |
| Reorder | Changing sequence | Specific | "Reorder columns" |

### Navigate — Moving through the interface

| Verb | Use When | Tone | Example |
|---|---|---|---|
| View | Opening a read-only detail screen | Passive | "View details" |
| Open | Launching a document or application | Neutral | "Open in editor" |
| Go to | Jumping to a specific location | Direct | "Go to settings" |
| Browse | Exploratory navigation | Casual | "Browse templates" |
| Explore | Open-ended discovery | Inviting | "Explore features" |
| Back | Returning to previous state | Terse | "Back to dashboard" |
| Show | Revealing hidden content | Direct | "Show more" |
| Expand | Enlarging a collapsed section | Specific | "Expand all" |

### Communicate — Sending or sharing information

| Verb | Use When | Tone | Example |
|---|---|---|---|
| Send | Transmitting a message or form | Final | "Send message" |
| Share | Making content available to others | Collaborative | "Share with team" |
| Publish | Making content publicly visible | Formal | "Publish article" |
| Submit | Sending a form for review or processing | Formal | "Submit application" |
| Post | Publishing to a feed or forum | Casual | "Post comment" |
| Invite | Requesting someone to join | Social | "Invite collaborator" |
| Notify | Alerting others of something | Informational | "Notify team" |

### Manage — Controlling, organizing, or removing

| Verb | Use When | Tone | Example |
|---|---|---|---|
| Save | Persisting current state | Neutral | "Save changes" |
| Delete | Permanently removing | Destructive | "Delete account" |
| Remove | Taking out of a collection (may not destroy) | Moderate | "Remove from list" |
| Archive | Moving to inactive storage | Moderate | "Archive conversation" |
| Cancel | Stopping a process or dismissing a dialog | Neutral | "Cancel subscription" |
| Disable | Turning a feature off without removing | Moderate | "Disable notifications" |
| Restore | Bringing back a deleted or archived item | Recovery | "Restore from trash" |
| Export | Downloading data to local | Specific | "Export as CSV" |
| Duplicate | Creating a copy | Specific | "Duplicate template" |

---

## 2. Error Message Templates

Every error message should answer three questions: What happened? Why did it happen? What can the user do about it?

### Form Validation Errors

**Email field**
- Bad: "Invalid input."
- Good: "Enter a valid email address, like name@example.com."

**Required field**
- Bad: "This field is required."
- Good: "Enter your last name to continue."

**Password strength**
- Bad: "Password too weak."
- Good: "Add at least one number and one uppercase letter. Your password needs to be 8+ characters."

**Character limit**
- Bad: "Too many characters."
- Good: "Shorten your bio to 160 characters. You're at 203."

**Number format**
- Bad: "Invalid number."
- Good: "Enter a number without commas or currency symbols, like 5000."

**Date format**
- Bad: "Invalid date."
- Good: "Enter the date as MM/DD/YYYY, like 03/15/2026."

**Phone number**
- Bad: "Invalid phone number."
- Good: "Enter a 10-digit phone number, like (555) 123-4567."

### Network Errors

**Connection lost**
- Bad: "Network error."
- Good: "You seem to be offline. Check your connection and try again."

**Timeout**
- Bad: "Request timed out."
- Good: "This is taking longer than usual. Check your connection or try again in a moment."

**Slow connection**
- Bad: "Loading..."
- Good: "Your connection is slow. This may take a bit longer than usual."

### Server Errors

**Generic server error**
- Bad: "500 Internal Server Error."
- Good: "Something went wrong on our end. Try again in a few minutes. If this keeps happening, contact support."

**Service unavailable**
- Bad: "503 Service Unavailable."
- Good: "We're doing some quick maintenance. We'll be back shortly — usually within a few minutes."

**Rate limited**
- Bad: "429 Too Many Requests."
- Good: "You've made a lot of requests in a short time. Wait a minute and try again."

### Permission Errors

**Not authorized**
- Bad: "403 Forbidden."
- Good: "You don't have access to this page. Ask your team admin for permission."

**Session expired**
- Bad: "401 Unauthorized."
- Good: "Your session has expired. Sign in again to continue where you left off."

**Feature locked**
- Bad: "Upgrade required."
- Good: "This feature is available on the Pro plan. Upgrade to unlock it."

### Conflict and Data Errors

**Duplicate entry**
- Bad: "Duplicate key error."
- Good: "An account with this email already exists. Try signing in instead."

**Conflict / concurrent edit**
- Bad: "409 Conflict."
- Good: "Someone else edited this document while you were working. Review their changes and try saving again."

**File too large**
- Bad: "File size exceeds limit."
- Good: "This file is 25 MB, but the maximum is 10 MB. Try compressing it or choosing a smaller file."

**Unsupported format**
- Bad: "Unsupported file type."
- Good: "We support JPG, PNG, and WebP files. Convert your file and try again."

---

## 3. Empty State Copy

Empty states are a user's first impression of a feature. They should educate, motivate, and provide a clear next action.

### First-Use Empty State

The user has never created content in this section.

- **Template**: "[Feature name] will appear here once you [primary action]. [One sentence of value proposition]."
- **Example**: "Your projects will appear here once you create one. Organize your work, track progress, and collaborate with your team."
- **CTA button**: "Create your first project"

### No Search Results

The user searched but nothing matched.

- **Template**: "No results for '[search term].' [Suggestion to broaden or rephrase.]"
- **Example**: "No results for 'quartely report.' Check the spelling or try a broader search like 'report.'"
- **Secondary action**: "Clear search" or "Browse all documents"

### No Data (Filters Applied)

The user applied filters that exclude all items.

- **Template**: "No [items] match your current filters. [Suggest adjusting filters.]"
- **Example**: "No invoices match your current filters. Try changing the date range or removing the status filter."
- **CTA button**: "Clear all filters"

### Error-Caused Empty State

Data could not be loaded due to an error.

- **Template**: "We couldn't load your [content]. [Brief explanation.] [Retry action.]"
- **Example**: "We couldn't load your recent activity. This is usually temporary — give it another try."
- **CTA button**: "Try again"

### Permission-Required Empty State

The user can see the section exists but lacks access.

- **Template**: "You need [specific permission] to view [content]. [Who to contact.]"
- **Example**: "You need editor access to view team analytics. Ask your workspace admin to update your role."
- **CTA button**: "Request access"

---

## 4. Loading State Copy

Loading states fill the gap between action and result. They should reduce perceived wait time and set expectations.

### Skeleton Text

Skeleton screens replace content with gray placeholder shapes. No copy is needed — the shapes themselves communicate "content is loading." However, if skeletons persist beyond 2 seconds, add text.

- **After 2 seconds**: "Loading your dashboard..."
- **After 5 seconds**: "Still loading. This may take a moment."
- **After 10 seconds**: "This is taking longer than expected. You can wait or try refreshing."

### Progress Descriptions

For multi-step processes, describe what is happening.

- **File upload**: "Uploading report.pdf... 64% complete"
- **Data processing**: "Analyzing 12,000 records... This usually takes about 30 seconds."
- **Export**: "Preparing your export. We'll notify you when it's ready to download."
- **Account setup**: "Setting up your workspace... Creating default channels... Almost done."

### Estimated Time

Show estimated time only when you can predict it accurately. An inaccurate estimate is worse than no estimate.

- **Accurate estimate**: "Exporting 5,000 rows. About 10 seconds remaining."
- **Uncertain duration**: "Processing your request. This may take a few minutes." (Do not say "2 minutes" if you are guessing.)

### Humor Guidelines

Humor in loading states can reduce frustration, but apply it carefully.

- **When humor works**: Consumer apps with a playful brand, waits over 5 seconds where tension builds, contexts where the user chose to wait (e.g., generating a report they requested).
- **When humor fails**: Enterprise or medical software, error-adjacent loading (will this fail?), repeat experiences (a joke is funny once, annoying the hundredth time).
- **Examples that work**: "Crunching the numbers..." / "Waking up the servers..." / "Almost there. Putting the finishing touches on your report."
- **Examples that fail**: "Hold on, we're not that fast!" / "Patience is a virtue!" (Condescending.) / "Wow, you have a lot of data!" (Implies blame.)

---

## 5. Confirmation Dialog Copy

Confirmation dialogs prevent accidental destructive actions. They must clearly state the consequence and provide unambiguous button labels.

### Destructive Action

- **Title**: "Delete this project?"
- **Body**: "This will permanently delete 'Q4 Marketing Campaign' and all its 23 tasks. This action cannot be undone."
- **Buttons**: "Delete project" (destructive, red) / "Keep project" (secondary)
- **Never**: "Are you sure?" with "Yes" / "No" buttons. "Yes" to what? Force the user to re-read the title.

### Data Loss Warning

- **Title**: "Discard unsaved changes?"
- **Body**: "You have unsaved changes to this document. If you leave now, your changes will be lost."
- **Buttons**: "Discard changes" (destructive) / "Save and leave" (primary) / "Keep editing" (tertiary/link)

### Irreversible Action

- **Title**: "Close your account?"
- **Body**: "This permanently deletes all your data, including 47 projects and 1,200 files. You will not be able to recover this data. Type 'DELETE' to confirm."
- **Buttons**: "Permanently close account" (destructive, disabled until confirmation typed) / "Cancel"

### Send / Publish

- **Title**: "Publish this article?"
- **Body**: "This will make 'Getting Started with Data Viz' visible to all users. You can unpublish it later."
- **Buttons**: "Publish" (primary) / "Cancel"

### Bulk Action

- **Title**: "Delete 15 items?"
- **Body**: "You selected 15 files. They will be moved to Trash and automatically deleted after 30 days."
- **Buttons**: "Delete 15 items" (destructive) / "Cancel"
- **Pattern**: Always include the count in both the title and the button label so the user sees the scope.

---

## 6. Permission Request Copy

Permission requests are trust negotiations. Users must understand why you need access before they grant it.

### Camera Access

**Pre-permission (shown before the OS prompt)**:
- "To scan documents, we need access to your camera. You can change this later in Settings."
- **CTA**: "Allow camera access"

**In-context (shown when the user taps a camera feature)**:
- "Tap the button below to take a profile photo. We'll ask for camera access."

**Denied state**:
- "Camera access was denied. To use this feature, enable Camera in Settings > Privacy > Camera > [App Name]."

### Location Access

**Pre-permission**:
- "We use your location to show nearby stores and estimate delivery times. Your location is never shared with other users."
- **CTA**: "Share location"

**In-context**:
- "To find restaurants near you, we need your location. We only use it while the app is open."

**Denied state**:
- "Location access is off. Turn it on in Settings > Privacy > Location Services to see nearby results."

### Notification Access

**Pre-permission**:
- "Get notified when your order ships, when someone replies to your message, or when a price drops. You can customize which notifications you receive."
- **CTA**: "Turn on notifications"

**In-context**:
- "Want to know when this item goes on sale? Turn on notifications and we'll alert you."

**Denied state**:
- "Notifications are turned off. Enable them in Settings > Notifications > [App Name] to get updates."

### Contacts Access

**Pre-permission**:
- "We can check if any of your contacts are already on [App Name] so you can connect with them. We never store or share your contact list."
- **CTA**: "Find my contacts"

**Denied state**:
- "Contact access is off. You can still invite people by sharing a link."

### Microphone Access

**Pre-permission**:
- "To record voice messages, we need access to your microphone. Recordings are only sent when you choose to share them."
- **CTA**: "Allow microphone"

**In-context**:
- "Hold the button to record a voice note. We'll ask for microphone access the first time."

---

## 7. Onboarding Copy

Onboarding copy introduces users to your product. It must be concise, benefit-focused, and skippable.

### Welcome Screen

- **Template**: "Welcome to [App Name]. [One sentence: what the user can do.] [One sentence: the primary benefit.]"
- **Example**: "Welcome to Flowboard. Organize your work in flexible boards and lists. Spend less time managing tasks and more time completing them."
- **CTA**: "Get started" (primary) / "Skip tour" (text link)

### Feature Introduction (Carousel or Tooltip Tour)

Each step should follow this structure:

- **Heading**: Action-oriented, 3-6 words. Not a feature name — a benefit.
- **Body**: One sentence explaining how to use it and why it matters.
- **Example step 1**: Heading: "See everything at a glance." Body: "Your dashboard shows tasks, deadlines, and team activity in one place."
- **Example step 2**: Heading: "Collaborate in real time." Body: "Mention teammates with @ to loop them in and get faster answers."
- **Example step 3**: Heading: "Never miss a deadline." Body: "Set due dates and get reminders before tasks are overdue."

### Value Proposition (Pre-Signup or Trial)

- **Headline**: State the outcome, not the feature. "Ship projects on time" not "Project management tool."
- **Subhead**: One sentence expanding on the headline. "Plan, track, and collaborate with your team in a single workspace."
- **Social proof**: "Trusted by 50,000 teams" or "4.8 stars on the App Store."
- **CTA**: "Start free trial" (primary) / "See how it works" (secondary, links to demo)

### Progressive Disclosure

Do not explain everything on day one. Introduce features when they become relevant.

- **Trigger-based tips**: "You just created your first project! Did you know you can invite teammates to collaborate? [Invite team]"
- **Milestone-based tips**: "You've completed 10 tasks this week. Try the weekly review feature to track your progress. [Try it]"
- **Dismissal**: Every tip must be dismissable. Provide "Got it" or "Don't show again." Honor the dismissal permanently.

---

## 8. Success State Copy

Success states confirm that the user's action worked. They should be clear, brief, and proportional to the action.

### Completion

For routine actions, a brief toast notification is sufficient.

- **File saved**: "Changes saved." (No exclamation mark — saving is routine.)
- **Email sent**: "Message sent to 3 recipients."
- **Profile updated**: "Profile updated."
- **Payment processed**: "Payment of $49.00 processed. You'll receive a receipt by email."

### Achievement

For meaningful milestones, slightly more celebration is appropriate.

- **First project created**: "Your first project is live! Share it with your team to start collaborating."
- **Goal reached**: "You've hit your weekly reading goal. 7 articles in 7 days."
- **Streak**: "12-day streak! You've logged in every day for almost two weeks."

### Milestone

For significant, infrequent accomplishments, a dedicated screen is appropriate.

- **Account verified**: Title: "You're verified." Body: "Your identity has been confirmed. You now have full access to all features."
- **Course completed**: Title: "Course complete!" Body: "You finished 'Advanced Data Visualization.' Download your certificate below."
- **Migration finished**: Title: "Migration complete." Body: "All 2,340 records have been imported. Review your data to make sure everything looks right."

### Celebration Without Excess

- **Match the magnitude**: A saved form gets a toast. A completed 6-month project gets a full-screen moment. Mismatch in either direction feels wrong.
- **Avoid false excitement**: Do not add confetti to a password change. Do not use exclamation marks for routine saves. The word "Congratulations!" should be reserved for genuinely congratulatory moments.
- **Provide next steps**: Every success state is an opportunity for forward momentum. "Payment processed" can be followed by "View your order" or "Continue shopping."

---

## 9. Tooltip and Helper Text

Tooltips and helper text answer questions before users ask them.

### When to Use Tooltips

- **Use tooltips for**: Icons without visible labels, abbreviated column headers, technical terms, form fields that benefit from additional context, disabled buttons (explain why it is disabled).
- **Do not use tooltips for**: Essential information the user must see to complete the task (they are not discoverable on mobile), long-form help content (use a help panel or link instead), information that is already visible in surrounding text.

### Length Guidelines

- **Tooltip**: 5-15 words. One sentence maximum. No periods unless there are multiple sentences (which there should not be).
- **Helper text below form fields**: 10-25 words. One sentence. Example: "This is the email address your team will use to reach you."
- **Inline help**: 15-40 words. Displayed in a callout or info box near the relevant element.

### Placement Rules

- **Tooltips**: Display above the trigger element by default. Flip to below if near the top viewport edge. Never obscure the element being described.
- **Helper text**: Always directly below the form field, between the input and the error message position. Use a lighter text color (but meeting 4.5:1 contrast ratio) to visually subordinate it to the input value.
- **Info icons**: Place the info icon (circled "i") inline after the label text, not after the input field. The icon triggers the tooltip.

### Writing Guidelines

- **Be specific**: "Your display name is visible to other team members" is better than "Enter your name."
- **Explain constraints upfront**: "Must be between 3 and 30 characters" prevents trial-and-error.
- **Use examples**: "Like 'Q4 Marketing Plan' or 'Website Redesign'" helps users understand the expected format.
- **Avoid stating the obvious**: A tooltip on a "Save" button that says "Saves your changes" adds nothing. Only add tooltips that provide information the user would not already know.

---

## 10. Tone Spectrum

Microcopy tone should be consistent with brand voice but adaptive to context. The same product can use different tones in different moments.

### The Spectrum

| Tone Level | Description | Use When | Example |
|---|---|---|---|
| **Formal** | Professional, precise, no contractions | Legal agreements, medical information, financial transactions, security alerts | "Your account will be permanently deactivated. This action cannot be reversed." |
| **Professional** | Clear, direct, occasional contractions | Enterprise software, settings, documentation, admin interfaces | "You don't have permission to view this page. Contact your admin for access." |
| **Friendly** | Warm, conversational, uses "you" and "we" | Consumer apps, onboarding, success states, feature introductions | "You're all set! Your workspace is ready. Invite your team to get started." |
| **Casual** | Relaxed, playful, may use colloquialisms | Social apps, gaming, creative tools, loading states | "Nice! Your design is looking great. Share it with the world?" |
| **Playful** | Humorous, personality-driven, uses wordplay | Brand moments, easter eggs, marketing-adjacent surfaces | "Inbox zero. Go outside. Touch grass. You've earned it." |

### Context-Dependent Tone Shifts

Even within a single product, tone shifts based on context.

- **Error messages**: One notch more formal than the product's baseline. Errors are not the time for jokes.
- **Success messages**: One notch more casual than baseline. Celebrate gently.
- **Destructive actions**: Always professional or formal. "This will permanently delete your data" should never sound casual.
- **Onboarding**: One notch more friendly than baseline. First impressions benefit from warmth.
- **Help documentation**: Match the product baseline exactly. Consistency aids comprehension.

### Brand Voice Consistency

- **Create a voice chart**: Define 3-4 voice attributes (e.g., "Clear, Confident, Friendly, Never Condescending") and provide do/don't examples for each.
- **Write a word list**: Document preferred terms. Do you say "Sign in" or "Log in"? "Delete" or "Remove"? "Settings" or "Preferences"? Pick one and use it everywhere.
- **Audit regularly**: Microcopy written by different team members drifts over time. Quarterly audits catch inconsistencies before users notice them.
- **Localization consideration**: Humor, idioms, and contractions do not always translate. If your product is localized, write source copy that is clear enough to survive translation. Avoid puns, cultural references, and slang that a translator might misinterpret or be forced to abandon.

### The Golden Rules of Microcopy

1. **Clarity over cleverness.** A user who understands immediately beats a user who smiles but hesitates.
2. **Say less.** Every word competes for attention. Fewer words mean each remaining word carries more weight.
3. **Use the user's language.** If your users say "customers," do not say "contacts." If they say "send," do not say "dispatch."
4. **Front-load the important word.** "Delete 15 files permanently" puts the action first. "Are you sure you want to permanently delete the 15 files you selected?" buries it.
5. **Be specific about consequences.** "This can't be undone" is good. "Your 23 tasks and 4 attachments will be permanently deleted" is better.
6. **Test with real users.** The microcopy you think is clear may confuse the people who actually use your product. A/B test critical flows. Run comprehension tests on error messages. Watch session recordings for hesitation.

---

## Quick Reference Card

| Interface State | Key Principle | Max Length |
|---|---|---|
| Button label | Start with a verb, be specific | 1-3 words |
| Error message | What happened + what to do | 1-2 sentences |
| Empty state | Educate + motivate + CTA | 2-3 sentences + button |
| Loading state | Set expectations, show progress | 1 sentence |
| Confirmation dialog | State the consequence, label buttons specifically | Title + 1-2 sentences |
| Permission request | Explain why + reassure about privacy | 1-2 sentences |
| Tooltip | Answer one specific question | 5-15 words |
| Success message | Confirm + suggest next step | 1 sentence |
| Onboarding step | Benefit headline + how-to sentence | Heading + 1 sentence |

Every word in your interface is a design decision. Treat microcopy with the same rigor you apply to layout, color, and interaction design.
