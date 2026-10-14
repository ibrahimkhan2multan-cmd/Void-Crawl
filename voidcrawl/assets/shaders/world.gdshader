shader_type spatial;
render_mode cull_back, diffuse_lambert, specular_disabled;

// VOIDCRAWL world material. Per-instance colour tints a tiny shared noise texture that is
// projected in world space, so every block (any scale) shows the same 1 m grain.
// Walls between the camera and the hero dissolve with a dither so the hero is never hidden.

uniform sampler2D tex : source_color, filter_nearest, repeat_enable;
uniform vec2 player_screen = vec2(0.5, 0.5);
uniform float player_depth = 12.0;
uniform float fade_radius = 0.14;
uniform float aspect = 1.7778;
uniform float fade_enabled = 1.0;

varying vec3 wpos;
varying vec3 wnorm;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnorm = abs(normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz));
}

void fragment() {
	vec2 uv;
	if (wnorm.y > 0.6) {
		uv = wpos.xz;
	} else if (wnorm.x > 0.6) {
		uv = wpos.zy;
	} else {
		uv = wpos.xy;
	}
	vec3 t = texture(tex, uv * 0.5).rgb;
	ALBEDO = COLOR.rgb * t;
	ROUGHNESS = 1.0;
	if (fade_enabled > 0.5) {
		float depth = -VERTEX.z;
		vec2 d = (SCREEN_UV - player_screen) * vec2(aspect, 1.0);
		float dist = length(d);
		if (depth < player_depth - 0.6 && dist < fade_radius) {
			float f = smoothstep(fade_radius * 0.35, fade_radius, dist);
			float n = fract(52.9829189 * fract(dot(FRAGCOORD.xy, vec2(0.06711056, 0.00583715))));
			if (n > f * 0.8 + 0.08) {
				discard;
			}
		}
	}
}
