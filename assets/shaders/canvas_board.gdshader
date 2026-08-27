shader_type canvas_item;

uniform float tile_count : hint_range(1.0, 256.0) = 42.0;
uniform vec4 border_color : source_color = vec4(0.2, 0.2, 0.2, 1.0);
uniform float border_thickness : hint_range(0.0, 0.05) = 0.006;
uniform vec4 inner_shadow_color : source_color = vec4(0.0, 0.0, 0.0, 0.06);
uniform float inner_shadow_reach : hint_range(0.0, 0.1) = 0.03;

void fragment() {
	vec2 tiled_uv = fract(UV * tile_count);
	vec4 grain = texture(TEXTURE, tiled_uv);

	vec2 edge_dist = min(UV, vec2(1.0) - UV);
	float min_edge = min(edge_dist.x, edge_dist.y);

	float shadow_mix = 1.0 - smoothstep(0.0, inner_shadow_reach, min_edge);
	vec3 color = mix(grain.rgb, inner_shadow_color.rgb, shadow_mix * inner_shadow_color.a);

	float border_mix = 1.0 - smoothstep(0.0, border_thickness, min_edge);
	color = mix(color, border_color.rgb, border_mix);

	COLOR = vec4(color, grain.a);
}
