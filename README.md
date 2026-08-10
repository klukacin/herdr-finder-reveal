# herdr-finder-reveal

Click a local file path in a [Herdr](https://github.com/herdrdev/herdr) pane, get it revealed in Finder.

Agent and compiler output is full of paths — `src/config/url.zig:42:10`,
`~/.config/herdr/config.toml`, `/Users/you/projects/app/README.md`. This plugin makes
them clickable and hands them to Finder.

- Files are revealed and selected (`open -R`).
- Directories are opened (`open`).
- `~/…` is expanded, relative paths resolve against the cwd of the pane you clicked in.
- A trailing `:line` or `:line:col` is stripped, so `foo.rs:42:10` still lands on `foo.rs`.

macOS only.

## Why a plugin

The terminal cannot do this for you inside Herdr:

- **Ghostty** detects file paths natively, but opens them with `NSWorkspace.open` — the
  default *application*, not Finder. Its custom `link` regex is not wired up either:
  setting it fails with `error.NotImplemented`, and `man 5 ghostty` says
  `TODO: This can't currently be set`.
- Even if it were, the click never reaches the terminal. Herdr defaults to
  `mouse_capture = true` and owns the mouse, so the pane multiplexer has to handle it.

Herdr's plugin system exposes exactly the missing piece: a `link_handlers` entry maps a
regex to an action.

## Install

Herdr has no `plugin` CLI subcommand as of 0.7.5 — the plugin API lives on the control
socket. Clone, then link:

```sh
git clone https://github.com/klukacin/herdr-finder-reveal.git \
  ~/.config/herdr/plugins/herdr-finder-reveal

printf '{"id":"1","method":"plugin.link","params":{"path":"%s","enabled":true}}\n' \
  "$HOME/.config/herdr/plugins/herdr-finder-reveal" \
  | nc -U ~/.config/herdr/herdr.sock
```

Then click a path in any pane.

## Managing it

`params` is mandatory on every request, even when empty.

```sh
H=~/.config/herdr/herdr.sock

# list
printf '{"id":"1","method":"plugin.list","params":{}}\n' | nc -U $H | jq

# disable / enable
printf '{"id":"1","method":"plugin.disable","params":{"plugin_id":"finder-reveal"}}\n' | nc -U $H
printf '{"id":"1","method":"plugin.enable","params":{"plugin_id":"finder-reveal"}}\n' | nc -U $H

# remove
printf '{"id":"1","method":"plugin.unlink","params":{"plugin_id":"finder-reveal"}}\n' | nc -U $H

# what the action actually did, with exit code and stderr
printf '{"id":"1","method":"plugin.log.list","params":{"plugin_id":"finder-reveal"}}\n' | nc -U $H | jq
```

Invoke it without clicking, to test the chain:

```sh
printf '{"id":"1","method":"plugin.action.invoke","params":{"plugin_id":"finder-reveal","action_id":"reveal","context":{"clicked_url":"%s"}}}\n' \
  "$PWD/README.md" | nc -U ~/.config/herdr/herdr.sock
```

## How it works

`herdr-plugin.toml` declares one action and one link handler:

```toml
[[actions]]
id = "reveal"
command = ["/bin/sh", "-c", "exec \"$HERDR_PLUGIN_ROOT/reveal.sh\""]

[[link_handlers]]
id = "local-path"
action = "reveal"
pattern = "…"
```

The `sh -c` wrapper is required: `command` is argv, executed directly, so nothing
expands `$HERDR_PLUGIN_ROOT` unless a shell does it.

Context arrives through the environment, not argv:

| variable | meaning |
|---|---|
| `HERDR_PLUGIN_CLICKED_URL` | the matched text that was clicked |
| `HERDR_PLUGIN_LINK_HANDLER_ID` | which handler matched |
| `HERDR_PLUGIN_ROOT` | plugin directory |
| `HERDR_ACTIVE_PANE_CWD` | cwd of the pane clicked in |
| `HERDR_PLUGIN_CONTEXT_JSON` | full context, incl. `focused_pane_cwd` |

## Caveat: no look-around

Herdr compiles patterns with the Rust [`regex`](https://docs.rs/regex) crate, which has
no look-behind. A path therefore cannot be excluded by what precedes it, so the
`/tmp/…` branch also matches inside a URL like `https://host/tmp/x`.

`reveal.sh` compensates by requiring the resolved path to exist on disk. A URL segment
only misfires if the same path happens to exist locally.

## License

MIT
