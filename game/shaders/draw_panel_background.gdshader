shader_type canvas_item;
render_mode unshaded;

// The draw panel is a lens held over the paused level. Mipmapped screen samples
// make the rim progressively softer while the page-sized centre keeps a low,
// deliberately non-zero blur floor.
uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap, repeat_disable;

uniform vec4 veil_color : source_color = vec4(0.027, 0.035, 0.024, 1.0);
uniform vec4 wind_gold : source_color = vec4(0.859, 0.659, 0.208, 1.0);
uniform vec4 wind_pale : source_color = vec4(0.945, 0.855, 0.616, 1.0);
uniform float veil_strength : hint_range(0.0, 1.0) = 0.66;
uniform float edge_blur_lod : hint_range(0.0, 7.0) = 5.8;
uniform float spin_blur : hint_range(0.0, 0.05) = 0.020;
uniform float chromatic_pixels : hint_range(0.0, 8.0) = 2.1;
uniform float polar_displacement : hint_range(0.0, 0.02) = 0.0070;
uniform float dream_flow_pixels : hint_range(0.0, 32.0) = 14.0;
uniform float dream_speed : hint_range(0.0, 2.0) = 0.34;
uniform float dream_breathe : hint_range(0.0, 0.25) = 0.10;

// Driven from DrawPanel. It starts at one and burns away during the entrance,
// leaving only the quieter, constantly moving polar lens behind the page.
uniform float opening_burst : hint_range(0.0, 1.0) = 0.0;


vec2 rotate_around_origin(vec2 point, float angle) {
	float sine = sin(angle);
	float cosine = cos(angle);
	return mat2(vec2(cosine, sine), vec2(-sine, cosine)) * point;
}


float soft_band(float value, float centre, float half_width) {
	return 1.0 - smoothstep(half_width, half_width + 0.012, abs(value - centre));
}


void fragment() {
	float node_alpha = COLOR.a;
	float aspect = SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	vec2 point = SCREEN_UV - vec2(0.5);
	point.x *= aspect;
	float radius = length(point);
	float angle = atan(point.y, point.x);
	vec2 radial = point / max(radius, 0.0001);
	vec2 tangent = vec2(-radial.y, radial.x);

	// Blur rises from 20% in the centre to 85% at the viewport edge. The opening
	// adds a strong polar pull around the page which settles into a breathing drift.
	float edge = smoothstep(0.10, 0.83, radius);
	float blur_weight = mix(0.20, 0.85, edge);
	float polar_wave = sin(radius * 38.0 - TIME * 1.35 + angle * 5.0);
	float swirl_window = smoothstep(0.18, 0.30, radius)
		* (1.0 - smoothstep(0.80, 0.96, radius));
	float ambient_twist = sin(TIME * 0.55 + radius * 8.0) * 0.006 * blur_weight;
	float opening_twist = opening_burst * swirl_window
		* (0.18 + sin(angle * 3.0 - TIME * 2.4) * 0.035);
	vec2 warped_point = rotate_around_origin(
		point,
		ambient_twist + opening_twist
	);
	warped_point += radial * polar_wave * polar_displacement * blur_weight;
	warped_point += tangent * sin(angle * 7.0 + TIME * 0.8)
		* polar_displacement * 0.55 * blur_weight;

	// A slow, continuously rotating smear keeps the paused world from becoming a
	// static screenshot. The breathing term only adds blur, so the 20% centre and
	// 85% edge remain hard minimums throughout the cycle.
	float dream_time = TIME * dream_speed;
	float breath = 0.5 + 0.5 * sin(dream_time * 1.7 + radius * 5.0 - angle * 0.8);
	float blur_lod = edge_blur_lod * blur_weight
		* (1.0 + breath * dream_breathe + opening_burst * 0.12);
	float blur_span = spin_blur * blur_weight * (0.70 + opening_burst * 1.55);
	float flow_angle = dream_time
		+ sin(dream_time * 0.73 + radius * 6.0 + angle * 2.0) * 0.48;
	vec2 flow_axis = vec2(cos(flow_angle), sin(flow_angle));
	float flow_length = dream_flow_pixels * SCREEN_PIXEL_SIZE.y * blur_weight
		* mix(0.72, 1.0, breath);
	vec3 scene = vec3(0.0);
	for (int sample_index = -2; sample_index <= 2; sample_index++) {
		float sample_phase = float(sample_index) * 0.5;
		float sample_angle = sample_phase * blur_span;
		vec2 sample_point = rotate_around_origin(warped_point, sample_angle);
		// The secondary curve prevents the five taps from reading as a straight
		// directional streak; the kernel slowly curls as it travels.
		sample_point += flow_axis * sample_phase * flow_length;
		sample_point += tangent * sin(sample_phase * 1.5707963 + dream_time * 0.9)
			* flow_length * 0.24;
		vec2 sample_uv = vec2(sample_point.x / aspect, sample_point.y) + vec2(0.5);
		scene += textureLod(screen_texture, clamp(sample_uv, vec2(0.001), vec2(0.999)), blur_lod).rgb;
	}
	scene /= 5.0;

	// The colour split follows the circular motion instead of sliding horizontally,
	// so it reads as paint passing through a spinning lens rather than a TV glitch.
	vec2 base_uv = vec2(warped_point.x / aspect, warped_point.y) + vec2(0.5);
	vec2 chroma_offset = vec2(tangent.x / aspect, tangent.y) 
		* SCREEN_PIXEL_SIZE * chromatic_pixels * (0.20 + edge * 0.80);
	float red = textureLod(screen_texture, clamp(base_uv + chroma_offset, vec2(0.001), vec2(0.999)), blur_lod).r;
	float blue = textureLod(screen_texture, clamp(base_uv - chroma_offset, vec2(0.001), vec2(0.999)), blur_lod).b;
	scene.r = mix(scene.r, red, 0.82);
	scene.b = mix(scene.b, blue, 0.82);

	vec3 veiled_scene = mix(scene, veil_color.rgb, veil_strength);

	// Pixel-wind: quantised spiral ribbons and small broken glints sweep around the
	// page only while it arrives. Quantising before deriving polar coordinates keeps
	// every mote on the same chunky pixel grid as the rest of the interface.
	vec2 wind_grid = vec2(400.0, 225.0);
	vec2 pixel_uv = (floor(SCREEN_UV * wind_grid) + vec2(0.5)) / wind_grid;
	vec2 pixel_point = pixel_uv - vec2(0.5);
	pixel_point.x *= aspect;
	float pixel_radius = length(pixel_point);
	float pixel_angle = atan(pixel_point.y, pixel_point.x);
	float spiral_phase = fract(pixel_radius * 6.0 - pixel_angle / 6.2831853 * 3.0 - TIME * 1.75);
	float inner_ribbon = soft_band(spiral_phase, 0.50, 0.022);
	float outer_ribbon = soft_band(fract(spiral_phase + 0.37), 0.50, 0.014);
	float counter_phase = fract(pixel_radius * 8.5 + pixel_angle / 6.2831853 * 4.0 + TIME * 2.1);
	float counter_ribbon = soft_band(counter_phase, 0.50, 0.012);
	float dash = step(0.38, fract(pixel_angle / 6.2831853 * 20.0
		+ floor(pixel_radius * 24.0) * 0.31 + TIME * 0.5));
	float ring_window = smoothstep(0.22, 0.30, pixel_radius)
		* (1.0 - smoothstep(0.74, 0.90, pixel_radius));
	float wind = (inner_ribbon + outer_ribbon * 0.72 + counter_ribbon * 0.42)
		* dash * ring_window * opening_burst;
	float glint = step(0.92, fract(sin(dot(floor(pixel_uv * wind_grid), vec2(12.9898, 78.233))) * 43758.5453));
	glint *= soft_band(fract(pixel_radius * 5.0 - TIME * 1.4), 0.5, 0.035) * ring_window * opening_burst;
	vec3 wind_color = mix(wind_gold.rgb, wind_pale.rgb, clamp(glint + outer_ribbon * 0.35, 0.0, 1.0));
	vec3 final_color = mix(veiled_scene, wind_color, clamp(wind * 0.92 + glint * 0.68, 0.0, 0.92));

	COLOR = vec4(final_color, node_alpha);
}
