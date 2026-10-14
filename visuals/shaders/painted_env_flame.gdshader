shader_type spatial;
// Painted flame tongue for braziers, torches and campfires: Y-axis billboard quad (MultiMesh friendly), additive,
// flickers (scale + sway) per instance from its world position, HDR so bloom catches the core.
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

uniform sampler2D flame_tex : source_color, filter_linear_mipmap;
uniform vec4 tint : source_color = vec4(1.0, 0.8, 0.6, 1.0);
uniform float energy = 2.4;
uniform float speed = 7.0;

varying float seed;

void vertex() {
	vec3 origin = MODEL_MATRIX[3].xyz;
	seed = fract(sin(dot(origin.xz, vec2(12.9898, 78.233))) * 43758.5453);
	float t = TIME * speed + seed * 31.0;
	float flick = 0.85 + 0.15 * sin(t) * sin(t * 1.73 + 1.2);
	float sway = sin(t * 0.6 + seed * 6.0) * 0.12 * UV.y;
	vec3 right = normalize(vec3(INV_VIEW_MATRIX[0].x, 0.0, INV_VIEW_MATRIX[0].z));
	float sx = length(MODEL_MATRIX[0].xyz);
	float sy = length(MODEL_MATRIX[1].xyz);
	vec3 w = origin + right * (VERTEX.x + sway * (1.0 - UV.y)) * sx + vec3(0.0, 1.0, 0.0) * VERTEX.y * sy * flick;
	VERTEX = (inverse(MODEL_MATRIX) * vec4(w, 1.0)).xyz;
}

void fragment() {
	vec4 t = texture(flame_tex, UV);
	ALBEDO = t.rgb * tint.rgb * energy;
	ALPHA = t.a;
}
