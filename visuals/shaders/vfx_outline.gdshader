shader_type spatial;
// Inverted-hull outline for convex VFX solids (shards, crystals): scales the mesh out from its origin, so it
// also works on flat-shaded meshes with split normals. Shares `fade` with vfx_solid: hidden once the dissolve starts.
render_mode unshaded, cull_front, shadows_disabled;

uniform vec4 line_col : source_color = vec4(0.05, 0.03, 0.08, 1.0);
uniform float width = 0.06;
instance uniform float fade : instance_index(5) = 1.0;

void vertex() {
	VERTEX += normalize(VERTEX + vec3(1e-4)) * width;
}

void fragment() {
	// the dark back hull would show through the solid's dissolve holes as black blocks: drop the outline as soon
	// as the dissolve starts (the bright dissolve edge of vfx_solid carries the silhouette from there)
	if (fade < 0.97) {
		discard;
	}
	ALBEDO = line_col.rgb;
}
