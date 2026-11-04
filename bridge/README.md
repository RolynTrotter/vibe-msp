# Max bridge

This lets Claude Desktop see and edit a running Max 9 patch.

## Setup (macOS, one command)

Paste this into Terminal:

```
curl -fsSL https://raw.githubusercontent.com/RolynTrotter/vibe-msp/main/bridge/install.sh | bash
```

Then quit Claude Desktop (Cmd-Q) and reopen it. That's it: when a chat needs Max, the bridge opens Max and starts itself. Run the same command again to update.

## Where this comes from

This is a vendored copy of [tiianhk/MaxMSP-MCP-Server](https://github.com/tiianhk/MaxMSP-MCP-Server) at commit `6d7b716` (MIT; see `LICENSE`), with these changes:

- **`server.py` connects lazily.** The upstream server connected to Max at startup and exited if Max wasn't already running. This version starts cleanly, connects on the first tool call, and if Max isn't reachable it runs `open MaxMSP_Agent/bridge.maxpat` and waits up to 90 s (`MAX_CONNECT_TIMEOUT`). It reconnects after Max restarts.
- **`MaxMSP_Agent/bridge.maxpat` is based on upstream `demo.maxpat`:**
  - A `loadbang → delay 1500 → script start` chain starts the Node bridge when the patch opens.
  - The "install" tab is removed, because `install.sh` runs `npm install` itself.
- **`max_mcp.js` avoid-rect fix:** `get_avoid_rect_position` sent pretty-printed JSON through Max atoms, which arrived garbled (`755281034568`). It now sends compact JSON like the other replies.
- **The upstream `install.py` is replaced by `install.sh`.** The old script crashed on configs without `mcpServers`. The new one installs everything and registers the server as `max` in `claude_desktop_config.json`, removing the old `MaxMSPMCP` entry if there is one.

The bridge only sees the patch it lives in, meaning the run-agent tab of `bridge.maxpat`.
