# iOS 26 Liquid Glass & Material 3 Expressive — Platform Design Languages 2025-2026

The two dominant mobile platforms diverged sharply in 2025-2026. Apple introduced Liquid Glass with iOS 26 at WWDC25 — a translucent, light-refracting material system that replaces flat opaque chrome with depth-aware surfaces. Google countered at I/O 2025 with Material 3 Expressive — an evolution of Material Design that layers spring-based motion, morphing shapes, and emotional color onto its component library. Both represent the most significant visual language shifts since iOS 7's flat redesign and Material Design's original 2014 launch. Understanding each system in depth is essential for any designer or developer building native mobile experiences.

---

## iOS 26 Liquid Glass Design Language

### What Liquid Glass Is

Liquid Glass is Apple's new design material introduced in iOS 26 (announced WWDC 2025). It replaces the flat, frosted-blur backgrounds that have defined iOS chrome since iOS 7 with a physically modeled translucent surface that dynamically refracts, reflects, and tints based on the content beneath it. Think of it as a pane of tinted, curved glass sitting above your interface — light passes through it, colors bleed into it, and specular highlights dance across its surface as you scroll or tilt the device.

The system applies Liquid Glass to all standard navigation chrome by default: navigation bars, tab bars, toolbars, sidebars, and segmented controls. When you build a new iOS 26 app using SwiftUI or update an existing UIKit app, these system-provided elements automatically render with the glass material. This is not an opt-in effect — it is the new baseline. Apps that do nothing will get glass chrome for free. Apps that have heavily customized their chrome will need to audit and adapt.

Liquid Glass is not purely cosmetic. It establishes a spatial hierarchy: glass surfaces sit at a defined elevation above the content layer. The refraction effect communicates this depth without relying on drop shadows (which Apple has steadily de-emphasized). The result is an interface that feels more physical and dimensional while maintaining the clean, content-forward ethos Apple has championed.

### Core Visual Properties

**Translucency.** Liquid Glass surfaces are not opaque and not merely blurred. They transmit a filtered version of the content beneath them. The transmission is non-uniform — edges refract more than the center, mimicking the optical behavior of a curved glass pane. This creates a subtle lens-like distortion at the periphery of glass elements.

**Dynamic tinting.** The glass material continuously samples colors from the content it overlays and integrates those colors into its own appearance. A glass tab bar sitting above a blue photograph takes on a cool blue tint. The same tab bar above an orange sunset scene shifts warm. This sampling happens in real time as the user scrolls, creating a living, responsive chrome layer. The tinting algorithm applies perceptual color science to avoid garish results — it desaturates sampled colors and biases toward the system accent color to maintain coherence.

**Specular highlights.** Apple applies a simulated light source that produces highlights along the edges and top surface of glass elements. These highlights respond to device orientation data (gyroscope/accelerometer), creating parallax-like movement when the user tilts their device. The highlights reinforce the illusion that the surface is a real, three-dimensional material.

**Depth layering.** Glass elements exist at explicit depth planes. A navigation bar is one layer, a floating action card is another, and a modal sheet is another still. Each layer exhibits progressively stronger glass effects — deeper blur, more pronounced refraction — communicating the stacking order visually. This replaces the elevation-shadow model used in previous iOS releases and in Material Design.

**Edge treatment.** Glass surfaces feature subtle, luminous borders that define their boundaries. These borders are semi-transparent and pick up ambient color, appearing almost as thin caustic lines. They help the eye parse where one glass surface ends and another begins, which is critical because the translucent nature of the material can otherwise cause surfaces to visually merge.

### Key APIs

SwiftUI provides the primary API surface for Liquid Glass in iOS 26.

**`.glassEffect(.regular)`** — The fundamental modifier. Apply it to any SwiftUI view to render that view with the standard Liquid Glass material. The `.regular` variant produces the default system glass appearance. A `.clear` variant is available for lighter-weight glass with less tinting and blur.

```swift
struct GlassCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Now Playing")
                .font(.headline)
            Text("Artist — Track Title")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding()
        .glassEffect(.regular)
    }
}
```

**`GlassEffectContainer`** — A container view that establishes a glass rendering context. When multiple glass elements need to coexist and composite correctly (avoiding double-blur artifacts), wrap them in a `GlassEffectContainer`. The container ensures that overlapping glass surfaces blend properly rather than stacking blur upon blur.

```swift
GlassEffectContainer {
    VStack {
        HeaderBar()
            .glassEffect(.regular)
        ContentArea()
        TabBar()
            .glassEffect(.regular)
    }
}
```

**`ToolbarGlassEffect`** — A specialized modifier for toolbar items that opts them into the glass material. This is primarily useful when building custom toolbars that should match the system appearance without manually applying `.glassEffect`.

```swift
.toolbar {
    ToolbarItem(placement: .bottomBar) {
        HStack {
            Button("Action") { }
            Spacer()
            Button("More") { }
        }
    }
}
.toolbarGlassEffect(.regular)
```

**UIKit support.** For UIKit-based apps, `UIGlassEffect` is available as a `UIVisualEffect` subclass that can be applied via `UIVisualEffectView`. The `UINavigationBarAppearance` and `UITabBarAppearance` classes gain new `.glassEffect` configuration properties. However, Apple's direction is clear: SwiftUI is the first-class citizen for Liquid Glass, and UIKit support is a compatibility bridge.

```swift
let glassView = UIVisualEffectView(effect: UIGlassEffect())
glassView.frame = containerView.bounds
containerView.addSubview(glassView)
```

### System Adoption

In iOS 26, the following system elements use Liquid Glass by default with no developer action required:

- **Navigation bars** — Both large-title and inline-title navigation bars render with glass. The large title collapses into a glass inline bar on scroll, and the transition animates the glass properties smoothly.
- **Tab bars** — The bottom tab bar is glass. Selected and unselected icons render with vibrancy effects that ensure legibility against the dynamic glass background.
- **Toolbars** — Bottom toolbars and keyboard accessories adopt glass.
- **Sidebars** — On iPad and in split-view layouts, the sidebar column uses glass, allowing the detail content to bleed through faintly.
- **Segmented controls** — The segmented control background uses a glass material, with the selected segment rendered as a brighter, more opaque glass pill.
- **Search bars** — The search field embedded in navigation bars uses a glass material for its background.
- **Menus and popovers** — Context menus, pull-down menus, and popovers use glass materials with enhanced depth.

### Typography and Contrast

Placing text on a dynamic, color-shifting background is a readability challenge. Apple addresses this through the **vibrancy system**. When text is placed inside a glass effect view, the system automatically applies vibrancy — a compositing mode that adjusts the text's color and brightness to maintain contrast against whatever background is currently visible through the glass.

The vibrancy system operates in several modes: `.primary` for maximum contrast (used for titles and body text), `.secondary` for medium contrast (used for supplementary labels), and `.tertiary` for subtle text (used for placeholders and less critical information). These are not fixed colors — they are dynamic rendering modes that respond to the glass background in real time.

Developers should use SwiftUI's semantic foreground styles (`.primary`, `.secondary`, `.tertiary`) rather than hardcoded colors. These styles automatically adapt to the glass context. Hardcoded colors — `Color.white`, `Color.black`, or custom hex values — will not adapt and may become unreadable over certain backgrounds.

```swift
// Correct: semantic styles adapt to glass
Text("Title").foregroundStyle(.primary)
Text("Subtitle").foregroundStyle(.secondary)

// Incorrect: hardcoded colors do not adapt
Text("Title").foregroundColor(.white) // may fail on light glass
```

### Custom Implementation Patterns

**Glass cards.** Creating card-style UI elements with glass:

```swift
struct GlassInfoCard: View {
    let title: String
    let description: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: "info.circle")
                .font(.headline)
            Text(description)
                .font(.body)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular)
    }
}
```

**Glass buttons.** Interactive glass elements should include a visible border to communicate tappability:

```swift
struct GlassButton: View {
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.body.weight(.semibold))
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
        }
        .glassEffect(.regular)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(.white.opacity(0.3), lineWidth: 1)
        )
    }
}
```

**Glass overlays.** Full-screen or partial overlays that use glass to maintain spatial context:

```swift
struct GlassOverlay<Content: View>: View {
    @Binding var isPresented: Bool
    @ViewBuilder let content: Content

    var body: some View {
        if isPresented {
            ZStack {
                Color.black.opacity(0.2)
                    .ignoresSafeArea()
                    .onTapGesture { isPresented = false }

                VStack(spacing: 16) {
                    content
                }
                .padding(24)
                .glassEffect(.regular)
                .padding(.horizontal, 32)
            }
            .transition(.opacity.combined(with: .scale(scale: 0.95)))
        }
    }
}
```

### Fallback Patterns for Earlier iOS Versions

Apps that support iOS 25 and earlier must conditionally apply glass effects. Use `#available` checks:

```swift
struct AdaptiveChromeView: View {
    var body: some View {
        VStack {
            Text("Content")
                .padding()
        }
        .background {
            if #available(iOS 26, *) {
                Color.clear.glassEffect(.regular)
            } else {
                // Fallback: standard material
                Rectangle()
                    .fill(.ultraThinMaterial)
            }
        }
    }
}
```

For UIKit:

```swift
func makeChromeBackground() -> UIView {
    if #available(iOS 26, *) {
        return UIVisualEffectView(effect: UIGlassEffect())
    } else {
        let blur = UIBlurEffect(style: .systemThinMaterial)
        return UIVisualEffectView(effect: blur)
    }
}
```

The `.ultraThinMaterial` and `.thinMaterial` SwiftUI materials provide the closest visual approximation to Liquid Glass on older systems. They lack the refraction and dynamic tinting but maintain translucency.

### Usability Concerns and NNGroup Critique

Nielsen Norman Group published analysis of the Liquid Glass redesign raising several evidence-based concerns that designers must take seriously (see nngroup.com for the full iOS 26 analysis):

**Reduced contrast.** Glass surfaces dynamically shift in lightness and hue depending on background content. Text and icons placed on these surfaces can fall below WCAG AA contrast ratios (4.5:1 for normal text, 3:1 for large text) when the background happens to be close in luminance to the foreground. Apple's vibrancy system mitigates this but does not guarantee compliance under all conditions. NNGroup's testing found specific scenarios — light text over a pale sky photograph, dark text over a dark map region — where contrast dropped below usable thresholds.

**Legibility challenges.** Even when technical contrast ratios are met, the visual noise introduced by a shifting, refracting background beneath text degrades reading speed and increases cognitive load. Users must distinguish text from the moving, colored content visible through the glass. This is particularly problematic for older users, users with low vision, and anyone reading in bright outdoor lighting conditions.

**Touch target ambiguity.** Liquid Glass elements have soft, luminous edges rather than hard boundaries. This can reduce the perceived clickable area of interactive elements. Users may be uncertain where a glass button begins and ends, leading to mistaps. NNGroup's analysis suggests that the visual softness of glass makes elements feel more decorative and less interactive than their opaque predecessors.

**Information hierarchy disruption.** When both chrome and content use translucent materials, the visual hierarchy can flatten. Users rely on opacity and contrast differences to distinguish interactive controls from passive content. Glass-on-glass layouts risk creating an undifferentiated visual field where everything blurs together.

### Accessibility Considerations

**Respect `accessibilityReduceTransparency`.** When the user enables "Reduce Transparency" in iOS Settings (Settings > Accessibility > Display & Text Size > Reduce Transparency), all glass effects must fall back to fully opaque surfaces. SwiftUI handles this automatically for system controls, but custom glass implementations must check this setting:

```swift
@Environment(\.accessibilityReduceTransparency) var reduceTransparency

var body: some View {
    content
        .background {
            if reduceTransparency {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemBackground))
            } else {
                Color.clear.glassEffect(.regular)
            }
        }
}
```

**Worst-case contrast testing.** Test glass text against the lightest and darkest backgrounds that could plausibly appear beneath it. Take screenshots with varied content scrolled behind glass elements and measure contrast ratios. Do not assume the vibrancy system will always save you — verify empirically.

**Borders on interactive elements.** Add subtle stroke borders to all tappable glass elements. This provides a clear visual boundary that communicates interactivity even when the glass material blends with the background. The border should be semi-transparent white or system-color to harmonize with the glass aesthetic.

**Increase Contrast mode.** When the user enables "Increase Contrast" (Settings > Accessibility > Display & Text Size > Increase Contrast), glass surfaces should become more opaque, borders should become more prominent, and text should switch to higher-weight vibrancy. Test your app with this setting enabled.

**VoiceOver and glass.** Glass effects are purely visual and have no impact on the VoiceOver accessibility tree. Ensure all glass elements have proper accessibility labels, traits, and actions regardless of their visual treatment.

### Design Migration Guide

**Adopt glass for:**
- Navigation chrome (navigation bars, tab bars, toolbars, sidebars) — this happens automatically for system elements
- Floating controls and FAB-style buttons that hover above content
- Card elements that overlay media or maps
- Overlay sheets and popovers
- Segmented controls and picker surfaces

**Keep opaque for:**
- Primary content areas (text articles, feeds, lists of data) — reading surfaces must not have shifting backgrounds
- Data-heavy views (tables, spreadsheets, dashboards) — the visual noise of glass degrades scanability
- Text input fields — while the field container can be glass, the actual text editing area should have a stable background
- Onboarding and tutorial screens — when teaching users, clarity trumps aesthetic
- Accessibility-critical interfaces (medical, financial, emergency) — use glass only for non-critical chrome, never for content that must be parsed quickly and accurately

**Migration steps for existing iOS apps:**
1. Build against the iOS 26 SDK. System bars will automatically adopt glass.
2. Audit custom navigation and toolbar implementations. Replace custom backgrounds with `.glassEffect(.regular)` or allow the system default.
3. Remove hardcoded foreground colors on text placed over chrome. Switch to semantic `.foregroundStyle(.primary)` / `.secondary`.
4. Test with Reduce Transparency enabled. Provide opaque fallbacks for all custom glass views.
5. Test with Increase Contrast enabled. Verify all interactive elements remain clearly distinguishable.
6. Test with Dynamic Type at the largest accessibility sizes. Glass text at XXL sizes must remain legible.
7. Profile performance on the oldest supported device. Glass effects involve real-time compositing that can impact frame rate on older hardware.

---

## Material 3 Expressive

### What M3 Expressive Is

Material 3 Expressive is Google's evolution of Material Design 3, announced at Google I/O 2025 and shipping with Android 16. It represents a philosophical shift: where Material Design has historically emphasized structure, consistency, and systematic restraint, M3 Expressive encourages emotional resonance, personality, and dynamic visual behavior. Google's design team describes it as making interfaces "feel alive."

The core changes fall into three categories: **spring-based motion** (replacing duration-and-easing curves with physics-based spring animations), **shape morphing** (components that transition fluidly between shape states), and **expressive color** (richer tonal palettes with more emotional range). These are not merely cosmetic updates — they require new implementation patterns and a different mental model for how components behave.

M3 Expressive is backward-compatible with Material 3. Existing M3 apps will not break. The new components and behaviors are additive. However, to achieve the expressive look and feel, developers must opt into the new component variants, spring motion specs, and shape tokens. It is an evolution, not a replacement, but the visual difference between an M3 app and an M3 Expressive app is immediately apparent.

### New and Updated Components

M3 Expressive introduces 15 new or substantially updated components. The most significant:

**Floating Action Button (morphing shapes).** The FAB is no longer a static circle or rounded rectangle. In M3 Expressive, the FAB can morph between shape states — circle when idle, rounded rectangle when hovered or focused, pill shape when expanded to show a label. The morphing uses spring animation and feels organic. The FAB also supports a new "large" variant that occupies more screen real estate for primary actions.

**Bottom App Bar (expanded).** The bottom app bar gains an expressive layout mode where it can expand vertically to reveal additional actions or contextual content. The expansion uses spring physics and supports gesture-driven interaction (swipe up to expand, swipe down to collapse).

**Navigation Rail (expressive icons).** The navigation rail — used on tablets and large-screen devices — now supports animated icon transitions. When a destination becomes active, the icon can scale, morph shape, or play a brief spring animation. The active indicator uses the new expressive shape tokens.

**Navigation Bar (spring selection).** The bottom navigation bar's active indicator now animates between destinations using a spring curve rather than a hard cut or linear interpolation. The indicator pill slides, stretches, and settles with a bounce, creating a tactile feel.

**Segmented Button (spring animation).** The selected state indicator in segmented buttons transitions with spring physics. The indicator pill stretches to cover the new selection and then contracts to its resting size, creating a fluid, elastic motion.

**Carousel.** A new first-class carousel component for scrolling through visual content. Supports peek (next item partially visible), hero (one large item with small flanking items), and full-screen variants. Items can have varying sizes and the scroll physics use spring-based settling.

**Date and Time Pickers (refined).** Updated with new expressive shapes, spring-animated selection indicators, and improved touch targets. The date picker calendar view uses spring motion for month transitions.

**Chips (expressive states).** Chips gain richer state transitions — selection animates with a spring scale effect, and chip groups can reflow with spring-based layout animation when chips are added or removed.

**Progress Indicators (spring motion).** Linear and circular progress indicators gain spring-based animation for determinate progress updates. Rather than linearly interpolating to the new value, the indicator springs to it with overshoot and settle, communicating energy and momentum.

**Search (expanded).** The search component supports a new expanded mode where it transitions from a search bar to a full-screen search experience with spring animation. The expansion feels like the search field is physically growing to fill the screen.

**Top App Bar (expressive scroll).** The top app bar's collapse-on-scroll behavior now uses spring physics. When the user stops scrolling mid-collapse, the bar springs to either its expanded or collapsed state rather than snapping.

**Buttons (shape expression).** All button variants (filled, outlined, tonal, text, elevated) gain subtle shape animation on press. The button's corner radius can increase slightly on press, creating a "squish" effect that communicates tactile feedback.

**Icon Buttons (animated emphasis).** Icon buttons support a spring scale animation on tap that provides visual feedback beyond the ripple effect.

**Dialogs (spring entry).** Dialogs now enter and exit with spring-based scale and fade animations rather than the previous linear fade.

**Bottom Sheets (spring settle).** Bottom sheets use spring physics for their drag-and-settle behavior. When released mid-drag, the sheet springs to the nearest snap point with natural overshoot.

### Spring-Based Motion Model

The most fundamental technical change in M3 Expressive is the shift from **duration-based easing** to **spring-based physics** for animation.

In traditional animation (and in Material Design through M3), motion is defined by a duration (e.g., 300ms) and an easing curve (e.g., ease-in-out). The animation always takes exactly the specified duration. If interrupted mid-flight, restarting the animation can cause velocity discontinuities (visual stutters).

Spring-based animation models motion as a mass attached to a spring. The parameters are:

- **Stiffness** — How strong the spring is. Higher stiffness means faster animation. Measured in N/m conceptually, but in practice specified as a dimensionless constant.
- **Damping ratio** — How quickly oscillation dies out. A ratio of 1.0 is critically damped (no bounce, fastest settling). Below 1.0 is underdamped (bounce/overshoot). Above 1.0 is overdamped (slow, sluggish settling).
- **Mass** — The weight of the animated element. Heavier elements move more slowly and have more momentum.

M3 Expressive defines standard spring specs for different interaction contexts:

- **Responsive spring** (stiffness: 1500, damping ratio: 1.0) — For immediate feedback like button presses. Critically damped, no bounce.
- **Expressive spring** (stiffness: 380, damping ratio: 0.7) — The signature M3 Expressive feel. Moderate speed with visible overshoot and a subtle bounce. Used for navigation indicator movement, FAB morphing, and sheet settling.
- **Gentle spring** (stiffness: 200, damping ratio: 0.85) — For large-scale transitions like screen changes and full-screen expansions. Slower, with slight overshoot.
- **Bouncy spring** (stiffness: 500, damping ratio: 0.5) — For playful interactions. Pronounced bounce. Used sparingly for delight moments (e.g., a successful action animation).

In Jetpack Compose, spring animations are specified via the `spring()` animation spec:

```kotlin
val offsetX by animateFloatAsState(
    targetValue = if (isSelected) selectedX else unselectedX,
    animationSpec = spring(
        dampingRatio = 0.7f,  // Expressive: visible overshoot
        stiffness = 380f       // Moderate speed
    )
)
```

**Interruptibility.** The critical advantage of spring-based motion is that it is inherently interruptible. If a spring animation is running and the target changes, the animation seamlessly redirects toward the new target while preserving the current velocity. There is no stutter, no restart, no abrupt change. This makes spring animations feel far more natural during rapid user interaction (e.g., quickly switching between navigation tabs).

### Shape Morphing

M3 Expressive introduces a shape system where components can transition between predefined shape states. Shapes are defined by corner radius, corner treatment (rounded vs. cut), and overall silhouette.

**Shape tokens** define the available shapes:

- `ShapeKeyTokens.ExtraSmall` — 4dp radius
- `ShapeKeyTokens.Small` — 8dp radius
- `ShapeKeyTokens.Medium` — 12dp radius
- `ShapeKeyTokens.Large` — 16dp radius
- `ShapeKeyTokens.ExtraLarge` — 28dp radius
- `ShapeKeyTokens.Full` — Fully rounded (pill/circle)

Components can animate between these shape tokens based on state. For example, a FAB starts as `Full` (circle), morphs to `Large` (rounded rectangle) when expanded, and returns to `Full` when collapsed. The morphing is driven by the spring motion system.

```kotlin
val cornerRadius by animateDpAsState(
    targetValue = if (isExpanded) 16.dp else 28.dp,
    animationSpec = spring(
        dampingRatio = 0.7f,
        stiffness = 380f
    )
)

FloatingActionButton(
    onClick = { isExpanded = !isExpanded },
    shape = RoundedCornerShape(cornerRadius),
    modifier = Modifier.animateContentSize(
        animationSpec = spring(
            dampingRatio = 0.7f,
            stiffness = 380f
        )
    )
) {
    // Content
}
```

### Expressive Color System

M3 Expressive extends Material You's dynamic color system with richer tonal palettes and new emphasis mechanisms:

**Expanded tonal palette.** The tonal palette gains additional weight stops between the existing tones. Where M3 defined tones at 0, 10, 20, 30, 40, 50, 60, 70, 80, 90, 95, 99, 100 — M3 Expressive adds intermediate tones (e.g., 4, 6, 12, 17, 22, 25, 35, 87, 92, 94, 96, 98) for finer color control. This enables subtler color distinctions between component states.

**Dynamic color from content.** Beyond wallpaper-based theming, M3 Expressive supports extracting dominant colors from in-app content (e.g., album art, product images) and applying them to nearby UI elements. This creates contextual color relationships within the app.

**Emphasis through color weight.** Rather than using opacity to create emphasis hierarchies (which can cause readability issues on varied backgrounds), M3 Expressive uses tonal weight — selecting lighter or darker tones from the same palette to create visual hierarchy. Primary content uses mid-weight tones, secondary content uses lighter tones, and tertiary content uses the lightest tones.

**Color scheme generation.** The `DynamicScheme` API generates complete color schemes from a single seed color. M3 Expressive adds new scheme variants: `SchemeExpressive`, `SchemeFruitSalad`, `SchemeRainbow`, and `SchemeMonochrome`, each with a distinct personality that influences how the tonal palette is distributed across color roles.

```kotlin
val dynamicColorScheme = dynamicColorScheme(
    seedColor = extractedColor,
    style = PaletteStyle.Expressive // New M3 Expressive style
)

MaterialTheme(
    colorScheme = dynamicColorScheme
) {
    // App content with expressive colors
}
```

### Compose Implementation Examples

**Spring-based NavigationBar:**

```kotlin
@Composable
fun ExpressiveNavigationBar(
    selectedIndex: Int,
    onItemSelected: (Int) -> Unit,
    items: List<NavigationItem>
) {
    NavigationBar {
        items.forEachIndexed { index, item ->
            NavigationBarItem(
                selected = selectedIndex == index,
                onClick = { onItemSelected(index) },
                icon = {
                    val scale by animateFloatAsState(
                        targetValue = if (selectedIndex == index) 1.1f else 1.0f,
                        animationSpec = spring(
                            dampingRatio = 0.6f,
                            stiffness = 400f
                        )
                    )
                    Icon(
                        imageVector = item.icon,
                        contentDescription = item.label,
                        modifier = Modifier.scale(scale)
                    )
                },
                label = { Text(item.label) }
            )
        }
    }
}
```

**Morphing FAB:**

```kotlin
@Composable
fun MorphingFAB(
    isExpanded: Boolean,
    onClick: () -> Unit,
    icon: ImageVector,
    label: String
) {
    val cornerRadius by animateDpAsState(
        targetValue = if (isExpanded) 16.dp else 28.dp,
        animationSpec = spring(dampingRatio = 0.7f, stiffness = 380f)
    )

    FloatingActionButton(
        onClick = onClick,
        shape = RoundedCornerShape(cornerRadius),
        modifier = Modifier.animateContentSize(
            animationSpec = spring(dampingRatio = 0.7f, stiffness = 380f)
        )
    ) {
        Row(
            modifier = Modifier.padding(horizontal = if (isExpanded) 20.dp else 16.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            Icon(imageVector = icon, contentDescription = null)
            AnimatedVisibility(visible = isExpanded) {
                Text(
                    text = label,
                    style = MaterialTheme.typography.labelLarge
                )
            }
        }
    }
}
```

**Carousel component:**

```kotlin
@Composable
fun ExpressiveCarousel(
    items: List<CarouselItem>,
    modifier: Modifier = Modifier
) {
    HorizontalMultiBrowseCarousel(
        state = rememberCarouselState { items.count() },
        modifier = modifier.height(220.dp),
        preferredItemWidth = 186.dp,
        itemSpacing = 8.dp,
        flingBehavior = CarouselDefaults.multiBrowseFlingBehavior(
            state = rememberCarouselState { items.count() },
            snapAnimationSpec = spring(
                dampingRatio = 0.8f,
                stiffness = 300f
            )
        )
    ) { index ->
        val item = items[index]
        Card(
            shape = RoundedCornerShape(16.dp),
            modifier = Modifier.fillMaxSize()
        ) {
            AsyncImage(
                model = item.imageUrl,
                contentDescription = item.description,
                contentScale = ContentScale.Crop,
                modifier = Modifier.fillMaxSize()
            )
        }
    }
}
```

### Comparison with iOS 26

iOS 26 and M3 Expressive represent fundamentally different responses to the same design question: "How do we make interfaces feel more premium and engaging in 2025-2026?"

Apple's answer is **material** — make the interface feel like it is made of a real, physical substance (glass). The emphasis is on visual richness through light interaction: refraction, reflection, tinting, translucency. Motion in iOS 26 serves the material (e.g., glass glinting as you tilt the device) but is not the primary expressive mechanism.

Google's answer is **motion** — make the interface feel alive through how it moves. The emphasis is on spring physics, shape morphing, and animated state transitions. Material (color, surface) plays a role, but the defining characteristic of M3 Expressive is how things move, not what they are made of.

This divergence means that cross-platform design is more challenging than ever. A glass-material aesthetic on Android looks out of place. Spring-bouncy animations on iOS feel un-Apple. Designers must embrace platform-native expression rather than seeking a middle ground.

### Accessibility in M3 Expressive

**Spring animations and `reduceMotion`.** All spring-based animations in M3 Expressive must respect the system `prefers-reduced-motion` / Android `Animator duration scale` settings. When reduced motion is enabled, spring animations should either be replaced with simple cuts (instant transitions) or use critically damped springs with high stiffness (effectively removing bounce while maintaining smooth transitions).

```kotlin
val dampingRatio = if (LocalReduceMotion.current) 1.0f else 0.7f
val stiffness = if (LocalReduceMotion.current) 1500f else 380f

val offset by animateFloatAsState(
    targetValue = targetOffset,
    animationSpec = spring(dampingRatio = dampingRatio, stiffness = stiffness)
)
```

**Minimum touch targets.** All M3 Expressive components maintain the Material Design minimum touch target of 48dp x 48dp, regardless of visual size. Shape morphing does not reduce touch targets — the interactive hit area remains constant even as the visual shape changes. Verify this when implementing custom morphing components.

**Color contrast in dynamic themes.** The dynamic color system includes built-in contrast enforcement. When generating color schemes from seed colors or content, the algorithm ensures that text-background combinations meet WCAG AA contrast ratios (4.5:1 for normal text, 3:1 for large text). This holds for both light and dark themes. However, custom color overrides can break this guarantee — always validate contrast when departing from the generated scheme.

**Content descriptions for animated icons.** When icons animate (scale, morph) to indicate state changes, ensure that the state change is also communicated via semantics for screen reader users. The animation is invisible to TalkBack; the semantics must carry the meaning.

---

## Platform Comparison: iOS 26 vs Android 16

### Visual Philosophy Divergence

Apple and Google have moved in orthogonal directions. Apple's Liquid Glass makes the interface feel like a physical artifact — a slab of tinted glass that you look through and interact with. The beauty comes from stillness and material. Google's M3 Expressive makes the interface feel like a living organism — components bounce, morph, stretch, and settle. The beauty comes from movement and transformation.

For Apple, the hero moment is a navigation bar catching a specular highlight as the user tilts their phone. For Google, the hero moment is a FAB smoothly morphing from circle to pill as the user scrolls down.

This divergence is not arbitrary. It reflects each company's broader platform identity. Apple has always been about premium materials — aluminum, glass, ceramic — and Liquid Glass extends that identity into software. Google has always been about intelligence and responsiveness — search, assistant, adaptive systems — and spring motion extends that identity into animation.

### Navigation Pattern Differences

The tab bar (iOS) and bottom navigation bar (Android) now look and behave more differently than at any point since Material Design's introduction.

iOS's tab bar is a glass surface that changes color based on the content beneath it. It feels like part of the physical device, a permanent fixture. The selected tab is indicated by an icon fill change and tint color, visible through the glass.

Android's bottom navigation bar uses a spring-animated selection indicator that slides between destinations with bounce and overshoot. It feels like a living control, responding dynamically to your touch. The visual emphasis is on the motion of selection, not the material of the bar.

### Animation Approach

iOS 26 uses animation primarily to reinforce the material metaphor — glass refracting, surfaces parallaxing, elements fading through translucent layers. The animations are subtle and serve the material. They do not call attention to themselves.

Android 16 uses animation as the primary expressive channel. Spring physics make every state change feel physical and intentional. Overshoot and bounce are features, not artifacts. The animations are meant to be noticed and to convey personality.

### What This Means for Cross-Platform Teams

**Do not homogenize.** The temptation for cross-platform teams (especially those using Flutter or React Native) is to create a single visual language that works on both platforms. In 2025-2026, this approach will feel wrong on both platforms. Users will notice. The platform design languages have diverged too far.

**Follow each platform for chrome.** Navigation bars, tab bars, toolbars, system controls — these must follow the platform. Glass on iOS, expressive spring motion on Android. Users interact with these elements through deep muscle memory.

**Unify content areas.** Your app's content — cards, lists, media, data — can share a design language across platforms. The chrome wrapping it should be platform-native, but the content itself can express your brand consistently.

**Budget for platform-specific work.** Plan for 15-25% additional design and engineering effort to properly support both platforms' new design languages. This is not optional polish — it is baseline platform compliance.

**Use platform-adaptive components.** Flutter's `Cupertino` and `Material` libraries, React Native's platform-specific components, and Kotlin Multiplatform with Compose Multiplatform and SwiftUI all provide pathways to platform-native behavior from shared business logic.

---

## Migration Guides

### iOS: Migrating to Liquid Glass

**From UIKit to SwiftUI glass patterns:**

1. **Audit existing `UIVisualEffectView` usage.** Replace `UIBlurEffect` instances with `UIGlassEffect` where appropriate. For new development, prefer SwiftUI's `.glassEffect()` modifier.
2. **Remove custom navigation bar backgrounds.** If you have set `UINavigationBarAppearance` with custom background images or colors, remove them and allow the system glass default. If you must customize, use the new `.glassEffect` appearance properties.
3. **Convert hardcoded colors to semantic styles.** Grep your codebase for `UIColor.white`, `UIColor.black`, `Color.white`, `Color.black`, and any custom `UIColor(hex:)` / `Color(hex:)` calls used for text on chrome. Replace with `.label`, `.secondaryLabel`, `.foregroundStyle(.primary)`, `.foregroundStyle(.secondary)`.
4. **Implement `accessibilityReduceTransparency` fallbacks.** For every custom glass view, add a code path that renders an opaque background when Reduce Transparency is enabled.
5. **Test on physical devices.** Glass effects are composited by the GPU in real time. Simulator rendering may not accurately reflect performance or appearance on actual hardware. Test on the oldest device you support.

**Testing checklist:**
- All text on glass surfaces meets WCAG AA contrast under light, dark, and varied content backgrounds
- Reduce Transparency enabled: all glass falls back to opaque
- Increase Contrast enabled: borders and text weight increase appropriately
- Dynamic Type at all sizes: glass chrome does not clip or obscure text
- Landscape orientation: glass surfaces resize and recomposite correctly
- Performance: maintain 60fps during scrolling with glass navigation and tab bars on oldest supported device
- VoiceOver: all glass elements have correct labels, traits, and navigation order

### Android: Migrating to M3 Expressive

**From M3 to M3 Expressive:**

1. **Update Material Compose BOM.** Ensure you are using the latest Material 3 Compose library version that includes Expressive components. Update your `material3` dependency to the version shipping with the Android 16 SDK.
2. **Adopt spring animations incrementally.** Start by replacing `tween()` and `animateFloatAsState` duration-based specs in navigation components (bottom nav indicator, tab indicator) with `spring()` specs using expressive parameters (damping: 0.7, stiffness: 380).
3. **Integrate new components.** Replace custom carousel implementations with the M3 Expressive `Carousel` component. Replace custom FABs with the morphing `FloatingActionButton`. Adopt the new `SegmentedButton` with spring selection.
4. **Update shape tokens.** If you have defined custom shapes, align them with the new M3 Expressive shape token scale. Use `ShapeKeyTokens` for consistent shape language across components.
5. **Review dynamic color.** If you use `dynamicColorScheme()`, explore the new `PaletteStyle.Expressive` variant for richer color generation. Test that all generated schemes maintain contrast ratios.
6. **Handle reduced motion.** Audit every spring animation and ensure it respects `prefers-reduced-motion`. Provide a critically damped fallback (damping: 1.0, high stiffness) or instant transition.

**Testing checklist:**
- Spring animations are smooth at 60/90/120fps on target devices
- Reduced motion setting: all springs become critically damped or instant
- Dynamic color: text contrast meets WCAG AA in all generated schemes (light, dark, and high-contrast variants)
- Shape morphing: touch targets remain >= 48dp throughout all shape states
- Carousel: supports TalkBack navigation, announces item position ("item 2 of 5")
- Back gesture: all expressive transitions (expanded search, bottom sheet springs, dialog entry) work correctly with predictive back
- Large screens: navigation rail expressive icons render and animate correctly on tablets and foldables
- Performance: spring animations do not cause frame drops on mid-range devices (target: Pixel 6a class hardware)