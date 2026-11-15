shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform sampler2D hall_scene : source_color, repeat_disable, filter_nearest;
uniform sampler2D scene_snapshot : source_color, repeat_disable, filter_linear;
uniform bool active = false;
uniform bool returning = false;
uniform vec2 painting_center = vec2(0.5);
uniform vec2 painting_half_size = vec2(0.1);
uniform float hall_zoom = 1.0;
uniform float camera_travel = 0.0;
uniform float aperture_reveal = 0.0;
uniform float level_scale = 1.0;
uniform vec2 level_center = vec2(0.5);

void fragment() {
	if (!active) {
		COLOR = texture(screen_texture, SCREEN_UV);
	} else {
		// One camera transform for the WHOLE hall: moulding, wall, neighbours and player.
		vec2 frame_center = mix(painting_center, vec2(0.5), camera_travel);
		vec2 hall_uv = painting_center + (SCREEN_UV - frame_center) / hall_zoom;
		vec3 hall = texture(hall_scene, hall_uv).rgb;
		// Only the inside of the selected frame opens. The gilt belongs to the hall.
		vec2 edge = SCREEN_PIXEL_SIZE / hall_zoom;
		vec2 aperture = vec2(1.0) - smoothstep(painting_half_size - edge,
			painting_half_size + edge, abs(hall_uv - painting_center));
		float opening = aperture.x * aperture.y * aperture_reveal;
		// The farther plane has its own magnification and pan, independent of the mask.
		vec2 level_uv = (SCREEN_UV - level_center) / level_scale + vec2(0.5);
		vec3 world = returning ? texture(scene_snapshot, level_uv).rgb
			: texture(screen_texture, level_uv).rgb;
		COLOR = vec4(mix(hall, world, opening), 1.0);
	}
}
