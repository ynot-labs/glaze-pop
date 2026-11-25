shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_back, unshaded;

// True Chromatic Dispersion Screen Refraction + CC0 Glacier Crystal MatCap + Sharp Studio Prisms!
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear_mipmap;
uniform sampler2D u_matcap_crystal : source_color, filter_linear_mipmap, repeat_disable;
uniform sampler2D u_studio_env : source_color, filter_linear_mipmap, repeat_enable;
uniform float u_clock = 0.0;
uniform float u_show_symbols = 0.0;

varying vec4 v_custom;
varying vec3 v_local_pos;
varying vec3 v_local_nrm;
varying vec3 v_world_pos;

void vertex() {
	v_custom = INSTANCE_CUSTOM;
	v_local_pos = VERTEX;
	v_local_nrm = NORMAL;

	float dt = u_clock - v_custom.y;
	if (v_custom.y > 0.01 && dt >= 0.0 && dt < 0.40) {
		VERTEX += NORMAL * (exp(-dt * 15.0) * sin(dt * 50.0) * 0.03);
	}
	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

vec2 dir_to_equirect(vec3 d) {
	float phi = atan(d.z, d.x);
	float theta = asin(clamp(d.y, -1.0, 1.0));
	return vec2(phi / (2.0 * PI) + 0.5, 0.5 - theta / PI);
}

float diamond_symbol(vec2 p) {
	vec2 q = abs(p);
	float d = max((q.x + q.y) * 0.7071 - 0.16, -((q.x + q.y) * 0.7071 - 0.085));
	float aa = max(fwidth(d), 0.01);
	return 1.0 - smoothstep(-aa, aa, d);
}

void fragment() {
	vec3 base = COLOR.rgb;
	// Razor-sharp diamond cut flat-shaded view normal + internal facet bevel!
	vec3 flat_view_n = normalize(cross(dFdx(VERTEX), dFdy(VERTEX)));
	vec3 an = abs(v_local_nrm);
	vec2 face_uv = (an.y > an.x && an.y > an.z) ? v_local_pos.xz : ((an.x > an.z) ? v_local_pos.zy : v_local_pos.xy);

	// Internal diamond facet cleavage planes inside the crystal cube
	vec2 oct_uv = face_uv * 2.0;
	vec3 inner_facet = normalize(flat_view_n + vec3(sin(oct_uv.x * 4.5) * 0.22, cos(oct_uv.y * 4.5) * 0.22, 0.0));

	// 1. RGB Chromatic Dispersion Screen Refraction (real Swarovski prism effect!)
	vec2 base_off = inner_facet.xy * 0.048;
	float r_ch = textureLod(screen_texture, clamp(SCREEN_UV - base_off * 0.86, vec2(0.005), vec2(0.995)), 0.6).r;
	float g_ch = textureLod(screen_texture, clamp(SCREEN_UV - base_off * 1.00, vec2(0.005), vec2(0.995)), 0.6).g;
	float b_ch = textureLod(screen_texture, clamp(SCREEN_UV - base_off * 1.15, vec2(0.005), vec2(0.995)), 0.6).b;
	vec3 refracted_bg = vec3(r_ch, g_ch, b_ch) * mix(vec3(1.0), base * 1.35 + vec3(0.15, 0.25, 0.30), 0.68);

	// 2. CC0 Glacier Crystal MatCap + Sharp Studio Softbox Glints
	vec2 mc_uv = inner_facet.xy * vec2(0.49, -0.49) + 0.5;
	vec3 mc_crystal = texture(u_matcap_crystal, mc_uv).rgb;

	vec3 world_n = normalize((INV_VIEW_MATRIX * vec4(flat_view_n, 0.0)).xyz);
	vec3 world_view = normalize(INV_VIEW_MATRIX[3].xyz - v_world_pos);
	vec3 refl_dir = reflect(-world_view, world_n);
	vec3 studio_glint = textureLod(u_studio_env, dir_to_equirect(refl_dir), 0.0).rgb;

	float fresnel = pow(1.0 - clamp(abs(flat_view_n.z), 0.0, 1.0), 2.4);
	float sparkle = smoothstep(0.78, 0.98, dot(studio_glint, vec3(0.333)));

	vec3 col = mix(refracted_bg, mc_crystal * (base * 1.25 + vec3(0.18)), 0.52);
	col += studio_glint * (0.22 + 0.52 * fresnel) + vec3(1.0) * sparkle * 0.55;

	float sym = diamond_symbol(face_uv * 1.25);
	col = mix(col, vec3(1.0), sym * 0.88 * u_show_symbols);

	float ao = clamp(v_custom.w, 0.42, 1.0);
	ALBEDO = col * mix(0.65, 1.0, ao);
}
