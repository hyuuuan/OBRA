shader_type canvas_item;
render_mode unshaded, blend_add;

// Local coordinates keep the fade attached to the lens while the pointer turns it.
// World coordinates keep suspended specks in the water rather than stuck to the torch.
uniform float beam_length = 260.0;
uniform float half_angle = 0.38;
uniform float underwater = 0.0;
uniform float phase = 0.0;
// The defaults are the hand flashlight's. The bakunawa's beam is the same light (bakunawa_2d.gd),
// but it is a stealth rule 460 to 1000 px long, so it must still read at the far edge of what
// it can see: it asks for more light, kept further out, and sides that hold on longer.
uniform vec3 lamp = vec3(1.0, 0.94, 0.73);
uniform float gain = 1.0;
uniform float carry = 0.0;
uniform float side_from = 0.35;
varying vec2 beam_position;
varying vec2 world_position;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void vertex() {
	beam_position = VERTEX - vec2(20.0, 0.0);
	world_position = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	// Two-world-pixel cells preserve the artwork's grid, including the soft penumbra.
	vec2 p = floor(beam_position / 2.0) * 2.0 + 1.0;
	float along = clamp(p.x / beam_length, 0.0, 1.0);
	float width = 7.0 + max(p.x, 0.0) * tan(half_angle);
	float across = abs(p.y) / width;
	float side = 1.0 - smoothstep(side_from, 1.0, across);
	float end_fade = 1.0 - smoothstep(0.50, 1.0, along);
	float start = smoothstep(-2.0, 4.0, p.x);
	float falloff = mix(exp(-along * 2.0), 1.0, carry) * end_fade;
	float core = exp(-across * across * 8.0);
	float haze = side * falloff * start;
	float lens = exp(-dot(p / vec2(13.0, 10.0), p / vec2(13.0, 10.0)) * 1.6);
	vec3 water = vec3(0.35, 0.78, 1.0);
	vec3 tint = mix(lamp, water, underwater * (0.25 + along * 0.55));

	// Refraction makes faint, moving ribs in the haze; no strobing or camera effects.
	vec2 world_pixel = floor(world_position / 2.0) * 2.0;
	float refraction = sin(world_pixel.x * 0.032 + world_pixel.y * 0.071 + phase * 0.65)
		* sin(world_pixel.y * 0.043 - phase * 0.45);
	float shimmer = 1.0 + underwater * refraction * 0.12;
	vec2 drift = world_pixel + vec2(phase * 4.0, -phase * 9.0);
	vec2 cell = floor(drift / 19.0);
	vec2 centre = vec2(hash(cell + 7.0), hash(cell + 23.0)) * 0.7 + 0.15;
	float mote = 1.0 - smoothstep(0.025, 0.085, length(fract(drift / 19.0) - centre));
	mote *= step(0.86, hash(cell)) * underwater * haze;
	float brightness = haze * (0.13 + core * 0.14) * shimmer * gain + lens * 0.38;
	COLOR = vec4(mix(tint, vec3(0.72, 0.95, 1.0), mote), brightness + mote * 0.60);
}
