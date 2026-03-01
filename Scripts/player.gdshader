 shader_type canvas_item;

uniform bool invert_colors = true;

void fragment() {
    vec4 color = texture(TEXTURE, UV);

    if (invert_colors) {
        COLOR = vec4(1.0 - color.rgb, color.a);
    } else {
        COLOR = color;
    }
}