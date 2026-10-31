# unfocused

A local-only macOS menu bar app that keeps track of the work you've already started across all your apps (Slack threads, emails, docs, pages, tasks) and helps you finish it instead of starting yet another thing.

No server, no account. Your data, logs and on-device AI stay on your Mac.

> Status: early development. See the [v1 spec](https://github.com/stefanhoth/unfocused/issues/1).

## Install

```bash
brew tap stefanhoth/unfocused https://github.com/stefanhoth/unfocused
brew install --cask stefanhoth/unfocused/unfocused
```

Update with `brew upgrade --cask unfocused`. Builds aren't notarized yet (ADR 0003): on first launch after installing or updating, approve unfocused in **System Settings → Privacy & Security → Open Anyway**.

## Requirements

- macOS 26 or later
- To build: the Xcode Command Line Tools (`xcode-select --install`) with Swift 6.2 or later. Full Xcode is optional.

## Develop

```bash
make setup   # install the pre-commit hook
make test    # run the tests
make lint    # format check + build with warnings as errors
make format  # fix formatting
make run     # build build/Unfocused Dev.app and launch it
```

The app stores its database in `~/Library/Application Support/unfocused/` and logs in `~/Library/Logs/unfocused/`.

## Project docs

- [GLOSSARY.md](GLOSSARY.md): the domain language (Loop, Focus, Anchor, Loose End, Tie-off, …)
- [docs/adr/](docs/adr/): architecture decisions
- [docs/DECISIONS.md](docs/DECISIONS.md): smaller decisions
- [docs/github-repo-settings.md](docs/github-repo-settings.md): one-time repo setup
