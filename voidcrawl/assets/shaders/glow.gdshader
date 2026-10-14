shader_type spatial;
render_mode unshaded, cull_back;
// Self-lit blocks (crystals, flames, runes). Colour comes from the instance; energy brightens it.
uniform float energy = 1.4;
void fragment() {
	ALBEDO = COLOR.rgb * energy;
}
