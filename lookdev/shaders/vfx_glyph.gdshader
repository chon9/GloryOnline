shader_type spatial;
// Rotating glyph circle (bible 5.1): concentric rings, a rotating rune band, ticks, a hexagram and an outer
// crown of small triangles. Procedural, drawn on a flat quad (UV 0..1). No text, no texture.
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;

uniform vec4 core : source_color = vec4(0.95, 0.92, 1.0, 1.0);
uniform vec4 mid : source_color = vec4(0.54, 0.3, 1.0, 1.0);
uniform vec4 accent : source_color = vec4(0.42, 0.48, 1.0, 1.0);
uniform float energy = 2.5;
uniform float spin = 0.25;
uniform float reveal = 1.0;   // 0..1: rings draw on from the centre

float hash1(float n) { return fract(sin(n * 12.9898) * 43758.5453); }
float ring(float r, float c, float w) { return smoothstep(w, 0.0, abs(r - c)); }
float seg(vec2 p, vec2 a, vec2 b, float w) {
	vec2 pa = p - a;
	vec2 ba = b - a;
	float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
	return smoothstep(w, 0.0, length(pa - ba * h));
}

void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	float r = length(p);
	float t = TIME * spin;
	float a = atan(p.y, p.x);
	float g = 0.0;
	float hot = 0.0;
	g += ring(r, 0.96, 0.012) + ring(r, 0.9, 0.006) + ring(r, 0.66, 0.01) + ring(r, 0.6, 0.005) + ring(r, 0.3, 0.008);
	hot += ring(r, 0.96, 0.006);
	// rune band between 0.7 and 0.86 (rotating)
	float ar = a + t;
	float cells = 48.0;
	float cid = floor((ar / 6.28318 + 0.5) * cells);
	float cu = fract((ar / 6.28318 + 0.5) * cells);
	float cv = (r - 0.7) / 0.16;
	float rune = 0.0;
	if (cv > 0.0 && cv < 1.0) {
		vec2 q = vec2(cu, cv);
		float h1 = hash1(cid);
		float h2 = hash1(cid + 7.0);
		float h3 = hash1(cid + 13.0);
		rune += seg(q, vec2(0.5, 0.15), vec2(0.5, 0.85), 0.06);
		rune += seg(q, vec2(0.5, 0.2 + h1 * 0.6), vec2(0.15 + h2 * 0.2, 0.5 + h3 * 0.35), 0.06);
		rune += seg(q, vec2(0.5, 0.85 - h2 * 0.4), vec2(0.82, 0.6 - h1 * 0.3), 0.06) * step(0.35, h3);
		rune += seg(q, vec2(0.25, 0.85), vec2(0.75, 0.85), 0.05) * step(h1, 0.5);
	}
	g += rune * 0.9;
	// ticks on the outer ring (counter-rotating)
	float at = a - t * 1.5;
	float tick = smoothstep(0.03, 0.0, abs(fract((at / 6.28318) * 72.0) - 0.5) - 0.44) * step(0.9, r) * step(r, 0.95);
	g += tick * 0.7;
	// hexagram inside 0.6
	float rot = -t * 0.6;
	for (int k = 0; k < 6; k++) {
		float a0 = rot + float(k % 3) * 2.0944 + (k >= 3 ? 1.0472 : 0.0);
		float a1 = a0 + 2.0944;
		g += seg(p, vec2(cos(a0), sin(a0)) * 0.6, vec2(cos(a1), sin(a1)) * 0.6, 0.008);
	}
	// crown of small triangles outside the rim
	float cc = fract(((a + t * 0.5) / 6.28318) * 12.0);
	g += step(0.97, r) * step(r, 0.97 + 0.035 * (1.0 - abs(cc - 0.5) * 2.0));
	float centre = exp(-r * r * 30.0) * 0.6;
	float rv = smoothstep(reveal * 1.05 + 0.02, reveal * 1.05 - 0.05, r);
	vec3 c = mix(accent.rgb, mid.rgb, smoothstep(0.2, 0.9, r)) * g + core.rgb * (hot + centre) + core.rgb * rune * 0.4;
	ALBEDO = c * energy * rv;
	ALPHA = clamp(g + hot + centre, 0.0, 1.0) * rv * step(r, 1.02);
}
