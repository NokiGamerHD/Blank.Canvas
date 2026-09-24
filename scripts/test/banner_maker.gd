extends Node

const OUTPUT_DIR: String = "res://press-kit/promo"
const FONT_PATH: String = "res://assets/fonts/press_start_2p.ttf"
const ICON_PATH: String = "res://icon.svg"
const ARENA_SIDE: float = 1400.0
const OUTPUT_SCALE: int = 2
const PAINT_RESOLUTION: float = 1.0
const SETTLE_FRAMES: int = 10
const FONT_CELL: int = 8
const FONT_ORIGIN: Vector2 = Vector2(4.0, 4.0)
const UI_PIXEL: int = 8
const POINTER_SCALE: int = 12
const ICON_ART_SIZE: int = 36
const ICON_SOURCE_SIZE: float = 128.0
const ICON_GRAY_SATURATION: float = 0.35
const ICON_GRAY_SPLIT: float = 0.55
const TITLE_ICON_GAP_CELLS: int = 4
const ORB_PATH_LENGTH: float = 190.0
const SHARD_RAYS: int = 8
const SHARD_RAY_MIN: float = 120.0
const SHARD_RAY_MAX: float = 230.0
const BLAST_PAINT_FACTOR: float = 0.5
const BLAST_SPATTERS: int = 8
const DEATH_SPLAT_FACTOR: float = 2.4
const DEATH_SPATTERS: int = 4
const BOSS_SPLAT_FACTOR: float = 0.42
const BOSS_SPLAT_SPATTERS: int = 5
const QR_SOURCE_SIZE: int = 500
const QR_CARD_BORDER: int = 8
const QR_ENTRIES: Array[Dictionary] = [
	{"file": "QR-Jogo.png", "label": "itch.io Link"},
	{"file": "QR-Insta.png", "label": "Instagram Link"},
]

const INK_COLOR: Color = Color(0.15, 0.15, 0.15, 1.0)
const CREDIT_COLOR: Color = Color(0.2, 0.2, 0.2, 1.0)
const OUTLINE_COLOR: Color = Color(1.0, 1.0, 1.0, 1.0)
const WARM_TINT: Color = Color(1.0, 0.9, 0.56, 1.0)
const SHADOW_COLOR: Color = Color(0.0, 0.0, 0.0, 0.3)
const BRUSH_PAINT: Color = Color("e0b400")

const CREDIT: String = "Developed by Imperial Bay™"
const CARD_COLOR: Color = Color(1.0, 1.0, 1.0, 1.0)

const ICON_DARK: Color = Color("2b2b2b")
const ICON_LIGHT: Color = Color("fbfbf8")
const ICON_PAINTS: Array[Color] = [Color("0b35dc"), Color("15b10f"), Color("d94f4f")]

const CURSOR_PATTERN: Array[String] = [
	"#...........",
	"##..........",
	"#o#.........",
	"#oo#........",
	"#ooo#.......",
	"#oooo#......",
	"#ooooo#.....",
	"#oooooo#....",
	"#ooooooo#...",
	"#oooooooo#..",
	"#ooooo#####.",
	"#oo#oo#.....",
	"#o#.#oo#....",
	"##..#oo#....",
	"#....#oo#...",
	".....#oo#...",
	"......#oo#..",
	"......#oo#..",
	".......##...",
]

const CURSOR_TONES: Dictionary = {
	"#": Color(0.08, 0.08, 0.08, 1.0),
	"o": Color(1.0, 1.0, 1.0, 1.0),
}

const BRUSH_PATTERN: Array[String] = [
	"................##.",
	"...............#Ww#",
	"..............#Ww#.",
	".............#Ww#..",
	"............#Ww#...",
	"...........#Ww#....",
	"..........#Ww#.....",
	".........#Ww#......",
	"........#Mmm#......",
	"......##Mmm#.......",
	".....#bbbb#........",
	"....#bbbb#.........",
	"...#Pbbb#..........",
	"..#Ppp##...........",
	".#Pp##.............",
	"#Pp#...............",
	"#p#................",
	".#.................",
]

const BRUSH_TIP: Vector2i = Vector2i(1, 16)

const BRUSH_TONES: Dictionary = {
	"#": Color(0.15, 0.15, 0.15, 1.0),
	"W": Color("ba8040"),
	"w": Color("8a5a2b"),
	"M": Color("d7dce0"),
	"m": Color("8c929a"),
	"b": Color("463223"),
	"P": Color("f5d65c"),
	"p": Color("e0b400"),
}

const LAYOUTS: Array[Dictionary] = [
	{
		"file": "banner-%dx%d.png",
		"size": Vector2i(3840, 2160),
		"view": Vector2i(960, 540),
		"title_lines": ["BLANK CANVAS"],
		"title_scale": 28,
		"icon_scale": 10,
		"title_center_y": 760,
		"line_gap": 84,
		"slogan_lines": ["Canvas into your Blank!"],
		"slogan_scale": 14,
		"slogan_top": 1144,
		"slogan_gap": 48,
		"credit_scale": 9,
		"credit_center_y": 1960,
		"selection": Vector2i(0, 6),
		"brush": Vector2i(0, 11),
		"seed": 20260921,
		"blast": Vector2(0.74, 0.1),
		"trails": [
			{"type": EnemyBase.EnemyType.BOSS, "at": Vector2(0.87, 0.77), "heading": -2.4},
			{"type": EnemyBase.EnemyType.BOSS, "at": Vector2(0.58, 0.13), "heading": 0.3, "generation": 1,
				"aim": Vector2(0.44, 0.2)},
			{"type": EnemyBase.EnemyType.BOSS, "at": Vector2(0.95, 0.44), "heading": -1.2, "generation": 2},
			{"type": EnemyBase.EnemyType.COMMON, "at": Vector2(0.08, 0.2), "heading": 0.9},
			{"type": EnemyBase.EnemyType.COMMON, "at": Vector2(0.2, 0.83), "heading": -0.4},
			{"type": EnemyBase.EnemyType.FAST, "at": Vector2(0.36, 0.09), "heading": 2.6},
			{"type": EnemyBase.EnemyType.FAST, "at": Vector2(0.05, 0.62), "heading": -0.7},
			{"type": EnemyBase.EnemyType.STALKER, "at": Vector2(0.27, 0.66), "heading": 0.2},
			{"type": EnemyBase.EnemyType.STALKER, "at": Vector2(0.72, 0.63), "heading": 3.3},
			{"type": EnemyBase.EnemyType.TANK, "at": Vector2(0.13, 0.43), "heading": 3.6},
			{"type": EnemyBase.EnemyType.TANK, "at": Vector2(0.47, 0.67), "heading": -1.9, "generation": 1},
		],
	},
	{
		"file": "banner-%dx%d.png",
		"size": Vector2i(2160, 3840),
		"view": Vector2i(540, 960),
		"title_lines": ["BLANK", "CANVAS"],
		"title_scale": 28,
		"icon_scale": 12,
		"title_center_y": 1380,
		"line_gap": 84,
		"slogan_lines": ["Canvas into", "your Blank!"],
		"slogan_scale": 16,
		"slogan_top": 1920,
		"slogan_gap": 56,
		"credit_scale": 8,
		"credit_center_y": 3580,
		"selection": Vector2i(1, 0),
		"brush": Vector2i(0, 4),
		"seed": 20260922,
		"blast": Vector2(0.74, 0.72),
		"trails": [
			{"type": EnemyBase.EnemyType.BOSS, "at": Vector2(0.72, 0.13), "heading": 2.2},
			{"type": EnemyBase.EnemyType.BOSS, "at": Vector2(0.2, 0.09), "heading": 0.4, "generation": 1,
				"aim": Vector2(0.36, 0.2)},
			{"type": EnemyBase.EnemyType.BOSS, "at": Vector2(0.84, 0.75), "heading": -1.7, "generation": 2,
				"aim": Vector2(0.58, 0.7)},
			{"type": EnemyBase.EnemyType.COMMON, "at": Vector2(0.15, 0.59), "heading": 0.3},
			{"type": EnemyBase.EnemyType.COMMON, "at": Vector2(0.58, 0.79), "heading": -2.6},
			{"type": EnemyBase.EnemyType.FAST, "at": Vector2(0.42, 0.26), "heading": 2.4},
			{"type": EnemyBase.EnemyType.FAST, "at": Vector2(0.08, 0.74), "heading": -0.6},
			{"type": EnemyBase.EnemyType.STALKER, "at": Vector2(0.38, 0.64), "heading": 1.1},
			{"type": EnemyBase.EnemyType.STALKER, "at": Vector2(0.8, 0.83), "heading": 3.9},
			{"type": EnemyBase.EnemyType.TANK, "at": Vector2(0.6, 0.64), "heading": 0.8},
			{"type": EnemyBase.EnemyType.TANK, "at": Vector2(0.09, 0.87), "heading": -2.2, "generation": 1},
		],
	},
	{
		"file": "poster-a4-%dx%d.png",
		"size": Vector2i(1240, 1754),
		"view": Vector2i(310, 439),
		"title_lines": ["BLANK", "CANVAS"],
		"title_scale": 16,
		"icon_scale": 7,
		"title_center_y": 300,
		"line_gap": 40,
		"slogan_lines": ["Canvas into", "your Blank!"],
		"slogan_scale": 10,
		"slogan_top": 616,
		"slogan_gap": 28,
		"credit_scale": 5,
		"credit_center_y": 1690,
		"selection": Vector2i(1, 0),
		"brush": Vector2i(0, 4),
		"pointer_scale": 7,
		"selection_unit": 4,
		"seed": 20260924,
		"blast": Vector2(0.82, 0.26),
		"qr": {"top": 960, "gap": 48, "pad": 24, "scale": 1, "label_scale": 4, "label_gap": 24},
		"trails": [
			{"type": EnemyBase.EnemyType.BOSS, "at": Vector2(0.17, 0.11), "heading": 2.4},
			{"type": EnemyBase.EnemyType.BOSS, "at": Vector2(0.86, 0.08), "heading": 0.6, "generation": 1,
				"aim": Vector2(0.68, 0.16)},
			{"type": EnemyBase.EnemyType.FAST, "at": Vector2(0.1, 0.4), "heading": -0.6},
			{"type": EnemyBase.EnemyType.COMMON, "at": Vector2(0.34, 0.53), "heading": -2.4},
			{"type": EnemyBase.EnemyType.STALKER, "at": Vector2(0.74, 0.47), "heading": 1.0},
			{"type": EnemyBase.EnemyType.TANK, "at": Vector2(0.55, 0.28), "heading": 0.8},
			{"type": EnemyBase.EnemyType.TANK, "at": Vector2(0.93, 0.38), "heading": -2.1, "generation": 1},
		],
	},
]

var _font: FontFile = null
var _masks: Dictionary = {}
var _qr_images: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_font = (load(FONT_PATH) as FontFile).duplicate(true) as FontFile
	_font.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	_font.hinting = TextServer.HINTING_NONE
	_font.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED

	var icon: Image = _pixel_icon()
	if icon == null:
		get_tree().quit(1)
		return

	for layout in LAYOUTS:
		for line in layout["title_lines"] + layout["slogan_lines"]:
			await _cache_mask(line)
	await _cache_mask(CREDIT)
	for entry in QR_ENTRIES:
		await _cache_mask(entry["label"])
	if not _load_qr_images():
		get_tree().quit(1)
		return

	var failed: bool = false
	for layout in LAYOUTS:
		var background: Image = await _render_world(layout)
		var banner: Image = _compose(layout, background, icon)
		banner.convert(Image.FORMAT_RGB8)
		var file: String = layout["file"] % [banner.get_width(), banner.get_height()]
		var path: String = ProjectSettings.globalize_path(OUTPUT_DIR.path_join(file))
		var save_error: int = banner.save_png(path)
		if save_error != OK:
			push_warning("[BannerMaker] Falha ao salvar %s (erro %d)." % [path, save_error])
			failed = true
			continue
		print("banner: %s" % path)
	get_tree().quit(1 if failed else 0)


func _load_qr_images() -> bool:
	for entry in QR_ENTRIES:
		var path: String = ProjectSettings.globalize_path(OUTPUT_DIR.path_join(entry["file"]))
		var image: Image = Image.load_from_file(path)
		if image == null:
			push_warning("[BannerMaker] Não foi possível ler o QR %s." % path)
			return false
		if image.get_width() != QR_SOURCE_SIZE or image.get_height() != QR_SOURCE_SIZE:
			push_warning("[BannerMaker] %s tem %dx%d, e o layout espera %d de lado." % [
				path, image.get_width(), image.get_height(), QR_SOURCE_SIZE])
			return false
		image.convert(Image.FORMAT_RGBA8)
		_qr_images[entry["file"]] = image
	return true


func _cache_mask(text: String) -> void:
	if _masks.has(text):
		return
	var viewport: SubViewport = SubViewport.new()
	viewport.transparent_bg = true
	viewport.disable_3d = true
	viewport.size = Vector2i(text.length() * FONT_CELL + FONT_CELL * 2, FONT_CELL * 3)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	var label: Label = Label.new()
	label.add_theme_font_override("font", _font)
	label.add_theme_font_size_override("font_size", FONT_CELL)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
	label.add_theme_constant_override("outline_size", 0)
	label.position = FONT_ORIGIN
	label.text = text
	viewport.add_child(label)
	add_child(viewport)
	for i in 3:
		await RenderingServer.frame_post_draw
	var image: Image = viewport.get_texture().get_image()
	viewport.queue_free()
	image.convert(Image.FORMAT_RGBA8)

	var used: Rect2i = image.get_used_rect()
	var width: int = text.length() * FONT_CELL
	var mask: Image = Image.create(width, maxi(used.size.y, 1), false, Image.FORMAT_RGBA8)
	mask.fill(Color(0, 0, 0, 0))
	for y in used.size.y:
		for x in width:
			var source: Vector2i = Vector2i(used.position.x + x, used.position.y + y)
			if source.x < image.get_width() and image.get_pixelv(source).a > 0.5:
				mask.set_pixel(x, y, Color.WHITE)
	_masks[text] = mask


func _pixel_icon() -> Image:
	var svg: String = FileAccess.get_file_as_string(ICON_PATH)
	var image: Image = Image.new()
	var load_error: int = image.load_svg_from_string(svg, float(ICON_ART_SIZE) / ICON_SOURCE_SIZE)
	if load_error != OK or image.get_width() != ICON_ART_SIZE:
		push_warning("[BannerMaker] Não foi possível rasterizar %s (erro %d)." % [ICON_PATH, load_error])
		return null
	image.convert(Image.FORMAT_RGBA8)
	for y in image.get_height():
		for x in image.get_width():
			var pixel: Color = image.get_pixel(x, y)
			if pixel.a < 0.5:
				image.set_pixel(x, y, Color(0, 0, 0, 0))
				continue
			if pixel.s < ICON_GRAY_SATURATION:
				image.set_pixel(x, y, ICON_DARK if pixel.v < ICON_GRAY_SPLIT else ICON_LIGHT)
				continue
			var best: Color = ICON_PAINTS[0]
			var best_distance: float = INF
			for tone in ICON_PAINTS:
				var distance: float = absf(angle_difference(pixel.h * TAU, tone.h * TAU))
				if distance < best_distance:
					best_distance = distance
					best = tone
			image.set_pixel(x, y, best)
	return image


func _render_world(layout: Dictionary) -> Image:
	var size: Vector2i = layout["size"] * OUTPUT_SCALE
	var view: Vector2i = layout["view"]
	var viewport: SubViewport = SubViewport.new()
	viewport.size = size
	viewport.disable_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	add_child(viewport)

	var arena: Arena = load(GameManager.SCENE_ARENA).instantiate() as Arena
	arena.arena_size = Vector2(ARENA_SIDE, ARENA_SIDE)
	(arena.get_node("WaveManager") as WaveManager).first_wave_delay = 9000.0
	(arena.get_node("PaintCanvas") as PaintCanvas).resolution_scale = PAINT_RESOLUTION * OUTPUT_SCALE
	viewport.add_child(arena)
	await get_tree().process_frame
	arena.hud.visible = false
	arena.player.sprite.visible = false
	arena.player.remove_from_group("player")
	arena.ability_controller.set_physics_process(false)
	arena.player.camera.zoom = Vector2(size) / Vector2(view)
	arena.player.camera.reset_smoothing()
	_add_warm_tint(arena)

	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = layout["seed"]
	var origin: Vector2 = arena.player.global_position - Vector2(view) / 2.0

	_paint_blast(arena, origin + layout["blast"] * Vector2(view), rng)
	for entry in layout["trails"]:
		var spot: Vector2 = origin + entry["at"] * Vector2(view)
		_paint_history(arena.paint_canvas, entry, spot, rng)
		if entry.has("aim"):
			_paint_orb_path(arena.paint_canvas, spot, origin + entry["aim"] * Vector2(view))
	arena.paint_canvas.dry_all()

	for i in SETTLE_FRAMES:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image: Image = viewport.get_texture().get_image()
	viewport.queue_free()
	await get_tree().process_frame
	image.convert(Image.FORMAT_RGBA8)
	return image


func _add_warm_tint(arena: Arena) -> void:
	var tint: ColorRect = ColorRect.new()
	var material: CanvasItemMaterial = CanvasItemMaterial.new()
	material.blend_mode = CanvasItemMaterial.BLEND_MODE_MUL
	tint.material = material
	tint.color = WARM_TINT
	tint.size = arena.arena_size
	tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	arena.add_child(tint)
	arena.move_child(tint, arena.board_canvas.get_index() + 1)


func _paint_history(canvas: PaintCanvas, entry: Dictionary, spot: Vector2, rng: RandomNumberGenerator) -> void:
	var type: int = entry["type"]
	var generation: int = entry.get("generation", 0)
	var preset: Dictionary = EnemyBase.PRESETS[type]
	var color: Color = preset["trail_color"]
	var radius: float = preset["trail_radius"] * pow(preset.get("split_scale", 1.0), generation)
	var back: Vector2 = Vector2.from_angle(entry["heading"])
	var side: Vector2 = back.orthogonal()

	match type:
		EnemyBase.EnemyType.COMMON:
			var legs: int = 6
			var previous: Vector2 = spot + back * 62.0 * legs + side * 24.0
			for step in range(legs - 1, -1, -1):
				var point: Vector2 = spot + back * 62.0 * step + side * (24.0 if step % 2 == 0 else -24.0)
				if step == 0:
					point = spot
				canvas.paint_line(previous, point, radius, color)
				previous = point
		EnemyBase.EnemyType.FAST:
			canvas.paint_line(spot + back * 440.0 + side * rng.randf_range(-50.0, 50.0), spot, radius, color)
		EnemyBase.EnemyType.STALKER:
			var orbit: float = rng.randf_range(64.0, 92.0)
			var center: Vector2 = spot + side * orbit
			var end_angle: float = (spot - center).angle()
			var start_angle: float = end_angle - TAU * 1.35
			var previous: Vector2 = center + Vector2.from_angle(start_angle) * orbit
			for step in range(1, 61):
				var point: Vector2 = center + Vector2.from_angle(lerpf(start_angle, end_angle, step / 60.0)) * orbit
				canvas.paint_line(previous, point, radius, color)
				previous = point
		EnemyBase.EnemyType.TANK:
			var start: Vector2 = spot + back * 300.0
			var bend: Vector2 = spot + back * 150.0 + side * rng.randf_range(-40.0, 40.0)
			canvas.paint_line(start, bend, radius, color)
			canvas.paint_line(bend, spot, radius, color)
			if generation > 0:
				_paint_splat(canvas, start, preset["explosion_paint_radius"], color, 6, rng)
		EnemyBase.EnemyType.BOSS:
			_paint_splat(canvas, spot, preset["explosion_paint_radius"] * BOSS_SPLAT_FACTOR
				* pow(preset["split_scale"], generation), color, BOSS_SPLAT_SPATTERS, rng)
			return
	_paint_splat(canvas, spot, radius * DEATH_SPLAT_FACTOR, color, DEATH_SPATTERS, rng)


func _paint_splat(canvas: PaintCanvas, center: Vector2, radius: float, color: Color, spatters: int,
		rng: RandomNumberGenerator) -> void:
	canvas.paint_circle(center, radius, color)
	for i in spatters:
		var offset: Vector2 = Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(radius * 0.8, radius * 1.7)
		canvas.paint_circle(center + offset, rng.randf_range(radius * 0.25, radius * 0.5), color)


func _paint_blast(arena: Arena, center: Vector2, rng: RandomNumberGenerator) -> void:
	var preset: Dictionary = EnemyBase.PRESETS[EnemyBase.EnemyType.BOSS]
	var color: Color = preset["trail_color"]
	var start_angle: float = rng.randf() * TAU
	for ray in SHARD_RAYS:
		var direction: Vector2 = Vector2.from_angle(start_angle + TAU * float(ray) / float(SHARD_RAYS))
		var end: Vector2 = center + direction * rng.randf_range(SHARD_RAY_MIN, SHARD_RAY_MAX)
		arena.paint_canvas.paint_line(center, end, BossShard.TRAIL_RADIUS, color)
	_paint_splat(arena.paint_canvas, center, preset["explosion_paint_radius"] * BLAST_PAINT_FACTOR,
		color, BLAST_SPATTERS, rng)


func _paint_orb_path(canvas: PaintCanvas, spot: Vector2, target: Vector2) -> void:
	var color: Color = EnemyBase.PRESETS[EnemyBase.EnemyType.BOSS]["trail_color"]
	var aim: Vector2 = (target - spot).normalized()
	canvas.paint_line(spot, spot + aim * ORB_PATH_LENGTH, BossOrb.TRAIL_RADIUS, color)


func _compose(layout: Dictionary, background: Image, icon: Image) -> Image:
	var banner: Image = background
	var size: Vector2i = layout["size"] * OUTPUT_SCALE

	var lines: Array = layout["title_lines"]
	var title_scale: int = layout["title_scale"] * OUTPUT_SCALE
	var icon_scale: int = layout["icon_scale"] * OUTPUT_SCALE
	var line_gap: int = layout["line_gap"] * OUTPUT_SCALE
	var line_height: int = (_masks[lines[0]] as Image).get_height() * title_scale
	var text_width: int = 0
	for line in lines:
		text_width = maxi(text_width, _text_width(line, title_scale))
	var icon_size: int = ICON_ART_SIZE * icon_scale
	var icon_gap: int = title_scale * TITLE_ICON_GAP_CELLS
	var block_height: int = lines.size() * line_height + (lines.size() - 1) * line_gap
	var left: int = _snap((size.x - icon_size - icon_gap - text_width) / 2)
	var center_y: int = layout["title_center_y"] * OUTPUT_SCALE

	_stamp_image(banner, icon, Vector2i(left, _snap(center_y - icon_size / 2)), icon_scale)

	var text_left: int = left + icon_size + icon_gap
	var text_top: int = _snap(center_y - block_height / 2)
	var line_origins: Array[Vector2i] = []
	for index in lines.size():
		var origin: Vector2i = Vector2i(text_left, text_top + index * (line_height + line_gap))
		line_origins.append(origin)
		_stamp_text(banner, _masks[lines[index]], origin, title_scale, INK_COLOR)

	var brush: Vector2i = layout["brush"]
	var brush_cell: Vector2i = line_origins[brush.x] + Vector2i(brush.y * FONT_CELL * title_scale, 0)
	_paint_letter(banner, _masks[lines[brush.x]], brush.y, brush_cell, title_scale)

	var selection: Vector2i = layout["selection"]
	var selection_cell: Vector2i = line_origins[selection.x] + Vector2i(selection.y * FONT_CELL * title_scale, 0)
	var selection_unit: int = int(layout.get("selection_unit", UI_PIXEL)) * OUTPUT_SCALE
	var handle: Vector2i = _draw_selection(banner, selection_cell, title_scale, selection_unit)
	var pointer_scale: int = int(layout.get("pointer_scale", POINTER_SCALE)) * OUTPUT_SCALE
	_stamp_pattern(banner, CURSOR_PATTERN, CURSOR_TONES, handle, pointer_scale, true)

	var tip: Vector2i = brush_cell + Vector2i((FONT_CELL - 1) * title_scale, title_scale / 2)
	_stamp_pattern(banner, BRUSH_PATTERN, BRUSH_TONES, tip - BRUSH_TIP * pointer_scale, pointer_scale, false)

	var slogan_scale: int = layout["slogan_scale"] * OUTPUT_SCALE
	var slogan_top: int = layout["slogan_top"] * OUTPUT_SCALE
	for line in layout["slogan_lines"]:
		var mask: Image = _masks[line]
		var origin: Vector2i = Vector2i(_snap((size.x - _text_width(line, slogan_scale)) / 2), slogan_top)
		_stamp_text(banner, mask, origin, slogan_scale, INK_COLOR)
		slogan_top += mask.get_height() * slogan_scale + int(layout["slogan_gap"]) * OUTPUT_SCALE

	var credit_mask: Image = _masks[CREDIT]
	var credit_scale: int = layout["credit_scale"] * OUTPUT_SCALE
	var credit_origin: Vector2i = Vector2i(_snap((size.x - _text_width(CREDIT, credit_scale)) / 2),
		_snap(int(layout["credit_center_y"]) * OUTPUT_SCALE - credit_mask.get_height() * credit_scale / 2))
	_stamp_text(banner, credit_mask, credit_origin, credit_scale, CREDIT_COLOR)
	if layout.has("qr"):
		_stamp_qr_block(banner, layout["qr"], size.x)
	return banner


func _stamp_qr_block(target: Image, setup: Dictionary, width: int) -> void:
	var scale: int = int(setup["scale"]) * OUTPUT_SCALE
	var pad: int = int(setup["pad"]) * OUTPUT_SCALE
	var border: int = QR_CARD_BORDER * OUTPUT_SCALE
	var gap: int = int(setup["gap"]) * OUTPUT_SCALE
	var label_scale: int = int(setup["label_scale"]) * OUTPUT_SCALE
	var label_gap: int = int(setup["label_gap"]) * OUTPUT_SCALE
	var card: int = QR_SOURCE_SIZE * scale + pad * 2
	var block: int = card * QR_ENTRIES.size() + gap * (QR_ENTRIES.size() - 1)
	var left: int = _snap((width - block) / 2)
	var top: int = _snap(int(setup["top"]) * OUTPUT_SCALE)

	for index in QR_ENTRIES.size():
		var entry: Dictionary = QR_ENTRIES[index]
		var origin: Vector2i = Vector2i(left + index * (card + gap), top)
		_blend_block(target, Rect2i(origin + Vector2i(border, border) * 2,
			Vector2i(card, card)), SHADOW_COLOR)
		target.fill_rect(Rect2i(origin - Vector2i(border, border),
			Vector2i(card + border * 2, card + border * 2)), INK_COLOR)
		target.fill_rect(Rect2i(origin, Vector2i(card, card)), CARD_COLOR)
		_stamp_texture(target, _qr_images[entry["file"]], origin + Vector2i(pad, pad), scale)

		var mask: Image = _masks[entry["label"]]
		var label_origin: Vector2i = Vector2i(
			_snap(origin.x + (card - _text_width(entry["label"], label_scale)) / 2),
			_snap(origin.y + card + border + label_gap))
		_stamp_text(target, mask, label_origin, label_scale, INK_COLOR)


func _stamp_texture(target: Image, art: Image, origin: Vector2i, scale: int) -> void:
	for y in art.get_height():
		for x in art.get_width():
			var pixel: Color = art.get_pixel(x, y)
			if pixel.a <= 0.5:
				continue
			target.fill_rect(Rect2i(origin + Vector2i(x, y) * scale, Vector2i(scale, scale)), pixel)


func _text_width(text: String, scale: int) -> int:
	return (text.length() * FONT_CELL - 1) * scale


func _stamp_text(target: Image, mask: Image, origin: Vector2i, scale: int, color: Color) -> void:
	_stamp_mask(target, _outline_of(mask), origin - Vector2i(scale, scale), scale, OUTLINE_COLOR)
	_stamp_mask(target, mask, origin, scale, color)


func _snap(value: int) -> int:
	return value - posmod(value, UI_PIXEL * OUTPUT_SCALE)


func _blend_block(target: Image, rect: Rect2i, color: Color) -> void:
	var block: Image = Image.create(rect.size.x, rect.size.y, false, Image.FORMAT_RGBA8)
	block.fill(color)
	target.blend_rect(block, Rect2i(Vector2i.ZERO, rect.size), rect.position)


func _stamp_mask(target: Image, mask: Image, origin: Vector2i, scale: int, color: Color) -> void:
	for y in mask.get_height():
		for x in mask.get_width():
			if mask.get_pixel(x, y).a > 0.5:
				target.fill_rect(Rect2i(origin + Vector2i(x, y) * scale, Vector2i(scale, scale)), color)


func _outline_of(mask: Image) -> Image:
	var outline: Image = Image.create(mask.get_width() + 2, mask.get_height() + 2, false, Image.FORMAT_RGBA8)
	outline.fill(Color(0, 0, 0, 0))
	for y in mask.get_height():
		for x in mask.get_width():
			if mask.get_pixel(x, y).a <= 0.5:
				continue
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					outline.set_pixel(x + 1 + dx, y + 1 + dy, Color.WHITE)
	return outline


func _stamp_image(target: Image, art: Image, origin: Vector2i, scale: int) -> void:
	var solid: Image = Image.create(art.get_width(), art.get_height(), false, Image.FORMAT_RGBA8)
	solid.fill(Color(0, 0, 0, 0))
	for y in art.get_height():
		for x in art.get_width():
			if art.get_pixel(x, y).a > 0.5:
				solid.set_pixel(x, y, Color.WHITE)
	_stamp_mask(target, _outline_of(solid), origin - Vector2i(scale, scale), scale, OUTLINE_COLOR)
	for y in art.get_height():
		for x in art.get_width():
			var pixel: Color = art.get_pixel(x, y)
			if pixel.a > 0.5:
				target.fill_rect(Rect2i(origin + Vector2i(x, y) * scale, Vector2i(scale, scale)), pixel)


func _stamp_pattern(target: Image, pattern: Array[String], tones: Dictionary, origin: Vector2i,
		scale: int, shadowed: bool) -> void:
	if shadowed:
		for y in pattern.size():
			for x in pattern[y].length():
				if tones.has(pattern[y][x]):
					_blend_block(target, Rect2i(origin + Vector2i(x + 1, y + 1) * scale, Vector2i(scale, scale)),
						SHADOW_COLOR)
	for y in pattern.size():
		for x in pattern[y].length():
			if tones.has(pattern[y][x]):
				target.fill_rect(Rect2i(origin + Vector2i(x, y) * scale, Vector2i(scale, scale)),
					tones[pattern[y][x]])


func _paint_letter(target: Image, mask: Image, index: int, cell: Vector2i, scale: int) -> void:
	var light: Color = BRUSH_TONES["P"]
	for y in mask.get_height():
		for x in FONT_CELL:
			var source: Vector2i = Vector2i(index * FONT_CELL + x, y)
			if mask.get_pixelv(source).a <= 0.5 or x - y < 2:
				continue
			var tone: Color = light if (x + y) % 3 == 0 else BRUSH_PAINT
			target.fill_rect(Rect2i(cell + Vector2i(x, y) * scale, Vector2i(scale, scale)), tone)
	for drip in [Vector2i(FONT_CELL - 2, 2), Vector2i(FONT_CELL - 2, 3)]:
		if mask.get_pixelv(Vector2i(index * FONT_CELL + drip.x, drip.y)).a <= 0.5:
			target.fill_rect(Rect2i(cell + drip * scale, Vector2i(scale, scale)), BRUSH_PAINT)
			break


func _draw_selection(target: Image, cell: Vector2i, scale: int, unit: int) -> Vector2i:
	var glyph: int = (FONT_CELL - 1) * scale
	var pad: int = scale * 2 / 3
	var box: Rect2i = Rect2i(cell - Vector2i(pad, pad), Vector2i(glyph + pad * 2, glyph + pad * 2))
	var dash: int = unit * 2
	for x in range(0, box.size.x, unit):
		var tone: Color = INK_COLOR if (x / dash) % 2 == 0 else Color.WHITE
		target.fill_rect(Rect2i(box.position + Vector2i(x, 0), Vector2i(unit, unit)), tone)
		target.fill_rect(Rect2i(box.position + Vector2i(x, box.size.y - unit), Vector2i(unit, unit)), tone)
	for y in range(0, box.size.y, unit):
		var tone: Color = INK_COLOR if (y / dash) % 2 == 0 else Color.WHITE
		target.fill_rect(Rect2i(box.position + Vector2i(0, y), Vector2i(unit, unit)), tone)
		target.fill_rect(Rect2i(box.position + Vector2i(box.size.x - unit, y), Vector2i(unit, unit)), tone)

	var handle_size: int = unit * 4
	var corners: Array[Vector2i] = [
		box.position, box.position + Vector2i(box.size.x / 2, 0), box.position + Vector2i(box.size.x, 0),
		box.position + Vector2i(0, box.size.y / 2), box.position + Vector2i(box.size.x, box.size.y / 2),
		box.position + Vector2i(0, box.size.y), box.position + Vector2i(box.size.x / 2, box.size.y),
		box.end,
	]
	for corner in corners:
		var top_left: Vector2i = _snap_grid(corner - Vector2i(handle_size, handle_size) / 2, unit)
		target.fill_rect(Rect2i(top_left, Vector2i(handle_size, handle_size)), INK_COLOR)
		target.fill_rect(Rect2i(top_left + Vector2i(unit, unit), Vector2i(unit, unit) * 2), Color.WHITE)
	return _snap_grid(box.end - Vector2i(unit, unit), unit)


func _snap_grid(value: Vector2i, unit: int) -> Vector2i:
	return Vector2i(value.x - posmod(value.x, unit), value.y - posmod(value.y, unit))
