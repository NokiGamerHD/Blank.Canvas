extends Node

const SPOT: Vector2 = Vector2(300.0, 300.0)
const RADIUS: float = 12.0
const WALK_SECONDS: float = 0.8
const CORRIDOR_START: Vector2 = Vector2(200.0, 1200.0)
const CORRIDOR_LENGTH: float = 900.0
const CORRIDOR_RADIUS: float = 26.0

var _arena: Arena = null
var _canvas: PaintCanvas = null
var _failures: int = 0
var _red: Color = EnemyBase.PRESETS[EnemyBase.EnemyType.COMMON]["trail_color"]
var _blue: Color = EnemyBase.PRESETS[EnemyBase.EnemyType.FAST]["trail_color"]
var _yellow: Color = EnemyBase.PRESETS[EnemyBase.EnemyType.STALKER]["trail_color"]
var _green: Color = EnemyBase.PRESETS[EnemyBase.EnemyType.TANK]["trail_color"]


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var character: Image = Image.create(36, 36, false, Image.FORMAT_RGBA8)
	character.fill(Color(0, 0, 0, 0))
	character.fill_rect(Rect2i(8, 8, 20, 20), Color("2f9e5a"))
	GameManager.set_character_drawing(character)
	_arena = load(GameManager.SCENE_ARENA).instantiate() as Arena
	_arena.arena_size = Vector2(1600.0, 1600.0)
	(_arena.get_node("WaveManager") as WaveManager).first_wave_delay = 9000.0
	add_child(_arena)
	_canvas = _arena.paint_canvas
	_arena.ability_controller.set_physics_process(false)
	_arena.player.set_physics_process(false)
	await get_tree().process_frame
	await get_tree().process_frame

	_check_wet_is_brighter()
	await _check_drying()
	_check_fresh_mixes()
	_check_mix_table()
	_check_old_paint_is_covered()
	_check_same_color_does_not_mix()
	_check_overlay_does_not_mix()
	_check_coverage()
	_check_footing()
	await _check_footing_speed()
	await _check_screen_edges()
	await _check_game_over_coverage()

	print("falhas: %d" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _report(label: String, passed: bool, detail: String) -> void:
	if not passed:
		_failures += 1
	print("%s %s %s" % ["ok  " if passed else "FALHA", label, detail])


func _pixel(world: Vector2) -> Vector2i:
	return Vector2i(_canvas.to_local(world) * _canvas.resolution_scale)


func _base_at(world: Vector2) -> Color:
	return _canvas.get_image_copy().get_pixelv(_pixel(world))


func _display_at(world: Vector2) -> Color:
	return _canvas.get_display_image_copy().get_pixelv(_pixel(world))


func _spot(index: int) -> Vector2:
	return SPOT + Vector2(float(index % 5) * 120.0, float(index / 5) * 120.0)


func _same(first: Color, second: Color) -> bool:
	return absi(first.r8 - second.r8) <= 1 and absi(first.g8 - second.g8) <= 1 \
		and absi(first.b8 - second.b8) <= 1 and absi(first.a8 - second.a8) <= 1


func _hue_degrees(color: Color) -> float:
	return color.h * 360.0


func _check_wet_is_brighter() -> void:
	var spot: Vector2 = _spot(0)
	_canvas.paint_circle(spot, RADIUS, _red)
	var base: Color = _base_at(spot)
	var shown: Color = _display_at(spot)
	_report("tinta nova aparece mais brilhante que a cor dela",
		_same(base, PaintCanvas.flatten(_red)) and is_equal_approx(base.a, 1.0) and shown.v > base.v + 0.1 and absf(shown.h - base.h) < 0.03 and _canvas.is_wet_at(spot),
		"base=%s na_tela=%s molhada=%s" % [base.to_html(), shown.to_html(), _canvas.is_wet_at(spot)])


func _check_drying() -> void:
	var spot: Vector2 = _spot(0)
	await get_tree().create_timer(PaintCanvas.WET_TIME_MS / 1000.0 + 0.4).timeout
	var shown: Color = _display_at(spot)
	var dry: bool = not _canvas.is_wet_at(spot)
	_canvas.paint_circle(spot, RADIUS, _blue)
	var covered: Color = _base_at(spot)
	_report("tinta seca volta a cor normal e deixa de misturar",
		dry and _same(shown, PaintCanvas.flatten(_red)) and _same(covered, PaintCanvas.flatten(_blue)),
		"seca=%s na_tela=%s azul_por_cima=%s" % [dry, shown.to_html(), covered.to_html()])


func _check_fresh_mixes() -> void:
	var spot: Vector2 = _spot(1)
	var before: int = _canvas.mix_count()
	_canvas.paint_circle(spot, RADIUS, _red)
	_canvas.paint_circle(spot, RADIUS, _blue)
	var mixed: Color = _base_at(spot)
	var hue: float = _hue_degrees(mixed)
	var floor_red: Color = PaintCanvas.flatten(_red)
	var floor_blue: Color = PaintCanvas.flatten(_blue)
	_report("vermelho fresco com azul vira um roxo cheio e opaco",
		hue > 250.0 and hue < 300.0 and _canvas.mix_count() > before and _display_at(spot).v > mixed.v
			and mixed.s >= maxf(floor_red.s, floor_blue.s) - 0.05 and is_equal_approx(mixed.a, 1.0),
		"resultado=%s matiz=%.0f saturacao=%.2f alfa=%.2f misturas=%d" % [
			mixed.to_html(), hue, mixed.s, mixed.a, _canvas.mix_count() - before
		])


func _check_mix_table() -> void:
	var blue_yellow: float = _hue_degrees(PaintCanvas.mix_colors(_blue, _yellow))
	var red_yellow: float = _hue_degrees(PaintCanvas.mix_colors(_red, _yellow))
	var red_green: Color = PaintCanvas.mix_colors(_red, _green)
	var blue_yellow_color: Color = PaintCanvas.mix_colors(_blue, _yellow)
	var floor_red: Color = PaintCanvas.flatten(_red)
	var floor_green: Color = PaintCanvas.flatten(_green)
	_report("misturas de pintor: azul e amarelo verde, vermelho e amarelo laranja, opostos escurecem",
		blue_yellow > 70.0 and blue_yellow < 160.0 and red_yellow > 12.0 and red_yellow < 50.0
			and red_green.s < minf(floor_red.s, floor_green.s) and red_green.v < minf(floor_red.v, floor_green.v)
			and blue_yellow_color.s > 0.7 and blue_yellow_color.v > 0.75
			and is_equal_approx(red_green.a, 1.0) and is_equal_approx(blue_yellow_color.a, 1.0),
		"azul+amarelo=%s vermelho+amarelo=%.0f vermelho+verde=%s" % [
			blue_yellow_color.to_html(), red_yellow, red_green.to_html()
		])


func _check_old_paint_is_covered() -> void:
	var spot: Vector2 = _spot(2)
	_canvas.paint_circle(spot, RADIUS, _green)
	_canvas.dry_all()
	var before: int = _canvas.mix_count()
	_canvas.paint_circle(spot, RADIUS, _yellow)
	var base: Color = _base_at(spot)
	_report("traco novo passa por cima de tinta velha sem misturar",
		_same(base, PaintCanvas.flatten(_yellow)) and _canvas.mix_count() == before,
		"resultado=%s misturas=%d" % [base.to_html(), _canvas.mix_count() - before])


func _check_same_color_does_not_mix() -> void:
	var spot: Vector2 = _spot(3)
	var before: int = _canvas.mix_count()
	for i in 4:
		_canvas.paint_circle(spot + Vector2(float(i) * 3.0, 0.0), RADIUS, _blue)
	_report("mesma cor por cima nao mistura",
		_same(_base_at(spot), PaintCanvas.flatten(_blue)) and _canvas.mix_count() == before,
		"resultado=%s misturas=%d" % [_base_at(spot).to_html(), _canvas.mix_count() - before])


func _check_overlay_does_not_mix() -> void:
	var spot: Vector2 = _spot(4)
	_canvas.paint_circle(spot, RADIUS, _red)
	_canvas.paint_circle(spot, RADIUS * 0.5, EnemyBase.POISON_TRAIL_COLOR, false)
	var base: Color = _base_at(spot)
	_report("rastro do veneno fica roxo puro por cima do rastro fresco",
		_same(base, PaintCanvas.flatten(EnemyBase.POISON_TRAIL_COLOR)),
		"resultado=%s" % base.to_html())


func _check_coverage() -> void:
	var spot: Vector2 = _spot(7)
	var before: float = _canvas.coverage()
	_canvas.paint_circle(spot, RADIUS, _red)
	var once: float = _canvas.coverage()
	_canvas.dry_all()
	_canvas.paint_circle(spot, RADIUS, _blue)
	var twice: float = _canvas.coverage()
	_report("porcentagem pintada sobe com area nova e nao com repintura",
		once > before and is_equal_approx(once, twice),
		"antes=%.5f pintou=%.5f repintou=%.5f" % [before, once, twice])


func _paint_corridor(mixed: bool) -> void:
	var finish: Vector2 = CORRIDOR_START + Vector2(CORRIDOR_LENGTH, 0.0)
	_canvas.paint_line(CORRIDOR_START, finish, CORRIDOR_RADIUS, _red)
	if mixed:
		_canvas.paint_line(CORRIDOR_START, finish, CORRIDOR_RADIUS, _blue)


func _walk() -> float:
	var player: Player = _arena.player
	player.global_position = CORRIDOR_START
	player.velocity = Vector2.ZERO
	player.set_physics_process(true)
	await get_tree().physics_frame
	Input.action_press("move_right")
	await get_tree().create_timer(WALK_SECONDS).timeout
	Input.action_release("move_right")
	player.set_physics_process(false)
	return player.global_position.x - CORRIDOR_START.x


func _puff_count() -> int:
	var count: int = 0
	for child in _arena.get_node("Effects").get_children():
		if child.has_meta("paint_puff"):
			count += 1
	return count


func _clear_puffs() -> void:
	for child in _arena.get_node("Effects").get_children():
		if child.has_meta("paint_puff"):
			child.free()


func _check_footing() -> void:
	var spot: Vector2 = _spot(8)
	var clean: PaintCanvas.Footing = _canvas.footing_at(spot)
	_canvas.paint_circle(spot, RADIUS, _red)
	var fresh: PaintCanvas.Footing = _canvas.footing_at(spot)
	_canvas.paint_circle(spot, RADIUS, _blue)
	var mixed: PaintCanvas.Footing = _canvas.footing_at(spot)
	_canvas.dry_all()
	var dried: PaintCanvas.Footing = _canvas.footing_at(spot)
	_report("o chao sabe dizer se a tinta e fresca, misturada ou seca",
		clean == PaintCanvas.Footing.CLEAN and fresh == PaintCanvas.Footing.FRESH
			and mixed == PaintCanvas.Footing.FRESH_MIX and dried == PaintCanvas.Footing.CLEAN,
		"limpo=%d fresco=%d misturado=%d seco=%d" % [clean, fresh, mixed, dried])


func _check_footing_speed() -> void:
	_clear_puffs()
	var clean_distance: float = await _walk()
	var clean_puffs: int = _puff_count()

	_clear_puffs()
	_paint_corridor(false)
	var fresh_distance: float = await _walk()
	var fresh_puffs: int = _puff_count()
	var fresh_footing: PaintCanvas.Footing = _arena.player.footing()

	_clear_puffs()
	_canvas.dry_all()
	_paint_corridor(true)
	var mixed_distance: float = await _walk()
	var mixed_footing: PaintCanvas.Footing = _arena.player.footing()
	_canvas.dry_all()
	_clear_puffs()

	_report("tinta fresca segura o jogador e tinta misturada acelera",
		fresh_distance < clean_distance * 0.85 and mixed_distance > clean_distance * 1.2
			and fresh_footing == PaintCanvas.Footing.FRESH and mixed_footing == PaintCanvas.Footing.FRESH_MIX,
		"limpo=%.0f px fresco=%.0f px misturado=%.0f px" % [clean_distance, fresh_distance, mixed_distance])
	_report("pisar em tinta fresca solta fumacinha da cor do chao",
		fresh_puffs > 0 and clean_puffs == 0,
		"fumacas_no_limpo=%d fumacas_na_tinta=%d" % [clean_puffs, fresh_puffs])


func _check_screen_edges() -> void:
	var edges: ScreenEdges = _arena.hud.screen_edges()
	if edges == null:
		_report("bordas da tela existem no HUD", false, "nao foram criadas")
		return

	var mask: Image = edges.texture.get_image()
	var center_clear: bool = is_equal_approx(mask.get_pixel(mask.get_width() / 2, mask.get_height() / 2).a, 0.0)
	var corner_dark: bool = mask.get_pixel(0, 0).a > 0.9
	var pixelated: bool = edges.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST \
		and mask.get_width() == ScreenEdges.MASK_WIDTH

	var player: Player = _arena.player
	player.global_position = _spot(9)
	player.velocity = Vector2.ZERO
	player.set_physics_process(true)
	await _wait(ScreenEdges.FADE_TIME + 0.15)
	var spot: Vector2 = player.global_position
	var idle: Color = edges.modulate

	_canvas.paint_circle(spot, CORRIDOR_RADIUS, _red)
	await _wait(ScreenEdges.FADE_TIME + 0.15)
	var fresh: Color = edges.modulate

	_canvas.paint_circle(spot, CORRIDOR_RADIUS, _blue)
	await _wait(ScreenEdges.FADE_TIME + 0.15)
	var mixed: Color = edges.modulate

	_canvas.dry_all()
	await _wait(ScreenEdges.FADE_TIME + 0.15)
	var dried: Color = edges.modulate

	player.take_damage(5.0)
	var hurt: Color = edges.modulate
	await _wait(ScreenEdges.HURT_FADE_TIME + 0.2)
	var after_hurt: Color = edges.modulate
	player.set_physics_process(false)

	var tinted: bool = fresh.h > 0.9 or fresh.h < 0.1
	_report("bordas somem fora da tinta e pegam a cor do chao em cima dela",
		center_clear and corner_dark and pixelated and tinted
			and is_equal_approx(idle.a, 0.0) and is_equal_approx(dried.a, 0.0)
			and fresh.a > 0.2 and mixed.a > fresh.a,
		"centro_livre=%s canto_cheio=%s pixelado=%s alfa limpo=%.2f fresco=%.2f misturado=%.2f seco=%.2f cor_fresca=%s" % [
			center_clear, corner_dark, pixelated, idle.a, fresh.a, mixed.a, dried.a, fresh.to_html(false)
		])
	_report("bordas piscam em vermelho ao tomar dano e voltam ao normal",
		hurt.a > 0.5 and hurt.r > hurt.b * 2.0 and is_equal_approx(after_hurt.a, 0.0),
		"no_golpe=%s alfa=%.2f depois=%.2f" % [hurt.to_html(false), hurt.a, after_hurt.a])


func _check_game_over_coverage() -> void:
	var previous: float = GameManager.last_canvas_coverage
	var results: PackedStringArray = PackedStringArray()
	var expected: Array[String] = ["23%", "1%"]
	var values: Array[float] = [0.234, 0.002]
	var passed: bool = true
	for i in values.size():
		GameManager.last_canvas_coverage = values[i]
		var screen: Node = load(GameManager.SCENE_GAME_OVER).instantiate()
		add_child(screen)
		await get_tree().process_frame
		var text: String = (screen.get_node("CenterContainer/MenuContainer/CoverageLabel") as Label).text
		results.append(text)
		passed = passed and text.ends_with(expected[i])
		screen.queue_free()
	GameManager.last_canvas_coverage = previous
	_report("game over mostra quanto do quadro foi pintado", passed, " | ".join(results))
