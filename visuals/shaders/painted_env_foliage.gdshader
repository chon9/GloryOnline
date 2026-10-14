shader_type spatial;
// Painted leaf cards / blossom clumps for environment trees (bible 4.1 "vegetation"): alpha-cut painted atlas,
// 2-band soft lighting with a TINTED core shadow (darker at the canopy core, lighter at the edges), a warm
// back-light catch, and gentle wind sway. Double sided; normals are bent outward from the canopy centre by the
// mesh builder so the clump shades like one soft volume.
render_mode cull_disabled, diffuse_lambert, specular_disabled;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic;
uniform vec4 albedo_mul : source_color = vec4(1.0);
uniform vec4 shade_tint : source_color = vec4(0.45, 0.25, 0.55, 1.0);
uniform vec4 rim_col : source_color = vec4(1.0, 0.75, 0.55, 1.0);
uniform float rim_strength = 0.35;
uniform float alpha_cut = 0.45;
uniform float wind = 0.06;          // sway amplitude (m)
uniform float wind_speed = 1.3;
uniform vec4 emission_col : source_color = vec4(0.0, 0.0, 0.0, 1.0);

varying vec3 wpos;

void vertex() {
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float ph = dot(w, vec3(0.37, 0.11, 0.29));
	VERTEX += (inverse(mat3(MODEL_MATRIX)) * vec3(sin(TIME * wind_speed + ph), 0.0, cos(TIME * wind_speed * 0.8 + ph * 1.3))) * wind;
	wpos = w;
}

void fragment() {
	vec4 t = texture(albedo_tex, UV);
	ALBEDO = t.rgb * albedo_mul.rgb;
	ALPHA = t.a;
	ALPHA_SCISSOR_THRESHOLD = alpha_cut;
	EMISSION = emission_col.rgb;
	if (!FRONT_FACING) { NORMAL = -NORMAL; }
}

void light() {
	float ndl = dot(NORMAL, LIGHT);
	float band = smoothstep(-0.15, 0.3, ndl);
	if (LIGHT_IS_DIRECTIONAL) {
		float sh = smoothstep(0.3, 0.7, ATTENUATION);
		DIFFUSE_LIGHT += mix(shade_tint.rgb, vec3(1.0), band * sh) * LIGHT_COLOR / PI;
		// back-light catch: light coming through the canopy edge toward the viewer
		float back = pow(clamp(dot(-VIEW, LIGHT), 0.0, 1.0), 3.0) * (1.0 - abs(dot(NORMAL, VIEW)));
		SPECULAR_LIGHT += rim_col.rgb * back * rim_strength * LIGHT_COLOR / PI;
	} else {
		DIFFUSE_LIGHT += clamp(ndl * 0.5 + 0.5, 0.0, 1.0) * ATTENUATION * LIGHT_COLOR / PI;
	}
}
