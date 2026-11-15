shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform float blur_pixels = 0.0;
uniform float exposure_stops = 0.0;
uniform float white_cast = 0.0;

void fragment() {
	vec2 step_uv = SCREEN_PIXEL_SIZE * blur_pixels;
	vec3 colour = texture(screen_texture, SCREEN_UV).rgb * 4.0;
	colour += texture(screen_texture, SCREEN_UV + vec2(step_uv.x, 0.0)).rgb * 2.0;
	colour += texture(screen_texture, SCREEN_UV - vec2(step_uv.x, 0.0)).rgb * 2.0;
	colour += texture(screen_texture, SCREEN_UV + vec2(0.0, step_uv.y)).rgb * 2.0;
	colour += texture(screen_texture, SCREEN_UV - vec2(0.0, step_uv.y)).rgb * 2.0;
	colour += texture(screen_texture, SCREEN_UV + step_uv).rgb;
	colour += texture(screen_texture, SCREEN_UV - step_uv).rgb;
	colour += texture(screen_texture, SCREEN_UV + vec2(step_uv.x, -step_uv.y)).rgb;
	colour += texture(screen_texture, SCREEN_UV + vec2(-step_uv.x, step_uv.y)).rgb;
	// Exposure adds light before the separate white veil. Modulation cannot do either.
	colour = min(colour * (exp2(exposure_stops) / 16.0), vec3(1.0));
	COLOR = vec4(mix(colour, vec3(1.0), white_cast), 1.0);
}
