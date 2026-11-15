shader_type canvas_item;
render_mode unshaded;

uniform float lava_clock = 0.0;
varying vec2 lava_uv;

void vertex() {
	// A textureless Polygon2D supplies no useful texture UVs. Anchor the fluid to its geometry.
	lava_uv=vec2((VERTEX.x+190.0)/380.0,(VERTEX.y-65.0)/475.0);
}

vec2 cell_point(vec2 p) {
	return fract(sin(vec2(dot(p,vec2(127.1,311.7)),dot(p,vec2(269.5,183.3))))*43758.5453);
}

void fragment() {
	vec2 pixel = floor(lava_uv*vec2(78.0,100.0))/vec2(78.0,100.0);
	vec2 p = pixel*vec2(6.0,11.0)+vec2(lava_clock*0.08,-lava_clock*0.16);
	vec2 base = floor(p);
	vec2 local = fract(p);
	float first = 9.0;
	float second = 9.0;
	for (int y=-1;y<=1;y++) {
		for (int x=-1;x<=1;x++) {
			vec2 neighbour=vec2(float(x),float(y));
			vec2 point=cell_point(base+neighbour);
			float distance=length(neighbour+point-local);
			if (distance<first) { second=first; first=distance; }
			else { second=min(second,distance); }
		}
	}
	float molten=smoothstep(0.015,0.19,second-first);
	float pulse=0.5+0.5*sin(lava_clock*1.2+pixel.x*8.0+pixel.y*4.0);
	vec3 glow=mix(vec3(0.96,0.25,0.045),vec3(1.0,0.79,0.24),molten);
	vec3 colour=mix(vec3(0.24,0.065,0.055),glow,smoothstep(0.0,0.045,second-first));
	COLOR=vec4(colour*(0.88+0.12*pulse),1.0);
}
