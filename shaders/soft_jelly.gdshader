shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform float u_clock = 0.0;
uniform float u_show_symbols = 0.0;

varying vec4 v_custom;
varying vec3 v_local_pos;
varying vec3 v_local_nrm;

void vertex() {
	v_custom = INSTANCE_CUSTOM;
	v_local_pos = VERTEX;
	v_local_nrm = NORMAL;

	// Ambient gentle jelly breathing + strong elastic wobble on hit/ripple!
	float idle_breathe = sin(u_clock * 2.8 + (MODEL_MATRIX[3].x + MODEL_MATRIX[3].z) * 1.3) * 0.008;
	float bounce = idle_breathe;
	float dt = u_clock - v_custom.y;
	if (v_custom.y > 0.01 && dt >= 0.0 && dt < 0.75) {
		bounce += exp(-dt * 6.8) * sin(dt * 28.0) * 0.115;
	}
	float top_weight = clamp(VERTEX.y + 0.5, 0.0, 1.0);
	VERTEX.xz *= 1.0 + bounce * (0.4 + 0.6 * top_weight);
	VERTEX.y *= 1.0 - bounce * 1.1;
}

float jelly_symbol(vec2 p, int sym_id) {
	float d = 1.0;
	if (sym_id == 1) {
		// Twin soft wave lines (Peach Jelly)
		float w1 = abs(p.y - 0.07 - 0.038 * sin(p.x * 18.0)) - 0.026;
		float w2 = abs(p.y + 0.07 - 0.038 * sin(p.x * 18.0)) - 0.026;
		d = max(min(w1, w2), abs(p.x) - 0.21);
	} else {
		// Rounded triangle / berry badge (Berry Jelly)
		vec2 q = p;
		q.y += 0.04;
		float k = sqrt(3.0);
		q.x = abs(q.x) - 0.19;
		q.y = q.y + 0.19 / k;
		if (q.x + k * q.y > 0.0) q = vec2(q.x - k * q.y, -k * q.x - q.y) / 2.0;
		q.x -= clamp(q.x, -0.38, 0.0);
		d = -length(q) * sign(q.y) - 0.02;
	}
	float aa = max(fwidth(d), 0.008);
	return 1.0 - smoothstep(-aa, aa, d);
}

void fragment() {
	vec3 base = COLOR.rgb;
	vec3 an = abs(v_local_nrm);
	vec2 face_uv = (an.y > an.x && an.y > an.z) ? v_local_pos.xz : ((an.x > an.z) ? v_local_pos.zy : v_local_pos.xy);

	// Internal gummy core glow (thicker center = warmer saturated peach/berry core, edges = milky translucent)
	float center_mask = 1.0 - smoothstep(0.05, 0.48, length(v_local_pos));
	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.4);
	float wave_rib = 0.5 + 0.5 * cos(length(face_uv) * 26.0);

	vec3 inner_glow = mix(base * 1.06 + vec3(0.04, 0.02, 0.01), vec3(1.0, 0.86, 0.76), fresnel * 0.32);
	vec3 col = mix(base, inner_glow, 0.32 + 0.22 * center_mask) + vec3(0.015) * wave_rib;

	int sym_id = int(round(v_custom.x));
	float sym = jelly_symbol(face_uv * 1.25, sym_id);
	col = mix(col, vec3(1.0, 0.98, 0.95), sym * 0.82 * u_show_symbols);

	float ao = clamp(v_custom.w, 0.36, 1.0);
	ALBEDO = col * mix(0.60, 1.0, ao);
	// Warm subsurface internal glow matching Fig. 1 translucent gummy cubes without overexposure!
	EMISSION = base * (0.07 + 0.08 * center_mask + 0.06 * fresnel) * ao;
	ROUGHNESS = 0.14;
	SPECULAR = 0.85;
	METALLIC = 0.0;
}

void light() {
	float ndl = dot(NORMAL, LIGHT);
	float wrap = clamp((ndl + 0.48) / 1.48, 0.0, 1.0);
	float back_sss = pow(clamp(dot(-VIEW, LIGHT + NORMAL * 0.35), 0.0, 1.0), 2.8);
	DIFFUSE_LIGHT += (wrap * 0.72 + back_sss * 0.32) * ATTENUATION * LIGHT_COLOR;

	vec3 half_v = normalize(VIEW + LIGHT);
	float spec = pow(clamp(dot(NORMAL, half_v), 0.0, 1.0), 84.0);
	SPECULAR_LIGHT += spec * 0.45 * ATTENUATION * LIGHT_COLOR;
}
