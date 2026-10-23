shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_disabled, specular_schlick_ggx;

uniform sampler2D wave_normal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform vec4 shallow_color : source_color = vec4(0.06, 0.24, 0.34, 0.76);
uniform vec4 deep_color : source_color = vec4(0.02, 0.08, 0.16, 0.90);
uniform float wave_speed = 0.035;
uniform float uv_scale = 0.075;

varying vec3 v_world_pos;

void vertex() {
	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	VERTEX.y += sin(TIME * 1.6 + v_world_pos.x * 0.35 + v_world_pos.z * 0.25) * 0.08;
}

void fragment() {
	vec2 uv1 = v_world_pos.xz * uv_scale + vec2(TIME * wave_speed, TIME * wave_speed * 0.65);
	vec2 uv2 = v_world_pos.xz * (uv_scale * 1.63) - vec2(TIME * wave_speed * 0.8, -TIME * wave_speed * 0.5);
	vec3 n1 = texture(wave_normal, uv1).rgb;
	vec3 n2 = texture(wave_normal, uv2).rgb;
	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	vec4 col = mix(shallow_color, deep_color, clamp(fresnel * 1.2, 0.0, 1.0));
	ALBEDO = col.rgb + vec3(0.08, 0.11, 0.15) * fresnel;
	ALPHA = col.a;
	NORMAL_MAP = normalize(mix(n1, n2, 0.5));
	NORMAL_MAP_DEPTH = 0.85;
	ROUGHNESS = 0.09;
	METALLIC = 0.15;
	SPECULAR = 0.75;
}
