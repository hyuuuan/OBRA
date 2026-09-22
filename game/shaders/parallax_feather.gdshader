shader_type canvas_item;

// A backdrop plate that is TILED, not painted to tile. Each copy stops at the edge of its own
// artwork, and where that edge falls on something opaque -- a terrace wall, a mound of rock --
// the cut runs straight up the screen. Fading the two side edges lets one copy go into the
// layer behind it instead of stopping against it.
//
// The region is the atlas rect in the texture's own UV (x0, y0, x1, y1): an AtlasTexture hands
// the shader UVs for the whole page, so "the edge of the art" has to be told.
uniform vec4 region = vec4(0.0, 0.0, 1.0, 1.0);
uniform float feather : hint_range(0.0, 0.5) = 0.07;
// The background plates are painted with deep shadows because they were delivered as
// stand-alone illustrations. Once layered behind gameplay those shadows merge into one
// dark band. Lift midtones without lifting true black, then restore a little saturation;
// per-material defaults keep this shader neutral everywhere else.
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
	float across = (UV.x - region.x) / max(region.z - region.x, 0.00001);
	colour.a *= smoothstep(0.0, feather, across) * smoothstep(0.0, feather, 1.0 - across);
	COLOR = colour;
}
