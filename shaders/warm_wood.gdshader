shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform float u_clock = 0.0;
uniform float u_show_symbols = 0.0;

varying vec4 v_custom;
varying vec3 v_local_pos;
varying vec3 v_local_nrm;
varying vec3 v_seed;

void vertex() {
	v_custom = INSTANCE_CUSTOM;
	v_local_pos = VERTEX;
	v_local_nrm = NORMAL;
	v_seed = MODEL_MATRIX[3].xyz * 0.37;

	float dt = u_clock - v_custom.y;
	if (v_custom.y > 0.01 && dt >= 0.0 && dt < 0.40) {
		float knock = exp(-dt * 16.0) * sin(dt * 44.0) * 0.035;
		VERTEX.xz += vec2(knock, -knock * 0.7);
	}
}

float hash31(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.zyx + 31.32);
	return fract((p.x + p.y) * p.z);
}

float noise3(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float n000 = hash31(i + vec3(0,0,0));
	float n100 = hash31(i + vec3(1,0,0));
	float n010 = hash31(i + vec3(0,1,0));
	float n110 = hash31(i + vec3(1,1,0));
	float n001 = hash31(i + vec3(0,0,1));
	float n101 = hash31(i + vec3(1,0,1));
	float n011 = hash31(i + vec3(0,1,1));
	float n111 = hash31(i + vec3(1,1,1));
	return mix(
		mix(mix(n000, n100, f.x), mix(n010, n110, f.x), f.y),
		mix(mix(n001, n101, f.x), mix(n011, n111, f.x), f.y),
		f.z
	);
}

float wood_symbol(vec2 p) {
	vec2 q = abs(p);
	float outer = max(q.x, q.y) - 0.185;
	float inner = max(q.x, q.y) - 0.115;
	float d = max(outer, -inner);
	float bar = max(abs(p.y) - 0.025, abs(p.x) - 0.16);
	d = min(d, bar);
	float aa = max(fwidth(d), 0.008);
	return 1.0 - smoothstep(-aa, aa, d);
}

void fragment() {
	vec3 base = COLOR.rgb;
	// Organic 3D walnut/oak timber rings + fine longitudinal fibers
	vec3 wp = (v_local_pos + v_seed) * vec3(4.2, 1.35, 4.2);
	float warp = noise3(wp * 1.8) * 0.55;
	float rings = sin((length(wp.xz + warp) * 7.5)) * 0.5 + 0.5;
	rings = smoothstep(0.15, 0.88, rings);
	float fibers = noise3(v_local_pos * vec3(28.0, 5.5, 28.0) + v_seed * 7.0);

	vec3 light_wood = base * 1.14 + vec3(0.05, 0.03, 0.01);
	vec3 dark_grain = base * 0.68;
	vec3 col = mix(dark_grain, light_wood, rings * 0.72 + fibers * 0.28);

	vec3 an = abs(v_local_nrm);
	vec2 face_uv = (an.y > an.x && an.y > an.z) ? v_local_pos.xz : ((an.x > an.z) ? v_local_pos.zy : v_local_pos.xy);
	// Subtle warm chamfer edge highlight (mortise-tenon craftsmanship!)
	float chamfer = smoothstep(0.38, 0.48, max(abs(face_uv.x), abs(face_uv.y)));
	col = mix(col, light_wood * 1.05, chamfer * 0.28);

	float sym = wood_symbol(face_uv * 1.25);
	col = mix(col, vec3(0.99, 0.94, 0.84), sym * 0.82 * u_show_symbols);

	float ao = clamp(v_custom.w, 0.26, 1.0);
	ALBEDO = col * mix(0.48, 1.0, ao);
	ROUGHNESS = mix(0.54, 0.40, rings);
	SPECULAR = 0.34;
	METALLIC = 0.0;
}
