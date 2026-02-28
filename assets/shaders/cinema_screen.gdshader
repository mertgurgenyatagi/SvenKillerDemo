shader_type spatial;
render_mode unshaded;

uniform float base_emission  : hint_range(1.0, 20.0) = 10.0;
uniform float flicker_speed  : hint_range(1.0, 60.0) = 30.0;
uniform float flicker_amount : hint_range(0.0, 0.5)  = 0.15;
uniform float edge_fade      : hint_range(0.01, 0.5) = 0.025;
uniform vec4  screen_color   : source_color           = vec4(0.90, 0.94, 1.0, 1.0);

float hash(float n) {
	return fract(sin(n) * 43758.5453123);
}

void fragment() {
	// UV is 0-1 per face on CSGBox3D — no VERTEX.xy guesswork.
	vec2 uv = UV;

	// Soft vignette: brightness falls to zero toward each edge.
	float ex = smoothstep(0.0, edge_fade, uv.x) * smoothstep(0.0, edge_fade, 1.0 - uv.x);
	float ey = smoothstep(0.0, edge_fade, uv.y) * smoothstep(0.0, edge_fade, 1.0 - uv.y);
	float vignette = ex * ey;

	// Discrete frame-like flicker.
	float flicker = 1.0 - flicker_amount * hash(floor(TIME * flicker_speed));

	// Slow-drifting film grain.
	float grain = (hash(dot(uv, vec2(127.1, 311.7)) + fract(TIME * 0.5)) - 0.5) * 0.04;

	float brightness = max(0.0, vignette * flicker + grain * vignette);

	// ALBEDO makes the screen visibly white-blue even without bloom.
	// EMISSION feeds the glow/bloom post-process.
	ALBEDO   = screen_color.rgb * brightness;
	EMISSION = screen_color.rgb * brightness * base_emission;
}
