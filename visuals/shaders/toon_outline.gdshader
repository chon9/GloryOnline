shader_type spatial;
// Inverted-hull outline with a constant SCREEN-SPACE width (bible 3.1: ~1.6 px at 1080p, thinner at distance).
// Colour = albedo * 0.3 with saturation x1.3 -> never pure black.
render_mode cull_front, unshaded, depth_draw_opaque, shadows_disabled, skip_vertex_transform;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap;
uniform vec4 albedo_mul : source_color = vec4(1.0);
uniform vec4 line_tint : source_color = vec4(1.0);
uniform float width_px = 1.6;
uniform float darken = 0.3;
uniform float alpha_cut = 0.5;
uniform float far_fade = 14.0;   // beyond this view distance the line thins (to 45%)
uniform float cull_dist = 40.0;  // LOD: beyond this the hull is culled (the line is < 1 px there anyway)

// Near-camera fade (feelfix): per-instance screen-door dither (stays opaque-sorted) so characters and their
// weapons next to the lens never block the view. Set per GeometryInstance by CharacterVisual; near_fade_end = 0
// (the default: portraits, previews) disables the distance part, fade_mul < 1 dithers the whole instance.
instance uniform float near_fade_end = 0.0;
instance uniform float fade_mul = 1.0;

void vertex() {
	vec4 vpos = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	vec3 vn = normalize(MODELVIEW_NORMAL_MATRIX * NORMAL);
	vec4 clip = PROJECTION_MATRIX * vpos;
	vec2 dir = (PROJECTION_MATRIX * vec4(vn, 0.0)).xy;
	float l = length(dir);
	dir = l > 1e-5 ? dir / l : vec2(0.0);
	float scale = VIEWPORT_SIZE.y / 1080.0;
	float dist_k = mix(1.0, 0.45, clamp((-vpos.z - 3.0) / far_fade, 0.0, 1.0));
	// LOD: the line thins to nothing over the last 4 m before cull_dist (it is < 1 px there anyway); the hull then
	// sits exactly on the surface, pushed behind it, and fails the depth test. NEVER move single vertices to a
	// fixed clip position here: a triangle straddling cull_dist would then stretch from the character to the
	// screen corner (the "long grey/teal strip from every enemy ~40 m away" bug).
	dist_k *= 1.0 - smoothstep(cull_dist - 4.0, cull_dist, -vpos.z);
	clip.xy += dir * (width_px * scale * dist_k) * 2.0 / VIEWPORT_SIZE * clip.w;
	// nudge the hull slightly back so it never draws over the surface
	clip.z -= 0.0002 * clip.w;
	POSITION = clip;
	VERTEX = vpos.xyz;
	NORMAL = vn;
}

void fragment() {
	vec4 t = texture(albedo_tex, UV) * albedo_mul;
	vec3 c = t.rgb * line_tint.rgb;
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(vec3(l), c, 1.3) * darken;
	ALBEDO = clamp(c, 0.0, 1.0);
	ALPHA = t.a;
	ALPHA_SCISSOR_THRESHOLD = alpha_cut;

	float nf = fade_mul;
	if (near_fade_end > 0.0) {
		nf *= smoothstep(near_fade_end * 0.35, near_fade_end, length(VERTEX));
	}
	if (nf < 0.999 && nf <= fract(52.9829189 * fract(dot(FRAGCOORD.xy, vec2(0.06711056, 0.00583715))))) {
		discard;
	}
}
