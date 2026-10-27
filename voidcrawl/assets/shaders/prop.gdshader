shader_type spatial;
render_mode cull_back, diffuse_lambert, specular_disabled;

// Small dungeon dressing (vines, banners, icicles, barrels...). Instance colour tints a detail texture.
// Props mounted on walls use the same see-through dither as the walls so they never block the hero.

uniform sampler2D tex : source_color, filter_nearest, repeat_enable;
uniform vec2 player_screen = vec2(0.5, 0.5);
uniform float player_depth = 12.0;
uniform float fade_radius = 0.14;
uniform float aspect = 1.7778;
uniform float fade_enabled = 0.0;

void fragment() {
	vec3 t = texture(tex, UV * 2.0).rgb;
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
