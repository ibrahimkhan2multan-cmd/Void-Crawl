class_name VCMats
extends RefCounted
## Shared, cached materials and meshes. Reusing resources keeps memory low and lets the
## renderer batch work. One small generated noise texture gives every block its grain.

static var _mats: Dictionary = {}
static var _meshes: Dictionary = {}
static var _tex: ImageTexture = null

static func stone_texture() -> ImageTexture:
	if _tex != null:
		return _tex
	var n := 32
	var img := Image.create(n, n, false, Image.FORMAT_RGB8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 424242
	for y in n:
		for x in n:
			var v := 0.82 + rng.randf() * 0.18
			# faint brick-like mortar lines so blocks read as masonry
			if y % 16 == 0 or (x + (8 if (y / 16) % 2 == 1 else 0)) % 16 == 0:
				v *= 0.78
			img.set_pixel(x, y, Color(v, v, v))
	_tex = ImageTexture.create_from_image(img)
	return _tex

## Opaque lit material. emissive > 0 makes it self-lit (crystals, flames).
static func solid(color: Color, emissive: float = 0.0, textured: bool = false) -> StandardMaterial3D:
	var key := "s%s_%s_%s" % [color.to_html(), emissive, textured]
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 1.0
	m.metallic = 0.0
	m.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
	if textured:
		m.albedo_texture = stone_texture()
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	if emissive > 0.0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = emissive
	_mats[key] = m
	return m

## Material for MultiMesh blocks: tint comes from per-instance colour.
static func block_material() -> StandardMaterial3D:
	if _mats.has("block"):
		return _mats["block"]
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = stone_texture()
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	m.roughness = 1.0
	m.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
	_mats["block"] = m
	return m

static func glow_block_material() -> StandardMaterial3D:
	if _mats.has("glowblock"):
		return _mats["glowblock"]
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mats["glowblock"] = m
	return m

## Unshaded translucent material for telegraphs, rings and slashes.
static func fx(color: Color, additive: bool = false) -> StandardMaterial3D:
	var key := "fx%s_%s" % [color.to_html(true), additive]
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	if additive:
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_mats[key] = m
	return m

static func flash_overlay() -> StandardMaterial3D:
	if _mats.has("flash"):
		return _mats["flash"]
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(1, 1, 1, 0.65)
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mats["flash"] = m
	return m

static func box(size: Vector3) -> BoxMesh:
	var key := "b%s" % size
	if _meshes.has(key):
		return _meshes[key]
	var b := BoxMesh.new()
	b.size = size
	_meshes[key] = b
	return b

static func quad(size: Vector2) -> PlaneMesh:
	var key := "q%s" % size
	if _meshes.has(key):
		return _meshes[key]
	var p := PlaneMesh.new()
	p.size = size
	_meshes[key] = p
	return p

## Add a coloured box part to a parent. Returns the MeshInstance3D.
static func part(parent: Node3D, size: Vector3, pos: Vector3, color: Color, emissive: float = 0.0, node_name: String = "") -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = box(size)
	mi.material_override = solid(color, emissive)
	mi.position = pos
	if node_name != "":
		mi.name = node_name
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi

static var _blob: StandardMaterial3D = null

## Soft round contact shadow (radial gradient), shared by every actor.
static func blob_shadow() -> StandardMaterial3D:
	if _blob != null:
		return _blob
	var g := Gradient.new()
	g.colors = PackedColorArray([Color(0, 0, 0, 0.55), Color(0, 0, 0, 0.0)])
	g.offsets = PackedFloat32Array([0.15, 1.0])
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 64
	tex.height = 64
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	_blob = m
	return m

static func add_blob(parent: Node3D, size: float) -> void:
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	mi.mesh = q
	mi.rotation_degrees = Vector3(-90, 0, 0)
	mi.position = Vector3(0, 0.04, 0)
	mi.material_override = blob_shadow()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
