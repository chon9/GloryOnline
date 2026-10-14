shader_type spatial;
// Short clumpy painted grass / flower tufts (MultiMesh). Root -> tip colour gradient (uses UV.y: 0 tip, 1 root),
// per-instance colour (INSTANCE_CUSTOM-free: COLOR from MultiMesh use_colors), wind sway at the tips, root darkening
// so tufts sit in the ground. No shadows cast (set on the instance), soft tinted lighting.
render_mode cull_disabled, diffuse_lambert, specular_disabled;

uniform vec4 root_col : source_color = vec4(0.18, 0.36, 0.30, 1.0);
uniform vec4 tip_col : source_color = vec4(0.62, 0.82, 0.42, 1.0);
uniform vec4 shade_tint : source_color = vec4(0.45, 0.55, 0.75, 1.0);
uniform float use_instance_color = 1.0;
uniform float wind = 0.12;
uniform float wind_speed = 1.6;

void vertex() {
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float tip = 1.0 - UV.y;
	float ph = dot(w, vec3(0.21, 0.0, 0.17));
	VERTEX.x += sin(TIME * wind_speed + ph) * wind * tip * tip;
	VERTEX.z += cos(TIME * wind_speed * 0.7 + ph) * wind * 0.6 * tip * tip;
	NORMAL = vec3(0.0, 1.0, 0.0);
}

void fragment() {
	float tip = 1.0 - UV.y;
	vec3 tipc = mix(tip_col.rgb, COLOR.rgb, use_instance_color * step(0.001, COLOR.a));
	ALBEDO = mix(root_col.rgb, tipc, smoothstep(0.0, 0.85, tip));
	ROUGHNESS = 1.0;
}

void light() {
	if (LIGHT_IS_DIRECTIONAL) {
		float sh = smoothstep(0.3, 0.7, ATTENUATION);
		DIFFUSE_LIGHT += mix(shade_tint.rgb, vec3(1.0), sh) * LIGHT_COLOR / PI;
	} else {
		DIFFUSE_LIGHT += ATTENUATION * LIGHT_COLOR / PI * 0.7;
	}
}
