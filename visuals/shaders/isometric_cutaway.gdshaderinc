// A small dithered sight window through foreground walls/canopies. Keep their
// shadows and collision: only the active gameplay camera gets this cutaway.
global uniform vec4 iso_focus;
global uniform vec3 iso_eye;

bool iso_occludes(vec3 world_pos, vec3 view_eye, vec2 pixel) {
	if (iso_focus.w < 0.01 || distance(view_eye, iso_eye) > 0.1) { return false; }
	vec3 toward_eye = normalize(iso_eye - iso_focus.xyz);
	vec3 delta = world_pos - iso_focus.xyz;
	float depth = dot(delta, toward_eye);
	float lateral = length(delta - toward_eye * depth);
	float hole = 1.0 - smoothstep(iso_focus.w * 0.65, iso_focus.w, lateral);
	float noise = fract(dot(floor(pixel), vec2(0.75487766, 0.56984029)));
	return depth > 0.5 && world_pos.y > iso_focus.y - 0.55 && noise < hole * 0.96;
}
