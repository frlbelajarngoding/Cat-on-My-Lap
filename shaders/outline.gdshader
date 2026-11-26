shader_type canvas_item;
// Outline putih di sekeliling sprite (cocok untuk pixel art).
// Sprite diperbesar sedikit (padding) supaya outline tidak terpotong tepi gambar.

uniform vec4 outline_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float width : hint_range(0.0, 8.0) = 1.0;   // tebal outline, dalam piksel TEKSTUR
uniform float pulse_speed = 6.0;                     // 0 = tidak berkedip

varying vec2 v_uv;
varying vec4 v_mod;

void vertex() {
	float pad = ceil(width) + 1.0;
	vec2 e = (UV * 2.0 - 1.0) * pad;   // geser sudut kotak ke luar
	VERTEX += e;
	v_uv = UV + e * TEXTURE_PIXEL_SIZE;
	v_mod = COLOR;                     // modulate sprite (alpha toggle, dll)
}

float alpha_at(vec2 uv) {
	if (uv.x < 0.0 || uv.y < 0.0 || uv.x > 1.0 || uv.y > 1.0) {
		return 0.0;
	}
	return texture(TEXTURE, uv).a;
}

void fragment() {
	vec4 tex = vec4(0.0);
	if (v_uv.x >= 0.0 && v_uv.y >= 0.0 && v_uv.x <= 1.0 && v_uv.y <= 1.0) {
		tex = texture(TEXTURE, v_uv);
	}
	vec2 px = TEXTURE_PIXEL_SIZE * width;
	float a = 0.0;
	a = max(a, alpha_at(v_uv + vec2( px.x, 0.0)));
	a = max(a, alpha_at(v_uv + vec2(-px.x, 0.0)));
	a = max(a, alpha_at(v_uv + vec2(0.0,  px.y)));
	a = max(a, alpha_at(v_uv + vec2(0.0, -px.y)));
	a = max(a, alpha_at(v_uv + vec2( px.x,  px.y)));
	a = max(a, alpha_at(v_uv + vec2(-px.x,  px.y)));
	a = max(a, alpha_at(v_uv + vec2( px.x, -px.y)));
	a = max(a, alpha_at(v_uv + vec2(-px.x, -px.y)));

	float blink = 1.0;
	if (pulse_speed > 0.0) {
		blink = 0.65 + 0.35 * sin(TIME * pulse_speed);
	}
	vec4 outline = vec4(outline_color.rgb, outline_color.a * a * blink);
	vec4 body = tex * v_mod;
	COLOR = mix(outline, body, tex.a);
}
