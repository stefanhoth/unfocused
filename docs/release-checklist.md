# Release checklist

Releases run from **Actions → Release → Run workflow** (tick *dry run* to only build and sign). Then check by hand, on a Mac that already has unfocused:

1. `brew update && brew upgrade --cask unfocused`. Approve the new build under **System Settings → Privacy & Security → Open Anyway**.
2. The menu bar icon appears; there's no Dock icon.
3. The panel hotkey (default ⌃Space) opens the panel; typing searches; ⌘↩ Captures; ↩ Focuses; leaving a Loop asks Where I left off; Esc closes.
4. **Accessibility still granted** after the update (System Settings → Privacy & Security → Accessibility shows unfocused enabled, and features needing it work without asking again). This proves the stable signing certificate keeps the grant (ADR 0003). The first time this is checked, record the result in `docs/DECISIONS.md`.
5. Quit and relaunch: Loops, Focus and settings are still there.
- [ ] Look check: `open build/Unfocused.app --args --show panel` (also `left-off`, `tie-off`, `banner`, `focus-preview`) over a light and a dark wallpaper; text stays readable on the glass, and with Reduce Motion on, Tie-off cards fade instead of sliding.
- [ ] Typing works right away in the panel and in Where did you leave off?; the log shows `Panel text field has the cursor: true` after each showing.
