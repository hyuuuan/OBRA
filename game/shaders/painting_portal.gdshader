shader_type canvas_item;
render_mode unshaded;

// Copied before the hall is drawn. UV belongs to the growing painting, so the live
// level starts inside that painting and shares its size and position throughout.
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform sampler2D scene_snapshot : source_color, repeat_disable, filter_linear;
uniform bool returning = false;

void fragment() {
	vec3 scene = returning ? texture(scene_snapshot, UV).rgb : texture(screen_texture, UV).rgb;
	COLOR = vec4(scene, COLOR.a);
}
