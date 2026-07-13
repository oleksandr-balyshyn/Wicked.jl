# Graphics API

The stable graphics surface covers terminal image capability detection, image
sources, protocol encoding, Unicode fallback rendering, image registration,
terminal animation state, and frame-scoped graphics emission.

Use these APIs when an application needs images or media widgets that can run on
different Linux terminal capabilities:

- `detect_graphics_capabilities` and `select_graphics_protocol` choose Kitty,
  Sixel, Unicode fallback, or no graphics from explicit configuration and
  terminal responses.
- `RasterImage`, `EncodedImage`, and `SixelPayload` model the image inputs that
  can be encoded or displayed.
- `ImagePlacement`, `encode_graphics`, and `delete_graphics` produce terminal
  protocol commands without mutating application state.
- `unicode_fallback` returns deterministic cell-sized color samples for terminals
  without native image support.
- `ImageRegistry` deduplicates image ids and reference counts across frames.
- `GraphicsLayer` batches graphics for a frame and commits them through
  `IOGraphicsSink` or `TestGraphicsSink`.
- `AnimationFrame` and `TerminalAnimation` provide explicit, testable image
  animation state.

Protocol support is capability-driven. Production applications should keep
Unicode fallback paths and run manual release checks on the terminal emulators
they support.

For a runnable public-API example with a deterministic raster fixture and
Unicode fallback rendering, see
[`examples/graphics_quickstart.jl`](examples/graphics_quickstart.jl).

## Release evidence

Headless buffers and `TestGraphicsSink` prove encoding, fallback, and frame-layer
behavior, but they do not prove that a real terminal displays images correctly.
Before claiming production graphics parity, record Linux real-terminal evidence
with [`TERMINAL_EVIDENCE_TEMPLATE.md`](TERMINAL_EVIDENCE_TEMPLATE.md) for the
terminal categories that the release supports:

- Minimal ANSI or 16-color terminals must use Unicode fallback and must not emit
  Kitty or Sixel control sequences.
- Kitty or WezTerm runs must cover capability detection, image placement,
  clipping, resize, cleanup, and fallback when Kitty graphics is disabled.
- Sixel-capable terminal runs must cover Sixel payload emission, clipping,
  cleanup, and fallback when Sixel is disabled or unavailable.
- tmux, GNU screen, SSH, and redirected-output runs must record capability
  downgrade behavior and confirm unsupported graphics protocols are not emitted.

Archive screenshots, terminal recordings, or transcripts with the completed
terminal evidence record. CI and headless examples are necessary regression
coverage, but they are not a substitute for these real-terminal observations.

```@autodocs
Modules = [
    Wicked.Graphics,
    Wicked.GraphicsBackend,
]
Private = false
```
