shader_type spatial;
// Molten portal membrane for the Lava Cave gate: a slow spiralling heat-haze of molten bands in polar UV space,
// dark smouldering core, hot rim, cellular crust flecks. Unshaded + emissive, partially transparent so the cavern
// shows through the gaps (no flat solid disc).
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never, shadows_disabled;

uniform vec4 hot : source_color = vec4(1.0, 0.62, 0.2, 1.0);
uniform vec4 deep : source_color = vec4(0.55, 0.08, 0.04, 1.0);
uniform float energy = 2.4;
uniform float speed = 0.06;

float h(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float n(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h(i), h(i + vec2(1, 0)), f.x), mix(h(i + vec2(0, 1)), h(i + vec2(1, 1)), f.x), f.y);
}
float fbm(vec2 p) { float s = 0.0, a = 0.5; for (int i = 0; i < 4; i++) { s += a * n(p); p *= 2.03; a *= 0.5; } return s; }

void fragment() {
	vec2 q = UV * 2.0 - 1.0;
	float r = length(q);
	float a = atan(q.y, q.x) / 6.28318;
	float t = TIME * speed;
	vec2 sp = vec2(a * 6.0 + r * 2.5 - t * 3.0, r * 3.0 - t);
	float swirl = fbm(sp * 2.0 + fbm(sp * 3.0 + t) * 1.5);
	float bands = smoothstep(0.45, 0.7, swirl);
	float rim = smoothstep(0.7, 0.98, r) * (1.0 - smoothstep(0.98, 1.0, r));
	vec3 c = mix(deep.rgb * 0.4, hot.rgb, bands * (0.35 + 0.65 * r));
	c += hot.rgb * rim * 1.5;
	ALBEDO = c;
	EMISSION = c * energy;
	ALPHA = clamp((0.25 + 0.55 * bands) * (0.4 + 0.6 * r) + rim, 0.0, 0.9) * (1.0 - smoothstep(0.99, 1.0, r));
}
