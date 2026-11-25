shader_type sky;

// Clean Cool-Architectural Light Gray-Blue Stage Gradient (#E8EEF5 -> #F5F8FC)
// Calibrated in linear space so output after Filmic tonemapping matches Page 2's exact cool light gray-blue!
uniform vec3 u_top_color : source_color = vec3(0.835, 0.882, 0.935);
uniform vec3 u_mid_color : source_color = vec3(0.885, 0.918, 0.958);
uniform vec3 u_bot_color : source_color = vec3(0.925, 0.948, 0.978);

void sky() {
	vec2 uv = SCREEN_UV;
	float d = length((uv - vec2(0.5, 0.34)) * vec2(1.0, 1.35));
	float spot = exp(-d * d * 2.4) * 0.045;
	vec3 col = mix(u_top_color, u_mid_color, smoothstep(0.0, 0.55, uv.y));
	col = mix(col, u_bot_color, smoothstep(0.50, 1.0, uv.y));
	COLOR = clamp(col + vec3(spot), 0.0, 1.0);
}
