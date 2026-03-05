shader_type canvas_item;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_nearest;
uniform float grain_amount : hint_range(0.0, 0.3) = 0.055;
uniform float grain_speed : hint_range(1.0, 120.0) = 24.0;

void fragment() {
	vec2 uv = SCREEN_UV;
	vec4 screen_col = texture(SCREEN_TEXTURE, uv);

	// Randomise per-frame by stepping through time in discrete steps
	float t = floor(TIME * grain_speed) * 0.017;

	// Two-pass hash for a more organic look
	vec2 seed = FRAGCOORD.xy + vec2(t, t * 1.37);
	float n = fract(sin(dot(seed, vec2(12.9898, 78.233))) * 43758.5453);
	n += fract(sin(dot(seed + vec2(31.41, 27.18), vec2(93.9898, 67.345))) * 24418.1234);
	n = (n * 0.5) - 0.5;   // centre around zero: -0.5 .. 0.5

	COLOR = vec4(screen_col.rgb + n * grain_amount, screen_col.a);
}
