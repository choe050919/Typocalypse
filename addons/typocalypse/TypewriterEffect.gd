extends Node
class_name TypewriterEffect

signal char_emitted(index: int, char: String)
signal word_emitted(word_index: int, word: String)
signal finished()

@export_node_path("CanvasItem") var target_path: NodePath
@export_range(1.0, 500.0, 1.0) var base_delay_ms := 45.0
@export_range(0.0, 3000.0, 1.0) var default_start_delay_ms := 0.0
@export_range(0.1, 5.0, 0.01) var min_speed_multiplier := 0.1
@export_range(0.1, 5.0, 0.01) var max_speed_multiplier := 5.0
@export_range(1, 32, 1) var max_chars_per_frame := 8
@export var queue_requests := false
@export_range(0.0, 400.0, 1.0) var punctuation_extra_delay_ms := 120.0
@export_range(0.0, 1.0, 0.01) var whitespace_delay_multiplier := 0.35
@export_range(0.0, 400.0, 1.0) var acceleration_per_char_ms := 0.0
@export_range(1.0, 500.0, 1.0) var minimum_delay_ms := 20.0
@export var cursor_visible := true
@export var cursor_symbol := "_"
@export_range(0.5, 20.0, 0.1) var cursor_blink_hz := 2.5
@export var cursor_persist_on_finish := false
@export var default_hooks: Array[TypewriterHook] = []

var source_text := ""
var visible_len := 0
var is_playing := false
var speed_mult := 1.0

var _target: CanvasItem = null
var _target_is_rich := false
var _char_structs: Array = []
var _accumulator := 0.0
var _start_delay_s := 0.0
var _is_paused := false
var _dynamic_delay_ms := 0.0
var _display_cache := ""
var _cursor_timer := 0.0
var _cursor_state := true
var _word_buffer := ""
var _word_index := 0
var _pending_word_contexts := PackedStringArray()
var _play_queue: Array = []
var _finished_emitted := false
var _active_hooks: Array[TypewriterHook] = []

const WORD_BREAK_CHARS := [".", ",", "!", "?", ";", ":"]

func _ready() -> void:
    set_process(true)
    _resolve_target()
    set_hooks(default_hooks)

func _process(delta: float) -> void:
    if not is_inside_tree():
        return
    _update_cursor(delta)
    for hook in _active_hooks:
        hook.process(delta)
    if not is_playing or _is_paused:
        return
    if not _ensure_target():
        stop()
        return
    if _start_delay_s > 0.0:
        _start_delay_s -= delta
        if _start_delay_s > 0.0:
            return
        _accumulator += -_start_delay_s
    _accumulator += delta
    var emitted := 0
    while visible_len < _char_structs.size() and emitted < max_chars_per_frame:
        var delay_s := _compute_delay_for_index(visible_len)
        if _accumulator < delay_s:
            break
        _accumulator -= delay_s
        _emit_next_char()
        emitted += 1
    if visible_len >= _char_structs.size():
        _finish_sequence()

func play(text: String, start_delay_ms := -1.0) -> void:
    ## Starts the typewriter playback for the provided text.
    ## If already playing it will either queue or replace the current playback depending on queue_requests.
    if start_delay_ms < 0.0:
        start_delay_ms = default_start_delay_ms
    if is_playing:
        if queue_requests:
            _play_queue.append({"text": text, "delay": start_delay_ms})
            return
        _interrupt()
    _begin_playback(text, start_delay_ms)

func pause() -> void:
    ## Pauses playback without resetting the current progress.
    _is_paused = true

func resume() -> void:
    ## Resumes playback if previously paused.
    if is_playing:
        _is_paused = false

func stop(reset := true) -> void:
    ## Stops playback. Optionally clears the displayed text and pending queue.
    if not is_playing:
        if reset:
            _reset_display()
        return
    _interrupt()
    if reset:
        _reset_display()
    _play_queue.clear()

func set_speed(mult: float) -> void:
    ## Sets the playback speed multiplier. Valid range is clamped between the exported min and max values.
    speed_mult = clamp(mult, min_speed_multiplier, max_speed_multiplier)

func is_paused() -> bool:
    ## Returns true when the effect is currently paused.
    return _is_paused

func skip_to_end() -> void:
    ## Immediately reveals the full text and emits the finished signal once.
    if not is_playing:
        return
    for i in range(visible_len, _char_structs.size()):
        _consume_char_for_word_state(_char_structs[i], true)
    visible_len = _char_structs.size()
    _apply_visible_text(true)
    _finish_sequence()

func rewind(chars: int) -> void:
    ## Rewinds the playback by the requested character count.
    if chars <= 0:
        return
    visible_len = max(visible_len - chars, 0)
    _accumulator = 0.0
    _dynamic_delay_ms = base_delay_ms
    _rebuild_word_tracking()
    _apply_visible_text()

func set_cursor(visible: bool, symbol := "_", blink_hz := 2.0) -> void:
    ## Configures the cursor visibility and blink behaviour.
    cursor_visible = visible
    cursor_symbol = symbol
    cursor_blink_hz = blink_hz
    _cursor_state = true
    _cursor_timer = 0.0
    _apply_visible_text()

func set_hooks(hooks: Array[TypewriterHook]) -> void:
    ## Replaces the active hooks with the provided array.
    for hook in _active_hooks:
        hook.clear_effect()
    _active_hooks.clear()
    if hooks == null:
        return
    for hook in hooks:
        if hook == null:
            continue
        _active_hooks.append(hook)
        hook.set_effect(self)

func set_target(target: CanvasItem) -> void:
    ## Overrides the label or rich text label target used for rendering.
    if target == null:
        target_path = NodePath("")
    else:
        target_path = target.get_path()
    _resolve_target()
    _apply_visible_text(true)

func resume_next_in_queue() -> void:
    if _play_queue.is_empty():
        return
    var job = _play_queue[0]
    _play_queue.remove_at(0)
    _begin_playback(job["text"], job["delay"])

func _resolve_target() -> void:
    if not is_inside_tree():
        return
    if target_path.is_empty():
        _target = null
        return
    var node = get_node_or_null(target_path)
    if node and (node is Label or node is RichTextLabel):
        _target = node
        _target_is_rich = node is RichTextLabel
    else:
        _target = null

func _ensure_target() -> bool:
    if _target and is_instance_valid(_target):
        return true
    _resolve_target()
    return _target != null

func _begin_playback(text: String, start_delay_ms: float) -> void:
    var parsed := _parse_text(text)
    source_text = parsed["plain"]
    _char_structs = parsed["chars"]
    visible_len = 0
    _accumulator = 0.0
    _start_delay_s = max(start_delay_ms, 0.0) / 1000.0
    _dynamic_delay_ms = base_delay_ms
    _word_buffer = ""
    _pending_word_contexts = PackedStringArray()
    _word_index = 0
    _finished_emitted = false
    is_playing = true
    _is_paused = false
    _cursor_state = true
    _cursor_timer = 0.0
    speed_mult = clamp(speed_mult, min_speed_multiplier, max_speed_multiplier)
    _apply_visible_text(true)

func _interrupt() -> void:
    is_playing = false
    _is_paused = false

func _finish_sequence() -> void:
    if not is_playing:
        return
    _flush_pending_word(true)
    is_playing = false
    if not _finished_emitted:
        _finished_emitted = true
        emit_signal("finished")
        for hook in _active_hooks:
            hook.on_finished()
    if not _play_queue.is_empty():
        resume_next_in_queue()
    else:
        if not cursor_persist_on_finish:
            _cursor_state = false
            _apply_visible_text(true)

func _emit_next_char() -> void:
    var data = _char_structs[visible_len]
    visible_len += 1
    _apply_visible_text()
    emit_signal("char_emitted", visible_len - 1, data.char)
    for hook in _active_hooks:
        hook.on_char(data.char, visible_len - 1, data.contexts)
    _consume_char_for_word_state(data, true)
    if data.char.is_space() or data.char in WORD_BREAK_CHARS:
        _dynamic_delay_ms = base_delay_ms
    else:
        _dynamic_delay_ms = max(minimum_delay_ms, _dynamic_delay_ms - acceleration_per_char_ms)

func _apply_visible_text(force := false) -> void:
    var base_text := ""
    if visible_len > 0:
        base_text = source_text.substr(0, visible_len)
    var cursor_text := ""
    if cursor_visible and (is_playing or cursor_persist_on_finish):
        if _cursor_state:
            cursor_text = cursor_symbol
    var final_text := base_text + cursor_text
    if not force and final_text == _display_cache:
        return
    _display_cache = final_text
    if _ensure_target():
        if _target_is_rich:
            (_target as RichTextLabel).bbcode_text = final_text
        elif _target is Label:
            (_target as Label).text = final_text

func _compute_delay_for_index(index: int) -> float:
    if _char_structs.is_empty():
        return base_delay_ms / 1000.0
    var data = _char_structs[index]
    var delay := _dynamic_delay_ms
    if data.char.is_space():
        delay = base_delay_ms * whitespace_delay_multiplier
    elif data.char in WORD_BREAK_CHARS:
        delay = base_delay_ms + punctuation_extra_delay_ms
    delay = max(minimum_delay_ms, delay)
    delay = delay / clamp(speed_mult, min_speed_multiplier, max_speed_multiplier)
    return delay / 1000.0

func _parse_text(text: String) -> Dictionary:
    var result: Array = []
    var contexts: Array[String] = []
    var i := 0
    var plain := ""
    while i < text.length():
        var ch := text[i]
        if ch == "[":
            var close_idx := text.find("]", i)
            if close_idx == -1:
                result.append(_make_char_entry(ch, contexts))
                plain += ch
                i += 1
                continue
            var tag := text.substr(i + 1, close_idx - i - 1)
            if tag.begins_with("FX:"):
                contexts.append(tag.substr(3, tag.length() - 3))
            elif tag.begins_with("/FX") and not contexts.is_empty():
                contexts.pop_back()
            i = close_idx + 1
            continue
        result.append(_make_char_entry(ch, contexts))
        plain += ch
        i += 1
    return {"chars": result, "plain": plain}

func _make_char_entry(ch: String, contexts: Array[String]) -> Dictionary:
    var entry_contexts := PackedStringArray()
    for ctx in contexts:
        entry_contexts.append(ctx)
    return {"char": ch, "contexts": entry_contexts}

func _flush_pending_word(emit_signal_flag: bool) -> void:
    if _word_buffer.is_empty():
        return
    if emit_signal_flag:
        emit_signal("word_emitted", _word_index, _word_buffer)
        for hook in _active_hooks:
            hook.on_word(_word_buffer, _word_index, _pending_word_contexts)
    _word_buffer = ""
    _word_index += 1

func _consume_char_for_word_state(data: Dictionary, emit_signals: bool) -> void:
    var ch: String = data.char
    if not ch.is_space() and not (ch in WORD_BREAK_CHARS):
        _word_buffer += ch
        _pending_word_contexts = data.contexts
        return
    _flush_pending_word(emit_signals)

func _rebuild_word_tracking() -> void:
    _word_buffer = ""
    _word_index = 0
    _pending_word_contexts = PackedStringArray()
    for i in range(visible_len):
        _consume_char_for_word_state(_char_structs[i], false)

func _reset_display() -> void:
    visible_len = 0
    _word_buffer = ""
    _word_index = 0
    _pending_word_contexts = PackedStringArray()
    _display_cache = ""
    if _ensure_target():
        if _target_is_rich:
            (_target as RichTextLabel).bbcode_text = ""
        else:
            (_target as Label).text = ""

func _update_cursor(delta: float) -> void:
    if not cursor_visible:
        return
    if not is_playing and not cursor_persist_on_finish:
        return
    if cursor_blink_hz <= 0.0:
        return
    _cursor_timer += delta
    var blink_period := 1.0 / cursor_blink_hz
    if _cursor_timer >= blink_period:
        _cursor_timer -= blink_period
        _cursor_state = not _cursor_state
        _apply_visible_text()
