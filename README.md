# unfocused

A local-only macOS menu bar app that keeps track of the work you've already started across all your apps (Slack threads, emails, docs, pages, tasks) and helps you finish it instead of starting yet another thing.

No server, no account. Your data, logs and on-device AI stay on your Mac.

Website: <https://unfocused.stefanhoth.com>

> Status: early development. See the [v1 spec](https://github.com/stefanhoth/unfocused/issues/1).

## Install

```bash
brew tap stefanhoth/unfocused https://github.com/stefanhoth/unfocused
brew install --cask stefanhoth/unfocused/unfocused
```

Update with `brew upgrade --cask unfocused`. Builds aren't notarized yet (ADR 0003): on first launch after installing or updating, approve unfocused in **System Settings → Privacy & Security → Open Anyway**.

## Agent access

An **Agent** (Claude, ChatGPT, a local model: an app you chose, usually driven by an AI model) can read your Loops through `unfocused-mcp`, a small program that ships inside the app and speaks the Model Context Protocol over stdio. It only reads; it can't change anything, and it needs no macOS permission.

1. Install unfocused and open it once, so it has data.
2. In **Settings → Agent access**, turn on **Let Agents read my Loops**. Nothing is shared until you do. **Let Agents read my Activity** is a second switch, also off by default, because window titles, pages and conversations reveal far more than Loops. Turning a switch off applies on the next request, even to an Agent that is already connected.
3. Add it to your Agent. For Claude Code:

   ```bash
   claude mcp add unfocused -- unfocused-mcp
   ```

   For other apps that support MCP servers, use `unfocused-mcp` as the command, with no arguments. In the JSON form most of them use:

   ```json
   {
     "mcpServers": {
       "unfocused": { "command": "unfocused-mcp" }
     }
   }
   ```

   If the app can't find it, use the full path `/Applications/Unfocused.app/Contents/MacOS/unfocused-mcp` (or wherever Homebrew put the app) as the command.

**Where answers go.** What an Agent asks for is sent to the app that calls unfocused. With a remote model, that app passes it on to the provider's servers. With a local model, it stays on your Mac. unfocused itself sends nothing anywhere. The switch is your consent, not a lock: any program running as you can read unfocused's data file directly. Loop and Anchor titles reach the model as they are, so a crafted page title could try to steer the Agent.

**Tools.** With Loops allowed: `focused_loop`, `list_loops`, `search_open_loops`, `get_loop`, `loose_ends`, `loops_involving`. With Activity allowed as well: `activity`, `unfocused_time`, `time_spent`, `work_log`, `recap`. While a switch is off the tools are still listed, but calls answer with how to turn it on. Settings shows when access was last used and by which Agent.

**If an Agent gets an error instead of data:**

- *"There is no unfocused data yet. Open unfocused once."* unfocused was never started on this Mac. Open it, then try again.
- *"unfocused has not finished updating its data. Open unfocused once to update."* A new version hasn't migrated your data yet. Open the app.
- *"The data was written by a newer unfocused. Update unfocused."* A newer build (for example a dev build) changed the data. Run `brew upgrade --cask unfocused`.

The decision behind it: [ADR 0007](docs/adr/0007-read-only-agent-access-through-mcp.md).

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

The app stores its database in `~/Library/Application Support/unfocused/` and logs in `~/Library/Logs/unfocused/`. Dev builds share both with releases. Signing, permissions, review flags and debugging: [docs/local-development.md](docs/local-development.md).

## Project docs

- [GLOSSARY.md](GLOSSARY.md): the domain language (Loop, Focus, Anchor, Loose End, Tie-off, …)
- [docs/adr/](docs/adr/): architecture decisions
- [docs/DECISIONS.md](docs/DECISIONS.md): smaller decisions
- [docs/release-checklist.md](docs/release-checklist.md): the manual checks before and after a release
- [docs/local-development.md](docs/local-development.md): building and running locally
- [docs/github-repo-settings.md](docs/github-repo-settings.md): one-time repo setup
- [site/README.md](site/README.md): the landing page
