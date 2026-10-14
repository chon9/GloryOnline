shader_type spatial;
// Painted lava (bible 4.2 hot accent): slow-flowing cooled crust plates (dark basalt, hard edges) floating on a
// bright molten core, HDR emissive cracks so bloom catches them, a hotter rim where crust meets melt.
render_mode diffuse_lambert, specular_disabled;

uniform vec4 crust : source_color = vec4(0.10, 0.05, 0.05, 1.0);
uniform vec4 crust_hi : source_color = vec4(0.28, 0.12, 0.08, 1.0);
uniform vec4 melt : source_color = vec4(1.0, 0.42, 0.08, 1.0);
uniform vec4 core : source_color = vec4(1.0, 0.86, 0.38, 1.0);
uniform float energy = 3.2;
uniform vec2 flow = vec2(0.0, 0.12);
uniform float crust_amount = 0.5;

varying vec3 wp;

float h(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float n(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h(i), h(i + vec2(1, 0)), f.x), mix(h(i + vec2(0, 1)), h(i + vec2(1, 1)), f.x), f.y);
}
float fbm(vec2 p) { float s = 0.0, a = 0.5; for (int i = 0; i < 4; i++) { s += a * n(p); p *= 2.05; a *= 0.5; } return s; }
// cellular crust plates
float cells(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p);
	float d1 = 8.0, d2 = 8.0;
	for (int y = -1; y <= 1; y++) for (int x = -1; x <= 1; x++) {
		vec2 g = vec2(float(x), float(y));
		vec2 o = vec2(h(i + g), h(i + g + 17.0));
		float d = length(g + o - f);
		if (d < d1) { d2 = d1; d1 = d; } else if (d < d2) { d2 = d; }
	}
	return d2 - d1;
}

void vertex() { wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }

void fragment() {
	vec2 p = wp.xz * 0.35 + flow * TIME;
	vec2 warp = vec2(fbm(p * 0.7 + TIME * 0.03), fbm(p * 0.7 - 11.0)) * 0.8;
	float edge = cells(p * 1.1 + warp);
	float plate = smoothstep(0.08, 0.22, edge) * smoothstep(1.0 - crust_amount - 0.15, 1.0 - crust_amount + 0.15, fbm(p * 0.5 + 3.0) + 0.25);
	float heat = 1.0 - plate;
	float pulse = 0.85 + 0.15 * sin(TIME * 1.7 + fbm(p * 2.0) * 6.0);
	vec3 mc = mix(melt.rgb, core.rgb, smoothstep(0.3, 0.9, fbm(p * 1.7 - TIME * 0.05)));
	vec3 cc = mix(crust.rgb, crust_hi.rgb, fbm(p * 3.0));
	ALBEDO = mix(mc * 0.4, cc, plate);
	float rim = smoothstep(0.25, 0.08, edge) * plate;
	EMISSION = mc * (heat * energy * pulse + rim * 1.2) + melt.rgb * plate * 0.06;
	ROUGHNESS = 0.8;
}
