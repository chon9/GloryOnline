shader_type spatial;
// Shockwave ring / radial burst on a flat quad: hot white leading edge, coloured body, torn noisy inner edge,
// optional radial streaks.
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;

uniform vec4 core : source_color = vec4(1.0, 0.97, 0.75, 1.0);
uniform vec4 mid : source_color = vec4(1.0, 0.77, 0.23, 1.0);
uniform vec4 accent : source_color = vec4(1.0, 0.35, 0.12, 1.0);
uniform float energy = 3.0;
uniform float radius = 0.8;
uniform float width = 0.12;
uniform float rays = 0.0;

float hash1(float n) { return fract(sin(n * 12.9898) * 43758.5453); }

void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	float r = length(p);
	float a = atan(p.y, p.x);
	float k = (a / 6.28318 + 0.5);
	float n = hash1(floor(k * 64.0)) * 0.5 + hash1(floor(k * 17.0) + 3.0) * 0.5;
	float body = smoothstep(radius - width * (0.6 + n), radius, r) * smoothstep(radius + 0.01, radius - 0.01, r) * step(0.001, width);
	float lead = smoothstep(radius - 0.025, radius, r) * smoothstep(radius + 0.01, radius - 0.002, r) * step(0.001, width);
	float streak = 0.0;
	if (rays > 0.0) {
		float s = pow(hash1(floor(k * 90.0)), 6.0);
		streak = s * smoothstep(radius * 1.15, radius * 0.3, r) * smoothstep(0.05, radius * 0.5, r) * rays;
	}
	vec3 c = mix(accent.rgb, mid.rgb, body) * body + core.rgb * lead * 1.5 + mix(mid.rgb, core.rgb, 0.5) * streak;
	ALBEDO = c * energy;
	ALPHA = clamp(body + lead + streak, 0.0, 1.0);
}
