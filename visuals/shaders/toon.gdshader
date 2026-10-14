shader_type spatial;
// RONGYAO character toon shader (Art Bible v1 section 3.1), game version of lookdev/shaders/toon.gdshader.
// 2-band diffuse with a per-material TINTED shadow (never grey), thin fresnel rim from the key light,
// optional recolour of the source albedo (gradient map by luminance or hue swap) so stock CC0 VRoid
// textures can be re-dressed into class palettes without repainting.
// Pass 2 additions:
//   special = 1 (hair): broken anisotropic specular streaks (Kajiya-Kay along the strand, stepped, broken into
//                       2-4 angular slashes per lock) - bible 2.3 / 3.1
//   special = 2 (face): clean single-tone face shadow from the HEAD axes instead of the mesh normals (an SDF-style
//                       threshold that sweeps across the face as the light turns; never blotchy) - bible 2.2 / 3.1
//   zone_ambient / zone_rim: map zone tint (CharacterVisual.set_zone_tint) - shadows and rim pick up the zone light.
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
uniform float shade_shift = 0.0;      // push the terminator (negative = more lit)
uniform float band_soft = 0.045;
uniform vec4 rim_color : source_color = vec4(1.0, 0.89, 0.69, 1.0);
uniform float rim_width = 0.12;
uniform float rim_strength = 0.65;
uniform vec4 emission_col : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float lit_boost = 1.0;
// zone tint
uniform vec4 zone_ambient : source_color = vec4(1.0, 1.0, 1.0, 1.0);   // multiplies the shadow tint
uniform vec4 zone_rim : source_color = vec4(1.0, 1.0, 1.0, 0.0);       // rgb = zone rim colour, a = how much it replaces rim_color
// special surfaces
uniform int special = 0;
uniform vec4 hair_spec_color : source_color = vec4(1.0, 0.97, 0.9, 1.0);
uniform float hair_spec_strength = 0.55;
uniform float hair_spec_shift = 0.0;
uniform vec3 head_center = vec3(0.0, 1.6, 0.0);   // world space, updated per frame by CharacterVisual
uniform vec3 head_right = vec3(1.0, 0.0, 0.0);
uniform vec3 head_fwd = vec3(0.0, 0.0, 1.0);
uniform float face_half_width = 0.075;

varying vec3 v_up;
varying float v_strand;
varying float v_crown;
varying float v_face_x;
varying vec3 v_hr;
varying vec3 v_hf;

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
float hash1(float n) {
	return fract(sin(n * 127.1) * 43758.5453);
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
	if (special == 1) {
		// strand direction ~ world up projected on the surface; each lock (by its azimuth round the head) gets its
		// own highlight offset so the band breaks into separate angular slashes
		v_up = (VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz;
		vec3 wn = (INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz;
		float az = atan(wn.x, wn.z);
		float lock = floor(az * 5.0 + UV.x * 7.0);
		v_strand = hash1(lock);
		v_crown = smoothstep(0.15, 0.55, wn.y);
	} else if (special == 2) {
		vec3 wp = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
		v_face_x = dot(wp - head_center, head_right) / face_half_width;
		v_hr = normalize((VIEW_MATRIX * vec4(head_right, 0.0)).xyz);
		v_hf = normalize((VIEW_MATRIX * vec4(head_fwd, 0.0)).xyz);
	}
}

void light() {
	float ndl = dot(NORMAL, LIGHT) + shade_shift;
	float band = smoothstep(-band_soft, band_soft, ndl);
	if (special == 2) {
		// face: the shadow edge is a vertical line across the face that sweeps with the light angle round the head
		float lx = dot(LIGHT, v_hr);
		float lz = dot(LIGHT, v_hf);
		float a = acos(clamp(lz / max(length(vec2(lx, lz)), 1e-4), -1.0, 1.0));
		float edge = 1.0 - 2.0 * a / PI;
		float sx = v_face_x * (lx >= 0.0 ? 1.0 : -1.0);
		band = smoothstep(-edge - 0.04, -edge + 0.04, sx + 0.15);
	}
	vec3 rimc = mix(rim_color.rgb, zone_rim.rgb, zone_rim.a);
	vec3 shade = shade_tint.rgb * zone_ambient.rgb;
	if (LIGHT_IS_DIRECTIONAL) {
		// attenuation carries cast shadows; snap it so shadows stay graphic (faces ignore hair shadow blotches)
		float sh = smoothstep(0.35, 0.65, ATTENUATION);
		if (special != 2) {
			band *= sh;
		}
		vec3 lit = mix(shade, vec3(lit_boost), band);
		DIFFUSE_LIGHT += lit * LIGHT_COLOR / PI;
		float fres = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
		float rim = smoothstep(1.0 - rim_width, 1.0 - rim_width + 0.04, fres);
		float side = clamp(0.35 + 0.65 * max(dot(NORMAL, LIGHT), 0.0) + 0.6 * max(dot(-VIEW, LIGHT), 0.0), 0.0, 1.0);
		SPECULAR_LIGHT += rimc * rim * side * rim_strength * sh * LIGHT_COLOR / PI;
		if (special == 1) {
			vec3 tng = normalize(v_up - NORMAL * dot(v_up, NORMAL) + vec3(1e-5));
			vec3 tsh = normalize(tng + NORMAL * (hair_spec_shift + (v_strand - 0.5) * 0.5));
			vec3 hv = normalize(LIGHT + VIEW);
			float th = dot(tsh, hv);
			float aniso = pow(sqrt(max(1.0 - th * th, 0.0)), 160.0);
			float streak = smoothstep(0.55, 0.6, aniso) * step(0.4, v_strand) * v_crown;
			vec3 sc = hair_spec_color.rgb * mix(ALBEDO, vec3(1.0), 0.55);
			SPECULAR_LIGHT += sc * streak * hair_spec_strength * band * LIGHT_COLOR / PI;
		}
	} else {
		DIFFUSE_LIGHT += band * ATTENUATION * LIGHT_COLOR / PI * 0.8;
	}
}
