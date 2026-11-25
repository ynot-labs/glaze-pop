shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

// Real Scanned CC0 Poly Haven American Walnut Veneer PBR (Albedo + GL Normal + Roughness) + Studio IBL!
uniform sampler2D u_wood_albedo : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D u_wood_normal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D u_wood_rough : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform sampler2D u_studio_env : source_color, filter_linear_mipmap, repeat_enable;
uniform float u_clock = 0.0;
uniform float u_show_symbols = 0.0;

varying vec4 v_custom;
varying vec3 v_local_pos;
varying vec3 v_local_nrm;
varying vec3 v_seed;
varying vec3 v_world_pos;
varying vec3 v_world_nrm;

void vertex() {
	v_custom = INSTANCE_CUSTOM;
	v_local_pos = VERTEX;
	v_local_nrm = NORMAL;
	v_seed = MODEL_MATRIX[3].xyz * 0.29;

	float dt = u_clock - v_custom.y;
	if (v_custom.y > 0.01 && dt >= 0.0 && dt < 0.38) {
		float knock = exp(-dt * 16.0) * sin(dt * 44.0) * 0.032;
		VERTEX.xz += vec2(knock, -knock * 0.7);
	}
	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_world_nrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

vec2 dir_to_equirect(vec3 d) {
	float phi = atan(d.z, d.x);
	float theta = asin(clamp(d.y, -1.0, 1.0));
	return vec2(phi / (2.0 * PI) + 0.5, 0.5 - theta / PI);
}

float wood_symbol(vec2 p) {
	vec2 q = abs(p);
	float d = max(max(q.x, q.y) - 0.19, -(max(q.x, q.y) - 0.115));
	d = min(d, max(abs(p.y) - 0.026, abs(p.x) - 0.16));
	float aa = max(fwidth(d), 0.01);
	return 1.0 - smoothstep(-aa, aa, d);
}

void fragment() {
	vec3 an = abs(v_local_nrm);
	vec2 face_uv = (an.y > an.x && an.y > an.z) ? v_local_pos.xz : ((an.x > an.z) ? v_local_pos.zy : v_local_pos.xy);
	// Per-block randomized UV offset on real scanned American Walnut so every block has unique organic grain!
	vec2 grain_uv = face_uv * 0.62 + v_seed.xz + vec2(v_seed.y * 0.7, -v_seed.y * 0.4);

	vec3 tex_col = texture(u_wood_albedo, grain_uv).rgb;
	float tex_rough = texture(u_wood_rough, grain_uv).r;
	NORMAL_MAP = texture(u_wood_normal, grain_uv).rgb;
	NORMAL_MAP_DEPTH = 1.15;

	// Warm beeswax oiled walnut tone + hand-sanded mortise chamfer edge highlight
	vec3 col = mix(tex_col * 1.18, COLOR.rgb * tex_col * 1.65, 0.48);
	float chamfer = smoothstep(0.36, 0.48, max(abs(face_uv.x), abs(face_uv.y)));
	col = mix(col, col * 1.24 + vec3(0.04, 0.025, 0.01), chamfer * 0.45);

	// Subtle warm studio beeswax sheen from Poly Haven HDRI
	vec3 world_view = normalize(INV_VIEW_MATRIX[3].xyz - v_world_pos);
	vec3 refl_dir = reflect(-world_view, v_world_nrm);
	vec3 env_wax = textureLod(u_studio_env, dir_to_equirect(refl_dir), 3.2).rgb;
	col += env_wax * 0.08;

	float sym = wood_symbol(face_uv * 1.25);
	col = mix(col, vec3(0.99, 0.95, 0.86), sym * 0.85 * u_show_symbols);

	float ao = clamp(v_custom.w, 0.24, 1.0);
	ALBEDO = col * mix(0.45, 1.0, ao);
	ROUGHNESS = clamp(tex_rough * 0.72, 0.26, 0.62);
	SPECULAR = 0.48;
	METALLIC = 0.0;
}
