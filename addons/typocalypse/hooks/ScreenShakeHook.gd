extends TypewriterHook
class_name TypewriterScreenShakeHook

## Applies a lightweight trauma based screen shake to a Camera2D when characters are emitted.
@export_node_path("Camera2D") var camera_path: NodePath
@export_range(0.0, 10.0, 0.01) var trauma_per_char := 0.1
@export_range(0.0, 50.0, 0.01) var max_amplitude := 10.0
@export_range(0.0, 20.0, 0.01) var decay_rate := 4.0

var _camera: Camera2D = null
var _trauma := 0.0
var _rng := RandomNumberGenerator.new()

func _on_effect_attached() -> void:
    _resolve_camera()
    _rng.randomize()

func _on_effect_detached() -> void:
    if _camera:
        _camera.offset = Vector2.ZERO

func process(delta: float) -> void:
    if _camera == null:
        _resolve_camera()
    if _camera == null:
        return
    if _trauma <= 0.0:
        _camera.offset = Vector2.ZERO
        return
    _trauma = max(_trauma - decay_rate * delta, 0.0)
    var shake = _trauma * _trauma * max_amplitude
    var offset = Vector2(
        _rng.randf_range(-shake, shake),
        _rng.randf_range(-shake, shake)
    )
    _camera.offset = offset

func on_char(char: String, index: int, contexts: PackedStringArray) -> void:
    _trauma = min(1.0, _trauma + trauma_per_char)

func _resolve_camera() -> void:
    if _effect == null:
        return
    _camera = _effect.get_node_or_null(camera_path)
