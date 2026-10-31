# iOS and Android Design Patterns — Platform-Native Deep Dive

## Philosophy of Platform Divergence

iOS and Android represent fundamentally different design philosophies. Apple's Human Interface Guidelines (HIG) emphasize clarity, deference, and depth through a curated, controlled aesthetic. Google's Material Design 3 emphasizes expressiveness, adaptability, and a physics-based interaction model rooted in surfaces and elevation. Designing effectively for mobile requires understanding not just the components each platform offers, but the reasoning behind each convention and the user expectations those conventions have trained over a decade of interaction.

Never force one platform's idioms onto the other. Users develop deep muscle memory for their chosen platform. An Android user expecting a back arrow in the top-left will be disoriented by an iOS-style swipe-only dismissal. An iOS user expecting a bottom sheet to expand smoothly will find an Android dialog box jarring. Respect these expectations as non-negotiable constraints.

---

## Navigation Patterns

### Tab Bar (iOS) vs Bottom Navigation Bar (Android)

**iOS Tab Bar:**
- Fixed at the bottom of the screen with up to 5 items (use "More" tab beyond 5).
- Each tab maintains its own navigation stack independently. Switching tabs preserves state — tapping the active tab pops to root.
- Icons use SF Symbols (outline for inactive, filled for active). Labels appear below icons and must always be present.
- The tab bar remains visible during push navigation within a tab. It hides only during full-screen experiences (media playback, immersive content).
- Translucent material background adapts to content scrolling underneath.
- Badge indicators display on tab icons for unread counts. Use numeric badges sparingly; a simple dot suffices for non-numeric notifications.

**Android Bottom Navigation Bar:**
- Supports 3 to 5 destinations. For fewer than 3 or more than 5, use a navigation drawer or navigation rail instead.
- Active destination uses a filled icon inside a pill-shaped indicator. Inactive destinations use outlined icons.
- Labels appear on all items by default (Material 3 recommendation). Earlier Material Design versions hid inactive labels, but research showed this harmed discoverability.
- Navigation state handling differs from iOS: Android uses a single back stack with fragment transactions. The Navigation component manages destination state, but tab state is not preserved by default without explicit implementation.
- Color derives from the dynamic color system (Material You). The active indicator color comes from the secondary container color role.

**Key difference:** iOS tabs are truly independent navigation stacks. Android bottom navigation destinations share a more interconnected navigation graph. Design information architecture accordingly — iOS tolerates deeper per-tab hierarchies, while Android favors flatter navigation with cross-destination relationships.

### Navigation Bar / Top App Bar

**iOS Navigation Bar:**
- Contains a back button (chevron + previous title or "Back"), an optional title (centered), and trailing action buttons.
- Large title style collapses to inline on scroll, providing a distinctive iOS feel. Use large titles for top-level views, inline titles for detail views.
- Back button behavior is system-managed. The swipe-from-left-edge gesture to go back is a platform expectation — never disable it.
- Supports search bar integration that reveals on pull-down in large title mode.

**Android Top App Bar:**
- Four variants: center-aligned, small, medium, large. Medium and large collapse on scroll similar to iOS large titles.
- Navigation icon (hamburger menu or back arrow) sits in the leading position. Title is left-aligned by default (center-aligned variant available but less common).
- Action buttons (up to 3 visible) sit in the trailing position. Overflow menu (three-dot icon) collects additional actions.
- The top app bar integrates with the CoordinatorLayout for scroll behaviors: scroll off screen, snap, pin in place, or collapse to a condensed form.

### Back Behavior

**iOS:**
- Back navigation is hierarchical and predictable: the back button in the navigation bar and the swipe-from-left-edge gesture both pop the current view from the navigation stack.
- There is no system-wide back gesture beyond the navigation stack context. Modals and sheets are dismissed by swipe-down or explicit close buttons.
- Provide a clear visual back affordance on every pushed view.

**Android:**
- The system back button (gesture or on-screen button) handles all back navigation: popping views, closing dialogs, dismissing bottom sheets, collapsing expanded elements.
- Predictive back (introduced in Android 13, expanded in 14+) shows a preview of the destination before completing the back action. Support this by implementing the predictive back API.
- Back behavior is more complex: it can mean "up" in the hierarchy, "close" for overlays, or "exit" from the app. Define the back behavior explicitly for every screen and overlay state.
- Deep-linked destinations must construct a proper back stack so the system back button navigates logically even when the user entered mid-hierarchy.

---

## Sheet and Overlay Patterns

### iOS Sheet Presentations vs Android Bottom Sheets

**iOS Sheets:**
- Sheet presentation is the primary modal pattern in modern iOS. Sheets slide up from the bottom, covering most of the screen but leaving the parent view visible behind and above.
- Detents control sheet height: `.medium` (half screen) and `.large` (full screen) are system-provided. Custom detents allow precise height control.
- Sheets support interactive dismissal via swipe-down. Protect against accidental dismissal of forms with unsaved data using `isModalInPresentation`.
- The grabber handle at the top signals draggability. Include it for all resizable sheets.
- Sheets can be non-modal — the user interacts with the parent view while the sheet remains at a medium detent (map applications demonstrate this pattern).

**Android Bottom Sheets:**
- Two types: standard (embedded in the layout, coexists with other content) and modal (overlay with scrim behind).
- Standard bottom sheets have multiple states: collapsed (peek height), half-expanded, expanded. Use `BottomSheetBehavior` to manage state transitions.
- Modal bottom sheets use `ModalBottomSheet` (Compose) or `BottomSheetDialogFragment`. They display a scrim overlay and dismiss on outside tap or swipe-down.
- Bottom sheets integrate with the back gesture — system back collapses or dismisses the sheet.
- Drag handle at the top serves the same purpose as the iOS grabber. Material 3 standardizes the drag handle component.

**Design implication:** iOS sheets have become the default presentation style, replacing many full-screen modals. Android bottom sheets serve a similar role but coexist with dialogs and full-screen destinations. Choose the overlay type based on content complexity: simple choices use a dialog (Android) or action sheet (iOS), moderate content uses a bottom sheet, complex flows use a full-screen presentation.

### iOS Segmented Controls vs Android Tabs

**iOS Segmented Controls:**
- A horizontal strip of 2-5 mutually exclusive options. Selecting one deselects the others.
- Use for filtering or switching views within a single context (e.g., "Day / Week / Month" in a calendar).
- Sizing is compact — segmented controls fit within navigation bars or toolbars.
- Do not use for navigation between different content areas; use tabs (via tab bar) for that purpose.

**Android Tabs:**
- Horizontal row of text (and optionally icon) labels. Supports scrollable tabs for many items or fixed tabs for 2-4 items.
- Primary tabs sit directly below the top app bar for top-level content switching. Secondary tabs handle sub-categories within a primary tab.
- Tabs pair with ViewPager/HorizontalPager for swipeable content. Provide both tap and swipe to switch between tabs.
- Material 3 tabs use a bottom indicator line for the active tab. Secondary tabs use a full-width background indicator.

**Design implication:** These components serve overlapping but distinct roles. iOS segmented controls are compact filters; Android tabs are a broader content-switching mechanism. When designing cross-platform, map iOS segmented controls to Android tabs or chips depending on the use case.

---

## Contextual Action Patterns

### Action Sheets (iOS) vs Bottom Sheets for Actions (Android)

**iOS Action Sheets:**
- Present a list of actions related to the current context. Slide up from the bottom on iPhone, appear as a popover on iPad.
- Include a cancel button that dismisses the sheet. Destructive actions display in red.
- Maximum of roughly 8-10 actions before scrolling becomes necessary. If more are needed, reconsider the information architecture.
- Action sheets interrupt the user's flow — use them only when a decision is required before proceeding.

**Android:**
- Contextual actions typically appear in a modal bottom sheet, a menu, or a dialog.
- Bottom sheet menus present a vertical list of actions with icons. They accommodate more actions gracefully through scrolling.
- Alternatively, use a dropdown menu anchored to the triggering element for fewer actions (3-6).
- Destructive actions are not color-coded by default. Use explicit warning text or a confirmation dialog for irreversible operations.

### Context Menus and Long Press

**iOS Context Menus:**
- Triggered by long press (and previously 3D Touch / Haptic Touch). The source element scales up with a blur behind it, presenting a preview and action list.
- Context menus provide quick actions without navigating away from the current screen. The preview allows "peeking" at content.
- Actions in context menus can include SF Symbol icons. Group related actions with separators.
- Context menus work on virtually any element — list rows, collection cells, buttons, images.
- Always provide an alternative path to the same actions for accessibility. Context menus are a shortcut, not the only path.

**Android Long Press / Contextual Menus:**
- Long press traditionally triggers a contextual action mode (action bar at top with contextual actions) for multi-select scenarios.
- For single-item actions, a popup menu anchored to the item serves the context menu role.
- Android does not have the iOS-style preview interaction. Long press feedback is typically a ripple effect and haptic vibration.
- Tooltips appear on long press of icon buttons (showing the button's label), which is a distinct behavior from contextual actions.

---

## Search Patterns

**iOS Search:**
- The search bar integrates into the navigation bar. In large title mode, pulling down reveals the search field. Tapping it presents a search experience overlaying the current content.
- Search suggestions appear immediately. Recent searches display by default. Scope bars (segmented control below search) allow filtering by category.
- The search controller manages the search presentation lifecycle including the cancel button appearance and keyboard management.
- Search tokens (pill-shaped filters) combine structured filters with free-text search.

**Android Search:**
- Material 3 introduces the Search Bar and Search View pattern. The search bar sits at the top of the screen, expanding into a full search view on tap.
- Alternatively, the top app bar can transform into a search field using the search icon action.
- Search suggestions and recent searches display in the expanded search view. Filter chips below the search field enable structured filtering.
- Voice search integration is common on Android due to Google Assistant integration.

---

## Settings Patterns

**iOS Settings Style:**
- Grouped table view with inset grouped style: rounded-corner sections separated by headers and footers.
- Toggle switches for on/off preferences. Navigation rows with disclosure indicators for sub-screens.
- The Settings app itself sets the standard. Third-party apps replicate this structure for in-app settings.
- Destructive settings (sign out, delete account) appear at the bottom in a separate section with red text.

**Android Preferences:**
- Material 3 preferences use a full-width list with section headers. Switch toggles for boolean settings.
- PreferenceScreen and PreferenceFragment provide a framework for building hierarchical settings.
- Settings categories use text dividers rather than the grouped card style of iOS.
- The "About" or "Info" section appears at the bottom. Account management and sign-out sit prominently but with confirmation dialogs.

---

## Notification and Alert Patterns

**iOS:**
- Alerts are centered modal dialogs with a title, optional message, and 1-3 buttons. Two-button alerts place the default action on the right (bold). Destructive actions use red text.
- Do not overuse alerts — they interrupt the user completely. Use in-line messaging or banners for non-critical information.
- Push notifications use the standard notification center. Rich notifications can include images, action buttons, and live activities.
- The Dynamic Island displays ongoing activities and compact notifications for supported apps.

**Android:**
- Material 3 dialogs are centered modals similar to iOS alerts. They support a title, body text, and up to 3 text buttons (negative, positive, neutral).
- Snackbars provide brief, non-modal feedback at the bottom of the screen. They can include a single action (e.g., "Undo"). This pattern has no direct iOS equivalent.
- Toast messages show ephemeral, non-interactive feedback. Use sparingly — snackbars are preferred because they support actions.
- Push notifications support rich media, action buttons, and notification channels for user-controlled categorization.

---

## Onboarding Patterns

**iOS:**
- Full-screen welcome pages with large illustrations, concise text, and "Continue" buttons. The standard pattern uses 3-4 screens maximum.
- The "What's New" sheet appears on app updates to highlight new features. Use SF Symbols and short bullet points.
- Avoid mandatory onboarding for returning users. Offer a "Skip" option on every screen.
- Request permissions during onboarding only if the app cannot function without them. Defer optional permissions to contextual moments.

**Android:**
- Step indicators (dots or progress bar) at the bottom of onboarding screens provide clear progress feedback.
- Onboarding uses a ViewPager/HorizontalPager with swipe navigation between steps.
- Material Design recommends onboarding only when the value is not self-evident. Self-evident apps should skip onboarding entirely.
- The "Get Started" button replaces the paging controls on the final screen.

---

## Permission Request Patterns

**iOS:**
- The system permission dialog appears once per permission per app lifetime. Once the user denies, the app cannot re-prompt — it must direct the user to Settings.
- This one-shot nature demands strategic timing: request permissions at the moment the user performs an action that requires them (just-in-time). Never request permissions on first launch.
- Pre-permission screens (custom UI explaining why the permission is needed) are critical for increasing grant rates. Show the value before triggering the system dialog.
- Permissions include: camera, microphone, location (always/when-in-use), notifications, contacts, photos (full/limited), tracking (ATT framework), health data, and Bluetooth.

**Android:**
- Permissions use a system dialog similar to iOS, but Android allows re-prompting until the user selects "Don't ask again."
- Android 13+ requires explicit notification permission requests (previously granted by default).
- The `shouldShowRequestPermissionRationale()` API indicates whether the user previously denied the permission, allowing the app to explain the need before re-requesting.
- Provide graceful degradation when permissions are denied. Never block the entire app for a single denied permission unless it is truly essential.

---

## Gesture Differences

**iOS Swipe-Back:**
- Swipe from the left edge of the screen to pop the current view. This gesture is universal across all navigation-stack-based views.
- The gesture is interruptible — the user can start swiping back, see the previous screen, and cancel by swiping forward.
- Custom view controllers that override this gesture (swipeable carousels, drawers) must handle the conflict explicitly. Disabling swipe-back is strongly discouraged.

**Android Predictive Back:**
- The system back gesture (swipe from either edge) triggers the predictive back animation: the current screen shrinks, shifts, and reveals the previous destination.
- Apps must opt in to predictive back and use the OnBackPressedCallback API. Legacy overrides of `onBackPressed()` disable the predictive animation.
- The animation provides a preview of where back will lead, reducing uncertainty.

**Reachability:**
- iOS Reachability (swipe down on the bottom edge / home indicator area) slides the entire screen contents down so the top half is reachable with one hand. Design with awareness that the top portion of the screen may be reached via Reachability.
- Android has one-handed mode (shrink the screen to a corner) on some OEM skins. Samsung, Pixel, and others implement it differently. Do not rely on this feature — design critical interactions within natural thumb reach.

---

## Typography Systems

**SF Pro (iOS):**
- Apple's system font with optical sizes: SF Pro Text (below 20pt), SF Pro Display (20pt and above). The system selects the appropriate optical size automatically.
- SF Pro Rounded offers a friendlier alternative. SF Mono handles monospaced code content.
- Dynamic Type scales text based on user accessibility settings across 12 size categories, from xSmall to AX5 (accessibility extra-extra-extra-extra-extra large). Every text element must support Dynamic Type.
- Text styles (Large Title, Title 1-3, Headline, Body, Callout, Subheadline, Footnote, Caption 1-2) define semantic roles. Use these rather than specifying raw point sizes.
- Font weight ranges from ultralight to black, with standard weight being regular for body text and semibold/bold for emphasis.

**Roboto / Material Type Scale (Android):**
- Roboto remains the default Android system font, though Material 3 supports custom typefaces more readily.
- The Material 3 type scale defines roles: Display (large/medium/small), Headline (large/medium/small), Title (large/medium/small), Body (large/medium/small), Label (large/medium/small).
- Each role specifies font family, weight, size, line height, and letter spacing.
- Android text scaling respects the system font size setting. Test at the largest system text size to ensure layouts do not break.
- Variable fonts are supported on Android 8+ (API 26+), enabling smoother weight and width transitions.

---

## Platform-Specific Components

**iOS Picker Wheels:**
- Spinning drum-style selector for values (dates, times, quantities). Placed inline or in a sheet.
- Compact date/time pickers (iOS 14+) use a condensed button that expands into a calendar or wheel on tap.
- Use pickers only when the value set is large and ordered. For small sets (under 7 items), use a segmented control or button group instead.

**Android Chips:**
- Compact, interactive elements representing attributes, actions, or filters. Types: assist, filter, input, suggestion.
- Filter chips serve the role of multi-select options. Input chips represent user-provided data (e.g., email recipients).
- Chips appear in rows and can wrap to multiple lines. They support leading icons, close buttons, and checkmarks.

**Date Pickers:**
- iOS: Compact calendar picker (grid), wheel picker (spinning drums), or inline calendar. The system handles locale-appropriate formatting.
- Android: Material 3 date picker offers a calendar view with month navigation and a text input mode. Date range selection is supported natively.
- Both platforms handle locale, calendar system, and date formatting automatically. Never build a custom date picker from scratch.

---

## Dynamic Island (iOS) Integration Patterns

- Dynamic Island surrounds the front-facing camera and proximity sensor cluster on iPhone 14 Pro and later. It displays compact and expanded Live Activities.
- Compact view: two separate leading and trailing elements flanking the sensor cluster. Minimal information — a progress indicator, timer, or status icon.
- Expanded view: on long press, the Dynamic Island expands to show richer content. Include essential controls (play/pause, end activity) and key information.
- Design Live Activities that degrade gracefully on devices without Dynamic Island (they display as a banner on the Lock Screen instead).
- Use the ActivityKit framework to manage Live Activity lifecycle. Activities have a maximum duration of 8 hours (extended to 12 hours in some cases).
- Do not abuse Live Activities for marketing or non-time-sensitive content. Apple rejects apps that misuse the feature.

---

## Material You Theming and Dynamic Color

- Material You generates a color palette from the user's wallpaper (Android 12+). The system extracts seed colors and produces tonal palettes across six key color roles: primary, secondary, tertiary, error, neutral, and neutral-variant.
- Each color role generates a 13-tone palette (0, 10, 20, 30, 40, 50, 60, 70, 80, 90, 95, 99, 100). Light and dark themes map to different tonal values within these palettes.
- Design for color flexibility. Components must remain accessible (meeting WCAG AA 4.5:1 contrast) regardless of which dynamic colors the system generates. The tonal palette system guarantees contrast mathematically.
- Custom colors can coexist with dynamic colors. Define custom color roles for brand-critical elements, mapping them to the harmonized color system so they blend with the dynamic palette.
- Implement dynamic color using `DynamicColors.applyToActivitiesIfAvailable()` in Android views or `dynamicColorScheme()` in Jetpack Compose.
- Test with multiple wallpapers — edge cases include near-white wallpapers (producing very light themes), near-black wallpapers (producing very dark themes), and highly saturated wallpapers (producing vivid palettes).

---

## Widget Design Patterns

**iOS WidgetKit:**
- Widgets are read-only, glanceable displays. They do not support interactive controls beyond tap targets that deep link into the app (iOS 17+ introduced interactive widgets with Button and Toggle).
- Available in small, medium, large, and extra-large (iPad only) sizes. Each size demands a distinct layout — never simply scale up the small widget for the large size.
- Content should be immediately useful without any user action. Show the most relevant information based on time of day, location, or user behavior.
- Use timeline providers to schedule content updates. Widgets receive a limited number of refreshes per day — optimize for meaningful update intervals.
- StandBy mode (iOS 17+) displays widgets on a bedside clock. Design for this context: larger text, reduced density, night-friendly colors.

**Android Glance (Jetpack Compose-based):**
- Glance provides a Compose-based API for building Android app widgets. Widgets support interactive elements natively (buttons, checkboxes, lists).
- Widget sizes are flexible, defined by minimum and maximum grid dimensions (cells). Users can resize widgets within this range.
- Content updates use Glance's state management or WorkManager for background updates.
- Design for the resizable nature of Android widgets: define layouts that adapt to different aspect ratios and sizes.
- Material 3 widget guidance recommends using the dynamic color system, rounded corners matching the system widget radius, and clear content hierarchy.

---

## Share Sheet and Inter-App Communication

**iOS Share Sheet:**
- `UIActivityViewController` presents the system share sheet with a standardized layout: a preview of the shared content, frequent contacts (AirDrop, Messages), a scrollable row of app share targets, and a scrollable list of actions (Copy, Print, Add to Reading List, etc.).
- Apps can provide share extensions that appear in other apps' share sheets. Design share extensions to complete quickly — they run in a limited memory environment.
- App Shortcuts and Siri integration allow the app to suggest actions in Spotlight and the share sheet.
- Universal Links enable deep linking from shared URLs directly into the app.

**Android Share Sheet / Sharesheet:**
- `Intent.createChooser()` displays the system share sheet. Android's share sheet includes Direct Share targets (specific contacts or conversations), app targets, and custom actions.
- Apps receive shared content via intent filters declared in the manifest. Design the receiving flow to handle shared content gracefully — validate the data type and size.
- The Sharesheet API supports rich previews (title, image, content type) for the shared content.
- Android App Links (verified deep links) complement sharing by resolving shared URLs to specific app destinations.

**Cross-platform implication:** Both platforms have rich but divergent sharing APIs. Abstract the sharing layer in cross-platform apps, presenting each platform's native share sheet rather than building a custom one.

---

## Cross-Platform Frameworks: Respecting Platform Conventions

### React Native

- Use platform-specific components where they exist: `SegmentedControlIOS`, platform-aware navigation libraries (React Navigation's native stack).
- React Navigation supports platform-adaptive headers, tab bars, and transition animations. Enable `headerLargeTitle` on iOS and platform-appropriate back button rendering.
- File extensions (`.ios.js`, `.android.js`) or the `Platform.select()` API enable per-platform component variants.
- Do not use a single custom navigation pattern on both platforms. iOS users expect stack-based swipe-back; Android users expect the system back gesture.
- Typography should use the system font on each platform by default. Specify `fontFamily: 'System'` or use `Platform.select()` for platform-specific typeface stacks.

### Flutter

- Flutter provides Material and Cupertino widget libraries. Use `CupertinoApp` and `CupertinoPageRoute` for iOS-style navigation, `MaterialApp` and `MaterialPageRoute` for Android.
- The `platform_adaptive` pattern checks `Theme.of(context).platform` to render platform-appropriate components.
- Flutter's `CupertinoNavigationBar` replicates iOS navigation bars with large titles. `CupertinoTabScaffold` provides iOS-style tab bar navigation. Use these on iOS instead of Material `AppBar` and `BottomNavigationBar`.
- The `flutter_adaptive_scaffold` package provides responsive and platform-adaptive layout primitives.
- Gesture handling: on iOS, use `CupertinoPageRoute` for automatic swipe-back support. On Android, ensure the `WillPopScope` / `PopScope` widget integrates with the predictive back API.

### Kotlin Multiplatform (KMP) / Compose Multiplatform

- KMP shares business logic while allowing platform-native UI. Compose Multiplatform extends this to shared UI code with platform-specific adaptations.
- On Android, Compose Multiplatform uses Jetpack Compose directly — full Material 3 support is automatic.
- On iOS, Compose Multiplatform renders via Skia. The rendering is pixel-accurate but does not inherit iOS system conventions automatically. Apply Cupertino-style theming and navigation patterns explicitly.
- Evaluate whether shared UI provides sufficient platform fidelity. For apps where native feel is paramount, share only business logic and implement UI natively per platform.

---

## Summary: Decision Framework

| Decision | iOS Approach | Android Approach |
|---|---|---|
| Primary navigation | Tab bar (bottom, 5 max) | Bottom navigation (3-5) or nav drawer (5+) |
| Secondary navigation | Push navigation with swipe-back | Push navigation with system back |
| Contextual actions | Action sheet or context menu | Bottom sheet menu or popup menu |
| Brief feedback | None (use inline status) | Snackbar with optional action |
| Filters within a view | Segmented control | Tabs or filter chips |
| Date/time input | Compact picker (calendar/wheel) | Material date/time picker |
| Settings layout | Inset grouped table view | Full-width preference list |
| Permission strategy | One-shot with pre-permission screen | Contextual with rationale API |
| Theming | Light/dark with accent color | Material You dynamic color |
| Widget interaction | Limited (iOS 17+ adds Button/Toggle) | Fully interactive |

Design each platform as a first-class citizen. The best cross-platform apps feel native everywhere, not custom everywhere.

---

## iOS 26 Liquid Glass & Material 3 Expressive Updates

### iOS 26: Liquid Glass Design Language

Apple's iOS 26 (announced WWDC 2025) introduces Liquid Glass as the foundational visual paradigm across the entire system. This is the most significant visual redesign since iOS 7's shift to flat design, and it fundamentally changes how navigation bars, tab bars, toolbars, and sidebars render.

**Glass as the Default Material.** All standard UIKit and SwiftUI navigation chrome now uses glass by default. Navigation bars, tab bars, toolbars, and sidebars render as translucent, light-refracting surfaces that reveal the content behind them while maintaining legibility. This is not optional styling — it is the system default, and apps that do not account for it will look inconsistent with the rest of the OS.

**The `.glassEffect()` Modifier.** SwiftUI introduces the `.glassEffect()` modifier to apply glass material to custom views. This enables designers and developers to extend the glass language beyond system chrome into custom UI elements — cards, floating panels, action buttons, and overlay surfaces. The modifier handles light refraction, specular highlights, and background sampling automatically, adapting to the content behind the glass surface in real time.

**System Vibrancy for Text on Glass.** Text rendered on glass surfaces must use system vibrancy to remain legible. Vibrancy dynamically adjusts text color and weight based on the background content visible through the glass. Use `primaryVibrancy`, `secondaryVibrancy`, and `tertiaryVibrancy` hierarchies for text on glass. Hard-coded text colors will appear washed out or illegible on glass surfaces.

**Accessibility: `accessibilityReduceTransparency`.** When a user enables Reduce Transparency in accessibility settings, glass effects must degrade to solid, opaque surfaces. Always check and respect `UIAccessibility.isReduceTransparencyEnabled` (UIKit) or the `accessibilityReduceTransparency` environment value (SwiftUI). Apps that ignore this setting will fail accessibility review. Design glass layouts with a fallback opaque state that maintains the same spatial relationships and information hierarchy.

**Depth and Layering.** Liquid Glass introduces a formal depth model where glass surfaces exist at different Z-planes. System navigation bars sit at one depth, floating elements at another, and content at the base layer. Each depth level applies different levels of refraction and blur, creating a natural sense of spatial hierarchy without relying on drop shadows.

### Material 3 Expressive: Spring Motion and New Components

Google's Material 3 Expressive update (2025-2026) represents a parallel but philosophically different evolution. Where Apple moves toward materiality (glass, light, refraction), Google moves toward expression through spring-based physics and exuberant component design.

**Spring-Based Motion System.** M3 Expressive replaces duration-based animation curves with spring physics as the default motion model. The default spring configuration uses stiffness 380 and damping ratio 0.7, producing responsive motion with a subtle organic settle. This is a fundamental shift: instead of specifying "animate over 300ms with ease-out," designers specify physical properties that produce natural-feeling motion with inherent interruptibility.

**Morphing FAB (Floating Action Button).** The FAB now morphs fluidly between states — from a compact circle to an extended label, from a resting position to an expanded action menu. The morphing animation uses the spring system, and the FAB can transform into a bottom sheet or a full-screen creation surface. This replaces the previous expand-from-center pattern.

**Expressive Navigation Bar Indicator.** The bottom navigation bar's active destination indicator evolves from a static pill shape to an animated, spring-driven indicator that morphs and bounces between destinations. The indicator stretches, contracts, and settles with visible spring physics, adding personality to navigation transitions. The animation parameters (stiffness 380, dampingRatio 0.7) keep the motion responsive without feeling slow.

**Carousel Component.** M3 Expressive introduces a new Carousel component for horizontally scrollable content. The carousel supports hero (single large item), multi-browse (multiple visible items), and contained (fixed-width items) layouts. Items scale, fade, and snap with spring-driven physics as the user scrolls.

### Platform Divergence: Glass vs Expression

The 2025-2026 update cycle reveals a fascinating divergence in platform philosophy:

- **Apple** moves toward physical materiality — glass, refraction, light response, and depth. The interaction model becomes more grounded in optical physics.
- **Google** moves toward emotional expression — spring physics, morphing shapes, animated indicators, and exuberant motion. The interaction model becomes more grounded in mechanical physics.

For cross-platform teams, this divergence demands a design strategy that embraces platform-native patterns rather than forcing convergence. A cross-platform app should use glass materials and vibrancy on iOS while using spring-driven motion and expressive indicators on Android. Attempting to implement glass effects on Android or spring FABs on iOS produces an uncanny experience that feels native to neither platform.

The shared ground between platforms: both now favor physics-based systems (optical physics on iOS, mechanical physics on Android) over arbitrary timing curves. Both prioritize adaptive, responsive interfaces that react to user input and environmental context. Design systems serving both platforms should define shared semantic intent (e.g., "navigation feedback," "surface hierarchy") while allowing platform-specific implementation.

> For the complete deep-dive on implementation specifics, glass modifier API details, spring parameter tuning, and cross-platform bridging strategies, see `ios26-liquid-glass-material3-expressive.md`.

---

## Key Sources

- Apple Human Interface Guidelines (2025, updated for iOS 26)
- Apple Developer — Liquid Glass and `.glassEffect()` documentation (WWDC 2025)
- Google Material Design 3 Expressive Guidelines (2025-2026)
- Google Material Design 3 Guidelines (2025)
- Android Developers — Predictive Back Gesture documentation
- Apple Developer — ActivityKit and Live Activities documentation
- Material You — Dynamic Color system technical documentation
- React Navigation documentation — Platform-specific behaviors
- Flutter documentation — Platform adaptations
- Hoober, S. (2017). "Design for Fingers, Touch, and People"
