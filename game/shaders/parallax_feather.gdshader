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

void fragment() {
	vec4 colour = texture(TEXTURE, UV) * COLOR;
	float across = (UV.x - region.x) / max(region.z - region.x, 0.00001);
	colour.a *= smoothstep(0.0, feather, across) * smoothstep(0.0, feather, 1.0 - across);
	COLOR = colour;
}
