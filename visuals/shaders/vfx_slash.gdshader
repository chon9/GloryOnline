shader_type spatial;
// Anime crescent slash (bible 5.1): thick in the middle, razor tips, white-hot core on the leading edge,
// coloured falloff, alpha-erosion dissolve instead of a linear fade. Ported from lookdev with instance
// uniforms so every arc shares one material. UV.x = along the arc, UV.y = across (0 inner, 1 outer).
render_mode unshaded, blend_premul_alpha, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

instance uniform vec4 core : source_color = vec4(1.0);
instance uniform vec4 mid : source_color = vec4(0.81, 0.9, 1.0, 1.0);
instance uniform vec4 accent : source_color = vec4(0.44, 0.66, 1.0, 1.0);
instance uniform float energy = 3.0;
instance uniform float progress = 0.5;   // 0 = starts, 0.5 = fully drawn, 1 = dissolved
instance uniform float alpha_mul = 1.0;
instance uniform float fade = 1.0;

float hash(vec2 p) { vec3 p3 = fract(vec3(p.xyx) * 0.1031); p3 += dot(p3, p3.yzx + 33.33); return fract((p3.x + p3.y) * p3.z); }
float vnoise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

void fragment() {
	float u = UV.x;
	float v = UV.y;
	float head = clamp(progress * 2.0, 0.0, 1.0);
	float drawn = smoothstep(head + 0.02, head - 0.05, u);
	float tail = smoothstep(0.0, 0.35, u - (head - 1.0) * 0.9);
	float thick = sin(clamp(u, 0.0, 1.0) * PI);
	float edge = smoothstep(1.0 - thick, 1.0 - thick + 0.03, v) * smoothstep(1.0, 0.975, v);
	float streak = vnoise(vec2(u * 6.0, v * 40.0));
	float er = smoothstep(0.5, 1.0, progress);
	float n = vnoise(vec2(u * 18.0, v * 9.0)) * 0.6 + vnoise(vec2(u * 45.0, v * 25.0)) * 0.4;
	float keep = smoothstep(er - 0.05, er + 0.05, n + (1.0 - er) * 0.2);
	float a = edge * drawn * tail * keep * alpha_mul * fade;
	float band_v = (v - (1.0 - thick)) / max(thick, 0.001);
	vec3 c = accent.rgb;
	c = mix(c, mid.rgb * max(energy * 0.5, 1.0), step(0.45, band_v));
	c = mix(c, core.rgb * energy, step(0.82, band_v));
	c *= 0.9 + 0.2 * streak;
	float body_alpha = mix(0.78, 1.0, step(0.45, band_v));
	a = clamp(a * body_alpha, 0.0, 1.0);
	if (a < 0.003) {
		discard;
	}
	ALBEDO = c * a;
	ALPHA = a * mix(0.95, 0.4, step(0.82, band_v));
}
