shader_type canvas_item;
// THE DIM, WITH A HOLE IN IT WHERE THE LESSON IS.
//
// One full-screen rect. Everything is darkened except a rounded box around the thing a lesson
// is about -- a button, a gauge, the apo -- and a gold ring stands at the edge of that box and
// keeps leaving it, so the eye is pulled to the one bright place on a dark screen before a
// word is read. That is the point: a player who does not read still sees WHERE.
//
// Pixels, not UV: `rect_size` is the rect's own size, so `hole` is in the same screen units
// the HUD reports through get_global_rect(), and nothing has to be converted twice.

uniform vec2 rect_size = vec2(1600.0, 900.0);
// x, y, width, height of the lit box. A zero size dims the whole screen.
uniform vec4 hole = vec4(0.0);
uniform float radius = 18.0;
uniform float feather = 26.0;
uniform float dim : hint_range(0.0, 1.0) = 0.62;
uniform vec4 shade : source_color = vec4(0.02, 0.03, 0.02, 1.0);
uniform vec4 ring_color : source_color = vec4(0.859, 0.659, 0.208, 1.0);
// 0..1, how far the current ring has travelled out from the edge of the box.
uniform float pulse = 0.0;
uniform float ring_strength : hint_range(0.0, 1.0) = 1.0;
// The whole dim fading in and out. A shader that writes COLOR does not get the node's
// modulate, so the fade has to be its own.
uniform float fade : hint_range(0.0, 1.0) = 1.0;

float round_box(vec2 p, vec2 half_size, float r) {
	vec2 q = abs(p) - half_size + vec2(r);
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

void fragment() {
	vec2 p = UV * rect_size;
	float alpha = dim;
	float ring = 0.0;
	if (hole.z > 0.5 && hole.w > 0.5) {
		vec2 centre = hole.xy + hole.zw * 0.5;
		float r = min(radius, min(hole.z, hole.w) * 0.5);
		float d = round_box(p - centre, hole.zw * 0.5, r);
		alpha = smoothstep(0.0, feather, d) * dim;
		// A steady keyline on the edge, and a second ring that travels outward and fades.
		float edge = 1.0 - smoothstep(1.0, 3.0, abs(d - 2.0));
		float travel = 1.0 - smoothstep(1.0, 3.5, abs(d - 4.0 - pulse * 28.0));
		ring = max(edge * 0.85, travel * (1.0 - pulse)) * ring_strength;
	}
	vec3 colour = mix(shade.rgb, ring_color.rgb, ring);
	COLOR = vec4(colour, max(alpha, ring) * fade);
}
