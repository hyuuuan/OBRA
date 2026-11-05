shader_type canvas_item;
render_mode unshaded;

uniform float art_fraction;

void fragment() {
	// Keep the painted frames in proportion. Their last row falls into shadow
	// below the artwork, where a low camera or the minimap can see the gorge.
	float art_y = UV.y / art_fraction;
	vec3 falls = texture(TEXTURE, vec2(UV.x, min(art_y, 1.0 - TEXTURE_PIXEL_SIZE.y * 0.5))).rgb;
	vec3 shadow = vec3(0.024, 0.10, 0.115);
	COLOR = vec4(mix(falls, shadow, smoothstep(1.0, 1.38, art_y)), 1.0);
}
