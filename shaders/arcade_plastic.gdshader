shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

// Cube Smash High-Saturation Glossy Molded-Plastic Toy Brick Shader!
//  - Crisp vivid jewel colors (zero washed-out white haze!)
//  - Deep dark grooved seams between bricks so every cube pops razor-sharp
//  - Strong 3-face sculptural volume (bright glossy lit face -> rich deep shadow side)
//  - Sharp specular bevel catchlights + 0.06s Hit-Flash + 6 Colorblind Micro-Symbols
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

float draw_spec_symbol(vec2 p, int cid) {
	float d = 1.0;
	if (cid == 1) {
		d = length(p) - 0.17;
	} else if (cid == 2) {
		vec2 q = p + vec2(0.0, 0.05);
		float k = sqrt(3.0);
		q.x = abs(q.x) - 0.19;
		q.y = q.y + 0.19 / k;
		if (q.x + k * q.y > 0.0) q = vec2(q.x - k * q.y, -k * q.x - q.y) / 2.0;
		q.x -= clamp(q.x, -0.38, 0.0);
		d = -length(q) * sign(q.y) - 0.012;
	} else if (cid == 3) {
		vec2 q = abs(p);
		d = (q.x + q.y) * 0.7071 - 0.165;
	} else if (cid == 4) {
		vec2 q = abs(p);
		d = max(q.x, q.y) - 0.155;
	} else if (cid == 5) {
		float a = atan(p.y, p.x) + PI * 0.5;
		float r = length(p);
		float seg = mod(a, TAU / 5.0) - (PI / 5.0);
		float star_r = mix(0.095, 0.21, smoothstep(0.0, 1.0, cos(seg * 2.5)));
		d = r - star_r;
	} else {
		vec2 q = abs(p);
		d = min(q.x + q.y * 0.32 - 0.085, q.y + q.x * 0.32 - 0.085);
		d = max(d, length(p) - 0.22);
	}
	float aa = max(fwidth(d), 0.014);
	return 1.0 - smoothstep(-aa, aa, d);
}

void fragment() {
	vec3 base = srgb_to_linear(clamp(COLOR.rgb, 0.0, 1.0));
	// Boost jewel color richness (no pastel washout!)
	vec3 rich = pow(base, vec3(1.08));

	// Continuous 3D bevel edge coordinate (zero corner artifacts!)
	vec3 ap = abs(v_local_pos);
	float max_c = max(ap.x, max(ap.y, ap.z));
	float min_c = min(ap.x, min(ap.y, ap.z));
	float edge_c = ap.x + ap.y + ap.z - max_c - min_c;

	// Crisp glossy bevel shoulder + deep Cube-Smash dark brick groove!
	float bevel_sheen = smoothstep(0.32, 0.40, edge_c) * (1.0 - smoothstep(0.41, 0.46, edge_c));
	float brick_groove = smoothstep(0.425, 0.488, edge_c);
	vec3 col = rich * (1.0 + bevel_sheen * 0.16) * (1.0 - brick_groove * 0.48);

	vec3 an = abs(v_local_nrm);
	vec2 face_uv = (an.y > an.x && an.y > an.z) ? v_local_pos.xz : ((an.x > an.z) ? v_local_pos.zy : v_local_pos.xy);

	// Spinner Layer crisp glowing white arrow ring band (flag z == 2.0)
	float is_spinner = step(1.5, v_custom.z) * step(v_custom.z, 2.5);
	if (is_spinner > 0.5 && an.y < 0.65 && edge_c < 0.37) {
		float band = smoothstep(0.16, 0.10, abs(face_uv.y));
		float chev = smoothstep(0.12, 0.06, abs(abs(face_uv.y) * 1.25 - (0.14 - face_uv.x * 0.65)));
		col = mix(col, vec3(1.0, 1.0, 1.0), clamp(chev * band, 0.0, 1.0) * 0.90);
	}

	// Optional Colorblind Micro-Symbol
	if (u_show_symbols > 0.5 && edge_c < 0.36) {
		int cid = int(round(v_custom.x));
		float sym = draw_spec_symbol(face_uv * 1.15, cid);
		col = mix(col, vec3(1.0), sym * 0.62 * u_show_symbols);
	}

	// Strong cavity AO for crisp 3D depth between stacked cubes!
	float ao = clamp(v_custom.w, 0.40, 1.0);
	float cavity = mix(0.38, 1.0, ao);

	col = mix(col, vec3(1.0), clamp(v_flash * 0.92, 0.0, 1.0));

	// Subtle saturated rim glow (never bleaches to white!)
	float ndv = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float rim = pow(1.0 - ndv, 3.4) * 0.20;

	ALBEDO = col;
	ROUGHNESS = 0.18;
	SPECULAR = 0.72;
	METALLIC = 0.0;
	AO = cavity;
	AO_LIGHT_AFFECT = 0.68;
	EMISSION = rich * rim * cavity + vec3(1.0) * v_flash * 1.05;
}

void light() {
	// Strong 3-Face Cube-Smash Arcade Modeling:
	// Bright vivid lit top -> rich mid side -> deep dark-saturated underside!
	float ndl = dot(NORMAL, LIGHT);
	float shadow_mask = clamp(ATTENUATION, 0.0, 1.0);
	float lit = clamp(ndl * 0.95 + 0.08, 0.0, 1.0) * shadow_mask;

	// Deep saturated shadow color (e.g. Yellow -> rich amber-gold, Green -> deep forest, Red -> rich crimson!)
	vec3 shadow_col = ALBEDO * mix(vec3(0.24, 0.20, 0.32), ALBEDO * 0.55, 0.55);
	DIFFUSE_LIGHT += mix(shadow_col, ALBEDO * 1.12, lit) * LIGHT_COLOR / PI;

	// Razor-sharp glossy plastic bevel specular catchlight!
	vec3 half_vec = normalize(LIGHT + VIEW);
	float ndh = max(dot(NORMAL, half_vec), 0.0);
	float spec = pow(ndh, 38.0) * 0.42 + pow(ndh, 180.0) * 0.85;
	SPECULAR_LIGHT += LIGHT_COLOR * shadow_mask * spec * smoothstep(0.0, 0.14, ndl);
}
