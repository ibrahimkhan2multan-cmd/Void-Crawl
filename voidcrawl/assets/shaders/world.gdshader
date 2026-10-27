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
uniform float frost_mode = 0.0;      // 1 = ice dungeon: the moss channel becomes frost

varying vec3 wpos;
varying vec3 wnorm;

float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash21(i), hash21(i + vec2(1.0, 0.0)), f.x), mix(hash21(i + vec2(0.0, 1.0)), hash21(i + vec2(1.0, 1.0)), f.x), f.y);
}

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
	// procedural stonework: slabs on floors and tops, offset brick courses on walls
	vec2 q = uv;
	float brick_h = 0.5;
	if (wnorm.y > 0.6) {
		q = uv;
	} else {
		q = vec2(uv.x, uv.y / brick_h);
	}
	float row = floor(q.y);
	q.x += mod(row, 2.0) * 0.5;
	vec2 cell = floor(q);
	vec2 f = fract(q);
	float edge = min(min(f.x, 1.0 - f.x), min(f.y, 1.0 - f.y));
	float mortar = smoothstep(0.0, 0.09, edge);
	float h = fract(sin(dot(cell, vec2(12.9898, 78.233))) * 43758.5453);
	float tint = 0.86 + 0.28 * h;
	float bevel = smoothstep(0.09, 0.22, edge);
	vec3 stone = COLOR.rgb * t * tint * mix(0.55, 1.0, mortar) * (0.94 + 0.12 * bevel);
	if (wnorm.y <= 0.6) {
		// walls: darker near the floor, lit rim near the top
		stone *= mix(0.55, 1.0, smoothstep(0.0, 1.4, wpos.y));
		stone += vec3(0.05, 0.035, 0.08) * smoothstep(2.0, 2.8, wpos.y);
	}
	// cracked bricks: a thin dark zig-zag on roughly one brick in six
	if (h > 0.84) {
		float cx = 0.3 + 0.4 * f.y + 0.06 * sin(f.y * 14.0);
		float crack = step(abs(f.x - cx), 0.035) * step(0.12, f.y) * step(f.y, 0.88);
		stone *= 1.0 - 0.55 * crack;
	}
	// moss (or frost): chunky 8-per-metre pixels, thicker along mortar and low on walls
	float amt = clamp(1.0 - COLOR.a, 0.0, 1.0);
	if (amt > 0.01) {
		vec2 pq = floor(uv * 8.0) / 8.0;
		float n = vnoise(pq * 1.25) * 0.6 + vnoise(pq * 3.3 + 9.0) * 0.4;
		float low = (wnorm.y > 0.6) ? 0.0 : (1.0 - smoothstep(0.1, 2.0, wpos.y)) * 0.2;
		float edge_grow = (1.0 - mortar) * 0.25;
		float m = smoothstep(0.74 - amt * 0.2, 0.84 - amt * 0.2, n + low + edge_grow * amt);
		float px = hash21(pq * 17.0);
		if (frost_mode > 0.5) {
			vec3 ice = mix(vec3(0.78, 0.9, 1.0), vec3(1.0), px * 0.8);
			stone = mix(stone, ice * (0.8 + 0.3 * px), m * 0.85);
			if (m > 0.5 && px > 0.93) { stone = vec3(1.0); }
		} else {
			vec3 mc = mix(vec3(0.07, 0.2, 0.06), vec3(0.2, 0.42, 0.12), px);
			stone = mix(stone, mc, m * 0.92);
			if (m > 0.5 && px > 0.9) { stone = vec3(0.34, 0.52, 0.16); }
		}
	}
	// slow wet stains on floors
	if (wnorm.y > 0.6) {
		float st = vnoise(floor(uv * 6.0) / 6.0 * 0.5 + 40.0);
		stone *= 1.0 - 0.18 * smoothstep(0.62, 0.8, st);
	}
	ALBEDO = stone;
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
