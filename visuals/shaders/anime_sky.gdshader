shader_type sky;
// Painted anime sky (bible 4.1 / 3.2): cyan zenith -> pale horizon haze, sun with a wide soft halo,
// big stylised cumulus with hard-edged lit tops and soft cool bottoms, thin high streak clouds.
// Original code; needs no textures (procedural value noise).

uniform vec4 zenith : source_color = vec4(0.1, 0.42, 0.8, 1.0);
uniform vec4 mid_sky : source_color = vec4(0.35, 0.7, 0.93, 1.0);
uniform vec4 horizon : source_color = vec4(0.78, 0.9, 0.97, 1.0);
uniform vec4 ground : source_color = vec4(0.62, 0.74, 0.84, 1.0);
uniform vec4 cloud_lit : source_color = vec4(1.0, 0.99, 0.96, 1.0);
uniform vec4 cloud_shade : source_color = vec4(0.62, 0.74, 0.9, 1.0);
uniform vec4 sun_tint : source_color = vec4(1.0, 0.95, 0.85, 1.0);
uniform float cloud_cover = 0.48;
uniform float cloud_scale = 1.6;
uniform float time_scale = 0.004;
// night options: stars + nebula mist, and a painted moon disc at LIGHT0 instead of the sun
uniform float star_amount = 0.0;
uniform vec4 nebula_col : source_color = vec4(0.45, 0.3, 0.85, 1.0);
uniform float moon = 0.0;
uniform float moon_size = 0.035;
uniform float sun_strength = 1.0;

float hash(vec2 p) { vec3 p3 = fract(vec3(p.xyx) * 0.1031); p3 += dot(p3, p3.yzx + 33.33); return fract((p3.x + p3.y) * p3.z); }
float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}
float fbm(vec2 p) {
	float a = 0.5;
	float s = 0.0;
	for (int i = 0; i < 6; i++) {
		s += a * vnoise(p);
		p = p * 2.03 + vec2(1.7, 9.2);
		a *= 0.5;
	}
	return s;
}

void sky() {
	vec3 d = EYEDIR;
	float h = d.y;
	vec3 col;
	if (h >= 0.0) {
		float t = pow(clamp(h, 0.0, 1.0), 0.45);
		col = mix(horizon.rgb, mid_sky.rgb, smoothstep(0.0, 0.45, t));
		col = mix(col, zenith.rgb, smoothstep(0.45, 1.0, t));
	} else {
		col = mix(horizon.rgb, ground.rgb, smoothstep(0.0, 0.25, -h));
	}
	// sun + halo
	vec3 sd = normalize(LIGHT0_DIRECTION);
	float sdot = max(dot(d, sd), 0.0);
	if (moon > 0.5) {
		float md = acos(clamp(dot(d, sd), -1.0, 1.0));
		float disc = smoothstep(moon_size, moon_size * 0.92, md);
		// painted craters: two soft darker blots inside the disc
		vec2 mp = vec2(dot(d, normalize(cross(sd, vec3(0.0, 1.0, 0.0)))), d.y - sd.y) / moon_size;
		float crater = smoothstep(0.5, 0.2, length(mp - vec2(0.25, 0.2))) * 0.12 + smoothstep(0.35, 0.1, length(mp + vec2(0.3, 0.25))) * 0.1;
		col = mix(col, sun_tint.rgb * (1.6 - crater * 4.0), disc);
		col += sun_tint.rgb * (pow(max(dot(d, sd), 0.0), 60.0) * 0.35 + pow(max(dot(d, sd), 0.0), 8.0) * 0.12);
	} else {
		col += sun_tint.rgb * sun_strength * (pow(sdot, 900.0) * 30.0 + pow(sdot, 40.0) * 0.45 + pow(sdot, 6.0) * 0.18);
	}
	if (star_amount > 0.0 && h > 0.0) {
		vec2 suv = d.xz / (h + 0.35) * 90.0;
		vec2 cell = floor(suv);
		float rnd = hash(cell);
		vec2 off = vec2(hash(cell + 3.1), hash(cell + 7.7)) - 0.5;
		float star = smoothstep(0.09, 0.0, length(fract(suv) - 0.5 - off * 0.6)) * step(0.93, rnd);
		float twinkle = 0.6 + 0.4 * sin(TIME * (1.0 + rnd * 3.0) + rnd * 40.0);
		float neb = smoothstep(0.45, 0.85, fbm(d.xz / (h + 0.4) * 1.3 + 5.0)) * smoothstep(0.0, 0.4, h);
		col += nebula_col.rgb * neb * 0.35 * star_amount;
		col += vec3(0.85, 0.92, 1.0) * star * twinkle * star_amount * smoothstep(0.05, 0.3, h) * 1.6;
	}
	// cumulus: projected on a dome, hard-edged tops
	if (h > -0.02) {
		vec2 uv = d.xz / (h + 0.18) * cloud_scale;
		uv += vec2(TIME * time_scale, TIME * time_scale * 0.4);
		float n = fbm(uv * 0.55);
		float detail = fbm(uv * 2.2 + 4.0);
		float dens = n + detail * 0.18 - (1.0 - cloud_cover);
		float body = smoothstep(0.0, 0.035, dens);                 // crisp anime silhouette
		// lighting: sample toward the sun for a lit rim + soft cool underside
		float n2 = fbm((uv + sd.xz * 0.08) * 0.55) + detail * 0.18 - (1.0 - cloud_cover);
		float lit = clamp((dens - n2) * 9.0 + 0.55, 0.0, 1.0);
		lit = smoothstep(0.35, 0.65, lit);                          // 2-band like the characters
		float under = smoothstep(0.25, -0.05, h) * 0.3;
		vec3 cc = mix(cloud_shade.rgb, cloud_lit.rgb, lit) - under * 0.15;
		cc += sun_tint.rgb * pow(sdot, 12.0) * 0.6 * smoothstep(0.0, 0.06, dens) * (1.0 - smoothstep(0.06, 0.3, dens));
		float fade = smoothstep(-0.02, 0.12, h) * (1.0 - smoothstep(0.55, 0.95, h) * 0.6);
		col = mix(col, cc, body * fade);
		// high streak clouds
		vec2 suv = d.xz / (h + 0.05) * vec2(0.25, 2.5) + vec2(TIME * 0.002, 0.0);
		float s = smoothstep(0.62, 0.8, fbm(suv * 1.5)) * smoothstep(0.1, 0.5, h) * (1.0 - body);
		col = mix(col, vec3(1.0), s * 0.35);
	}
	COLOR = col;
}
