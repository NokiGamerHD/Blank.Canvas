shader_type canvas_item;

uniform float hue_shift_speed : hint_range(0.0, 0.5) = 0.05;
uniform float hue_shift_amount : hint_range(0.0, 0.5) = 0.15;

vec3 rgb_to_hsv(vec3 c) {
	vec4 k = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = mix(vec4(c.bg, k.wz), vec4(c.gb, k.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
	float d = q.x - min(q.w, q.y);
	float e = 1.0e-10;
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

vec3 hsv_to_rgb(vec3 c) {
	vec4 k = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
	vec3 p = abs(fract(c.xxx + k.xyz) * 6.0 - k.www);
	return c.z * mix(k.xxx, clamp(p - k.xxx, 0.0, 1.0), c.y);
}

void fragment() {
	vec4 tex_color = texture(TEXTURE, UV);
	vec3 hsv = rgb_to_hsv(tex_color.rgb);
	float shift = sin(TIME * hue_shift_speed * 6.283185) * hue_shift_amount;
	hsv.x = fract(hsv.x + shift);
	COLOR = vec4(hsv_to_rgb(hsv), tex_color.a);
}
