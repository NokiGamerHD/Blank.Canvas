shader_type canvas_item;

uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform vec4 dissolve_color : source_color = vec4(0.06, 0.06, 0.05, 1.0);
uniform float pixel_size : hint_range(2.0, 24.0) = 6.0;

const float bayer_matrix[16] = float[16](
	0.0, 8.0, 2.0, 10.0,
	12.0, 4.0, 14.0, 6.0,
	3.0, 11.0, 1.0, 9.0,
	15.0, 7.0, 13.0, 5.0
);

void fragment() {
	vec2 block = floor(FRAGCOORD.xy / pixel_size);
	int bx = int(mod(block.x, 4.0));
	int by = int(mod(block.y, 4.0));
	float threshold = (bayer_matrix[bx + by * 4] + 0.5) / 16.0;
	float covered = step(threshold, progress);
	COLOR = vec4(dissolve_color.rgb, covered);
}
