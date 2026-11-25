shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_back, specular_schlick_ggx;

uniform vec4 glass_tint : source_color = vec4(0.93, 0.97, 1.0, 1.0);

void fragment() {
	float ndv = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float fresnel = pow(1.0 - ndv, 3.4);
	vec3 refl = reflect(-VIEW, NORMAL);
	// Studio softbox vertical specular highlight streak on curved glass bell jar!
	float streak1 = pow(clamp(dot(normalize(refl), normalize(vec3(-0.55, 0.45, 0.70))), 0.0, 1.0), 28.0);
	float streak2 = pow(clamp(dot(normalize(refl), normalize(vec3(0.65, 0.35, 0.65))), 0.0, 1.0), 42.0);

	ALBEDO = glass_tint.rgb * 0.92 + vec3(1.0) * (streak1 * 0.65 + streak2 * 0.35);
	EMISSION = vec3(0.95, 0.98, 1.0) * (streak1 * 0.28 + fresnel * 0.16);
	ROUGHNESS = 0.04;
	SPECULAR = 1.0;
	METALLIC = 0.08;
	ALPHA = clamp(0.12 + fresnel * 0.48 + streak1 * 0.42 + streak2 * 0.22, 0.10, 0.74);
}
