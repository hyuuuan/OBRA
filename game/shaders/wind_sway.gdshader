shader_type canvas_item;

// Palms in the wind. The top of the sprite leans and comes back while its foot stays planted,
// which is a shear of the whole quad -- the image is untouched, so every pixel stays a hard
// square and it reads as the painting moving rather than as a filter laid over it.
//
// `lean` is how far the top travels, in texels; `gust` how many sways a second; `phase` keeps
// two clumps from moving in lockstep. `root` is the UV.y the foot sits at: below it, nothing
// moves -- the rocks a clump stands on are part of the same plate.

uniform float lean = 6.0;
uniform float gust = 0.35;
uniform float phase = 0.0;
uniform float root = 0.85;

void vertex() {
	float height = clamp((root - UV.y) / max(root, 0.001), 0.0, 1.0);
	float swing = sin(TIME * gust * 6.2831 + phase) * 0.7 + sin(TIME * gust * 2.7 * 6.2831 + phase * 1.7) * 0.3;
	VERTEX.x += floor(swing * lean * height + 0.5);
}
