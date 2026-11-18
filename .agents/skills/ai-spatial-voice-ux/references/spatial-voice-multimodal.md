# Spatial Computing, Voice, and Multimodal Interaction Design

## Authoritative Reference for Spatial, Voice, and Emerging Interface Design

This reference codifies the design patterns, interaction models, and UX principles governing spatial computing environments, voice user interfaces, multimodal interaction design, and emerging interaction paradigms. These patterns address the expanding spectrum of human-computer interaction beyond screens, keyboards, and touch, encompassing the full range of human sensory and motor capabilities.

---

## Apple Vision Pro Design Patterns

### Eye Tracking and Hand Pinch Interaction Model

Design for an interaction model where the eyes select and the hands confirm. This "look and pinch" paradigm requires fundamentally different design thinking from touch or mouse-based interfaces.

Make **interactive targets large enough for comfortable eye targeting**: minimum 60pt diameter for primary actions, with generous spacing between adjacent interactive elements. The eye tracking system operates with approximately 1-degree angular accuracy, which translates to different physical sizes depending on element distance from the user. Account for this variable resolution in spatial layouts.

Implement **hover states driven by eye focus**: when the user's gaze rests on an interactive element for approximately 100-200ms, display a subtle highlight that confirms the element is targeted. Use a gentle scale increase (1.05-1.1x), a soft glow, or a material luminance change rather than abrupt color switches. The hover state must feel responsive without triggering on incidental gaze-through as the user scans the interface.

Design for the **pinch gesture vocabulary**: single pinch to tap/select, pinch-and-drag for scrolling and repositioning, double pinch for secondary actions, and pinch-and-hold for contextual menus. Provide visual feedback for each gesture state: finger tracking indicators during the approach, confirmation animation on pinch, and continuous feedback during drag operations.

Handle **eye tracking edge cases**: users wearing certain corrective lenses may have reduced tracking accuracy; users with strabismus or other eye conditions may not be trackable at all. Provide fallback input methods (head pointer, voice commands, Bluetooth trackpad/keyboard) and design the core experience to function with any input method, not exclusively eye tracking.

### Window Management in Spatial Space

Design window management for a three-dimensional environment where screen boundaries are replaced by the user's physical space.

Position **new windows** at a comfortable default distance (1.5-2 meters from the user's head position) and at natural eye height (slightly below eye level, approximately 15 degrees down from horizontal). Place new windows in the user's current gaze direction rather than at a fixed spatial coordinate so they appear in the user's field of view regardless of which direction they are facing.

Implement **window chrome** that includes a grab bar at the bottom edge for repositioning, a close button in the top-left corner following visionOS convention, and an optional resize handle. Keep window chrome minimal and semi-transparent to maximize content area. Display chrome at full opacity only when the user gazes at the window edges, fading to near-invisible when attention is on content.

Support **window grouping and snapping**: allow users to spatially arrange related windows into clusters that move together when repositioned. Implement a grid snap for users who prefer organized layouts, with a configurable grid resolution. Provide a "reset layout" command that returns all windows to a default tidy arrangement.

Design for **window persistence across sessions**: save window positions, sizes, and groupings so users return to their spatial workspace exactly as they left it. Support named workspace configurations that users can switch between based on activity (reading, coding, media).

### The Ornament Pattern for Floating Controls

Implement ornaments as the primary pattern for contextual controls and toolbars in visionOS applications.

Position **ornaments** along the bottom edge of windows by default, floating slightly in front of and below the window surface. Ornaments should feel physically connected to their parent window (moving when the window moves) while occupying a distinct depth plane that separates controls from content.

Design ornament content for **minimal visual weight**: use glass material backgrounds with vibrancy effects, SF Symbols for icons, and concise text labels. Keep ornament height to a single row of controls (44-60pt) for most use cases. Use expandable ornaments that grow to reveal additional controls only when explicitly invoked.

Support **ornament repositioning**: while the bottom edge is the default, allow ornaments to attach to left, right, or top edges when the content layout benefits from alternative placement. For media players, a bottom ornament with transport controls is conventional. For editors, a left-edge ornament with tool palettes may be more appropriate.

### Passthrough and the Immersion Spectrum

Design experiences that intentionally and meaningfully position themselves along the immersion spectrum from full passthrough to full immersion.

Treat the **immersion level as a design variable**, not a binary choice. Most productivity applications should operate in passthrough or shared space mode, where virtual content coexists with the physical environment. Entertainment and focused creative applications may justify progressive immersion that gradually dims the physical world as the user engages more deeply.

Implement **immersion transitions** as smooth, user-controllable gradients rather than abrupt switches. Use the Digital Crown interaction to allow users to dial immersion up or down at their own pace. Provide haptic and audio cues that confirm immersion level changes.

Design **passthrough-aware layouts** that account for the user's physical environment. Avoid placing virtual content where it would occlude doorways, other people, or hazards. Use room understanding APIs to intelligently position content in appropriate locations (a virtual whiteboard on a blank wall, a virtual display on a desk surface).

For **full immersion** experiences, provide a reliable, always-accessible escape mechanism to return to passthrough. Display a persistent but unobtrusive indicator of the physical environment's status (someone entered the room, a pet is nearby) to prevent the isolation anxiety that some users experience in fully immersive environments.

### SharePlay and Shared Spatial Experiences

Design collaborative spatial experiences that maintain social presence across local and remote participants.

For **co-located experiences**, render shared virtual content that all participants see from their own spatial perspective. Ensure consistent object positioning so that when one user points at a virtual element, all other users see the gesture directed at the correct location. Use spatial audio so each participant's voice emanates from their physical location.

For **remote collaboration**, represent remote participants as Personas (spatial representations based on facial and hand scanning) positioned at appropriate social distances. Place Personas to the side of shared content, mimicking natural meeting room arrangements where participants sit around a shared display.

Design **shared interaction** with clear ownership indicators: when one participant manipulates a shared object, display their name or avatar color on the manipulation handles. Implement turn-taking for single-user controls and simultaneous editing for content that supports it, with real-time conflict resolution.

### visionOS Typography and Legibility

Apply typography guidelines optimized for the unique legibility challenges of spatial displays.

Use **SF Pro** as the primary typeface, which Apple has optimized for the variable focal distances and pixel densities of spatial displays. Set minimum text sizes at 17pt for body text, 13pt for captions, and avoid anything below 10pt for any purpose. These minimums are larger than iPad equivalents because text in spatial environments is rendered at variable distances and viewed through optical systems that reduce effective resolution.

Implement **dynamic type sizing** that adjusts based on the window's distance from the user. Text that is legible at 1.5 meters becomes too small at 3 meters. Scale text proportionally when users reposition windows to greater distances, or constrain maximum window distance to maintain legibility.

Choose **high-contrast color combinations** for text, favoring white or light text on the glass material system's semi-transparent dark backgrounds. Avoid thin font weights (ultralight, thin) for any text that must be read quickly or at a glance. Regular and medium weights provide the best balance of spatial legibility and visual refinement.

---

## Meta Quest Design Patterns

### Hand Tracking vs. Controller Input

Design for seamless transitions between hand tracking and controller input, as Quest users frequently switch between them.

For **hand tracking**, design larger interactive targets than traditional touch interfaces: minimum 48mm diameter at arm's length interaction distance. Implement a clear pointer ray that extends from the user's index finger during far-field interaction, and switch to direct touch semantics when the user's hand is within 30cm of a virtual surface. Provide visual feedback on hand detection state so users know when their hands are being tracked.

For **controller input**, leverage the standard Quest controller layout: trigger for primary selection, grip for grabbing, thumbstick for navigation, and face buttons for system actions. Design consistent mappings across the application and display controller diagrams during onboarding or when new interactions are introduced.

Handle **input method transitions** gracefully. Detect when a user sets down controllers and raises hands (or vice versa) and switch input modes without requiring explicit settings changes. Maintain a brief dual-input period during transitions to avoid dropping user actions. Display a subtle input mode indicator (hand icon or controller icon) in the periphery so users always know which mode is active.

### Mixed Reality Passthrough UI

Design mixed reality experiences for Quest's passthrough cameras, accounting for their specific characteristics and limitations.

Account for **passthrough visual quality**: current passthrough has limited dynamic range, color accuracy, and resolution compared to direct vision. Avoid designs that require users to read small physical-world text through passthrough or to make fine color distinctions in the physical environment. Use virtual overlays to enhance physical world readability when needed.

Position **virtual elements relative to physical surfaces** using scene understanding. Anchor menus and panels to detected walls, tables, and floors so they feel physically grounded. When physical surface detection is unavailable or inaccurate, fall back to head-relative or world-locked positioning with explicit visual anchoring cues.

Design for **lighting adaptation**: virtual content should respond to the physical environment's lighting conditions detected through passthrough. Bright virtual elements in a dark room or dark elements against bright passthrough both create jarring discontinuities. Implement automatic brightness and contrast adjustment for virtual UI based on passthrough luminance analysis.

### Guardian/Boundary System Integration

Respect and integrate with Quest's Guardian boundary system rather than fighting against it.

Design the experience's **spatial requirements** to fit within typical Guardian sizes (2m x 2m for room-scale, stationary for seated). Detect the available Guardian size at launch and adapt the experience layout accordingly. Never place critical interactive elements outside the Guardian boundary.

Implement **boundary proximity warnings** that supplement the system Guardian: when the user's hands or body approach the boundary during gameplay or interaction, dim virtual content in that direction and gently redirect attention toward the center of the play space. For experiences that involve physical movement, display a virtual floor pattern or boundary indicator that is visible without breaking immersion.

Handle **boundary redefinition** gracefully. If the user redraws their Guardian mid-experience, detect the change and reposition virtual elements to fit the new boundary. Save spatial layouts relative to the Guardian boundary rather than absolute world coordinates so they adapt to reconfigured spaces.

### Social Presence and Avatar Design

Design avatar and social presence systems that balance expressiveness, comfort, and performance.

Implement **avatar expression mirroring** that maps the user's facial expressions (detected through the headset's face-tracking cameras) to their avatar in real time. Prioritize mouth movement for speech synchronization, eye movement for gaze direction (critical for social signaling), and eyebrow movement for emotional expression. Accept graceful degradation when full face tracking is unavailable: procedurally animate expression based on voice analysis.

Design **avatar customization** that offers extensive personalization while maintaining consistent proportions that work for the interaction model. Allow creative expression (unusual colors, fantasy features) while ensuring all avatars have clear eye direction indicators and visible mouth movement for communication legibility.

Support **multiple representation fidelity levels**: a full-body expressive avatar for social spaces, a simplified upper-body avatar for collaborative work sessions, and a name badge or cursor for large-group events where rendering dozens of full avatars would impact performance.

### Comfort Ratings and Content Warnings

Implement a comprehensive comfort rating system that helps users self-select appropriate experiences.

Define **comfort tiers** based on empirically validated motion sickness risk factors: Comfortable (stationary or slow movement, no artificial locomotion), Moderate (some artificial movement, moderate pace), Intense (fast movement, rotation, height changes). Display the comfort rating prominently on experience launch screens and in store listings.

Provide **per-symptom warnings** rather than generic comfort ratings when possible: "This experience includes artificial forward movement," "This experience includes height exposure," "This experience includes rapid rotation." Different users have different susceptibility profiles, and specific warnings allow them to make informed choices based on their personal tolerances.

Implement **dynamic comfort settings** within experiences: adjustable locomotion speed, optional vignetting during movement, snap-turn vs. smooth-turn options, and teleportation alternatives to continuous movement. Present these settings during first launch and make them accessible from the pause menu.

---

## Spatial Layout Principles

### Z-Depth and Information Layering

Use depth as a semantic dimension that communicates information hierarchy, state, and relationship.

Establish a **depth hierarchy** convention: content at the base depth plane (0-50cm from the default surface), interactive controls slightly forward (10-30cm in front of content), modal overlays and alerts further forward (50-100cm in front of content), and environmental/ambient elements behind the content plane. Maintain consistent depth semantics across the application so users develop intuitive spatial literacy.

Use **depth transitions** to communicate state changes: bring elements forward when activated, push them back when deactivated, and remove them to infinity when dismissed. Animate depth changes over 200-400ms with natural easing to maintain the physical metaphor of objects moving through space.

Avoid **depth fighting**: never place two interactive layers at the same depth where they might overlap. When content overlaps in screen space but occupies different depths, ensure sufficient depth separation (minimum 10cm) for comfortable binocular disparity and clear targeting.

### Comfortable Viewing Zones and Distances

Respect the physiological comfort constraints of human spatial perception in all layout decisions.

Position primary content in the **comfort zone**: 1-4 meters distance, within 30 degrees horizontal and 20 degrees vertical of the user's neutral head position (straight ahead, slight downward gaze). Peripheral content can extend to 60 degrees horizontal but should not contain text or detailed visuals that require sharp focus.

Avoid the **near-field discomfort zone** below 0.5 meters. Content placed too close causes vergence-accommodation conflict in current headsets, leading to eye strain and discomfort. Reserve the near-field zone for brief, transient interactions only (confirming a grab gesture, displaying a hand menu).

Design for **seated and standing postures**: detect the user's head height at launch and adjust the vertical center of the interface accordingly. A seated user's comfortable gaze center is approximately 1.2m above the floor; a standing user's is approximately 1.6m. Adjust all spatial layouts to match the detected posture.

### Curved vs. Flat Panel Layouts

Choose panel geometry based on content type and interaction requirements.

Use **curved panels** for content-consumption interfaces (browsing, reading, video viewing) where the user remains relatively stationary. Curve the panel at a radius equal to its distance from the user so that all points on the panel are equidistant from the eyes, providing uniform sharpness and comfortable viewing. Use a cylindrical curve for wide panels, a spherical curve for tall-and-wide panels.

Use **flat panels** for precision interaction interfaces (text editing, drawing, detailed manipulation) where the user needs predictable spatial relationships between input gestures and content response. Flat panels maintain consistent pixel density and aspect ratio, which is important for applications that map to traditional 2D workflows.

Support **panel curvature adjustment** as a user preference. Some users prefer flat panels for all contexts; others prefer curved panels for everything. Provide a global setting with per-application override capability.

### Spatial Audio for UI Feedback

Integrate spatial audio as a core UI feedback channel, not merely a cosmetic enhancement.

Assign **positional audio to interface elements**: when a notification appears at the user's upper-right, play the notification sound from that spatial direction. When the user selects a menu item on their left, play the selection sound from the left. This spatial audio mapping reinforces the spatial UI model and helps users maintain awareness of interface element locations without visual search.

Design **audio feedback for interaction states**: a subtle soft sound when gaze enters an interactive element (hover), a crisp confirmation sound on selection (pinch or click), a resistance or friction sound when dragging, and a satisfying placement sound when dropping. Keep these sounds brief (50-200ms), non-fatiguing, and consistent across the application.

Implement **audio distance attenuation** for spatial interfaces: elements further from the user produce quieter audio feedback, reinforcing the depth hierarchy. Modal alerts should be louder (closer) than ambient notifications (further), matching their visual depth position.

### Gaze-Aware Responsive UI

Adapt interface behavior based on where the user is looking to create focused, calm experiences.

Implement **attention-based detail levels**: show full detail (labels, descriptions, secondary actions) for elements near the user's gaze point, and reduce to simplified representations (icons only, collapsed state) for elements in the periphery. Transition smoothly as the user's gaze moves across the interface, expanding elements as they receive attention and collapsing them as attention moves away.

Use **gaze dwell** carefully. Dwell-to-activate (staring at an element to trigger it) is useful for accessibility and hands-free scenarios but must include generous dwell times (800ms+) and clear progress indicators to prevent accidental activation. Never use dwell as the only activation method; always provide an alternative explicit gesture.

Design **gaze-aware content loading**: preload content in the direction of the user's gaze movement so that scrolling or panning feels instantaneous. Prioritize rendering quality for elements near the gaze center and reduce quality for peripheral elements to maintain performance.

---

## Voice Interface Deep Dive

### Conversation Design Methodology

Apply Google's conversation design framework and complementary methodologies to create voice interfaces that feel natural and effective.

Begin every voice design project with **persona definition**: define the voice interface's personality as a detailed character description, including communication style (formal/informal, concise/elaborate, empathetic/matter-of-fact), knowledge scope (expert in specific domains, general knowledge), and relationship to the user (assistant, guide, companion, tool). Write sample dialogs in this persona's voice before designing any system logic.

Map the **conversation lifecycle**: opening (how the interaction begins, greeting, context establishment), body (the core task or information exchange), error handling (what happens when things go wrong), and closing (how the interaction concludes, confirmation, next steps). Design each phase explicitly rather than focusing only on the happy path.

Create **dialog flow diagrams** that map every possible conversation state, including: user intents (what the user might want), system actions (what the voice interface does), prompts (what the voice interface says), expected responses (what the user might say next), and error states (what happens when the system does not understand). Test these flows through table-reading exercises where team members role-play the user and system.

### VUI Dialog Flow and State Management

Implement robust state management that handles the inherent ambiguity and non-linearity of spoken conversation.

Design **dialog states** with explicit entry conditions, valid user inputs, system responses, and transition rules. Maintain a conversation context stack that tracks: the current dialog state, pending questions awaiting answers, established facts (slot values), and conversation history for reference resolution ("that one," "the first option").

Handle **out-of-order information** gracefully. When the user provides information that answers a question the system has not yet asked, accept and store it rather than following the rigid dialog script. If a user says "Book me a flight to Tokyo next Tuesday, economy class," capture all three slots (destination, date, class) simultaneously rather than asking for them sequentially.

Implement **context persistence** across turns with appropriate decay. Recently discussed entities and preferences should remain available for reference ("change that to Thursday" should map "that" to the most recently discussed date) while older context should fade gracefully. Define context lifetime rules: within-turn context persists for 2-3 turns, session context persists for the entire interaction, and user profile context persists across sessions.

### Prompt Escalation Strategies

Design graduated assistance that starts with natural, open-ended prompts and progressively constrains as the user struggles.

Begin with an **open prompt** that invites natural language: "What would you like to do?" If the user's response is not understood, escalate to a **constrained prompt** that narrows the scope: "Would you like to check your balance, make a transfer, or pay a bill?" If still unsuccessful, escalate to a **guided prompt** with explicit options: "Say 'balance,' 'transfer,' or 'bill.'" As a final resort, offer to **transfer to a human** or provide an alternative input modality.

Tailor the **escalation pace** to the interaction context. For first-time users, escalate quickly (after one failed open prompt) to reduce frustration. For experienced users, allow more attempts at open prompts before constraining, respecting their likely preference for natural interaction.

### Voice Persona Design

Design voice personas that are consistent, appropriate, and engaging without being deceptive.

Define the persona's **vocal characteristics** in detail: gender presentation (or intentionally gender-neutral), age range, accent/dialect, speaking pace (measured in words per minute: 130-160 for informational content, 100-130 for complex instructions), pitch range, and warmth level. Ensure these characteristics are consistent across all prompts and interactions.

Design **emotional range** appropriate to the persona's role. A medical information assistant should convey calm competence and empathy without false cheerfulness. A gaming companion can be enthusiastic and expressive. A banking assistant should be professional and reassuring. Map specific emotional tones to specific conversation states: empathy for error recovery, enthusiasm for positive outcomes, calm authority for security-sensitive interactions.

Avoid **persona characteristics that deceive**: do not design voice personas to sound indistinguishable from human operators without disclosure. Ensure users understand they are interacting with an AI system, even if the voice is highly natural and personable.

### Multi-Language Voice Interface Considerations

Design voice interfaces that function across languages without assuming English-centric interaction patterns.

Handle **language detection** automatically: listen for the first few seconds of speech to identify the language and switch the dialog system to the appropriate language model and response set. Support mid-conversation language switching for multilingual users who may mix languages naturally (code-switching).

Design **locale-appropriate interaction patterns**: formal address conventions (tu/vous, du/Sie), culturally appropriate levels of directness, and locale-specific number/date/currency formatting in voice responses. Do not simply translate English prompts; redesign dialog flows for each target language's conversational norms.

Account for **speech recognition accuracy variation** across languages. Languages with less training data may have higher error rates. Adjust confirmation frequency and escalation thresholds by language, confirming more frequently in languages where recognition accuracy is lower.

### Voice Error Recovery Patterns

Design error recovery that maintains conversation flow and user confidence.

Implement **tiered error responses** that vary based on the type and frequency of errors. First misunderstanding: rephrase the question with additional context ("I didn't catch that. Could you tell me the city you're traveling to?"). Second misunderstanding: offer constrained options ("I'm having trouble understanding. Are you saying Boston, Austin, or something else?"). Third misunderstanding: offer alternative modalities ("Would you like me to send you a text message with a link to complete this on screen?").

Use **implicit confirmation** for high-confidence recognitions ("Booking a flight to Tokyo...") and **explicit confirmation** for low-confidence or high-stakes recognitions ("I heard you want to transfer $5,000 to account ending in 4392. Is that correct?"). Never confirm every utterance explicitly, as this creates tedious interaction.

Design **correction patterns** that are efficient: "No, I said Boston not Austin" should be parseable without requiring the user to repeat the entire utterance. Support partial corrections, negation patterns ("not that one, the other one"), and ordinal references ("the second option").

### Wake Word Design and False Activation Prevention

Design wake word systems that balance responsiveness with false activation prevention.

Choose a **wake word** with distinct phonetic characteristics: 3-4 syllables, uncommon in everyday speech, phonetically distinctive from common words in all target languages, and easy to pronounce across accents. Test candidate wake words against large corpora of ambient speech to measure false activation rates before deployment.

Implement **multi-stage activation**: the wake word detector (always listening, low power) triggers a more sophisticated speech recognition system that confirms the activation was intentional before opening the microphone for full processing. Display a clear **listening indicator** (light, animation, sound) immediately upon activation so users know the system is attending.

Design for **false activation recovery**: when the system activates incorrectly, provide a quick dismiss mechanism (a short silence timeout, a "never mind" command, or a physical cancel gesture). Do not speak a lengthy greeting before the user has a chance to cancel an accidental activation. Keep the initial activation response brief: a short tone or a single-word acknowledgment ("Yes?") rather than a full sentence.

---

## Multimodal Interaction Design

### Input Fusion

Design systems that intelligently combine simultaneous inputs from multiple modalities into a unified interaction.

Implement **complementary fusion** where different modalities contribute different information to a single command: "Put that [voice] there [pointing gesture]," where voice specifies the action and gesture specifies the object and location. Parse multimodal inputs within a temporal window (typically 1-3 seconds) and resolve cross-modal references using spatial, temporal, and semantic context.

Handle **redundant input** where the user provides the same information through multiple channels simultaneously (tapping a button while also saying "confirm"). Treat redundant inputs as reinforcement of a single intent rather than two separate commands. Use the redundancy to increase confidence in intent recognition.

Design for **sequential multimodal input** where users chain modalities: gaze at an object, then voice a command about it. Maintain a short-term multimodal context buffer that links recent gaze targets, gesture references, and touch selections to subsequent voice commands. Define clear timeout rules for when cross-modal references expire (typically 5-10 seconds).

### Modality Switching

Design interfaces that support fluid transitions between input methods without mode confusion or lost context.

Detect **modality switches** automatically based on user behavior: if a user has been typing and begins speaking, transition to voice input mode without requiring explicit mode selection. Maintain context across the switch so the voice input is interpreted in the context of what was being typed.

Provide **modality suggestions** based on context: when the user is in a noisy environment, suggest touch or text input. When the user's hands are occupied, suggest voice. When precision is needed, suggest direct manipulation. Frame suggestions as helpful rather than prescriptive.

Support **concurrent modality use** where users employ different modalities for different aspects of the interaction simultaneously: scrolling with one hand while voice-dictating a response, or gazing at a reference document while typing in a different window.

### Cross-Device Continuity

Design experiences that flow seamlessly across devices, from phone to desktop to spatial computing headset.

Implement **handoff protocols** that transfer the current interaction state between devices with minimal user effort. When a user transitions from phone to desktop, transfer: the current task state, conversation history, unsaved inputs, scroll position, and active selections. Use a brief visual animation that shows content "traveling" between devices to reinforce the continuity metaphor.

Design **device-appropriate representations** of the same content: a spatial 3D model viewer on the headset becomes an interactive 2D turntable on the desktop and a static gallery on the phone. Maintain content fidelity while adapting the interaction model to each device's strengths.

Support **simultaneous multi-device use** where a user employs multiple devices concurrently: a phone as a controller while wearing a headset, a laptop displaying reference material while a spatial display shows the primary workspace. Design complementary roles for each device rather than simply mirroring content.

### Ambient Interfaces

Design proactive, context-aware systems that provide information and assistance without requiring explicit user invocation.

Implement **contextual triggers** that surface relevant information based on environmental and behavioral signals: display travel time to the next calendar event when the user picks up their keys, show meeting prep notes when the user enters a conference room, surface relevant messages when the user's attention becomes available after a focused work period.

Design ambient information displays with **multiple attention levels**: a glanceable peripheral state (a colored light, a single number), a summary state (a brief notification card), and a detailed state (full information panel). Let users pull information from glanceable to detailed as they allocate attention, rather than pushing detailed information that demands immediate attention.

Balance **proactivity with restraint**: an ambient system that constantly demands attention becomes a distraction system. Establish a maximum interruption frequency, prioritize signals by urgency and relevance, and batch non-urgent notifications. Measure and optimize for user attention wellbeing, not engagement metrics.

### Wearable Interface Design

Design interaction patterns optimized for the unique constraints and capabilities of wearable devices.

For **smartwatch interfaces**, design for 2-5 second interactions maximum for most tasks. Use a single-column layout with 44pt minimum touch targets. Prioritize the information most needed at a glance (time, current activity status, next upcoming event) and progressive disclosure for details. Support the Digital Crown as a precise scrolling and selection input that works without occluding the small display.

For **smart ring interfaces**, design interactions around the ring's limited input vocabulary: single tap, double tap, long press, and rotation gestures. Map these to high-frequency, low-complexity actions: accept/dismiss notification, start/stop timer, advance presentation slide, trigger voice assistant. Never require the ring to be the primary interface for complex tasks; use it as a remote trigger for experiences hosted on a more capable device.

For **smart glasses interfaces**, design for the extreme constraint of a small peripheral display combined with voice and gesture input. Keep visual notifications to the absolute minimum: a dot of color, a single icon, a 3-5 word text snippet. Rely on audio and haptic channels for most feedback. Design voice interactions that are socially appropriate for public use (short commands, confirmable with a nod rather than spoken affirmation).

---

## Emerging Interaction Paradigms (2025-2030)

### Brain-Computer Interfaces

Design for the current and near-term state of non-invasive brain-computer interfaces, which offer limited but growing interaction capabilities.

Current non-invasive BCI provides **coarse intent detection**: binary yes/no, attention level, relaxation level, and basic directional commands (up/down/left/right) at slow speeds (5-20 bits per minute). Design BCI-enhanced interfaces around these limitations: use BCI as a confirmation or selection channel (think "yes" to select the highlighted option) rather than a primary input method. Pair BCI with other modalities where BCI provides the intent and another modality provides the specifics.

Address **calibration UX** as a critical design challenge. Current BCI systems require per-session calibration lasting 2-15 minutes. Design calibration as an engaging, game-like experience rather than a tedious procedure. Track calibration quality in real-time and communicate whether the current calibration is sufficient for the intended interaction.

Design for **signal reliability**: BCI signals are noisy and vary with the user's cognitive state, fatigue level, and external electromagnetic interference. Implement confidence thresholds with clear visual feedback: "I detected an intent but I'm not confident enough to act on it. Did you mean to select this?" Never execute irreversible actions based solely on BCI input without confirmation through a more reliable modality.

### Emotion-Aware Interfaces

Design interfaces that sense and respond to the user's emotional state through physiological signals while maintaining user agency and privacy.

Use **physiological inputs** (heart rate variability, skin conductance, facial expression, voice tone analysis) to create adaptive interfaces that respond to emotional context. When elevated stress is detected, simplify the interface, reduce cognitive load, and offer support. When engagement is high, present more advanced options and challenges. When attention wanes, reduce information density and surface the most critical content.

Implement emotion sensing with **strict transparency and control**. Always display an indicator showing that emotion sensing is active and what signals are being monitored. Provide immediate access to disable emotion sensing entirely, to pause it temporarily, or to correct the system's emotional assessment ("I'm not frustrated, I'm concentrating"). Never use emotion data for purposes beyond the immediate interface adaptation without explicit informed consent.

Design **emotional responses** that are appropriate and proportionate. An interface that detects mild frustration might simplify a form or offer help. An interface that detects distress should provide supportive resources and human assistance options. Never manipulate emotions for engagement or commercial purposes. Never gate-keep functionality based on emotional state.

### Digital Twin Interactions

Design interfaces for interacting with virtual representations of physical objects, environments, and systems.

Present digital twins with **appropriate fidelity levels**: a high-fidelity visual replica for inspection and analysis, a schematic view for system understanding, a data overlay view for monitoring metrics, and a simulation view for testing changes. Allow rapid switching between views based on the current task.

Implement **bidirectional synchronization** visualization: when the physical object changes state, animate the digital twin updating to match. When the user manipulates the digital twin to plan a change, display the pending changes distinctly from the current physical state. Provide explicit "apply to physical" commands that push digital twin changes to the real system, with appropriate safety confirmations.

Design **temporal navigation** for digital twins: allow users to scrub through the twin's state history to understand how the physical system reached its current state, and simulate future states based on planned changes or predicted conditions. Display temporal navigation as a timeline with key events marked and state snapshots at configurable intervals.

### Swarm Interfaces

Design control interfaces for managing multiple autonomous agents, robots, or drones from a single operator station.

Implement **overview-detail** visualization: a map or spatial view showing all agents' positions and states simultaneously (the overview) with the ability to select any individual agent for detailed status, telemetry, and direct control (the detail). Use color coding, icons, and animation to convey each agent's current state (idle, executing task, error, returning) at a glance.

Design **command abstraction levels**: individual agent commands ("Agent 7, move to position X"), group commands ("All agents in sector B, begin survey pattern"), and goal-based commands ("Cover the entire building perimeter with overlapping camera views"). The system should decompose high-level goals into agent-level commands and display the plan for operator review before execution.

Handle **exception management** as the primary operator task. In nominal operation, the swarm executes autonomously and the operator monitors. Design the interface to surface exceptions prominently: an agent that has deviated from its plan, an agent that has encountered an obstacle, an agent that needs a decision that exceeds its autonomous authority. Prioritize exceptions by severity and present them in order of time-criticality.

### Tangible UI: Bridging Physical and Digital

Design interfaces that use physical objects as input devices and control surfaces for digital systems.

Implement **object recognition** that identifies physical items placed on or near an interactive surface and generates appropriate digital responses. A physical document placed on a smart desk surface could trigger OCR and digital filing. A physical product placed on a retail display could trigger information overlay and comparison tools. A physical architectural model placed on a table could trigger structural analysis visualization.

Design **physical-digital mappings** that feel natural and discoverable. Rotating a physical dial to adjust a digital parameter is intuitive. Moving physical blocks on a surface to organize digital content leverages spatial reasoning skills. The mapping between physical action and digital response should be immediate, proportional, and reversible.

Support **hybrid workflows** where users move fluidly between physical and digital interactions. A designer might sketch on physical paper, scan or photograph the sketch to digitize it, refine it digitally, then print and annotate the refinement on paper again. Design the system to support this fluid alternation without requiring formal "scan" or "import" steps.

---

## Summary of Core Principles for Spatial, Voice, and Multimodal Design

1. **Embody over display**: spatial interfaces should feel like physical objects in the environment, not floating screens.
2. **Respect the body**: design within human physiological comfort zones for visual, auditory, vestibular, and motor systems.
3. **Modality fluidity**: never lock users into a single input method; support graceful transitions between voice, gesture, gaze, touch, and novel inputs.
4. **Conversation, not command**: voice interfaces succeed when they follow conversational norms rather than command-line paradigms.
5. **Progressive immersion**: allow users to control their level of engagement with virtual content, from peripheral awareness to full immersion.
6. **Social appropriateness**: design interactions that are acceptable in the user's social context, whether private, professional, or public.
7. **Calibrate to capability**: match the complexity of the interaction to the fidelity and reliability of the input modality.
8. **Fail gracefully across modalities**: when one input method fails, seamlessly offer alternatives rather than blocking the interaction.
9. **Privacy as a first principle**: physiological, spatial, and voice data are deeply personal; treat them with the highest privacy standards.
10. **Design for the body you inhabit**: account for the full range of human physical ability, sensory capacity, and cognitive diversity in every spatial and multimodal design decision.

These patterns will evolve rapidly as spatial computing hardware matures, voice AI improves, and new input modalities emerge. Treat this reference as a living document that requires regular revision as the field advances.
