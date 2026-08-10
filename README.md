# herdr-finder-reveal

Ctrl-click a local file path in a [Herdr](https://github.com/herdrdev/herdr) pane
and it is revealed in Finder.

Agent and compiler output is full of paths — `src/config/url.zig:42:10`,
`~/.config/herdr/config.toml`, `/Users/you/projects/app/README.md`. This plugin
hands them to Finder instead of to a browser or a text editor.

- Files are revealed and selected (`open -R`). Directories are opened (`open`).
- `file://host/path` URLs are percent-decoded, and the host is dropped.
- `~` is expanded; relative paths resolve against the cwd of the pane you clicked in.
- A trailing `:line` or `:line:col` is stripped, so `foo.rs:42:10` still lands on `foo.rs`.
- macOS only.

## Install

```sh
herdr plugin install klukacin/herdr-finder-reveal
herdr plugin list
```

Requires Herdr 0.7.5 or newer. To hack on it locally, clone and link the working
directory instead:

```sh
herdr plugin link /path/to/herdr-finder-reveal
```

## Use

**Ctrl+click** the path. Control is Herdr's modified-click modifier on every
platform, including macOS: captured terminal mouse reports cannot expose
Command/Super separately from a plain click, so `⌘+click` never reaches Herdr.

Herdr only makes **OSC 8 hyperlinks** clickable — it has no plain-text link
scanner. A path is therefore a target when the program that printed it emitted
an OSC 8 hyperlink, which is what this plugin's pattern matches, either as a
`file://` URI or as a path inside the link target. Plain text that merely looks
like a path is not clickable, and no plugin can change that.

Every invocation prints its verdict to the plugin log:

```sh
herdr plugin log list --plugin klukacin.finder-reveal
```

```
reveal: /path              file revealed in Finder
open dir: /path            directory opened
skip: not a local path     the clicked URL carries a scheme other than file://
skip: no such path         nothing at that path on disk
skip: relative path, no pane cwd
```

Exit status alone proves nothing: a silent no-op also exits 0. Read the line,
not the status.

## Why a plugin

The terminal cannot do this for you inside Herdr.

- **Ghostty** detects file paths natively, but opens them with
  `NSWorkspace.open` — the default *application*, not Finder. Its custom `link`
  regex is not wired up either: setting it fails with `error.NotImplemented`,
  and `man 5 ghostty` says `TODO: This can't currently be set!`
- Even if it were, the click never reaches the terminal. Herdr defaults to
  `mouse_capture = true` and owns the mouse.

## Context

Herdr passes invocation context through the environment, not argv:

| Variable | Meaning |
| --- | --- |
| `HERDR_PLUGIN_CLICKED_URL` | the matched text that was clicked |
| `HERDR_PLUGIN_LINK_HANDLER_ID` | which handler matched |
| `HERDR_PLUGIN_ROOT` | plugin directory |
| `HERDR_ACTIVE_PANE_CWD` | cwd of the pane clicked in |
| `HERDR_PLUGIN_CONTEXT_JSON` | full context, incl. `focused_pane_cwd` |

`HERDR_ACTIVE_PANE_CWD` is not part of the documented plugin contract, so
`reveal.sh` falls back to `focused_pane_cwd` from `HERDR_PLUGIN_CONTEXT_JSON`.

## Caveat: no look-around

Herdr compiles patterns with the Rust [`regex`](https://docs.rs/regex) crate,
which has no look-behind. A path therefore cannot be excluded by what precedes
it, so the bare-path branch also matches inside a URL such as
`https://host/tmp/x`. `reveal.sh` rejects scheme-bearing input before any path
handling, and still requires the resolved path to exist on disk.

## License

MIT
