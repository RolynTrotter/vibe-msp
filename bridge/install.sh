#!/bin/bash
# vibe-msp: one-command setup of the Max <-> Claude Desktop bridge (macOS).
#
#   curl -fsSL https://raw.githubusercontent.com/RolynTrotter/vibe-msp/main/bridge/install.sh | bash
#
# Safe to run again: it updates in place. Everything goes in ~/vibe-msp
# (plus ~/.vibe-msp/node if Node.js has to be downloaded).

# Everything is inside main(), so bash reads the whole script before running it.
# This matters for `curl | bash`, where commands could otherwise eat the rest of
# the script from stdin.
main() {
  set -euo pipefail

  REPO_URL="https://github.com/RolynTrotter/vibe-msp.git"
  BRANCH="${VIBE_MSP_BRANCH:-main}"
  DEST="${VIBE_MSP_DIR:-$HOME/vibe-msp}"
  BR="$DEST/bridge"
  NODE_VERSION="v22.11.0"

  say() { printf '\n\033[1m==> %s\033[0m\n' "$1"; }
  die() { printf '\n\033[31mSetup failed: %s\033[0m\n' "$1" >&2; exit 1; }

  [ "$(uname)" = "Darwin" ] || die "this installer is for macOS."
  command -v git >/dev/null || die "git is missing. Run 'xcode-select --install', then run this command again."

  say "Getting vibe-msp into $DEST"
  if [ -d "$DEST/.git" ]; then
    git -C "$DEST" fetch -q origin "$BRANCH" </dev/null
    git -C "$DEST" checkout -q "$BRANCH" </dev/null 2>/dev/null \
      || git -C "$DEST" checkout -q -b "$BRANCH" "origin/$BRANCH" </dev/null
    git -C "$DEST" merge -q --ff-only "origin/$BRANCH" </dev/null \
      || die "$DEST has local changes that conflict with the update. Move it aside and run this again."
  else
    [ -e "$DEST" ] && die "$DEST already exists and isn't a vibe-msp checkout. Move it aside and run this again."
    git clone -q --branch "$BRANCH" "$REPO_URL" "$DEST" </dev/null
  fi

  say "Setting up Python"
  if ! command -v uv >/dev/null; then
    curl -LsSf https://astral.sh/uv/install.sh | sh >/dev/null </dev/null
    export PATH="$HOME/.local/bin:$PATH"
  fi
  command -v uv >/dev/null || die "couldn't install uv."
  if [ ! -x "$BR/.venv/bin/python" ]; then
    uv venv -q --python 3.12 "$BR/.venv" </dev/null
  fi
  uv pip install -q --python "$BR/.venv/bin/python" -r "$BR/requirements.txt" </dev/null

  say "Setting up Node (for the Max side of the bridge)"
  if ! command -v npm >/dev/null; then
    NODE_DIR="$HOME/.vibe-msp/node"
    if [ ! -x "$NODE_DIR/bin/npm" ]; then
      ARCH="$(uname -m)"; [ "$ARCH" = "x86_64" ] && ARCH="x64"
      mkdir -p "$NODE_DIR"
      curl -fsSL "https://nodejs.org/dist/$NODE_VERSION/node-$NODE_VERSION-darwin-$ARCH.tar.gz" \
        | tar -xz -C "$NODE_DIR" --strip-components 1
    fi
    export PATH="$NODE_DIR/bin:$PATH"
  fi
  (cd "$BR/MaxMSP_Agent" && npm install --no-audit --no-fund --no-update-notifier --loglevel=error </dev/null >/dev/null)
  [ -d "$BR/MaxMSP_Agent/node_modules/socket.io" ] || die "npm install didn't produce socket.io."

  say "Connecting it to Claude Desktop"
  "$BR/.venv/bin/python" - "$BR" <<'PY'
import json, os, shutil, sys, time
br = sys.argv[1]
path = os.path.expanduser("~/Library/Application Support/Claude/claude_desktop_config.json")
os.makedirs(os.path.dirname(path), exist_ok=True)
data = {}
if os.path.exists(path) and os.path.getsize(path) > 0:
    backup = path + ".bak-" + time.strftime("%Y%m%d-%H%M%S")
    shutil.copy(path, backup)
    print("    backed up existing config to", backup)
    with open(path) as f:
        data = json.load(f)
servers = data.setdefault("mcpServers", {})
if servers.pop("MaxMSPMCP", None) is not None:
    print("    replaced the old MaxMSPMCP entry")
servers["max"] = {
    "command": os.path.join(br, ".venv", "bin", "python"),
    "args": [os.path.join(br, "server.py")],
}
with open(path, "w") as f:
    json.dump(data, f, indent=2)
PY

  say "Done!"
  cat <<'MSG'

  Last step: quit Claude Desktop completely (Cmd-Q) and open it again.

  After that, just ask Claude to do something in Max. It opens Max and starts
  the bridge by itself, so there are no buttons to click and nothing to start
  first. Objects it builds appear in the "run-agent" tab of the bridge patch.

  To update later, paste the same command again.
MSG
}

main "$@"
