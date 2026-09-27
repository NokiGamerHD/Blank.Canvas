extends Node

const PLAYER_SPOT: Vector2 = Vector2(600.0, 600.0)
const EXPECTED_CHECKS: int = 14

var _arena: Arena = null
var _player: Player = null
var _controller: AbilityController = null
var _touch: TouchControls = null
var _failures: int = 0
var _checks: int = 0
var _paused_asked: int = 0


func _ready() -> void:
	GameManager.shop_items = PackedStringArray()
	process_mode = Node.PROCESS_MODE_ALWAYS
	_arena = load(GameManager.SCENE_ARENA).instantiate() as Arena
	_arena.arena_size = Vector2(1200.0, 1200.0)
	(_arena.get_node("WaveManager") as WaveManager).first_wave_delay = 9000.0
	add_child(_arena)

	_arena.paint_canvas.remove_from_group("paint_canvas")
	_player = _arena.player
	_controller = _arena.ability_controller
	_player.max_hp = 1000000.0
	_player.current_hp = 1000000.0
	_player.global_position = PLAYER_SPOT

	await get_tree().process_frame
	await get_tree().process_frame
	_touch = _arena.hud.touch_controls()
	if _touch == null:
		print("FALHA os controles de toque nao foram criados")
		get_tree().quit(1)
		return
	_touch.pause_requested.connect(func() -> void: _paused_asked += 1)

	await _check_activation()
	await _check_static_sticks()
	await _check_dash_beside_aim()
	await _check_move_stick()
	await _check_aim_stick()
	await _check_left_stick_does_not_fire()
	await _check_dash_button()
	await _check_pause_button()
	await _check_release_on_pause()
	await _check_flask_tap()
	await _check_flask_cell_size()
	await _check_minimap_tap()
	await _check_mouse_leaves_touch_mode()
	await _check_typing_keeps_touch_mode()

	if _checks != EXPECTED_CHECKS:
		_failures += 1
		print("FALHA checagens incompletas: %d de %d" % [_checks, EXPECTED_CHECKS])
	print("checagens: %d  falhas: %d" % [_checks, _failures])
	get_tree().quit(1 if _failures > 0 else 0)


func _report(label: String, passed: bool, detail: String) -> void:
	_checks += 1
	if not passed:
		_failures += 1
	print("%s %s %s" % ["ok  " if passed else "FALHA", label, detail])


func _screen() -> Vector2:
	return _touch.screen_size()


func _to_screen(point: Vector2) -> Vector2:
	return _touch.get_viewport().get_final_transform() * point


func _press(index: int, point: Vector2) -> void:
	var event: InputEventScreenTouch = InputEventScreenTouch.new()
	event.index = index
	event.position = _to_screen(point)
	event.pressed = true
	Input.parse_input_event(event)
	await get_tree().process_frame


func _drag(index: int, point: Vector2) -> void:
	var event: InputEventScreenDrag = InputEventScreenDrag.new()
	event.index = index
	event.position = _to_screen(point)
	Input.parse_input_event(event)
	await get_tree().process_frame


func _release(index: int, point: Vector2) -> void:
	var event: InputEventScreenTouch = InputEventScreenTouch.new()
	event.index = index
	event.position = _to_screen(point)
	event.pressed = false
	Input.parse_input_event(event)
	await get_tree().process_frame


func _left_spot() -> Vector2:
	return _touch.move_stick_center()


func _right_spot() -> Vector2:
	return _touch.aim_stick_center()


func _mouse_click(point: Vector2, pressed: bool) -> void:
	var click: InputEventMouseButton = InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = pressed
	click.device = 0
	click.position = _to_screen(point)
	Input.parse_input_event(click)
	await get_tree().process_frame


func _check_mouse_leaves_touch_mode() -> void:
	await _press(0, _left_spot())
	await _release(0, _left_spot())
	var on_touch: bool = GameManager.uses_touch() and _touch.is_active()

	await get_tree().create_timer(float(GameManager.TOUCH_MOUSE_GRACE_MS) / 1000.0 + 0.1).timeout
	await _mouse_click(Vector2(30.0, 30.0), true)
	await _mouse_click(Vector2(30.0, 30.0), false)
	var back_to_mouse: bool = not GameManager.uses_touch() and not _touch.is_active() \
		and not _touch.visible and not _controller.touch_input

	await _press(0, _left_spot())
	await _release(0, _left_spot())
	var touch_again: bool = GameManager.uses_touch() and _touch.is_active()
	_report("clique de mouse devolve o jogo ao modo de PC, e um toque traz de volta o de celular",
		on_touch and back_to_mouse and touch_again,
		"depois_do_toque=%s voltou_ao_mouse=%s toque_de_novo=%s" % [
			on_touch, back_to_mouse, touch_again])


func _key_press(code: Key) -> void:
	var key: InputEventKey = InputEventKey.new()
	key.keycode = code
	key.physical_keycode = code
	key.pressed = true
	key.device = 0
	Input.parse_input_event(key)
	await get_tree().process_frame
	key = key.duplicate() as InputEventKey
	key.pressed = false
	Input.parse_input_event(key)
	await get_tree().process_frame


func _check_typing_keeps_touch_mode() -> void:
	await _press(0, _left_spot())
	await _release(0, _left_spot())
	await get_tree().create_timer(float(GameManager.TOUCH_MOUSE_GRACE_MS) / 1000.0 + 0.1).timeout
	await _key_press(KEY_K)
	var still_touch: bool = GameManager.uses_touch()
	await _key_press(KEY_W)
	var left_touch: bool = not GameManager.uses_touch()
	_report("digitar texto no celular nao derruba o toque, mas tecla de jogo devolve ao PC",
		still_touch and left_touch,
		"apos_letra_solta=%s apos_tecla_de_andar=%s" % [still_touch, not left_touch])


func _check_activation() -> void:
	var before: bool = _touch.is_active()
	await _press(0, _left_spot())
	var after: bool = _touch.is_active()
	var switched: bool = _controller.touch_input and GameManager.uses_touch()
	await _release(0, _left_spot())
	_report("o primeiro toque liga os controles e tira o tiro do botao do mouse",
		not before and after and switched and _touch.visible,
		"antes=%s depois=%s controlador_em_toque=%s visivel=%s" % [
			before, after, switched, _touch.visible])


func _check_move_stick() -> void:
	var origin: Vector2 = _left_spot()
	await _press(0, origin)
	await _drag(0, origin + Vector2(TouchControls.MAX_PULL, 0.0))
	await get_tree().process_frame
	var pressed_right: bool = Input.is_action_pressed("move_right")
	var strength: float = Input.get_action_strength("move_right")
	var start: Vector2 = _player.global_position
	await get_tree().create_timer(0.5).timeout
	var moved: Vector2 = _player.global_position - start
	await _release(0, origin + Vector2(TouchControls.MAX_PULL, 0.0))
	await get_tree().process_frame
	var stopped: bool = not Input.is_action_pressed("move_right")
	_report("o analogico da esquerda anda para o lado puxado e solta a acao ao levantar o dedo",
		pressed_right and strength > 0.9 and moved.x > 40.0 and absf(moved.y) < 20.0 and stopped,
		"acao=%s forca=%.2f andou=(%.0f, %.0f) soltou=%s" % [
			pressed_right, strength, moved.x, moved.y, stopped])


func _check_aim_stick() -> void:
	var origin: Vector2 = _right_spot()
	await _press(1, origin)
	await _drag(1, origin + Vector2(0.0, -TouchControls.MAX_PULL))
	await get_tree().process_frame
	var firing: bool = _controller.touch_firing
	var aim: Vector2 = _player.aim_position() - _player.global_position
	await _release(1, origin + Vector2(0.0, -TouchControls.MAX_PULL))
	await get_tree().process_frame
	var stopped: bool = not _controller.touch_firing
	_report("o analogico da direita mira na direcao puxada e atira so enquanto esta puxado",
		firing and aim.y < -100.0 and absf(aim.x) < 30.0 and stopped,
		"atirando=%s mira=(%.0f, %.0f) parou=%s" % [firing, aim.x, aim.y, stopped])


func _check_left_stick_does_not_fire() -> void:
	var origin: Vector2 = _left_spot()
	await _press(0, origin)
	await _drag(0, origin + Vector2(0.0, TouchControls.MAX_PULL))
	await get_tree().process_frame
	await get_tree().process_frame
	var mouse_says_fire: bool = Input.is_action_pressed("fire")
	var firing: bool = _controller.touch_firing
	await _release(0, origin + Vector2(0.0, TouchControls.MAX_PULL))
	_report("andar com o dedo esquerdo nao dispara, mesmo o toque virando clique de mouse",
		not firing,
		"tiro_por_toque=%s acao_fire_do_mouse=%s" % [firing, mouse_says_fire])


func _check_dash_button() -> void:
	var spot: Vector2 = _touch.dash_button_rect().get_center()
	var ready_before: bool = _player.dash_ready()
	await _press(0, spot)
	await get_tree().process_frame
	var dashing: bool = not _player.dash_ready()
	await _release(0, spot)
	_report("o botao de dash dispara o dash",
		ready_before and dashing,
		"pronto_antes=%s dash_em_curso=%s" % [ready_before, dashing])


func _check_pause_button() -> void:
	var spot: Vector2 = _touch.pause_button_rect().get_center()
	var before: int = _paused_asked
	await _press(0, spot)
	await _release(0, spot)
	await get_tree().process_frame
	var opened: bool = _arena.pause_screen.visible
	if opened:
		_arena.pause_screen.close()
		await get_tree().process_frame
	_report("o botao de pausa abre a pausa",
		_paused_asked == before + 1 and opened,
		"pedidos=%d abriu=%s" % [_paused_asked - before, opened])


func _check_release_on_pause() -> void:
	var origin: Vector2 = _left_spot()
	await _press(0, origin)
	await _drag(0, origin + Vector2(TouchControls.MAX_PULL, 0.0))
	await get_tree().process_frame
	var walking: bool = Input.is_action_pressed("move_right")
	_touch.release_all()
	await get_tree().process_frame
	var released: bool = not Input.is_action_pressed("move_right") and not _controller.touch_firing
	await _release(0, origin)
	_report("abrir a pausa solta o analogico, sem o jogador andar sozinho na volta",
		walking and released,
		"andava=%s soltou=%s" % [walking, released])


func _check_flask_tap() -> void:
	var belt: FlaskBelt = _player.flask_belt
	belt.slots.clear()
	belt.store(Color("0b35dc"), [FlaskEffects.RUSH])
	await get_tree().process_frame
	var bar: FlaskBar = _arena.hud.flask_bar()
	bar.refresh()
	await get_tree().process_frame
	var stored: int = belt.slots.size()
	var cell: Control = bar.cell_at(0)
	var used: bool = false
	if cell != null:
		var click: InputEventMouseButton = InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = true
		cell.gui_input.emit(click)
		await get_tree().process_frame
		used = belt.slots.size() < stored
	_report("tocar no slot do cinto usa o frasco, sem precisar de teclado",
		stored == 1 and cell != null and used,
		"guardou=%d celula=%s usou=%s" % [stored, cell != null, used])


func _check_minimap_tap() -> void:
	var overlay: MapOverlay = _arena.hud.map_overlay()
	var click: InputEventMouseButton = InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	_arena.hud.minimap.gui_input.emit(click)
	await get_tree().process_frame
	await get_tree().process_frame
	var opened: bool = overlay.is_open()
	overlay.gui_input.emit(click)
	await get_tree().process_frame
	await get_tree().process_frame
	var closed: bool = not overlay.is_open()
	_report("tocar no minimapa abre o mapa grande, e tocar de novo fecha",
		opened and closed,
		"abriu=%s fechou=%s" % [opened, closed])


func _check_static_sticks() -> void:
	var move_center: Vector2 = _touch.move_stick_center()
	var aim_center: Vector2 = _touch.aim_stick_center()
	var radius: float = _touch.stick_radius()
	var screen: Vector2 = _screen()
	var anchored: bool = is_equal_approx(move_center.y, screen.y - float(TouchControls.STICK_MARGIN) - radius) \
		and is_equal_approx(move_center.x, float(TouchControls.STICK_MARGIN) + radius) \
		and is_equal_approx(aim_center.x, screen.x - float(TouchControls.STICK_MARGIN) - radius)

	await _press(0, move_center + Vector2(46.0, 0.0))
	await get_tree().process_frame
	var pressed_right: bool = Input.is_action_pressed("move_right")
	var strength: float = Input.get_action_strength("move_right")
	var kept_center: bool = _touch.move_stick_center() == move_center
	await _release(0, move_center + Vector2(46.0, 0.0))
	await get_tree().process_frame
	_report("os analogicos ficam fixos nos cantos de baixo e leem o dedo a partir do centro deles",
		anchored and kept_center and pressed_right and strength > 0.5 and radius >= 54.0,
		"raio=%.0f fixo=%s andou_sem_arrastar=%s forca=%.2f" % [
			radius, anchored and kept_center, pressed_right, strength])


func _check_dash_beside_aim() -> void:
	var aim_center: Vector2 = _touch.aim_stick_center()
	var center: Vector2 = _touch.dash_button_center()
	var radius: float = _touch.dash_button_radius()
	var offset: Vector2 = center - aim_center
	var diagonal: bool = offset.x < -30.0 and offset.y < -30.0 \
		and absf(absf(offset.x) - absf(offset.y)) < 6.0
	var gap: float = offset.length() - _touch.stick_radius() - radius
	var corner: Vector2 = center + Vector2(1.0, 1.0) * (radius + float(TouchControls.TOUCH_PADDING))
	var ready_before: bool = _player.dash_ready()
	await _press(0, corner)
	await get_tree().process_frame
	var round_edge: bool = _player.dash_ready()
	await _release(0, corner)
	await get_tree().process_frame
	_report("o dash fica em diagonal ao lado do analogico de mira, redondo e fora da quina",
		diagonal and gap > 0.0 and gap < 24.0 and radius >= 24.0 and ready_before and round_edge,
		"desvio=(%.0f, %.0f) raio=%.0f folga=%.0f quina_ignorada=%s" % [
			offset.x, offset.y, radius, gap, round_edge])


func _check_flask_cell_size() -> void:
	var bar: FlaskBar = _arena.hud.flask_bar()
	var cell: Control = bar.cell_at(0)
	var grew: bool = bar.slot_scale() == FlaskBar.TOUCH_SLOT_SCALE and cell != null \
		and cell.custom_minimum_size.x >= float(FlaskBar.SLOT_WIDTH * FlaskBar.TOUCH_SLOT_SCALE)
	var numbered: bool = false
	if cell != null:
		for sibling in cell.get_parent().get_children():
			if sibling is Label:
				numbered = true
	var slots: int = GameManager.flask_slots
	GameManager.flask_slots = 8
	bar.refresh()
	await get_tree().process_frame
	await get_tree().process_frame
	var low: Control = bar.cell_at(7)
	var below_zone: bool = low != null \
		and low.get_global_rect().get_center().y > _screen().y * TouchControls.ZONE_TOP_FRACTION
	var walked: bool = false
	if low != null:
		var spot: Vector2 = low.get_global_rect().get_center()
		await _press(0, spot)
		await get_tree().process_frame
		walked = Input.is_action_pressed("move_right") or Input.is_action_pressed("move_left") \
			or Input.is_action_pressed("move_up") or Input.is_action_pressed("move_down")
		await _release(0, spot)
	GameManager.flask_slots = slots
	bar.refresh()
	await get_tree().process_frame
	_report("no celular o slot do frasco fica maior, sem numero, e tocar nele nao anda",
		grew and not numbered and below_zone and not walked,
		"escala=%d largura=%.0f com_numero=%s segunda_fileira_na_zona=%s andou=%s" % [
			bar.slot_scale(), cell.custom_minimum_size.x if cell != null else 0.0,
			numbered, below_zone, walked])
