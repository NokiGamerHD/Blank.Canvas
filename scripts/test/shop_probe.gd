extends Node

const EXPECTED_CHECKS: int = 13
const ITEM_TEXT_WIDTH: float = 150.0
const DESCRIPTION_WIDTH: float = 450.0

var _shop: ShopScreen = null
var _failures: int = 0
var _checks: int = 0
var _saved_palettes: int = 0
var _saved_slots: int = 0
var _saved_items: PackedStringArray = PackedStringArray()
var _saved_signature: String = ""
var _saved_best: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_saved_palettes = GameManager.palettes
	_saved_slots = GameManager.flask_slots
	_saved_items = GameManager.shop_items.duplicate()
	_saved_signature = GameManager.signature_name
	_saved_best = GameManager.best_wave

	_shop = ShopScreen.new()
	add_child(_shop)
	await get_tree().process_frame
	await get_tree().process_frame

	await _check_catalog()
	await _check_purchase()
	await _check_belt()
	await _check_persistence()
	await _check_player_items()
	await _check_footing_and_heal()
	await _check_starting_flask()
	await _check_shop_prices()
	await _check_palette_items()
	await _check_metal_paint()
	await _check_creator_height()
	await _check_canvas_decoration()
	await _check_texts()

	_restore()
	if _checks != EXPECTED_CHECKS:
		_failures += 1
		print("FALHA checagens incompletas: %d de %d" % [_checks, EXPECTED_CHECKS])
	print("checagens: %d  falhas: %d" % [_checks, _failures])
	get_tree().quit(1 if _failures > 0 else 0)


func _restore() -> void:
	GameManager.palettes = _saved_palettes
	GameManager.flask_slots = _saved_slots
	GameManager.shop_items = _saved_items
	GameManager.signature_name = _saved_signature
	GameManager.best_wave = _saved_best
	GameManager._save_progress()


func _report(label: String, passed: bool, detail: String) -> void:
	_checks += 1
	if not passed:
		_failures += 1
	print("%s %s %s" % ["ok  " if passed else "FALHA", label, detail])


func _clear_items() -> void:
	GameManager.shop_items = PackedStringArray()
	GameManager.flask_slots = FlaskEffects.START_SLOTS
	GameManager.palettes = 0


func _check_catalog() -> void:
	var count: int = ShopItems.ORDER.size()
	var priced: bool = true
	var keyed: bool = true
	for id in ShopItems.ORDER:
		if ShopItems.price(id) <= 0:
			priced = false
		if LocalizationManager.text(ShopItems.name_key(id)) == ShopItems.name_key(id):
			keyed = false
		if LocalizationManager.text(ShopItems.description_key(id)) == ShopItems.description_key(id):
			keyed = false
	_report("os doze itens existem, todos com preco e com nome e descricao traduzidos",
		count == 12 and priced and keyed,
		"itens=%d precos=%s textos=%s" % [count, priced, keyed])


func _check_purchase() -> void:
	_clear_items()
	var blocked: bool = not GameManager.can_buy_shop_item(ShopItems.APRON) \
		and not GameManager.buy_shop_item(ShopItems.APRON)
	GameManager.palettes = 5
	var bought: bool = GameManager.buy_shop_item(ShopItems.APRON)
	var charged: bool = GameManager.palettes == 5 - ShopItems.price(ShopItems.APRON)
	var owned: bool = GameManager.has_shop_item(ShopItems.APRON)
	var twice: bool = GameManager.buy_shop_item(ShopItems.APRON)
	_report("sem paleta nao compra, com paleta compra e desconta, e o mesmo item nao compra duas vezes",
		blocked and bought and charged and owned and not twice,
		"travou=%s comprou=%s saldo=%d dupla=%s" % [blocked, bought, GameManager.palettes, twice])


func _check_belt() -> void:
	_clear_items()
	GameManager.palettes = 20
	var slots_before: int = GameManager.flask_slots
	var first: bool = GameManager.buy_shop_item(ShopItems.BELT)
	var grew: bool = GameManager.flask_slots == slots_before + 1
	while GameManager.flask_slots < FlaskEffects.MAX_SLOTS:
		GameManager.buy_shop_item(ShopItems.BELT)
	var capped: bool = not GameManager.can_buy_shop_item(ShopItems.BELT) \
		and GameManager.shop_item_sold_out(ShopItems.BELT)
	_report("o cinto e o unico item repetido: compra ate oito slots e trava no teto",
		first and grew and GameManager.flask_slots == FlaskEffects.MAX_SLOTS and capped,
		"slots=%d travou_no_teto=%s" % [GameManager.flask_slots, capped])


func _check_persistence() -> void:
	_clear_items()
	GameManager.palettes = 6
	GameManager.buy_shop_item(ShopItems.TAP)
	GameManager.set_signature_name("luca")
	GameManager.shop_items = PackedStringArray()
	GameManager.signature_name = ""
	GameManager._load_progress()
	var kept: bool = GameManager.has_shop_item(ShopItems.TAP)
	var signed: bool = GameManager.signature_name == "LUCA"
	_report("item comprado e assinatura sobrevivem ao settings.cfg, em maiuscula",
		kept and signed,
		"item_relido=%s assinatura=%s" % [kept, GameManager.signature_name])


func _check_player_items() -> void:
	_clear_items()
	var plain: Player = load("res://scenes/player/player.tscn").instantiate() as Player
	add_child(plain)
	await get_tree().process_frame
	var base_hp: float = plain.max_hp
	var base_pickup: float = plain.pickup_radius(100.0)
	plain.queue_free()

	GameManager.shop_items = PackedStringArray([ShopItems.APRON, ShopItems.BRUSH])
	var buffed: Player = load("res://scenes/player/player.tscn").instantiate() as Player
	add_child(buffed)
	await get_tree().process_frame
	var hp_gain: float = buffed.max_hp - base_hp
	var pickup_gain: float = buffed.pickup_radius(100.0) - base_pickup
	var full: bool = is_equal_approx(buffed.current_hp, buffed.max_hp)
	buffed.queue_free()
	await get_tree().process_frame
	_report("avental soma vida maxima e pincel grosso soma alcance de coleta",
		is_equal_approx(hp_gain, ShopItems.APRON_HP) and is_equal_approx(pickup_gain, 25.0) and full,
		"vida=+%.0f coleta=+%.0f%% nasce_cheio=%s" % [hp_gain, pickup_gain, full])


func _check_footing_and_heal() -> void:
	_clear_items()
	var plain: Player = load("res://scenes/player/player.tscn").instantiate() as Player
	add_child(plain)
	await get_tree().process_frame
	var base_footing: float = plain.fresh_paint_speed()
	var base_heal: float = PaintDrop.heal_amount()

	GameManager.shop_items = PackedStringArray([ShopItems.SHOES, ShopItems.TAP])
	var shod: float = plain.fresh_paint_speed()
	var tapped: float = PaintDrop.heal_amount()
	plain.queue_free()
	await get_tree().process_frame
	_report("tenis solta a tinta fresca e torneira dobra a cura da gota",
		is_equal_approx(base_footing, Player.FRESH_PAINT_SPEED) \
			and is_equal_approx(shod, ShopItems.SHOES_FOOTING) \
			and is_equal_approx(base_heal, PaintDrop.HEAL) \
			and is_equal_approx(tapped, ShopItems.TAP_HEAL),
		"chao %.2f -> %.2f  cura %.0f -> %.0f" % [base_footing, shod, base_heal, tapped])


func _check_starting_flask() -> void:
	_clear_items()
	GameManager.shop_items = PackedStringArray([ShopItems.CASE])
	var arena: Arena = load(GameManager.SCENE_ARENA).instantiate() as Arena
	arena.arena_size = Vector2(900.0, 900.0)
	(arena.get_node("WaveManager") as WaveManager).first_wave_delay = 9000.0
	add_child(arena)
	await get_tree().process_frame
	await get_tree().process_frame
	var stored: int = arena.player.flask_belt.slots.size()
	var colored: bool = stored > 0 and arena.player.flask_belt.slots[0]["effects"].size() == 1
	arena.queue_free()
	await get_tree().process_frame
	_report("o estojo poe um frasco no cinto ja no comeco da partida",
		stored == 1 and colored,
		"frascos=%d com_efeito=%s" % [stored, colored])


func _check_shop_prices() -> void:
	_clear_items()
	var screen: CanvasLayer = load("res://scenes/ui/progression_screen.tscn").instantiate() as CanvasLayer
	add_child(screen)
	await get_tree().process_frame
	var base_reroll: int = screen.reroll_price()
	var base_ability: int = screen.new_ability_price()

	GameManager.shop_items = PackedStringArray([ShopItems.NOTEBOOK, ShopItems.CONSIGN])
	var free_reroll: int = screen.reroll_price()
	var cheap_ability: int = screen.new_ability_price()
	screen.queue_free()
	await get_tree().process_frame
	_report("caderneta deixa o primeiro sorteio de graca e consignacao barateia a habilidade nova",
		base_reroll == 3 and free_reroll == 0 \
			and cheap_ability == base_ability - ShopItems.CONSIGN_DISCOUNT,
		"sorteio %d -> %d  habilidade %d -> %d" % [
			base_reroll, free_reroll, base_ability, cheap_ability])


func _check_palette_items() -> void:
	_clear_items()
	var base_slots: int = GameManager.custom_color_slots()
	GameManager.shop_items = PackedStringArray([ShopItems.PALETTE])
	var wide: int = GameManager.custom_color_slots()
	GameManager.shop_items = PackedStringArray([ShopItems.PALETTE, ShopItems.METALLIC])
	var still_wide: int = GameManager.custom_color_slots()

	var creator: Control = load(GameManager.SCENE_ABILITY_CREATOR).instantiate() as Control
	add_child(creator)
	await get_tree().process_frame
	await get_tree().process_frame
	var grid: GridContainer = creator.get_node(
		"CenterContainer/MainContainer/EditorRow/SidePanel/PaletteGrid") as GridContainer
	var header: HBoxContainer = creator.get_node(
		"CenterContainer/MainContainer/EditorRow/SidePanel/PaletteHeader") as HBoxContainer
	var cells: int = grid.get_child_count()
	var expected: int = DrawingCreatorBase.PALETTE_COLORS.size() + still_wide
	var in_header: int = 0
	for child in header.get_children():
		if child is Button and child != creator.custom_color_button:
			in_header += 1
	creator.queue_free()
	await get_tree().process_frame
	_report("as tres tintas metalicas ficam no cabecalho, acima da grade, e nao gastam espaco de cor",
		base_slots == GameManager.MAX_CUSTOM_COLORS and wide == still_wide \
			and wide == base_slots + ShopItems.EXTRA_COLOR_SLOTS \
			and cells == expected and in_header == ShopItems.metal_count(),
		"espacos %d -> %d (com metalica %d)  celulas=%d de %d  no_cabecalho=%d" % [
			base_slots, wide, still_wide, cells, expected, in_header])


func _check_metal_paint() -> void:
	GameManager.shop_items = PackedStringArray([ShopItems.METALLIC])
	var creator: Control = load(GameManager.SCENE_ABILITY_CREATOR).instantiate() as Control
	add_child(creator)
	await get_tree().process_frame
	await get_tree().process_frame
	var editor: PixelEditor = creator.pixel_editor

	editor.set_current_color(Color("ff0000"))
	var flat: Dictionary = {}
	for row in 12:
		flat[editor.paint_color_at(Vector2i(0, row)).to_html(false)] = true

	editor.set_metal(1)
	var tones: Dictionary = {}
	var brightest: float = 0.0
	var darkest: float = 1.0
	for row in 12:
		var tone: Color = editor.paint_color_at(Vector2i(0, row))
		tones[tone.to_html(false)] = true
		brightest = maxf(brightest, tone.v)
		darkest = minf(darkest, tone.v)
	var repeats: bool = editor.paint_color_at(Vector2i(0, 0)).is_equal_approx(
		editor.paint_color_at(Vector2i(0, ShopItems.METAL_BAND)))

	editor.set_current_color(Color("00ff00"))
	var cleared: bool = editor.metal_index < 0
	creator.queue_free()
	await get_tree().process_frame
	_report("tinta metalica pinta em faixas claras e escuras, nao numa cor so, e a cor normal volta lisa",
		flat.size() == 1 and tones.size() >= 4 and brightest - darkest > 0.3 and repeats and cleared,
		"tons=%d brilho %.2f a %.2f  cor_normal=%d tom(ns)  limpou=%s" % [
			tones.size(), darkest, brightest, flat.size(), cleared])


func _check_creator_height() -> void:
	GameManager.shop_items = PackedStringArray([ShopItems.PALETTE, ShopItems.METALLIC])
	var heights: Array[float] = []
	for path in [GameManager.SCENE_CHARACTER_CREATOR, GameManager.SCENE_ABILITY_CREATOR]:
		var creator: Control = load(path).instantiate() as Control
		add_child(creator)
		await get_tree().process_frame
		await get_tree().process_frame
		var main: Control = creator.get_node("CenterContainer/MainContainer") as Control
		heights.append(main.size.y)
		creator.queue_free()
		await get_tree().process_frame
	var fits: bool = heights[0] <= 480.0 and heights[1] <= 480.0
	_report("com a linha extra de cores os dois criadores continuam dentro dos 480 px",
		fits,
		"personagem=%.0f habilidade=%.0f" % [heights[0], heights[1]])


func _check_canvas_decoration() -> void:
	_clear_items()
	var canvas: Image = Image.create(400, 300, false, Image.FORMAT_RGBA8)
	canvas.fill(Color.WHITE)
	GameManager.set_last_canvas_snapshot(canvas)
	var plain: Image = GameManager.decorated_canvas()
	var untouched: bool = plain.get_pixel(2, 2).is_equal_approx(Color.WHITE)

	GameManager.shop_items = PackedStringArray([ShopItems.FRAME, ShopItems.SIGNATURE])
	GameManager.signature_name = "LUCA"
	var fancy: Image = GameManager.decorated_canvas()
	var framed: bool = fancy.get_pixel(1, 1).is_equal_approx(CanvasFrame.FRAME_OUTER_COLOR)
	var inked: int = 0
	for y in range(fancy.get_height() - 40, fancy.get_height()):
		for x in range(fancy.get_width() - 120, fancy.get_width()):
			if fancy.get_pixel(x, y).is_equal_approx(CanvasFrame.SIGNATURE_COLOR):
				inked += 1
	var intact: bool = canvas.get_pixel(1, 1).is_equal_approx(Color.WHITE)
	GameManager.set_last_canvas_snapshot(null)
	_report("moldura e assinatura entram so no quadro salvo, sem sujar o original",
		untouched and framed and inked > 40 and intact,
		"sem_item=%s moldura=%s pixels_da_assinatura=%d original_limpo=%s" % [
			untouched, framed, inked, intact])


func _check_texts() -> void:
	var font: Font = _shop.item_button(ShopItems.BELT).get_theme_font("font")
	var size: int = 8
	var wide: PackedStringArray = PackedStringArray()
	for code in ["en", "pt_BR"]:
		var table: Dictionary = LocalizationManager.TRANSLATIONS[code]
		for id in ShopItems.ORDER:
			var name_width: float = font.get_string_size(
				table[ShopItems.name_key(id)], HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
			if name_width > ITEM_TEXT_WIDTH:
				wide.append("%s %s %.0f" % [code, id, name_width])
			var description: float = font.get_string_size(
				table[ShopItems.description_key(id)], HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
			if description > DESCRIPTION_WIDTH:
				wide.append("%s desc.%s %.0f" % [code, id, description])
	_report("nome e descricao de cada item cabem na prateleira nos dois idiomas",
		wide.is_empty(),
		"estourando=%s" % ["nenhum" if wide.is_empty() else ", ".join(wide)])
