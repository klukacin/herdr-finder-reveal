#!/bin/sh
# Herdr link handler: reveal a clicked local path in Finder.
#
# Herdr passes invocation context through the environment, not argv:
#   HERDR_PLUGIN_CLICKED_URL   the matched text that was clicked
#   HERDR_ACTIVE_PANE_CWD      cwd of the pane the click came from
#   HERDR_PLUGIN_CONTEXT_JSON  full context, incl. focused_pane_cwd
set -eu

p="${HERDR_PLUGIN_CLICKED_URL:-}"
[ -n "$p" ] || exit 0

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
    [ -n "$base" ] || exit 0
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
[ -e "$p" ] || exit 0

# A directory is more useful opened than revealed in its parent.
if [ -d "$p" ]; then
  exec /usr/bin/open "$p"
else
  exec /usr/bin/open -R "$p"
fi
