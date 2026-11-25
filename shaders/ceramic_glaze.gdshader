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
	if (v_custom.y > 0.01 && dt >= 0.0 && dt < 0.55) {
		float amp = exp(-dt * 11.0) * sin(dt * 38.0) * 0.055;
		VERTEX.xz *= 1.0 + amp;
		VERTEX.y *= 1.0 - amp * 1.15;
	}
}

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float symbol_mask(vec2 p, int sym_id) {
	float d = 1.0;
	if (sym_id == 0) {
		// Ring + center dot (Celadon Ceramic)
		float r = length(p);
		d = min(abs(r - 0.19) - 0.032, r - 0.055);
	} else if (sym_id == 5) {
		// Four-point star (Amber Glaze)
		vec2 q = abs(p);
		d = (q.x + q.y * 0.42 - 0.11);
		d = min(d, q.y + q.x * 0.42 - 0.11);
		d = max(d, length(p) - 0.24);
	} else {
		float r = length(p);
		d = abs(r - 0.17) - 0.03;
	}
	float aa = max(fwidth(d), 0.008);
	return 1.0 - smoothstep(-aa, aa, d);
}

void fragment() {
	vec3 base = COLOR.rgb;
	vec3 an = abs(v_local_nrm);
	vec2 face_uv = (an.y > an.x && an.y > an.z) ? v_local_pos.xz : ((an.x > an.z) ? v_local_pos.zy : v_local_pos.xy);

	// Fine artisan stoneware micro-speckle & glaze pooling near beveled edges
	float edge_dist = max(abs(face_uv.x), abs(face_uv.y));
	float glaze_pool = smoothstep(0.28, 0.47, edge_dist);
	float speckle = hash21(floor((face_uv + 0.5) * 42.0));
	vec3 col = mix(base, base * 0.86 + vec3(0.05, 0.05, 0.04), glaze_pool * 0.45);
	if (speckle > 0.94) {
		col *= 0.88;
	}

	// Subtle micro-dot embossed grid + optional high-contrast accessibility symbol
	vec2 dot_grid = fract((face_uv + 0.5) * 5.0) - 0.5;
	float micro_dot = 1.0 - smoothstep(0.14, 0.22, length(dot_grid));
	col += vec3(0.025) * micro_dot * (1.0 - glaze_pool);

	int sym_id = int(round(v_custom.x));
	float sym = symbol_mask(face_uv * 1.25, sym_id);
	float sym_vis = 0.82 * u_show_symbols;
	col = mix(col, vec3(0.99, 0.97, 0.93), sym * sym_vis);

	// Analytical 3D voxel cavity Ambient Occlusion in v_custom.w
	float ao = clamp(v_custom.w, 0.28, 1.0);
	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.4);

	ALBEDO = col * mix(0.52, 1.0, ao) + vec3(0.05, 0.05, 0.045) * fresnel;
	ROUGHNESS = mix(0.30, 0.18, glaze_pool);
	SPECULAR = 0.62;
	METALLIC = 0.02;
}
