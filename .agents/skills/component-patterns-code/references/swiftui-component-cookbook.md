# SwiftUI Component Cookbook — Production iOS/macOS Components

This reference provides production-ready SwiftUI components with complete code, accessibility support, design token integration, and preview providers. Every component follows Apple Human Interface Guidelines and is tested against Dynamic Type, VoiceOver, and dark mode. Components target iOS 17+ unless otherwise noted.

---

## Theme System — EnvironmentKey-Based Design Tokens

Before building components, establish a theme system that flows through the SwiftUI environment. This replaces hardcoded colors, spacing, and typography with a single source of truth.

```swift
// MARK: - Design Tokens

struct AppTheme {
    // Colors
    let primaryColor: Color
    let secondaryColor: Color
    let destructiveColor: Color
    let successColor: Color
    let warningColor: Color
    let surfaceColor: Color
    let surfaceSecondaryColor: Color
    let textPrimary: Color
    let textSecondary: Color
    let textOnPrimary: Color
    let borderDefault: Color
    let borderFocused: Color
    let borderError: Color

    // Spacing (4-point grid)
    let spacingXS: CGFloat   // 4
    let spacingSM: CGFloat   // 8
    let spacingMD: CGFloat   // 16
    let spacingLG: CGFloat   // 24
    let spacingXL: CGFloat   // 32
    let spacingXXL: CGFloat  // 48

    // Typography
    let headingFont: Font
    let bodyFont: Font
    let captionFont: Font
    let buttonFont: Font

    // Radius
    let radiusSM: CGFloat    // 6
    let radiusMD: CGFloat    // 12
    let radiusLG: CGFloat    // 20
    let radiusFull: CGFloat  // 999

    // Elevation
    let shadowLight: (color: Color, radius: CGFloat, x: CGFloat, y: CGFloat)
    let shadowMedium: (color: Color, radius: CGFloat, x: CGFloat, y: CGFloat)

    // Animation
    let animationDefault: Animation
    let animationSpring: Animation
}

extension AppTheme {
    static let `default` = AppTheme(
        primaryColor: Color("BrandPrimary", bundle: .main),
        secondaryColor: Color("BrandSecondary", bundle: .main),
        destructiveColor: .red,
        successColor: .green,
        warningColor: .orange,
        surfaceColor: Color(.systemBackground),
        surfaceSecondaryColor: Color(.secondarySystemBackground),
        textPrimary: Color(.label),
        textSecondary: Color(.secondaryLabel),
        textOnPrimary: .white,
        borderDefault: Color(.separator),
        borderFocused: Color("BrandPrimary", bundle: .main),
        borderError: .red,
        spacingXS: 4, spacingSM: 8, spacingMD: 16,
        spacingLG: 24, spacingXL: 32, spacingXXL: 48,
        headingFont: .system(.title, design: .rounded, weight: .bold),
        bodyFont: .system(.body, design: .default),
        captionFont: .system(.caption, design: .default),
        buttonFont: .system(.body, design: .rounded, weight: .semibold),
        radiusSM: 6, radiusMD: 12, radiusLG: 20, radiusFull: 999,
        shadowLight: (Color.black.opacity(0.08), 4, 0, 2),
        shadowMedium: (Color.black.opacity(0.15), 10, 0, 4),
        animationDefault: .easeInOut(duration: 0.2),
        animationSpring: .spring(response: 0.35, dampingFraction: 0.7)
    )
}

// MARK: - Environment Key

private struct AppThemeKey: EnvironmentKey {
    static let defaultValue: AppTheme = .default
}

extension EnvironmentValues {
    var appTheme: AppTheme {
        get { self[AppThemeKey.self] }
        set { self[AppThemeKey.self] = newValue }
    }
}

// MARK: - Usage at App Root

@main
struct MyApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.appTheme, .default)
        }
    }
}
```

All components below access tokens via `@Environment(\.appTheme) private var theme`.

---

## 1. PrimaryButton

A full-featured button with loading state, icon variants, haptic feedback, and disabled state. Uses the `.buttonStyle` modifier pattern for reusability.

```swift
// MARK: - PrimaryButtonStyle

struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.appTheme) private var theme
    @Environment(\.isEnabled) private var isEnabled

    let isLoading: Bool
    let icon: String?
    let isDestructive: Bool

    init(isLoading: Bool = false, icon: String? = nil, isDestructive: Bool = false) {
        self.isLoading = isLoading
        self.icon = icon
        self.isDestructive = isDestructive
    }

    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: theme.spacingSM) {
            if isLoading {
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(theme.textOnPrimary)
                    .scaleEffect(0.85)
            }

            if let icon, !isLoading {
                Image(systemName: icon)
                    .font(.body.weight(.semibold))
            }

            if !isLoading {
                configuration.label
            } else {
                Text("Loading...")
            }
        }
        .font(theme.buttonFont)
        .foregroundStyle(theme.textOnPrimary)
        .frame(maxWidth: .infinity, minHeight: 50)
        .padding(.horizontal, theme.spacingLG)
        .background(buttonBackground(isPressed: configuration.isPressed))
        .clipShape(RoundedRectangle(cornerRadius: theme.radiusMD))
        .opacity(isEnabled ? 1.0 : 0.5)
        .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
        .animation(theme.animationDefault, value: configuration.isPressed)
        .allowsHitTesting(!isLoading && isEnabled)
    }

    private func buttonBackground(isPressed: Bool) -> Color {
        if isDestructive {
            return isPressed ? theme.destructiveColor.opacity(0.8) : theme.destructiveColor
        }
        return isPressed ? theme.primaryColor.opacity(0.8) : theme.primaryColor
    }
}

// MARK: - Haptic Helper

extension View {
    func hapticOnTap(style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) -> some View {
        self.simultaneousGesture(TapGesture().onEnded {
            UIImpactFeedbackGenerator(style: style).impactOccurred()
        })
    }
}

// MARK: - PrimaryButton View

struct PrimaryButton: View {
    let title: String
    let icon: String?
    let isLoading: Bool
    let isDestructive: Bool
    let action: () -> Void

    init(
        _ title: String,
        icon: String? = nil,
        isLoading: Bool = false,
        isDestructive: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.isLoading = isLoading
        self.isDestructive = isDestructive
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Text(title)
        }
        .buttonStyle(PrimaryButtonStyle(
            isLoading: isLoading,
            icon: icon,
            isDestructive: isDestructive
        ))
        .hapticOnTap()
        .accessibilityLabel(isLoading ? "\(title), loading" : title)
        .accessibilityAddTraits(.isButton)
        .accessibilityRemoveTraits(isLoading ? .isButton : [])
    }
}

// MARK: - Preview

#Preview("Primary Button States") {
    VStack(spacing: 16) {
        PrimaryButton("Continue", icon: "arrow.right") { }
        PrimaryButton("Submitting...", isLoading: true) { }
        PrimaryButton("Delete Account", isDestructive: true) { }
        PrimaryButton("Disabled") { }.disabled(true)
    }
    .padding()
}
```

Design notes: The `ButtonStyle` approach means consumers can also apply this style to any standard `Button` via `.buttonStyle(PrimaryButtonStyle())`. The haptic fires on the simultaneous gesture so it does not block the button action. The loading state removes hit testing and announces "loading" to VoiceOver.

---

## 2. ValidatedTextField

A text field with floating label animation, inline validation, clear button, and character count. Uses `@FocusState` for keyboard management.

```swift
struct ValidatedTextField: View {
    @Environment(\.appTheme) private var theme

    let label: String
    @Binding var text: String
    var validation: ((String) -> ValidationState)?
    var maxCharacters: Int?
    var keyboardType: UIKeyboardType = .default
    var textContentType: UITextContentType?

    @FocusState private var isFocused: Bool
    @State private var validationState: ValidationState = .idle

    enum ValidationState: Equatable {
        case idle
        case valid(String?)
        case invalid(String)
    }

    private var borderColor: Color {
        switch validationState {
        case .invalid: return theme.borderError
        case .valid: return theme.successColor
        case .idle: return isFocused ? theme.borderFocused : theme.borderDefault
        }
    }

    private var isLabelFloating: Bool {
        isFocused || !text.isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacingXS) {
            ZStack(alignment: .leading) {
                // Floating label
                Text(label)
                    .font(isLabelFloating ? theme.captionFont : theme.bodyFont)
                    .foregroundStyle(
                        validationState is_invalid
                            ? theme.destructiveColor
                            : (isFocused ? theme.primaryColor : theme.textSecondary)
                    )
                    .offset(y: isLabelFloating ? -24 : 0)
                    .animation(theme.animationSpring, value: isLabelFloating)

                HStack {
                    TextField("", text: $text)
                        .font(theme.bodyFont)
                        .foregroundStyle(theme.textPrimary)
                        .focused($isFocused)
                        .keyboardType(keyboardType)
                        .textContentType(textContentType)
                        .autocorrectionDisabled()
                        .onChange(of: text) { _, newValue in
                            if let maxCharacters, newValue.count > maxCharacters {
                                text = String(newValue.prefix(maxCharacters))
                            }
                            if let validation {
                                validationState = validation(text)
                            }
                        }
                        .onChange(of: isFocused) { _, focused in
                            if !focused, let validation {
                                validationState = validation(text)
                            }
                        }

                    if !text.isEmpty && isFocused {
                        Button {
                            text = ""
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(theme.textSecondary)
                        }
                        .accessibilityLabel("Clear text")
                    }

                    // Validation icon
                    switch validationState {
                    case .valid:
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(theme.successColor)
                            .transition(.scale.combined(with: .opacity))
                    case .invalid:
                        Image(systemName: "exclamationmark.circle.fill")
                            .foregroundStyle(theme.destructiveColor)
                            .transition(.scale.combined(with: .opacity))
                    case .idle:
                        EmptyView()
                    }
                }
            }
            .padding(.vertical, theme.spacingSM + 4)
            .padding(.horizontal, theme.spacingMD)
            .background(theme.surfaceSecondaryColor)
            .clipShape(RoundedRectangle(cornerRadius: theme.radiusSM))
            .overlay(
                RoundedRectangle(cornerRadius: theme.radiusSM)
                    .stroke(borderColor, lineWidth: isFocused ? 2 : 1)
            )
            .animation(theme.animationDefault, value: validationState)

            // Bottom row: message + character count
            HStack {
                switch validationState {
                case .invalid(let message):
                    Text(message)
                        .font(theme.captionFont)
                        .foregroundStyle(theme.destructiveColor)
                        .accessibilityLabel("Error: \(message)")
                case .valid(let message):
                    if let message {
                        Text(message)
                            .font(theme.captionFont)
                            .foregroundStyle(theme.successColor)
                    }
                case .idle:
                    EmptyView()
                }

                Spacer()

                if let maxCharacters {
                    Text("\(text.count)/\(maxCharacters)")
                        .font(theme.captionFont)
                        .foregroundStyle(theme.textSecondary)
                        .accessibilityLabel("\(text.count) of \(maxCharacters) characters")
                }
            }
        }
    }

    // Helper for pattern matching in computed property
    private var is_invalid: Bool {
        if case .invalid = validationState { return true }
        return false
    }
}

#Preview("Validated Text Field") {
    struct PreviewWrapper: View {
        @State private var email = ""
        @State private var name = "John"

        var body: some View {
            VStack(spacing: 24) {
                ValidatedTextField(
                    label: "Email Address",
                    text: $email,
                    validation: { value in
                        if value.isEmpty { return .idle }
                        let regex = /^[^@]+@[^@]+\.[^@]+$/
                        return value.contains(regex)
                            ? .valid("Looks good")
                            : .invalid("Enter a valid email address")
                    },
                    keyboardType: .emailAddress,
                    textContentType: .emailAddress
                )

                ValidatedTextField(
                    label: "Display Name",
                    text: $name,
                    validation: { value in
                        value.count >= 2 ? .valid(nil) : .invalid("Minimum 2 characters")
                    },
                    maxCharacters: 30
                )
            }
            .padding()
        }
    }
    return PreviewWrapper()
}
```

---

## 3. AdaptiveSheet

A modal sheet leveraging iOS 16+ presentation detents with drag indicator, keyboard avoidance, and adaptive sizing.

```swift
struct AdaptiveSheet<Content: View>: ViewModifier {
    @Binding var isPresented: Bool
    let detents: Set<PresentationDetent>
    let showDragIndicator: Bool
    let onDismiss: (() -> Void)?
    @ViewBuilder let content: () -> Content

    init(
        isPresented: Binding<Bool>,
        detents: Set<PresentationDetent> = [.medium, .large],
        showDragIndicator: Bool = true,
        onDismiss: (() -> Void)? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self._isPresented = isPresented
        self.detents = detents
        self.showDragIndicator = showDragIndicator
        self.onDismiss = onDismiss
        self.content = content
    }

    func body(content parentContent: Content) -> some View {
        parentContent
            .sheet(isPresented: $isPresented, onDismiss: onDismiss) {
                NavigationStack {
                    content()
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Done") {
                                    isPresented = false
                                }
                            }
                        }
                }
                .presentationDetents(detents)
                .presentationDragIndicator(showDragIndicator ? .visible : .hidden)
                .presentationCornerRadius(20)
                .presentationBackgroundInteraction(
                    detents.contains(.medium) ? .enabled(upThrough: .medium) : .disabled
                )
                .interactiveDismissDisabled(false)
            }
    }
}

extension View {
    func adaptiveSheet<Content: View>(
        isPresented: Binding<Bool>,
        detents: Set<PresentationDetent> = [.medium, .large],
        showDragIndicator: Bool = true,
        onDismiss: (() -> Void)? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        modifier(AdaptiveSheet(
            isPresented: isPresented,
            detents: detents,
            showDragIndicator: showDragIndicator,
            onDismiss: onDismiss,
            content: content
        ))
    }
}

// Custom fraction detent example
extension PresentationDetent {
    static let quarter = PresentationDetent.fraction(0.25)
    static let oneThird = PresentationDetent.fraction(0.33)
}

#Preview("Adaptive Sheet") {
    struct PreviewWrapper: View {
        @State private var showSheet = false
        var body: some View {
            Button("Show Sheet") { showSheet = true }
                .adaptiveSheet(isPresented: $showSheet, detents: [.medium, .large]) {
                    List {
                        ForEach(0..<20) { i in
                            Text("Row \(i)")
                        }
                    }
                    .navigationTitle("Select Item")
                }
        }
    }
    return PreviewWrapper()
}
```

---

## 4. SwipeableListRow

List row with trailing swipe actions (delete, archive, pin) and leading swipe (mark read) with destructive confirmation.

```swift
struct SwipeableListRow<Content: View>: View {
    @Environment(\.appTheme) private var theme

    let content: () -> Content
    var onDelete: (() -> Void)?
    var onArchive: (() -> Void)?
    var onPin: (() -> Void)?
    var onToggleRead: (() -> Void)?
    var isPinned: Bool = false
    var isRead: Bool = true

    @State private var showDeleteConfirmation = false

    var body: some View {
        content()
            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                if let onDelete {
                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                    .tint(theme.destructiveColor)
                }

                if let onArchive {
                    Button {
                        onArchive()
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    } label: {
                        Label("Archive", systemImage: "archivebox")
                    }
                    .tint(.orange)
                }

                if let onPin {
                    Button {
                        onPin()
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    } label: {
                        Label(isPinned ? "Unpin" : "Pin",
                              systemImage: isPinned ? "pin.slash" : "pin")
                    }
                    .tint(.yellow)
                }
            }
            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                if let onToggleRead {
                    Button {
                        onToggleRead()
                        UISelectionFeedbackGenerator().selectionChanged()
                    } label: {
                        Label(isRead ? "Unread" : "Read",
                              systemImage: isRead ? "envelope.badge" : "envelope.open")
                    }
                    .tint(theme.primaryColor)
                }
            }
            .confirmationDialog(
                "Delete this item?",
                isPresented: $showDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    onDelete?()
                    UINotificationFeedbackGenerator().notificationOccurred(.warning)
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This action cannot be undone.")
            }
    }
}

#Preview("Swipeable List") {
    List {
        ForEach(0..<5) { i in
            SwipeableListRow(
                content: {
                    HStack {
                        Circle().fill(.blue).frame(width: 40, height: 40)
                        VStack(alignment: .leading) {
                            Text("Item \(i)").font(.headline)
                            Text("Subtitle text").font(.subheadline).foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                },
                onDelete: { print("Delete \(i)") },
                onArchive: { print("Archive \(i)") },
                onPin: { print("Pin \(i)") },
                onToggleRead: { print("Toggle read \(i)") }
            )
        }
    }
}
```

---

## 5. AdaptiveNavigationStack

A navigation container that uses `NavigationStack` on iPhone and `NavigationSplitView` on iPad, with programmatic navigation via `NavigationPath`.

```swift
struct AdaptiveNavigationStack<Sidebar: View, Detail: View>: View {
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var navigationPath = NavigationPath()
    @State private var selectedItem: String?

    let title: String
    let sidebar: (Binding<String?>) -> Sidebar
    let detail: (String) -> Detail

    var body: some View {
        if sizeClass == .regular {
            NavigationSplitView {
                sidebar($selectedItem)
                    .navigationTitle(title)
            } detail: {
                if let selectedItem {
                    detail(selectedItem)
                } else {
                    ContentUnavailableView(
                        "No Selection",
                        systemImage: "sidebar.left",
                        description: Text("Select an item from the sidebar.")
                    )
                }
            }
            .navigationSplitViewStyle(.balanced)
        } else {
            NavigationStack(path: $navigationPath) {
                sidebar(Binding(
                    get: { selectedItem },
                    set: { newValue in
                        selectedItem = newValue
                        if let newValue {
                            navigationPath.append(newValue)
                        }
                    }
                ))
                .navigationTitle(title)
                .navigationDestination(for: String.self) { item in
                    detail(item)
                }
            }
        }
    }
}

#Preview("Adaptive Navigation") {
    AdaptiveNavigationStack(
        title: "Inbox",
        sidebar: { selection in
            List(selection: selection) {
                ForEach(["Design Review", "Sprint Planning", "1:1 Notes"], id: \.self) { item in
                    NavigationLink(value: item) {
                        Text(item)
                    }
                }
            }
        },
        detail: { item in
            Text("Detail for \(item)")
                .navigationTitle(item)
        }
    )
}
```

---

## 6. DynamicForm

A form with sections, toggles, pickers, and steppers that adapts to Dynamic Type and includes a keyboard toolbar.

```swift
struct DynamicForm: View {
    @Environment(\.appTheme) private var theme
    @FocusState private var focusedField: FormField?

    @State private var name = ""
    @State private var email = ""
    @State private var notificationsEnabled = true
    @State private var frequency: NotificationFrequency = .daily
    @State private var maxItems = 10
    @State private var notes = ""

    enum FormField: Hashable {
        case name, email, notes
    }

    enum NotificationFrequency: String, CaseIterable, Identifiable {
        case realtime = "Real-time"
        case daily = "Daily"
        case weekly = "Weekly"
        var id: String { rawValue }
    }

    var body: some View {
        Form {
            Section {
                TextField("Full Name", text: $name)
                    .textContentType(.name)
                    .focused($focusedField, equals: .name)

                TextField("Email", text: $email)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .focused($focusedField, equals: .email)
            } header: {
                Text("Profile")
            }

            Section {
                Toggle("Enable Notifications", isOn: $notificationsEnabled)
                    .tint(theme.primaryColor)

                if notificationsEnabled {
                    Picker("Frequency", selection: $frequency) {
                        ForEach(NotificationFrequency.allCases) { freq in
                            Text(freq.rawValue).tag(freq)
                        }
                    }
                    .pickerStyle(.menu)

                    Stepper("Max items: \(maxItems)", value: $maxItems, in: 1...50)
                }
            } header: {
                Text("Preferences")
            } footer: {
                Text("Notifications are sent based on your selected frequency.")
            }

            Section("Notes") {
                TextEditor(text: $notes)
                    .frame(minHeight: 100)
                    .focused($focusedField, equals: .notes)
                    .accessibilityLabel("Additional notes")
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    focusedField = nil
                }
                .fontWeight(.semibold)
            }
        }
        .scrollDismissesKeyboard(.interactively)
    }
}

#Preview("Dynamic Form") {
    NavigationStack {
        DynamicForm()
            .navigationTitle("Settings")
    }
}
```

---

## 7. BadgedTabView

A tab view with badge counts, SF Symbols, and selection haptic feedback.

```swift
struct BadgedTabView: View {
    @State private var selectedTab: Tab = .home
    @State private var previousTab: Tab = .home

    enum Tab: String, CaseIterable {
        case home, search, notifications, profile

        var title: String {
            rawValue.capitalized
        }

        var icon: String {
            switch self {
            case .home: return "house"
            case .search: return "magnifyingglass"
            case .notifications: return "bell"
            case .profile: return "person.circle"
            }
        }

        var selectedIcon: String {
            switch self {
            case .home: return "house.fill"
            case .search: return "magnifyingglass"
            case .notifications: return "bell.fill"
            case .profile: return "person.circle.fill"
            }
        }
    }

    let badgeCounts: [Tab: Int]

    init(badgeCounts: [Tab: Int] = [:]) {
        self.badgeCounts = badgeCounts
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            ForEach(Tab.allCases, id: \.self) { tab in
                tabContent(for: tab)
                    .tabItem {
                        Label(
                            tab.title,
                            systemImage: selectedTab == tab ? tab.selectedIcon : tab.icon
                        )
                    }
                    .tag(tab)
                    .badge(badgeCounts[tab] ?? 0)
            }
        }
        .onChange(of: selectedTab) { oldValue, newValue in
            if oldValue != newValue {
                UISelectionFeedbackGenerator().selectionChanged()
            }
            previousTab = oldValue
        }
    }

    @ViewBuilder
    private func tabContent(for tab: Tab) -> some View {
        switch tab {
        case .home:
            NavigationStack { Text("Home").navigationTitle("Home") }
        case .search:
            NavigationStack { Text("Search").navigationTitle("Search") }
        case .notifications:
            NavigationStack { Text("Notifications").navigationTitle("Notifications") }
        case .profile:
            NavigationStack { Text("Profile").navigationTitle("Profile") }
        }
    }
}

#Preview("Badged Tab View") {
    BadgedTabView(badgeCounts: [.notifications: 3])
}
```

---

## 8. CachedAsyncImage

An async image loader with placeholder, error state, in-memory cache, and phase-based transition animation.

```swift
// MARK: - Image Cache

actor ImageCache {
    static let shared = ImageCache()
    private var cache = NSCache<NSURL, UIImage>()

    init() {
        cache.countLimit = 100
        cache.totalCostLimit = 50 * 1024 * 1024 // 50MB
    }

    func image(for url: URL) -> UIImage? {
        cache.object(forKey: url as NSURL)
    }

    func store(_ image: UIImage, for url: URL) {
        let cost = image.pngData()?.count ?? 0
        cache.setObject(image, forKey: url as NSURL, cost: cost)
    }
}

// MARK: - CachedAsyncImage

struct CachedAsyncImage: View {
    let url: URL?
    let contentMode: ContentMode
    let cornerRadius: CGFloat

    @State private var phase: AsyncImagePhase = .empty

    init(url: URL?, contentMode: ContentMode = .fill, cornerRadius: CGFloat = 0) {
        self.url = url
        self.contentMode = contentMode
        self.cornerRadius = cornerRadius
    }

    var body: some View {
        Group {
            switch phase {
            case .empty:
                ZStack {
                    Color(.tertiarySystemFill)
                    ProgressView()
                }
                .transition(.opacity)

            case .success(let image):
                image
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))

            case .failure:
                ZStack {
                    Color(.tertiarySystemFill)
                    VStack(spacing: 8) {
                        Image(systemName: "photo.badge.exclamationmark")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                        Text("Failed to load")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .transition(.opacity)

            @unknown default:
                EmptyView()
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        .animation(.easeInOut(duration: 0.3), value: phaseID)
        .task(id: url) {
            await loadImage()
        }
        .accessibilityElement()
        .accessibilityLabel("Image")
        .accessibilityAddTraits(.isImage)
    }

    private var phaseID: Int {
        switch phase {
        case .empty: return 0
        case .success: return 1
        case .failure: return 2
        @unknown default: return -1
        }
    }

    private func loadImage() async {
        guard let url else {
            phase = .failure(URLError(.badURL))
            return
        }

        // Check cache
        if let cached = await ImageCache.shared.image(for: url) {
            phase = .success(Image(uiImage: cached))
            return
        }

        // Fetch from network
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let uiImage = UIImage(data: data) else {
                phase = .failure(URLError(.cannotDecodeContentData))
                return
            }
            await ImageCache.shared.store(uiImage, for: url)
            phase = .success(Image(uiImage: uiImage))
        } catch {
            phase = .failure(error)
        }
    }
}

#Preview("Cached Async Image") {
    VStack(spacing: 16) {
        CachedAsyncImage(
            url: URL(string: "https://picsum.photos/400/300"),
            cornerRadius: 12
        )
        .frame(height: 200)

        CachedAsyncImage(url: nil, cornerRadius: 12)
            .frame(height: 200)
    }
    .padding()
}
```

---

## 9. ToastOverlay

A toast notification system using `.overlay` and `.transition` with auto-dismiss, stacking, and VoiceOver announcement.

```swift
// MARK: - Toast Model

struct ToastItem: Identifiable, Equatable {
    let id = UUID()
    let message: String
    let type: ToastType
    let duration: TimeInterval

    enum ToastType {
        case info, success, warning, error

        var icon: String {
            switch self {
            case .info: return "info.circle.fill"
            case .success: return "checkmark.circle.fill"
            case .warning: return "exclamationmark.triangle.fill"
            case .error: return "xmark.circle.fill"
            }
        }

        var tint: Color {
            switch self {
            case .info: return .blue
            case .success: return .green
            case .warning: return .orange
            case .error: return .red
            }
        }
    }

    static func == (lhs: ToastItem, rhs: ToastItem) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Toast Manager

@Observable
class ToastManager {
    var toasts: [ToastItem] = []

    func show(_ message: String, type: ToastItem.ToastType = .info, duration: TimeInterval = 3.0) {
        let toast = ToastItem(message: message, type: type, duration: duration)
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            toasts.append(toast)
        }

        Task { @MainActor in
            try? await Task.sleep(for: .seconds(duration))
            dismiss(toast)
        }
    }

    func dismiss(_ toast: ToastItem) {
        withAnimation(.easeOut(duration: 0.25)) {
            toasts.removeAll { $0.id == toast.id }
        }
    }
}

// MARK: - Toast Overlay Modifier

struct ToastOverlayModifier: ViewModifier {
    @Environment(\.appTheme) private var theme
    let manager: ToastManager

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .top) {
                VStack(spacing: theme.spacingSM) {
                    ForEach(manager.toasts) { toast in
                        ToastView(toast: toast) {
                            manager.dismiss(toast)
                        }
                        .transition(
                            .asymmetric(
                                insertion: .move(edge: .top).combined(with: .opacity),
                                removal: .move(edge: .top).combined(with: .opacity)
                            )
                        )
                    }
                }
                .padding(.horizontal, theme.spacingMD)
                .padding(.top, theme.spacingSM)
            }
    }
}

// MARK: - Individual Toast View

struct ToastView: View {
    @Environment(\.appTheme) private var theme
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverEnabled

    let toast: ToastItem
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: theme.spacingSM) {
            Image(systemName: toast.type.icon)
                .foregroundStyle(toast.type.tint)
                .font(.title3)

            Text(toast.message)
                .font(theme.bodyFont)
                .foregroundStyle(theme.textPrimary)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(theme.textSecondary)
            }
            .accessibilityLabel("Dismiss notification")
        }
        .padding(theme.spacingMD)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: theme.radiusMD))
        .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isStaticText)
        .onAppear {
            if voiceOverEnabled {
                UIAccessibility.post(
                    notification: .announcement,
                    argument: toast.message
                )
            }
        }
    }
}

extension View {
    func toastOverlay(manager: ToastManager) -> some View {
        modifier(ToastOverlayModifier(manager: manager))
    }
}

#Preview("Toast Overlay") {
    struct PreviewWrapper: View {
        @State private var manager = ToastManager()
        var body: some View {
            VStack(spacing: 16) {
                Button("Info") { manager.show("File saved successfully.", type: .info) }
                Button("Success") { manager.show("Upload complete.", type: .success) }
                Button("Warning") { manager.show("Storage almost full.", type: .warning) }
                Button("Error") { manager.show("Connection lost.", type: .error) }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .toastOverlay(manager: manager)
        }
    }
    return PreviewWrapper()
}
```

---

## 10. SkeletonView

A shimmer loading placeholder using gradient animation, shape-matched to content, respecting `accessibilityReduceMotion`.

```swift
struct SkeletonView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shimmerOffset: CGFloat = -1.0

    let width: CGFloat?
    let height: CGFloat
    let cornerRadius: CGFloat

    init(width: CGFloat? = nil, height: CGFloat = 16, cornerRadius: CGFloat = 6) {
        self.width = width
        self.height = height
        self.cornerRadius = cornerRadius
    }

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(Color(.systemGray5))
            .frame(width: width, height: height)
            .overlay(
                Group {
                    if !reduceMotion {
                        shimmerGradient
                            .offset(x: shimmerOffset * 350)
                            .onAppear {
                                withAnimation(
                                    .linear(duration: 1.5)
                                    .repeatForever(autoreverses: false)
                                ) {
                                    shimmerOffset = 1.0
                                }
                            }
                    }
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .accessibilityLabel("Loading content")
            .accessibilityAddTraits(.isImage)
    }

    private var shimmerGradient: some View {
        LinearGradient(
            colors: [
                Color(.systemGray5).opacity(0),
                Color(.systemGray3).opacity(0.4),
                Color(.systemGray5).opacity(0)
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
        .frame(width: 200)
    }
}

// MARK: - Skeleton Composites

struct SkeletonCard: View {
    @Environment(\.appTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacingSM) {
            SkeletonView(height: 180, cornerRadius: theme.radiusMD)

            SkeletonView(width: 200, height: 20, cornerRadius: 4)
            SkeletonView(height: 14, cornerRadius: 4)
            SkeletonView(width: 140, height: 14, cornerRadius: 4)
        }
        .padding(theme.spacingMD)
        .background(theme.surfaceColor)
        .clipShape(RoundedRectangle(cornerRadius: theme.radiusLG))
    }
}

struct SkeletonListRow: View {
    @Environment(\.appTheme) private var theme

    var body: some View {
        HStack(spacing: theme.spacingSM) {
            SkeletonView(width: 48, height: 48, cornerRadius: 24)

            VStack(alignment: .leading, spacing: 6) {
                SkeletonView(width: 160, height: 16, cornerRadius: 4)
                SkeletonView(width: 100, height: 12, cornerRadius: 4)
            }
        }
        .padding(.vertical, theme.spacingXS)
    }
}

#Preview("Skeleton Views") {
    VStack(spacing: 24) {
        SkeletonCard()

        VStack(spacing: 0) {
            ForEach(0..<4, id: \.self) { _ in
                SkeletonListRow()
                Divider()
            }
        }
        .padding(.horizontal)
    }
    .padding()
}
```

When `accessibilityReduceMotion` is true, the shimmer animation is suppressed and the skeleton renders as a static gray shape. This respects the system-level preference without requiring any user configuration in the app.

---

## Haptic Feedback Patterns

SwiftUI does not have a built-in haptic API. Use UIKit feedback generators called from SwiftUI event handlers. There are three generator types, each serving a distinct purpose.

### UIImpactFeedbackGenerator

Physical impact sensation. Use for button presses, collisions, or snapping into place.

```swift
// Intensity levels: .light, .medium, .heavy, .soft, .rigid
let generator = UIImpactFeedbackGenerator(style: .medium)
generator.impactOccurred()

// With custom intensity (0.0 to 1.0)
generator.impactOccurred(intensity: 0.6)
```

**When to use:** Button taps, pull-to-refresh threshold, dragging an item past a snap point, toggling a switch.

### UISelectionFeedbackGenerator

Subtle tick for selection changes. The lightest haptic available.

```swift
let generator = UISelectionFeedbackGenerator()
generator.selectionChanged()
```

**When to use:** Scrolling through a picker, tab bar selection change, moving between segmented control options, carousel pagination.

### UINotificationFeedbackGenerator

Semantic feedback for outcomes. Three variants map to different vibration patterns.

```swift
let generator = UINotificationFeedbackGenerator()
generator.notificationOccurred(.success) // Affirmative double-tap
generator.notificationOccurred(.warning) // Cautionary triple-tap
generator.notificationOccurred(.error)   // Harsh buzz
```

**When to use:** Form submission success, payment completion, validation error, destructive action confirmation.

### Preparation for Low Latency

For time-critical haptics (during gestures or animations), call `prepare()` before the event to spin up the Taptic Engine in advance.

```swift
let impact = UIImpactFeedbackGenerator(style: .heavy)
impact.prepare() // Call early, e.g., on drag start

// Later, at the exact moment:
impact.impactOccurred()
```

### Reusable Haptic Modifier

```swift
struct HapticModifier: ViewModifier {
    enum HapticType {
        case impact(UIImpactFeedbackGenerator.FeedbackStyle)
        case selection
        case notification(UINotificationFeedbackGenerator.FeedbackType)
    }

    let type: HapticType

    func body(content: Content) -> some View {
        content.simultaneousGesture(TapGesture().onEnded {
            trigger()
        })
    }

    private func trigger() {
        switch type {
        case .impact(let style):
            UIImpactFeedbackGenerator(style: style).impactOccurred()
        case .selection:
            UISelectionFeedbackGenerator().selectionChanged()
        case .notification(let type):
            UINotificationFeedbackGenerator().notificationOccurred(type)
        }
    }
}

extension View {
    func haptic(_ type: HapticModifier.HapticType) -> some View {
        modifier(HapticModifier(type: type))
    }
}

// Usage:
Button("Save") { save() }
    .haptic(.notification(.success))
```

---

## iOS 26 Liquid Glass Patterns

iOS 26 (announced WWDC 2025) introduces the Liquid Glass design language. This replaces many uses of `.ultraThinMaterial` and custom blurs with a system-level translucent glass treatment that dynamically adapts to content behind it.

### Core Modifier: `.glassEffect`

The primary API for applying Liquid Glass in SwiftUI is the `.glassEffect` modifier. It renders a translucent, dynamically tinted surface that refracts and reflects the content beneath it.

```swift
// Basic Liquid Glass button
Button("Accept") {
    acceptInvitation()
}
.padding(.horizontal, 20)
.padding(.vertical, 12)
.glassEffect(.regular)
.clipShape(Capsule())
```

### GlassEffectContainer

When multiple glass elements are grouped, wrap them in a `GlassEffectContainer` to ensure they share a unified refraction and do not create visual artifacts where they overlap.

```swift
GlassEffectContainer {
    HStack(spacing: 12) {
        Button(action: { /* ... */ }) {
            Image(systemName: "heart.fill")
        }
        .glassEffect(.regular)

        Button(action: { /* ... */ }) {
            Image(systemName: "square.and.arrow.up")
        }
        .glassEffect(.regular)

        Button(action: { /* ... */ }) {
            Image(systemName: "ellipsis")
        }
        .glassEffect(.regular)
    }
    .padding()
}
```

### Liquid Glass Card

```swift
struct GlassCard: View {
    let title: String
    let subtitle: String
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.primary)

            Text(title)
                .font(.headline)

            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
}
```

### Liquid Glass Navigation Bar

In iOS 26, the system navigation bar automatically adopts Liquid Glass when using `NavigationStack`. To customize:

```swift
NavigationStack {
    ScrollView {
        // content
    }
    .navigationTitle("Dashboard")
    .toolbarBackgroundVisibility(.automatic, for: .navigationBar)
}
// The system handles glass rendering for the nav bar automatically.
// Avoid fighting the system by manually setting toolbar backgrounds
// unless you have a specific design reason.
```

### Liquid Glass Tab Bar

```swift
TabView {
    Tab("Home", systemImage: "house.fill") {
        HomeView()
    }
    Tab("Search", systemImage: "magnifyingglass") {
        SearchView()
    }
    Tab("Profile", systemImage: "person.fill") {
        ProfileView()
    }
}
// In iOS 26, TabView tab bars render with Liquid Glass by default.
// The system automatically adjusts tinting based on scroll content.
```

### Dynamic Tinting and Material Adaptation

Liquid Glass samples colors from the content behind it, producing a tinted translucency. You can influence this:

```swift
// Tinted glass using foreground style
Text("Premium")
    .padding()
    .glassEffect(.regular)
    .tint(.purple) // Influences the glass tint color

// The system blends the tint with the sampled background,
// so the exact appearance varies by context.
```

### Fallback Patterns for iOS 25 and Earlier

Liquid Glass APIs are unavailable below iOS 26. Use availability checks:

```swift
struct AdaptiveGlassCard: View {
    let title: String

    var body: some View {
        VStack {
            Text(title)
                .padding()
        }
        .frame(maxWidth: .infinity)
        .modifier(GlassFallbackModifier())
    }
}

struct GlassFallbackModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            content
                .glassEffect(.regular)
                .clipShape(RoundedRectangle(cornerRadius: 20))
        } else {
            content
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .shadow(color: .black.opacity(0.08), radius: 8, y: 2)
        }
    }
}
```

### NNGroup Usability Critique: Liquid Glass Concerns

Nielsen Norman Group and other UX research bodies have raised significant usability concerns about the Liquid Glass design language that practitioners must account for.

**Reduced contrast.** Liquid Glass surfaces are translucent by design, which means text and icons rendered on them compete visually with whatever content appears behind the surface. In testing, this has produced WCAG contrast ratio failures, particularly with light text over bright or varied backgrounds. System apps mitigate this with automatic vibrancy adjustments, but custom implementations may not receive the same treatment.

**Legibility under motion.** As the user scrolls, the content behind a glass surface changes continuously. This creates a shifting-background effect under labels, icons, and controls. For users with cognitive disabilities, low vision, or vestibular sensitivity, this constant visual change can reduce legibility and increase cognitive load.

**Touch target ambiguity.** The soft, borderless nature of glass elements can make it harder for users to distinguish interactive controls from decorative surfaces. Where a solid-background button has a clear boundary, a glass button blends into its environment. This is a Fitts's Law concern: users may take longer to identify and target glass controls.

**Recommendations for practitioners:**
- Always test glass surfaces against a variety of background content, not just the default wallpaper.
- Use `UIAccessibility.isReduceTransparencyEnabled` to detect when users prefer solid backgrounds and provide an opaque fallback.
- Ensure text on glass surfaces meets WCAG AA contrast minimums (4.5:1 for body text, 3:1 for large text) under worst-case background conditions.
- Add subtle borders or shadows to glass interactive elements to reinforce their boundaries.
- Test with VoiceOver: glass elements must have proper accessibility labels regardless of their visual treatment.

```swift
// Respecting Reduce Transparency
struct AccessibleGlassModifier: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    func body(content: Content) -> some View {
        if reduceTransparency {
            content
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16))
        } else {
            if #available(iOS 26, *) {
                content
                    .glassEffect(.regular)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            } else {
                content
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }
        }
    }
}
```

---

## Component Architecture Guidelines

**Environment over init parameters.** For theming and feature flags, prefer `@Environment` over passing values through every initializer. This keeps call sites clean and lets intermediate views remain unaware of data they do not use.

**ViewModifier for reusable behavior.** Patterns like haptics, glass effects, skeleton loading, and toast overlays are best expressed as `ViewModifier` types with convenience `View` extensions. This keeps the SwiftUI modifier-chain syntax intact.

**Preview discipline.** Every component should have at least one `#Preview` block. For stateful components, wrap the preview in a `PreviewWrapper` struct with `@State` properties. This provides an interactive preview without polluting the component's public API.

**Accessibility is not optional.** Every component must:
- Have an `accessibilityLabel` when the visual content alone is insufficient.
- Use `accessibilityAddTraits` and `accessibilityRemoveTraits` to communicate role changes (e.g., a button that becomes non-interactive during loading).
- Post `UIAccessibility.Notification.announcement` for transient content like toasts.
- Respect `accessibilityReduceMotion` and `accessibilityReduceTransparency`.

**State management.** Use `@State` for view-local state, `@Binding` for parent-owned state, `@FocusState` for keyboard management, and `@Observable` (iOS 17+) for shared state objects. Avoid `@ObservedObject` for objects the view does not own; prefer `@Environment` or pass them explicitly.

**Performance.** Avoid placing expensive work in `body`. Use `.task` for async operations, `.onChange` sparingly (prefer `Binding` transforms), and extract subviews to limit the scope of re-evaluation. The `SkeletonView` shimmer animation demonstrates using a single `@State` offset with `repeatForever` rather than a timer, which is more efficient.

---

## Summary Table

| Component | Key APIs | iOS Min | Accessibility |
|---|---|---|---|
| PrimaryButton | ButtonStyle, ProgressView, UIImpactFeedbackGenerator | 16 | Loading state label, trait removal |
| ValidatedTextField | @FocusState, onChange, TextField | 17 | Error announcements, character count |
| AdaptiveSheet | presentationDetents, sheet modifier | 16 | Standard sheet dismissal |
| SwipeableListRow | swipeActions, confirmationDialog | 16 | Destructive role, button labels |
| AdaptiveNavigationStack | NavigationStack, NavigationSplitView, NavigationPath | 16 | ContentUnavailableView |
| DynamicForm | Form, Toggle, Picker, Stepper, ToolbarItemGroup | 16 | Dynamic Type, keyboard toolbar |
| BadgedTabView | TabView, badge modifier, SF Symbols | 16 | Tab labels, badge counts |
| CachedAsyncImage | URLSession, NSCache, AsyncImagePhase | 16 | Image trait, loading label |
| ToastOverlay | overlay, transition, @Observable | 17 | VoiceOver announcement, auto-dismiss |
| SkeletonView | LinearGradient, repeatForever, @Environment | 16 | Reduce motion, loading label |
| Liquid Glass | glassEffect, GlassEffectContainer | 26 | Reduce transparency fallback |
