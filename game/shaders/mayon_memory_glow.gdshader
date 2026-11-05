shader_type canvas_item;
render_mode unshaded;

uniform sampler2D landmark_alpha : filter_nearest, repeat_disable;
uniform vec2 padding_uv;

float silhouette(vec2 uv) {
	vec2 inside = step(vec2(0.0), uv) * step(uv, vec2(1.0));
	return texture(landmark_alpha, uv).a * inside.x * inside.y;
}

float nearby_alpha(vec2 uv, vec2 radius) {
	vec2 diagonal = radius * 0.707107;
	float horizontal = max(silhouette(uv + vec2(radius.x, 0.0)),
		silhouette(uv - vec2(radius.x, 0.0)));
	float vertical = max(silhouette(uv + vec2(0.0, radius.y)),
		silhouette(uv - vec2(0.0, radius.y)));
	float ascending = max(silhouette(uv + diagonal), silhouette(uv - diagonal));
	vec2 descending = diagonal * vec2(1.0, -1.0);
	float opposite = max(silhouette(uv + descending), silhouette(uv - descending));
	return max(max(horizontal, vertical), max(ascending, opposite));
}

void fragment() {
	// Undo the quad's padding so the alpha samples align with the original sprite.
	vec2 uv = UV * (vec2(1.0) + 2.0 * padding_uv) - padding_uv;
	float outside = 1.0 - smoothstep(0.02, 0.3, silhouette(uv));
	float edge = nearby_alpha(uv, padding_uv * 0.34);
	float middle = nearby_alpha(uv, padding_uv * 0.67);
	float outer = nearby_alpha(uv, padding_uv);
	float halo = max(max(edge * 0.98, middle * 0.38), outer * 0.15);
	vec3 yellow = mix(vec3(1.0, 0.70, 0.08), vec3(1.0, 0.94, 0.40), edge);
	COLOR = vec4(yellow, halo * outside);
}
