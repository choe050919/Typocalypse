extends TypewriterHook
class_name TypewriterGlitchHook

## Applies random glitch effect to characters
@export_node_path("RichTextLabel") var target_path: NodePath
@export_range(0.0, 1.0, 0.01) var glitch_chance := 0.15
@export_range(0.0, 1.0, 0.01) var glitch_duration := 0.1
@export var glitch_chars := "!@#$%^&*(){}[]<>?/\\|~`"

var _target: RichTextLabel = null
var _glitched_indices: Dictionary = {}
var _rng := RandomNumberGenerator.new()

func should_handle_rendering() -> bool:
	return true

func _on_effect_attached() -> void:
	_resolve_target()
	_glitched_indices.clear()
	_rng.randomize()

func _on_effect_detached() -> void:
	pass

func process(delta: float) -> void:
	if _target == null or not is_instance_valid(_target):
		_resolve_target()
		return
	
	# 글리치 타이머 업데이트
	var to_remove := []
	for idx in _glitched_indices.keys():
		_glitched_indices[idx] -= delta
		if _glitched_indices[idx] <= 0.0:
			to_remove.append(idx)
	
	for idx in to_remove:
		_glitched_indices.erase(idx)
	
	if not _glitched_indices.is_empty() or to_remove.size() > 0:
		_update_glitch_text()

func on_char(char: String, index: int, contexts: PackedStringArray) -> void:
	if _rng.randf() < glitch_chance:
		_glitched_indices[index] = glitch_duration
	
	_update_glitch_text()

func _resolve_target() -> void:
	if _effect == null or not is_instance_valid(_effect):
		return
	
	if target_path.is_empty():
		return
	
	var root = _effect.get_tree().root if _effect.is_inside_tree() else null
	if root:
		_target = root.get_node_or_null(target_path)
	
	if _target == null:
		_target = _effect.get_node_or_null(target_path)
	
	if _target and _target is RichTextLabel:
		if not _target.bbcode_enabled:
			_target.bbcode_enabled = true

func _update_glitch_text() -> void:
	if _target == null:
		return
	
	var typewriter = _effect as TypewriterEffect
	if typewriter == null:
		return
	
	var plain_text = typewriter.source_text.substr(0, typewriter.visible_len)
	var glitched_text := ""
	
	for i in range(plain_text.length()):
		var char = plain_text[i]
		
		if _glitched_indices.has(i):
			var glitch_char = glitch_chars[_rng.randi() % glitch_chars.length()]
			var glitch_color = Color(
				_rng.randf_range(0.5, 1.0),
				_rng.randf_range(0.0, 0.5),
				_rng.randf_range(0.5, 1.0)
			)
			glitched_text += "[color=#" + glitch_color.to_html(false) + "]" + glitch_char + "[/color]"
		else:
			glitched_text += char
	
	if typewriter.cursor_visible and (typewriter.is_playing or typewriter.cursor_persist_on_finish):
		if typewriter._cursor_state:
			glitched_text += typewriter.cursor_symbol
	
	_target.text = glitched_text

func on_finished() -> void:
	pass
