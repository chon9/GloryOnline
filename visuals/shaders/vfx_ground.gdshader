shader_type spatial;
// Ground zones and attack telegraphs (Fx area visuals). Flat PlaneMesh, UV 0..1.
// shape: 0 circle, 1 line (start at UV.y = 1, extends to UV.y = 0), 2 ring (inner = inner radius fraction).
// telegraph = 1: warning read first (bosses rely on it): thick HDR outline with a dark inner keyline,
//   rotating rune band (circle/ring) or marching chevrons (line), moving hatch, and a fill that sweeps from the
//   centre/start to the edge/end as `progress` goes 0 -> 1 (= time until impact) with a white-hot front.
// telegraph = 0: active zone with an element pattern (style), cel-stepped, gently animated.
// style: 0 fire, 1 ice, 2 lightning, 3 holy, 4 dark, 5 poison, 6 wind, 7 earth, 8 blood, 9 rune, 10 thorn
// size: plane size in metres (patterns stay a constant world scale).
render_mode unshaded, blend_premul_alpha, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

instance uniform vec4 tint : source_color = vec4(1.0, 0.2, 0.1, 1.0);
instance uniform float progress = 1.0;
instance uniform float shape = 0.0;
instance uniform float inner = 0.55;
instance uniform float alpha = 1.0;
instance uniform float telegraph = 0.0;
instance uniform float style = 9.0;
instance uniform vec2 size = vec2(4.0, 4.0);
instance uniform float seed = 0.0;

float hash1(float n) { return fract(sin(n * 12.9898) * 43758.5453); }
float hash2(vec2 p) { vec3 p3 = fract(vec3(p.xyx) * 0.1031); p3 += dot(p3, p3.yzx + 33.33); return fract((p3.x + p3.y) * p3.z); }
vec2 hash22(vec2 p) { return vec2(hash2(p), hash2(p + 19.19)); }
float vnoise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash2(i), hash2(i + vec2(1, 0)), f.x), mix(hash2(i + vec2(0, 1)), hash2(i + vec2(1, 1)), f.x), f.y);
}
// distance to the nearest voronoi cell border
float voro_edge(vec2 x) {
	vec2 n = floor(x);
	vec2 f = fract(x);
	vec2 mg;
	vec2 mr;
	float md = 8.0;
	for (int j = -1; j <= 1; j++)
	for (int i = -1; i <= 1; i++) {
		vec2 g = vec2(float(i), float(j));
		vec2 o = hash22(n + g);
		vec2 r = g + o - f;
		float d = dot(r, r);
		if (d < md) { md = d; mr = r; mg = g; }
	}
	md = 8.0;
	for (int j = -2; j <= 2; j++)
	for (int i = -2; i <= 2; i++) {
		vec2 g = mg + vec2(float(i), float(j));
		vec2 o = hash22(n + g);
		vec2 r = g + o - f;
		if (dot(mr - r, mr - r) > 0.00001) {
			md = min(md, dot(0.5 * (mr + r), normalize(r - mr)));
		}
	}
	return md;
}
float seg(vec2 p, vec2 a, vec2 b, float w) {
	vec2 pa = p - a;
	vec2 ba = b - a;
	float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
	return step(length(pa - ba * h), w);
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	vec2 half_size = size * 0.5;
	vec2 wp = p * half_size;                 // metres from the centre
	int sh = int(shape + 0.5);
	float inside;
	float edge_m;                            // metres to the outer edge (>= 0 inside)
	float fillmask;
	float r = length(p);
	float ang = atan(p.y, p.x);
	float rad_m = half_size.x;
	if (sh == 1) {
		vec2 q = half_size - abs(wp);
		edge_m = min(q.x, q.y);
		inside = step(0.0, edge_m);
		float along = 1.0 - UV.y;
		fillmask = step(along, progress);
	} else {
		edge_m = (1.0 - r) * rad_m;
		inside = step(0.0, edge_m);
		if (sh == 2) {
			float inner_m = (r - inner) * rad_m;
			inside *= step(0.0, inner_m);
			edge_m = min(edge_m, inner_m);
			fillmask = step((r - inner) / max(1.0 - inner, 0.01), progress);
		} else {
			fillmask = step(r, progress);
		}
	}
	if (inside < 0.5) {
		discard;
	}
	vec3 tc = tint.rgb;
	vec3 hotc = mix(tc, vec3(1.0), telegraph > 0.5 ? 0.3 : 0.65);
	vec3 col = vec3(0.0);
	float a = 0.0;
	float op = 0.5;                          // opacity share (rest is additive)
	float outline_w = clamp(min(half_size.x, half_size.y) * 0.06, 0.07, 0.2);
	float outline = step(edge_m, outline_w);
	float keyline = step(outline_w, edge_m) * step(edge_m, outline_w + 0.06);
	if (telegraph > 0.5) {
		// readable warning: hot outline + dark keyline + hatch + sweeping fill with a white front
		float hatch = step(0.5, fract((wp.x + wp.y) * 1.6 - TIME * 1.2));
		float body = 0.16 + 0.1 * hatch;
		float filled = fillmask * 0.42;
		float front_d = 0.0;
		if (sh == 1) {
			front_d = abs((1.0 - UV.y) - progress) * size.y;
		} else if (sh == 2) {
			front_d = abs((r - inner) / max(1.0 - inner, 0.01) - progress) * rad_m * (1.0 - inner);
		} else {
			front_d = abs(r - progress) * rad_m;
		}
		float front = step(front_d, 0.06) * step(0.02, progress);
		float band = 0.0;
		if (sh != 1) {
			// rotating rune band just inside the outline
			float bw = 0.34;
			float bv = (edge_m - outline_w - 0.1) / bw;
			if (bv > 0.0 && bv < 1.0) {
				float cells = max(floor(6.2832 * rad_m / 0.42), 8.0);
				float ar = ang / 6.28318 + 0.5 + TIME * 0.06;
				float cid = floor(ar * cells);
				vec2 q = vec2(fract(ar * cells), bv);
				float h1 = hash1(cid);
				float h2 = hash1(cid + 7.0);
				band += seg(q, vec2(0.5, 0.15), vec2(0.5, 0.85), 0.09);
				band += seg(q, vec2(0.5, 0.25 + h1 * 0.5), vec2(0.15 + h2 * 0.25, 0.7), 0.08);
				band += seg(q, vec2(0.5, 0.8 - h2 * 0.4), vec2(0.85, 0.55), 0.08) * step(0.4, h1);
				band = clamp(band, 0.0, 1.0);
			}
		} else {
			// chevrons marching from the start toward the end
			float along_m = (1.0 - UV.y) * size.y;
			float cx = abs(wp.x) / max(half_size.x, 0.01);
			float ch = fract((along_m - cx * half_size.x * 0.6) / 1.1 - TIME * 1.4);
			band = step(ch, 0.18) * step(cx, 0.75) * step(0.2, edge_m);
		}
		col = tc * 1.4 * body + tc * 2.2 * filled + hotc * 4.0 * outline + hotc * 3.0 * front + hotc * 2.4 * band;
		a = max(max(body + filled, outline), max(front, band * 0.9));
		// dark keyline separates the warning from bright floors
		col = mix(col, vec3(0.05, 0.0, 0.0), keyline * 0.8);
		a = max(a, keyline * 0.75);
		op = mix(0.62, 0.9, keyline);
	} else {
		int st = int(style + 0.5);
		float pat = 0.0;
		float hot = 0.0;
		float t = TIME;
		vec2 rp = vec2(length(wp), atan(wp.y, wp.x));
		if (st == 0) {
			float e = voro_edge(wp * 0.9 + seed);
			hot = step(e, 0.06 + 0.03 * sin(t * 6.0 + wp.x));
			pat = 0.35 + 0.25 * step(0.5, vnoise(wp * 1.5 + t * 0.8));
		} else if (st == 1) {
			float e = voro_edge(wp * 1.3 + seed);
			hot = step(e, 0.035);
			pat = 0.4 + 0.25 * step(0.55, vnoise(wp * 2.2));
		} else if (st == 2) {
			float tt = floor(t * 12.0);
			float n1 = vnoise(vec2(rp.x * 3.0, tt));
			float arcs = step(abs(fract(rp.y / 6.2832 * 7.0 + (n1 - 0.5) * 0.4 + tt * 0.13) - 0.5), 0.02);
			hot = arcs * step(0.4, hash1(tt + floor(rp.y / 6.2832 * 7.0)));
			pat = 0.22;
		} else if (st == 3) {
			float rays = step(abs(fract(rp.y / 6.2832 * 18.0 + t * 0.15) - 0.5), 0.08);
			float rings = step(abs(fract(rp.x * 1.2 - t * 0.5) - 0.5), 0.06);
			hot = max(rays * 0.6, rings);
			pat = 0.38;
		} else if (st == 4) {
			float sp = fract(rp.y / 6.2832 * 3.0 + rp.x * 0.35 + t * 0.4);
			hot = step(abs(sp - 0.5), 0.08) * smoothstep(0.0, 1.0, rp.x);
			pat = 0.45 + 0.2 * step(0.5, sp);
		} else if (st == 5) {
			vec2 g = wp * 1.4;
			vec2 cid = floor(g);
			float h = hash2(cid + seed);
			float rr = length(fract(g) - 0.5);
			float pulse = 0.25 + 0.18 * fract(t * 0.7 + h);
			hot = step(abs(rr - pulse), 0.04) * step(0.45, h);
			pat = 0.4 + 0.2 * step(0.5, vnoise(wp * 1.2 + t * 0.3));
		} else if (st == 6) {
			float sp = fract(rp.y / 6.2832 * 4.0 - rp.x * 0.5 + t * 1.2);
			hot = step(abs(sp - 0.5), 0.05) * step(0.35, vnoise(wp * 3.0 + t));
			pat = 0.18;
		} else if (st == 7) {
			float e = voro_edge(wp * 0.8 + seed);
			hot = 0.0;
			pat = 0.55;
			col += vec3(0.0);
			a = step(e, 0.05) * 0.8;
		} else if (st == 8) {
			float n = vnoise(wp * 1.6 + seed) * 0.65 + vnoise(wp * 4.0) * 0.35;
			pat = step(0.48, n) * 0.75 + 0.15;
			hot = step(0.48, n) * step(n, 0.52);
		} else if (st == 9) {
			float rings = step(abs(fract(rp.x * 0.9 - t * 0.25) - 0.5), 0.04);
			float spokes = step(abs(fract(rp.y / 6.2832 * 12.0 - t * 0.05) - 0.5), 0.03) * step(0.3, rp.x);
			hot = max(rings, spokes * 0.7);
			pat = 0.3;
		} else {
			float br = fract(rp.y / 6.2832 * 14.0 + sin(rp.x * 2.5 + seed) * 0.15);
			hot = step(abs(br - 0.5), 0.05);
			pat = 0.35 + 0.2 * step(0.55, vnoise(wp * 2.0));
		}
		float rim = outline;
		if (st == 7) {
			// earth: dark painted cracks over a brown fill
			col = tc * 0.9 * pat + hotc * 2.0 * rim;
			col = mix(col, vec3(0.08, 0.05, 0.03), a);
			a = max(max(pat * 0.75, rim), a);
			op = 0.8;
		} else if (st == 8) {
			col = tc * 1.0 * pat + hotc * 2.0 * hot + hotc * 2.4 * rim;
			a = max(max(pat, hot), rim);
			op = 0.85;
		} else {
			col = tc * 1.25 * pat + hotc * 3.0 * hot + hotc * 2.8 * rim;
			a = max(max(pat, hot), rim);
			op = mix(0.35, 0.15, hot);
		}
	}
	a = clamp(a * alpha * tint.a, 0.0, 1.0);
	if (a < 0.003) {
		discard;
	}
	ALBEDO = col * alpha * tint.a;
	ALPHA = a * op;
}
