shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

// V1.0 Production Arcade Glossy Plastic Shader (RD-SPEC-03 Section 1.2 & 2.1)
//  - Uses beveled_cube.glb (exact 92 tris, 2-seg bevel)
//  - Converts MultiMesh raw sRGB COLOR -> exact Linear space (1:1 match to 2D cannons!)
//  - Roughness 0.22, Specular 0.65, Fresnel Rim = pow(1 - N·V, 3.0) * 0.18
//  - Hit-Flash via instance_custom_data.g (0.06s white flash + 1.0 -> 1.15 pop)
//  - Exact 6 Colorblind Micro-Symbols (1:Circle, 2:Triangle, 3:Diamond, 4:Square, 5:5-Star, 6:Cross-Star)
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

	// Hit-Flash 0.06s + scale pulse 1.0 -> 1.15
	float dt = u_clock - v_custom.y;
	if (v_custom.y > 0.01 && dt >= 0.0 && dt < 0.14) {
		if (dt < 0.065) {
			float pop = sin((dt / 0.065) * PI) * 0.15;
			VERTEX *= 1.0 + pop;
			v_flash = 1.0 - (dt / 0.065);
		} else {
			float settle = exp(-(dt - 0.065) * 30.0) * sin((dt - 0.065) * 62.0) * 0.035;
			VERTEX *= 1.0 + settle;
		}
	}
	v_world_nrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

vec3 srgb_to_linear(vec3 c) {
	return mix(c / 12.92, pow((c + vec3(0.055)) / 1.055, vec3(2.4)), step(vec3(0.04045), c));
}

// Exact RD-SPEC-03 Section 1.2 Colorblind Micro-Symbols (1-based color_id 1..6!)
float draw_spec_symbol(vec2 p, int cid) {
	float d = 1.0;
	if (cid == 1) {
		// 1: Cobalt Blue -> Solid Circle (实心圆)
		d = length(p) - 0.17;
	} else if (cid == 2) {
		// 2: Coral Red -> Equilateral Triangle (正三角)
		vec2 q = p + vec2(0.0, 0.05);
		float k = sqrt(3.0);
		q.x = abs(q.x) - 0.19;
		q.y = q.y + 0.19 / k;
		if (q.x + k * q.y > 0.0) q = vec2(q.x - k * q.y, -k * q.x - q.y) / 2.0;
		q.x -= clamp(q.x, -0.38, 0.0);
		d = -length(q) * sign(q.y) - 0.012;
	} else if (cid == 3) {
		// 3: Vibrant Orange -> Diamond (菱形)
		vec2 q = abs(p);
		d = (q.x + q.y) * 0.7071 - 0.165;
	} else if (cid == 4) {
		// 4: Emerald Green -> Square (正方形)
		vec2 q = abs(p);
		d = max(q.x, q.y) - 0.155;
	} else if (cid == 5) {
		// 5: Sun Yellow -> 5-Point Star (五角星)
		float a = atan(p.y, p.x) + PI * 0.5;
		float r = length(p);
		float seg = mod(a, TAU / 5.0) - (PI / 5.0);
		float star_r = mix(0.095, 0.21, smoothstep(0.0, 1.0, cos(seg * 2.5)));
		d = r - star_r;
	} else {
		// 6: Electric Purple -> Cross Star (十字星)
		vec2 q = abs(p);
		d = min(q.x + q.y * 0.32 - 0.085, q.y + q.x * 0.32 - 0.085);
		d = max(d, length(p) - 0.22);
	}
	float aa = max(fwidth(d), 0.014);
	return 1.0 - smoothstep(-aa, aa, d);
}

void fragment() {
	vec3 base = srgb_to_linear(clamp(COLOR.rgb, 0.0, 1.0));

	// Continuous 3D bevel edge coordinate (zero discontinuities across 2-seg bevel & corners!)
	vec3 ap = abs(v_local_pos);
	float max_c = max(ap.x, max(ap.y, ap.z));
	float min_c = min(ap.x, min(ap.y, ap.z));
	float edge_c = ap.x + ap.y + ap.z - max_c - min_c;

	float bevel_sheen = smoothstep(0.34, 0.42, edge_c) * (1.0 - smoothstep(0.43, 0.48, edge_c));
	float brick_groove = smoothstep(0.44, 0.488, edge_c);
	vec3 col = base * (1.0 + bevel_sheen * 0.10) * (1.0 - brick_groove * 0.20);

	vec3 an = abs(v_local_nrm);
	vec2 face_uv = (an.y > an.x && an.y > an.z) ? v_local_pos.xz : ((an.x > an.z) ? v_local_pos.zy : v_local_pos.xy);

	// Spinner Layer subtle white directional chevron band (flag z == 2.0)
	float is_spinner = step(1.5, v_custom.z) * step(v_custom.z, 2.5);
	if (is_spinner > 0.5 && an.y < 0.65 && edge_c < 0.37) {
		float band = smoothstep(0.16, 0.10, abs(face_uv.y));
		float chev = smoothstep(0.12, 0.06, abs(abs(face_uv.y) * 1.25 - (0.14 - face_uv.x * 0.65)));
		col = mix(col, vec3(0.96, 0.98, 1.0), clamp(chev * band, 0.0, 1.0) * 0.82);
	}

	// Optional Colorblind Micro-Symbol on flat face center (subtle, never obscures specular!)
	if (u_show_symbols > 0.5 && edge_c < 0.36) {
		int cid = int(round(v_custom.x));
		float sym = draw_spec_symbol(face_uv * 1.15, cid);
		col = mix(col, vec3(0.96, 0.98, 1.0), sym * 0.55 * u_show_symbols);
	}

	float ao = clamp(v_custom.w, 0.50, 1.0);
	float cavity = mix(0.56, 1.0, ao);

	// Hit-Flash pure white pop
	col = mix(col, vec3(1.0), clamp(v_flash * 0.92, 0.0, 1.0));

	// RD-SPEC-03 Section 2.1 exact Fresnel Rim = pow(1.0 - dot(NORMAL, VIEW), 3.0) * 0.18
	float ndv = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float fresnel_rim = pow(1.0 - ndv, 3.0) * 0.18;

	ALBEDO = col;
	ROUGHNESS = 0.22;
	SPECULAR = 0.65;
	METALLIC = 0.0;
	AO = cavity;
	AO_LIGHT_AFFECT = 0.52;
	EMISSION = mix(col, vec3(1.0), 0.35) * fresnel_rim * cavity + vec3(1.0) * v_flash * 0.92;
}

void light() {
	float ndl = dot(NORMAL, LIGHT);
	float shadow_mask = clamp(ATTENUATION, 0.0, 1.0);
	float diff = clamp(ndl * 0.88 + 0.12, 0.0, 1.0) * shadow_mask;

	// Rich saturated shadow side matching Page 2 Golden Master (never muddy gray!)
	vec3 deep_shadow = ALBEDO * ALBEDO * 0.22 * (1.0 - diff);
	DIFFUSE_LIGHT += (ALBEDO * diff * 0.96 + deep_shadow) * LIGHT_COLOR / PI;

	vec3 half_vec = normalize(LIGHT + VIEW);
	float ndh = max(dot(NORMAL, half_vec), 0.0);
	float glossy_spec = pow(ndh, 44.0) * 0.36 + pow(ndh, 190.0) * 0.62;
	SPECULAR_LIGHT += LIGHT_COLOR * shadow_mask * glossy_spec * smoothstep(0.0, 0.16, ndl);
}
