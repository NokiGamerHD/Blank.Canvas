class_name DrawingCode
extends RefCounted

const MAGIC_FIRST: int = 66
const MAGIC_SECOND: int = 67
const FORMAT_VERSION: int = 1
const HEADER_SIZE: int = 6
const MAX_COLORS: int = 255
const MAX_RUN: int = 255
const MAX_GRID: int = 255
const BASE64_CHARS: String = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/="


static func encode(image: Image) -> String:
	if image == null:
		push_warning("[DrawingCode] Nenhuma imagem para codificar.")
		return ""

	var source: Image = image.duplicate()
	if source.get_format() != Image.FORMAT_RGBA8:
		source.convert(Image.FORMAT_RGBA8)

	var grid: int = source.get_width()
	if grid < 1 or grid > MAX_GRID or source.get_height() != grid:
		push_warning("[DrawingCode] Só desenhos quadrados de até %d pixels viram código." % MAX_GRID)
		return ""

	var palette: PackedColorArray = PackedColorArray()
	var lookup: Dictionary = {}
	var indices: PackedByteArray = PackedByteArray()

	for y in grid:
		for x in grid:
			var color: Color = source.get_pixel(x, y)
			if color.a <= 0.0:
				color = Color(0, 0, 0, 0)
			var key: int = _color_key(color)
			if not lookup.has(key):
				if palette.size() >= MAX_COLORS:
					push_warning("[DrawingCode] Desenho com mais de %d cores, código não gerado." % MAX_COLORS)
					return ""
				lookup[key] = palette.size()
				palette.append(color)
			indices.append(lookup[key])

	var payload: PackedByteArray = PackedByteArray()
	payload.append(palette.size())
	for color in palette:
		payload.append(_to_byte(color.r))
		payload.append(_to_byte(color.g))
		payload.append(_to_byte(color.b))
		payload.append(_to_byte(color.a))

	var position: int = 0
	while position < indices.size():
		var value: int = indices[position]
		var run: int = 1
		while position + run < indices.size() and run < MAX_RUN and indices[position + run] == value:
			run += 1
		payload.append(value)
		payload.append(run)
		position += run

	var compressed: PackedByteArray = payload.compress(FileAccess.COMPRESSION_DEFLATE)
	if compressed.is_empty():
		push_warning("[DrawingCode] Falha ao compactar o desenho.")
		return ""

	var bytes: PackedByteArray = PackedByteArray()
	bytes.append(MAGIC_FIRST)
	bytes.append(MAGIC_SECOND)
	bytes.append(FORMAT_VERSION)
	bytes.append(grid)
	bytes.append(payload.size() & 0xff)
	bytes.append((payload.size() >> 8) & 0xff)
	bytes.append_array(compressed)
	return Marshalls.raw_to_base64(bytes)


static func decode(code: String) -> Image:
	var clean: String = _sanitize(code)
	if clean.is_empty() or clean.length() % 4 != 0:
		return null

	var bytes: PackedByteArray = Marshalls.base64_to_raw(clean)
	if bytes.size() <= HEADER_SIZE:
		return null
	if bytes[0] != MAGIC_FIRST or bytes[1] != MAGIC_SECOND or bytes[2] != FORMAT_VERSION:
		return null

	var grid: int = bytes[3]
	if grid < 1 or grid > MAX_GRID:
		return null

	var payload_size: int = bytes[4] | (bytes[5] << 8)
	if payload_size < 1:
		return null

	var payload: PackedByteArray = bytes.slice(HEADER_SIZE).decompress(payload_size, FileAccess.COMPRESSION_DEFLATE)
	if payload.size() != payload_size:
		return null

	var palette_size: int = payload[0]
	if palette_size < 1 or payload.size() < 1 + palette_size * 4:
		return null

	var palette: PackedColorArray = PackedColorArray()
	var cursor: int = 1
	for i in palette_size:
		palette.append(Color8(payload[cursor], payload[cursor + 1], payload[cursor + 2], payload[cursor + 3]))
		cursor += 4

	var image: Image = Image.create(grid, grid, false, Image.FORMAT_RGBA8)
	var total: int = grid * grid
	var written: int = 0
	while cursor + 1 < payload.size() and written < total:
		var value: int = payload[cursor]
		var run: int = payload[cursor + 1]
		cursor += 2
		if value >= palette_size or run < 1 or written + run > total:
			return null
		for step in run:
			image.set_pixel((written + step) % grid, (written + step) / grid, palette[value])
		written += run

	if written != total:
		return null
	return image


static func is_valid(code: String) -> bool:
	return decode(code) != null


static func _sanitize(code: String) -> String:
	var clean: String = ""
	for i in code.length():
		var character: String = code[i]
		if BASE64_CHARS.contains(character):
			clean += character
	return clean


static func _color_key(color: Color) -> int:
	return (_to_byte(color.r) << 24) | (_to_byte(color.g) << 16) | (_to_byte(color.b) << 8) | _to_byte(color.a)


static func _to_byte(value: float) -> int:
	return clampi(int(round(value * 255.0)), 0, 255)
