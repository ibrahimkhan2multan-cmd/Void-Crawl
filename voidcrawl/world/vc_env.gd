class_name VCEnv
extends RefCounted
## Builds the dark-fantasy Environment (ambient, fog, tone-map). One place so the menu,
## dungeon and previews all share the same look.

static func make(quality: Dictionary, boss: bool = false, palette: String = "crypt") -> Environment:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.015, 0.008, 0.03)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.74, 0.70, 0.82)
	env.ambient_light_energy = 0.78
	if palette == "ember":
		env.ambient_light_color = Color(0.9, 0.68, 0.58)
		env.background_color = Color(0.04, 0.012, 0.01)
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.05
	if bool(quality.get("fog", true)):
		env.fog_enabled = true
		env.fog_light_color = Color(0.16, 0.05, 0.03) if palette == "ember" else Color(0.07, 0.04, 0.13)
		env.fog_density = 0.016
		env.fog_sky_affect = 0.0
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.08
	env.adjustment_contrast = 1.1
	if bool(quality.get("glow", true)):
		env.glow_enabled = true
		env.glow_intensity = 0.7
		env.glow_strength = 1.0
		env.glow_bloom = 0.05
		env.glow_hdr_threshold = 0.95
		env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	return env

## Minimal environment: flat ambient, no fog, no tone-map, no adjustments, no glow.
static func make_safe() -> Environment:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.015, 0.008, 0.03)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.8, 0.76, 0.88)
	env.ambient_light_energy = 0.9
	return env
