shader_type canvas_item;

uniform sampler2D border_texture : hint_default_white;
uniform float border_thickness : hint_range(0.0, 0.3) = 0.12;
uniform float ornate_intensity : hint_range(0.0, 2.0) = 1.0;
uniform float edge_sharpness : hint_range(1.0, 10.0) = 4.0;

void fragment() {
	vec2 uv = UV;

	// Distance from edges (0.0 at edge, 1.0 at center)
	float dist_x = min(uv.x, 1.0 - uv.x);
	float dist_y = min(uv.y, 1.0 - uv.y);
	float edge_dist = min(dist_x, dist_y);

	// Sharp falloff for border region
	float border_mask = 1.0 - smoothstep(0.0, border_thickness, edge_dist);
	border_mask = pow(border_mask, edge_sharpness);

	// Sample ornate pattern (tiled for corners)
	vec2 border_uv = vec2(uv.x * 4.0, uv.y * 4.0);
	float ornate_pattern = texture(border_texture, border_uv).r;

	// Combine: white ornate pattern on transparent
	float final_alpha = border_mask * ornate_pattern * ornate_intensity;
	COLOR = vec4(1.0, 1.0, 1.0, final_alpha);
}
