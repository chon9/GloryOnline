shader_type spatial;
// Painted-PBR hybrid for environments (bible 3.2): hand-painted look from world-space value noise
// (no photo textures), baked-in cavity/AO darkening, slope-driven snow cover, stratified rock bands,
// tinted soft-terminator lighting so shadows go cyan/violet instead of grey.
render_mode diffuse_lambert, specular_disabled;

uniform vec4 base_col : source_color = vec4(0.42, 0.46, 0.58, 1.0);
uniform vec4 base_col2 : source_color = vec4(0.30, 0.33, 0.45, 1.0);
uniform vec4 snow_col : source_color = vec4(0.82, 0.89, 0.96, 1.0);
uniform vec4 snow_shadow_tint : source_color = vec4(0.36, 0.62, 0.86, 1.0);
uniform vec4 shade_tint : source_color = vec4(0.36, 0.48, 0.78, 1.0);
uniform float snow_amount = 0.55;      // 0 = none, 1 = everything facing up
uniform float snow_sharp = 0.06;
uniform float strata = 0.0;            // 1 = horizontal rock layers
uniform float noise_scale = 0.35;
uniform float paint_strength = 0.22;
uniform float wrap = 0.25;
uniform float rim_amount = 0.0;
uniform vec4 rim_col : source_color = vec4(0.85, 0.95, 1.0, 1.0);
uniform vec4 emission_col : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float use_vertex_color = 0.0;
uniform float blocks = 0.0;          // > 0: ashlar stone courses (block height in metres)
uniform vec4 warm_col : source_color = vec4(0.86, 0.66, 0.50, 1.0);   // warm patches (lichen, sun-baked stone)
uniform float warm_amount = 0.0;
uniform float stroke = 0.35;         // vertical dry-brush strokes on steep faces
uniform float tiles = 0.0;           // > 0: running-bond flagstones on up-facing surfaces (tile size in metres)
uniform vec4 grout_col : source_color = vec4(0.3, 0.26, 0.24, 1.0);
uniform vec4 heat_col : source_color = vec4(0.0, 0.0, 0.0, 1.0);   // fake bounce glow near the ground (lava caves)
uniform float heat_height = 3.0;
// terrain extras: macro value/hue variation of the up-facing cover (grass / snow / sand), dry patches,
// painted cliff ledges on steep faces, and per-vertex masks (COLOR.r = worn path, COLOR.g = hollow / AO)
uniform vec4 cover_col2 : source_color = vec4(0.0, 0.0, 0.0, 0.0);   // alpha 0 = unused
uniform vec4 cover_col3 : source_color = vec4(0.0, 0.0, 0.0, 0.0);   // dry / bare patches, alpha 0 = unused
uniform float macro = 0.0;            // 0..1 large-scale value variation (breaks "one flat colour" at distance)
uniform float macro_scale = 0.025;
uniform float ledges = 0.0;           // 0..1 bright ledge lines + dark undercuts on steep strata
uniform float use_vertex_masks = 0.0;
uniform vec4 wear_col : source_color = vec4(0.55, 0.45, 0.35, 1.0);

varying vec3 wpos;
varying vec3 wnrm;
varying float snow_k;

float hash(vec3 p) { p = fract(p * vec3(0.1031, 0.1030, 0.0973)); p += dot(p, p.yxz + 33.33); return fract((p.x + p.y) * p.z); }
float vnoise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float n000 = hash(i), n100 = hash(i + vec3(1, 0, 0)), n010 = hash(i + vec3(0, 1, 0)), n110 = hash(i + vec3(1, 1, 0));
	float n001 = hash(i + vec3(0, 0, 1)), n101 = hash(i + vec3(1, 0, 1)), n011 = hash(i + vec3(0, 1, 1)), n111 = hash(i + vec3(1, 1, 1));
	return mix(mix(mix(n000, n100, f.x), mix(n010, n110, f.x), f.y), mix(mix(n001, n101, f.x), mix(n011, n111, f.x), f.y), f.z);
}
float fbm(vec3 p) {
	float s = 0.0, a = 0.5;
	for (int i = 0; i < 4; i++) { s += a * vnoise(p); p = p * 2.07 + 3.1; a *= 0.5; }
	return s;
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 p = wpos * noise_scale;
	float n = fbm(p);
	float n2 = fbm(p * 3.1 + 7.0);
	// brush-like value variation: stretched noise along the slope
	vec3 c = mix(base_col2.rgb, base_col.rgb, smoothstep(0.3, 0.7, n));
	if (use_vertex_color > 0.5 && use_vertex_masks < 0.5) { c *= COLOR.rgb; }
	if (strata > 0.0) {
		float band = sin(wpos.y * 3.2 + n * 3.0) * 0.5 + 0.5;
		c *= mix(1.0, 0.78 + 0.3 * smoothstep(0.4, 0.6, band), strata);
	}
	c *= 1.0 - paint_strength * 0.5 + paint_strength * n2;
	// warm/cool contrast: big soft patches of warm pigment over the cool base
	float wp = smoothstep(0.42, 0.62, fbm(wpos * 0.13 + vec3(11.0, 3.0, 7.0)));
	c = mix(c, c * warm_col.rgb * 1.55, warm_amount * wp);
	// dry-brush strokes: noise stretched along the slope direction, stronger on steep faces
	float steep = 1.0 - abs(wnrm.y);
	float br = vnoise(vec3((wpos.x + wpos.z) * 2.6, wpos.y * 0.35, (wpos.z - wpos.x) * 2.6));
	c *= 1.0 + stroke * steep * (smoothstep(0.35, 0.75, br) - 0.5) * 0.5;
	if (blocks > 0.0) {
		float hcoord = (wpos.x + wpos.z) * 0.7071;
		float row = floor(wpos.y / blocks);
		float fy = fract(wpos.y / blocks);
		float fx = fract(hcoord / (blocks * 2.2) + row * 0.5);
		float joint = max(smoothstep(0.06, 0.0, fy), smoothstep(0.03, 0.0, min(fx, 1.0 - fx)));
		float bid = hash(vec3(floor(hcoord / (blocks * 2.2) + row * 0.5), row, 1.0));
		c *= 0.85 + 0.25 * bid;
		c = mix(c, c * 0.45, joint);
	}
	if (tiles > 0.0 && wnrm.y > 0.6) {
		float row = floor(wpos.z / tiles);
		float tx = wpos.x / (tiles * 1.4) + mod(row, 2.0) * 0.5;
		float fz = fract(wpos.z / tiles);
		float fx = fract(tx);
		float wob = (vnoise(wpos * 1.7) - 0.5) * 0.06;
		float j = max(smoothstep(0.05, 0.0, min(fz, 1.0 - fz) + wob), smoothstep(0.035, 0.0, min(fx, 1.0 - fx) + wob));
		float tid = hash(vec3(floor(tx), row, 3.0));
		c *= 0.86 + 0.26 * tid;
		c *= 1.0 - 0.14 * clamp(1.0 - min(min(fz, 1.0 - fz), min(fx, 1.0 - fx)) * 8.0, 0.0, 1.0);
		c = mix(c, grout_col.rgb * (0.8 + 0.4 * n2), j * 0.85);
	}
	// snow cover on up-facing surfaces, noisy edge, painted crisp
	float up = wnrm.y + (n - 0.5) * 0.5;
	snow_k = smoothstep(1.0 - snow_amount - snow_sharp, 1.0 - snow_amount + snow_sharp, up) * step(0.001, snow_amount);
	vec3 snow = snow_col.rgb * (0.93 + 0.1 * n2);
	if (cover_col2.a > 0.0) {
		float hp = smoothstep(0.38, 0.62, fbm(wpos * macro_scale * 2.3 + vec3(5.0, 1.0, 9.0)));
		snow = mix(snow, cover_col2.rgb * (0.93 + 0.1 * n2), hp * cover_col2.a);
	}
	if (cover_col3.a > 0.0) {
		float dp = smoothstep(0.58, 0.72, fbm(wpos * macro_scale * 4.1 + vec3(17.0, 3.0, 2.0)) + (n2 - 0.5) * 0.25);
		snow = mix(snow, cover_col3.rgb * (0.9 + 0.2 * n), dp * cover_col3.a);
	}
	// brushy cover edge: small clumps of cover reach down the slope, rock shows through on top
	c = mix(c, snow, snow_k);
	if (ledges > 0.0) {
		float steep2 = smoothstep(0.35, 0.75, 1.0 - abs(wnrm.y));
		float lb = fract(wpos.y * 0.42 + n * 0.6);
		float ledge = smoothstep(0.9, 0.97, lb) * steep2;
		float under = smoothstep(0.0, 0.12, lb) * (1.0 - smoothstep(0.12, 0.3, lb)) * steep2;
		c = mix(c, c * 1.35 + vec3(0.04), ledge * ledges);
		c *= 1.0 - under * 0.35 * ledges;
	}
	if (macro > 0.0) {
		float m = fbm(wpos * macro_scale + vec3(31.0, 0.0, 7.0));
		c *= mix(1.0, 0.72 + 0.56 * m, macro);
	}
	if (use_vertex_masks > 0.5) {
		float w = clamp(COLOR.r, 0.0, 1.0);
		float we = smoothstep(0.25, 0.75, w + (n2 - 0.5) * 0.6);
		c = mix(c, wear_col.rgb * (0.85 + 0.3 * n), we);
		c *= 1.0 - clamp(COLOR.g, 0.0, 1.0) * 0.45;
		snow_k *= 1.0 - we;
	}
	ALBEDO = c;
	ROUGHNESS = 0.9;
	EMISSION = emission_col.rgb + heat_col.rgb * smoothstep(heat_height, -0.5, wpos.y) * (0.6 + 0.4 * n);
}

void light() {
	float ndl = dot(NORMAL, LIGHT);
	float w = clamp((ndl + wrap) / (1.0 + wrap), 0.0, 1.0);
	float band = smoothstep(0.0, 0.35, w);
	float sh = ATTENUATION;
	vec3 tint = mix(shade_tint.rgb, snow_shadow_tint.rgb, snow_k);
	if (LIGHT_IS_DIRECTIONAL) {
		vec3 l = mix(tint, vec3(1.0), band * sh);
		DIFFUSE_LIGHT += l * LIGHT_COLOR / PI;
		float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 4.0);
		SPECULAR_LIGHT += rim_col.rgb * fres * rim_amount * sh * LIGHT_COLOR / PI;
	} else {
		DIFFUSE_LIGHT += w * ATTENUATION * LIGHT_COLOR / PI;
	}
}
