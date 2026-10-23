shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform sampler2D grass_albedo : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D grass_normal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D grass_roughness : filter_linear_mipmap, repeat_enable;

uniform sampler2D rock_albedo : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D rock_normal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D rock_roughness : filter_linear_mipmap, repeat_enable;

uniform float uv_scale_grass = 0.085;
uniform float uv_scale_rock = 0.045;

varying vec3 v_world_pos;
varying vec3 v_world_nrm;

void vertex() {
	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_world_nrm = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}

void fragment() {
	vec2 uv_g = v_world_pos.xz * uv_scale_grass;
	vec2 uv_r = v_world_pos.xz * uv_scale_rock;

	float slope = 1.0 - clamp(v_world_nrm.y, 0.0, 1.0);
	float rock_mask = clamp(max(COLOR.r, smoothstep(0.28, 0.58, slope)), 0.0, 1.0);
	float shore_mask = clamp(COLOR.g, 0.0, 1.0);
	float ao_val = clamp(COLOR.b, 0.35, 1.0);

	vec3 g_col = texture(grass_albedo, uv_g).rgb;
	vec3 r_col = texture(rock_albedo, uv_r).rgb;
	vec3 shore_col = mix(vec3(0.26, 0.23, 0.17), vec3(0.10, 0.11, 0.10), shore_mask);

	vec3 base_col = mix(g_col, r_col, rock_mask);
	base_col = mix(base_col, shore_col, shore_mask * 0.80);

	vec3 n_grass = texture(grass_normal, uv_g).rgb;
	vec3 n_rock = texture(rock_normal, uv_r).rgb;
	float rgh_g = texture(grass_roughness, uv_g).r;
	float rgh_r = texture(rock_roughness, uv_r).r;

	ALBEDO = base_col * ao_val;
	NORMAL_MAP = normalize(mix(n_grass, n_rock, rock_mask));
	NORMAL_MAP_DEPTH = mix(0.85, 1.35, rock_mask);
	ROUGHNESS = mix(mix(rgh_g, rgh_r, rock_mask), 0.22, shore_mask * 0.7);
	SPECULAR = 0.32;
}
