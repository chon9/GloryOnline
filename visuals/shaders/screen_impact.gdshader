shader_type canvas_item;
// Impact frame (bible 5.3 / 5.4): radial speed lines converging on the hit point, element-tinted flash,
// slight chromatic split and vignette. Shown on a full-screen ColorRect for 1-2 frames on heavy hits, then
// faded out with `strength`. `invert` > 0 mixes in the anime negative flash for ultimates.
// Ported from lookdev/shaders/screen_impact.gdshader.
uniform vec2 focus = vec2(0.5, 0.5);
uniform vec4 tint : source_color = vec4(0.8, 0.9, 1.0, 1.0);
uniform float flash = 0.25;
uniform float lines = 0.6;
uniform float vignette = 0.22;
uniform float invert = 0.0;
uniform float strength = 1.0;
uniform float seed = 0.0;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear;

float hash1(float n) { return fract(sin(n * 12.9898) * 43758.5453); }

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 d = uv - focus;
	d.x *= SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	float r = length(d);
	float a = atan(d.y, d.x);
	vec2 dir = d / max(r, 1e-4);
	float ca = 0.0016 * smoothstep(0.1, 0.8, r) * strength;
	vec3 col;
	col.r = texture(screen_tex, uv + dir * ca).r;
	col.g = texture(screen_tex, uv).g;
	col.b = texture(screen_tex, uv - dir * ca).b;
	vec3 base = col;
	float id = floor((a / 6.28318 + 0.5) * 420.0 + seed * 97.0);
	float s = step(0.86, hash1(id)) * smoothstep(0.2 + hash1(id + 5.0) * 0.25, 0.95, r);
	col = mix(col, vec3(1.0), s * lines * 0.8);
	col = mix(col, tint.rgb, flash * (1.0 - smoothstep(0.0, 0.7, r) * 0.5));
	float lum = dot(base, vec3(0.299, 0.587, 0.114));
	vec3 neg = mix(vec3(1.0) - vec3(lum), tint.rgb * (1.0 - lum) * 1.4, 0.35);
	col = mix(col, neg, invert);
	col *= 1.0 - vignette * smoothstep(0.45, 1.0, r);
	COLOR = vec4(mix(base, col, strength), 1.0);
}
