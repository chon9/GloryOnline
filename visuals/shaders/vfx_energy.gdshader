shader_type spatial;
// Energy body (spheres, tubes, pillars, bolts): cel-banded fresnel, rim/accent -> mid -> white-hot core
// facing the camera, HDR so bloom carries the glow. Ported from lookdev/shaders/vfx_energy.gdshader with
// instance uniforms (shared material, per-instance palette) and premultiplied alpha.
// vfade > 0 fades both ends along UV.y (pillars / beams), dissolve > 0 erodes it with noise.
render_mode unshaded, blend_premul_alpha, cull_back, depth_draw_never, shadows_disabled, fog_disabled;

instance uniform vec4 core : source_color = vec4(1.0, 0.98, 0.85, 1.0);
instance uniform vec4 mid : source_color = vec4(1.0, 0.65, 0.2, 1.0);
instance uniform vec4 accent : source_color = vec4(0.82, 0.16, 0.2, 1.0);
instance uniform float energy = 3.0;
instance uniform float fade = 1.0;
instance uniform float vfade = 0.0;
instance uniform float dissolve = 0.0;
instance uniform float additive = 0.5;

float hash2(vec2 p) { vec3 p3 = fract(vec3(p.xyx) * 0.1031); p3 += dot(p3, p3.yzx + 33.33); return fract((p3.x + p3.y) * p3.z); }
float vnoise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash2(i), hash2(i + vec2(1, 0)), f.x), mix(hash2(i + vec2(0, 1)), hash2(i + vec2(1, 1)), f.x), f.y);
}

void fragment() {
	float f = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	vec3 col = accent.rgb;
	col = mix(col, mid.rgb * max(energy * 0.4, 1.0), step(0.42, f));
	col = mix(col, core.rgb * energy, step(0.86, f));
	float a = fade * (0.7 + 0.3 * f);
	if (vfade > 0.0) {
		a *= smoothstep(0.0, vfade, UV.y) * smoothstep(1.0, 1.0 - vfade, UV.y);
	}
	if (dissolve > 0.0) {
		float n = vnoise(UV * vec2(18.0, 6.0) + TIME * 2.0);
		a *= step(dissolve, n);
	}
	if (a < 0.003) {
		discard;
	}
	ALBEDO = col * a;
	ALPHA = a * (1.0 - additive * step(0.42, f));
}
