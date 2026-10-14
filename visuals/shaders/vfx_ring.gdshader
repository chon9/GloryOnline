shader_type spatial;
// Shockwave ring / radial burst on a flat quad: hot white leading edge, coloured body, torn noisy inner edge,
// optional radial streaks (rays) and painted ground cracks. Ported from lookdev with instance uniforms.
// bb = true makes the quad face the camera (radial speed-line bursts).
render_mode unshaded, blend_premul_alpha, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

uniform bool bb = false;
instance uniform vec4 core : source_color = vec4(1.0, 0.97, 0.75, 1.0);
instance uniform vec4 mid : source_color = vec4(1.0, 0.77, 0.23, 1.0);
instance uniform vec4 accent : source_color = vec4(1.0, 0.35, 0.12, 1.0);
instance uniform float energy = 3.0;
instance uniform float radius = 0.8;
instance uniform float width = 0.12;
instance uniform float rays = 0.0;
instance uniform float cracks = 0.0;
instance uniform float fade = 1.0;
instance uniform float seed = 0.0;

float hash1(float n) { return fract(sin(n * 12.9898) * 43758.5453); }

void vertex() {
	if (bb) {
		vec3 sc = vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz), length(MODEL_MATRIX[2].xyz));
		mat4 mw = mat4(normalize(INV_VIEW_MATRIX[0]), normalize(INV_VIEW_MATRIX[1]), normalize(INV_VIEW_MATRIX[2]), MODEL_MATRIX[3]);
		MODELVIEW_MATRIX = VIEW_MATRIX * mw * mat4(vec4(sc.x, 0.0, 0.0, 0.0), vec4(0.0, sc.y, 0.0, 0.0), vec4(0.0, 0.0, sc.z, 0.0), vec4(0.0, 0.0, 0.0, 1.0));
	}
}

void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	float r = length(p);
	float a = atan(p.y, p.x);
	float k = (a / 6.28318 + 0.5);
	float n = hash1(floor(k * 64.0) + seed) * 0.5 + hash1(floor(k * 17.0) + 3.0 + seed) * 0.5;
	float has_w = step(0.001, width);
	float body = smoothstep(radius - width * (0.6 + n), radius, r) * smoothstep(radius + 0.01, radius - 0.01, r) * has_w;
	float lead = smoothstep(radius - 0.025, radius, r) * smoothstep(radius + 0.01, radius - 0.002, r) * has_w;
	float streak = 0.0;
	if (rays > 0.0) {
		float s = pow(hash1(floor(k * 90.0) + seed * 7.0), 6.0);
		streak = s * smoothstep(radius * 1.15, radius * 0.3, r) * smoothstep(0.05, radius * 0.5, r) * rays;
	}
	float crack = 0.0;
	if (cracks > 0.0) {
		// 7 jagged crack lines radiating from the centre, painted dark
		float ck = k * 7.0 + seed;
		float cid = floor(ck);
		float wob = (hash1(cid + floor(r * 9.0)) - 0.5) * 0.25;
		float lane = abs(fract(ck) - 0.5 - wob);
		float len = 0.45 + 0.5 * hash1(cid * 3.1 + seed);
		crack = step(lane, 0.035 * (1.0 - r / len)) * step(r, len) * step(0.06, r) * cracks;
	}
	vec3 c = mix(accent.rgb, mid.rgb, body) * body * max(energy * 0.5, 1.0) + core.rgb * lead * energy + mix(mid.rgb, core.rgb, 0.5) * streak * energy;
	float glow = clamp(body + lead + streak, 0.0, 1.0) * fade;
	float ca = crack * fade;
	if (glow + ca < 0.003) {
		discard;
	}
	// glow adds (premultiplied, low alpha); cracks paint a dark line over the floor
	ALBEDO = c * fade + vec3(0.06, 0.045, 0.05) * ca;
	ALPHA = clamp(glow * 0.35 + ca * 0.85, 0.0, 1.0);
}
