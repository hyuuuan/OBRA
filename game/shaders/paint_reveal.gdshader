shader_type canvas_item;
// LOLA'S CANVAS, BEING PAINTED. Where the paint has reached, the painting; everywhere else, its
// underdrawing: a faint warm ghost of it on the bare canvas. It goes on in strokes, a block at a
// time (the art's pixel idiom, not a smooth wipe): row by row from the sky down, each row swept
// left to right with a ragged leading edge. Scattered blocks read as static, not as a brush.
// Lola2D raises `reveal` each time her brush reaches the canvas.

uniform float reveal : hint_range(0.0, 1.0) = 0.0;
uniform vec2 blocks = vec2(32.0, 10.0);
uniform vec4 paper : source_color = vec4(0.957, 0.937, 0.894, 1.0);
uniform vec4 sketch_ink : source_color = vec4(0.42, 0.33, 0.24, 1.0);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	// Godot 4 hands fragment() the texture already multiplied into COLOR: read it, never sample again.
	vec4 painted = COLOR;
	vec2 cell = floor(UV * blocks);
	float along = clamp((cell.x + (hash(cell) - 0.5) * 2.5) / blocks.x, 0.0, 0.999);
	float turn = (cell.y + along) / blocks.y;
	float luma = dot(painted.rgb, vec3(0.299, 0.587, 0.114));
	vec3 underdrawing = mix(paper.rgb, sketch_ink.rgb, (1.0 - luma) * 0.32);
	vec3 shown = turn < reveal ? painted.rgb : underdrawing;
	// The newest strokes are still wet: a touch of sheen on the last blocks she laid.
	if (turn < reveal && turn > reveal - 0.03) {
		shown = mix(shown, vec3(1.0), 0.14);
	}
	COLOR = vec4(shown, painted.a);
}
