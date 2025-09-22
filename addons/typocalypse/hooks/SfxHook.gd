extends TypewriterHook
class_name TypewriterSfxHook

## Plays an AudioStreamPlayer each time a character is emitted.
@export_node_path("AudioStreamPlayer") var player_path: NodePath
@export var min_interval_ms := 40.0

var _player: AudioStreamPlayer = null
var _elapsed_ms := 0.0

func _on_effect_attached() -> void:
    _resolve_player()
    _elapsed_ms = min_interval_ms

func process(delta: float) -> void:
    _elapsed_ms += delta * 1000.0

func on_char(char: String, index: int, contexts: PackedStringArray) -> void:
    if _player == null:
        _resolve_player()
    if _player == null:
        return
    if _elapsed_ms < min_interval_ms:
        return
    _elapsed_ms = 0.0
    if _player.stream == null:
        return
    _player.play()

func _resolve_player() -> void:
    if _effect == null:
        return
    _player = _effect.get_node_or_null(player_path)
