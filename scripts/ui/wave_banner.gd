class_name WaveBanner
extends Control

const WAVE_FONT_SIZE: int = 20
const BOSS_FONT_SIZE: int = 28
const WAVE_COLOR: Color = Color(0.15, 0.15, 0.15, 1.0)
const BOSS_COLOR: Color = Color("b10f73")
const OUTLINE_COLOR: Color = Color(0.97, 0.97, 0.95, 1.0)
const OUTLINE_SIZE: int = 6
const TOP_OFFSET: float = 96.0
const RISE: float = 10.0
const FADE_IN: float = 0.18
const HOLD: float = 1.0
const BOSS_HOLD: float = 1.6
const FADE_OUT: float = 0.35
const BOSS_PULSE: float = 0.22
const BOSS_SHAKE: float = 5.0

var _label: Label = null
var _tween: Tween = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_label = Label.new()
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_color_override("font_outline_color", OUTLINE_COLOR)
	_label.add_theme_constant_override("outline_size", OUTLINE_SIZE)
	_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_label.offset_top = TOP_OFFSET
	_label.offset_bottom = TOP_OFFSET + BOSS_FONT_SIZE * 2
	add_child(_label)
	_label.modulate.a = 0.0


func announce_wave(wave: int) -> void:
	_show(LocalizationManager.text("hud.wave_banner", [wave]), WAVE_FONT_SIZE, WAVE_COLOR, HOLD)
	AudioManager.play_wave_start()


func announce_boss() -> void:
	_show(LocalizationManager.text("hud.boss_banner"), BOSS_FONT_SIZE, BOSS_COLOR, BOSS_HOLD)
	AudioManager.play_boss_wave()
	_pulse()
	var player: Player = get_tree().get_first_node_in_group("player") as Player
	if player != null:
		player.shake(BOSS_SHAKE)


func text() -> String:
	return _label.text


func is_showing() -> bool:
	return _label.modulate.a > 0.0


func _show(message: String, font_size: int, color: Color, hold: float) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_label.text = message
	_label.add_theme_font_size_override("font_size", font_size)
	_label.add_theme_color_override("font_color", color)
	_label.offset_top = TOP_OFFSET + RISE
	_label.modulate.a = 0.0

	_tween = create_tween()
	_tween.set_parallel(true)
	_tween.tween_property(_label, "modulate:a", 1.0, FADE_IN)
	_tween.tween_property(_label, "offset_top", TOP_OFFSET, FADE_IN).set_trans(Tween.TRANS_BACK) \
		.set_ease(Tween.EASE_OUT)
	_tween.chain().tween_interval(hold)
	_tween.chain().tween_property(_label, "modulate:a", 0.0, FADE_OUT)


func _pulse() -> void:
	var pulse: Tween = create_tween()
	pulse.tween_property(_label, "scale", Vector2(1.08, 1.08), BOSS_PULSE).set_trans(Tween.TRANS_SINE)
	pulse.tween_property(_label, "scale", Vector2.ONE, BOSS_PULSE).set_trans(Tween.TRANS_SINE)
