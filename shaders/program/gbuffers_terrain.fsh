#extension GL_ARB_gpu_shader5 : enable

#if defined PARALLAX_ENABLED && defined PARALLAX_DEPTH_WRITE
    #extension GL_ARB_conservative_depth : enable
#endif

#define RENDER_FRAG
#define RENDER_GBUFFER
#define RENDER_TERRAIN

#include "/lib/constants.glsl"
#include "/lib/common.glsl"

#if defined PARALLAX_ENABLED && defined PARALLAX_DEPTH_WRITE
    layout (depth_greater) out float gl_FragDepth;
#endif

in vec2 lmcoord;
in vec2 texcoord;
in vec4 glcolor;
in float geoNoL;
in vec3 viewPos;
in vec3 viewNormal;
in vec3 viewTangent;
flat in float tangentW;
flat in mat2 atlasBounds;

#if MATERIAL_FORMAT == MATERIAL_FORMAT_DEFAULT
    flat in float matSmooth;
    flat in float matF0;
    flat in float matSSS;
    flat in float matEmissive;
#endif

#ifdef PARALLAX_ENABLED
    in vec2 localCoord;
    in vec3 tanViewPos;

    uniform mat4 gbufferProjection;

    #if defined SKY_ENABLED && defined SHADOW_ENABLED
        in vec3 tanLightPos;
    #endif
#endif

#ifdef SKY_ENABLED
    uniform vec3 upPosition;
    uniform float wetness;
#endif

#ifdef AF_ENABLED
    in vec4 spriteBounds;

    uniform float viewHeight;
#endif

uniform sampler2D gtexture;
uniform sampler2D normals;
uniform sampler2D specular;
uniform sampler2D lightmap;

uniform ivec2 atlasSize;

#if MC_VERSION >= 11700 && defined IS_OPTIFINE
    uniform float alphaTestRef;
#endif

#ifdef AF_ENABLED
    #include "/lib/sampling/anisotropic.glsl"
#endif

#include "/lib/atlas.glsl"
#include "/lib/sampling/linear.glsl"

#ifdef SKY_ENABLED
    #include "/lib/world/porosity.glsl"
#endif

#ifdef PARALLAX_ENABLED
    #include "/lib/parallax.glsl"
#endif

#if DIRECTIONAL_LIGHTMAP_STRENGTH > 0
    #include "/lib/lighting/directional.glsl"
#endif

#include "/lib/material/material_reader.glsl"
#include "/lib/lighting/basic_gbuffers.glsl"
#include "/lib/lighting/pbr_gbuffers.glsl"

/* RENDERTARGETS: 2,3 */
out uvec4 outColor0;
#if defined SHADOW_ENABLED && defined SHADOW_COLOR
    out vec3 outColor1;
#endif


void main() {
    vec3 shadowColorMap;
    vec4 colorMap, normalMap, specularMap, lightingMap;
    PbrLighting(colorMap, normalMap, specularMap, lightingMap, shadowColorMap);

    uvec4 data;
    data.r = packUnorm4x8(colorMap);
    data.g = packUnorm4x8(normalMap);
    data.b = packUnorm4x8(specularMap);
    data.a = packUnorm4x8(lightingMap);
    outColor0 = data;

    #if defined SHADOW_ENABLED && defined SHADOW_COLOR
        outColor1 = shadowColorMap;
    #endif
}
