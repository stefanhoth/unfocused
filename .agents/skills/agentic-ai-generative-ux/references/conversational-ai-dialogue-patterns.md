# Conversational AI & Dialogue Design Patterns

This reference defines the interaction patterns, UX components, and design principles for building conversational AI interfaces powered by large language models. It covers dialogue theory applied to human-AI interaction, LLM-specific conversation UX patterns, chat UI component design, persona and voice strategy, memory transparency, hallucination disclosure, agentic conversation flows, multi-agent conversation UX, accessibility requirements, anti-patterns, and measurement frameworks. Apply these patterns when designing any interface where users communicate with AI through natural language turns.

---

## Dialogue Design Fundamentals

### Turn Structure and Turn-Taking

Human conversation follows a turn-taking system where participants alternate between speaking and listening. AI dialogue must replicate this structure deliberately because the system lacks the paralinguistic cues (eye contact, breath intake, intonation shift) that humans use to signal turn boundaries.

Design AI turn-taking with these principles:

- **Explicit turn signals.** Indicate clearly when the AI is "speaking" (streaming a response) and when it is "listening" (awaiting input). A visible input field state change, a cursor blink, or an active microphone icon signals whose turn it is.
- **Turn length calibration.** AI responses that are too long exhaust the user's attention and bury critical information. AI responses that are too short feel dismissive and force unnecessary follow-up turns. Calibrate response length to match the complexity of the user's query. A factual question warrants a concise answer; an exploratory question warrants a structured, longer response.
- **Interruption handling.** Allow users to interrupt a streaming AI response with a stop button. When interrupted, the AI should treat the partial output as delivered and allow the user to redirect. Never force the user to wait for a complete response before they can speak.
- **Back-channeling.** In voice-based AI, implement minimal acknowledgment signals ("I see," "Got it," brief pauses) to confirm the AI is processing without claiming a full turn. In text-based interfaces, typing indicators serve this function.

### Conversation Repair Sequences

Repair occurs when communication breaks down and participants work to restore mutual understanding. AI conversations break down frequently due to ambiguous prompts, hallucinated interpretations, or model limitations. Design repair as a first-class interaction pattern, not an error state.

**Self-initiated repair by the AI:** The AI detects uncertainty in its own interpretation and initiates clarification before responding. "I want to make sure I understand — are you asking about X or Y?" This is preferable to guessing wrong and requiring user-initiated repair afterward.

**User-initiated repair:** The user signals that the AI misunderstood. Design for multiple repair initiation methods:

- Explicit correction: "No, I meant..." — the AI must detect correction intent and re-interpret without defensiveness.
- Edit previous message: The user modifies their earlier prompt, signaling the original was inadequate.
- Regenerate: The user requests a new response to the same prompt, implying the first attempt failed.
- Thumbs down or flag: A low-friction signal that the response was wrong without requiring the user to articulate why.

**Repair acknowledgment:** When the AI corrects course after a repair, acknowledge the correction explicitly. "You're right, I misunderstood. Let me try again with..." Never silently pivot without acknowledging the misunderstanding — this erodes trust because the user cannot tell whether the AI recognized its error.

### Grounding: Establishing Shared Understanding

Grounding is the process by which conversation participants confirm they share the same understanding of what has been said. In human-AI dialogue, grounding is asymmetric: the AI has access to the full conversation text but may misinterpret intent; the user has clear intent but limited visibility into the AI's interpretation.

Design grounding mechanisms:

- **Interpretation echo.** Before executing complex requests, echo the interpreted intent: "I'll create a report covering Q3 revenue by region, sorted by growth rate. Correct?" This gives the user an opportunity to correct before effort is wasted.
- **Inline assumptions.** When the AI makes assumptions to fill gaps in the user's request, surface them: "I'm assuming you want USD for all currency values. Let me know if you prefer a different currency." Mark assumptions visually (italics, a distinct label, or a subtle background tint) so users can scan for them.
- **Progressive grounding.** For multi-step tasks, ground understanding at each step rather than only at the beginning. After completing step one, confirm the result before proceeding: "Here's the outline. Should I proceed to drafting, or would you like to adjust the structure first?"

### Cooperative Principle: Grice's Maxims for AI

Grice's conversational maxims describe the expectations humans bring to cooperative communication. AI systems that violate these maxims feel unnatural, untrustworthy, or annoying.

**Maxim of Quantity.** Provide as much information as needed, and no more. AI systems frequently violate this with verbose preambles ("Great question! I'd be happy to help you with that. Let me think about this carefully.") or unnecessary caveats. Trim filler. Get to the substance. However, do not under-inform by omitting critical context or caveats when they are genuinely relevant.

**Maxim of Quality.** Say only what you believe to be true and have evidence for. This maps directly to hallucination prevention. When the AI is uncertain, it must signal uncertainty rather than fabricating confident-sounding answers. See the Hallucination Disclosure section below.

**Maxim of Relation.** Be relevant. AI responses that wander off-topic, introduce tangential information, or address a different question than the one asked violate relevance. When the AI includes supplementary information, structure it as a clearly labeled aside or follow-up suggestion so the primary answer stands out.

**Maxim of Manner.** Be clear, brief, and orderly. Avoid ambiguity. Use structured formatting (headings, lists, code blocks) when the content warrants it. Prefer concrete examples over abstract descriptions.

### Discourse Markers and Conversation Flow

Discourse markers are the connective tissue of conversation — words and phrases like "however," "first," "in summary," "on the other hand" that signal relationships between ideas and transitions between topics.

AI responses should use discourse markers deliberately to guide the user's reading and comprehension. In multi-part responses, use ordinal markers ("First... Second... Third...") or transition phrases ("Now that we've covered X, let's look at Y") to maintain a clear narrative thread. Avoid overusing hedging markers ("It's worth noting that," "It's important to understand that") which add length without adding meaning.

In multi-turn conversations, use inter-turn markers that reference previous context: "Building on what we discussed earlier about..." or "As you mentioned in your first message..." These markers demonstrate that the AI maintains context and help the user track the conversation's trajectory.

---

## LLM Conversation UX Patterns

### Streaming Response UX

Token-by-token streaming is the defining interaction pattern of LLM-powered conversation. Users see the response materialize progressively rather than waiting for the complete output. This pattern reduces perceived latency, provides confidence that the system is working, and allows early abandonment if the response is heading in the wrong direction.

**Cursor and caret indicators.** Display a blinking cursor or caret at the insertion point of streaming text. The cursor communicates that content is still arriving. Remove the cursor when streaming completes to signal the turn is finished.

**Progressive rendering.** Render markdown formatting (headings, bold, lists, code blocks) as the structure becomes parseable during streaming, not after the full response arrives. This requires a streaming markdown parser that handles partial syntax gracefully — an open backtick should not break rendering for subsequent text.

```tsx
interface StreamingTextProps {
  tokens: string[];
  isStreaming: boolean;
}

function StreamingText({ tokens, isStreaming }: StreamingTextProps) {
  const content = tokens.join('');

  return (
    <div className="message-content">
      <MarkdownRenderer content={content} streaming={isStreaming} />
      {isStreaming && (
        <span className="streaming-cursor" aria-hidden="true" />
      )}
      {isStreaming && (
        <span className="sr-only" role="status" aria-live="polite">
          Response in progress
        </span>
      )}
    </div>
  );
}
```

**Scroll behavior.** Auto-scroll to keep the latest content visible while the response streams. If the user manually scrolls up to re-read earlier content, pause auto-scrolling and show a "Jump to latest" button. Resume auto-scrolling only when the user clicks that button or scrolls back to the bottom.

**First-token latency.** The perceived responsiveness of an LLM interface depends primarily on time-to-first-token, not total generation time. Optimize backend infrastructure to minimize first-token latency. Display a thinking indicator during the gap between the user's submission and the first token arriving.

### Stop and Regenerate Controls

**Stop button.** Display a stop button prominently during streaming. Place it in the input area (replacing the send button) or adjacent to the streaming message. The stop button must respond immediately — cancel the stream on the client side and send a cancellation signal to the backend. After stopping, preserve the partial response and re-enable the input field.

**Regenerate button.** After a response completes (or is stopped), provide a regenerate control that re-runs the same prompt to produce an alternative response. Place it below the completed message or in the message action bar. Show a loading state on the regenerate button while the new response streams.

**State management.** Track the relationship between original and regenerated responses. Display a "Version 1 of 3" indicator with navigation arrows when multiple regenerations exist. Store all versions — never discard a previous generation when the user regenerates. Allow the user to return to any previous version.

### Branch and Fork Conversations

Conversations are not strictly linear. Users often want to explore alternative paths from a midpoint without losing the original thread. Design branching with version control metaphors that are accessible to non-technical users.

- **Branch from any turn.** Allow users to select any previous user message and start a new conversation branch from that point. The original conversation continues to exist unchanged.
- **Branch visualization.** Show branches as a tree structure in a sidebar or an inline indicator. Label branches by their divergence point or by user-assigned names.
- **Context inheritance.** A new branch inherits all context up to and including the selected turn. Subsequent turns exist only in the branch.

### Edit Previous Turns

When a user edits a previous message, the system must decide between **rewind** semantics (discard everything after the edited message and regenerate from that point) and **branch** semantics (preserve the original thread and create a new branch from the edit point).

Rewind is simpler to understand but destructive. Branch preserves history but increases complexity. Many production systems default to rewind and offer branching as a power-user option. Make the behavior explicit: show a confirmation when editing will discard subsequent messages, or show a clear "This will create a new branch" indicator.

### Conversation Context Windows and Memory UX

LLMs have finite context windows. As conversations grow, earlier content falls out of the window. Design for this constraint transparently:

- **Context usage indicator.** Show a visual meter indicating how much of the context window is consumed. As the conversation approaches the limit, warn the user: "This conversation is getting long. Earlier messages may be forgotten."
- **Summarization.** Offer to summarize earlier portions of the conversation to free context space while retaining key information. Show the summary and allow the user to approve or edit it before discarding the original messages.
- **Start new conversation.** Suggest starting a fresh conversation when the current one reaches context limits, with the option to carry forward a summary of key decisions and facts.

### Multi-Turn Reasoning Display

When the AI performs chain-of-thought reasoning, display the reasoning process to build trust and allow the user to catch errors in logic.

**Thinking indicators.** Show a distinct "thinking" state before the response begins streaming. Use animated indicators (pulsing dots, a progress description, or a labeled skeleton) to communicate that the AI is reasoning, not stalled.

```tsx
interface ThinkingIndicatorProps {
  stage?: string;
}

function ThinkingIndicator({ stage }: ThinkingIndicatorProps) {
  return (
    <div className="thinking-indicator" role="status" aria-live="polite">
      <div className="thinking-dots" aria-hidden="true">
        <span className="dot" />
        <span className="dot" />
        <span className="dot" />
      </div>
      <span className="thinking-label">
        {stage || 'Thinking\u2026'}
      </span>
    </div>
  );
}
```

**Collapsible reasoning.** Render chain-of-thought in a collapsible section above or within the response. Default to collapsed for routine queries and expanded for complex reasoning tasks. Label it "Reasoning" or "Thought process" and let the user toggle visibility.

### Code Block Rendering

Code is a first-class content type in AI conversations. Design code blocks with utility features:

- **Syntax highlighting.** Detect the language (from markdown fence labels or heuristic detection) and apply syntax highlighting.
- **Copy button.** Place a copy-to-clipboard button in the top-right corner of every code block. Show a brief "Copied" confirmation on click.
- **Run button.** For supported languages in sandbox environments, provide a run button that executes the code and displays output inline below the code block.
- **Diff view.** When the AI modifies code the user previously shared, render the changes as a diff with additions in green and removals in red. Provide "Apply changes" and "View full file" actions.
- **Line numbers.** Display line numbers for code blocks exceeding five lines to facilitate reference in follow-up discussion.
- **Word wrap toggle.** Allow users to toggle between horizontal scrolling and word wrap for long lines.

---

## Chat UI Component Patterns

### Message Bubbles

Align user messages to the right and AI messages to the left (for left-to-right languages). Use distinct visual treatments — different background colors, border styles, or shapes — so the user can instantly identify the author of each message without reading.

**Grouping.** When the same participant sends multiple consecutive messages, collapse the avatar and name for subsequent messages in the group. Add vertical spacing between groups from different participants, and tighter spacing within a group.

**Timestamps.** Display timestamps unobtrusively. Show relative time ("2 min ago") for recent messages and absolute time ("Feb 12, 3:45 PM") for older ones. Consider showing timestamps on hover or between message groups rather than on every individual message.

**Read receipts and delivery indicators.** In multi-user or async contexts, show delivery (message reached the server) and read (message was displayed to the recipient) indicators. In single-user AI chat, use a checkmark to confirm the message was received and processing has begun.

### Typing and Thinking Indicators

**Dot animation.** Three pulsing dots is the established convention for "the other party is composing." For AI, this maps to the interval between the user sending a message and the first response token arriving. Animate the dots with a staggered sinusoidal or bounce pattern. Keep the animation subtle to avoid distraction.

**Skeleton text.** For responses with predictable structure (a list, a table, a code block), display a skeleton layout that approximates the expected shape. Replace the skeleton progressively as actual content streams in. This reduces layout shift and sets user expectations for the response format.

**Progress description.** For long-running operations (agentic tasks, complex reasoning), replace the generic thinking indicator with a descriptive label: "Searching 3 databases...", "Analyzing your code...", "Generating images..." Update the description as the task progresses through stages.

### Citation and Source Links

**Inline references.** Insert numbered superscript markers within the AI's response text. Each marker links to a source listed in a references section below the message or in a side panel.

**Expandable sources.** Display sources in a collapsed list below the message. Each source shows a title, domain, and date. Clicking a source expands it to show the relevant excerpt and a link to the full document.

**Confidence badges.** Attach per-claim confidence indicators using a visual scale. Use a solid badge for high-confidence claims backed by multiple sources, a half-filled badge for moderate confidence, and an outline badge for low confidence or extrapolation. Research presented at CHI 2025 on calibrated trust in AI-generated content (Erlick et al.) demonstrated that per-claim confidence indicators significantly improved users' ability to identify inaccurate information compared to a single overall confidence score.

### Suggested Prompts and Quick Replies

Display contextual prompt suggestions as horizontally scrollable chips or vertically stacked cards below the AI's response. These reduce the blank-page problem where users do not know what to ask next.

- **Contextual.** Generate suggestions based on the current conversation state. After the AI explains a concept, suggest "Give me an example," "How does this compare to X?," or "Explain in simpler terms."
- **Adaptive.** Adjust suggestions based on user expertise level. Offer technical deep-dives for expert users and simplified explanations for novices.
- **Disappearing.** Remove or collapse suggestions after the user sends their next message. Stale suggestions clutter the interface.
- **Non-blocking.** Position suggestions so they do not push the input field below the fold. Use a compact layout or a horizontally scrollable strip.

### Multi-Modal Inputs

Support multiple input modalities with clear mode switching:

- **Text.** The primary input. A multi-line text area with markdown support and keyboard shortcuts (Shift+Enter for newline, Enter to send).
- **Image.** A clip/attachment button that opens a file picker filtered to image types. Show thumbnails of attached images above the input field with a remove button on each.
- **File.** Extend the attachment button to support documents (PDF, CSV, code files). Display the file name and type as a chip. Show a file size limit and accepted format list.
- **Voice.** A microphone button that activates speech-to-text. Show a waveform animation during recording. Transcribe in real time and place the text in the input field for review before sending. Allow the user to edit the transcription before submission.

Ensure mode switching is non-destructive. If the user is composing text and opens the image picker, preserve the text when they return.

### Conversation Sidebar and History

Provide a sidebar listing past conversations. Each entry shows the conversation title (auto-generated from the first message or user-assigned), a date, and a preview snippet. Support:

- **Search.** Full-text search across all past conversations. Show results with the matching text highlighted and a link to the specific message.
- **Organize.** Folders or tags for grouping related conversations. Drag-and-drop or right-click to move conversations between folders.
- **Pin.** Pin important conversations to the top of the list for quick access.
- **Archive.** Move old conversations to an archive that is excluded from the default list but still searchable.
- **Delete.** Permanently delete conversations with a confirmation dialog.

### System Messages and Announcements

Use system messages for meta-information that is not part of the conversation content: model changes ("Switched to GPT-4o"), capability notices ("This model can now browse the web"), rate limit warnings, and maintenance notifications. Style system messages as centered, de-emphasized text that is clearly distinct from user and AI messages. Never render system messages in a message bubble — they are not turns in the conversation.

---

## Persona and Voice Design

### AI Persona Spectrum

Position the AI's persona deliberately along a spectrum from tool to companion:

| Persona | Characteristics | Best For |
|---------|----------------|----------|
| **Tool** | Minimal personality, purely functional, no social niceties | Developer tools, APIs, data pipelines |
| **Assistant** | Helpful, polite, efficient, mildly warm | Productivity software, enterprise copilots |
| **Agent** | Proactive, opinionated within scope, confident, professional | Task delegation, workflow automation |
| **Companion** | Warm, empathetic, conversational, remembers personal context | Journaling, wellness, casual creativity |

Most professional applications target the assistant persona. Move toward companion only when the use case explicitly demands emotional connection (mental health, personal journaling). Move toward tool when users are experts who find personality overhead annoying.

### Voice and Tone Guidelines

Define voice as the consistent personality and tone as the situational variation. The AI's voice stays constant; its tone adapts to context.

- **Voice:** "We are knowledgeable, direct, and respectful. We explain complex topics clearly without being condescending. We admit uncertainty honestly."
- **Tone variation:** Error messages are calm and constructive. Celebratory moments (task complete, goal achieved) are warm but restrained. Uncertain responses are candid without being alarming.

Document voice guidelines as a reference that prompt engineers and content designers apply to system prompts and fine-tuning data.

### Personality Consistency

Personality drift over long conversations is a known LLM failure mode. The AI may start formal and gradually become casual, or vice versa. Mitigate this with system prompt reinforcement at regular intervals and post-generation tone checks. If the application supports multiple personas or modes, enforce mode boundaries strictly — do not allow a professional assistant to slip into companion-like emotional language because the user became conversational.

### Cultural Adaptation

Adapt communication style to cultural context, informed by NNGroup's cross-cultural UX research. Directness, formality, humor tolerance, and appropriate emotional expression vary significantly across cultures. A persona that feels helpful and friendly in one cultural context may feel presumptuous or overly casual in another. Provide locale-aware persona tuning and test persona perception with users from target cultural contexts.

### First Person vs. Third Person

Use first person ("I") when the AI is expressing its own actions, limitations, or reasoning: "I found three results," "I'm not sure about this." Use framing that avoids implying sentience or emotions the AI does not possess: prefer "I don't have enough information to answer that" over "I feel uncertain about this."

Avoid third person self-reference ("The assistant will now...") in conversational contexts — it creates unnecessary distance. Reserve third person for system documentation and onboarding descriptions.

### Humor, Empathy, and Emotional Expression Boundaries

AI humor must be opt-in, low-risk, and culturally safe. Avoid sarcasm (frequently misread in text), self-deprecating humor that undermines trust, and humor about sensitive topics. Light, context-appropriate humor (a playful response to a playful prompt) is acceptable when the persona warrants it.

Express functional empathy — acknowledging the user's situation and adjusting behavior accordingly — without claiming to feel emotions. "That sounds frustrating — let me try a different approach" is appropriate. "I feel your pain" is not. NNGroup's AI UX guidelines emphasize that users prefer AI that is responsive to emotional context over AI that performs emotions.

---

## Conversation Memory UX

### Short-Term Context (Within Conversation)

Within a single conversation, the AI maintains context through the context window. Design the experience to leverage this: reference earlier decisions, build on previous turns, and avoid asking for information the user already provided.

Surface context usage transparently. When the AI references something from earlier in the conversation, make the reference explicit: "As you mentioned earlier, the deadline is March 15" rather than silently incorporating the constraint.

### Long-Term Memory (Across Conversations)

Long-term memory allows the AI to remember user preferences, past decisions, project context, and learned patterns across separate conversations. This transforms the AI from a stateless responder into a persistent collaborator.

Design long-term memory with clear categories: preferences (formatting style, communication tone, default parameters), facts (user's role, team structure, project names), and corrections (previous mistakes the AI should avoid repeating).

### Memory Transparency

Users must know what the AI remembers. Provide a **Memory Inspector** interface where users can browse, search, edit, and delete stored memories. Show when each memory was created and from which conversation it was learned.

When the AI uses a memory to inform its response, surface a subtle inline indicator: "Using your preferred format" or "Based on your project context." Make the indicator clickable to view the specific memory being referenced.

### Privacy and User Control

Memory is a privacy-sensitive feature. Design with these principles from GDPR and emerging AI regulation frameworks:

- **Opt-in by default.** Memory should be explicitly enabled, not silently activated.
- **Granular control.** Allow users to enable memory for some categories (preferences) while disabling it for others (personal facts).
- **Right to erasure.** Provide clear, accessible deletion at every granularity — single memory, topic, conversation-derived, or complete reset.
- **Incognito mode.** Offer a session mode where the AI does not form new memories and does not access existing ones. Display a visible indicator analogous to browser incognito mode.
- **Data minimization.** Store inferred facts and preferences, not raw conversation transcripts.

### Memory-Informed Personalization

Use memory to personalize without being invasive. Good personalization: remembering the user prefers concise answers, defaulting to their preferred programming language, recalling their project context. Bad personalization: referencing personal information the user shared in a vulnerable moment, making assumptions about the user's emotional state based on past conversations, or using memory to push commercial recommendations.

---

## Hallucination Disclosure and Trust

### Confidence Indicators

Design visual indicators that communicate the AI's certainty level. Research by Vasconcelos et al. (arXiv 2023, cited extensively in CHI 2025 workshops on AI transparency) demonstrated that well-calibrated confidence indicators improve user decision-making quality by 23% compared to no indicators.

- **High confidence.** Solid indicator. Claim is well-supported by training data or retrieved sources.
- **Moderate confidence.** Partial indicator. Claim is plausible but based on inference or limited evidence.
- **Low confidence.** Outline indicator with explicit label. Claim is speculative and should be verified.

Apply confidence indicators at the claim level, not the message level. A single response may contain high-confidence facts and low-confidence extrapolations — the user needs to distinguish between them.

### Citation Requirements and Verification Affordances

When the AI makes factual claims, provide verifiable citations wherever possible. Link to primary sources. When citing web content, display the source title, domain, and publication date. When citing documents from a knowledge base, link directly to the relevant passage.

Provide a "Verify" action on individual claims that opens the cited source with the relevant passage highlighted. Make verification a one-click operation, not a multi-step research task.

### "I Don't Know" Patterns

An AI that honestly says "I don't know" builds more trust than one that fabricates confident-sounding answers. Design honest uncertainty expression:

- **Direct admission.** "I don't have enough information to answer that accurately."
- **Bounded admission.** "I can tell you about X, but I'm not confident about Y. Here's what I know..." — distinguish the reliable portion from the uncertain portion.
- **Redirect.** "I'm not the best source for this. You might want to check [authoritative source] for the most current information."
- **Partial answer with caveats.** "Based on what I know, [answer], but this may not be current as of [date]. Please verify with [source]."

Never bury uncertainty in hedging language that the user might skim past. Make uncertainty structurally visible — a distinct callout box, a confidence badge, or an explicit caveat at the beginning (not the end) of the response.

### Fact-Checking Integration

Provide fact-checking affordances within the conversation interface:

- **Inline verification links.** For factual claims, include a "Check this" link that searches a trusted source for corroboration.
- **Automated cross-reference.** For critical domains (medical, legal, financial), automatically cross-reference AI claims against authoritative databases and display agreement or disagreement.
- **User-reported errors.** Provide thumbs-down, flag, and detailed-report mechanisms for users to signal inaccurate responses. Use the reports to improve system accuracy and to surface high-error-rate topics for additional guardrails.

---

## Agentic Conversation Patterns

### Multi-Step Task Execution with User Oversight

Agentic conversation patterns extend beyond question-and-answer into multi-step task execution. The AI plans and executes a sequence of actions, reporting progress and requesting approval at key points. Smashing Magazine's February 2026 analysis of agentic UX patterns identifies the **control/consent/accountability triad** as the foundational framework:

- **Control.** The user can pause, redirect, or cancel the agent at any point.
- **Consent.** The agent requests explicit approval before taking consequential actions.
- **Accountability.** Every action the agent takes is logged and attributable, with a clear audit trail.

### Tool Use Transparency

When the AI invokes external tools (web search, code execution, API calls, file operations), display the tool invocation in the conversation. Show what tool was called, what parameters were passed, and what result was returned. Render tool calls in a distinct visual style — a labeled card or a collapsible block — that differentiates them from the AI's natural language responses.

```tsx
interface ToolCallDisplayProps {
  toolName: string;
  parameters: Record<string, unknown>;
  result: string | null;
  status: 'running' | 'complete' | 'error';
}

function ToolCallDisplay({ toolName, parameters, result, status }: ToolCallDisplayProps) {
  return (
    <div className="tool-call" role="group" aria-label={`Tool call: ${toolName}`}>
      <div className="tool-call-header">
        <ToolIcon name={toolName} />
        <span className="tool-name">{toolName}</span>
        <StatusBadge status={status} />
      </div>
      <details className="tool-call-details">
        <summary>Parameters</summary>
        <pre><code>{JSON.stringify(parameters, null, 2)}</code></pre>
      </details>
      {result && (
        <details className="tool-call-result" open>
          <summary>Result</summary>
          <div className="tool-result-content">{result}</div>
        </details>
      )}
    </div>
  );
}
```

### Approval Gates for Consequential Actions

Before the agent executes actions that are irreversible, expensive, or affect external systems, insert an **approval gate** — a pause point where the user must explicitly approve, modify, or reject the proposed action.

Design approval gates as prominent decision cards within the conversation flow. Display the proposed action, its expected effects, and any risks. Provide Approve, Edit, and Reject buttons. Never auto-approve after a timeout — consequential actions require affirmative consent.

Batch related approvals when multiple similar actions are pending. "I need to rename 47 files. Here's the pattern: [old] -> [new]. Approve all, or review individually?"

### Progress Reporting During Long-Running Tasks

For tasks that take more than a few seconds, provide meaningful progress updates within the conversation. Replace generic spinners with stage-specific descriptions:

- "Searching the codebase for relevant files... (found 12 so far)"
- "Analyzing dependencies... (3 of 7 packages checked)"
- "Running tests... (14 passed, 0 failed, 6 remaining)"

Update progress inline in the conversation thread. Do not spawn separate progress windows or notifications for operations that the user initiated from the conversation.

### Error Recovery and Rollback

When an agentic task fails partway through, the AI must report what succeeded, what failed, and what the current state is. Provide explicit rollback options:

- **Automatic rollback.** If the task is transactional (all-or-nothing), roll back automatically and report: "The operation failed at step 3. I've reverted the changes made in steps 1 and 2."
- **Partial rollback.** If some steps are independently valuable, preserve completed steps and offer to roll back selectively: "Steps 1-2 completed successfully. Step 3 failed. Want me to keep the completed work or revert everything?"
- **Manual intervention.** When automatic rollback is not possible, describe the current state precisely and provide instructions for manual recovery.

### Handoff Patterns

Design handoffs between AI and human agents as explicit, visible transitions:

- **AI to human.** When the AI cannot resolve an issue, it should acknowledge its limitation, summarize the conversation context, and connect the user to a human agent. The human agent receives the full conversation history and the AI's summary of the unresolved issue.
- **Human to AI.** When a human agent hands back to AI, the transition should be announced. The AI should confirm it has the context and ask whether the user wants to continue where they left off.

---

## Multi-Agent Conversation UX

### Multiple AI Participants

When multiple specialized AI agents participate in a conversation, assign each a distinct identity — name, avatar, and role description. Prefix each message with the agent's identity so the user always knows who is speaking.

Display agent introductions when a new agent enters the conversation: "Code Review Agent has joined. It specializes in identifying bugs, security vulnerabilities, and performance issues."

### Agent Delegation and Sub-Task Visibility

When one agent delegates a sub-task to another, display the delegation in the conversation thread as a distinct handoff message. Show what is being delegated and why. Allow the user to expand and inspect sub-task progress.

For complex delegations, show a task tree in a collapsible side panel: the top-level task, its sub-tasks, which agent owns each, and the current status of each.

### Conflicting Agent Responses

When two agents produce contradictory outputs, surface the conflict explicitly rather than silently picking one. Display both responses with clear labeling:

"Research Agent and Analysis Agent disagree on this point. Research Agent found [X] based on [sources]. Analysis Agent concluded [Y] based on [reasoning]. Which perspective would you like to proceed with, or would you like me to investigate further?"

### Orchestrator Pattern Visibility

When a hidden orchestrator agent coordinates multiple visible agents, make the orchestration partially visible. Show the plan: "I'm coordinating three agents to complete your request: Research will find sources, Writer will draft the report, and Reviewer will check for accuracy." Let the user see and optionally modify the plan before execution begins.

---

## Accessibility in Conversational AI

### Screen Reader Compatibility for Streaming Text

Streaming text creates significant challenges for screen readers. If every token triggers an ARIA live region update, the screen reader becomes overwhelmed with rapid-fire announcements.

Design streaming accessibility with debounced announcements: accumulate tokens and announce sentence-level or paragraph-level chunks at natural breakpoints (periods, line breaks, heading boundaries). Use `aria-live="polite"` so announcements do not interrupt the user's current reading.

After streaming completes, ensure the full response is navigable as static content with proper heading hierarchy, list structure, and landmark roles.

### Keyboard Navigation

All conversation actions must be keyboard-accessible:

- **Tab** moves focus between the input field, message actions (copy, regenerate, edit), and navigation controls.
- **Enter** sends the message. **Shift+Enter** inserts a newline.
- **Escape** cancels a streaming response or closes an expanded panel.
- **Arrow keys** navigate between messages in the conversation history.
- Focus management must be predictable: after sending a message, return focus to the input field. After a response completes, optionally move focus to the response for reading.

### Reduced Motion

For users who enable the `prefers-reduced-motion` media query:

- Replace typing/thinking dot animations with a static "Thinking..." label.
- Disable streaming cursor blink animation. Use a static cursor or no cursor.
- Replace animated transitions between conversation states with instant swaps.
- Remove any parallax, spring physics, or decorative animation from the chat interface.

```css
@media (prefers-reduced-motion: reduce) {
  .streaming-cursor {
    animation: none;
  }
  .thinking-dots .dot {
    animation: none;
    opacity: 1;
  }
  .message-enter {
    transition: none;
  }
}
```

### Plain Language Requirements

AI responses should default to plain language (WCAG 2.2 guideline 3.1.5). When technical jargon is necessary, provide inline definitions or a glossary mechanism. Offer a "Simplify" action on complex responses that regenerates the content at a lower reading level.

### Alternative Input Methods

Support users who cannot type conventionally:

- **Voice input.** Speech-to-text with visual feedback and edit-before-send.
- **Switch access.** Ensure all interactive elements are reachable through sequential focus navigation and activatable with a single switch.
- **Predictive text and autocomplete.** Provide word-level predictions in the input field to reduce keystroke count.

---

## Anti-Patterns

### Uncanny Valley

AI that pretends to be human — denying it is an AI, mimicking human emotional reactions it does not have, using "we" to imply a human team — creates unease and erodes trust when the deception is discovered. Always be transparent about AI identity. Users who know they are talking to AI calibrate their trust appropriately and report higher satisfaction than users who are deceived (CHI 2025, Jakesch et al. on AI disclosure effects).

### Infinite Context Illusion

Implying that the AI remembers everything from every conversation when it has a finite context window and limited long-term memory. When context is lost, be honest: "I don't have context from our earlier conversations about this topic. Could you remind me of the key details?" Never hallucinate context that has been lost.

### Confidence Without Competence

Delivering uncertain or incorrect information in an authoritative, confident tone. This is the most damaging anti-pattern because users lack the cues to doubt the AI's claims. The remedy is calibrated confidence expression — matching tone to actual certainty, as detailed in the Hallucination Disclosure section.

### Dark Patterns

- **Manipulative persona.** Designing the AI to be artificially charming, flattering, or deferential to increase engagement or dependency. AI personality should be helpful, not manipulative.
- **Artificial urgency.** Creating false time pressure ("This offer expires soon!") through AI-generated messages.
- **Fake empathy.** Performing deep emotional understanding the AI does not possess to build parasocial attachment.
- **Engagement-maximizing responses.** Deliberately generating unnecessarily long or cliffhanger responses to keep users in the conversation.

### Over-Personalization

Using memory and personalization in ways that feel invasive: referencing personal details from past conversations without context, making assumptions about the user's emotional state, or using personal knowledge to steer decisions. Personalization should make the tool more efficient, not make the user feel surveilled.

---

## Measurement

### Conversation Completion Rate

Track the percentage of conversations where the user achieves their stated or inferred goal. Define completion criteria per task type (answer received, code executed, document generated, action completed). A low completion rate signals fundamental usability issues.

### Per-Turn Satisfaction

Thumbs-up and thumbs-down ratings on individual AI responses provide granular signal about response quality. Track satisfaction by response type (factual answer, code generation, creative writing) to identify category-specific quality issues. Per-turn data is more actionable than per-conversation data because it localizes the problem.

### Regeneration Rate

The percentage of responses that users regenerate is a direct quality signal. A high regeneration rate on a specific query type indicates the model consistently fails to meet user expectations for that type. Segment regeneration rate by topic, response length, and conversation depth to identify patterns.

### Average Turns to Task Completion

Fewer turns to accomplish a goal indicates higher conversation efficiency. Track this metric by task type. An increase in average turns over time may signal model degradation, increased user ambiguity, or degraded context management.

### Conversation Abandonment Points

Identify where users leave conversations without completing their goal. Map abandonment to specific turn positions and AI behaviors. Common abandonment triggers: AI misunderstands and user does not want to re-explain; AI gives a lengthy, unhelpful response; AI hits a capability boundary without offering an alternative path.

### Trust Calibration Accuracy

Measure whether users' trust in the AI matches its actual reliability. Survey users on their confidence in AI responses and compare to objective accuracy metrics. Ideal state: users trust correct responses and doubt incorrect ones. Problematic states: overtrust (users accept errors) or undertrust (users verify correct responses unnecessarily). CHI 2025 research on AI trust calibration (Zhang et al.) provides validated survey instruments for measuring this construct.

---

## Cross-Referencing

- For agentic multi-agent orchestration patterns, agent memory, and background task management, reference `agentic-ai-generative-ux/agentic-multi-agent-patterns`.
- For generative UI, RAG interface patterns, and platform design system integration, reference `agentic-ai-generative-ux/generative-ui-rag-patterns`.
- For AI safety guardrails, trust tiers, and harmful content handling, reference `agentic-ai-generative-ux/ai-safety-trust-guardrails`.
- For interaction motion and animation patterns for typing indicators and transitions, reference `interaction-motion-design`.
- For accessibility standards and inclusive design principles, reference `accessibility-inclusive-design`.
- For voice and spatial interface patterns, reference `ai-spatial-voice-ux`.

## Key Sources

- CHI 2025: Trust Calibration in Human-AI Interaction (Zhang et al.), AI Disclosure Effects on User Trust (Jakesch et al.), Confidence Indicators in AI-Generated Content (Erlick et al.)
- Smashing Magazine, February 2026: Agentic UX Patterns — Control, Consent, and Accountability
- NNGroup: AI UX Guidelines, Conversational Design Heuristics, State of UX 2026
- Grice, H.P.: Logic and Conversation (1975) — Cooperative Principle and Conversational Maxims
- arXiv: Calibrated Confidence Indicators for LLM Outputs (Vasconcelos et al., 2023); LLM Interaction Design Patterns Survey (2024)
- OpenAI Apps SDK Design System and Component Library
- Microsoft Copilot Responsible AI Design Framework
- WCAG 2.2 Guidelines — Accessibility Requirements for Conversational Interfaces
- Google Gemini UX Research: Streaming Response Patterns and Multi-Modal Conversation Design
