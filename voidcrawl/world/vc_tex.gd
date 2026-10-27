class_name VCTex
extends RefCounted
## Procedural pixel-art detail textures. Each is a small tileable 16x16 grey-ish pattern that is tinted by the
## material colour, so one shared set gives every coloured box cloth weave, riveted metal, fur, bone, ice...
## One tile covers 0.5 world units, so texel size is the same on every part (Minecraft-style).

const N := 16
static var _cache: Dictionary = {}

static func texture(style: String) -> ImageTexture:
	if _cache.has(style):
		return _cache[style]
	var img := Image.create(N, N, false, Image.FORMAT_RGB8)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(style) + 1234
	for y in N:
		for x in N:
			img.set_pixel(x, y, _px(style, x, y, rng))
	if style in ["metal", "plate"]:
		_rivets(img)
	if style == "bone":
		_cracks(img, rng)
	if style == "ice":
		_sparkle(img, rng)
	if style == "stone":
		_chips(img, rng)
	img.generate_mipmaps()
	var t := ImageTexture.create_from_image(img)
	_cache[style] = t
	return t

static func _g(v: float) -> Color:
	v = clampf(v, 0.0, 1.0)
	return Color(v, v, v)

static func _px(style: String, x: int, y: int, rng: RandomNumberGenerator) -> Color:
	var n := rng.randf()
	# bevel: lit top/left edge, shaded bottom/right edge (gives every panel a chunky 3D rim)
	var bev := 0.0
	if y == 0 or x == 0:
		bev = 0.035
	if y == N - 1 or x == N - 1:
		bev = -0.08
	match style:
		"cloth":
			var weave := 0.035 if (x + y) % 2 == 0 else -0.035
			return _g(0.88 + (n - 0.5) * 0.1 + weave + bev * 0.7)
		"leather":
			var stitch := -0.1 if (y == 2 or y == N - 3) and x % 3 != 0 else 0.0
			return _g(0.84 + (n - 0.5) * 0.14 + stitch + bev)
		"metal":
			var streak := 0.0
			if y % 5 == 2 and x > 3 and x < 12:
				streak = 0.06
			return _g(0.9 + (n - 0.5) * 0.06 + streak + bev * 1.4)
		"plate":
			var panel := -0.07 if x == N / 2 or y == N / 2 else 0.0
			return _g(0.92 + (n - 0.5) * 0.05 + panel + bev * 1.5)
		"skin":
			return _g(0.96 + (n - 0.5) * 0.06 + bev * 0.3)
		"fur":
			var col_str := 0.5 + 0.5 * sin(float(x) * 2.3 + float((x * 7) % 5))
			return _g(0.82 + (n - 0.5) * 0.12 + col_str * 0.1 - 0.05 * float((y + x * 3) % 4 == 0) + bev * 0.3)
		"bone":
			return _g(0.93 + (n - 0.5) * 0.07 + bev)
		"ice":
			var streak2 := 0.07 if (x + y) % 7 == 0 else 0.0
			return _g(0.93 + (n - 0.5) * 0.06 + streak2 + bev * 0.8)
		"stone":
			return _g(0.86 + (n - 0.5) * 0.13 + bev)
		"glow":
			var grid := -0.05 if x % 8 == 0 or y % 8 == 0 else 0.0
			return _g(1.0 + (n - 0.5) * 0.04 + grid)
	return _g(0.9 + (n - 0.5) * 0.08 + bev)

static func _rivets(img: Image) -> void:
	for p in [Vector2i(2, 2), Vector2i(13, 2), Vector2i(2, 13), Vector2i(13, 13)]:
		img.set_pixel(p.x, p.y, _g(0.6))
		img.set_pixel(p.x - 1, p.y - 1, _g(1.0))

static func _cracks(img: Image, rng: RandomNumberGenerator) -> void:
	for k in 2:
		var x := rng.randi_range(3, 12)
		var y := rng.randi_range(2, 6)
		for i in 5:
			img.set_pixel(clampi(x, 0, N - 1), clampi(y + i, 0, N - 1), _g(0.58))
			x += rng.randi_range(-1, 1)

static func _sparkle(img: Image, rng: RandomNumberGenerator) -> void:
	for k in 3:
		img.set_pixel(rng.randi_range(2, 13), rng.randi_range(2, 13), _g(1.0))

static func _chips(img: Image, rng: RandomNumberGenerator) -> void:
	for k in 4:
		var x := rng.randi_range(1, 13)
		var y := rng.randi_range(1, 13)
		img.set_pixel(x, y, _g(0.65))
		img.set_pixel(x + 1, y, _g(0.7))
		img.set_pixel(x, y + 1, _g(0.75))

## Pick a sensible style from a part's colour when the caller did not name one.
static func auto_style(c: Color, emissive: float) -> String:
	if emissive >= 1.0:
		return "glow"
	var h := c.h
	var s := c.s
	var v := c.v
	if v > 0.55 and s > 0.1 and s < 0.55 and h > 0.02 and h < 0.1:
		return "skin"
	if h > 0.5 and h < 0.64 and v > 0.7 and s < 0.6:
		return "ice"
	if s < 0.2 and v > 0.5 and c.r >= c.b:
		return "bone"
	if s < 0.34 and c.b >= c.r and v > 0.3:
		return "metal"
	return "cloth"
