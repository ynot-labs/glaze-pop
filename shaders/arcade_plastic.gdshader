shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

// Lightweight Arcade Glossy Plastic Shader (GDD 5.1: 1 Draw Call MultiMesh, 60fps Mobile/WebGL2!)
// Pure vivid instance albedo + crisp plastic specular (roughness 0.22, specular 0.65)
// + Fresnel rim lift + cool-sky / warm-white hemisphere ambient + 0.06s Hit-Flash + Micro Symbols!
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

	// Hit-Flash 0.06s + pop-expansion (1.0 -> 1.15) & micro neighbor wobble!
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

float draw_micro_symbol(vec2 p, int sym_id) {
	float d = 1.0;
	if (sym_id == 0) {
		// Cobalt Blue -> Circle ring
		d = abs(length(p) - 0.19) - 0.036;
	} else if (sym_id == 1) {
		// Coral Red -> Solid diamond
		vec2 q = abs(p);
		d = (q.x + q.y) * 0.7071 - 0.17;
	} else if (sym_id == 2) {
		// Vibrant Orange -> Triangle
		vec2 q = p + vec2(0.0, 0.04);
		float k = sqrt(3.0);
		q.x = abs(q.x) - 0.18;
		q.y = q.y + 0.18 / k;
		if (q.x + k * q.y > 0.0) q = vec2(q.x - k * q.y, -k * q.x - q.y) / 2.0;
		q.x -= clamp(q.x, -0.36, 0.0);
		d = -length(q) * sign(q.y) - 0.015;
	} else if (sym_id == 3) {
		// Emerald Green -> Plus / Cross
		vec2 q = abs(p);
		d = min(max(q.x - 0.055, q.y - 0.19), max(q.y - 0.055, q.x - 0.19));
	} else if (sym_id == 4) {
		// Sun Yellow -> 4-point star
		vec2 q = abs(p);
		d = min(q.x + q.y * 0.38 - 0.10, q.y + q.x * 0.38 - 0.10);
		d = max(d, length(p) - 0.22);
	} else {
		// Electric Purple -> Hollow square
		vec2 q = abs(p);
		float sq = max(q.x, q.y);
		d = abs(sq - 0.16) - 0.036;
	}
	float aa = max(fwidth(d), 0.012);
	return 1.0 - smoothstep(-aa, aa, d);
}

void fragment() {
	vec3 base = COLOR.rgb;
	vec3 an = abs(v_local_nrm);
	vec2 face_uv = (an.y > an.x && an.y > an.z) ? v_local_pos.xz : ((an.x > an.z) ? v_local_pos.zy : v_local_pos.xy);

	// Crisp ABS toy brick bevel shoulder sheen + subtle micro-seam between blocks
	float edge_d = max(abs(face_uv.x), abs(face_uv.y));
	float bevel_lift = smoothstep(0.35, 0.46, edge_d);
	float seam = smoothstep(0.47, 0.50, edge_d);
	vec3 col = mix(base, base * 1.14 + vec3(0.08), bevel_lift * 0.45);
	col *= (1.0 - seam * 0.18);

	// Spinner Layer glowing white chevron accent (flag z == 2.0)
	float is_spinner = step(1.5, v_custom.z) * step(v_custom.z, 2.5);
	if (is_spinner > 0.5 && an.y < 0.6) {
		float arrow_band = smoothstep(0.18, 0.12, abs(face_uv.y));
		float chev = smoothstep(0.14, 0.08, abs(abs(face_uv.y) * 1.3 - (0.14 - face_uv.x * 0.65)));
		float mark = clamp(chev * arrow_band, 0.0, 1.0);
		col = mix(col, vec3(1.0, 1.0, 1.0), mark * 0.72);
	}

	// Chain-locked subtle steel cross sheen (flag z == 3.0)
	float is_locked = step(2.5, v_custom.z);
	if (is_locked > 0.5) {
		float diag1 = smoothstep(0.085, 0.045, abs(face_uv.x - face_uv.y));
		float diag2 = smoothstep(0.085, 0.045, abs(face_uv.x + face_uv.y));
		float chain_m = clamp(max(diag1, diag2), 0.0, 1.0);
		col = mix(col, vec3(0.24, 0.29, 0.38), chain_m * 0.78);
	}

	// Colorblind optional faint geometric symbol
	int sym_id = int(round(v_custom.x));
	float sym = draw_micro_symbol(face_uv * 1.15, sym_id);
	col = mix(col, vec3(1.0), sym * 0.48 * u_show_symbols);

	// Hemisphere fake ambient (cool sky-blue top light + warm-white bottom bounce)
	float hemi_t = clamp(v_world_nrm.y * 0.5 + 0.5, 0.0, 1.0);
	vec3 hemi_light = mix(vec3(0.98, 0.94, 0.89), vec3(0.84, 0.92, 1.0), hemi_t);

	// Crisp Fresnel rim lift for clean glossy arcade toy silhouette
	float ndv = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float fresnel = pow(1.0 - ndv, 3.2);

	// Analytical 3D cavity AO (keeps stacked blocks crisp without turning muddy!)
	float ao = clamp(v_custom.w, 0.52, 1.0);
	float cavity = mix(0.62, 1.0, ao);

	// Hit-Flash pure white pop
	col = mix(col, vec3(1.0), clamp(v_flash * 0.92, 0.0, 1.0));

	ALBEDO = col;
	ROUGHNESS = 0.22;
	SPECULAR = 0.65;
	METALLIC = is_locked * 0.12;
	AO = cavity;
	AO_LIGHT_AFFECT = 0.45;

	// Subtle hemisphere bounce + Fresnel edge pop + Hit-Flash glow + Spinner glow
	vec3 emiss = col * hemi_light * 0.24 * cavity
		+ mix(base, vec3(1.0), 0.62) * fresnel * 0.22 * cavity
		+ vec3(1.0) * v_flash * 0.85
		+ vec3(0.85, 0.96, 1.0) * is_spinner * 0.08;
	EMISSION = emiss;
}
