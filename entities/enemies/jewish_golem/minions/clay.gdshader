shader_type canvas_item;

// Turns any sprite into baked clay: its shading is kept, its colours are
// replaced by a ramp from dark to light clay. Used by the golem's minions.

uniform vec4 dark_clay : source_color = vec4(0.30, 0.19, 0.13, 1.0);
uniform vec4 light_clay : source_color = vec4(0.86, 0.66, 0.45, 1.0);

void fragment() {
	float shade = dot(COLOR.rgb, vec3(0.299, 0.587, 0.114));
	COLOR.rgb = mix(dark_clay.rgb, light_clay.rgb, shade);
}
