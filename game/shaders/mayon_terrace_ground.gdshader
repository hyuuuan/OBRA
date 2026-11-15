shader_type canvas_item;

varying float world_y;
varying vec2 join_distance;

void vertex() {
	world_y = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).y;
	join_distance = COLOR.rg;
}

void fragment() {
	float px = TEXTURE_PIXEL_SIZE.y;
	float depth = UV.y / px;
	float x = fract(UV.x);
	// A small irregularity in the turf breaks up long straight stripes across the caps.
	float world_x = UV.x / TEXTURE_PIXEL_SIZE.x;
	float grass_y = depth + 2.0 * sin(world_x * 0.12) + 1.4 * sin(world_x * 0.37);
	vec4 grass = texture(TEXTURE, vec2(x, clamp(grass_y, 0.0, 54.0) * px));
	// Mirror an opaque stretch of stone. Every step samples the same wall at a given
	// world height, so the stones continue across the joins and under the grass.
	float stone_y = 56.0 + (1.0 - abs(mod(world_y / 112.0, 2.0) - 1.0)) * 112.0;
	vec4 stone = texture(TEXTURE, vec2(x, stone_y * px));
	// Let the lower tread blend into the same stone as the riser beside it.
	float join = smoothstep(0.0, 36.0 / 2048.0, min(join_distance.x, join_distance.y));
	float turf = (1.0 - smoothstep(32.0, 54.0, grass_y)) * join;
	vec4 ground = mix(stone, grass, turf);
	ground.a = mix(grass.a * step(0.0, grass_y), stone.a, smoothstep(8.0, 16.0, depth));
	ground.rgb *= 1.0 - 0.32 * smoothstep(140.0, 580.0, world_y);
	COLOR = ground;
}
