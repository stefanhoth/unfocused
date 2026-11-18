# Agentic AI and Multi-Agent UX Design Patterns

## Authoritative Reference for Designing Agent-Driven Interfaces

This reference defines the design patterns, interaction models, and UX principles required to build interfaces where one or more autonomous AI agents act on behalf of users. These patterns address the fundamental shift from user-as-operator to user-as-supervisor, covering single-agent autonomy, multi-agent coordination, background task management, agent memory, platform copilot integration, and the emerging paradigms that move AI interfaces beyond conversational chat into task-centric, hybrid, and generative territory.

---

## Agentic AI Design Principles

### Autonomy Boundaries

Define a clear autonomy envelope for every agent in the system. The autonomy envelope specifies exactly which decisions the agent makes independently, which it recommends and awaits approval for, and which it must never attempt.

Classify every agent action into one of four autonomy tiers:

| Tier | Agent Behavior | User Involvement | Example |
|------|---------------|-------------------|---------|
| **Silent** | Acts and logs | None unless user inspects logs | Formatting a document, caching search results |
| **Notify** | Acts and sends a non-blocking notification | User reviews after the fact | Sending a routine status email, filing a low-priority ticket |
| **Confirm** | Proposes action and pauses for approval | User approves, modifies, or rejects | Scheduling a meeting on the user's calendar, purchasing under $50 |
| **Escalate** | Surfaces the decision with full context and does not proceed | User must decide and instruct | Deleting production data, sending a contract, spending over a threshold |

Map every capability the agent possesses to exactly one tier. Publish the mapping in a visible "Agent Permissions" panel accessible from the agent's profile or settings. Allow users to promote or demote individual actions between tiers — a user who trusts the agent with calendar management can move scheduling from Confirm to Notify, while a cautious user can move it to Escalate.

Never allow silent-tier actions for irreversible operations. Irreversibility is the primary axis for tier assignment: the harder an action is to undo, the higher its default tier must be.

### Escalation Design

Design the escalation moment as a first-class interaction, not an error state. When an agent escalates, present a **decision card** containing:

- **What** the agent wants to do (specific, concrete action description).
- **Why** the agent believes this action is appropriate (reasoning trace, abbreviated).
- **Risk** — what could go wrong if the action proceeds, and what happens if it does not.
- **Alternatives** — other actions the agent considered and why it ranked them lower.
- **Controls** — Approve, Modify (open an inline editor for the proposed action), Reject (with an optional instruction for what to do instead), and Defer (snooze the decision for a configurable duration).

Batch related escalations. If an agent needs approval for twelve similar file renames, present them as a grouped decision card with individual override capability rather than twelve separate interruptions. Show the count, a summary of the pattern, and an "Approve All / Review Individually" toggle.

Implement **escalation urgency levels** using progressive notification intensity. Low-urgency escalations appear as badge counts or inbox items. Medium-urgency escalations surface as toast notifications or banner alerts. High-urgency escalations use modal interruptions or system-level notifications. Never cry wolf — reserve high-urgency for genuinely time-sensitive or high-stakes decisions.

### Agent Memory: Cross-Session State

Agent memory is what transforms a stateless assistant into a persistent collaborator. Design memory as a first-class, user-visible system with clear boundaries.

Organize agent memory into three layers:

1. **Session memory:** Active conversation context. Discarded when the session ends unless the user explicitly saves it.
2. **Episodic memory:** Remembered facts from past sessions — user preferences, past decisions, project context, corrected mistakes. Persists across sessions. Decays or is pruned based on relevance and age.
3. **Semantic memory:** Learned generalizations about the user — preferred communication style, risk tolerance, domain expertise level, recurring patterns. Updated incrementally as episodic memories accumulate.

Display memory state transparently. Provide a **Memory Inspector** panel where users can browse what the agent remembers, organized by category (preferences, facts, corrections, context). Show when each memory was created or last accessed. Allow users to edit, pin (prevent decay), or delete individual memories.

Surface memory usage in context. When the agent's response is influenced by a remembered preference, show a subtle inline indicator: "Using your preferred format (learned Oct 2025)." Make the indicator clickable to view and optionally revoke the memory.

### Forgetting Controls

Give users absolute authority over agent memory. Implement forgetting at multiple granularities:

- **Delete a single memory:** Remove one specific fact or preference from the Memory Inspector.
- **Forget a topic:** Erase all memories related to a specific project, person, or subject area.
- **Forget a session:** Remove all memories derived from a specific past conversation.
- **Factory reset:** Clear all episodic and semantic memory, returning the agent to its default state.

Confirm destructive forgetting operations with a preview of what will be deleted. For topic-level and broader deletions, show the count and a sample of affected memories before executing.

Implement a **memory pause** mode where the agent continues to function but stops forming new long-term memories. Display a visible indicator (analogous to a browser's incognito mode) so users always know whether the current session is being remembered.

---

## Multi-Agent Coordination Dashboards

### Orchestration Visibility Patterns

When a system deploys multiple specialized agents working together, expose the orchestration structure to the user. Hidden coordination breeds confusion and distrust.

Design a **workflow plan view** that shows the complete agent pipeline before execution begins. Render this as a directed acyclic graph (DAG) where nodes represent agent tasks and edges represent dependencies and data flow. Label each node with the assigned agent's name, the task description, and the estimated duration. Allow users to approve the plan, reorder steps, remove steps, or add manual intervention points before execution begins.

```
┌─────────────┐     ┌──────────────┐     ┌─────────────────┐
│  Research    │────▶│  Analysis    │────▶│  Report Writer  │
│  Agent       │     │  Agent       │     │  Agent          │
│  ⏳ ~2 min   │     │  ⏳ ~1 min   │     │  ⏳ ~3 min      │
└─────────────┘     └──────────────┘     └─────────────────┘
       │                                          │
       │            ┌──────────────┐              │
       └───────────▶│  Fact-Check  │◀─────────────┘
                    │  Agent       │
                    │  ⏳ ~1 min   │
                    └──────────────┘
```

### Swimlane Views

For workflows with parallel agent activity, use a **swimlane visualization** where each horizontal lane represents one agent. Time flows left to right. Active task blocks fill each lane with color-coded status:

| Status | Visual Treatment |
|--------|-----------------|
| Queued | Gray block, dashed border |
| Running | Blue block, animated pulse |
| Waiting for input | Yellow block, attention icon |
| Complete | Green block, checkmark |
| Failed | Red block, error icon |
| Paused | Gray block, pause icon |

Show dependency arrows between lanes where one agent's output feeds into another's input. Highlight the critical path — the sequence of dependent tasks that determines total completion time — with a distinct visual treatment so users understand which agent is the bottleneck.

### Dependency Graphs

For complex multi-agent workflows with non-linear dependencies, provide an interactive **dependency graph** view. Render agents as nodes and data/control flow as directed edges. Support zoom, pan, and click-to-inspect on any node to see the agent's current status, inputs received, outputs produced, and execution logs.

Animate the graph during execution: light up edges as data flows between agents, pulse nodes when they are actively processing, and gray out completed nodes. Provide a timeline scrubber that allows users to replay the execution history and understand what happened at any point.

### Agent Status Indicators

Display a persistent **agent status bar** that summarizes the state of all active agents without requiring users to open the full dashboard. Design this as a compact horizontal strip or a floating widget showing:

- Agent avatar or icon for each active agent.
- Current status (idle, working, waiting, error) as a color-coded dot.
- A one-line description of current activity on hover.
- Click-to-expand for full detail.

Aggregate status into a single summary when many agents are active: "4 agents working, 1 waiting for input, 2 complete." Link the summary to the full dashboard.

---

## Agent Identity, Specialization, and Handoff Visualization

### Distinct Agent Personas

Assign each agent a **clear identity** composed of:

- **Name:** A descriptive, memorable name that communicates the agent's specialization. "Research Agent," "Code Reviewer," "Data Analyst" — never "Agent 1" or "Bot A."
- **Avatar:** A unique visual icon or illustration that is instantly recognizable in status bars, notifications, and conversation threads.
- **Role description:** A one-sentence summary of the agent's capabilities and operating domain, displayed in the agent's profile card and on first introduction.
- **Capability badges:** Small, scannable labels listing the agent's key capabilities (e.g., "Web Search," "Code Execution," "File I/O," "API Access"). Display badges in the agent's profile and wherever the agent is identified in the UI.

Introduce agents to users before they act. When a new agent enters a workflow for the first time, show a brief introduction card: "Meet Research Agent. It searches the web, academic databases, and your company knowledge base to find relevant sources. It cannot modify files or execute code."

### Active Agent Indicator

Always show **which agent is currently acting**. In conversation threads, prefix each message with the agent's avatar and name. In dashboard views, highlight the active agent's swimlane or node. In notification banners, include the originating agent's identity.

When multiple agents are active simultaneously, show all of them with distinct visual treatments. Never merge outputs from different agents into an undifferentiated stream — users must always know which agent produced which output.

### Handoff Animations and Transitions

Visualize the moment one agent passes control or data to another. Design handoff transitions that communicate:

1. **Who** is handing off (source agent identity).
2. **What** is being handed off (summary of data or context transferred).
3. **Who** is receiving (destination agent identity).
4. **Why** the handoff is happening (the source agent's task is complete, or the task requires different capabilities).

Render handoffs in conversation views as a distinct **handoff message** styled differently from regular agent messages:

```
───────────────────────────────────────────
🔄 Handoff: Research Agent → Writing Agent
   Passing: 12 sources, topic outline, key findings summary
   Reason: Research phase complete. Writing phase begins.
───────────────────────────────────────────
```

In graph and swimlane views, animate the edge between agents with a data-flow animation (a dot or pulse traveling along the connection line) at the moment of handoff.

Allow users to **inspect handoff payloads**. Clicking the handoff message reveals the full data package being transferred, allowing users to verify that the correct context is being passed and to intervene if critical information is missing.

---

## Background Task Management UX

### Monitoring Widgets

Design **persistent monitoring widgets** for agents running asynchronous tasks while users work on other things. Place these widgets in a consistent location — a bottom bar, a sidebar panel, or a floating overlay — that is always accessible but never obstructs the primary workspace.

Each background task widget displays:

- Agent name and avatar.
- Task description (one line).
- Progress indicator (determinate progress bar when estimable, indeterminate animation when not).
- Elapsed time and estimated time remaining.
- Status (running, paused, waiting for input, complete, failed).
- Quick actions: Pause, Resume, Cancel, View Details.

Support **widget density modes**: expanded (full detail per task), compact (icon + progress bar + status dot per task), and minimized (single aggregate indicator showing count and overall status).

### Attention-on-Demand Notifications

Implement a **progressive urgency** notification model where agents work silently by default and escalate their demands for attention based on the situation:

| Situation | Notification Level | Treatment |
|-----------|-------------------|-----------|
| Task progressing normally | Silent | Update widget only |
| Task complete, results ready | Gentle | Badge count, subtle toast |
| Task blocked, needs user input | Moderate | Persistent banner, sound optional |
| Task failed or encountered critical error | Urgent | Modal or system notification |
| Time-sensitive decision required | Critical | Modal with countdown, sound |

Never interrupt the user for routine completions. Accumulate completed task notifications and present them in a batch when the user next checks the monitoring widget or returns to the agent's workspace.

### Result Staging: Review Before Apply

When an agent completes a background task, **stage results for review** rather than auto-applying them. Present results in a dedicated review interface that shows:

- What the agent produced (full output preview).
- What will change if the user applies the results (diff view for modifications, preview for new content).
- Confidence indicators on individual output elements.
- Accept All, Accept with Modifications, and Reject actions.

For tasks that produce multiple artifacts, allow **granular acceptance**: accept some outputs, reject others, and request regeneration of specific items. Maintain the staged results until the user takes action — never auto-expire or auto-apply staged outputs without explicit user configuration.

### Task Queue Management

Provide a **task queue interface** where users can view, reorder, and manage all pending and active agent tasks:

- Drag-and-drop reordering to prioritize tasks.
- Bulk actions: pause all, resume all, cancel selected.
- Filters: by agent, by status, by priority, by creation date.
- Resource allocation visibility: if agents share compute or API quota, show how resources are distributed across queued tasks.

---

## Agent Memory and Learning UX

### Preference Learning Indicators

When the agent learns a new preference or pattern from user behavior, **surface the learning transparently**. Display a brief, non-blocking notification: "Noticed you prefer bullet points over paragraphs for summaries. I'll use that format going forward." Include a one-click "Don't learn this" dismissal and a link to the Memory Inspector.

Design a **learning log** accessible from the agent's settings that shows a chronological list of everything the agent has learned, with timestamps, the source interaction, and the inferred preference. Allow users to confirm, correct, or delete any learned item.

### "The Agent Is Learning From You" Transparency

Make the learning process visible without being intrusive. Show a subtle, persistent indicator when the learning system is active — analogous to a recording indicator on a camera. Use language that respects user agency: "Adapting to your preferences" rather than "Training on your data."

Distinguish between **local learning** (preferences stored on-device, used only for this user) and **federated learning** (anonymized patterns contributed to model improvement). Provide separate opt-in controls for each. Default local learning to opt-in and federated learning to opt-out.

### Memory Inspection Interfaces

Build a comprehensive **Memory Inspector** that treats agent memory as user-owned data:

- **Browse by category:** Preferences, facts, corrections, context, relationships.
- **Search memories:** Full-text search across all stored memories.
- **Sort by recency, frequency of use, or relevance.**
- **View source:** For each memory, show the conversation or interaction that created it.
- **Edit:** Allow users to modify stored memories (correct an inferred preference, update a stored fact).
- **Export:** Download all agent memories as a structured file (JSON or CSV) for portability.

### Privacy Implications of Agent Memory

Address privacy proactively in the memory system design:

- Clearly label what is stored locally versus in the cloud.
- Apply automatic expiration to sensitive categories (financial data, health information) unless the user explicitly pins them.
- Never store raw conversation content as memory — extract and store only the inferred facts and preferences.
- Provide compliance controls for regulated environments: GDPR right-to-erasure mapped to factory reset, data portability mapped to memory export, purpose limitation mapped to per-category memory controls.
- Display a **privacy summary** in the Memory Inspector header: "23 memories stored locally. 0 sent to cloud. Last pruned: 3 days ago."

---

## Platform Copilot Guidelines

### Microsoft Copilot Framework Design Principles

Apply Microsoft's responsible AI design principles when building copilot experiences:

- **User control at all times:** The user can override, undo, or disable any copilot action. Never remove the manual path.
- **Transparency of process:** Show what data the copilot accessed, what reasoning it applied, and what confidence level it assigns.
- **Grounded in user data:** Copilot responses must reference specific user documents, emails, or data rather than generating from pure model knowledge. Display source attributions.
- **Iterative refinement:** Design for multi-turn interaction where the user progressively refines the copilot's output rather than expecting perfection on the first attempt.
- **Skill-based architecture:** Organize copilot capabilities as discrete, named skills that users can discover, invoke, and configure independently.

### OpenAI Apps SDK Design Patterns

Design for the three display modes defined by the OpenAI Apps SDK:

| Display Mode | Viewport | Use Case | Layout Guidance |
|-------------|----------|----------|-----------------|
| **Inline** | Embedded within host content | Contextual assistance, annotations, inline tools | Maximum 400px width, scrollable, no overlays |
| **Floating** | Overlay panel anchored to trigger | Quick interactions, lookups, brief tasks | 320-480px width, 400-600px height, dismissible |
| **Fullscreen** | Entire viewport | Complex tasks, multi-step workflows, immersive experiences | Full responsive layout, own navigation |

Implement **token-based rendering** where the app receives streamed tokens and renders them progressively. Use the SDK's component primitives for consistent styling:

```jsx
// OpenAI Apps SDK component structure
<AppContainer displayMode="floating">
  <Header title="Research Assistant" />
  <MessageList>
    <AssistantMessage streaming={true}>
      <Citation source={doc} />
      <ActionButton label="Apply" onClick={handleApply} />
    </AssistantMessage>
  </MessageList>
  <InputBar placeholder="Ask a follow-up..." />
</AppContainer>
```

### GitHub Copilot Patterns

Apply the established GitHub Copilot interaction patterns as the benchmark for inline code assistance:

- **Ghost text:** Display suggestions as semi-transparent text at the cursor position. Use a color that is clearly distinguishable from authored code (typically 40-50% opacity of the editor's foreground color).
- **Tab-to-accept:** Accept the entire suggestion with a single Tab keypress. Continue typing to dismiss implicitly. Esc to dismiss explicitly.
- **Word-level acceptance:** Use Ctrl+Right (or Cmd+Right) to accept one word at a time for partial adoption.
- **Cycle alternatives:** Use Alt+] and Alt+[ to cycle through alternative suggestions without dismissing the current one.
- **Copilot Chat panel:** A sidebar conversation that maintains awareness of the open file, selected code, and terminal output. References to code are rendered as clickable links that navigate to the relevant file and line.
- **Inline chat (Ctrl+I):** A transient input field that appears at the cursor position for quick instructions ("refactor this function," "add error handling") and applies the result as an inline diff.

### CopilotKit Patterns for Frontend Integration

Apply CopilotKit's patterns for embedding copilot functionality directly into frontend applications:

- **Copilot-aware components:** Annotate UI components with semantic descriptions that the copilot can read and act upon. This gives the copilot understanding of the application's current state and available actions.
- **Copilot actions:** Define callable functions that the copilot can invoke in response to user requests, bridging natural language to application-specific operations.
- **Copilot-readable state:** Expose application state to the copilot in structured form so it can reason about the user's current context without screen-reading heuristics.
- **Copilot textarea:** A text input component that provides inline AI assistance (autocompletion, rewriting, expansion) within any text field in the application, not just a dedicated chat interface.

---

## The "Beyond Chat" Paradigm

### Why Chat Alone Is Insufficient

Chat interfaces are effective for open-ended exploration, simple question-answering, and ambiguous tasks where the user's goal is not yet well-defined. They fail for:

- **Structured data entry:** Collecting fifteen parameters through a conversation is slower and more error-prone than filling a form.
- **Comparison tasks:** Evaluating five options side-by-side is impossible in a linear message thread.
- **Spatial reasoning:** Arranging elements on a canvas, designing layouts, or organizing information hierarchically requires direct manipulation, not description.
- **Precision control:** Adjusting a value by 3% is faster with a slider than with a sentence.
- **Monitoring:** Watching six real-time metrics requires a dashboard, not a chatbot.

### Task-Centric vs. Conversation-Centric Interfaces

Design the interface around the task structure, not the conversation structure. A conversation-centric UI puts the chat thread at the center and treats everything else as secondary. A task-centric UI puts the task artifact (the document, the dashboard, the code, the design) at the center and treats conversation as one of several input/control mechanisms.

| Dimension | Conversation-Centric | Task-Centric |
|-----------|---------------------|--------------|
| Primary viewport | Chat thread | Task artifact (document, canvas, dashboard) |
| AI input method | Text prompt | Text prompt + direct manipulation + structured controls |
| AI output | Text response in thread | Modifications to the artifact, inline annotations, structured results |
| History | Conversation scroll | Version history of the artifact |
| Collaboration | Chat participants | Co-editors of the artifact |

### Hybrid Interfaces: Chat + Structured UI

Build **hybrid interfaces** that combine conversational input with structured output and controls:

1. **Chat as command input:** The user types natural language in a chat-like input. The system responds with structured UI elements — forms, tables, charts, diffs — rendered inline in the conversation or in an adjacent panel.
2. **Structured UI with chat fallback:** The primary interface is a structured application (form, editor, dashboard). When the user encounters something the structured UI does not handle, they drop into a contextual chat that is aware of the current application state.
3. **Parallel panels:** A persistent chat panel sits alongside the main workspace. The user can direct the AI through chat, and the AI's actions are reflected in the workspace in real time.

### When to Use Each Interaction Mode

| Mode | Best For | Avoid When |
|------|----------|------------|
| **Chat** | Ambiguous goals, exploratory queries, open-ended brainstorming, simple Q&A | Structured data entry, precision adjustment, spatial tasks |
| **Forms** | Known parameter collection, structured data entry, configuration | User's goal is ambiguous, parameters are unknown upfront |
| **Direct manipulation** | Spatial arrangement, visual design, drag-and-drop organization, precision control | User cannot see the target state, too many options for manual selection |
| **Generative UI** | Variable-structure tasks, personalized interfaces, complex tasks that resist static layouts | Simple, well-understood tasks with stable interaction patterns |

### Progressive Interface Escalation

Design systems that **start with the simplest appropriate interface and escalate** as task complexity demands:

1. **Start with chat** for goal elicitation: "What do you want to accomplish?"
2. **Escalate to a form** when the system identifies the required parameters: "I need these 5 inputs to proceed."
3. **Escalate to a workspace** when the task involves iterative manipulation of an artifact: "Here's the draft — edit directly or tell me what to change."
4. **Escalate to a dashboard** when the task involves monitoring multiple parallel activities: "Your agents are working — here's the status."

Signal each escalation explicitly. Show the transition: "This is getting complex — let me set up a proper workspace for you." Allow users to collapse back to chat at any time.

---

## Prompt Engineering UX

### The Six Augmentation Patterns

Design interfaces that help users craft effective prompts without requiring them to learn prompt engineering. These six patterns, identified in UX research on human-AI co-creation, transform prompting from an expert skill into an accessible interaction.

### 1. Style Galleries

Present a **visual grid of example outputs** organized by style, mood, or approach. The user browses and selects a reference output rather than describing the desired style in words.

Design the gallery as a filterable grid with large thumbnail previews. Support hover-to-enlarge and click-to-select. Show the prompt or style parameters that produced each example beneath the thumbnail. Allow multi-select to combine attributes from different examples ("the color palette of this one with the layout of that one").

Place the gallery adjacent to the prompt input so users can browse examples while composing their request. Update the gallery dynamically based on the user's current prompt text to show the most relevant style options.

### 2. Prompt Rewrite

After the user submits a prompt, the system **improves it automatically** and shows both the original and enhanced versions. Display the rewrite in a diff-like view highlighting what was added, removed, or restructured.

```
Original:  "Make a landing page for my app"
Rewritten: "Design a modern, mobile-responsive landing page for a
            productivity app targeting remote workers. Include a hero
            section with value proposition, feature highlights with
            icons, social proof section, and a clear call-to-action.
            Use a clean, professional color scheme."
```

Provide "Use Original," "Use Rewrite," and "Edit Rewrite" actions. Show the rewrite before generating the output so users understand what the AI is actually working from. Track which rewrites users accept to improve the rewrite model over time.

### 3. Targeted Rewrite

Instead of rewriting the entire prompt, identify the **weakest or most ambiguous part** and suggest a specific improvement for just that section. Highlight the problematic span in the user's prompt and show the suggestion inline.

Design this as an **underline and tooltip** pattern: the weak span gets a yellow underline, and hovering reveals the suggestion with a one-click accept action. Alternatively, show a margin annotation pointing to the specific span with the improvement text.

### 4. Related Prompts

After generating a result, display a set of **follow-up prompt suggestions** that refine, extend, or vary the output. Present these as clickable chips or cards below the result.

Organize related prompts into categories:

- **Refine:** "Make it more formal," "Simplify the language," "Add more detail to section 2."
- **Extend:** "Now create the about page," "Generate matching social media posts," "Add an FAQ section."
- **Vary:** "Show a darker color scheme," "Try a minimalist version," "What would this look like for a B2B audience?"

### 5. Prompt Builders

Provide **structured forms that construct prompts** from discrete inputs. Replace a blank text field with a guided builder that collects parameters through dropdowns, chips, and text fields.

Design the builder as a collapsible panel with fields for:

- **Task type** (dropdown: generate, edit, analyze, summarize, translate).
- **Subject** (text input: the topic or content).
- **Tone** (chip selector: professional, casual, technical, creative, academic).
- **Audience** (text input or dropdown: executives, developers, general public).
- **Length** (radio: brief, standard, detailed, comprehensive).
- **Format** (chip selector: paragraph, bullet list, table, code, structured report).
- **Constraints** (text input: any additional requirements).

Assemble the form inputs into a coherent prompt and display the resulting prompt text in a preview area. Allow users to edit the assembled prompt directly before submission. Support saving builder configurations as reusable templates.

### 6. Parametrization

Provide **sliders, knobs, and visual controls** that adjust generation parameters without requiring prompt text.

| Parameter | Control Type | Range | Default |
|-----------|-------------|-------|---------|
| Creativity/Temperature | Slider | Conservative ↔ Creative | Center |
| Output length | Segmented control | Short / Medium / Long / Unlimited | Medium |
| Formality | Slider | Casual ↔ Formal | Center |
| Technical depth | Slider | Beginner ↔ Expert | Beginner |
| Detail level | Slider | Overview ↔ Comprehensive | Overview |

Group parameter controls in a collapsible "Advanced" panel beneath the prompt input. Show a real-time preview or prediction of how parameter changes will affect the output. Provide named presets ("Quick Summary," "Deep Analysis," "Creative Brainstorm") that configure multiple parameters at once.

---

## Natural Language Interface (LUI) Patterns

### Designing for Natural Language as Primary Input

When natural language is the primary input modality, design the entire interaction model around the inherent ambiguity, variability, and imprecision of human language.

Provide a **prominent, well-labeled input area** with a placeholder that communicates the expected input type and scope: "Describe what you need..." or "Ask anything about your project..." rather than a generic "Type here." Show the input area at a comfortable width (minimum 480px on desktop) to encourage multi-sentence requests rather than terse keywords.

Support **multi-modal input augmentation**: allow users to attach files, paste images, drag in references, or use voice-to-text alongside their natural language input. Show attached context items as removable chips above or below the input field.

### Disambiguation UX

When user intent is ambiguous, resolve it through **structured clarification** rather than open-ended follow-up questions.

Design disambiguation as a **choice card** that presents the two to four most likely interpretations as selectable options:

```
I interpreted your request in multiple ways:

○ Create a new report from scratch using last quarter's data
○ Update the existing Q3 report with the latest numbers
○ Generate a comparison between Q3 and Q4 reports

Which did you mean? Or describe further:  [____________]
```

Limit choices to four or fewer. If more than four interpretations are plausible, the request is too ambiguous for choice-based disambiguation — ask a specific clarifying question instead.

Rank disambiguation options by likelihood and pre-select the most probable interpretation. Allow the user to confirm the pre-selection with a single keystroke (Enter) for efficient flow when the system guesses correctly.

### Error Handling for Misunderstood Intent

When the system cannot parse or act on user input, provide **specific, actionable error messages** rather than generic failure states.

| Error Type | Response Pattern |
|-----------|-----------------|
| Unparseable input | "I couldn't understand that. Try rephrasing, or use one of these example formats: [examples]" |
| Partially understood | "I understood [parsed part] but not [unparsed part]. Can you clarify [unparsed part]?" |
| Out of scope | "I can't [requested action] because [reason]. I can [alternative action] instead." |
| Ambiguous entity | "Which [entity type] did you mean? [list of candidates with disambiguating details]" |
| Missing required info | "To [action], I also need [missing parameters]. [Pre-fill what's known in a form]" |

Never respond with "I don't understand" alone. Always include at least one concrete suggestion for how the user can rephrase or proceed.

### Slot-Filling Conversational Patterns

For tasks that require multiple parameters, use **slot-filling** to collect them through a natural conversational flow rather than a rigid form.

Maintain a visible **parameter status display** that shows which slots are filled and which remain:

```
✓ Destination:  Tokyo
✓ Dates:        March 15-22
✓ Budget:       Under $800
○ Class:        [not specified — defaulting to Economy]
○ Airline pref: [not specified — searching all]
```

Allow users to fill slots in any order. Accept partial input and infer what you can. When the user provides a sentence that fills multiple slots simultaneously ("fly me to Tokyo next week in business class"), parse and fill all applicable slots at once.

Pre-fill slots from context when possible: user profile data, recent history, organizational defaults. Show pre-filled values as editable defaults, clearly marked as system-suggested.

### Mixed-Initiative Dialog Design

Design for conversations where **both the user and the system drive the interaction**. In mixed-initiative dialog, the system does not merely respond to user commands — it proactively suggests, asks questions, offers alternatives, and redirects when appropriate.

Implement mixed-initiative behaviors:

- **Proactive suggestion:** The system notices an opportunity and offers it. "While I'm booking your flight, I can also find hotels near the conference venue. Want me to?"
- **Clarification request:** The system identifies ambiguity and asks. "You said 'next week' — do you mean Monday the 15th through Friday the 19th, or the full week through Sunday?"
- **Redirect:** The system recognizes a more efficient path. "Instead of searching each vendor individually, I can check an aggregator that covers all of them. Shall I?"
- **Constraint surfacing:** The system discovers a conflict and alerts. "There are no direct flights under $800 for those dates. Flights with one stop start at $620, or direct flights start at $950. How should I proceed?"

Balance system initiative carefully. Too much initiative feels pushy and breaks the user's flow. Too little makes the system feel passive and unhelpful. Calibrate initiative frequency based on task complexity: higher initiative for complex, multi-step tasks where the user may overlook considerations; lower initiative for simple, well-defined requests where the user knows exactly what they want.

### Progressive Refinement of Requests

Design for **iterative improvement** of natural language requests through feedback loops.

After generating an initial result, provide **refinement affordances** that make incremental adjustment easy:

- **Natural language refinement:** "Make it shorter" or "Focus more on the methodology section." Parse refinements relative to the current output.
- **Structured refinement:** Clickable aspects of the output that open targeted controls. Click a paragraph to get options: shorten, expand, rephrase, remove, move up/down.
- **Comparative refinement:** Generate two or three variants and let the user select the best one or cherry-pick elements from each. "Version A's intro with Version B's conclusion."

Track the refinement history so users can navigate back to any previous version. Display the refinement trajectory as a compact version timeline: "v1 → v2 (shortened) → v3 (added data) → v4 (formal tone)."

---

## Cross-Referencing

- For foundational AI interface patterns (chat, copilot, transparency), reference `ai-spatial-voice-ux/ai-native-interface-patterns`.
- For AI ethics, dark pattern avoidance, and content strategy, reference `ux-ethics-content-strategy`.
- For accessibility requirements in agent interfaces, reference `accessibility-inclusive-design`.
- For design system integration with generative and agent-driven UI, reference `design-systems-architecture`.
- For interaction and motion design in handoff animations and status indicators, reference `interaction-motion-design`.

## Key Sources

- Gartner Top Strategic Technology Trends 2025 (Agentic AI as #1 trend)
- Microsoft Copilot Design Guidelines and Responsible AI Framework
- OpenAI Apps SDK Design System and Developer Documentation
- GitHub Copilot UX Research and Interaction Patterns
- CopilotKit Open Source Frontend Copilot Framework
- NNG Group: Outcome-Oriented Design, Generative UI, State of UX 2026
- Google A2UI: Agent-to-UI Interoperability Format
- ACM CHI 2025: Prompt Augmentation Patterns for Human-AI Co-Creation
- World Economic Forum: Multi-Agent AI Systems Design
- Arxiv: Survey of Agentic AI Design Workflows and Multi-Agent Orchestration UX
