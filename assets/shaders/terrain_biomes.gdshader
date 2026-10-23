shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

// Vertex COLOR channels encode strict non-overlapping biome weights:
// COLOR.r = Plains (Равнины), COLOR.g = Water Basin Bed (Водоемы), COLOR.b = Mountains (Горы)
uniform sampler2D grass_albedo : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D grass_normal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D grass_orm : filter_linear_mipmap, repeat_enable;

uniform sampler2D rock_albedo : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D rock_normal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D rock_orm : filter_linear_mipmap, repeat_enable;

uniform sampler2D waterbed_albedo : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D waterbed_normal : hint_normal, filter_linear_mipmap, repeat_enable;

uniform float uv_scale_plains = 0.14;
uniform float uv_scale_rock = 0.08;
uniform float uv_scale_bed = 0.18;

varying vec3 v_world_pos;
varying vec3 v_world_normal;

void vertex() {
	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 weights = max(COLOR.rgb, vec3(0.0));
	float w_sum = max(weights.r + weights.g + weights.b, 0.0001);
	weights /= w_sum;

	vec2 uv_p = v_world_pos.xz * uv_scale_plains;
	// Simple triplanar blend for steep mountain cliffs
	vec3 tri_w = abs(v_world_normal);
	tri_w = pow(tri_w, vec3(4.0));
	tri_w /= max(tri_w.x + tri_w.y + tri_w.z, 0.0001);

	vec3 r_col = texture(rock_albedo, v_world_pos.zy * uv_scale_rock).rgb * tri_w.x
		+ texture(rock_albedo, v_world_pos.xz * uv_scale_rock).rgb * tri_w.y
		+ texture(rock_albedo, v_world_pos.xy * uv_scale_rock).rgb * tri_w.z;
	vec3 r_nrm = texture(rock_normal, v_world_pos.zy * uv_scale_rock).rgb * tri_w.x
		+ texture(rock_normal, v_world_pos.xz * uv_scale_rock).rgb * tri_w.y
		+ texture(rock_normal, v_world_pos.xy * uv_scale_rock).rgb * tri_w.z;
	vec3 r_orm = texture(rock_orm, v_world_pos.xz * uv_scale_rock).rgb;

	vec3 g_col = texture(grass_albedo, uv_p).rgb;
	vec3 g_nrm = texture(grass_normal, uv_p).rgb;
	vec3 g_orm = texture(grass_orm, uv_p).rgb;

	vec2 uv_b = v_world_pos.xz * uv_scale_bed;
	vec3 b_col = texture(waterbed_albedo, uv_b).rgb;
	vec3 b_nrm = texture(waterbed_normal, uv_b).rgb;
	vec3 b_orm = vec3(0.75, 0.28, 0.02);

	ALBEDO = g_col * weights.r + b_col * weights.g + r_col * weights.b;
	NORMAL_MAP = normalize(g_nrm * weights.r + b_nrm * weights.g + r_nrm * weights.b);
	NORMAL_MAP_DEPTH = 1.15;
	vec3 orm = g_orm * weights.r + b_orm * weights.g + r_orm * weights.b;
	AO = orm.r;
	ROUGHNESS = orm.g;
	METALLIC = orm.b;
}
