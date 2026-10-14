shader_type spatial;
// Painted water / ice sheet: deep -> shallow colour by a soft edge mask (UV.x = distance-to-shore 0..1 if the mesh
// provides it, else uniform), painted ripple bands and sky-glint streaks, crisp foam/frost rim. `ice` = 1 freezes it:
// no motion, cracked plates, white frost patches, cyan subsurface tint.
render_mode diffuse_lambert, specular_schlick_ggx, depth_draw_opaque;

uniform vec4 deep : source_color = vec4(0.10, 0.38, 0.52, 1.0);
uniform vec4 shallow : source_color = vec4(0.38, 0.78, 0.82, 1.0);
uniform vec4 glint : source_color = vec4(0.95, 1.0, 1.0, 1.0);
uniform vec4 frost : source_color = vec4(0.88, 0.95, 1.0, 1.0);
uniform float ice = 0.0;
uniform float speed = 0.05;
uniform float alpha = 0.88;

varying vec3 wp;

float h(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float n(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h(i), h(i + vec2(1, 0)), f.x), mix(h(i + vec2(0, 1)), h(i + vec2(1, 1)), f.x), f.y);
}
float fbm(vec2 p) { float s = 0.0, a = 0.5; for (int i = 0; i < 4; i++) { s += a * n(p); p *= 2.07; a *= 0.5; } return s; }

void vertex() { wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }

void fragment() {
	float t = TIME * speed * (1.0 - ice);
	vec2 p = wp.xz * 0.25;
	float big = fbm(p * 0.6 + vec2(t, t * 0.7));
	vec3 c = mix(deep.rgb, shallow.rgb, smoothstep(0.3, 0.75, big));
	// painted ripple bands
	float rip = smoothstep(0.62, 0.7, fbm(p * vec2(2.5, 0.9) + vec2(t * 3.0, 0.0)));
	c = mix(c, glint.rgb, rip * 0.35 * (1.0 - ice));
	if (ice > 0.0) {
		float crack = smoothstep(0.035, 0.0, abs(fbm(p * 1.6) - 0.5)) + smoothstep(0.02, 0.0, abs(fbm(p * 3.3 + 7.0) - 0.5)) * 0.6;
		float patch = smoothstep(0.55, 0.7, fbm(p * 0.8 + 3.0));
		c = mix(c, c * 1.35 + vec3(0.05, 0.1, 0.12), crack * ice);
		c = mix(c, frost.rgb, patch * 0.65 * ice);
		ROUGHNESS = mix(0.08, 0.6, patch);
	} else {
		ROUGHNESS = 0.06;
	}
	ALBEDO = c;
	METALLIC = 0.0;
	SPECULAR = 0.6;
	ALPHA = mix(alpha, 1.0, ice);
}
