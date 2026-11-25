shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, unshaded;

// Open-source CC0 nidorx Porcelain MatCap + Poly Haven Studio Softbox Panorama Clearcoat!
uniform sampler2D u_matcap_porcelain : source_color, filter_linear_mipmap, repeat_disable;
uniform sampler2D u_studio_env : source_color, filter_linear_mipmap, repeat_enable;
uniform float u_clock = 0.0;
uniform float u_show_symbols = 0.0;

varying vec4 v_custom;
varying vec3 v_local_pos;
varying vec3 v_local_nrm;
varying vec3 v_world_nrm;
varying vec3 v_world_pos;

void vertex() {
	v_custom = INSTANCE_CUSTOM;
	v_local_pos = VERTEX;
	v_local_nrm = NORMAL;

	float dt = u_clock - v_custom.y;
	if (v_custom.y > 0.01 && dt >= 0.0 && dt < 0.45) {
		float amp = exp(-dt * 12.0) * sin(dt * 40.0) * 0.045;
		VERTEX.xz *= 1.0 + amp;
		VERTEX.y *= 1.0 - amp;
	}
	v_world_nrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

vec2 dir_to_equirect(vec3 d) {
	float phi = atan(d.z, d.x);
	float theta = asin(clamp(d.y, -1.0, 1.0));
	return vec2(phi / (2.0 * PI) + 0.5, 0.5 - theta / PI);
}

float symbol_mask(vec2 p, int sym_id) {
	float d = 1.0;
	if (sym_id == 0) {
		float r = length(p);
		d = min(abs(r - 0.21) - 0.036, r - 0.06);
	} else {
		vec2 q = abs(p);
		d = min(q.x + q.y * 0.42 - 0.12, q.y + q.x * 0.42 - 0.12);
		d = max(d, length(p) - 0.26);
	}
	float aa = max(fwidth(d), 0.01);
	return 1.0 - smoothstep(-aa, aa, d);
}

void fragment() {
	vec3 base = COLOR.rgb;
	vec3 an = abs(v_local_nrm);
	vec2 face_uv = (an.y > an.x && an.y > an.z) ? v_local_pos.xz : ((an.x > an.z) ? v_local_pos.zy : v_local_pos.xy);

	// Molded blind-box rounded pillow normal so flat faces catch luscious softbox glaze gradients!
	vec3 pillow_local = normalize(mix(v_local_nrm, normalize(v_local_pos + vec3(0.0001)), 0.34));
	vec3 pillow_world = normalize(mix(v_world_nrm, normalize(v_local_pos + vec3(0.0001)), 0.26));
	vec3 pillow_view = normalize((VIEW_MATRIX * vec4(pillow_world, 0.0)).xyz);

	// 1. Sample Open-Source Porcelain Studio MatCap
	vec2 mc_uv = pillow_view.xy * vec2(0.49, -0.49) + 0.5;
	vec3 mc = texture(u_matcap_porcelain, mc_uv).rgb;

	// Glaze pooling around beveled tile edges (authentic Song/Kyoto celadon glaze!)
	float edge_dist = max(abs(face_uv.x), abs(face_uv.y));
	float glaze_rim = smoothstep(0.28, 0.48, edge_dist);
	vec3 glaze_tint = mix(base, base * 0.80 + vec3(0.07, 0.08, 0.07), glaze_rim * 0.55);

	// Combine satin ceramic diffuse + white glaze highlights from MatCap
	float luma = dot(mc, vec3(0.299, 0.587, 0.114));
	float spec_pop = smoothstep(0.76, 0.99, luma);
	vec3 col = glaze_tint * (0.38 + luma * 0.82) + vec3(1.0, 0.99, 0.97) * spec_pop * 0.48;

	// 2. Real Poly Haven Studio Softbox Clearcoat Reflection (IOR 1.5 Fresnel)
	vec3 world_view = normalize(INV_VIEW_MATRIX[3].xyz - v_world_pos);
	vec3 refl_dir = reflect(-world_view, pillow_world);
	vec3 env_spec = textureLod(u_studio_env, dir_to_equirect(refl_dir), 1.2).rgb;
	float fresnel = pow(1.0 - clamp(dot(pillow_view, vec3(0.0, 0.0, 1.0)), 0.0, 1.0), 3.2);
	col += env_spec * (0.08 + 0.32 * fresnel);

	int sym_id = int(round(v_custom.x));
	float sym = symbol_mask(face_uv * 1.25, sym_id);
	col = mix(col, vec3(0.99, 0.98, 0.95), sym * 0.85 * u_show_symbols);

	// Analytical 3D Voxel Cavity Ambient Occlusion (deep rich contact crevices!)
	float ao = clamp(v_custom.w, 0.22, 1.0);
	ALBEDO = col * mix(0.42, 1.0, ao);
}
