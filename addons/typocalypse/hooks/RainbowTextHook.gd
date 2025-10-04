extends TypewriterHook
class_name TypewriterRainbowHook

## Applies rainbow color cycling to the text as characters are emitted.
@export_node_path("RichTextLabel") var target_path: NodePath
@export_range(0.0, 1.0, 0.01) var hue_shift_per_char := 0.05
@export_range(0.0, 1.0, 0.01) var saturation := 1.0
@export_range(0.0, 1.0, 0.01) var value := 1.0
@export var animate_hue := true
@export_range(0.0, 5.0, 0.01) var animation_speed := 0.5

var _target: RichTextLabel = null
var _current_hue := 0.0
var _char_hues: Array[float] = []
var _animation_time := 0.0

func _on_effect_attached() -> void:
	_resolve_target()
	_current_hue = 0.0
	_char_hues.clear()
	_animation_time = 0.0
	print("[RAINBOW] Attached! Target: ", _target)
	if _target:
		print("[RAINBOW] BBCode enabled: ", _target.bbcode_enabled)

func _on_effect_detached() -> void:
	if _target and is_instance_valid(_target):
		# BBCode 태그를 제거하지 않고 그냥 남겨둠
		pass

func process(delta: float) -> void:
	if _target == null or not is_instance_valid(_target):
		_resolve_target()
	
	if _target == null:
		return
	
	if not _target.bbcode_enabled:
		print("[RAINBOW] BBCode is not enabled!")
		return
	
	if animate_hue:
		_animation_time += delta * animation_speed
		_update_rainbow_text()

func on_char(char: String, index: int, contexts: PackedStringArray) -> void:
	_char_hues.append(_current_hue)
	_current_hue = fmod(_current_hue + hue_shift_per_char, 1.0)
	print("[RAINBOW] Char added: '", char, "' hue: ", _char_hues[_char_hues.size()-1])
	_update_rainbow_text()

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
	
	# BBCode 활성화 확인
	if _target and _target is RichTextLabel:
		if not _target.bbcode_enabled:
			_target.bbcode_enabled = true
			print("[RAINBOW] Enabled BBCode on target")

func _update_rainbow_text() -> void:
	if _target == null or _char_hues.is_empty():
		return
	
	# TypewriterEffect에서 현재 표시 중인 텍스트 가져오기
	var typewriter = _effect as TypewriterEffect
	if typewriter == null:
		return
	
	var plain_text = typewriter.source_text.substr(0, typewriter.visible_len)
	var colored_text := ""
	
	for i in range(min(plain_text.length(), _char_hues.size())):
		var char = plain_text[i]
		var hue = _char_hues[i]
		
		# 애니메이션이 활성화되면 hue에 시간 기반 offset 추가
		if animate_hue:
			hue = fmod(hue + _animation_time, 1.0)
		
		var color = Color.from_hsv(hue, saturation, value)
		var hex_color = color.to_html(false)
		
		colored_text += "[color=#" + hex_color + "]" + char + "[/color]"
	
	# 커서 추가
	if typewriter.cursor_visible and (typewriter.is_playing or typewriter.cursor_persist_on_finish):
		colored_text += typewriter.cursor_symbol
	
	print("[RAINBOW] Setting text: ", colored_text.substr(0, 100))
	_target.text = colored_text

func on_finished() -> void:
	pass
