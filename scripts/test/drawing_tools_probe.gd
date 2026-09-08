extends Node

const CREATOR_SCENE: String = "res://scenes/character_creator/character_creator.tscn"

var _creator: DrawingCreatorBase
var _editor: PixelEditor
var _failures: int = 0


func _ready() -> void:
	var scene: PackedScene = load(CREATOR_SCENE)
	if scene == null:
		push_warning("[DrawingToolsProbe] Não foi possível carregar %s." % CREATOR_SCENE)
		get_tree().quit(1)
		return

	_creator = scene.instantiate()
	add_child(_creator)
	await get_tree().process_frame
	await get_tree().process_frame

	_editor = _creator.pixel_editor
	_check_pencil()
	_check_line()
	_check_rectangle()
	_check_ellipse()
	_check_bucket()
	_check_bucket_over_colors()
	_check_picker()
	_check_spray()
	_check_history()
	_check_palette_size()
	_check_color_dialog()
	_check_share_code()
	_check_share_code_rejects_garbage()
	_check_code_field()

	print("falhas: %d" % _failures)
	_creator.free()
	get_tree().quit(1 if _failures > 0 else 0)


func _report(label: String, passed: bool, detail: String) -> void:
	if not passed:
		_failures += 1
	print("%s %s %s" % ["ok  " if passed else "FALHA", label, detail])


func _cell_position(cell: Vector2i) -> Vector2:
	var cell_size: float = _editor.size.x / float(_editor.grid_size)
	return (Vector2(cell) + Vector2(0.5, 0.5)) * cell_size


func _drag(tool_id: int, from_cell: Vector2i, to_cell: Vector2i) -> void:
	_editor.set_tool(tool_id)
	_editor._begin_stroke(_cell_position(from_cell), false)
	_editor._continue_stroke(_cell_position(to_cell))
	_editor._end_stroke(_cell_position(to_cell))


func _painted() -> int:
	return _editor.painted_pixel_count()


func _check_pencil() -> void:
	_editor.clear_canvas()
	_editor.set_current_color(Color("d94f4f"))
	_drag(PixelEditor.Tool.PENCIL, Vector2i(2, 2), Vector2i(6, 2))
	_report("lápis", _painted() == 5, "pixels=%d esperado=5" % _painted())


func _check_line() -> void:
	_editor.clear_canvas()
	_drag(PixelEditor.Tool.LINE, Vector2i(4, 4), Vector2i(4, 12))
	_report("linha", _painted() == 9, "pixels=%d esperado=9" % _painted())


func _check_rectangle() -> void:
	_editor.clear_canvas()
	_editor.set_fill_shapes(false)
	_drag(PixelEditor.Tool.RECTANGLE, Vector2i(10, 10), Vector2i(15, 15))
	var outline: int = _painted()
	_editor.clear_canvas()
	_editor.set_fill_shapes(true)
	_drag(PixelEditor.Tool.RECTANGLE, Vector2i(10, 10), Vector2i(15, 15))
	var filled: int = _painted()
	_editor.set_fill_shapes(false)
	_report("retângulo", outline == 20 and filled == 36, "contorno=%d esperado=20 cheio=%d esperado=36" % [outline, filled])


func _check_ellipse() -> void:
	_editor.clear_canvas()
	_editor.set_fill_shapes(true)
	_drag(PixelEditor.Tool.ELLIPSE, Vector2i(8, 8), Vector2i(20, 20))
	var filled: int = _painted()
	_editor.set_fill_shapes(false)
	_drag(PixelEditor.Tool.ELLIPSE, Vector2i(8, 8), Vector2i(20, 20))
	_report("elipse", filled > 100 and filled < 169, "cheia=%d" % filled)


func _check_bucket() -> void:
	_editor.clear_canvas()
	_editor.set_current_color(Color("000000"))
	_editor.set_fill_shapes(false)
	_drag(PixelEditor.Tool.RECTANGLE, Vector2i(6, 6), Vector2i(20, 20))
	var outline: int = _painted()

	_editor.set_current_color(Color("f2d541"))
	_editor.set_tool(PixelEditor.Tool.BUCKET)
	_editor._begin_stroke(_cell_position(Vector2i(13, 13)), false)

	var image: Image = _editor.get_image_copy()
	var inside: int = 0
	var corner_still_black: bool = image.get_pixel(6, 6).is_equal_approx(Color("000000"))
	for y in range(7, 20):
		for x in range(7, 20):
			if image.get_pixel(x, y).is_equal_approx(Color("f2d541")):
				inside += 1
	var expected_inside: int = 13 * 13
	_report("balde", inside == expected_inside and corner_still_black, "miolo=%d esperado=%d contorno_intacto=%s total=%d contorno_original=%d" % [inside, expected_inside, corner_still_black, _painted(), outline])


func _check_bucket_over_colors() -> void:
	_editor.clear_canvas()
	_editor.set_fill_shapes(true)
	_editor.set_current_color(Color("000000"))
	_drag(PixelEditor.Tool.RECTANGLE, Vector2i(6, 6), Vector2i(20, 20))
	_editor.set_current_color(Color("d94f4f"))
	_drag(PixelEditor.Tool.RECTANGLE, Vector2i(10, 10), Vector2i(14, 14))
	_editor.set_fill_shapes(false)

	_editor.set_current_color(Color("f2d541"))
	_editor.set_tool(PixelEditor.Tool.BUCKET)
	_editor._begin_stroke(_cell_position(Vector2i(7, 7)), false)

	var image: Image = _editor.get_image_copy()
	var red_left: int = 0
	var yellow: int = 0
	for y in _editor.grid_size:
		for x in _editor.grid_size:
			var pixel: Color = image.get_pixel(x, y)
			if pixel.is_equal_approx(Color("d94f4f")):
				red_left += 1
			elif pixel.is_equal_approx(Color("f2d541")):
				yellow += 1
	_report("balde sobre outra cor", red_left == 25 and yellow == 200, "vermelho_restante=%d esperado=25 amarelo=%d esperado=200" % [red_left, yellow])


func _check_picker() -> void:
	_editor.clear_canvas()
	_editor.set_current_color(Color("4fc3d9"))
	_drag(PixelEditor.Tool.PENCIL, Vector2i(3, 3), Vector2i(3, 3))
	_editor.set_current_color(Color("000000"))
	_editor.set_tool(PixelEditor.Tool.PICKER)
	_editor._begin_stroke(_cell_position(Vector2i(3, 3)), false)
	_report("conta-gotas", _editor.current_color.is_equal_approx(Color("4fc3d9")) and _painted() == 1, "cor=%s pixels=%d" % [_editor.current_color.to_html(false), _painted()])


func _check_spray() -> void:
	_editor.clear_canvas()
	_editor.set_current_color(Color("7abf5a"))
	_editor.set_tool(PixelEditor.Tool.SPRAY)
	_editor._begin_stroke(_cell_position(Vector2i(18, 18)), false)
	for i in 20:
		_editor._process(0.1)
	_editor._end_stroke(_cell_position(Vector2i(18, 18)))
	var scattered: int = _painted()
	var far_pixel: bool = false
	var image: Image = _editor.get_image_copy()
	for y in _editor.grid_size:
		for x in _editor.grid_size:
			if image.get_pixel(x, y).a > 0.0 and Vector2i(x, y).distance_to(Vector2i(18, 18)) > 3.0:
				far_pixel = true
	_report("spray", scattered > 1 and not far_pixel, "pixels=%d longe_do_cursor=%s" % [scattered, far_pixel])


func _check_history() -> void:
	_editor.clear_canvas()
	_editor.set_current_color(Color("6a4fd9"))
	_drag(PixelEditor.Tool.PENCIL, Vector2i(30, 30), Vector2i(33, 30))
	var painted: int = _painted()
	_editor.undo()
	var after_undo: int = _painted()
	_editor.redo()
	var after_redo: int = _painted()
	_report("desfazer/refazer", painted == 4 and after_undo == 0 and after_redo == 4, "pintado=%d desfeito=%d refeito=%d" % [painted, after_undo, after_redo])


func _check_palette_size() -> void:
	var expected: int = DrawingCreatorBase.PALETTE_COLORS.size() + DrawingCreatorBase.CUSTOM_COLOR_SLOTS
	var swatches: int = _creator.palette_grid.get_child_count()
	var unique: Dictionary = {}
	for color in DrawingCreatorBase.PALETTE_COLORS:
		unique[color.to_html(false)] = true
	var repeated: bool = unique.size() != DrawingCreatorBase.PALETTE_COLORS.size()
	_report("paleta", swatches == expected and not repeated, "botoes=%d esperado=%d cores_repetidas=%s" % [swatches, expected, repeated])


func _check_color_dialog() -> void:
	var saved_colors: PackedColorArray = GameManager.custom_colors.duplicate()
	GameManager.custom_colors = PackedColorArray()
	_creator._refresh_custom_slots()

	var opened: bool = _creator.open_color_dialog()
	var dialog: ColorDialog = _creator._color_dialog
	if not opened or dialog == null:
		_report("seletor de cor", false, "o seletor não abriu")
		return

	dialog.hex_field.text = "#1a9be0"
	dialog._on_use_button_pressed()
	var applied: bool = _editor.current_color.is_equal_approx(Color("1a9be0"))
	var stored: bool = GameManager.custom_colors.size() == 1 and GameManager.custom_colors[0].is_equal_approx(Color("1a9be0"))
	var slot: Button = _creator._custom_slot_button(0)
	var selected: bool = slot.button_pressed and not slot.disabled
	_report("seletor de cor", applied and stored and selected and not dialog.visible, "cor=%s salva=%s selecionada=%s aberto=%s" % [_editor.current_color.to_html(false), stored, selected, dialog.visible])

	_creator.open_color_dialog()
	dialog.hex_field.text = "isso nao e cor"
	dialog._on_use_button_pressed()
	_report("seletor rejeita hex invalido", _editor.current_color.is_equal_approx(Color("1a9be0")), "cor=%s esperado=1a9be0" % _editor.current_color.to_html(false))

	GameManager.custom_colors = saved_colors
	GameManager._save_custom_colors()
	_creator._refresh_custom_slots()


func _check_share_code() -> void:
	_editor.clear_canvas()
	_editor.set_fill_shapes(true)
	_editor.set_current_color(Color("2e8a5c"))
	_drag(PixelEditor.Tool.RECTANGLE, Vector2i(4, 4), Vector2i(18, 18))
	_editor.set_current_color(Color("f28dbb"))
	_drag(PixelEditor.Tool.ELLIPSE, Vector2i(8, 8), Vector2i(14, 14))
	_editor.set_fill_shapes(false)
	_editor.set_current_color(Color("ffffff"))
	_drag(PixelEditor.Tool.PENCIL, Vector2i(20, 20), Vector2i(28, 20))

	var original: Image = _editor.get_image_copy()
	var code: String = DrawingCode.encode(original)
	var restored: Image = DrawingCode.decode(code)

	var identical: bool = restored != null
	if identical:
		for y in _editor.grid_size:
			for x in _editor.grid_size:
				if not original.get_pixel(x, y).is_equal_approx(restored.get_pixel(x, y)):
					identical = false
					break

	_editor.clear_canvas()
	var loaded: bool = false
	if restored != null:
		_editor.load_from_image(restored)
		loaded = _painted() == _count_opaque(original)

	_report("código de compartilhamento", identical and loaded and not code.is_empty(), "tamanho=%d identico=%s recarregado=%s" % [code.length(), identical, loaded])


func _check_share_code_rejects_garbage() -> void:
	var rejects_text: bool = DrawingCode.decode("nao sou um codigo") == null
	var rejects_empty: bool = DrawingCode.decode("") == null
	var rejects_base64: bool = DrawingCode.decode(Marshalls.raw_to_base64("blank canvas".to_utf8_buffer())) == null
	_report("código inválido", rejects_text and rejects_empty and rejects_base64, "texto=%s vazio=%s base64=%s" % [rejects_text, rejects_empty, rejects_base64])


func _count_opaque(image: Image) -> int:
	var count: int = 0
	for y in image.get_height():
		for x in image.get_width():
			if image.get_pixel(x, y).a > 0.0:
				count += 1
	return count


func _check_code_field() -> void:
	_editor.clear_canvas()
	_editor.set_current_color(Color("3f6fd9"))
	_editor.set_fill_shapes(true)
	_drag(PixelEditor.Tool.ELLIPSE, Vector2i(10, 10), Vector2i(24, 24))
	var painted: int = _painted()
	var code: String = _creator.code_field.text

	_editor.clear_canvas()
	_creator._load_code(code)
	var restored: int = _painted()

	_creator._load_code("codigo quebrado")
	var kept: int = _painted()

	_report("campo de código", not code.is_empty() and restored == painted and kept == restored, "pintado=%d recarregado=%d apos_codigo_ruim=%d" % [painted, restored, kept])
