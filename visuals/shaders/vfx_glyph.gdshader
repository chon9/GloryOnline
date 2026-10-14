shader_type spatial;
// Rotating glyph circle (bible 5.1): concentric rings, a rotating rune band, counter-rotating ticks, an
// element-specific inner figure and a crown of small triangles. Procedural, flat quad (UV 0..1), no text.
// Ported from lookdev/shaders/vfx_glyph.gdshader with instance uniforms and per-element inner figures:
// style 0 arcane hexagram, 1 holy sunburst + cross, 2 shadow pentagram + inward thorns, 3 nature petals,
// 4 fire triangles, 5 ice snowflake, 6 lightning zigzag ring, 7 qi taiji arcs.
render_mode unshaded, blend_premul_alpha, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

uniform bool bb = false;
instance uniform vec4 core : source_color = vec4(0.95, 0.92, 1.0, 1.0);
instance uniform vec4 mid : source_color = vec4(0.54, 0.3, 1.0, 1.0);
instance uniform vec4 accent : source_color = vec4(0.42, 0.48, 1.0, 1.0);
instance uniform float energy = 2.5;
instance uniform float spin = 0.25;
instance uniform float reveal = 1.0;   // 0..1: rings draw on from the centre
instance uniform float fade = 1.0;
instance uniform float style = 0.0;
instance uniform float seed = 0.0;

float hash1(float n) { return fract(sin(n * 12.9898) * 43758.5453); }
float ring(float r, float c, float w) { return smoothstep(w, 0.0, abs(r - c)); }
float seg(vec2 p, vec2 a, vec2 b, float w) {
	vec2 pa = p - a;
	vec2 ba = b - a;
	float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
	return smoothstep(w, 0.0, length(pa - ba * h));
}

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
	if (r > 1.03) {
		discard;
	}
	float t = TIME * spin + seed * 6.2832;
	float a = atan(p.y, p.x);
	float g = 0.0;
	float hot = 0.0;
	int st = int(style + 0.5);
	g += ring(r, 0.96, 0.014) + ring(r, 0.9, 0.007) + ring(r, 0.66, 0.011) + ring(r, 0.6, 0.006) + ring(r, 0.3, 0.009);
	hot += ring(r, 0.96, 0.007);
	// rune band between 0.7 and 0.86 (rotating)
	float ar = a + t;
	float cells = 40.0;
	float cid = floor((ar / 6.28318 + 0.5) * cells);
	float cu = fract((ar / 6.28318 + 0.5) * cells);
	float cv = (r - 0.7) / 0.16;
	float rune = 0.0;
	if (cv > 0.0 && cv < 1.0) {
		vec2 q = vec2(cu, cv);
		float h1 = hash1(cid + seed * 31.0);
		float h2 = hash1(cid + 7.0);
		float h3 = hash1(cid + 13.0);
		rune += seg(q, vec2(0.5, 0.15), vec2(0.5, 0.85), 0.07);
		rune += seg(q, vec2(0.5, 0.2 + h1 * 0.6), vec2(0.15 + h2 * 0.2, 0.5 + h3 * 0.35), 0.07);
		rune += seg(q, vec2(0.5, 0.85 - h2 * 0.4), vec2(0.82, 0.6 - h1 * 0.3), 0.07) * step(0.35, h3);
		rune += seg(q, vec2(0.25, 0.85), vec2(0.75, 0.85), 0.06) * step(h1, 0.5);
	}
	g += rune * 0.9;
	float at = a - t * 1.5;
	float tick = smoothstep(0.03, 0.0, abs(fract((at / 6.28318) * 72.0) - 0.5) - 0.44) * step(0.9, r) * step(r, 0.95);
	g += tick * 0.7;
	// element figure inside 0.6
	float rot = -t * 0.6;
	float fig = 0.0;
	if (st == 0 || st == 5) {
		for (int k = 0; k < 6; k++) {
			float a0 = rot + float(k % 3) * 2.0944 + (k >= 3 ? 1.0472 : 0.0);
			float a1 = a0 + 2.0944;
			fig += seg(p, vec2(cos(a0), sin(a0)) * 0.6, vec2(cos(a1), sin(a1)) * 0.6, 0.009);
		}
		if (st == 5) {
			// snowflake arms with side barbs
			for (int k = 0; k < 6; k++) {
				float a0 = rot + float(k) * 1.0472;
				vec2 d = vec2(cos(a0), sin(a0));
				vec2 nn = vec2(-d.y, d.x);
				fig += seg(p, vec2(0.0), d * 0.58, 0.012);
				fig += seg(p, d * 0.32, d * 0.42 + nn * 0.1, 0.009) + seg(p, d * 0.32, d * 0.42 - nn * 0.1, 0.009);
			}
		}
	} else if (st == 1) {
		float rays = smoothstep(0.08, 0.0, abs(fract((a + rot) / 6.28318 * 16.0) - 0.5) - 0.42) * step(0.32, r) * step(r, 0.58);
		fig += rays * 0.8;
		fig += seg(p, vec2(0.0, -0.5), vec2(0.0, 0.5), 0.014) + seg(p, vec2(-0.32, 0.12), vec2(0.32, 0.12), 0.014);
	} else if (st == 2) {
		for (int k = 0; k < 5; k++) {
			float a0 = rot + float(k) * 2.5133;
			float a1 = a0 + 2.5133;
			fig += seg(p, vec2(cos(a0), sin(a0)) * 0.6, vec2(cos(a1), sin(a1)) * 0.6, 0.009);
		}
		float thorn = fract((a - rot * 2.0) / 6.28318 * 24.0);
		fig += step(0.62, r) * step(r, 0.62 + 0.07 * (1.0 - abs(thorn - 0.5) * 2.0));
	} else if (st == 3) {
		for (int k = 0; k < 6; k++) {
			float a0 = rot + float(k) * 1.0472;
			fig += ring(length(p - vec2(cos(a0), sin(a0)) * 0.3), 0.3, 0.008);
		}
	} else if (st == 4) {
		for (int k = 0; k < 6; k++) {
			float a0 = rot + float(k % 3) * 2.0944 + (k >= 3 ? 1.0472 : 0.0);
			float a1 = a0 + 2.0944;
			float rr = k >= 3 ? 0.42 : 0.6;
			fig += seg(p, vec2(cos(a0), sin(a0)) * rr, vec2(cos(a1), sin(a1)) * rr, 0.01);
		}
	} else if (st == 6) {
		float z = fract((a + rot) / 6.28318 * 18.0);
		float zr = 0.45 + 0.1 * abs(z - 0.5) * 2.0;
		fig += smoothstep(0.012, 0.0, abs(r - zr));
		for (int k = 0; k < 3; k++) {
			float a0 = rot + float(k) * 2.0944;
			vec2 d = vec2(cos(a0), sin(a0));
			vec2 nn = vec2(-d.y, d.x);
			fig += seg(p, d * 0.1, d * 0.3 + nn * 0.08, 0.01) + seg(p, d * 0.3 + nn * 0.08, d * 0.28 - nn * 0.06, 0.01) + seg(p, d * 0.28 - nn * 0.06, d * 0.5, 0.01);
		}
	} else {
		float s = sin(a + rot);
		fig += smoothstep(0.012, 0.0, abs(length(p - vec2(cos(rot), sin(rot)) * 0.15) - 0.15)) * step(0.0, s);
		fig += smoothstep(0.012, 0.0, abs(length(p + vec2(cos(rot), sin(rot)) * 0.15) - 0.15)) * step(s, 0.0);
		fig += ring(r, 0.45, 0.008);
	}
	g += fig;
	float cc = fract(((a + t * 0.5) / 6.28318) * 12.0);
	g += step(0.97, r) * step(r, 0.97 + 0.035 * (1.0 - abs(cc - 0.5) * 2.0));
	float centre = exp(-r * r * 30.0) * 0.3;
	float rv = smoothstep(reveal * 1.05 + 0.02, reveal * 1.05 - 0.05, r);
	vec3 c = mix(accent.rgb, mid.rgb, smoothstep(0.2, 0.9, r)) * g + core.rgb * (hot + centre) + core.rgb * rune * 0.4 + core.rgb * fig * 0.3;
	float m = clamp(g + hot + centre, 0.0, 1.0) * rv * fade;
	if (m < 0.003) {
		discard;
	}
	ALBEDO = c * energy * rv * fade;
	ALPHA = m * 0.4;
}
