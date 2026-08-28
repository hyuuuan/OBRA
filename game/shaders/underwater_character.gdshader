shader_type canvas_item;

// The water itself already draws the pool. This shader changes the light reaching the
// character instead: warm wavelengths fall away with depth, the water colour scatters
// back in, and narrow surface caustics travel across the submerged pixels. World-space
// coordinates keep one waterline across a sprite or a collection of independent strokes.
uniform float effect_strength : hint_range(0.0, 1.0) = 0.0;
uniform float surface_y = 0.0;
uniform float bottom_y = 1.0;
uniform vec4 shallow_water : source_color = vec4(0.13, 0.55, 0.76, 1.0);
uniform vec4 deep_water : source_color = vec4(0.055, 0.28, 0.46, 1.0);
uniform vec4 caustic_light : source_color = vec4(0.62, 0.90, 0.91, 1.0);

varying vec2 world_position;


void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}


void fragment() {
	vec4 source = texture(TEXTURE, UV) * COLOR;
	float water_depth = max(bottom_y - surface_y, 1.0);
	float depth = clamp((world_position.y - surface_y) / water_depth, 0.0, 1.0);
	// A narrow feather avoids a one-pixel on/off seam as the character crosses the
	// surface while keeping the waterline crisp enough for the pixel-art world.
	float submerged = smoothstep(surface_y - 1.5, surface_y + 5.5, world_position.y);
	float amount = submerged * effect_strength;

	vec3 water_light = mix(shallow_water.rgb, deep_water.rgb, depth);
	// Red is absorbed first, then green. Blue survives longest. Multiplying the actual
	// source palette makes this illumination, not a translucent rectangle pasted on top.
	vec3 transmission = mix(vec3(0.60, 0.79, 0.94), vec3(0.38, 0.61, 0.86), depth);
	vec3 lit = source.rgb * transmission;
	lit = mix(lit, water_light, 0.12 + depth * 0.16);

	// Two travelling wave fields produce short, irregular shafts rather than one large
	// sine band. Quantised time and position preserve the deliberate pixel movement.
	float stepped_time = floor(TIME * 10.0) / 10.0;
	float stepped_x = floor(world_position.x * 0.5) * 2.0;
	float wave_a = sin(stepped_x * 0.105 + stepped_time * 2.1
		+ sin(world_position.y * 0.055 - stepped_time) * 1.35);
	float wave_b = sin(stepped_x * 0.061 - stepped_time * 1.45
		+ sin(world_position.y * 0.038 + stepped_time * 0.7));
	float caustic = smoothstep(1.24, 1.72, wave_a + wave_b);
	caustic *= (1.0 - depth * 0.62);
	lit += caustic_light.rgb * caustic * 0.20;

	// Broad moving shade makes the body respond to water motion even between caustics.
	float drift = sin(world_position.x * 0.035 + world_position.y * 0.018
		- stepped_time * 0.8) * 0.025;
	lit *= 0.95 + drift;

	COLOR = vec4(mix(source.rgb, lit, amount), source.a);
}
