shader_type canvas_item;
render_mode unshaded;

uniform sampler2D incoming : filter_nearest;
uniform float divider = 1.2;
uniform float column_width = 0.175;
uniform float column_softness = 0.225;
uniform bool foreground = false;

// One edge owns BOTH scenery masks and the occluding foreground. No screen-texture feedback.
float edge(float y) {
	return divider + (sin(y * 25.0) + sin(y * 63.0) * 0.45) * 0.004;
}

void fragment() {
	float seam = edge(UV.y);
	if (foreground) {
		// An opaque core hides the hard scenery seam and actors. Only the outer shadow
		// feathers out; the two places never dissolve through one another.
		float distance_to_edge = abs(UV.x - seam) - column_width * 0.5;
		float opacity = 1.0 - smoothstep(0.0, column_softness, distance_to_edge);
		COLOR = vec4(0.005, 0.006, 0.008, opacity);
	} else {
		vec4 old_place = texture(TEXTURE, UV);
		vec4 next_place = texture(incoming, UV);
		COLOR = mix(old_place, next_place, step(seam, UV.x));
	}
}
