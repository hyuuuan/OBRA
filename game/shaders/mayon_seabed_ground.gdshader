shader_type canvas_item;

varying float seabed_y;

void vertex() {
	seabed_y = VERTEX.y;
}

void fragment() {
	float px = TEXTURE_PIXEL_SIZE.y;
	float depth = UV.y / px;
	float x = fract(UV.x);
	// Only the shallow crest follows the local curve. The face uses one set
	// of coordinates across both banks and the dip, so its stones line up.
	float face_y = max(28.0, seabed_y + 12.0);
	vec3 face = texture(TEXTURE, vec2(x, min(face_y, 190.0) * px)).rgb;
	// Offset the buried stones and blend before the face runs out. This keeps
	// a mirrored row of stones from showing up at the bottom of the frame.
	float deep_y = 112.0 + (1.0 - abs(mod((face_y - 112.0) / 72.0, 2.0) - 1.0)) * 72.0;
	vec3 deep = texture(TEXTURE, vec2(fract(x + 0.34), deep_y * px)).rgb;
	vec3 sediment = mix(face, deep, smoothstep(138.0, 190.0, face_y));
	sediment *= 1.0 - 0.65 * smoothstep(125.0, 330.0, seabed_y);
	vec4 crest = texture(TEXTURE, vec2(x, min(depth + 8.0, 76.0) * px));
	float cap = 1.0 - smoothstep(24.0, 68.0, depth);
	float alpha = mix(crest.a, 1.0, smoothstep(2.0, 14.0, depth));
	COLOR = vec4(mix(sediment, crest.rgb, cap), alpha);
}
