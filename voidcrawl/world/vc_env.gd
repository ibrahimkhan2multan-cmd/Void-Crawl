class_name VCEnv
extends RefCounted
## Builds the dark-fantasy Environment (ambient, fog, tone-map). One place so the menu,
## dungeon and previews all share the same look.

static func make(quality: Dictionary, boss: bool = false) -> Environment:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.015, 0.008, 0.03)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.74, 0.70, 0.82)
	env.ambient_light_energy = 0.78
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.05
	if bool(quality.get("fog", true)):
		env.fog_enabled = true
		env.fog_light_color = Color(0.07, 0.04, 0.13)
		env.fog_density = 0.016
		env.fog_sky_affect = 0.0
	env.adjustment_enabled = true
	env.adjustment_saturation = 0.95
	env.adjustment_contrast = 1.06
	return env
