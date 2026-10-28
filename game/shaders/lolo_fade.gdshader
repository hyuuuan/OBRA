shader_type canvas_item;

// LOLO, FADING (Level 5). He is lola's memory of him and nothing else, and the painting coming
// apart is him coming apart: lower opacity, an outline that will not hold still, colour that
// does not quite hold. `thinness` 0 is the lolo of Levels 1-3; 1 is nearly nothing.
uniform float thinness : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	// The outline will not hold still: each row of pixels slips sideways by whole texels, a
	// different way each moment, further the thinner he is.
	float row = floor(UV.y / TEXTURE_PIXEL_SIZE.y);
	float slip = floor(sin(row * 1.7 + floor(TIME * 9.0) * 2.3) * 1.5 * thinness + 0.5);
	vec4 colour = texture(TEXTURE, UV + vec2(slip * TEXTURE_PIXEL_SIZE.x, 0.0)) * COLOR;
	float luminance = dot(colour.rgb, vec3(0.2126, 0.7152, 0.0722));
	// Colour that does not hold: it greys and comes back, unevenly.
	float hold = 1.0 - thinness * (0.55 + 0.25 * sin(TIME * 1.3 + row * 0.05));
	colour.rgb = mix(vec3(luminance), colour.rgb, clamp(hold, 0.0, 1.0));
	colour.a *= 1.0 - 0.55 * thinness;
	COLOR = colour;
}
