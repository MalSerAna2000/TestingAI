shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_disabled, diffuse_burley, specular_schlick_ggx;

uniform sampler2D normal_map_a : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D normal_map_b : hint_normal, filter_linear_mipmap, repeat_enable;
uniform vec4 shallow_color : source_color = vec4(0.06, 0.20, 0.26, 0.80);
uniform vec4 deep_color : source_color = vec4(0.02, 0.07, 0.14, 0.93);
uniform float wave_speed = 0.035;
uniform float wave_height = 0.14;

varying vec3 v_world_pos;

void vertex() {
	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float w = sin(v_world_pos.x * 0.35 + TIME * 1.4) * cos(v_world_pos.z * 0.29 - TIME * 1.1);
	VERTEX.y += w * wave_height;
}

void fragment() {
	vec2 uv1 = v_world_pos.xz * 0.045 + vec2(TIME * wave_speed, TIME * wave_speed * 0.65);
	vec2 uv2 = v_world_pos.xz * 0.072 - vec2(TIME * wave_speed * 0.78, TIME * wave_speed * 0.42);
	vec3 n1 = texture(normal_map_a, uv1).rgb;
	vec3 n2 = texture(normal_map_b, uv2).rgb;
	vec3 nrm = normalize(n1 + n2 - vec3(0.0, 0.0, 0.0));

	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 4.0);
	vec4 col = mix(deep_color, shallow_color, clamp(fresnel * 1.35, 0.0, 1.0));

	ALBEDO = col.rgb;
	ALPHA = clamp(mix(col.a, 0.98, fresnel), 0.0, 1.0);
	NORMAL_MAP = nrm;
	NORMAL_MAP_DEPTH = 0.9;
	ROUGHNESS = 0.07;
	METALLIC = 0.18;
	SPECULAR = 0.85;
}
