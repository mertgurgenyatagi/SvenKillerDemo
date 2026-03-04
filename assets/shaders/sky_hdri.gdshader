shader_type sky;

uniform sampler2D panorama : filter_linear_mipmap;
uniform float exposure : hint_range(0.1, 8.0) = 1.0;

const float PI = 3.14159265359;

void sky() {
	vec3 dir = normalize(EYEDIR);

	// Equirectangular (longitude-latitude) mapping
	// phi  = horizontal angle [-PI, PI]
	// theta = vertical angle from zenith [0 (top) → PI (bottom)]
	float phi   = atan(dir.z, dir.x);
	float theta = acos(clamp(dir.y, -1.0, 1.0));

	vec2 uv = vec2(phi / (2.0 * PI) + 0.5, theta / PI);

	COLOR = textureLod(panorama, uv, 0.0).rgb * exposure;
}
