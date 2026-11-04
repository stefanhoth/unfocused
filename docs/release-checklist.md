# Release checklist

Releases run from **Actions → Release → Run workflow** (tick *dry run* to only build and sign). Then check by hand, on a Mac that already has unfocused:

1. `brew update && brew upgrade --cask unfocused`. Approve the new build under **System Settings → Privacy & Security → Open Anyway**.
2. The menu bar icon appears; there's no Dock icon.
3. The panel hotkey (default ⌃Space) opens the panel; typing searches; ⌘↩ Captures; ↩ Focuses; leaving a Loop asks Where I left off; Esc closes.
4. **Accessibility still granted** after the update (System Settings → Privacy & Security → Accessibility shows unfocused enabled, and features needing it work without asking again). This proves the stable signing certificate keeps the grant (ADR 0003). The first time this is checked, record the result in `docs/DECISIONS.md`.
5. Quit and relaunch: Loops, Focus and settings are still there.
- [ ] Look check: `open "build/Unfocused Dev.app" --args --show panel` (also `left-off`, `tie-off`, `banner`, `focus-preview`) over a light and a dark wallpaper; text stays readable on the glass, and with Reduce Motion on, Tie-off cards fade instead of sliding.
- [ ] Typing works right away in the panel and in Where did you leave off?; the log shows `Panel text field has the cursor: true` after each showing.

## Agent access (`unfocused-mcp`, ADR 0007)

- [ ] `codesign --verify --strict --verbose=2 /Applications/Unfocused.app` and the same for `/Applications/Unfocused.app/Contents/MacOS/unfocused-mcp` pass (`scripts/check-bundle.sh` does this in CI; repeat it on the installed build).
- [ ] Gatekeeper, binary started through the cask's `PATH` link: in a fresh Terminal, `which unfocused-mcp` shows the link, and `spctl --assess --type execute -vv "$(which unfocused-mcp)"` plus `printf '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18","capabilities":{},"clientInfo":{"name":"check","version":"1"}}}\n' | unfocused-mcp` don't ask for a separate approval beyond the app's Open Anyway. Record what macOS says in `docs/DECISIONS.md` the first time.
- [ ] An Agent (for example `claude mcp add unfocused -- unfocused-mcp`) lists the tools.
- [ ] With **Let Agents read my Loops** off, a call is refused with how to turn it on; with it on, the same call returns Loops, without restarting the Agent. The Activity tools do the same with their own switch.
- [ ] Settings → Agent access shows "Last used by" with that Agent's name and the time of the call.

