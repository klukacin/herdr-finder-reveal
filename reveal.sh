#!/bin/sh
# Herdr link handler: reveal a clicked local path in Finder.
#
# Herdr passes invocation context through the environment, not argv:
#   HERDR_PLUGIN_CLICKED_URL   the matched text that was clicked
#   HERDR_ACTIVE_PANE_CWD      cwd of the pane the click came from
#   HERDR_PLUGIN_CONTEXT_JSON  full context, incl. focused_pane_cwd
set -eu

# Herdr captures stdout into the plugin log, so every exit path states its
# decision. Otherwise exit 0 cannot be told apart from a silent no-op.
say() { printf '%s\n' "$*"; }

p="${HERDR_PLUGIN_CLICKED_URL:-}"
[ -n "$p" ] || { say "skip: no clicked url"; exit 0; }

# A scheme means this is not a local path. The regex only ever matches a path
# segment, but a whole URL arriving here must not be joined onto the pane cwd.
case "$p" in *://*) say "skip: not a local path: $p"; exit 0 ;; esac

# Tilde expansion. Ghostty had the same bug (ghostty-org/ghostty#10863):
# URL(filePath:) treats "~" as a literal directory.
case "$p" in
  "~") p="$HOME" ;;
  "~/"*) p="$HOME/${p#\~/}" ;;
esac

# Relative path -> resolve against the cwd of the pane that was clicked.
case "$p" in
  /*) ;;
  *)
    base="${HERDR_ACTIVE_PANE_CWD:-}"
    if [ -z "$base" ] && [ -n "${HERDR_PLUGIN_CONTEXT_JSON:-}" ]; then
      base=$(printf '%s' "$HERDR_PLUGIN_CONTEXT_JSON" |
        sed -n 's/.*"focused_pane_cwd"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
    fi
    [ -n "$base" ] || { say "skip: relative path, no pane cwd: $p"; exit 0; }
    p="$base/${p#./}"
    ;;
esac

# Compiler/agent output appends :line and :line:col. Try the literal path
# first so filenames that legitimately contain a colon still work.
if [ ! -e "$p" ]; then
  stripped=${p%:*}
  [ -e "$stripped" ] && p=$stripped || {
    stripped=${stripped%:*}
    [ -e "$stripped" ] && p=$stripped
  }
fi

# The existence check is also what keeps a URL-embedded segment such as
# https://host/tmp/x from firing: /tmp/x has to exist locally to match.
[ -e "$p" ] || { say "skip: no such path: $p"; exit 0; }

# A directory is more useful opened than revealed in its parent.
if [ -d "$p" ]; then
  say "open dir: $p"
  exec /usr/bin/open "$p"
else
  say "reveal: $p"
  exec /usr/bin/open -R "$p"
fi
