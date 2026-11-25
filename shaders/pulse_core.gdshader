shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, unshaded;

// Radiant Golden Pulse Energy Core (Matches Page 2 glowing sun-core inside Rocket porthole!)
uniform float u_clock = 0.0;

varying vec3 v_local_pos;

void vertex() {
	v_local_pos = VERTEX;
	float pulse = 1.0 + sin(u_clock * 6.5) * 0.06;
	VERTEX *= pulse;
}

void fragment() {
	float ndv = clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
	float pulse = 0.5 + 0.5 * sin(u_clock * 7.0);
	vec3 core_white = vec3(1.0, 0.99, 0.90);
	vec3 core_gold = vec3(1.0, 0.76, 0.14);
	vec3 core_orange = vec3(1.0, 0.48, 0.08);
	vec3 col = mix(core_orange, core_gold, smoothstep(0.12, 0.58, ndv));
	col = mix(col, core_white, smoothstep(0.55, 0.96, ndv) * (0.78 + 0.22 * pulse));
	ALBEDO = col * (1.18 + 0.16 * pulse);
}
