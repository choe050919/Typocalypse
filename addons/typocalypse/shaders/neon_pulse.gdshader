shader_type canvas_item;

uniform float pulse_strength : hint_range(0.0, 5.0) = 0.0;
uniform vec3 accent_color : source_color = vec3(0.6, 0.9, 1.2);

void fragment() {
    vec4 base_color = texture(TEXTURE, UV);
    float glow = pulse_strength * 0.4;
    vec3 color = base_color.rgb + accent_color * glow;
    COLOR = vec4(color, base_color.a);
}
