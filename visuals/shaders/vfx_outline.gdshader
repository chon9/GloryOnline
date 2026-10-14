shader_type spatial;
// Inverted-hull outline for convex VFX solids (shards, crystals): scales the mesh out from its origin, so it
// also works on flat-shaded meshes with split normals. Shares `fade` with vfx_solid for the dissolve.
render_mode unshaded, cull_front, shadows_disabled;

uniform vec4 line_col : source_color = vec4(0.05, 0.03, 0.08, 1.0);
uniform float width = 0.06;
instance uniform float fade : instance_index(5) = 1.0;

varying vec3 v_obj;

float hash3(vec3 p) { p = fract(p * 0.3183099 + 0.1); p *= 17.0; return fract(p.x * p.y * p.z * (p.x + p.y + p.z)); }

void vertex() {
	v_obj = VERTEX;
	VERTEX += normalize(VERTEX + vec3(1e-4)) * width;
}

void fragment() {
	if (fade < 0.999 && hash3(floor(v_obj * 22.0)) > fade) {
		discard;
	}
	ALBEDO = line_col.rgb;
}
