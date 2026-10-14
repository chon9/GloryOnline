shader_type spatial;
// Light-streak ribbon (projectile trails, dash speed lines, lightning bolts): UV.x = 0 head .. 1 tail,
// UV.y = across. Cel bands across the ribbon (white-hot centre line, element mid, accent edge) and a razor
// taper toward the tail; the tail erodes in steps instead of a soft fade.
render_mode unshaded, blend_premul_alpha, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

instance uniform vec4 core : source_color = vec4(1.0);
instance uniform vec4 mid : source_color = vec4(0.5, 0.8, 1.0, 1.0);
instance uniform vec4 accent : source_color = vec4(0.2, 0.4, 1.0, 1.0);
instance uniform float energy = 3.0;
instance uniform float fade = 1.0;

float hash2(vec2 p) { vec3 p3 = fract(vec3(p.xyx) * 0.1031); p3 += dot(p3, p3.yzx + 33.33); return fract((p3.x + p3.y) * p3.z); }

void fragment() {
	float u = UV.x;
	float v = abs(UV.y - 0.5) * 2.0;
	float w = (1.0 - u) * smoothstep(0.0, 0.06, u + 0.02);
	float m = step(v, w);
	float er = hash2(vec2(floor(u * 24.0), floor(UV.y * 3.0)));
	m *= step(er * 0.35, (1.0 - u) * fade);
	float b = 1.0 - v / max(w, 1e-3);
	vec3 c = accent.rgb;
	c = mix(c, mid.rgb * max(energy * 0.5, 1.0), step(0.35, b));
	c = mix(c, core.rgb * energy, step(0.72, b));
	float a = m * fade * COLOR.a;
	if (a < 0.003) {
		discard;
	}
	ALBEDO = c * a;
	ALPHA = a * 0.3;
}
