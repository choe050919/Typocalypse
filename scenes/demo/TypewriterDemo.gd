extends Node2D

const SfxHookScript := preload("res://addons/typocalypse/hooks/SfxHook.gd")
const ScreenShakeHookScript := preload("res://addons/typocalypse/hooks/ScreenShakeHook.gd")
const ShaderPulseHookScript := preload("res://addons/typocalypse/hooks/ShaderPulseHook.gd")
const RainbowHookScript := preload("res://addons/typocalypse/hooks/RainbowTextHook.gd")
const GlitchHookScript := preload("res://addons/typocalypse/hooks/GlitchTextHook.gd")

@onready var typewriter: TypewriterEffect = $TypewriterEffect
@onready var input_field: LineEdit = $CanvasLayer/UIRoot/MarginContainer/VBox/InputField
@onready var preset_option: OptionButton = $CanvasLayer/UIRoot/MarginContainer/VBox/PresetRow/PresetOption
@onready var output_label: RichTextLabel = $CanvasLayer/UIRoot/MarginContainer/VBox/OutputLabel
@onready var camera: Camera2D = $DemoCamera
@onready var sfx_player: AudioStreamPlayer = $TypeSfxPlayer

var _presets: Array = []

func _ready() -> void:
	# Camera를 화면 중앙에 배치
	var viewport_size = get_viewport_rect().size
	camera.position = viewport_size / 2.0
	
	# BBCode 강제 활성화
	output_label.bbcode_enabled = true
	print("[DEMO] BBCode enabled on OutputLabel: ", output_label.bbcode_enabled)
	
	typewriter.set_target(output_label)
	typewriter.finished.connect(_on_finished)
	_connect_controls()
	_load_presets()
	if _presets.is_empty():
		_presets.append({
			"name": "Fallback",
			"text": "This is the fallback preset.",
			"settings": {},
			"hooks": []
		})
		preset_option.add_item("Fallback", 0)
	if preset_option.item_count > 0:
		preset_option.select(0)
		_apply_preset(0)

func _connect_controls() -> void:
	$CanvasLayer/UIRoot/MarginContainer/VBox/ControlsRow/PlayButton.pressed.connect(_on_play_pressed)
	$CanvasLayer/UIRoot/MarginContainer/VBox/ControlsRow/PauseButton.pressed.connect(typewriter.pause)
	$CanvasLayer/UIRoot/MarginContainer/VBox/ControlsRow/StopButton.pressed.connect(_on_stop_pressed)
	$CanvasLayer/UIRoot/MarginContainer/VBox/ControlsRow/RewindButton.pressed.connect(_on_rewind_pressed)
	$CanvasLayer/UIRoot/MarginContainer/VBox/ControlsRow/SkipButton.pressed.connect(typewriter.skip_to_end)
	$CanvasLayer/UIRoot/MarginContainer/VBox/ControlsRow/SpeedHalfButton.pressed.connect(func() -> void:
		typewriter.set_speed(0.5))
	$CanvasLayer/UIRoot/MarginContainer/VBox/ControlsRow/SpeedNormalButton.pressed.connect(func() -> void:
		typewriter.set_speed(1.0))
	$CanvasLayer/UIRoot/MarginContainer/VBox/ControlsRow/SpeedDoubleButton.pressed.connect(func() -> void:
		typewriter.set_speed(2.0))
	preset_option.item_selected.connect(_apply_preset)

func _load_presets() -> void:
	if not FileAccess.file_exists("res://typocalypse/presets/typewriter.json"):
		return
	var file := FileAccess.open("res://typocalypse/presets/typewriter.json", FileAccess.READ)
	if file == null:
		return
	var data: Dictionary = JSON.parse_string(file.get_as_text())
	if typeof(data) != TYPE_DICTIONARY:
		return
	_presets = data.get("presets", [])
	preset_option.clear()
	for i in _presets.size():
		var preset: Dictionary = _presets[i]
		preset_option.add_item(preset.get("name", "Preset %d" % i), i)

func _apply_preset(index: int) -> void:
	if index < 0 or index >= _presets.size():
		return
	var preset: Dictionary = _presets[index]
	input_field.text = preset.get("text", input_field.text)
	var settings: Dictionary = preset.get("settings", {})
	if settings.has("base_delay_ms"):
		typewriter.base_delay_ms = settings["base_delay_ms"]
	if settings.has("punctuation_extra_delay_ms"):
		typewriter.punctuation_extra_delay_ms = settings["punctuation_extra_delay_ms"]
	if settings.has("whitespace_delay_multiplier"):
		typewriter.whitespace_delay_multiplier = settings["whitespace_delay_multiplier"]
	var cursor_symbol: String = settings.get("cursor_symbol", typewriter.cursor_symbol)
	typewriter.set_cursor(typewriter.cursor_visible, cursor_symbol, typewriter.cursor_blink_hz)
	typewriter.set_speed(1.0)
	var hook_names: Array = preset.get("hooks", [])
	var hooks: Array[TypewriterHook] = []
	for hook_name in hook_names:
		var hook := _build_hook(String(hook_name))
		if hook:
			hooks.append(hook)
	typewriter.set_hooks(hooks)

func _build_hook(hook_id: String) -> TypewriterHook:
	var hook: TypewriterHook = null
	
	match hook_id:
		"sfx":
			hook = TypewriterSfxHook.new()
			hook.player_path = sfx_player.get_path()
			hook.min_interval_ms = 80.0
		"shake":
			hook = TypewriterScreenShakeHook.new()
			hook.camera_path = camera.get_path()
			hook.trauma_per_char = 0.25
			hook.max_amplitude = 12.0
			hook.decay_rate = 4.0
		"shader":
			hook = TypewriterShaderPulseHook.new()
			hook.target_path = output_label.get_path()
			hook.pulse_value = 1.5
			hook.decay_rate = 5.0
			hook.uniform_name = "pulse_strength"
		"rainbow":
			var RainbowScript = load("res://addons/typocalypse/hooks/RainbowTextHook.gd")
			if RainbowScript:
				hook = RainbowScript.new()
				hook.target_path = output_label.get_path()
				hook.hue_shift_per_char = 0.08
				hook.saturation = 1.0
				hook.value = 1.0
				hook.animate_hue = true
				hook.animation_speed = 0.3
		"glitch":
			var GlitchScript = load("res://addons/typocalypse/hooks/GlitchTextHook.gd")
			if GlitchScript:
				hook = GlitchScript.new()
				hook.target_path = output_label.get_path()
				hook.glitch_chance = 0.2
				hook.glitch_duration = 0.15
				hook.glitch_chars = "!@#$%^&*01▓░▒█"
	
	return hook

func _on_play_pressed() -> void:
	var text := input_field.text
	if text.is_empty():
		text = "Please enter text to play."
	if typewriter.is_paused() and typewriter.is_playing:
		typewriter.resume()
	else:
		typewriter.play(text)

func _on_stop_pressed() -> void:
	typewriter.stop()

func _on_rewind_pressed() -> void:
	typewriter.rewind(10)

func _on_finished() -> void:
	typewriter.set_cursor(typewriter.cursor_visible, typewriter.cursor_symbol, typewriter.cursor_blink_hz)

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		if typewriter.finished.is_connected(_on_finished):
			typewriter.finished.disconnect(_on_finished)
