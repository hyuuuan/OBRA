shader_type canvas_item;
// The scene transition: one stroke of ink across the screen (LevelManager), drawn as PIXEL ART
// (Kent, 2026-10-23: "pixelated style similar to the game"). Everything is worked out per cell of
// `pixel` screen px (at 1600 wide; scaled with the window), so the stroke's head and tail are
// stepped, its bristle streaks run per row of cells, its two ink tones are mixed by an ordered
// (Bayer) dither rather than a gradient, and its dry flecks are single cells. `progress` 0 -> 1
// sweeps its head across until the screen is ink; 1 -> 2 sweeps its tail on past.

uniform float progress : hint_range(0.0, 2.0) = 0.0;
uniform vec4 ink : source_color = vec4(0.055, 0.075, 0.062, 1.0);
uniform vec4 ink_light : source_color = vec4(0.12, 0.16, 0.13, 1.0);
// Screen px per stroke pixel, at a 1600-px-wide window.
uniform float pixel = 6.0;
// How deep the ragged head and tail are, and how far the stroke leans (shares of the width).
uniform float ragged = 0.16;
uniform float lean = 0.14;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

// The 4 x 4 ordered-dither threshold for a cell, 0..1.
float bayer(vec2 cell) {
	int x = int(mod(cell.x, 4.0));
	int y = int(mod(cell.y, 4.0));
	int index = x + y * 4;
	int table[16] = int[](0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5);
	return (float(table[index]) + 0.5) / 16.0;
}

void fragment() {
	vec2 screen = 1.0 / SCREEN_PIXEL_SIZE;
	float px = max(1.0, pixel * screen.x / 1600.0);
	vec2 cell = floor(FRAGCOORD.xy / px);
	vec2 cells = floor(screen / px);
	vec2 uv = (cell + 0.5) / cells;
	// Bristles: each row of cells runs a little ahead or behind its neighbours.
	float bristle = noise(vec2(0.0, uv.y * 46.0)) * 0.55 + noise(vec2(3.0, uv.y * 11.0)) * 0.45;
	float x = uv.x - (0.5 - uv.y) * lean;
	float span = 1.0 + ragged * 2.0 + lean;
	float head = -ragged - lean * 0.5 + span * clamp(progress, 0.0, 1.0);
	float tail = -ragged - lean * 0.5 + span * clamp(progress - 1.0, 0.0, 1.0);
	float edge = (bristle - 0.5) * ragged;
	float inside = step(x + edge, head) * step(tail, x + edge * 0.85);
	// Dry flecks, single cells, just ahead of the head while it crosses.
	float ahead = head - (x + edge);
	float fleck = step(0.86, hash(cell)) * step(-0.05, ahead) * step(ahead, 0.0) * step(progress, 0.99);
	float alpha = clamp(inside + fleck, 0.0, 1.0);
	// Two tones of ink, dithered: lighter along the grain of the stroke, never blended.
	float grain = smoothstep(0.35, 0.95, noise(vec2(uv.x * 3.0, uv.y * 60.0))) * 0.6;
	vec3 colour = grain > bayer(cell) ? ink_light.rgb : ink.rgb;
	COLOR = vec4(colour, alpha * ink.a);
}
