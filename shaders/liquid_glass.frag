#version 460 core
#include <flutter/runtime_effect.glsl>

// Diese zwei setzt die Engine selbst (Float 0 und 1 + Sampler 0).
uniform vec2 u_size;
uniform sampler2D u_texture;

// Ab Float-Index 2 kommen unsere eigenen Werte – die Reihenfolge ist
// maßgeblich und muss zu `_setUniforms` in LiquidGlass.dart passen.
uniform float u_radius;      // 2  Eckenradius in px
uniform float u_bezel;       // 3  Breite des gebogenen Rands in px
uniform float u_refraction;  // 4  Stärke der Brechung in px
uniform float u_blur;        // 5  Unschärfe-Radius in px
uniform float u_dispersion;  // 6  Farbsaum in px
uniform float u_highlight;   // 7  Stärke der Lichtkante (0..1)
uniform vec4 u_tint;         // 8-11  Tönung (RGB + Alpha, nicht premultipliziert)

out vec4 fragColor;

// Abstand zu einem abgerundeten Rechteck (negativ = innen).
float sdRoundRect(vec2 p, vec2 halfSize, float r) {
  vec2 q = abs(p) - halfSize + vec2(r);
  return min(max(q.x, q.y), 0.0) + length(max(q, vec2(0.0))) - r;
}

vec2 toUv(vec2 px) {
  vec2 uv = px / u_size;
#ifdef IMPELLER_TARGET_OPENGLES
  uv.y = 1.0 - uv.y;
#endif
  return uv;
}

// 12 Proben auf einer Spirale (goldener Winkel) = weicher, runder Blur.
vec3 blurAt(vec2 px) {
  if (u_blur < 0.5) {
    return texture(u_texture, toUv(px)).rgb;
  }
  vec3 sum = vec3(0.0);
  for (int i = 0; i < 12; i++) {
    float a = float(i) * 2.39996323;
    float r = sqrt((float(i) + 0.5) / 12.0) * u_blur;
    sum += texture(u_texture, toUv(px + vec2(cos(a), sin(a)) * r)).rgb;
  }
  return sum / 12.0;
}

void main() {
  vec2 frag = FlutterFragCoord().xy;
  vec2 halfSize = u_size * 0.5;
  vec2 p = frag - halfSize;
  float r = min(u_radius, min(halfSize.x, halfSize.y));

  float sd = sdRoundRect(p, halfSize, r);
  vec4 raw = texture(u_texture, toUv(frag));

  // Außerhalb der Form (Ecken) bleibt das Bild unverändert; der ClipRRect
  // schneidet es ohnehin ab.
  if (sd > 1.0) {
    fragColor = raw;
    return;
  }

  float depth = max(-sd, 0.0);                       // Abstand zum Rand, innen
  float t = clamp(1.0 - depth / u_bezel, 0.0, 1.0);  // 1 am Rand, 0 im Inneren
  float bend = 1.0 - sqrt(max(1.0 - t * t, 0.0));    // steiles Linsenprofil

  // Normale nach außen (Gradient der Distanzfunktion).
  float e = 1.0;
  vec2 n = vec2(
    sdRoundRect(p + vec2(e, 0.0), halfSize, r) - sdRoundRect(p - vec2(e, 0.0), halfSize, r),
    sdRoundRect(p + vec2(0.0, e), halfSize, r) - sdRoundRect(p - vec2(0.0, e), halfSize, r)
  );
  n = normalize(n + vec2(1e-5));

  // Brechung: am Rand wird der Hintergrund von weiter INNEN geholt.
  float shift = u_refraction * bend;
  float disp = u_dispersion * bend;
  vec2 pR = frag - n * (shift + disp);
  vec2 pG = frag - n * shift;
  vec2 pB = frag - n * (shift - disp);

  vec3 col = vec3(blurAt(pR).r, blurAt(pG).g, blurAt(pB).b);

  // Etwas mehr Sättigung, wie bei Apples Glas.
  float luma = dot(col, vec3(0.299, 0.587, 0.114));
  col = mix(vec3(luma), col, 1.18);

  // Tönung.
  col = mix(col, u_tint.rgb, u_tint.a);

  // Lichtkante: Licht von links oben, schwächere Gegenseite unten rechts.
  vec2 L = normalize(vec2(-0.55, -0.85));
  float lit = pow(max(dot(n, L), 0.0), 1.5);
  float back = pow(max(dot(n, -L), 0.0), 1.5);
  float spec = lit + 0.55 * back;

  float edgeLine = 1.0 - smoothstep(0.0, 1.8, depth);  // feine Linie am Rand
  float rimGlow = pow(t, 3.0);                          // weicher Schein nach innen
  float sheen = 1.0 - smoothstep(0.0, u_size.y * 0.55, frag.y); // oben heller

  col += vec3(1.0) * u_highlight *
         (edgeLine * (0.22 + 0.78 * spec) + rimGlow * spec * 0.35 + sheen * 0.05);

  float inside = 1.0 - smoothstep(-0.5, 0.5, sd);
  fragColor = vec4(mix(raw.rgb, clamp(col, 0.0, 1.0), inside), 1.0);
}