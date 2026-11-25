shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

// Lightweight Arcade Glossy Plastic Shader (GDD 5.1 & Page 2 Rocket Visual Benchmark!)
// Fixes MultiMesh raw-sRGB instance colors via exact sRGB->Linear conversion so 3D blocks
// match the 2D arcade cannons 1:1 with rich saturated shadows & crisp glossy bevel highlights!
uniform float u_clock = 0.0;
uniform float u_show_symbols = 0.0;

varying vec4 v_custom;
varying vec3 v_local_pos;
varying vec3 v_local_nrm;
varying vec3 v_world_nrm;
varying float v_flash;

void vertex() {
	v_custom = INSTANCE_CUSTOM;
	v_local_pos = VERTEX;
	v_local_nrm = NORMAL;
	v_flash = 0.0;

	// Hit-Flash 0.06s + pop-expansion (1.0 -> 1.15)
	float dt = u_clock - v_custom.y;
	if (v_custom.y > 0.01 && dt >= 0.0 && dt < 0.16) {
		if (dt < 0.065) {
			float pop = sin((dt / 0.065) * PI) * 0.15;
			VERTEX *= 1.0 + pop;
			v_flash = 1.0 - (dt / 0.065);
		} else {
			float settle = exp(-(dt - 0.065) * 28.0) * sin((dt - 0.065) * 65.0) * 0.04;
			VERTEX *= 1.0 + settle;
		}
	}

	v_world_nrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

vec3 srgb_to_linear(vec3 c) {
	return mix(c / 12.92, pow((c + vec3(0.055)) / 1.055, vec3(2.4)), step(vec3(0.04045), c));
}

float draw_micro_symbol(vec2 p, int sym_id) {
	float d = 1.0;
	if (sym_id == 0) {
		d = abs(length(p) - 0.19) - 0.036;
	} else if (sym_id == 1) {
		vec2 q = abs(p);
		d = (q.x + q.y) * 0.7071 - 0.17;
	} else if (sym_id == 2) {
		vec2 q = p + vec2(0.0, 0.04);
		float k = sqrt(3.0);
		q.x = abs(q.x) - 0.18;
		q.y = q.y + 0.18 / k;
		if (q.x + k * q.y > 0.0) q = vec2(q.x - k * q.y, -k * q.x - q.y) / 2.0;
		q.x -= clamp(q.x, -0.36, 0.0);
		d = -length(q) * sign(q.y) - 0.015;
	} else if (sym_id == 3) {
		vec2 q = abs(p);
		d = min(max(q.x - 0.055, q.y - 0.19), max(q.y - 0.055, q.x - 0.19));
	} else if (sym_id == 4) {
		vec2 q = abs(p);
		d = min(q.x + q.y * 0.38 - 0.10, q.y + q.x * 0.38 - 0.10);
		d = max(d, length(p) - 0.22);
	} else {
		vec2 q = abs(p);
		float sq = max(q.x, q.y);
		d = abs(sq - 0.16) - 0.036;
	}
	float aa = max(fwidth(d), 0.012);
	return 1.0 - smoothstep(-aa, aa, d);
}

void fragment() {
	// CRITICAL: Convert MultiMesh raw sRGB instance color into true LINEAR space!
	vec3 base = srgb_to_linear(clamp(COLOR.rgb, 0.0, 1.0));

	// Continuous 3D edge distance (median of |x|,|y|,|z|) -> zero UV jumps across bevels & corners!
	vec3 ap = abs(v_local_pos);
	float max_c = max(ap.x, max(ap.y, ap.z));
	float min_c = min(ap.x, min(ap.y, ap.z));
	float edge_c = ap.x + ap.y + ap.z - max_c - min_c;

	// Subtle glossy toy-brick bevel highlight + crisp dark-tinted groove between stacked bricks!
	float bevel_shoulder = smoothstep(0.35, 0.42, edge_c) * (1.0 - smoothstep(0.43, 0.475, edge_c));
	float brick_groove = smoothstep(0.435, 0.485, edge_c);
	vec3 col = base * (1.0 + bevel_shoulder * 0.10) * (1.0 - brick_groove * 0.22);

	vec3 an = abs(v_local_nrm);
	vec2 face_uv = (an.y > an.x && an.y > an.z) ? v_local_pos.xz : ((an.x > an.z) ? v_local_pos.zy : v_local_pos.xy);

	// Spinner Layer glowing white chevron accent (flag z == 2.0)
	float is_spinner = step(1.5, v_custom.z) * step(v_custom.z, 2.5);
	if (is_spinner > 0.5 && an.y < 0.65 && edge_c < 0.39) {
		float arrow_band = smoothstep(0.18, 0.11, abs(face_uv.y));
		float chev = smoothstep(0.13, 0.07, abs(abs(face_uv.y) * 1.25 - (0.14 - face_uv.x * 0.65)));
		col = mix(col, vec3(0.96, 0.98, 1.0), clamp(chev * arrow_band, 0.0, 1.0) * 0.85);
	}

	// Chain-locked dark metallic cross band (flag z == 3.0)
	float is_locked = step(2.5, v_custom.z);
	if (is_locked > 0.5 && edge_c < 0.42) {
		float diag1 = smoothstep(0.08, 0.04, abs(face_uv.x - face_uv.y));
		float diag2 = smoothstep(0.08, 0.04, abs(face_uv.x + face_uv.y));
		col = mix(col, vec3(0.07, 0.09, 0.14), clamp(max(diag1, diag2), 0.0, 1.0) * 0.88);
	}

	// Optional Colorblind micro-symbol on flat face center
	if (u_show_symbols > 0.5 && edge_c < 0.38) {
		int sym_id = int(round(v_custom.x));
		float sym = draw_micro_symbol(face_uv * 1.15, sym_id);
		col = mix(col, vec3(0.95), sym * 0.65 * u_show_symbols);
	}

	// Analytical 3D cavity AO for crisp brick separation
	float ao = clamp(v_custom.w, 0.48, 1.0);
	float cavity = mix(0.54, 1.0, ao);

	// Pure white Hit-Flash on impact
	col = mix(col, vec3(1.0), clamp(v_flash * 0.90, 0.0, 1.0));

	// Subtle cool-sky top Fresnel rim so silhouette pops cleanly against #E8EEF5 sky
	float ndv = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float fresnel = pow(1.0 - ndv, 3.6);
	float top_mask = smoothstep(-0.2, 0.8, v_world_nrm.y);

	ALBEDO = col;
	ROUGHNESS = 0.22;
	SPECULAR = 0.65;
	METALLIC = is_locked * 0.20;
	AO = cavity;
	AO_LIGHT_AFFECT = 0.55;
	EMISSION = col * fresnel * (0.08 + 0.10 * top_mask) * cavity
		+ vec3(1.0) * v_flash * 0.95
		+ vec3(0.40, 0.72, 1.0) * is_spinner * 0.04;
}

void light() {
	// Crisp Arcade Glossy Plastic Shading (Page 2 Rocket Look!):
	// Vibrant true-hue lit face + rich deep saturated shadow side (zero washed-out gray/white!)
	float ndl = dot(NORMAL, LIGHT);
	float shadow_mask = clamp(ATTENUATION, 0.0, 1.0);
	float diff = clamp(ndl * 0.88 + 0.12, 0.0, 1.0) * shadow_mask;

	// Deep saturated shadow fill (keeps Cobalt Blue -> Deep Royal Blue, Coral -> Rich Crimson!)
	vec3 deep_shadow = ALBEDO * ALBEDO * 0.22 * (1.0 - diff);
	DIFFUSE_LIGHT += (ALBEDO * diff * 0.95 + deep_shadow) * LIGHT_COLOR / PI;

	// Crisp Molded-Plastic Glossy Specular Highlight on rounded bevels!
	vec3 half_vec = normalize(LIGHT + VIEW);
	float ndh = max(dot(NORMAL, half_vec), 0.0);
	float glossy_lobe = pow(ndh, 42.0) * 0.38 + pow(ndh, 190.0) * 0.65;
	SPECULAR_LIGHT += LIGHT_COLOR * shadow_mask * glossy_lobe * smoothstep(0.0, 0.18, ndl);
}
