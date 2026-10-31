# Figma Mastery Workflows — Professional Design Tool Techniques

This reference covers professional-grade Figma workflows spanning layout, components, variables, prototyping, handoff, library management, file organization, plugins, shortcuts, and collaboration. Each section provides actionable patterns and specific Figma mechanics rather than generic design advice.

---

## 1. Auto Layout Deep-Dive

Auto Layout is the backbone of every production Figma file. Mastering it means understanding every parameter and knowing when each applies.

### Padding

Padding controls the internal spacing between the auto layout frame's boundary and its children.

- **Uniform padding**: Set a single value that applies to all four sides. Useful for simple containers like badges and pills.
- **Symmetric padding**: Set horizontal and vertical independently. The most common pattern for buttons (e.g., 24px horizontal, 12px vertical).
- **Individual side padding**: Click the independent padding icon to set top, right, bottom, and left separately. Essential for cards where bottom padding differs from top, or for asymmetric containers like sidebar navigation items with extra left indent.

### Gap

Gap defines the space between consecutive children in the layout direction.

- **Fixed gap**: A constant pixel value between each child. Standard for most use cases — button groups, form fields, nav items.
- **Auto gap (space between)**: Distributes remaining space equally between children, equivalent to CSS `justify-content: space-between`. Use this for headers where a logo sits left and nav items sit right, or for footers distributing link groups across the full width.
- **Gap on the cross axis**: As of recent Figma updates, wrap-enabled auto layouts support both primary and cross-axis gap, mirroring CSS `row-gap` and `column-gap`.

### Alignment

Alignment controls how children position within the auto layout frame along both axes.

- **Primary axis alignment**: Controls distribution along the layout direction. Options: start (packed left/top), center, end (packed right/bottom), space-between (auto gap).
- **Cross axis alignment**: Controls alignment perpendicular to the layout direction. Options: start, center, end, baseline (text baseline alignment). Baseline alignment is critical for rows mixing text of different sizes, such as a price display with a large dollar amount and a smaller currency label.
- **Individual child alignment**: Override a specific child's cross-axis alignment. Right-click a child and choose "Align self" to make one item stretch while siblings stay centered.

### Min/Max Constraints

Constraints on auto layout frames and their children enable responsive behavior.

- **Min width / Max width**: Set a minimum width so a button never shrinks below its touch target, or a max width so a text container never exceeds a readable line length (e.g., max-width 640px for body text).
- **Min height / Max height**: Prevent a card from collapsing when content is sparse (min-height) or from blowing out when content overflows (max-height with clipping).
- Constraints combine with fill/hug/fixed sizing to produce genuinely responsive components.

### Absolute Positioning Within Auto Layout

Any child inside an auto layout frame can be set to "Absolute position," removing it from the flow while keeping it visually within the parent.

- Use this for notification badges on icons (the badge sits absolute, top-right, while the icon participates in layout flow).
- Use for decorative elements like background gradients or watermarks that should not push other children.
- Absolute-positioned children respond to constraints (pin to edges), not to auto layout rules.

### Sizing Modes: Fill, Hug, Fixed

- **Hug contents**: The frame shrinks to wrap its children tightly. Default for new auto layout frames. Ideal for buttons, tags, chips.
- **Fill container**: The frame expands to consume available space in the parent's layout direction. Equivalent to CSS `flex: 1`. Use for the main content area in a sidebar layout, or for input fields that should stretch.
- **Fixed**: A specific pixel dimension that does not respond to parent or children. Use sparingly — mainly for icons and avatars where exact dimensions matter.

### Nested Auto Layout Patterns

Real interfaces are deeply nested auto layout frames. Typical hierarchy:

```
Page Frame (vertical, fill)
  Header (horizontal, fill, auto gap)
    Logo (fixed)
    Nav Group (horizontal, hug, gap 8)
    Actions (horizontal, hug, gap 12)
  Main Content (horizontal, fill)
    Sidebar (vertical, fixed 280, gap 4)
    Content Area (vertical, fill, gap 24)
      Section (vertical, fill, gap 16)
        Section Header (horizontal, fill)
        Card Grid (wrap, fill, gap 16)
          Card (vertical, hug, min-w 280, max-w 400)
  Footer (horizontal, fill, padding 24 48)
```

### Common Patterns

**Card with consistent spacing**: Vertical auto layout, 16px gap, 20px padding all sides. Image child set to fill-width and fixed height. Text group as a nested vertical auto layout with 4px gap. Action row as nested horizontal auto layout with auto gap.

**Responsive header**: Horizontal auto layout, fill-width, auto gap. Logo fixed-size at the start. Navigation group hugs contents. CTA button hugs at the end. The auto gap pushes logo left and CTA right with navigation floating as needed.

**Form field with label + input + helper**: Vertical auto layout, 4px gap. Label is a text layer (hug). Input is a nested horizontal auto layout (fill width, fixed height 44px, 12px horizontal padding) containing placeholder text. Helper text is a text layer (hug) with secondary color. The entire field component uses fill-container width so it stretches in any parent form.

---

## 2. Component Architecture

### Component vs. Instance Relationship

A **main component** (purple diamond icon) defines the source of truth. An **instance** (hollow diamond) inherits all properties from its main component. Overrides on instances are preserved across updates unless the overridden property is removed or structurally changed on the main component.

Key rules:
- Text overrides persist when the main component changes text content.
- Fill overrides persist when the main component changes fills.
- Adding new layers to the main component adds them to all instances.
- Removing layers from the main component removes them from instances (including their overrides — destructive).
- Reordering layers on the main component reorders them on instances.

### Variant Properties

Variants unify related component states into a single component set.

- **Enum property**: A list of named options. Example: Size = Small, Medium, Large. Type = Primary, Secondary, Tertiary.
- **Boolean property**: A true/false toggle. Example: Has Icon = true/false. Show Badge = true/false. Boolean properties with matching layer names automatically toggle layer visibility.
- **Text property**: Exposes a text layer's content as a configurable property. Example: Label, Helper Text, Placeholder. Consumers edit text directly in the properties panel without digging into layers.
- **Instance swap property**: Exposes a nested instance slot for swapping. Example: Icon (swap any icon component), Leading Element (swap avatar, icon, or checkbox). Define "preferred values" to suggest relevant swap options.

### Component Sets Organization

A component set groups variants visually. Best practices:

- Keep variant grids tidy: rows for one property (e.g., Type), columns for another (e.g., State).
- Limit properties to 4-5 maximum. Beyond that, consider splitting into separate component sets.
- Use a documentation layer (hidden, outside the component set) to annotate intended usage.

### Nested Component Composition

Production components are compositions of smaller atomic components.

Example — a `ListItem` component:
- Contains an `Avatar` instance (instance swap property).
- Contains a `TextGroup` built from `Text/Label` and `Text/Caption`.
- Contains an `IconButton` instance (instance swap property).
- The `ListItem` itself is a variant with properties: Has Avatar (boolean), Has Action (boolean), Size (enum).

### Slot Pattern

The slot pattern uses instance swap properties to create open composition points.

Example — a `Card` component with a `CardContent` slot:
- The card has a fixed header and footer.
- The middle area contains a placeholder instance (e.g., `.Slot/CardContent`).
- Consumers swap `.Slot/CardContent` for `CardContent/Image`, `CardContent/Chart`, `CardContent/UserProfile`, etc.
- Prefix slot placeholders with a dot (`.Slot/...`) so they sort to the top and are identifiable as abstract placeholders.

### Base Component Pattern

A base component holds shared structure; variants reference it.

Example — `_Base/Button`:
- Contains icon (optional via boolean), label, and trailing element.
- Defines auto layout, padding, gap, border radius.
- Each variant (`Button/Primary`, `Button/Secondary`) overrides only color fills and text colors.
- If padding or gap needs to change, update the base once and all variants inherit.
- Prefix base components with an underscore (`_Base/...`) so they sort to the top and are clearly not for direct consumption.

### Naming Conventions

Follow a hierarchical slash-delimited pattern:

```
Category / Type / State

Button / Primary / Default
Button / Primary / Hover
Button / Primary / Disabled
Input / Text / Default
Input / Text / Focus
Input / Text / Error
Icon / Navigation / ArrowLeft
Icon / Navigation / ArrowRight
```

This structure creates automatic groupings in the assets panel and instance swap menus. Consistent naming is the single most impactful practice for scalable component libraries.

---

## 3. Variable Modes & Design Tokens

### Variable Types

Figma supports four variable types:

- **Color**: Stores a single color value (solid). Used for fills, strokes, effects.
- **Number**: Stores a numeric value. Used for border radius, spacing, sizing, opacity, stroke width.
- **String**: Stores a text string. Used for text content and font family references.
- **Boolean**: Stores true/false. Used for component property values and visibility toggles.

### Collections and Modes

A **collection** groups related variables. Each collection supports multiple **modes** — alternate value sets for the same variable names.

Common collection strategies:

| Collection | Mode 1 | Mode 2 | Mode 3 |
|---|---|---|---|
| Color Theme | Light | Dark | High Contrast |
| Density | Comfortable | Compact | — |
| Breakpoint | Mobile | Tablet | Desktop |
| Brand | Brand A | Brand B | — |

Apply modes at the frame level. A frame set to "Dark" mode causes all child layers referencing color variables to resolve to their Dark mode values. Modes cascade — child frames inherit the parent's mode unless overridden.

### Variable Scoping

Scoping restricts where a variable appears in the UI:

- A color variable scoped to "Fill color" will not appear in the stroke color picker.
- A number variable scoped to "Gap" will not appear in the corner radius input.
- Available scopes for color: Fill Color, Stroke Color, Text Color, Effect Color.
- Available scopes for number: Corner Radius, Gap, Padding, Width, Height, Stroke Width, Opacity, Font Size, Line Height, Letter Spacing, Paragraph Spacing.

Scoping prevents accidental misuse and keeps the variable picker clean and contextually relevant.

### Aliasing (Semantic Tokens Referencing Primitive Tokens)

A two-tier (or three-tier) aliasing architecture separates raw values from semantic meaning.

**Primitive tokens** (tier 1):
```
Blue/500 = #3B82F6
Gray/100 = #F3F4F6
Gray/900 = #111827
Spacing/16 = 16
Spacing/24 = 24
```

**Semantic tokens** (tier 2):
```
Color/Brand/Primary = {Blue/500}
Color/Surface/Default = {Gray/100}       (Light mode)
Color/Surface/Default = {Gray/900}       (Dark mode)
Color/Text/Primary = {Gray/900}          (Light mode)
Color/Text/Primary = {Gray/100}          (Dark mode)
Spacing/Component/Padding = {Spacing/16}
```

Semantic tokens alias (reference) primitives using Figma's `{}` binding syntax. When you change `Blue/500`, every semantic token that references it updates automatically. When you switch modes, semantic tokens resolve to different primitives per mode.

### Variable-Driven Responsive Design

Number variables with modes enable responsive spacing and sizing:

```
Collection: Breakpoint
Variable: Container/Padding
  Mobile = 16
  Tablet = 24
  Desktop = 32

Variable: Grid/Columns
  Mobile = 4
  Tablet = 8
  Desktop = 12
```

Apply the "Mobile" mode to a phone-sized frame and the "Desktop" mode to a wide frame. The same design automatically adjusts spacing, padding, and grid values without manual overrides.

---

## 4. Prototyping

### Interaction Types

- **On click / On tap**: Triggered by clicking or tapping. The most common trigger for navigation, button actions, and toggles.
- **On drag**: Triggered by dragging a layer. Used for sliders, carousels, dismissible cards, drag-to-reorder.
- **While hovering**: Active as long as the cursor remains over the target. Used for tooltips, hover states, dropdown previews.
- **While pressing**: Active while the mouse button / touch is held down. Used for pressed/active states on buttons.
- **Mouse enter / Mouse leave**: Fire once when cursor enters or leaves. Distinguished from "while hovering" because they trigger a one-time action rather than a sustained state.
- **After delay**: Fires automatically after a specified duration. Used for splash screens, auto-advancing onboarding, toast dismissals.
- **Key/Gamepad**: Fires on keyboard or gamepad input. Useful for prototyping desktop apps, games, or keyboard-navigable interfaces.

### Animation Types

- **Instant**: No animation. Immediate swap. Use for tab switching or state changes that should feel instantaneous.
- **Dissolve**: Crossfade between frames. Set duration and easing. Good for modals appearing, page transitions in content-heavy apps.
- **Smart Animate**: Figma interpolates position, size, rotation, opacity, and fill between matching layers (matched by layer name). The most powerful animation type. Requirements: source and destination frames must share identically named layers for those layers to animate. Layers present in only one frame fade in or out.
- **Move In / Move Out**: The destination frame slides in from a specified direction over the source frame (move in), or the source slides out revealing the destination (move out). Used for bottom sheets, side panels, slide-over navigation.
- **Push**: Both source and destination move together, the destination pushing the source off screen. Classic mobile navigation transition.
- **Slide In / Slide Out**: Similar to move in/out but with slightly different stacking behavior. Use for drawer menus, notification panels.

### Smart Animate Requirements

For Smart Animate to interpolate a layer:

1. The layer must exist in both the source and destination frame.
2. The layer must have the **exact same name** in both frames.
3. The layer must be at the **same hierarchy depth** (same parent chain) or Figma must be able to unambiguously match it.
4. Properties that animate: X/Y position, width, height, rotation, opacity, fill color, stroke color, corner radius.
5. Properties that do not animate: text content changes, image swaps, effect changes (shadows, blurs).

### Scroll Behavior

- **Fixed position**: A layer stays pinned in the viewport while the rest of the content scrolls. Use for sticky headers, floating action buttons, bottom navigation bars. Set via the "Fix position when scrolling" checkbox.
- **Sticky**: Available in auto layout frames with overflow scrolling. A child "sticks" to the top (or bottom) of the scroll container when reached, then unsticks when its section scrolls past. Use for section headers in long lists.

### Overflow Scrolling

Enable overflow scrolling on a frame by toggling "Clip content" and then setting the scroll direction:

- **Vertical scrolling**: Content taller than the frame scrolls vertically. The most common scroll type for pages and lists.
- **Horizontal scrolling**: Content wider than the frame scrolls horizontally. Used for carousels, horizontal card lists, data tables.
- **Both**: Content scrolls in both directions. Used for large canvases, maps, data grids.

### Flow Starting Points

A flow is a named entry point for a prototype. A single Figma page can contain multiple flows (e.g., "Onboarding Flow," "Checkout Flow," "Settings Flow"). Each flow starts at a designated top-level frame. In presentation mode, users can switch between flows via the flow dropdown.

### Prototype Presentation Settings

- **Device frame**: Wrap the prototype in a device mockup (iPhone, Pixel, etc.).
- **Background color**: Set the area outside the prototype frame.
- **Starting frame**: The first frame shown when the prototype loads.
- **Hotspot hints**: Show clickable areas on tap (useful during usability testing to unstick participants, but disable for realistic tests).

---

## 5. Dev Mode & Handoff

### Dev Mode Panel

Dev Mode is a dedicated workspace for developers consuming design files.

- **Inspect tab**: Click any layer to see its properties — dimensions, position, colors (with variable names), typography, spacing, border radius, effects. Measurements between layers appear on hover.
- **Code tab**: View generated code snippets. Supports CSS, iOS (SwiftUI/UIKit), and Android (Compose/XML). Code output respects variables — if a fill uses `Color/Brand/Primary`, the code shows the variable name rather than a raw hex value.
- **Component properties**: When inspecting an instance, Dev Mode shows the component name, all property values (variant, boolean, text, instance swap), and a link to the main component.

### Ready for Dev Status

Designers mark frames as "Ready for dev" to signal that a section is finalized and approved. Developers can filter the file to show only "Ready for dev" sections, ignoring work-in-progress. This is the primary workflow handoff signal.

### Annotations

Designers can add annotations directly in Dev Mode — short notes attached to specific layers. Annotations appear when developers inspect those layers. Use annotations for behavioral notes that prototypes cannot convey: "This list loads 20 items initially, then infinite scrolls," or "Error state appears after 3 failed attempts."

### Section-Based Organization

Sections (the colored region tool) group related frames. In Dev Mode, sections become navigable categories. Recommended sections: "Components," "Page Flows," "States & Edge Cases," "Specifications."

### Compare Changes Across Versions

Dev Mode includes a compare feature that highlights visual differences between the current version and a previous version. Developers use this to see exactly what changed since their last implementation pass, reducing the risk of missing updates.

### VS Code Extension Integration

The Figma for VS Code extension allows developers to inspect Figma layers, copy code, and view component specs without leaving their editor. It supports linking code files to Figma components, creating a bidirectional reference between design and implementation.

---

## 6. Library Management

### Publishing Components and Styles

To share components across files:

1. Create components, styles (color, text, effect, grid), and variables in a library file.
2. Open the Assets panel, click the book icon, and publish.
3. Select which components and styles to include. Write a description of changes for the changelog.
4. Consumers enable the library in their files via Assets > Team Library.

Published items: components, component sets, color styles, text styles, effect styles, grid styles, variable collections.

### Library Analytics

The library publisher can view analytics:

- **Insertions**: How many times each component was inserted across consuming files. Identifies heavily used components (invest in their quality) and unused components (candidates for deprecation).
- **Detachments**: How many times instances were detached from each component. High detachment rates signal that the component does not accommodate necessary overrides — redesign it for flexibility.

### Library Updates

When a library publishes changes, consuming files receive an update notification. Consumers can:

- **Review**: See a visual diff of each changed component.
- **Accept**: Apply updates to all instances of that component in the file.
- **Dismiss**: Skip the update. Instances remain on the previous version.

### Multi-Library Architecture

Scale demands layered libraries:

1. **Primitives Library**: Variables only — colors, spacing, radii, typography scales. No components. Published first.
2. **Core Components Library**: Atoms and molecules (buttons, inputs, chips, avatars). Consumes the Primitives library for all token values.
3. **Pattern Library**: Organisms and templates (headers, forms, cards, modals). Consumes Core Components.
4. **Product Library** (optional): Product-specific compositions that combine patterns into ready-to-use page sections.

This layered approach mirrors front-end token and component architecture and prevents circular dependencies.

### Team Library vs. Project Library

- **Team library**: Available to all projects within a team. Best for shared design systems.
- **Project library**: Scoped to files within a single project. Best for project-specific components that should not pollute the broader team library (e.g., marketing campaign assets).

---

## 7. Naming Conventions & File Organization

### Page Naming

Use consistent page names across all files:

| Page Name | Purpose |
|---|---|
| Cover | Thumbnail page with project name, status, last updated |
| Components | Local components specific to this file |
| Patterns | Composed patterns / organisms |
| Flows | User flow screens connected with prototyping |
| Playground | Exploration and experimentation (not for dev) |
| Archive | Deprecated or superseded designs (kept for reference) |
| -- Divider -- | Use a page named "---" as a visual separator |

### Frame Naming for Developer Clarity

Every top-level frame should communicate its purpose:

```
Login / Default
Login / Error State
Login / Loading
Dashboard / Empty State
Dashboard / Populated
Settings / Profile / Edit Mode
```

Slash-delimited naming with context makes Dev Mode navigation intuitive. Avoid generic names like "Frame 437" — rename immediately upon creation.

### Layer Naming Discipline

- Name every layer meaningfully. "Rectangle 12" and "Group 7" are technical debt.
- Use lowercase-kebab-case or PascalCase consistently within a file. Match the engineering team's convention if possible.
- Prefix utility layers with an underscore: `_background`, `_spacer`, `_divider`.
- Name boolean-toggled layers to match their boolean property name exactly (e.g., a layer named "Icon" controlled by a boolean property named "Icon").

### Version History and Branching

- **Version history**: Figma auto-saves every 30 minutes. Manually save named versions at milestones: "v1.0 — Initial handoff," "v1.1 — Post-review revisions," "v2.0 — Redesign."
- **Branching**: Create a branch to make changes without affecting the main file. Branches are full file copies that can be merged back. Use branches for large explorations, design sprints, or when multiple designers work on different features simultaneously.

### File Organization by Project Phase

```
Project Folder
  Research & Discovery
    User Interviews Notes (FigJam)
    Competitive Audit (FigJam)
  Design Exploration
    Wireframes
    Concept A
    Concept B
  Production Design
    Design System (library file)
    Feature — Onboarding
    Feature — Dashboard
    Feature — Settings
  Archive
    Deprecated — Old Dashboard
```

---

## 8. Plugin Ecosystem Essentials

### Tokens Studio (formerly Figma Tokens)

The most critical plugin for design-system-at-scale work.

- **Token management**: Define tokens in a structured JSON format (following the W3C Design Token Community Group spec).
- **Multi-file sync**: Store tokens in a Git repository (GitHub, GitLab, Azure DevOps). Push and pull token changes directly from the plugin.
- **Style Dictionary export**: Export tokens in Style Dictionary format for automated transformation into CSS custom properties, iOS assets, Android resources, or any target format.
- **Token sets**: Organize tokens into sets (primitives, semantic, component-specific) and compose them with set ordering (later sets override earlier ones).
- **Math and references**: Use expressions like `{spacing.base} * 2` and alias references like `{color.primary.500}`.

### Content Reel

Provides realistic placeholder content — names, avatars, addresses, dates, paragraphs, email addresses. Select text layers and apply content from the plugin. Essential for testing designs with real-world data lengths and variety rather than "Lorem ipsum" or uniform "John Doe" entries.

### Stark

Comprehensive accessibility checking:

- **Contrast checker**: WCAG 2.1 AA and AAA compliance for text and UI elements against their backgrounds.
- **Vision simulator**: Preview designs as seen by people with protanopia, deuteranopia, tritanopia, and other vision differences.
- **Alt text annotations**: Add alt text to images for documentation purposes.
- **Touch target checker**: Verify that interactive elements meet minimum touch target sizes (44x44pt iOS, 48x48dp Android).
- **Focus order**: Define and visualize the tab/focus order for keyboard and screen reader navigation.

### Contrast

A lightweight, focused plugin solely for checking color contrast ratios. Enter foreground and background colors (or pick from the canvas) and get instant WCAG AA/AAA pass/fail results for normal text, large text, and UI components. Faster than Stark when you only need contrast checks.

### Batch Styler

Bulk-modify styles across an entire file. Change the font family of all text styles from Inter to Roboto in one operation. Update all color styles' opacity. Rename styles in batch using find-and-replace patterns. Indispensable during design system migrations or rebrands.

### Figma to Code Plugins Overview

- **Anima**: Exports to React, Vue, HTML with responsive CSS. Supports auto layout to flexbox conversion.
- **Locofy**: AI-powered Figma-to-code targeting React, React Native, Next.js, Gatsby. Handles responsiveness and component mapping.
- **Builder.io (Visual Copilot)**: Converts Figma designs to code for multiple frameworks. Uses AI to generate cleaner output than direct structural translation.
- **TeleportHQ**: Real-time Figma-to-code with a visual editor intermediary. Supports React, Vue, Angular, and static HTML.

Treat plugin-generated code as a starting point. Always review and refactor generated output to match project conventions, remove redundancies, and ensure semantic HTML.

---

## 9. Keyboard Shortcuts & Efficiency

### Essential Shortcuts Table

| Action | Mac | Windows |
|---|---|---|
| Frame tool | F | F |
| Rectangle | R | R |
| Ellipse | O | O |
| Line | L | L |
| Text | T | T |
| Pen (vector) | P | P |
| Hand (pan) | H or hold Space | H or hold Space |
| Zoom in | Cmd + = | Ctrl + = |
| Zoom out | Cmd + - | Ctrl + - |
| Zoom to fit | Shift + 1 | Shift + 1 |
| Zoom to selection | Shift + 2 | Shift + 2 |
| Zoom to 100% | Cmd + 0 | Ctrl + 0 |
| Add auto layout | Shift + A | Shift + A |
| Remove auto layout | Option + Shift + A | Alt + Shift + A |
| Create component | Cmd + Option + K | Ctrl + Alt + K |
| Detach instance | Cmd + Option + B | Ctrl + Alt + B |
| Toggle grid | Ctrl + G | Ctrl + G |
| Toggle rulers | Shift + R | Shift + R |
| Quick actions | Cmd + / | Ctrl + / |
| Search layers | Cmd + F (in layers panel) | Ctrl + F |
| Copy properties | Cmd + Option + C | Ctrl + Alt + C |
| Paste properties | Cmd + Option + V | Ctrl + Alt + V |
| Duplicate | Cmd + D | Ctrl + D |
| Duplicate in place | Cmd + D (hold) then move | Ctrl + D then move |
| Group | Cmd + G | Ctrl + G |
| Ungroup | Cmd + Shift + G | Ctrl + Shift + G |
| Bring forward | Cmd + ] | Ctrl + ] |
| Send backward | Cmd + [ | Ctrl + [ |
| Bring to front | Cmd + Shift + ] | Ctrl + Shift + ] |
| Send to back | Cmd + Shift + [ | Ctrl + Shift + [ |
| Boolean union | Cmd + E (after union) | Ctrl + E (flatten) |
| Scale tool | K | K |
| Measure distance | Hold Option + hover | Hold Alt + hover |
| Rename layer | Cmd + R | Ctrl + R |
| Batch rename | Select multiple, Cmd + R | Select multiple, Ctrl + R |
| Toggle Dev Mode | Shift + D | Shift + D |
| Present prototype | Cmd + Shift + Return | Ctrl + Shift + Enter |

### Selection Techniques

- **Deep select**: Cmd/Ctrl + click to select a layer nested inside groups and frames without entering the group.
- **Select all with same property**: Right-click > "Select all with same fill" (or stroke, font, instance). Powerful for bulk changes.
- **Select children**: After selecting a frame, press Enter to select its first child. Tab to cycle through children.
- **Select parent**: Press Shift + Enter or Escape to move up to the parent frame.
- **Drag select into groups**: Hold Cmd/Ctrl while drag-selecting to select layers inside groups.

### Boolean Operations

- **Union**: Combines shapes into a single filled shape. Use for building custom icons from basic shapes.
- **Subtract**: Cuts the top shape out of the bottom shape. Use for creating cutouts, notches, and custom holes.
- **Intersect**: Keeps only the overlapping area. Use for masking effects and cropping shapes.
- **Exclude**: Keeps everything except the overlap. Use for ring shapes and XOR patterns.
- **Flatten** (Cmd/Ctrl + E): Converts a boolean group into a single vector path. Do this after finalizing an icon to simplify the shape and reduce file complexity.

### Batch Operations

- **Batch rename**: Select multiple layers, press Cmd/Ctrl + R. Use patterns: `Layer $n` (numbered sequence), `$&` (current name), `Icon/$&` (prepend to existing name).
- **Paste to multiple**: Select multiple targets, then paste. Each target receives the clipboard content.
- **Copy/paste properties**: Cmd/Ctrl + Option/Alt + C to copy fill, stroke, effects, text styles. Cmd/Ctrl + Option/Alt + V to paste onto a selection of target layers.

### Measuring and Spacing Techniques

- **Measure distance**: Select a layer, hold Option/Alt, and hover over other layers to see the distance in pixels.
- **Nudge amount**: Default small nudge is 1px (arrow keys), large nudge is 10px (Shift + arrow). Customize large nudge in Preferences (many teams use 8px to align with an 8pt grid).
- **Distribute spacing**: Select multiple layers, then use the Tidy Up button or "Distribute vertical/horizontal spacing" from the right panel to equalize gaps.

---

## 10. Collaboration Workflows

### Real-Time Collaboration Etiquette

- **Use cursor chat**: Press `/` to send a quick message visible at your cursor position. Use for quick contextual notes without cluttering the comments panel.
- **Name your view**: Other collaborators see your named cursor moving around the file. Ensure your Figma profile name is recognizable.
- **Avoid working on the same frame simultaneously**: Auto layout reflows triggered by one designer can disrupt another's work in the same frame. Coordinate via sections or pages.
- **Lock finished sections**: Lock layers (Cmd/Ctrl + Shift + L) that are finalized to prevent accidental edits by collaborators.

### Commenting Best Practices

- **Pin comments to specific layers**, not arbitrary canvas positions. Layer-pinned comments move with the layer and remain contextually relevant.
- **Use threads**: Reply within an existing comment thread rather than creating a new comment for the same topic.
- **Resolve comments**: Mark comments as resolved once addressed. This keeps the canvas clean and creates an audit trail.
- **Tag stakeholders**: Use @mentions to notify specific team members. Reserve @mentions for people whose input is needed, rather than notifying everyone.
- **Use emoji reactions** for lightweight feedback (thumbs up, eyes) on comments that do not require a text response.

### Design Review in Figma

Structure design reviews directly in Figma:

1. Set up a dedicated "Review" page or section.
2. Organize screens in logical flow order, not arbitrary placement.
3. Add annotations on interaction details, edge cases, and decisions.
4. Present using Observation Mode (see below) so reviewers follow the presenter's view.
5. Collect feedback as comments pinned to relevant screens.
6. After review, create a summary comment on the page listing action items.

### Branching

Figma branching allows parallel workstreams:

- **Create a branch**: File menu > Create branch. Name it descriptively: `feature/onboarding-redesign`, `experiment/dark-theme`.
- **Work in isolation**: Changes on a branch do not affect the main file. Multiple branches can exist simultaneously.
- **Request review**: Before merging, request a review from a team member. They compare the branch to main and leave comments.
- **Merge**: Once approved, merge the branch back into main. Figma integrates the changes.
- **Merge conflicts**: If the main file changed in the same areas as the branch, Figma flags conflicts. The merger must choose which version to keep for each conflicting section. Conflicts are resolved visually — Figma shows both versions side by side.

### Merge Conflict Resolution

When a conflict arises:

- Figma highlights the conflicting frames/components.
- For each conflict, choose "Use branch version" or "Use main version."
- You cannot do a partial merge of a single conflicting frame — it is all-or-nothing per conflict unit.
- Minimize conflicts by having clear ownership boundaries: different designers work on different pages or sections, and branches are short-lived.

### Observation Mode

Click on a collaborator's avatar in the top-right toolbar to enter Observation Mode. Your viewport follows their navigation and zoom level in real time. Use this during:

- **Design reviews**: All reviewers follow the presenter.
- **Pair design sessions**: A junior designer follows a senior designer's walkthrough.
- **Stakeholder presentations**: Non-designers follow along without needing to navigate themselves.

Exit Observation Mode by clicking anywhere on the canvas or pressing Escape.

### Audio Conversations

Figma supports built-in audio conversations:

- Click the headphone icon in the top-right toolbar to start or join an audio session.
- All collaborators in the file can join.
- Combine audio with observation mode for a lightweight remote design review without needing a separate video call tool.
- Audio sessions are ephemeral — they exist only while at least one participant is active.

---

## Quick Reference: Anti-Patterns to Avoid

| Anti-Pattern | Why It Hurts | Better Approach |
|---|---|---|
| Using groups instead of auto layout frames | Groups do not respond to content changes or support padding/gap | Convert to auto layout (Shift + A) |
| Detaching instances to make overrides | Loses connection to library updates | Add variant properties to accommodate the override |
| Hard-coded color hex values instead of variables | Cannot theme, cannot switch modes, inconsistent values | Always apply color variables or styles |
| Unnamed layers ("Rectangle 47", "Frame 312") | Developers cannot find or reference layers; Smart Animate breaks | Name every layer immediately on creation |
| One massive page with hundreds of frames | Slow performance, impossible navigation | Split into logical pages per feature or flow |
| Skipping "Ready for dev" status | Developers implement work-in-progress designs | Always mark frames ready before handoff |
| Ignoring library update notifications | Instances drift from the design system source | Review and accept updates promptly |
| Deeply nested boolean groups in icons | Increases file size and renders inconsistently | Flatten (Cmd+E) after finalizing boolean operations |

---

This reference equips practitioners with specific, actionable Figma techniques spanning layout engineering, component systems, token-driven theming, interactive prototyping, developer handoff, library governance, organizational discipline, plugin tooling, operational efficiency, and team collaboration. Each section maps directly to daily design tool operations and scales from individual practice to enterprise design system management.
