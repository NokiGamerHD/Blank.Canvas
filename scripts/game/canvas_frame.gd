class_name CanvasFrame

const FRAME_OUTER_COLOR: Color = Color("2b2b2b")
const FRAME_INNER_COLOR: Color = Color("d8d2c4")
const SIGNATURE_COLOR: Color = Color("2b2b2b")
const FRAME_DIVISOR: int = 110
const MIN_FRAME: int = 8
const INNER_LINE: int = 2
const SIGNATURE_DIVISOR: int = 120
const MIN_SIGNATURE_SCALE: int = 3
const GLYPH_WIDTH: int = 3
const GLYPH_HEIGHT: int = 5
const GLYPH_SPACING: int = 1
const SIGNATURE_MARGIN: int = 6

const GLYPHS: Dictionary = {
	"A": ["###", "# #", "###", "# #", "# #"],
	"B": ["## ", "# #", "## ", "# #", "## "],
	"C": ["###", "#  ", "#  ", "#  ", "###"],
	"D": ["## ", "# #", "# #", "# #", "## "],
	"E": ["###", "#  ", "###", "#  ", "###"],
	"F": ["###", "#  ", "###", "#  ", "#  "],
	"G": ["###", "#  ", "# #", "# #", "###"],
	"H": ["# #", "# #", "###", "# #", "# #"],
	"I": ["###", " # ", " # ", " # ", "###"],
	"J": ["  #", "  #", "  #", "# #", "###"],
	"K": ["# #", "# #", "## ", "# #", "# #"],
	"L": ["#  ", "#  ", "#  ", "#  ", "###"],
	"M": ["# #", "###", "###", "# #", "# #"],
	"N": ["# #", "## ", "###", " ##", "# #"],
	"O": ["###", "# #", "# #", "# #", "###"],
	"P": ["###", "# #", "###", "#  ", "#  "],
	"Q": ["###", "# #", "# #", "###", "  #"],
	"R": ["###", "# #", "###", "## ", "# #"],
	"S": ["###", "#  ", "###", "  #", "###"],
	"T": ["###", " # ", " # ", " # ", " # "],
	"U": ["# #", "# #", "# #", "# #", "###"],
	"V": ["# #", "# #", "# #", "# #", " # "],
	"W": ["# #", "# #", "###", "###", "# #"],
	"X": ["# #", "# #", " # ", "# #", "# #"],
	"Y": ["# #", "# #", " # ", " # ", " # "],
	"Z": ["###", "  #", " # ", "#  ", "###"],
	"0": ["###", "# #", "# #", "# #", "###"],
	"1": [" # ", "## ", " # ", " # ", "###"],
	"2": ["###", "  #", "###", "#  ", "###"],
	"3": ["###", "  #", "###", "  #", "###"],
	"4": ["# #", "# #", "###", "  #", "  #"],
	"5": ["###", "#  ", "###", "  #", "###"],
	"6": ["###", "#  ", "###", "# #", "###"],
	"7": ["###", "  #", "  #", "  #", "  #"],
	"8": ["###", "# #", "###", "# #", "###"],
	"9": ["###", "# #", "###", "  #", "###"],
	"-": ["   ", "   ", "###", "   ", "   "],
	".": ["   ", "   ", "   ", "   ", " # "],
	" ": ["   ", "   ", "   ", "   ", "   "],
}


static func decorate(source: Image, name: String, framed: bool) -> Image:
	if source == null:
		return null
	var image: Image = Image.new()
	image.copy_from(source)
	if framed:
		_draw_frame(image)
	if not name.is_empty():
		_draw_signature(image, name, framed)
	return image


static func _frame_size(image: Image) -> int:
	return maxi(image.get_width() / FRAME_DIVISOR, MIN_FRAME)


static func _draw_frame(image: Image) -> void:
	var thickness: int = _frame_size(image)
	var width: int = image.get_width()
	var height: int = image.get_height()
	for y in height:
		for x in width:
			var depth: int = mini(mini(x, width - 1 - x), mini(y, height - 1 - y))
			if depth >= thickness:
				continue
			if depth >= thickness - INNER_LINE:
				image.set_pixel(x, y, FRAME_INNER_COLOR)
			else:
				image.set_pixel(x, y, FRAME_OUTER_COLOR)


static func _draw_signature(image: Image, name: String, framed: bool) -> void:
	var scale: int = maxi(image.get_width() / SIGNATURE_DIVISOR, MIN_SIGNATURE_SCALE)
	var text: String = name.to_upper()
	var span: int = text.length() * (GLYPH_WIDTH + GLYPH_SPACING) - GLYPH_SPACING
	if span <= 0:
		return
	var inset: int = SIGNATURE_MARGIN * scale
	if framed:
		inset += _frame_size(image)
	var origin: Vector2i = Vector2i(
		image.get_width() - span * scale - inset,
		image.get_height() - GLYPH_HEIGHT * scale - inset)
	if origin.x < 0 or origin.y < 0:
		return

	var cursor: int = origin.x
	for index in text.length():
		var glyph: Array = GLYPHS.get(text[index], GLYPHS[" "])
		for row in GLYPH_HEIGHT:
			var line: String = glyph[row]
			for column in GLYPH_WIDTH:
				if line[column] != "#":
					continue
				_fill_block(image, Vector2i(cursor + column * scale, origin.y + row * scale), scale)
		cursor += (GLYPH_WIDTH + GLYPH_SPACING) * scale


static func _fill_block(image: Image, spot: Vector2i, scale: int) -> void:
	for y in scale:
		for x in scale:
			var point: Vector2i = spot + Vector2i(x, y)
			if point.x < 0 or point.y < 0 or point.x >= image.get_width() or point.y >= image.get_height():
				continue
			image.set_pixel(point.x, point.y, SIGNATURE_COLOR)
