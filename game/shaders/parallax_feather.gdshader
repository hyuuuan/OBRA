shader_type canvas_item;

// The background plates are painted with deep shadows because they were delivered as
// stand-alone illustrations. Once layered behind gameplay those shadows merge into one
// dark band. Lift midtones without lifting true black, then restore a little saturation;
// per-material defaults keep this shader neutral everywhere else. Alpha is deliberately
// left untouched: crop edges are handled by the scene composition, while fading opacity
// here creates a visible translucent stripe as the parallax layers move.
uniform float midtone_lift : hint_range(0.0, 1.0) = 0.0;
uniform float saturation : hint_range(0.0, 2.0) = 1.0;
uniform vec3 sunlight = vec3(1.0);
uniform float shadow_fill : hint_range(0.0, 0.25) = 0.0;

void fragment() {
	vec4 colour = texture(TEXTURE, UV) * COLOR;
	vec3 lifted = mix(colour.rgb, sqrt(max(colour.rgb, vec3(0.0))), midtone_lift);
	float luminance = dot(lifted, vec3(0.2126, 0.7152, 0.0722));
	// Leave outline-black alone, but put open-sky fill into painted shadow colours. This is
	// the difference between retaining the plate's pixel contours and merely greying it out.
	float fill_mask = smoothstep(0.025, 0.18, luminance) * (1.0 - luminance);
	lifted += sunlight * shadow_fill * fill_mask;
	colour.rgb = clamp(mix(vec3(luminance), lifted, saturation) * sunlight, 0.0, 1.0);
	COLOR = colour;
}
