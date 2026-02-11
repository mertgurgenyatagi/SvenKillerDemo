shader_type spatial;

uniform vec4 base_color : source_color = vec4(0.34, 0.06, 0.024, 1.0);
uniform vec4 line_color : source_color = vec4(0.42, 0.1, 0.05, 1.0);
uniform float grid_size : hint_range(0.1, 5.0) = 0.5;
uniform float line_width : hint_range(0.001, 0.05) = 0.01;

void fragment() {
	// World-space grid so lines stay fixed when camera moves
	vec2 world_uv = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xz;
	vec2 grid_uv = abs(fract(world_uv / grid_size) - 0.5);
	float line = step(0.5 - line_width / grid_size, max(grid_uv.x, grid_uv.y));

	ALBEDO = mix(base_color.rgb, line_color.rgb, line);
	ROUGHNESS = 0.85;
	METALLIC = 0.0;
}
