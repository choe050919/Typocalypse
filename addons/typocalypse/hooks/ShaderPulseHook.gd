extends TypewriterHook
class_name TypewriterShaderPulseHook

## Pulses a ShaderMaterial uniform each time a character is emitted.
@export_node_path("CanvasItem") var target_path: NodePath
@export var uniform_name := "pulse_strength"
@export_range(0.0, 10.0, 0.01) var pulse_value := 1.0
@export_range(0.0, 20.0, 0.01) var decay_rate := 4.0

var _target: CanvasItem = null
var _current := 0.0

func _on_effect_attached() -> void:
    _resolve_target()
    _apply_value(0.0)

func _on_effect_detached() -> void:
    _apply_value(0.0)

func process(delta: float) -> void:
    if _target == null:
        _resolve_target()
    if _target == null:
        return
    if _current <= 0.0:
        return
    _current = max(_current - decay_rate * delta, 0.0)
    _apply_value(_current)

func on_char(char: String, index: int, contexts: PackedStringArray) -> void:
    _current = pulse_value
    _apply_value(_current)

func _resolve_target() -> void:
    if _effect == null:
        return
    _target = _effect.get_node_or_null(target_path)

func _apply_value(value: float) -> void:
    if _target == null:
        return
    var mat: Material = _target.material
    if mat is ShaderMaterial:
        mat.set_shader_parameter(uniform_name, value)
