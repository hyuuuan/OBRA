shader_type canvas_item;
// The scene transition: one stroke of ink across the screen (LevelManager). `progress` 0 -> 1
// sweeps its head across until the screen is ink; 1 -> 2 sweeps its tail on past, showing the next
// scene behind it. A brush stroke and not a plain edge: its head and tail are ragged where the
// bristles run out, streaked along their length, the stroke leaning as a wrist would lean it, and
// spattered with dry flecks just ahead of the head.

uniform float progress : hint_range(0.0, 2.0) = 0.0;
uniform vec4 ink : source_color = vec4(0.055, 0.075, 0.062, 1.0);
uniform vec4 ink_light : source_color = vec4(0.11, 0.15, 0.12, 1.0);
// How deep the ragged head and tail are, as a share of the screen's width.
uniform float ragged = 0.16;
// How far the stroke leans (its top ahead of its bottom).
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

void fragment() {
	vec2 uv = UV;
	// Bristles: each row of the stroke runs a little ahead or behind its neighbours.
	float bristle = noise(vec2(0.0, uv.y * 46.0)) * 0.55 + noise(vec2(3.0, uv.y * 11.0)) * 0.45;
	float x = uv.x - (0.5 - uv.y) * lean;
	float span = 1.0 + ragged * 2.0 + lean;
	float head = -ragged - lean * 0.5 + span * clamp(progress, 0.0, 1.0);
	float tail = -ragged - lean * 0.5 + span * clamp(progress - 1.0, 0.0, 1.0);
	float edge = (bristle - 0.5) * ragged;
	float inside = step(x + edge, head) * step(tail, x + edge * 0.85);
	// Dry flecks just ahead of the head while it is crossing.
	float ahead = head - (x + edge);
	float fleck = step(0.86, hash(floor(uv * vec2(160.0, 90.0)))) * step(-0.05, ahead) * step(ahead, 0.0) * step(progress, 0.99);
	float alpha = clamp(inside + fleck, 0.0, 1.0);
	// The ink itself: darker along the bristle grooves, a sheen where the stroke is thick.
	vec3 colour = mix(ink.rgb, ink_light.rgb, smoothstep(0.35, 0.95, noise(vec2(uv.x * 3.0, uv.y * 60.0))) * 0.5);
	COLOR = vec4(colour, alpha * ink.a);
}
