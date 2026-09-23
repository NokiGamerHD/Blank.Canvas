class_name FlaskBelt
extends Node

signal slots_changed
signal effect_changed(color: Color, effects: Array[String])

const FADE_OUT_TIME: float = 1.6
const GROW_TIME: float = 0.25

var slots: Array[Dictionary] = []

var _player: Player = null
var _active_effects: Array[String] = []
var _active_color: Color = Color(0, 0, 0, 0)
var _time_left: float = 0.0
var _bonus_hp: float = 0.0
var _grown: bool = false
var _fading: bool = false
var _scale_tween: Tween = null


func _ready() -> void:
	_player = get_parent() as Player
	if _player == null:
		push_warning("[FlaskBelt] O parent não é um Player; cinto de frascos desativado.")
		set_process(false)
		set_process_unhandled_input(false)


func _process(delta: float) -> void:
	if _time_left <= 0.0:
		return
	_time_left -= delta
	if not _fading and _time_left <= FADE_OUT_TIME:
		_begin_fade()
	if _time_left <= 0.0:
		_clear_effect()


func _unhandled_input(event: InputEvent) -> void:
	var key: InputEventKey = event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	var index: int = key.keycode - KEY_1
	if index < 0 or index >= FlaskEffects.MAX_SLOTS:
		return
	if use(index):
		get_viewport().set_input_as_handled()


func capacity() -> int:
	return clampi(GameManager.flask_slots, 1, FlaskEffects.MAX_SLOTS)


func has_room() -> bool:
	return slots.size() < capacity()


func store(color: Color, effects: Array[String]) -> bool:
	if not has_room() or effects.is_empty():
		return false
	slots.append({"color": Color(color.r, color.g, color.b, 1.0), "effects": effects.duplicate()})
	slots_changed.emit()
	return true


func use(index: int) -> bool:
	if is_active() or index < 0 or index >= slots.size() or _player == null or _player.is_dead():
		return false
	var flask: Dictionary = slots[index]
	slots.remove_at(index)
	_activate(flask["color"], flask["effects"])
	slots_changed.emit()
	return true


func active_effects() -> Array[String]:
	return _active_effects


func active_color() -> Color:
	return _active_color


func is_active() -> bool:
	return not _active_effects.is_empty()


func time_left() -> float:
	return maxf(_time_left, 0.0)


func speed_multiplier() -> float:
	return FlaskEffects.player_speed(_active_effects)


func dash_cooldown_multiplier() -> float:
	return FlaskEffects.dash_cooldown(_active_effects)


func dash_speed_multiplier() -> float:
	return FlaskEffects.dash_speed(_active_effects)


func fire_rate_multiplier() -> float:
	return FlaskEffects.fire_rate(_active_effects)


func damage_multiplier() -> float:
	return FlaskEffects.damage(_active_effects)


func _activate(color: Color, effects: Array[String]) -> void:
	_active_effects = effects.duplicate()
	_active_color = color
	_time_left = FlaskEffects.DURATION
	_fading = false
	if _player != null:
		_player.heal(FlaskEffects.USE_HEAL)
	AudioManager.play_flask_use()
	_paint_burst(color)
	_apply_body_effects()
	_set_screen_glow(color)
	effect_changed.emit(_active_color, _active_effects)


func _clear_effect() -> void:
	_remove_body_effects()
	_active_effects = []
	_active_color = Color(0, 0, 0, 0)
	_time_left = 0.0
	_set_screen_glow(Color(0, 0, 0, 0))
	effect_changed.emit(_active_color, _active_effects)


func _apply_body_effects() -> void:
	if not _active_effects.has(FlaskEffects.BURST) or _player == null:
		return
	_bonus_hp = FlaskEffects.BURST_BONUS_HP
	_player.max_hp += _bonus_hp
	_player.heal(_bonus_hp)
	_tween_body(FlaskEffects.BURST_GROW, GROW_TIME)
	_grown = true


func _remove_body_effects() -> void:
	if _player == null:
		return
	if _grown:
		_tween_body(1.0, GROW_TIME)
		_grown = false
	if _bonus_hp <= 0.0:
		return
	_player.max_hp = maxf(_player.max_hp - _bonus_hp, 1.0)
	_player.clamp_health()
	_bonus_hp = 0.0


func _begin_fade() -> void:
	_fading = true
	var edges: Node = _screen_edges()
	if edges != null:
		edges.fade_flask_glow(minf(FADE_OUT_TIME, maxf(_time_left, 0.05)))
	if _grown:
		_tween_body(1.0, minf(FADE_OUT_TIME, maxf(_time_left, 0.05)))
		_grown = false


func _tween_body(target: float, seconds: float) -> void:
	if _player == null:
		return
	if _scale_tween != null and _scale_tween.is_valid():
		_scale_tween.kill()
	_scale_tween = create_tween()
	_scale_tween.tween_method(_player.set_body_scale, _player.body_scale(), target, seconds) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _screen_edges() -> Node:
	var hud: Node = get_tree().get_first_node_in_group("hud")
	if hud == null or not hud.has_method("screen_edges"):
		return null
	return hud.screen_edges()


func _set_screen_glow(color: Color) -> void:
	var hud: Node = get_tree().get_first_node_in_group("hud")
	if hud == null or not hud.has_method("set_flask_glow"):
		return
	hud.set_flask_glow(color)


func _paint_burst(color: Color) -> void:
	var canvas: PaintCanvas = get_tree().get_first_node_in_group("paint_canvas") as PaintCanvas
	if canvas == null or _player == null:
		return
	canvas.paint_circle(_player.global_position, 32.0, color)
	for index in 6:
		var offset: Vector2 = Vector2.from_angle(TAU * float(index) / 6.0 + randf() * 0.6) \
			* randf_range(36.0, 64.0)
		canvas.paint_circle(_player.global_position + offset, randf_range(6.0, 12.0), color)
