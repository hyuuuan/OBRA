shader_type canvas_item;

varying float shore_y;

void vertex() {
	shore_y = VERTEX.y;
}

void fragment() {
	float px = TEXTURE_PIXEL_SIZE.y;
	float depth = UV.y / px;
	float x = fract(UV.x);
	// Continue the opaque stone below the original cap, sampling at the same
	// height on either side of a bank. Keep the moss in the cap and stop before
	// the hard seam at row 130.
	float stone_y = 61.0 + (1.0 - abs(mod((shore_y - 61.0) / 64.0, 2.0) - 1.0)) * 64.0;
	vec3 stone = texture(TEXTURE, vec2(x, stone_y * px)).rgb;
	float grain = 2.0 * sin(UV.x / TEXTURE_PIXEL_SIZE.x * 0.13);
	vec3 cap = texture(TEXTURE, vec2(x, clamp(depth + grain, 0.0, 70.0) * px)).rgb;
	vec3 shore = mix(stone, cap, 1.0 - smoothstep(42.0, 69.0, depth));
	// The low sand is wet, with a gradual darkening into the deeper rock.
	shore *= mix(vec3(1.0), vec3(0.81, 0.89, 0.9), smoothstep(8.0, 40.0, shore_y));
	shore *= 1.0 - 0.3 * smoothstep(110.0, 440.0, shore_y);
	COLOR = vec4(shore, 1.0);
}
