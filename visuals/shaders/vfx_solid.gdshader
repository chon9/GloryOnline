shader_type spatial;
// Cel-shaded solid VFX bodies (debris shards, ice crystals, thorns, projectile casings): one hard light band
// from a fixed key direction (top-left, same on every map, like painted anime debris), a cool shade colour
// and a coloured rim; unshaded so it costs nothing per light. `fade` < 1 erodes the mesh with fine noise and a
// bright tinted edge (alpha-erosion dissolve, bible 5.3) so solid pieces never pop. Outline: vfx_outline.gdshader as next_pass.
render_mode unshaded, cull_back, shadows_disabled;

instance uniform vec4 tint : source_color, instance_index(0) = vec4(0.4, 0.38, 0.45, 1.0);
instance uniform vec4 shade : source_color, instance_index(1) = vec4(0.3, 0.28, 0.5, 1.0);
instance uniform vec4 rim_col : source_color, instance_index(2) = vec4(1.0, 0.55, 0.2, 1.0);
instance uniform float rim_strength : instance_index(3) = 1.5;
instance uniform float glow : instance_index(4) = 0.0;
instance uniform float fade : instance_index(5) = 1.0;

varying vec3 v_obj;

float hash3(vec3 p) { p = fract(p * 0.3183099 + 0.1); p *= 17.0; return fract(p.x * p.y * p.z * (p.x + p.y + p.z)); }

void vertex() {
	v_obj = VERTEX;
}

void fragment() {
	// dissolve: fine cells (the coarse ones read as corrupted pixel blocks on snow) with a glowing tinted edge
	float edge = 0.0;
	if (fade < 0.999) {
		float n = hash3(floor(v_obj * 48.0));
		if (n > fade) {
			discard;
		}
		edge = step(fade - 0.07, n);
	}
	vec3 wn = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	float nl = dot(wn, normalize(vec3(-0.45, 0.8, 0.35)));
	vec3 c = nl > 0.18 ? tint.rgb : shade.rgb;
	c = nl > 0.82 ? mix(tint.rgb, vec3(1.0), 0.35) : c;
	float fr = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	c += rim_col.rgb * step(0.62, fr) * rim_strength * 0.5;
	c = mix(c, mix(rim_col.rgb, vec3(1.0), 0.5), edge);
	ALBEDO = c * (1.0 + glow);
}
