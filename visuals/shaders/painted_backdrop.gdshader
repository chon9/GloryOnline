shader_type spatial;
// Painted distant backdrop (bible 3.2 "aerial perspective"): an inverted cylinder far outside the play space,
// painted with 3 layers of mountain ridges that fade into the horizon haze, snow caps and dry-brush strokes.
// Unshaded and fog-free: the haze is painted in, exactly like a matte painting behind the 3D set.
render_mode unshaded, cull_front, fog_disabled, shadows_disabled, depth_draw_never, blend_mix;

uniform vec4 haze : source_color = vec4(0.82, 0.90, 0.97, 1.0);
uniform vec4 far_col : source_color = vec4(0.62, 0.74, 0.90, 1.0);
uniform vec4 mid_col : source_color = vec4(0.45, 0.56, 0.78, 1.0);
uniform vec4 near_col : source_color = vec4(0.33, 0.42, 0.64, 1.0);
uniform vec4 snow_col : source_color = vec4(0.95, 0.97, 1.0, 1.0);
uniform vec4 warm_col : source_color = vec4(1.0, 0.86, 0.72, 1.0);

uniform float h_scale = 1.0;     // ridge height multiplier (smaller radius -> lower ridges)
uniform float snow_caps = 0.85;  // 0 = bare rock ridges (desert, night canyon, cave)
uniform float strata = 0.0;      // horizontal rock bands on the near ridges

varying vec3 wp;

float hash(float n) { return fract(sin(n) * 43758.5453); }
float n1(float x) { float i = floor(x); float f = fract(x); f = f * f * (3.0 - 2.0 * f); return mix(hash(i), hash(i + 1.0), f); }
float ridge(float a, float seed, float amp, float base) {
	float h = 0.0, w = 0.5, f = 1.0;
	for (int k = 0; k < 5; k++) { h += w * (1.0 - abs(n1(a * f + seed) * 2.0 - 1.0)); w *= 0.5; f *= 2.3; }
	return base + h * amp;
}
float h2(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vn(vec2 p) { vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h2(i), h2(i + vec2(1, 0)), f.x), mix(h2(i + vec2(0, 1)), h2(i + vec2(1, 1)), f.x), f.y); }

void vertex() { wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }

void fragment() {
	float a = atan(wp.z, wp.x) * 24.0;
	float y = wp.y / h_scale;
	vec4 outc = vec4(0.0);
	// far -> near layers (painter's order)
	float hs[3] = {ridge(a * 0.6, 3.0, 70.0, 18.0), ridge(a * 0.9, 17.0, 46.0, 6.0), ridge(a * 1.4, 41.0, 26.0, -4.0)};
	vec3 cs[3] = {far_col.rgb, mid_col.rgb, near_col.rgb};
	for (int i = 0; i < 3; i++) {
		float d = hs[i] - y;
		if (d > 0.0) {
			float stroke = vn(vec2(a * 6.0 + float(i) * 13.0, y * 0.08)) ;
			vec3 c = cs[i] * (0.92 + 0.14 * stroke);
			// snow caps: a hard painted band just under the ridge line, broken by strokes
			float cap = step(d, 6.0 + 10.0 * stroke + float(2 - i) * 4.0);
			c = mix(c, mix(snow_col.rgb, warm_col.rgb, 0.25 * (1.0 - float(i) * 0.4)), cap * snow_caps);
			c *= 1.0 - strata * 0.18 * step(0.5, fract(y * 0.08 + stroke * 0.4)) * float(i) * 0.5;
			// sun-side warm edge, fading down into haze at the foot (aerial perspective)
			float foot = clamp(1.0 - d / 60.0, 0.0, 1.0);
			c = mix(haze.rgb, c, mix(0.55, 0.9, foot) - 0.15 * float(2 - i));
			outc = vec4(c, 1.0);
		}
	}
	// ground haze band hides the cylinder bottom
	float band = smoothstep(4.0, -14.0, y);
	outc = mix(outc, vec4(haze.rgb, 1.0), band * (outc.a > 0.0 ? 1.0 : 0.0));
	ALBEDO = outc.rgb;
	ALPHA = outc.a;
}
