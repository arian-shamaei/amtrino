# amtrino

**Every agent session on your Mac, at a glance — in the menu bar.**

amtrino watches your local AI coding sessions (Claude Code, Codex CLI) and
renders them as a live 3×3 dot grid in the macOS menu bar: one
identity-colored dot per session, breathing while it responds, flashing
when a response finishes, ringed when stalled. Click a finish notification
and it jumps you to that session's exact tmux pane.

The companion app to [amtr](https://github.com/arian-shamaei/anthropometer),
the btop-style Claude Code session instrument — but fully standalone: it
bundles its own copy of amtr's data engine and does not require the TUI.

## Install

Download the notarized zip from
[Releases](https://github.com/arian-shamaei/amtrino/releases), unzip, and
drop `amtrino.app` into /Applications. Requires macOS 13+ and `python3`
on PATH.

Or with Homebrew, once the cask is in the tap:

```sh
brew tap arian-shamaei/anthropometer
brew install --cask amtrino
```

## What the dots mean

- **color** — session identity (stable per session; themeable)
- **breathing** — responding right now
- **white flash** — response just finished (optional notification;
  clicking it focuses the session's tmux pane)
- **amber ring** — stalled (busy but quiet for 2 minutes)
- **hollow** — sitting in a shell
- **dim** — waiting for a prompt

Open the menu for the full picture: every session as a row
(name · project · context %), the 3×3 node grid — **drag a session onto a
node to pin it to that spot in the bar**, click a node to leave a
deliberate gap — a live-animated legend, and Options ▸ Help for the
animated tour (it also opens on first launch).

**Single-session mode** shows one session as a draining gradient tank or a
plain `NN%` readout. When the amtr TUI is running attached to the same
session, the tank mirrors amtr's exact rolled palette live.

**Themes**: eight built-ins (identity, pastel, monochrome, pressure zones,
vaporwave, matrix, ember, candy) plus custom gradients — a multi-stop
gradient editor with draggable color points. Identity mode adapts its
sampling to the menu bar's light/dark appearance per surface.

## How it works

A bundled copy of `amtr_engine.py` (stdlib Python, from the anthropometer
repo — synced by `scripts/sync-engine.sh`) runs in `--fleet` mode: a
change-detected JSON stream of every live session, read from the records
Claude Code and Codex already write on disk. amtrino only renders. The
wire contract lives in anthropometer's `SPEC.md` §f2.

Codex sessions are discovered by pairing live `codex` processes with
their newest cwd-matching rollout; status is event-precise
(`task_started`/`task_complete`).

## Build

```sh
swift build                       # dev build
.build/debug/AmtrBar --selfcheck  # palette goldens, wire model, slot law
sh scripts/build.sh 0.1.1         # assemble + sign + notarize amtrino.app
```

Signing auto-detects a Developer ID Application cert (hardened runtime)
and notarizes + staples when a `notarytool` keychain profile named
`amtrino` exists; otherwise it falls back to ad-hoc for local dev.

Dev affordances: `AMTRINO_ENGINE=/path/to/amtr_engine.py` overrides the
bundled engine; `AMTRINO_DUMP=/tmp/frame.png` writes every rendered icon
frame for visual validation.

The golden palette values in `Selfcheck.swift` are pinned against
anthropometer's `palette_golden_cross_language` test — a session's menu
bar dot and its amtr TUI tile are the same colors by contract.

## License

[MIT](LICENSE) © Arian Shamaei
