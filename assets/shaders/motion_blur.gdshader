shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear;
uniform vec2 velocity = vec2(0.0, 0.0);
uniform float intensity : hint_range(0.0, 2.0) = 0.5;

void fragment() {
	vec2 blur = velocity * intensity;

	vec4 acc = vec4(0.0, 0.0, 0.0, 0.0);
	float total = 0.0;

	for (int i = 0; i < 16; i++) {
		float t = float(i) / 15.0 - 0.5;
		float w = clamp(1.0 - abs(t) * 1.5, 0.05, 1.0);
		vec2 uv = clamp(SCREEN_UV + blur * t, vec2(0.0, 0.0), vec2(1.0, 1.0));
		acc += texture(screen_texture, uv) * w;
		total += w;
	}

	COLOR = acc / total;
}
