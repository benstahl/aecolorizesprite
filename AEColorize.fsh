#ifdef GL_ES
precision lowp float;
#endif

/* ========================================================================== */
vec4 DesaturatePerceptual(vec3 color, float Desaturation)
{
	vec3 grayXfer = vec3(0.3, 0.59, 0.11);
	vec3 gray = vec3(dot(grayXfer, color));
	return vec4(mix(color, gray, Desaturation), 1.0);
}

/* ========================================================================== */
vec3 RGBToHSL(vec3 color)
{
	vec3 hsl; // init to 0 to avoid warnings ? (and reverse if + remove first part)

	float fmin = min(min(color.r, color.g), color.b);	// Min. value of RGB
	float fmax = max(max(color.r, color.g), color.b);	// Max. value of RGB
	float delta = fmax - fmin;			 				// Delta RGB value

	hsl.z = (fmax + fmin) / 2.0;						// Luminance

	if (delta == 0.0) {	//This is a gray, no chroma...
		hsl.x = 0.0;	// Hue
		hsl.y = 0.0;	// Saturation
	} else {			// Chroma...
		if (hsl.z < 0.5)
			hsl.y = delta / (fmax + fmin); // Saturation
		else
			hsl.y = delta / (2.0 - fmax - fmin); // Saturation

		float deltaR = (((fmax - color.r) / 6.0) + (delta / 2.0)) / delta;
		float deltaG = (((fmax - color.g) / 6.0) + (delta / 2.0)) / delta;
		float deltaB = (((fmax - color.b) / 6.0) + (delta / 2.0)) / delta;

		if (color.r == fmax )
			hsl.x = deltaB - deltaG; // Hue
		else if (color.g == fmax)
			hsl.x = (1.0 / 3.0) + deltaR - deltaB; // Hue
		else if (color.b == fmax)
			hsl.x = (2.0 / 3.0) + deltaG - deltaR; // Hue

		if (hsl.x < 0.0)
			hsl.x += 1.0; // Hue
		else if (hsl.x > 1.0)
			hsl.x -= 1.0; // Hue
	}

	return hsl;
}

/* ========================================================================== */
vec3 HSLToRGB(vec3 hsl) {
	vec3 rgb;

	if (hsl.y == 0.0)
		rgb = vec3(hsl.z);
	else {
		float f2;

		if (hsl.z < 0.5)
			f2 = hsl.z * (1.0 + hsl.y);
		else
			f2 = (hsl.z + hsl.y) - (hsl.y * hsl.z);

		float f1 = 2.0 * hsl.z - f2;

		rgb.r = HueToRGB(f1, f2, hsl.x + (1.0/3.0));
		rgb.g = HueToRGB(f1, f2, hsl.x);
		rgb.b = HueToRGB(f1, f2, hsl.x - (1.0/3.0));
	}

	return rgb;
}

/* ==========================================================================
 Colorize a fragment with a given h, s, and b adjustments. Hue should be in
 the range 0..1, Sat 0..1, Brt -1.0..1.0 (0.0 = keep original brightness).
 ========================================================================= */
vec3 Colorize(vec3 srcColHSL, float hue, float sat, float brt) {
	if (hue < 0.0)
		hue += 1.0;
	else if (hue > 1.0)
		hue -= 1.0;

	float brtDelta = 0.0;
	if (brt < 0.0) {
		brtDelta = srcColHSL.z * brt;
	} else {
		brtDelta = (1.0 - srcColHSL.z) * brt;
	}

	vec3 colorized = vec3(hue, sat, srcColHSL.z + brtDelta);
	return colorized;
}

varying vec2 v_texCoord;
uniform sampler2D u_texture;
uniform float u_opacity;
uniform float u_tintHue;
uniform float u_tintSat;
uniform float u_tintBrt;
uniform bool u_usePerceptualDesaturation;

/* ========================================================================== */
void main() {
	vec4 textureColor = texture2D(u_texture, v_texCoord);
	vec3 hsl;

	if (u_usePerceptualDesaturation) {
		hsl = RGBToHSL(DesaturatePerceptual(textureColor.rgb, 1.0).rgb);
	} else {
		hsl = RGBToHSL(textureColor.rgb);
	}
	vec3 colorized = Colorize(hsl, u_tintHue, u_tintSat, u_tintBrt);

	vec4 result = vec4(HSLToRGB(colorized), textureColor.a * u_opacity);

	gl_FragColor = result;
}