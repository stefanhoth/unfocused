# unfocused

Local-only macOS 26 menu bar app (Swift 6, SwiftUI) that tracks started work ("Loops") across apps. Product spec: GitHub issue #1; tickets are its sub-issues.

## Commands

All work goes through the Makefile; CI runs the same targets.

- `make test`: Swift Testing suite
- `make lint`: `swift format lint --strict` + build with warnings as errors (CI-gating)
- `make format`: fix formatting
- `make app` / `make run`: assemble and launch `build/Unfocused.app`

Built with SwiftPM only, no Xcode project (ADR 0006). Command Line Tools are enough.

## Layout

- `Sources/UnfocusedCore`: UI-free domain core (ADR 0005). No SwiftUI/AppKit imports, no system permissions. All domain rules live here.
- `Sources/Unfocused`: the app shell. Thin adapters only: UI, hotkeys, Accessibility, context readers, wiring Core to the real file system.
- `Tests/UnfocusedCoreTests`: tests through Core's public interface.
- `scripts/build-app.sh`: bundles the release binary into an `.app`.

## Language and decisions

- Use the terms in `GLOSSARY.md` exactly, in code, tests, issues and UI. Respect the `_Avoid_` lists.
- Architecture decisions: `docs/adr/` (with `status:` frontmatter; superseded ADRs are kept). Smaller calls: `docs/DECISIONS.md`, added in the same PR.

## Testing

- Test behaviour through Core's public interface: commands and events in, query answers out. Use an in-memory database and a controlled clock; never assert on internal tables.
- System adapters (context readers per Source) get contract tests from recorded raw responses.
- The on-device AI is behind a replaceable reasoner; tests use a fake. No automated UI tests in v1; there's a manual release checklist instead.
- Write tests first. A new warning is fixed in the PR that would introduce it.

## PRs

- One topic per PR, squash-merged; the PR title is a conventional commit with scope, e.g. `feat(capture): add Slack anchors`.
- Branch from fresh `origin/main`, keep `make lint test` green, rebase before pushing, open the PR, auto-merge on green.
- Required checks: `Lint`, `Build`, `Test`, `Conventional commit title`. Renaming a CI job means updating `.github/rulesets/main-branch-protection.json` too.

## Releases

Manual CalVer releases via the Release workflow; `docs/release-checklist.md` lists the manual checks. Signing uses a stable self-signed certificate (Actions secrets); `scripts/sign-app.sh` only works on CI because trusting the certificate needs sudo.
