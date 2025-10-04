extends Resource
class_name TypewriterHook

## Base resource for customizing the typewriter effect behaviour.
## Implementers can override the callbacks to react to emitted characters, words or the end of playback.
var _effect: Node = null

func set_effect(effect: Node) -> void:
	_effect = effect
	_on_effect_attached()

func clear_effect() -> void:
	_on_effect_detached()
	_effect = null

func _on_effect_attached() -> void:
	pass

func _on_effect_detached() -> void:
	pass

func on_char(char: String, index: int, contexts: PackedStringArray) -> void:
	pass

func on_word(word: String, word_index: int, contexts: PackedStringArray) -> void:
	pass

func on_finished() -> void:
	pass

func process(delta: float) -> void:
	pass
