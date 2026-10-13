shader_type spatial;
// Energy core / fireball: white-hot centre (facing the camera) fading to the element colour at the rim.
render_mode unshaded, blend_mix, cull_back, depth_draw_never, shadows_disabled;

uniform vec4 core : source_color = vec4(1.0, 0.98, 0.85, 1.0);
uniform vec4 mid : source_color = vec4(1.0, 0.65, 0.2, 1.0);
uniform float energy = 4.0;
uniform float alpha_mul = 1.0;
uniform vec4 rim : source_color = vec4(0.82, 0.16, 0.2, 1.0);

void fragment() {
	// cel-banded energy: rim colour -> mid -> white-hot core, hard steps like painted anime fire
	float f = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	vec3 col = rim.rgb;
	col = mix(col, mid.rgb, step(0.38, f));
	col = mix(col, core.rgb, step(0.78, f));
	ALBEDO = col;
	EMISSION = col * max(energy - 1.0, 0.0) * (0.3 + 0.7 * step(0.78, f));
	ALPHA = clamp(alpha_mul * (0.75 + 0.25 * f), 0.0, 1.0);
}
