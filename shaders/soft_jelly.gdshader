shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_back, unshaded;

// True Frosted Screen-Space Transmission + CC0 Translucent Wax/Gummy MatCap + Studio Wet Coat!
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear_mipmap;
uniform sampler2D u_matcap_jelly : source_color, filter_linear_mipmap, repeat_disable;
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

	float idle_breathe = sin(u_clock * 3.0 + (MODEL_MATRIX[3].x + MODEL_MATRIX[3].z) * 1.7) * 0.010;
	float bounce = idle_breathe;
	float dt = u_clock - v_custom.y;
	if (v_custom.y > 0.01 && dt >= 0.0 && dt < 0.75) {
		bounce += exp(-dt * 6.5) * sin(dt * 30.0) * 0.12;
	}
	float top_w = clamp(VERTEX.y + 0.5, 0.0, 1.0);
	VERTEX.xz *= 1.0 + bounce * (0.4 + 0.6 * top_w);
	VERTEX.y *= 1.0 - bounce * 1.05;

	v_world_nrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

vec2 dir_to_equirect(vec3 d) {
	float phi = atan(d.z, d.x);
	float theta = asin(clamp(d.y, -1.0, 1.0));
	return vec2(phi / (2.0 * PI) + 0.5, 0.5 - theta / PI);
}

float jelly_symbol(vec2 p, int sym_id) {
	float d = 1.0;
	if (sym_id == 1) {
		float w1 = abs(p.y - 0.07 - 0.038 * sin(p.x * 18.0)) - 0.028;
		float w2 = abs(p.y + 0.07 - 0.038 * sin(p.x * 18.0)) - 0.028;
		d = max(min(w1, w2), abs(p.x) - 0.22);
	} else {
		vec2 q = p;
		q.y += 0.04;
		float k = sqrt(3.0);
		q.x = abs(q.x) - 0.19;
		q.y = q.y + 0.19 / k;
		if (q.x + k * q.y > 0.0) q = vec2(q.x - k * q.y, -k * q.x - q.y) / 2.0;
		q.x -= clamp(q.x, -0.38, 0.0);
		d = -length(q) * sign(q.y) - 0.02;
	}
	float aa = max(fwidth(d), 0.01);
	return 1.0 - smoothstep(-aa, aa, d);
}

void fragment() {
	vec3 base = COLOR.rgb;
	vec3 an = abs(v_local_nrm);
	vec2 face_uv = (an.y > an.x && an.y > an.z) ? v_local_pos.xz : ((an.x > an.z) ? v_local_pos.zy : v_local_pos.xy);

	// Plump gummy cushion normal
	vec3 dome_world = normalize(mix(v_world_nrm, normalize(v_local_pos + vec3(0.0001)), 0.44));
	vec3 dome_view = normalize((VIEW_MATRIX * vec4(dome_world, 0.0)).xyz);

	// 1. REAL Blurred Screen-Space Frosted Transmission (see blurry blocks & golden core behind jelly!)
	vec2 refract_uv = clamp(SCREEN_UV - dome_view.xy * 0.038, vec2(0.005), vec2(0.995));
	vec3 bg_blur = textureLod(screen_texture, refract_uv, 2.6).rgb;

	// Beer-Lambert gummy thickness absorption (center is rich fruit syrup, rim is translucent milky glow!)
	float radial = length(v_local_pos);
	float thickness = clamp(1.15 - radial * 1.35, 0.25, 1.0);
	vec3 syrup_color = mix(base * 1.16 + vec3(0.08, 0.03, 0.02), base * base * 0.85, thickness * 0.65);
	vec3 transmitted = bg_blur * mix(vec3(1.0), base * 1.22 + vec3(0.12, 0.06, 0.04), 0.72);

	// 2. Translucent Subsurface Wax/Jelly MatCap + Wet Studio Softbox Highlight
	vec2 mc_uv = dome_view.xy * vec2(0.49, -0.49) + 0.5;
	vec3 mc = texture(u_matcap_jelly, mc_uv).rgb;
	float mc_luma = dot(mc, vec3(0.333));
	float wet_spec = smoothstep(0.82, 0.995, mc_luma);

	vec3 world_view = normalize(INV_VIEW_MATRIX[3].xyz - v_world_pos);
	vec3 refl_dir = reflect(-world_view, dome_world);
	vec3 studio_refl = textureLod(u_studio_env, dir_to_equirect(refl_dir), 0.5).rgb;
	float fresnel = pow(1.0 - clamp(dome_view.z, 0.0, 1.0), 2.4);

	vec3 gummy_body = mix(transmitted, syrup_color * (0.48 + mc_luma * 0.72), 0.62);
	vec3 col = gummy_body + vec3(1.0, 0.97, 0.93) * wet_spec * 0.55 + studio_refl * (0.10 + 0.36 * fresnel);

	int sym_id = int(round(v_custom.x));
	float sym = jelly_symbol(face_uv * 1.25, sym_id);
	col = mix(col, vec3(1.0, 0.98, 0.95), sym * 0.85 * u_show_symbols);

	float ao = clamp(v_custom.w, 0.35, 1.0);
	ALBEDO = col * mix(0.58, 1.0, ao);
}
