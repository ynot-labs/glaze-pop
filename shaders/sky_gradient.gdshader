shader_type sky;

// Clean Cool-Architectural Light Gray-Blue Stage Gradient (#E8EEF5 -> #F5F8FC)
// GDD 5.1 & Page 2 visual benchmark: pure clean floating studio sky (zero floor, table, or clouds!)
uniform vec3 u_top_color : source_color = vec3(0.910, 0.933, 0.961);
uniform vec3 u_mid_color : source_color = vec3(0.945, 0.962, 0.982);
uniform vec3 u_bot_color : source_color = vec3(0.961, 0.973, 0.988);

void sky() {
	vec2 uv = SCREEN_UV;
	float d = length((uv - vec2(0.5, 0.34)) * vec2(1.0, 1.4));
	float spot = exp(-d * d * 2.6) * 0.028;
	vec3 col = mix(u_top_color, u_mid_color, smoothstep(0.0, 0.55, uv.y));
	col = mix(col, u_bot_color, smoothstep(0.50, 1.0, uv.y));
	COLOR = clamp(col + vec3(spot), 0.0, 1.0);
}
