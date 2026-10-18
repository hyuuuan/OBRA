shader_type canvas_item;
// THE DARK, WITH THE LIGHTS CUT OUT OF IT.
//
// One full-screen rect over the world, under every HUD layer. Each light the scene has is a hole:
// a radial one (a lantern, a fire) or a cone (a flashlight). The falloff and the way two lights
// combine (the brighter wins) are exactly LightField's, which is what gameplay asks -- so what the
// player can see and what the game counts as lit are the same thing.
//
// Pixels, not UV, like the tutorial spotlight: holes arrive in screen px from DarknessLayer.

uniform vec2 rect_size = vec2(1600.0, 900.0);
uniform float darkness : hint_range(0.0, 1.0) = 0.9;
uniform vec4 shade : source_color = vec4(0.012, 0.016, 0.035, 1.0);
// The share of a light's radius that is fully lit (LightField.SOFT_EDGE).
uniform float soft_edge = 0.6;
uniform int hole_count = 0;
// x, y, radius (screen px), strength
uniform vec4 holes[16];
uniform int cone_count = 0;
// x, y, radius (screen px), strength
uniform vec4 cones[4];
// direction x, direction y, half angle (radians), unused
uniform vec4 cone_dirs[4];

void fragment() {
	vec2 p = UV * rect_size;
	float lit = 0.0;
	for (int i = 0; i < 16; i++) {
		if (i >= hole_count) {
			break;
		}
		vec4 h = holes[i];
		float d = distance(p, h.xy);
		lit = max(lit, (1.0 - smoothstep(h.z * soft_edge, h.z, d)) * h.w);
	}
	for (int i = 0; i < 4; i++) {
		if (i >= cone_count) {
			break;
		}
		vec4 c = cones[i];
		vec2 off = p - c.xy;
		float d = length(off);
		float fall = (1.0 - smoothstep(c.z * soft_edge, c.z, d)) * c.w;
		float half_angle = cone_dirs[i].z;
		float angle = d > 1.0 ? acos(clamp(dot(off / d, normalize(cone_dirs[i].xy)), -1.0, 1.0)) : 0.0;
		fall *= 1.0 - smoothstep(half_angle * 0.7, half_angle, angle);
		lit = max(lit, fall);
	}
	COLOR = vec4(shade.rgb, darkness * (1.0 - lit));
}
