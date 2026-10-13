shader_type spatial;
// Pro-league arena floor: concentric flagstone rings with radial joints, frost drifts in the cracks,
// a glowing boundary rune band and a team-split centre seal. Mid value so fighters read on top of it.
render_mode diffuse_lambert, specular_disabled;

uniform float radius = 9.0;
uniform vec4 stone_a : source_color = vec4(0.30, 0.33, 0.45, 1.0);
uniform vec4 stone_b : source_color = vec4(0.40, 0.43, 0.55, 1.0);
uniform vec4 grout : source_color = vec4(0.16, 0.18, 0.27, 1.0);
uniform vec4 frost : source_color = vec4(0.88, 0.94, 1.0, 1.0);
uniform vec4 rune_col : source_color = vec4(0.35, 0.85, 1.0, 1.0);
uniform vec4 team_a : source_color = vec4(0.18, 0.48, 1.0, 1.0);
uniform vec4 team_b : source_color = vec4(1.0, 0.23, 0.29, 1.0);
uniform float rune_energy = 2.6;
uniform vec4 shade_tint : source_color = vec4(0.40, 0.48, 0.84, 1.0);

varying vec3 lpos;
varying vec3 wpos;

float hash(vec2 p) { vec3 p3 = fract(vec3(p.xyx) * 0.1031); p3 += dot(p3, p3.yzx + 33.33); return fract((p3.x + p3.y) * p3.z); }
float vnoise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}
float fbm(vec2 p) { float s = 0.0, a = 0.5; for (int i = 0; i < 5; i++) { s += a * vnoise(p); p *= 2.1; a *= 0.5; } return s; }

void vertex() {
	lpos = VERTEX;
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = lpos.xz;
	float r = length(p);
	float a = atan(p.y, p.x);
	float rn = r / radius;
	// flagstone rings + radial joints (more joints on outer rings)
	float ring_w = 1.35;
	float ring_i = floor(r / ring_w);
	float fr = fract(r / ring_w);
	float segs = max(6.0, floor(ring_i * 6.0 + 6.0));
	float ang = (a / 6.28318 + 0.5) * segs + hash(vec2(ring_i, 3.0)) * 3.0;
	float fa = fract(ang);
	float id = hash(vec2(ring_i, floor(ang)));
	float warp = (fbm(p * 1.3) - 0.5) * 0.08;
	float jr = smoothstep(0.0, 0.035, fr + warp) * smoothstep(0.0, 0.035, 1.0 - fr - warp);
	float arc_len = r * 6.28318 / segs;
	float ja = smoothstep(0.0, 0.04 / max(arc_len, 0.3), fa + warp * 0.3) * smoothstep(0.0, 0.04 / max(arc_len, 0.3), 1.0 - fa - warp * 0.3);
	float joint = 1.0 - jr * ja;
	float n = fbm(p * 0.9 + id * 10.0);
	float n2 = fbm(p * 4.0);
	vec3 c = mix(stone_a.rgb, stone_b.rgb, id * 0.7 + n * 0.5);
	c *= 0.86 + 0.24 * n2;
	// bevel: darken stone edges a little (painted cavity)
	float edge = 1.0 - min(min(fr, 1.0 - fr) * 6.0, min(fa, 1.0 - fa) * arc_len * 4.0);
	c *= 1.0 - clamp(edge, 0.0, 1.0) * 0.18;
	c = mix(c, grout.rgb, joint * 0.9);
	// frost drifts (in the joints and blown patches)
	float fp = smoothstep(0.6, 0.75, fbm(p * 0.35 + vec2(4.0, 1.0) + fbm(p * 1.7) * 0.6));
	c = mix(c, frost.rgb * (0.85 + 0.1 * n2), fp * 0.45);
	c = mix(c, mix(c, frost.rgb * 0.7, 0.45), joint * 0.45);
	vec3 emit = vec3(0.0);
	// boundary rune band
	float band_c = radius - 0.75;
	float band = smoothstep(0.42, 0.36, abs(r - band_c));
	float lines = smoothstep(0.035, 0.0, abs(abs(r - band_c) - 0.38));
	float glyph_cell = floor((a / 6.28318 + 0.5) * 96.0);
	float gx = fract((a / 6.28318 + 0.5) * 96.0);
	float gy = (r - band_c + 0.3) / 0.6;
	float g = 0.0;
	float h1 = hash(vec2(glyph_cell, 1.0)), h2 = hash(vec2(glyph_cell, 2.0)), h3 = hash(vec2(glyph_cell, 3.0));
	// pseudo runes: a vertical stroke + 1-2 diagonal / horizontal ticks per cell
	g += smoothstep(0.09, 0.03, abs(gx - 0.5)) * step(0.1, gy) * step(gy, 0.9);
	g += smoothstep(0.08, 0.02, abs(gy - (0.25 + h1 * 0.5) - (gx - 0.5) * (h2 - 0.5) * 2.0)) * step(0.18, gx) * step(gx, 0.82) * step(0.3, h3);
	g += smoothstep(0.08, 0.02, abs(gy - 0.8 + (gx - 0.5) * 0.8)) * step(0.25, gx) * step(gx, 0.75) * step(h3, 0.6);
	g *= step(0.15, gy) * step(gy, 0.85) * step(hash(vec2(glyph_cell, 9.0)), 0.92);
	c = mix(c, c * 0.55, band);
	emit += rune_col.rgb * (lines * 0.9 + g * band * 1.0) * rune_energy;
	// centre seal: split team colours, thin gold ring
	float seal = smoothstep(0.04, 0.0, abs(r - 2.2)) + smoothstep(0.03, 0.0, abs(r - 1.85));
	float spokes = smoothstep(0.03, 0.0, abs(sin(a * 4.0)) * r) * step(r, 2.2) * step(0.4, r);
	vec3 team = mix(team_a.rgb, team_b.rgb, step(0.0, p.x));
	emit += team * (seal * 1.4 + spokes * 0.6) * 1.2;
	c = mix(c, c * 0.8, smoothstep(2.25, 2.1, r));
	ALBEDO = c;
	EMISSION = emit;
	ROUGHNESS = 0.85;
}

void light() {
	float ndl = dot(NORMAL, LIGHT);
	float band = smoothstep(-0.1, 0.35, ndl);
	if (LIGHT_IS_DIRECTIONAL) {
		DIFFUSE_LIGHT += mix(shade_tint.rgb, vec3(1.0), band * ATTENUATION) * LIGHT_COLOR / PI;
	} else {
		DIFFUSE_LIGHT += max(ndl, 0.0) * ATTENUATION * LIGHT_COLOR / PI;
	}
}
