shader_type spatial;
// RONGYAO character toon shader (Art Bible v1 section 3.1).
// 2-band diffuse with a per-material TINTED shadow (never grey), thin fresnel rim from the key light,
// optional recolour of the source albedo (gradient map by luminance or hue swap) so stock CC0 VRoid
// textures can be re-dressed into class palettes without repainting.
render_mode cull_back, depth_draw_opaque, diffuse_lambert, specular_disabled;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec4 albedo_mul : source_color = vec4(1.0);
uniform float alpha_cut = 0.5;
// recolour: 0 = none (multiply), 1 = gradient-map by luminance (dark/mid/light), 2 = hue swap of saturated pixels
uniform int recolor_mode = 0;
uniform vec4 map_dark : source_color = vec4(0.05, 0.05, 0.07, 1.0);
uniform vec4 map_mid : source_color = vec4(0.12, 0.12, 0.16, 1.0);
uniform vec4 map_light : source_color = vec4(0.35, 0.35, 0.42, 1.0);
uniform float map_contrast = 1.0;
uniform float hue_target = 0.12;      // 0..1 hue for mode 2
uniform float hue_sat_boost = 1.2;
uniform float hue_min_sat = 0.18;     // pixels below this saturation keep their colour (whites, skin, lace)
// shading
uniform vec4 shade_tint : source_color = vec4(0.62, 0.66, 0.86, 1.0);   // shadow = albedo * tint
uniform float shade_shift = 0.0;      // push the terminator (negative = more lit, used on faces)
uniform float band_soft = 0.045;
uniform vec4 rim_color : source_color = vec4(1.0, 0.89, 0.69, 1.0);
uniform float rim_width = 0.12;
uniform float rim_strength = 0.65;
uniform vec4 emission_col : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float lit_boost = 1.0;

vec3 rgb2hsv(vec3 c) {
	vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
	float d = q.x - min(q.w, q.y);
	float e = 1.0e-10;
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}
vec3 hsv2rgb(vec3 c) {
	vec3 p = abs(fract(c.xxx + vec3(1.0, 2.0 / 3.0, 1.0 / 3.0)) * 6.0 - 3.0);
	return c.z * clamp(p - 1.0, 0.0, 1.0);
}

void fragment() {
	vec4 t = texture(albedo_tex, UV);
	vec3 c = t.rgb;
	if (recolor_mode == 1) {
		float l = clamp((dot(c, vec3(0.299, 0.587, 0.114)) - 0.5) * map_contrast + 0.5, 0.0, 1.0);
		c = l < 0.5 ? mix(map_dark.rgb, map_mid.rgb, l * 2.0) : mix(map_mid.rgb, map_light.rgb, l * 2.0 - 1.0);
	} else if (recolor_mode == 2) {
		vec3 h = rgb2hsv(c);
		float k = smoothstep(hue_min_sat, hue_min_sat + 0.12, h.y);
		vec3 swapped = hsv2rgb(vec3(hue_target, clamp(h.y * hue_sat_boost, 0.0, 1.0), h.z));
		c = mix(c, swapped, k);
	}
	ALBEDO = c * albedo_mul.rgb;
	ALPHA = t.a * albedo_mul.a;
	ALPHA_SCISSOR_THRESHOLD = alpha_cut;
	EMISSION = emission_col.rgb;
}

void light() {
	float ndl = dot(NORMAL, LIGHT) + shade_shift;
	float band = smoothstep(-band_soft, band_soft, ndl);
	if (LIGHT_IS_DIRECTIONAL) {
		// attenuation carries cast shadows; snap it so shadows stay graphic
		float sh = smoothstep(0.35, 0.65, ATTENUATION);
		band *= sh;
		vec3 lit = mix(shade_tint.rgb, vec3(lit_boost), band);
		DIFFUSE_LIGHT += lit * LIGHT_COLOR / PI;
		// rim: thin fresnel band, stronger on the lit side, also catches back-light
		float fres = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
		float rim = smoothstep(1.0 - rim_width, 1.0 - rim_width + 0.04, fres);
		float side = clamp(0.35 + 0.65 * max(dot(NORMAL, LIGHT), 0.0) + 0.6 * max(dot(-VIEW, LIGHT), 0.0), 0.0, 1.0);
		SPECULAR_LIGHT += rim_color.rgb * rim * side * rim_strength * sh * LIGHT_COLOR / PI;
	} else {
		DIFFUSE_LIGHT += band * ATTENUATION * LIGHT_COLOR / PI * 0.8;
	}
}
