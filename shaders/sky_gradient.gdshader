shader_type sky;

// Cube Smash Rich Royal-Blue Radial Studio Backdrop (Zero glare, maximum jewel-block contrast!)
// Center royal-blue spotlight #134DC2 -> deep sapphire vignette #051A54
uniform vec3 u_center_color : source_color = vec3(0.075, 0.302, 0.761);
uniform vec3 u_mid_color : source_color = vec3(0.039, 0.192, 0.565);
uniform vec3 u_edge_color : source_color = vec3(0.018, 0.090, 0.320);

void sky() {
	vec2 uv = SCREEN_UV;
	float d = length((uv - vec2(0.5, 0.35)) * vec2(1.0, 1.35));
	float t1 = smoothstep(0.0, 0.55, d);
	float t2 = smoothstep(0.42, 1.15, d);
	vec3 col = mix(u_center_color, u_mid_color, t1);
	col = mix(col, u_edge_color, t2);
	COLOR = col;
}
