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

	float dt = u_clock - v_custom.y;
	if (v_custom.y > 0.01 && dt >= 0.0 && dt < 0.45) {
		float shake = exp(-dt * 14.0) * sin(dt * 48.0) * 0.032;
		VERTEX += NORMAL * shake;
	}
}

float diamond_symbol(vec2 p) {
	vec2 q = abs(p);
	float d = (q.x + q.y) * 0.7071 - 0.155;
	float inner = (q.x + q.y) * 0.7071 - 0.085;
	d = max(d, -inner);
	float aa = max(fwidth(d), 0.008);
	return 1.0 - smoothstep(-aa, aa, d);
}

void fragment() {
	vec3 base = COLOR.rgb;
	// Accented flat gem-facet normal for razor-sharp diamond glints!
	vec3 flat_n = normalize(cross(dFdx(VERTEX), dFdy(VERTEX)));
	vec3 gem_n = normalize(mix(NORMAL, flat_n, 0.78));
	NORMAL = gem_n;

	vec3 an = abs(v_local_nrm);
	vec2 face_uv = (an.y > an.x && an.y > an.z) ? v_local_pos.xz : ((an.x > an.z) ? v_local_pos.zy : v_local_pos.xy);

	// Fake internal prism refraction & chromatic dispersion streak (zero screen-copy overhead!)
	vec3 refl = reflect(-VIEW, gem_n);
	float sky_band = smoothstep(-0.2, 0.75, refl.y);
	float prism_streak = pow(abs(sin(refl.x * 7.0 + refl.z * 5.0 + v_local_pos.y * 4.0)), 6.0);
	float fresnel = pow(1.0 - clamp(dot(gem_n, VIEW), 0.0, 1.0), 2.8);

	vec3 deep_ice = base * vec3(0.52, 0.78, 1.02);
	vec3 bright_ice = mix(base * 1.05, vec3(0.86, 0.96, 1.0), 0.42 * sky_band);
	vec3 dispersion = vec3(0.35, 0.82, 1.0) * prism_streak * 0.30;

	vec3 col = mix(deep_ice, bright_ice, 0.40 + 0.38 * fresnel) + dispersion;
	float sym = diamond_symbol(face_uv * 1.25);
	col = mix(col, vec3(1.0), sym * 0.85 * u_show_symbols);

	float ao = clamp(v_custom.w, 0.38, 1.0);
	ALBEDO = col * mix(0.60, 1.0, ao);
	EMISSION = (vec3(0.12, 0.38, 0.58) * prism_streak * 0.22 + vec3(0.45, 0.78, 0.96) * fresnel * 0.14) * ao;
	ROUGHNESS = 0.06;
	SPECULAR = 0.95;
	METALLIC = 0.12;
}
