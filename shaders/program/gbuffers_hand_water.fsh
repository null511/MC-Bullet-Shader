#extension GL_ARB_texture_query_levels : enable
#extension GL_ARB_gpu_shader5 : enable

#define RENDER_FRAG
#define RENDER_GBUFFER
#define RENDER_HAND_WATER

#include "/lib/constants.glsl"
#include "/lib/common.glsl"

in vec2 lmcoord;
in vec2 texcoord;
in vec4 glcolor;
in float geoNoL;
in vec3 viewPos;
in vec3 viewNormal;
in vec3 viewTangent;
flat in float tangentW;
flat in float exposure;
flat in int materialId;
flat in vec3 blockLightColor;
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

    #if defined SKY_ENABLED && defined SHADOW_ENABLED
        in vec3 tanLightPos;
    #endif
#endif

#ifdef SKY_ENABLED
    flat in vec3 sunColor;
    flat in vec3 moonColor;

    uniform vec3 sunPosition;
    uniform vec3 moonPosition;
    uniform float rainStrength;
    uniform vec3 skyColor;
    uniform float wetness;
    uniform int moonPhase;

    #ifdef SHADOW_ENABLED
        flat in vec3 skyLightColor;

        uniform mat4 shadowModelView;
        uniform mat4 shadowProjection;
        uniform vec3 shadowLightPosition;

        #if SHADOW_TYPE != SHADOW_TYPE_NONE
            uniform sampler2D shadowtex0;

            #ifdef SHADOW_COLOR
                uniform sampler2D shadowcolor0;
            #endif

            #ifdef SSS_ENABLED
                uniform usampler2D shadowcolor1;
            #endif
        
            #ifdef SHADOW_ENABLE_HWCOMP
                #ifdef IRIS_FEATURE_SEPARATE_HW_SAMPLERS
                    uniform sampler2DShadow shadowtex1HW;
                    uniform sampler2D shadowtex1;
                #else
                    uniform sampler2DShadow shadowtex1;
                #endif
            #else
                uniform sampler2D shadowtex1;
            #endif
        #endif

        #if SHADOW_TYPE == SHADOW_TYPE_CASCADED
            flat in float cascadeSizes[4];
            flat in vec3 matShadowProjections_scale[4];
            flat in vec3 matShadowProjections_translation[4];
        #endif

        #ifdef SHADOW_CONTACT
            uniform sampler2D depthtex1;
        #endif
    #endif
#endif

#ifdef AF_ENABLED
    in vec4 spriteBounds;
#endif

#if AO_TYPE == AO_TYPE_FANCY
    uniform sampler2D BUFFER_AO;
#endif

uniform sampler2D gtexture;
uniform sampler2D normals;
uniform sampler2D specular;
uniform sampler2D lightmap;
uniform sampler2D noisetex;
uniform sampler2D colortex10;

uniform ivec2 atlasSize;

//uniform mat4 shadowProjection;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjection;
uniform ivec2 eyeBrightnessSmooth;
uniform int heldBlockLightValue;
uniform int heldBlockLightValue2;
uniform vec3 cameraPosition;
uniform vec3 upPosition;
uniform float viewWidth;
uniform float viewHeight;
uniform int isEyeInWater;
uniform float near;
uniform float far;

uniform vec3 fogColor;
uniform float fogStart;
uniform float fogEnd;
uniform int fogMode;
uniform int fogShape;

#if MC_VERSION >= 11900
    uniform float darknessFactor;
#endif

#ifdef IS_OPTIFINE
    uniform float eyeHumidity;
#endif

#if REFLECTION_MODE == REFLECTION_MODE_SCREEN
    uniform sampler2D BUFFER_HDR_PREVIOUS;
    uniform sampler2D BUFFER_DEPTH_PREV;

    //uniform mat4 gbufferModelViewInverse;
    //uniform mat4 gbufferProjection;
    uniform mat4 gbufferProjectionInverse;
    uniform mat4 gbufferPreviousModelView;
    uniform mat4 gbufferPreviousProjection;
    uniform vec3 previousCameraPosition;
    //uniform vec3 cameraPosition;
#endif

#include "/lib/atlas.glsl"
#include "/lib/depth.glsl"
#include "/lib/lighting/blackbody.glsl"
#include "/lib/lighting/light_data.glsl"
#include "/lib/sampling/linear.glsl"

#ifdef PARALLAX_ENABLED
    #include "/lib/parallax.glsl"
#endif

#if DIRECTIONAL_LIGHTMAP_STRENGTH > 0
    #include "/lib/lighting/directional.glsl"
#endif

#ifdef SKY_ENABLED
    #include "/lib/world/scattering.glsl"
    #include "/lib/world/porosity.glsl"
    #include "/lib/world/sky.glsl"
    #include "/lib/lighting/basic.glsl"

    #if defined SHADOW_ENABLED && SHADOW_TYPE != SHADOW_TYPE_NONE
        #include "/lib/sampling/bayer.glsl"

        #if SHADOW_PCF_SAMPLES == 12
            #include "/lib/sampling/poisson_12.glsl"
        #elif SHADOW_PCF_SAMPLES == 24
            #include "/lib/sampling/poisson_24.glsl"
        #elif SHADOW_PCF_SAMPLES == 36
            #include "/lib/sampling/poisson_36.glsl"
        #endif
        
        #if SHADOW_TYPE == SHADOW_TYPE_CASCADED
            #include "/lib/shadows/csm.glsl"
            #include "/lib/shadows/csm_render.glsl"
        #elif SHADOW_TYPE != SHADOW_TYPE_NONE
            #include "/lib/shadows/basic.glsl"
            #include "/lib/shadows/basic_render.glsl"
        #endif

        #ifdef SHADOW_CONTACT
            #include "/lib/shadows/contact.glsl"
        #endif

        #ifdef VL_ENABLED
            #include "/lib/lighting/volumetric.glsl"
        #endif
    #endif
#endif

#include "/lib/world/fog.glsl"
#include "/lib/material/hcm.glsl"
#include "/lib/material/material.glsl"
#include "/lib/material/material_reader.glsl"

#if REFLECTION_MODE == REFLECTION_MODE_SCREEN
    #include "/lib/ssr.glsl"
#endif

#include "/lib/lighting/brdf.glsl"

#ifdef HANDLIGHT_ENABLED
    #include "/lib/lighting/pbr_handlight.glsl"
#endif

#include "/lib/lighting/pbr.glsl"
#include "/lib/lighting/pbr_forward.glsl"

/* RENDERTARGETS: 4,6 */
out vec4 outColor0;
out vec4 outColor1;


void main() {
    vec4 color = PbrLighting();

    vec4 outLum = vec4(0.0);
    outLum.r = log2(luminance(color.rgb) + EPSILON);
    outLum.a = color.a;
    outColor1 = outLum;

    color.rgb = clamp(color.rgb * exposure, vec3(0.0), vec3(65000));
    outColor0 = color;
}
