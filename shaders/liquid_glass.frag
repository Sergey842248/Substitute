#version 460 core
#include <flutter/runtime_effect.glsl>

// ImageFilter.shader supplies the filtered image and its dimensions.
uniform vec2 u_size;
uniform sampler2D u_texture;

// Keep these indices in sync with _setUniforms in lib/models/LiquidGlass.dart.
uniform float u_radius;      // 2: rounded-rectangle radius in px
uniform float u_bezel;       // 3: curved glass edge width in px
uniform float u_refraction;  // 4: inward lens displacement in px
uniform float u_blur;        // 5: backdrop blur radius in px
uniform float u_dispersion;  // 6: chromatic edge separation in px
uniform float u_highlight;   // 7: reflection intensity
uniform vec4 u_tint;         // 8-11: glass tint (linear RGBA)

out vec4 fragColor;

float sdRoundRect(vec2 p, vec2 halfSize, float radius) {
  vec2 q = abs(p) - halfSize + vec2(radius);
  return min(max(q.x, q.y), 0.0) + length(max(q, vec2(0.0))) - radius;
}

vec2 toUv(vec2 px) {
  vec2 uv = px / u_size;
#ifdef IMPELLER_TARGET_OPENGLES
  // Impeller's GLES texture origin is opposite to FlutterFragCoord's origin.
  uv.y = 1.0 - uv.y;
#endif
  return uv;
}

vec3 sampleBackdrop(vec2 px) {
  return texture(u_texture, toUv(px)).rgb;
}

// A small, symmetric, center-weighted blur keeps the surface legible while
// allowing the existing strength control to soften the scene behind the lens.
vec3 blurBackdrop(vec2 px) {
  if (u_blur < 0.5) {
    return sampleBackdrop(px);
  }

  vec2 dx = vec2(u_blur, 0.0);
  vec2 dy = vec2(0.0, u_blur);
  return sampleBackdrop(px) * 0.40
       + (sampleBackdrop(px + dx) + sampleBackdrop(px - dx)
       +  sampleBackdrop(px + dy) + sampleBackdrop(px - dy)) * 0.15;
}

vec2 roundedRectNormal(vec2 p, vec2 halfSize, float radius) {
  vec2 q = abs(p) - halfSize + vec2(radius);
  vec2 outside = max(q, vec2(0.0));
  vec2 normal;

  if (outside.x > 0.0 || outside.y > 0.0) {
    normal = normalize(outside) * sign(p);
  } else {
    // On a flat edge the SDF gradient is the normal of the nearest side.
    float horizontal = step(q.y, q.x);
    normal = vec2(horizontal, 1.0 - horizontal) * sign(p);
  }

  return normalize(normal + vec2(1e-5));
}

void main() {
  vec2 frag = FlutterFragCoord().xy;
  vec2 halfSize = u_size * 0.5;
  vec2 centered = frag - halfSize;
  float radius = clamp(u_radius, 0.0, min(halfSize.x, halfSize.y));
  float sd = sdRoundRect(centered, halfSize, radius);
  vec4 raw = texture(u_texture, toUv(frag));

  // ClipRRect performs the final shape clip; avoid unnecessary work in corners.
  if (sd > 1.0) {
    fragColor = raw;
    return;
  }

  float depth = max(-sd, 0.0);
  float bevelWidth = max(u_bezel, 0.01);
  float edge = clamp(1.0 - depth / bevelWidth, 0.0, 1.0);

  // A circular lens profile like RPhone's lens(): the backdrop is sampled
  // further toward the center at the curved glass boundary.
  float lensProfile = 1.0 - sqrt(max(1.0 - edge * edge, 0.0));
  vec2 normal = roundedRectNormal(centered, halfSize, radius);
  vec2 refracted = frag - normal * (max(u_refraction, 0.0) * lensProfile);
  float dispersion = max(u_dispersion, 0.0) * lensProfile;

  // Sample the background through the lens and split red/blue at the bevel.
  // The small separation is strongest at the curved perimeter, not in the face.
  vec3 base = blurBackdrop(refracted);
  vec3 color = base;
  if (dispersion > 0.05) {
    float red = blurBackdrop(refracted - normal * dispersion).r;
    float blue = blurBackdrop(refracted + normal * dispersion).b;
    color = vec3(red, base.g, blue);
  }

  float luminance = dot(color, vec3(0.2126, 0.7152, 0.0722));
  color = mix(vec3(luminance), color, 1.10);
  color = mix(color, u_tint.rgb, clamp(u_tint.a, 0.0, 0.75));

  // Fresnel-like edge reflection with a broad soft lobe and a narrow specular
  // streak. This remains visible even when the content behind the bar is flat.
  vec2 lightDirection = normalize(vec2(-0.48, -0.88));
  float facingLight = max(dot(normal, lightDirection), 0.0);
  float broadReflection = pow(facingLight, 4.0);
  float sharpReflection = pow(facingLight, 24.0);
  float oppositeReflection = pow(max(dot(normal, -lightDirection), 0.0), 10.0);
  float fresnel = pow(edge, 1.65);
  float edgeLine = exp(-depth / 1.25);

  float xPosition = centered.x / max(halfSize.x, 1.0);
  float topStreak = exp(-pow((centered.y + halfSize.y * 0.70) /
                             max(bevelWidth * 0.42, 1.0), 2.0))
      * smoothstep(-0.98, -0.66, xPosition)
      * (1.0 - smoothstep(0.22, 0.78, xPosition));
  float lowerReflection = exp(-pow((centered.y - halfSize.y * 0.76) /
                                   max(bevelWidth * 0.55, 1.0), 2.0))
      * smoothstep(-0.72, -0.10, xPosition)
      * (1.0 - smoothstep(0.45, 0.92, xPosition));

  vec3 coolReflection = vec3(0.72, 0.88, 1.0);
  vec3 warmReflection = vec3(1.0, 0.91, 0.78);
  vec3 reflectedLight = vec3(1.0) * (
      edgeLine * (0.16 + 0.38 * broadReflection + 0.68 * sharpReflection)
      + fresnel * (0.08 + 0.18 * broadReflection + 0.14 * oppositeReflection))
      + coolReflection * (topStreak * 0.28 + edgeLine * oppositeReflection * 0.10)
      + warmReflection * lowerReflection * 0.12;

  // Slightly darken the underside of the bevel to give the lens real depth.
  float lowerEdge = pow(max(normal.y, 0.0), 3.0) * edgeLine;
  color *= 1.0 - 0.10 * lowerEdge;
  color += reflectedLight * max(u_highlight, 0.0);

  float coverage = 1.0 - smoothstep(-0.55, 0.55, sd);
  fragColor = vec4(mix(raw.rgb, clamp(color, 0.0, 1.0), coverage), raw.a);
}
