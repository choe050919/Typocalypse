# Typocalypse Typewriter Effect

1. Add the `TypewriterEffect` node next to a `Label` or `RichTextLabel` and assign its `target_path`.
2. Call `play(text)` with optional delay, then use `pause()`, `resume()`, `stop()`, `skip_to_end()`, or `rewind(chars)` to control playback.
3. Adjust timings through the exported properties or at runtime using `set_speed(mult)`.
4. Toggle the cursor appearance via `set_cursor(visible, symbol, blink_hz)`.
5. Receive `char_emitted`, `word_emitted`, and `finished` signals to chain behaviours.
6. Inject SFX, screen shake, or shader pulses by creating hook resources and passing them to `set_hooks()`.
7. Load and preview presets in the demo scene: `scenes/demo/TypewriterDemo.tscn`.
8. Use the JSON file at `typocalypse/presets/typewriter.json` to define new preset configurations.
