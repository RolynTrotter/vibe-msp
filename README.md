# vibe-msp

Tools and skills that let Claude build Max/MSP patches without drag-and-drop.

- **`bridge/`** connects Claude Desktop to a running Max 9. To set it up on a Mac, paste this into Terminal:

  ```
  curl -fsSL https://raw.githubusercontent.com/RolynTrotter/vibe-msp/main/bridge/install.sh | bash
  ```

  Then quit and reopen Claude Desktop. See [bridge/README.md](bridge/README.md) for details.
- **`RESOURCES.md`** holds the research notes: the `.maxpat` format, existing tools and known gotchas.
