shader_type sky;

// Clean Cool-Architectural Light Gray-Blue Stage Gradient (#E8EEF5 -> #F5F8FC)
// Calibrated specifically for GL Compatibility + WebGL2 + Filmic tonemapper so it renders
// as a crisp cool light-blue-gray studio stage (NOT washed-out pure white!)
uniform vec3 u_top_color : source_color = vec3(0.760, 0.832, 0.915);
uniform vec3 u_mid_color : source_color = vec3(0.840, 0.890, 0.948);
uniform vec3 u_bot_color : source_color = vec3(0.900, 0.932, 0.970);

void sky() {
	vec2 uv = SCREEN_UV;
	float d = length((uv - vec2(0.5, 0.36)) * vec2(1.0, 1.35));
	float spot = exp(-d * d * 2.5) * 0.04;
	vec3 col = mix(u_top_color, u_mid_color, smoothstep(0.0, 0.55, uv.y));
	col = mix(col, u_bot_color, smoothstep(0.50, 1.0, uv.y));
	COLOR = clamp(col + vec3(spot), 0.0, 1.0);
}
