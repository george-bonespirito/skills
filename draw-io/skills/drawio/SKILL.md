---
name: drawio
description: Always use when user asks to create, generate, draw, or design a diagram, flowchart, architecture diagram, ER diagram, sequence diagram, class diagram, network diagram, mockup, wireframe, or UI sketch, or mentions draw.io, drawio, drawoi, .drawio files, or diagram export to PNG/SVG/PDF.
license: MIT
metadata:
  version: 0.1.0
  house-theme: adaptiveColors flat palette, readable in light/dark
---

# Draw.io Diagram Skill

Generate editable draw.io diagrams and export them as **SVG with the diagram XML embedded** — the headline deliverable. The exported `.drawio.svg` renders in any Markdown/browser/VS Code preview *and* reopens in draw.io for editing, because the source XML travels inside it. A house theme (below) keeps every diagram readable in both light and dark preview.

## Prerequisite — draw.io Desktop

The SVG/PNG/PDF export and the Mermaid→`.drawio` conversion run through the **draw.io Desktop** command-line binary. Install it first (`drawio` on PATH, or the platform path in [Locating the CLI](#locating-the-cli)); without it, only the [degraded XML/URL path](#no-cli-fallback) is available. This is a GUI host app — it cannot be bundled with the skill.

Detect it before authoring:

```bash
command -v drawio >/dev/null 2>&1 && echo "CLI present" || echo "no CLI — XML/URL fallback"
```

## House theme — apply to every diagram

Fold these into the mxGraphModel and cell styles unless the user asks otherwise. This is the visual contract; the [example](#canonical-example) is the reference to imitate.

- `adaptiveColors="auto"` on `<mxGraphModel>` — colors adapt to light/dark, so the SVG reads well in both VS Code light and dark preview. Non-negotiable for the SVG deliverable.
- **Flat pastel palette** — the `plain-*` draw.io fills, **no** `shadow`, `glass`, gradient, or sketch. Less visual noise.
- Soft corners: `rounded=1;arcSize=6`.
- Readable type: `fontSize=13;fontFamily=Helvetica;`; titles `fontStyle=1`. Body text `#333333`, never mass pure black.
- Edges: `edgeStyle=orthogonalEdgeStyle;rounded=1;strokeWidth=1.5;` — orthogonal, no curves.
- Generous spacing: nodes ≥ 120×60, gaps ≥ 40px.

Base palette (fill / stroke):

| Role | Fill | Stroke |
|------|------|--------|
| neutral | `#F5F5F5` | `#666666` |
| blue | `#DAE8FC` | `#6C8EBF` |
| green | `#D5E8D4` | `#82B366` |
| amber | `#FFF2CC` | `#D6B656` |
| red | `#F8CECC` | `#B85450` |
| purple | `#E1D5E7` | `#9673A6` |

## Authoring: Mermaid or XML?

Two ways to author, both ending as a native `.drawio`:

| Author as | Best for | Needs CLI? |
|-----------|----------|------------|
| **Mermaid** | Flowchart, sequence, class, state, ER, gantt, mindmap, timeline, C4, git graph, pie, and other standard types | Yes — CLI converts and auto-lays-out |
| **XML** | Custom styling, precise positioning, specific shape libraries (AWS, Azure, UML detail), or when the CLI is absent | No (optional ELK `--layout` needs the CLI) |

Prefer **Mermaid** when the CLI is present and the request is a standard type — write terse Mermaid and let draw.io lay it out; auto-layout beats hand-positioning cells. Use **XML** for control or as the universal fallback (works with no CLI at all).

## The pipeline

Every diagram becomes a native `.drawio` first, then is delivered in the requested format.

1. **Author → `.drawio`**
   - **Mermaid**: write to a `.mmd`, convert, then delete the `.mmd` (the `.drawio` is the artifact — draw.io already laid it out, no `--layout` needed):
     ```bash
     drawio -x -f xml -o diagram.drawio diagram.mmd
     ```
   - **XML**: write the mxGraphModel to `diagram.drawio` (see [XML format](#xml-format)); optionally apply an [ELK layout](#elk-layout-for-xml).
2. **Deliver**
   - *(no format)* → keep `diagram.drawio`, open it.
   - **svg / png / pdf** → export with embedded XML, then delete the source `.drawio`:
     ```bash
     drawio -x -f svg -e -b 10 -o diagram.drawio.svg diagram.drawio
     ```
   - **url** → build a browser URL from the XML, open it, keep the `.drawio` locally (see [Browser URL output](#browser-url-output)).
3. **Open the result.** If the open command fails, print the absolute path or URL so the user can open it manually.

**Always convert Mermaid to `.drawio` first, then export** — never export a `.mmd` straight to an image. Direct Mermaid→PNG with `-e` crashes on the embedded-XML step in current draw.io Desktop; the two-step path is reliable and produces an editable embed (see [Troubleshooting](#troubleshooting)).

<a id="no-cli-fallback"></a>
### No-CLI fallback

If the CLI is absent: author the diagram directly as XML and deliver a `.drawio` file or a `url`. Mermaid conversion, ELK layout, and image export all require the desktop app — tell the user installing draw.io Desktop unlocks the SVG deliverable and Mermaid.

<a id="canonical-example"></a>
## Canonical example

[`examples/c4-order-service.md`](examples/c4-order-service.md) walks through a C4 container diagram delivered as [`c4-order-service.drawio.svg`](examples/c4-order-service.drawio.svg) — the house theme applied end-to-end (adaptiveColors, flat palette, orthogonal edges, embedded editable XML). Imitate its structure and styling when generating similar architecture diagrams.

## ELK layout for XML

XML-authored diagrams can be auto-positioned by the CLI's `--layout` pass — the same ELK layouts as the editor's *Arrange ▸ Layout* menu. Generate cells with approximate (or `0,0`) positions and let ELK place them; you only need the graph *structure* right.

```bash
drawio -x -f xml --layout verticalFlow -o diagram.drawio diagram.drawio
```

Presets: `verticalFlow` (layered top-to-bottom — flowcharts, pipelines), `horizontalFlow` (left-to-right), `verticalTree` / `horizontalTree` (hierarchies, org charts), `radialTree`, `organic` (force-directed — networks).

For finer control, pass a JSON **array** instead of a preset — same format as the editor's custom-layout dialog:

```bash
drawio -x -f xml --layout '[{"layout":"elkLayered","config":{"elk.direction":"RIGHT"}}]' -o diagram.drawio diagram.drawio
```

Algorithms: `elkLayered`, `elkTree`, `elkRadial`, `elkOrganic`, `elkStress`, `elkBox`. `config` keys starting with `elk.` are ELK options (`elk.direction`, `elk.spacing.nodeNode`, `elk.layered.spacing.nodeNodeBetweenLayers`); `edgeStyle` and `corners` control connector rendering.

**Orthogonal edge routing** — `--layout libavoid` routes edges orthogonally around shapes without moving any vertex, the complement of the node layouts. Use it on hand-positioned XML whose connectors cross shapes; skip it after a flow/tree preset (those already route their edges). Mermaid-authored diagrams are already laid out — don't add `--layout`.

## Choosing the output format

Read the request for a format cue. If none is mentioned, produce the `.drawio` and open it — the user can export later.

| Format | Embeds XML | Notes |
|--------|-----------|-------|
| `svg` | Yes (`-e`) | **Default deliverable** — scalable, editable in draw.io, adaptiveColors renders in light/dark |
| `png` | Yes (`-e`) | Viewable everywhere, editable in draw.io |
| `pdf` | Yes (`-e`) | Printable, editable in draw.io |
| `jpg` | No | Lossy, no embedded XML |

## Browser URL output

For `url` format, generate a draw.io URL that opens the diagram in the browser editor at `app.diagrams.net` — no Desktop needed to *view* it (Mermaid still needs the CLI to convert to `.drawio` first; if absent, author as XML and build the URL from that). The `.drawio` is still written to disk as the persistent local copy.

Generate the URL with Node's built-in `zlib` (no external deps):

```bash
URL=$(node -e '
const fs = require("fs");
const zlib = require("zlib");
const xml = fs.readFileSync(process.argv[1], "utf8");
const compressed = zlib.deflateRawSync(encodeURIComponent(xml)).toString("base64");
const payload = encodeURIComponent(JSON.stringify({ type: "xml", compressed: true, data: compressed }));
console.log("https://app.diagrams.net/?grid=0&pv=0&border=10&edit=_blank#create=" + payload);
' "DIAGRAM.drawio")
```

Open it — `open "$URL"` (macOS), `xdg-open "$URL"` (Linux). On **Windows/WSL2**, `cmd.exe`'s `start` treats `&` as a separator and strips everything after `#`, silently dropping the `#create=...` payload. Write a `.url` shortcut file instead and open that (the path never contains `&`):

```bash
TMPFILE=$(node -e '
const fs = require("fs"), os = require("os"), path = require("path");
const p = path.join(os.tmpdir(), "drawio.url");
fs.writeFileSync(p, "[InternetShortcut]\r\nURL=" + process.argv[1] + "\r\n");
process.stdout.write(p);
' "$URL")
cmd.exe /c start "" "$TMPFILE"   # WSL2/Windows
```

Print the URL and confirm the local path. Very large diagrams may exceed browser URL length limits (~32K–2MB) — fall back to writing the `.drawio` and opening it locally.

## draw.io CLI

The desktop binary handles **Mermaid conversion**, **ELK layouts**, and **export** — all three need the app installed.

### Locating the CLI

Detect the environment, then locate the binary:

- **Linux (native)**: `drawio` — usually on PATH via snap/apt/flatpak.
- **macOS**: `/Applications/draw.io.app/Contents/MacOS/draw.io`.
- **WSL2** (detect: `grep -qi microsoft /proc/version`): use the Windows binary via `/mnt/c/...`, double-quoted (never backticked — backticks execute it at locate-time):
  ```bash
  DRAWIO_CMD="/mnt/c/Program Files/draw.io/draw.io.exe"
  # per-user fallback: "/mnt/c/Users/$WIN_USER/AppData/Local/Programs/draw.io/draw.io.exe"
  ```
- **Windows (native)**: `"C:\Program Files\draw.io\draw.io.exe"`.

Use `which drawio` (or `where draw.io` on Windows) before falling back to a platform path.

### Key export flags

```bash
drawio -x -f <format> -e -b 10 -o "<output>" "<input.drawio>"
```

- `-x` / `--export`: export mode (also used for conversion and layout passes)
- `-f` / `--format`: `xml` (produce `.drawio` from Mermaid/layout), svg, png, pdf, jpg
- `-e` / `--embed-diagram`: embed diagram XML in the output (svg/png/pdf only) — **required** for the editable deliverable
- `--layout`: run an ELK preset, `libavoid`, or a custom-layout JSON array before writing
- `-b` / `--border`: border width (default 0)
- `-t` / `--transparent`: transparent background (PNG only)
- `-s` / `--scale`, `--width` / `--height`: sizing
- `-a` / `--all-pages`, `-p` / `--page-index`: page selection (PDF)
- `--mermaid-image 1`: convert Mermaid to a single static SVG image cell instead of an editable diagram — only when the user explicitly asks for a non-editable image

### Opening the result

`open <file>` (macOS), `xdg-open <file>` (Linux), `cmd.exe /c start "" "$(wslpath -w <file>)"` (WSL2 — `wslpath -w` converts to a Windows path; the empty `""` stops `start` reading the filename as a window title), `start <file>` (Windows).

## File naming

- Descriptive, lowercase-hyphen names (`login-flow`, `database-schema`).
- Mermaid → matching `.mmd`, convert to `.drawio`, delete the `.mmd`.
- Export uses double extensions — `name.drawio.svg` / `.drawio.png` / `.drawio.pdf` — signalling embedded XML. Delete the intermediate `.drawio` after export.
- For `url` mode, keep the `.drawio` (no double extension) — the URL is a view/edit handle, the file is the persistent copy.

## XML format

A `.drawio` file is native mxGraphModel XML. Every diagram needs this structure:

```xml
<mxGraphModel adaptiveColors="auto">
  <root>
    <mxCell id="0"/>
    <mxCell id="1" parent="0"/>
  </root>
</mxGraphModel>
```

Cell `id="0"` is the root layer, `id="1"` the default parent; diagram elements use `parent="1"` unless using multiple layers.

For the full XML reference (styles, edge routing, containers, layers, tags, metadata, dark-mode colors), fetch: `https://raw.githubusercontent.com/jgraph/drawio-mcp/main/shared/xml-reference.md`. For Mermaid syntax across all diagram types plus flowchart styling (`style`, `classDef`, `linkStyle`): `https://raw.githubusercontent.com/jgraph/drawio-mcp/main/shared/mermaid-reference.md`. Match diagram label language to the user's.

## Troubleshooting

| Problem | Cause | Fix |
|---------|-------|-----|
| CLI not found | Desktop app missing/not on PATH | Author as XML, deliver `.drawio` or `url`; tell user to install draw.io Desktop for SVG + Mermaid |
| Mermaid → PNG crashes | Direct `.mmd`→PNG with `-e` broken in current Desktop | Two-step: convert to `.drawio` first (`-f xml`), then export |
| Blank diagram from Mermaid | Misspelled type keyword or syntax error | First non-directive line's keyword selects the type; check the Mermaid reference |
| Layout does nothing | Unknown preset, JSON not an array, or old Desktop build | Use a valid preset or a `[`-array; update draw.io Desktop |
| Empty/corrupt export | Invalid XML (comments, unescaped chars) | Validate well-formedness (below) |
| Diagram blank | Missing root cells `id="0"`/`id="1"` | Complete the mxGraphModel structure |
| Edges not rendering | Edge mxCell self-closing | Every edge needs `<mxGeometry relative="1" as="geometry" />` as a child |
| Empty diagram in `url` mode | `cmd.exe` stripped `#create=...` | Use the `.url` temp-file workaround — never pass the URL directly to `cmd.exe /c start` |

## CRITICAL: XML well-formedness

- **NEVER emit XML comments (`<!-- -->`) in output** — forbidden; they waste tokens and can cause parse errors.
- Escape special chars in attribute values: `&amp;`, `&lt;`, `&gt;`, `&quot;`.
- Every `mxCell` needs a unique `id`.

---

*Diagram pipeline built on the [draw.io Desktop](https://www.drawio.com/) CLI (draw.io / diagrams.net by JGraph Ltd). This skill is original work under MIT; draw.io itself is a separate project under its own license.*
