shader_type canvas_item;
void fragment() {
	vec4 col = texture(TEXTURE, UV);
	float diagonal = UV.x + UV.y;
	float sweep = pow(max(0.0, sin(diagonal * 3.14159 - TIME * 2.0)), 16.0);
	float mask = col.a;
	col.rgb += vec3(sweep * 0.8 * mask);
	COLOR = col;
}
