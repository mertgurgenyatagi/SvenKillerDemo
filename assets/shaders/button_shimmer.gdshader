shader_type canvas_item;

uniform float shimmer_speed : hint_range(0.05, 0.5) = 0.15;
uniform float shimmer_width : hint_range(0.1, 0.5) = 0.25;
uniform float shimmer_intensity : hint_range(0.0, 0.15) = 0.06;
uniform float base_brightness : hint_range(0.9, 1.0) = 0.98;

void fragment() {
	vec2 uv = UV;
	vec4 tex_color = texture(TEXTURE, uv);

	// Traveling highlight band (diagonal for elegance)
	float diagonal = (uv.x + uv.y) * 0.5;
	float shimmer_pos = fract(TIME * shimmer_speed);

	// Smooth falloff for the shimmer band
	float dist_to_shimmer = abs(diagonal - shimmer_pos);
	// Handle wrap-around
	dist_to_shimmer = min(dist_to_shimmer, 1.0 - dist_to_shimmer);

	float shimmer = smoothstep(shimmer_width, 0.0, dist_to_shimmer);

	// Apply subtle brightness boost
	float brightness = base_brightness + (shimmer * shimmer_intensity);

	COLOR = vec4(tex_color.rgb * brightness, tex_color.a);
}
