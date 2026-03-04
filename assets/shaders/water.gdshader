shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx, blend_mix;

uniform sampler2D DEPTH_TEXTURE : hint_depth_texture, filter_linear_mipmap;
uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;

// Wave settings
uniform float wave_speed        = 0.5;
uniform vec4  wave_a            = vec4(1.0, 1.0, 0.35, 3.0);   // xy=dir, z=steepness, w=length
uniform vec4  wave_b            = vec4(1.0, 0.6, 0.30, 1.55);
uniform vec4  wave_c            = vec4(1.0, 1.3, 0.25, 0.9);

// Surface settings
uniform vec2  sampler_scale     = vec2(0.25, 0.25);
uniform vec2  sampler_direction = vec2(0.05, 0.04);

uniform sampler2D uv_sampler         : hint_anisotropy;
uniform vec2      uv_sampler_scale   = vec2(0.25, 0.25);
uniform float     uv_sampler_strength = 0.04;

uniform sampler2D normalmap_a_sampler : hint_normal;
uniform sampler2D normalmap_b_sampler : hint_normal;

uniform sampler2D foam_sampler : hint_default_black;
uniform float     foam_level   = 0.5;

// Volume settings
uniform float refraction    = 0.075;
uniform vec4  color_deep    : source_color = vec4(0.04, 0.18, 0.35, 1.0);
uniform vec4  color_shallow : source_color = vec4(0.18, 0.55, 0.62, 1.0);
uniform float beers_law     = 2.0;
uniform float depth_offset  = -0.75;

// Vertex → Fragment
varying float vertex_height;
varying vec3  vertex_normal;
varying vec3  vertex_binormal;
varying vec3  vertex_tangent;


vec4 wave(vec4 parameter, vec2 position, float time, inout vec3 tangent, inout vec3 binormal)
{
	float wave_steepness = parameter.z;
	float wave_length    = parameter.w;

	float k = 2.0 * 3.14159265359 / wave_length;
	float c = sqrt(9.8 / k);
	vec2  d = normalize(parameter.xy);
	float f = k * (dot(d, position) - c * time);
	float a = wave_steepness / k;

	tangent  += normalize(vec3(1.0 - d.x * d.x * (wave_steepness * sin(f)),
	                           d.x * (wave_steepness * cos(f)),
	                           -d.x * d.y * (wave_steepness * sin(f))));
	binormal += normalize(vec3(-d.x * d.y * (wave_steepness * sin(f)),
	                           d.y * (wave_steepness * cos(f)),
	                           1.0 - d.y * d.y * (wave_steepness * sin(f))));

	return vec4(d.x * (a * cos(f)), a * sin(f) * 0.25, d.y * (a * cos(f)), 0.0);
}


void vertex()
{
	float time           = TIME * wave_speed;
	vec4  vertex         = vec4(VERTEX, 1.0);
	vec3  vertex_position = (MODEL_MATRIX * vertex).xyz;

	vec3 tang = vec3(0.0);
	vec3 bin  = vec3(0.0);

	vertex += wave(wave_a, vertex_position.xz, time, tang, bin);
	vertex += wave(wave_b, vertex_position.xz, time, tang, bin);
	vertex += wave(wave_c, vertex_position.xz, time, tang, bin);

	vertex_tangent  = tang;
	vertex_binormal = bin;
	vertex_height   = (PROJECTION_MATRIX * MODELVIEW_MATRIX * vertex).z;

	TANGENT  = vertex_tangent;
	BINORMAL = vertex_binormal;
	vertex_normal = normalize(cross(vertex_binormal, vertex_tangent));
	NORMAL   = vertex_normal;

	UV     = vertex.xz * sampler_scale;
	VERTEX = vertex.xyz;
}


void fragment()
{
	// Animated UV
	vec2 uv_offset          = sampler_direction * TIME;
	vec2 uv_sampler_uv      = UV * uv_sampler_scale + uv_offset;
	vec2 uv_sampler_uv_off  = uv_sampler_strength * texture(uv_sampler, uv_sampler_uv).rg * 2.0 - 1.0;
	vec2 uv                 = UV + uv_sampler_uv_off;

	// Normal map blend (75% A + 25% B)
	vec3 normalmap  = texture(normalmap_a_sampler, uv - uv_offset * 2.0).rgb * 0.75;
	     normalmap += texture(normalmap_b_sampler, uv + uv_offset).rgb * 0.25;

	// Refraction UV
	vec3 ref_normalmap  = normalmap * 2.0 - 1.0;
	     ref_normalmap  = normalize(vertex_tangent  * ref_normalmap.x
	                              + vertex_binormal * ref_normalmap.y
	                              + vertex_normal   * ref_normalmap.z);
	vec2 ref_uv = SCREEN_UV + (ref_normalmap.xy * refraction) / vertex_height;

	// Ground depth — reconstruct linear view-space depth from depth buffer
	float depth_raw = texture(DEPTH_TEXTURE, ref_uv).r * 2.0 - 1.0;
	float depth     = PROJECTION_MATRIX[3][2] / (depth_raw + PROJECTION_MATRIX[2][2]);

	// Water column thickness in view space. Clamp to ≥0 so grazing angles
	// don't produce a negative value that collapses Beer's Law to transparent.
	float water_col = max(depth + VERTEX.z + depth_offset, 0.0);

	float depth_blend     = clamp(1.0 - exp(water_col * -beers_law), 0.0, 1.0);
	float depth_blend_pow = clamp(pow(depth_blend, 2.5), 0.0, 1.0);

	// Water always shows its own colour; screen only adds a subtle refraction shimmer.
	vec3 screen_color = textureLod(SCREEN_TEXTURE, ref_uv, depth_blend_pow * 2.5).rgb;
	vec3 dye_color    = mix(color_shallow.rgb, color_deep.rgb, depth_blend_pow);
	// Screen contributes at most 20 % (only when water is shallow/transparent)
	float screen_blend = (1.0 - depth_blend_pow) * 0.2;
	vec3 color = mix(dye_color, screen_color * dye_color, screen_blend);

	// Foam at shallow edges — compare both quantities in view-space.
	// water_col < 1.0 means the seafloor is very close to the surface.
	if (water_col < 1.5)
	{
		float foam_noise = clamp(pow(texture(foam_sampler, (uv * 4.0) - uv_offset).r, 10.0) * 40.0, 0.0, 0.2);
		float foam_mix   = clamp(pow((1.5 - water_col + foam_noise), 8.0) * foam_noise * 0.4, 0.0, 1.0) * foam_level;
		color = mix(color, vec3(1.0), foam_mix);
	}

	ALBEDO          = color;
	METALLIC        = 0.1;
	ROUGHNESS       = 0.2;
	SPECULAR        = 0.2 + depth_blend_pow * 0.4;
	NORMAL_MAP      = normalmap;
	NORMAL_MAP_DEPTH = 1.25;
}
