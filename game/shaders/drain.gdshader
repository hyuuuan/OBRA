shader_type canvas_item;

// MAYON'S ASH: what it settles on goes white, then blank (Level 5 design).
//
// `drain` is how far the ash has taken it. 0 is the painting as painted. By 0.5 the colour is
// gone and what is left is lifted almost to the paper -- a ghost of the shading, so a pale tree
// still reads as a tree. By 0.85 it is flat paper, the shape only an edge. At 1 it is blank:
// not there at all, and Drainable takes its collision with it.
//
// A shader and not `modulate`: modulate multiplies, and nothing multiplied gets lighter than it
// was (AGENTS.md). White has to be painted in.
uniform float drain : hint_range(0.0, 1.0) = 0.0;
// The unpainted canvas, the colour every drained thing goes to.
uniform vec4 paper : source_color = vec4(0.957, 0.937, 0.894, 1.0);
// How much of that whitening a drained thing takes. 1 is Mayon's ash, all of it. Another level's
// old way (LevelBase._fades_the_old_way) takes little, so it dissolves in its own colours rather
// than going white -- a flat white slab is the ash's look, and no other painting has the ash.
uniform float wash : hint_range(0.0, 1.0) = 1.0;
// Where it starts to go, at all. Mayon's holds whole until it is flat paper (0.85).
uniform float vanish_from : hint_range(0.0, 1.0) = 0.85;

void fragment() {
	// ⚠ COLOR, as it is. In Godot 4 a canvas shader's COLOR already carries the texture, and
	// sampling TEXTURE again squared every colour: everything wearing this drew darker than it
	// was painted (0.42 came out 0.17) from the start, before any ash. run_drain_probe holds it.
	vec4 colour = COLOR;
	float luminance = dot(colour.rgb, vec3(0.2126, 0.7152, 0.0722));
	float pale = smoothstep(0.0, 0.5, drain);
	// Grey first, then lifted toward the paper, together, so it never passes through a dark grey.
	vec3 ghost = mix(vec3(luminance), paper.rgb, 0.82);
	vec3 rgb = mix(colour.rgb, mix(vec3(luminance), ghost, pale), pale);
	rgb = mix(rgb, paper.rgb, smoothstep(0.5, 0.85, drain));
	colour.rgb = mix(colour.rgb, rgb, wash);
	colour.a *= 1.0 - smoothstep(vanish_from, 1.0, drain);
	COLOR = colour;
}
