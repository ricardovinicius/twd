shader_type spatial;
render_mode world_vertex_coords, specular_disabled, vertex_lighting;

uniform sampler2D textura_albedo : source_color;

global uniform vec2 resolution; 
uniform sampler2D color_texture: source_color, filter_nearest;
uniform float vertex_wobble: hint_range(0.0, 1.0, 0.01) = 1.0;
uniform float affine_mapping: hint_range(0.0, 1.0, 0.01) = 1.0;
varying vec2 original_uv;

void vertex() {
	vec4 position = PROJECTION_MATRIX * VIEW_MATRIX * vec4(VERTEX, 1.0);
	vec2 snapping = resolution * vertex_wobble;
	vec2 screen_position = round(position.xy * snapping) / snapping;
	POSITION = vec4(screen_position, position.zw);
	
}

void fragment() {
	ALBEDO = texture(textura_albedo, UV).rgb; 
}

//void light() {
//	// Called for every pixel for every light affecting the material.
//	// Uncomment to replace the default light processing function with this one.
//}
