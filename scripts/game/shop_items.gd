class_name ShopItems

const BELT: String = "belt"
const CASE: String = "case"
const BRUSH: String = "brush"
const APRON: String = "apron"
const SHOES: String = "shoes"
const NOTEBOOK: String = "notebook"
const CONSIGN: String = "consign"
const TAP: String = "tap"
const PALETTE: String = "palette"
const METALLIC: String = "metallic"
const SIGNATURE: String = "signature"
const FRAME: String = "frame"

const ORDER: Array[String] = [
	BELT, CASE, BRUSH, APRON, SHOES, NOTEBOOK,
	CONSIGN, TAP, PALETTE, METALLIC, SIGNATURE, FRAME,
]

const PRICES: Dictionary = {
	BELT: 1,
	CASE: 2,
	BRUSH: 2,
	APRON: 3,
	SHOES: 3,
	NOTEBOOK: 2,
	CONSIGN: 4,
	TAP: 3,
	PALETTE: 1,
	METALLIC: 2,
	SIGNATURE: 2,
	FRAME: 2,
}

const BRUSH_BONUS: float = 0.25
const APRON_HP: float = 20.0
const SHOES_FOOTING: float = 0.72
const TAP_HEAL: float = 2.0
const CONSIGN_DISCOUNT: int = 25
const CONSIGN_FLOOR: int = 10
const EXTRA_COLOR_SLOTS: int = 10
const MAX_SIGNATURE_LENGTH: int = 12

const METAL_BAND: int = 6
const METAL_COLORS: Array[Color] = [
	Color("6b4a12"), Color("a8761f"), Color("d9a441"),
	Color("f7e08a"), Color("d9a441"), Color("8c5f18"),
	Color("5b6170"), Color("8a909e"), Color("c9ccd4"),
	Color("f4f6fa"), Color("c9ccd4"), Color("767d8c"),
	Color("6b2f16"), Color("a04c24"), Color("cf7440"),
	Color("f0a878"), Color("cf7440"), Color("8a3d1c"),
]


static func metal_count() -> int:
	return METAL_COLORS.size() / METAL_BAND


static func metal_color(index: int, row: int) -> Color:
	if index < 0 or index >= metal_count():
		return Color.BLACK
	return METAL_COLORS[index * METAL_BAND + posmod(row, METAL_BAND)]


static func metal_mid_color(index: int) -> Color:
	return metal_color(index, 2)


static func price(id: String) -> int:
	return int(PRICES.get(id, 0))


static func name_key(id: String) -> String:
	return "shop.item.%s" % id


static func description_key(id: String) -> String:
	return "shop.desc.%s" % id


static func is_repeatable(id: String) -> bool:
	return id == BELT


static func icon(_id: String) -> Texture2D:
	return null
