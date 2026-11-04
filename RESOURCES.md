# Max/MSP research notes

Research for building skills that let Claude write Max patches (`.maxpat` JSON) directly instead of dragging boxes around.

## The format

There is **no official `.maxpat` spec or JSON Schema** from Cycling '74 ([forum thread](https://cycling74.com/forums/specification-for-maxpat-json-format)). Everything below comes from reverse-engineering real patches.

A patch is plain JSON with this skeleton (taken from `max-sdk/help/vexpr.maxhelp`):

```json
{
  "patcher": {
    "fileversion": 1,
    "appversion": { "major": 7, "minor": 0, "revision": 0, "architecture": "x86", "modernui": 1 },
    "rect": [48, 79, 616, 565],
    "boxes": [
      { "box": { "id": "obj-1", "maxclass": "newobj", "text": "cycle~ 440",
                 "numinlets": 2, "numoutlets": 1, "outlettype": ["signal"],
                 "patching_rect": [30, 30, 70, 22] } }
    ],
    "lines": [
      { "patchline": { "source": ["obj-1", 0], "destination": ["obj-2", 0] } }
    ]
  }
}
```

Key facts:
- `maxclass` is `newobj` for ordinary typed-in objects. UI objects use their own class (`message`, `comment`, `toggle`, `number`, `ezdac~`, `live.dial`, and so on).
- `numinlets`, `numoutlets` and `outlettype` are stored in the file. Max mostly recomputes them on load, but patchlines to ports that don't exist are dropped.
- A subpatcher (`p foo`, `gen~`, `bpatcher`, `poly~` contents) is a nested `"patcher"` object inside the box.
- **Copy Compressed** text (`----------begin_max5_patcher----------`) is a variant of base64-encoded, zlib-compressed JSON, which forum users have decoded ([thread 1](https://cycling74.com/forums/format-of-compressed-json), [thread 2](https://cycling74.com/forums/copy-compressed-in-max-6)). Supporting it would let us paste patches to and from forum posts.

## Existing tools (all cloned and inspected)

| Project | What it gives us | License |
|---|---|---|
| [shakfu/py2max](https://github.com/shakfu/py2max) | Pure-Python offline `.maxpat` generator with round-trip parsing, a linter (`lint.py`: bad ports, orphan lines, duplicate IDs, unknown classes), auto-layout, `.amxd` read/write, and a bundled maxref object database (`maxref/data/bundle.json.gz`) | MIT |
| [tiianhk/MaxMSP-MCP-Server](https://github.com/tiianhk/MaxMSP-MCP-Server) | MCP server that drives a **running** Max (9+, V8 JS) to add, inspect and connect objects. Its `docs.json` (6 MB) holds inlet, outlet, argument and method docs for 1,129 objects (max 438, msp 445, jit 209, m4l 37) | MIT |
| [darosh/eslint-plugin-maxpat](https://github.com/darosh/eslint-plugin-maxpat) | Experimental ESLint plugin that lints `.maxpat` | MIT |
| [twhiston/maxGPT](https://github.com/twhiston/maxGPT) | Prompts for LLM patch generation ([prompts.md](https://github.com/twhiston/maxGPT/blob/main/misc/prompts.md)) | unclear |
| [jacklion710/max-patch-visualizer](https://github.com/jacklion710/max-patch-visualizer) | Web renderer for `.maxpat` (useful for previewing without Max) | – |
| robenkleene `claude-skills-maxmsp` ([listing](https://skillsmp.com/ar/creators/robenkleene/dotfiles/claude-skills-maxmsp)) | An existing Claude skill for Max (the page returned 403, so it hasn't been read yet) | – |

**Corpus of real patches:** `Cycling74/max-sdk` has 112 `.maxpat`/`.maxhelp` files and `Cycling74/min-devkit` has 29 (plus 31 `.maxref.xml`). These are good for golden examples and for testing a round-trip.

## Official docs

- JS scripting a patcher from inside Max: [JavaScript Tutorial 2](https://docs.cycling74.com/learn/articles/javascriptchapter02) (`this.patcher.newdefault`, `connect`, `remove`). This is the live-Max alternative to writing JSON.
- Reference pages: [Writing Reference Pages](https://cycling74.com/tutorials/writing-reference-pages), [Package authoring docs](https://cycling74.com/tutorials/package-authoring-writing-documentation). There is no formal schema for `.maxref.xml` either.
- C externals: [max-sdk](https://github.com/Cycling74/max-sdk) (C, source of truth) and [min-devkit](https://github.com/Cycling74/min-devkit) (modern C++). These are for writing **new objects**, not for composing patches, so they are probably out of scope for JSON generation.
- gen~ / GenExpr: [gen.codebox~](https://docs.cycling74.com/reference/gen.codebox~), [Gen in RNBO](https://rnbo.cycling74.com/learn/gen-rnbo). DSP written as text is a natural fit for an LLM.
- RNBO: [C++ source export](https://rnbo.cycling74.com/learn/the-cpp-source-code-target-overview). RNBO patches (`.rnbopat`) use the same JSON format and export to C++/Web Audio/VST.

## Known gotchas

- maxref inlet and outlet counts are the *defaults*. Many objects change their port count with arguments (`pack 0 0 0`, `+~`, `route a b c`, `gate 4`, `poly~`), so a validator needs per-object rules.
- Max doesn't run on Linux, so a cloud session **can't open patches to verify them**. Validation has to be static (schema, linter, object database), or a human (or a Mac runner) opens the file.
- `appversion` affects how some attributes are read, so we should pin one target Max version.

## Not found yet

- An official JSON Schema (none exists, so we'll have to write one).
- A headless or CLI Max for automated load-testing (none known, though RNBO's C++ export can compile and run without Max).
