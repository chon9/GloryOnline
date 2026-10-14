shader_type spatial;
// Procedural anime VFX sprite (bible 5.1): one shader, many cel-banded shapes, no textures.
// Used by single billboards (Fx flashes: per-instance colours/fade/progress via instance uniforms) and by
// CPUParticles3D emitters (per-emitter palette via instance uniforms, per-particle alpha from COLOR.a and
// life phase from INSTANCE_CUSTOM.y). Premultiplied alpha: `glow` kinds are mostly additive (bloom carries
// them), puffs/debris are opaque cel paint, so effects read on bright snow and dark caves alike.
// kind: 0 spark star, 1 glow orb, 2 streak, 3 puff (painted cloud), 4 flame tongue, 5 crystal shard,
//       6 plus, 7 bubble, 8 mote, 9 thin ring, 10 hex ward, 11 leaf/petal, 12 rock chip (flat painted)
// bb:   0 camera-facing, 1 camera-facing around the node's Y axis (streaks along velocity), 2 none (flat mesh)
render_mode unshaded, blend_premul_alpha, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform int kind = 0;
uniform int bb = 0;
uniform bool particles = false;
instance uniform vec4 core : source_color = vec4(1.0);
instance uniform vec4 mid : source_color = vec4(0.81, 0.9, 1.0, 1.0);
instance uniform vec4 accent : source_color = vec4(0.44, 0.66, 1.0, 1.0);
instance uniform float energy = 2.5;
instance uniform float fade = 1.0;
instance uniform float progress = 0.0;
instance uniform float seed = 0.0;

varying float v_prog;
varying float v_seed;
varying float v_ang;

float hash1(float n) { return fract(sin(n * 12.9898) * 43758.5453); }
float hash2(vec2 p) { vec3 p3 = fract(vec3(p.xyx) * 0.1031); p3 += dot(p3, p3.yzx + 33.33); return fract((p3.x + p3.y) * p3.z); }
float vnoise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash2(i), hash2(i + vec2(1, 0)), f.x), mix(hash2(i + vec2(0, 1)), hash2(i + vec2(1, 1)), f.x), f.y);
}

void vertex() {
	v_prog = particles ? INSTANCE_CUSTOM.y : progress;
	v_seed = particles ? float(INSTANCE_ID) * 0.6180339 + INSTANCE_CUSTOM.z : seed;
	float ang = particles ? INSTANCE_CUSTOM.x : 0.0;
	v_ang = ang;
	vec3 sc = vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz), length(MODEL_MATRIX[2].xyz));
	if (bb == 0) {
		mat4 mw = mat4(normalize(INV_VIEW_MATRIX[0]), normalize(INV_VIEW_MATRIX[1]), normalize(INV_VIEW_MATRIX[2]), MODEL_MATRIX[3]);
		mw = mw * mat4(vec4(cos(ang), -sin(ang), 0.0, 0.0), vec4(sin(ang), cos(ang), 0.0, 0.0), vec4(0.0, 0.0, 1.0, 0.0), vec4(0.0, 0.0, 0.0, 1.0));
		MODELVIEW_MATRIX = VIEW_MATRIX * mw * mat4(vec4(sc.x, 0.0, 0.0, 0.0), vec4(0.0, sc.y, 0.0, 0.0), vec4(0.0, 0.0, sc.z, 0.0), vec4(0.0, 0.0, 0.0, 1.0));
		MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
	} else if (bb == 1) {
		vec3 y = MODEL_MATRIX[1].xyz / max(sc.y, 1e-5);
		vec3 to_cam = normalize(INV_VIEW_MATRIX[3].xyz - MODEL_MATRIX[3].xyz);
		vec3 x = cross(y, to_cam);
		x = length(x) > 1e-4 ? normalize(x) : normalize(INV_VIEW_MATRIX[0].xyz);
		vec3 z = cross(x, y);
		mat4 mw = mat4(vec4(x * sc.x, 0.0), vec4(y * sc.y, 0.0), vec4(z * sc.z, 0.0), MODEL_MATRIX[3]);
		MODELVIEW_MATRIX = VIEW_MATRIX * mw;
		MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
	}
}

// returns vec3(mask, band 0 edge..1 hot core, additivity 0 opaque..1 additive)
vec3 shape(vec2 p, float pr, float sd, float ang) {
	float r = length(p);
	if (kind == 0) {
		// 4-point anime star: astroid body, thin long rays, white-hot centre
		vec2 q = abs(p);
		float s = sqrt(q.x) + sqrt(q.y);
		float star = step(s, 1.0);
		float ray = step(q.x, 0.035 * (1.0 - q.y)) + step(q.y, 0.035 * (1.0 - q.x));
		float m = clamp(star + ray, 0.0, 1.0) * step(r, 1.0);
		return vec3(m, clamp(1.0 - s, 0.0, 1.0) * 1.6 + step(r, 0.12), 0.85);
	} else if (kind == 1) {
		float m = step(r, 1.0);
		float halo = exp(-r * r * 5.0);
		return vec3(m * mix(halo * 0.3, 1.0, step(r, 0.42)), 1.0 - r * 1.1, 0.9);
	} else if (kind == 2) {
		// tapered streak: razor tips, fat middle slightly toward the head (+y)
		float w = (1.0 - abs(p.y)) * (0.75 + 0.25 * p.y);
		float m = step(abs(p.x), w) * step(abs(p.y), 1.0);
		return vec3(m, 1.0 - abs(p.x) / max(w, 1e-3), 0.8);
	} else if (kind == 3) {
		// painted puffy cloud: soft union of 4 sphere lumps read as ONE volume (normal from the blended
		// height field), cel lit from the screen top-left, alpha-erosion dissolve over life
		// wobbly painted silhouette instead of perfect circles
		p += (vec2(vnoise(p * 3.0 + sd * 3.1), vnoise(p * 3.0 - sd * 2.3)) - 0.5) * 0.22;
		float hsum = 0.0;
		vec2 grad = vec2(0.0);
		float wsum = 0.0;
		for (int i = 0; i < 4; i++) {
			float a = hash1(sd * 7.1 + float(i) * 3.7) * 6.2832;
			float d = i == 0 ? 0.0 : 0.3 + 0.12 * hash1(sd + float(i));
			float rr = i == 0 ? 0.6 : 0.36 + 0.12 * hash1(sd * 3.0 + float(i));
			vec2 c = vec2(cos(a), sin(a) * 0.75 + 0.12) * d;
			vec2 q = p - c;
			float h2 = rr * rr - dot(q, q);
			if (h2 > 0.0) {
				float h = sqrt(h2);
				float w = exp(h * 4.5);
				hsum += w * h;
				grad += w * (-q / max(h, 0.03));
				wsum += w;
			}
		}
		if (wsum <= 0.0) {
			return vec3(0.0);
		}
		float h = hsum / wsum;
		grad /= wsum;
		vec3 n = normalize(vec3(-grad * 0.8, 1.0));
		float er = smoothstep(0.35, 1.0, pr);
		float nz = vnoise(p * 4.0 + sd * 13.0) * 0.6 + vnoise(p * 9.0 - sd * 5.0) * 0.4;
		float m = step(er, nz * 0.9 + h * 0.6);
		vec2 l2 = vec2(-0.55, 0.65);
		l2 = vec2(l2.x * cos(ang) + l2.y * sin(ang), -l2.x * sin(ang) + l2.y * cos(ang));
		float lit = dot(n, normalize(vec3(l2, 0.6)));
		float band = lit > 0.74 ? 0.9 : (lit > 0.28 ? 0.5 : 0.1);
		return vec3(m, band, 0.0);
	} else if (kind == 4) {
		// flame tongue: teardrop pointing up, flickering, hottest at the base, burns away from the bottom
		float y = p.y;
		float wig = sin(y * 5.0 + TIME * 13.0 + sd * 6.0) * 0.08 * (y + 1.0);
		float w = 0.62 * pow(clamp((1.0 - y) * 0.5, 0.0, 1.0), 0.7) * smoothstep(-1.0, -0.55, y);
		float x = p.x - wig;
		float m = step(abs(x), w) * step(-1.0, y);
		m *= step(pr * 1.6 - 0.6, (1.0 - y) * 0.5 + vnoise(p * 5.0 + vec2(0.0, -TIME * 4.0)) * 0.3);
		float b = (1.0 - abs(x) / max(w, 1e-3)) * (1.1 - (y + 1.0) * 0.35);
		return vec3(m, b, 0.45);
	} else if (kind == 5) {
		// crystal shard: long diamond, lit facet / shaded facet, white edge glint
		vec2 q = vec2(p.x * 2.4, p.y);
		float d = abs(q.x) + abs(q.y);
		float m = step(d, 1.0);
		float b = p.x < 0.0 ? 0.85 : 0.35;
		b = d > 0.86 ? 1.0 : b;
		return vec3(m, b, 0.25);
	} else if (kind == 6) {
		vec2 q = abs(p);
		float m = max(step(q.x, 0.24) * step(q.y, 0.85), step(q.y, 0.24) * step(q.x, 0.85));
		float b = 1.0 - max(min(q.x, q.y) / 0.24, 0.0) * 0.6;
		return vec3(m, b, 0.55);
	} else if (kind == 7) {
		float ring = step(0.7, r) * step(r, 0.92);
		float hl = step(length(p - vec2(-0.32, 0.34)), 0.16);
		float body = step(r, 0.7) * 0.25;
		return vec3(max(max(ring, hl), body), hl > 0.5 ? 1.0 : (ring > 0.5 ? 0.5 : 0.2), 0.5);
	} else if (kind == 8) {
		vec2 q = abs(p);
		float s = pow(q.x, 0.4) + pow(q.y, 0.4);
		float m = clamp(step(s, 1.0) + exp(-r * r * 10.0) * 0.6, 0.0, 1.0);
		return vec3(m, clamp(1.2 - s, 0.0, 1.0), 0.9);
	} else if (kind == 9) {
		float ring = step(0.82, r) * step(r, 1.0);
		return vec3(ring, step(0.93, r) * 0.6 + 0.4, 0.8);
	} else if (kind == 10) {
		// hexagonal ward plate: bright frame, faint cells
		vec2 q = abs(p);
		float hx = max(q.x * 0.866 + q.y * 0.5, q.y);
		float frame = step(0.78, hx) * step(hx, 0.95);
		vec2 g = p * 3.0;
		vec2 gq = abs(fract(g + vec2(0.5 * floor(g.y), 0.0)) - 0.5);
		float cells = step(0.44, max(gq.x, gq.y)) * step(hx, 0.78) * 0.5;
		float fill = step(hx, 0.78) * 0.18;
		return vec3(max(max(frame, cells), fill), frame > 0.5 ? 1.0 : 0.45, 0.8);
	} else if (kind == 11) {
		// leaf / petal: pointed ellipse with a centre vein
		vec2 q = vec2(p.x * 1.9, p.y);
		float d = length(q) + abs(p.y) * 0.15;
		float m = step(d, 0.95) * step(abs(q.x), 1.0 - abs(p.y));
		float b = abs(p.x) < 0.05 ? 0.2 : (p.x < 0.0 ? 0.8 : 0.45);
		return vec3(m, b, 0.0);
	} else {
		// painted rock chip: irregular polygon, two facets
		float a = atan(p.y, p.x);
		float rr = 0.7 + 0.25 * sin(a * 3.0 + sd * 9.0) * 0.6 + 0.15 * hash1(floor((a + 3.1416) * 1.3) + sd);
		float m = step(r, rr);
		float b = (p.x + p.y) < 0.1 * sin(sd * 5.0) ? 0.85 : 0.4;
		b = r > rr - 0.1 ? 0.0 : b;
		return vec3(m, b, 0.0);
	}
}

void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	p.y = -p.y;
	vec3 s = shape(p, v_prog, v_seed, v_ang);
	float b = s.y;
	vec3 c = accent.rgb;
	c = mix(c, mid.rgb * max(energy * 0.4, 1.0), step(0.38, b));
	c = mix(c, core.rgb * energy, step(0.74, b));
	c *= COLOR.rgb;
	float a = s.x * fade * COLOR.a;
	if (a < 0.003) {
		discard;
	}
	ALBEDO = c * a;
	ALPHA = a * (1.0 - s.z);
}
