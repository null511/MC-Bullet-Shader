#define RENDER_FRAG
#define RENDER_GBUFFER
#define RENDER_TEXTURED

#undef PARALLAX_ENABLED
#undef AF_ENABLED

#include "/lib/constants.glsl"
#include "/lib/common.glsl"

in vec2 lmcoord;
in vec2 texcoord;
in vec4 glcolor;
in float geoNoL;
in vec3 localPos;
in vec3 viewPos;
in vec3 viewNormal;
//flat in mat2 atlasBounds;
flat in float exposure;
flat in vec3 blockLightColor;

#if defined HANDLIGHT_ENABLED || CAMERA_EXPOSURE_MODE == EXPOSURE_MODE_EYEBRIGHTNESS
    uniform int heldBlockLightValue;
    uniform int heldBlockLightValue2;
#endif

#ifdef SKY_ENABLED
    flat in vec3 sunColor;
    flat in vec3 moonColor;
    flat in vec2 skyLightLevels;
    flat in vec3 sunTransmittanceEye;
    flat in vec3 moonTransmittanceEye;

    uniform sampler2D noisetex;
    uniform usampler2D shadowcolor1;

    #if SHADER_PLATFORM == PLATFORM_IRIS
        uniform sampler3D texSunTransmittance;
        uniform sampler3D texMultipleScattering;
    #else
        uniform sampler3D colortex11;
        uniform sampler3D colortex12;
    #endif

    uniform float frameTimeCounter;
    uniform vec3 upPosition;
    uniform vec3 sunPosition;
    uniform vec3 moonPosition;
    uniform float rainStrength;
    uniform float wetness;
    uniform vec3 skyColor;
    uniform int moonPhase;

    #ifdef SHADOW_ENABLED
        uniform vec3 shadowLightPosition;
        //uniform float frameTimeCounter;
    
        #if SHADOW_TYPE != SHADOW_TYPE_NONE
            uniform sampler2D shadowtex0;
            uniform sampler2D shadowtex1;

            #ifdef IRIS_FEATURE_SEPARATE_HARDWARE_SAMPLERS
                uniform sampler2DShadow shadowtex1HW;
            #endif

            #if defined SHADOW_COLOR || defined SSS_ENABLED
                uniform sampler2D shadowcolor0;
            #endif

            // #if defined SSS_ENABLED && defined SHADOW_COLOR
            //     uniform usampler2D shadowcolor1;
            // #endif
            
            uniform mat4 shadowModelView;

            #if SHADOW_TYPE == SHADOW_TYPE_CASCADED
                flat in vec3 matShadowProjections_scale[4];
                flat in vec3 matShadowProjections_translation[4];
                flat in float cascadeSizes[4];
                in vec3 shadowPos[4];
                in float shadowBias[4];
            #elif SHADOW_TYPE != SHADOW_TYPE_NONE
                in vec4 shadowPos;
                in float shadowBias;

                uniform mat4 shadowProjection;
            #endif

            #if defined VL_SKY_ENABLED || defined VL_WATER_ENABLED //&& defined VL_PARTICLES
                //uniform sampler2D noisetex;
            
                uniform mat4 shadowModelViewInverse;
                uniform float viewWidth;
                uniform float viewHeight;
            #endif
            
            #if defined VL_SKY_ENABLED || defined VL_WATER_ENABLED
                #if SHADER_PLATFORM == PLATFORM_IRIS
                    uniform sampler3D texCloudNoise;
                #else
                    uniform sampler3D colortex13;
                #endif

                //uniform mat4 gbufferModelView;
                uniform mat4 gbufferProjection;
            #endif
        #endif
    #endif
#endif

#if defined SHADOW_CONTACT || REFLECTION_MODE == REFLECTION_MODE_SCREEN
    uniform mat4 gbufferProjectionInverse;
#endif

uniform sampler2D gtexture;
uniform sampler2D lightmap;
uniform sampler2D depthtex1;

#if ATMOSPHERE_TYPE == ATMOSPHERE_FANCY
    uniform sampler2D BUFFER_SKY_LUT;
#endif

uniform ivec2 eyeBrightnessSmooth;
uniform ivec2 eyeBrightness;
uniform int worldTime;

uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform vec3 cameraPosition;
uniform int isEyeInWater;
uniform float near;
uniform float far;

uniform vec3 fogColor;
uniform float fogStart;
uniform float fogEnd;
uniform int fogShape;
uniform int fogMode;

#if MC_VERSION >= 11700 && SHADER_PLATFORM != PLATFORM_IRIS
    uniform float alphaTestRef;
#endif

#if MC_VERSION >= 11900
    uniform float darknessFactor;
#endif

uniform float eyeHumidity;
uniform vec3 waterScatterColor;
uniform vec3 waterAbsorbColor;
uniform float waterFogDistSmooth;

#include "/lib/depth.glsl"
#include "/lib/sampling/noise.glsl"
#include "/lib/lighting/blackbody.glsl"
#include "/lib/lighting/light_data.glsl"
#include "/lib/lighting/fresnel.glsl"

#ifdef SKY_ENABLED
    #include "/lib/world/scattering.glsl"
    #include "/lib/sky/sun_moon.glsl"
    #include "/lib/world/sky.glsl"
#endif

#ifdef HANDLIGHT_ENABLED
    #include "/lib/lighting/basic_handlight.glsl"
#endif

#if defined SKY_ENABLED && defined SHADOW_ENABLED
    #if SHADOW_TYPE != SHADOW_TYPE_NONE
        #include "/lib/sampling/bayer.glsl"
    #endif

    #if SHADOW_TYPE == SHADOW_TYPE_CASCADED
        #include "/lib/shadows/csm.glsl"
        #include "/lib/shadows/csm_render.glsl"
    #elif SHADOW_TYPE != SHADOW_TYPE_NONE
        #include "/lib/shadows/basic.glsl"
        #include "/lib/shadows/basic_render.glsl"
    #endif
#endif

#ifdef SKY_ENABLED
    #include "/lib/sky/hillaire_common.glsl"
    #include "/lib/sky/hillaire_render.glsl"
    #include "/lib/sky/clouds.glsl"
#endif

#include "/lib/world/fog.glsl"

#if defined SKY_ENABLED && (defined VL_SKY_ENABLED || defined VL_WATER_ENABLED) && defined SHADOW_ENABLED && SHADOW_TYPE != SHADOW_TYPE_NONE //&& defined VL_PARTICLES
    #include "/lib/lighting/volumetric.glsl"
#endif

#include "/lib/lighting/basic.glsl"
#include "/lib/lighting/basic_forward.glsl"

/* RENDERTARGETS: 2,1 */
layout(location = 0) out vec4 outColor0;
layout(location = 1) out vec4 outColor1;


void main() {
    vec4 albedo = texture(gtexture, texcoord);
    if (albedo.a < (10.0/255.0)) {discard; return;}

    albedo.rgb = RGBToLinear(albedo.rgb * glcolor.rgb);
    //albedo.a *= PARTICLE_OPACITY;

    LightData lightData;
    lightData.occlusion = 1.0;
    lightData.blockLight = lmcoord.x;
    lightData.skyLight = lmcoord.y;
    lightData.parallaxShadow = 1.0;

    #ifdef PARTICLE_ROUNDING
        vec2 localTex = fract(texcoord * PARTICLE_RESOLUTION);
        localTex.y = 1.0 - localTex.y;

        vec3 _viewNormal = RestoreNormalZ(localTex);

        vec3 lightDir = normalize(shadowLightPosition);
        lightData.geoNoL = max(dot(_viewNormal, lightDir), 0.0);
    #else
        vec3 _viewNormal = normalize(viewNormal);
        lightData.geoNoL = geoNoL;
    #endif

    lightData.transparentScreenDepth = gl_FragCoord.z;
    lightData.opaqueScreenDepth = texelFetch(depthtex1, ivec2(gl_FragCoord.xy), 0).r;
    lightData.opaqueScreenDepthLinear = linearizeDepthFast(lightData.opaqueScreenDepth, near, far);
    lightData.transparentScreenDepthLinear = linearizeDepthFast(lightData.transparentScreenDepth, near, far);

    #ifdef SKY_ENABLED
        float worldY = localPos.y + cameraPosition.y;
        lightData.skyLightLevels = skyLightLevels;
        lightData.sunTransmittanceEye = sunTransmittanceEye;
        lightData.moonTransmittanceEye = moonTransmittanceEye;

        #if SHADER_PLATFORM == PLATFORM_IRIS
            lightData.sunTransmittance = GetSunTransmittance(texSunTransmittance, worldY, skyLightLevels.x);
            lightData.moonTransmittance = GetMoonTransmittance(texSunTransmittance, worldY, skyLightLevels.y);
        #else
            lightData.sunTransmittance = GetSunTransmittance(colortex11, worldY, skyLightLevels.x);
            lightData.moonTransmittance = GetMoonTransmittance(colortex11, worldY, skyLightLevels.y);
        #endif
    #endif

    #if defined SKY_ENABLED && defined SHADOW_ENABLED && SHADOW_TYPE != SHADOW_TYPE_NONE
        // #ifdef SHADOW_DITHER
        //     float ditherOffset = (GetScreenBayerValue() - 0.5) * shadowPixelSize;
        // #endif

        #if SHADOW_TYPE == SHADOW_TYPE_CASCADED
            for (int i = 0; i < 4; i++) {
                lightData.shadowPos[i] = shadowPos[i];
                lightData.shadowBias[i] = shadowBias[i];
                lightData.shadowTilePos[i] = GetShadowCascadeClipPos(i);

                lightData.matShadowProjection[i] = GetShadowCascadeProjectionMatrix_FromParts(matShadowProjections_scale[i], matShadowProjections_translation[i]);
                
                // #ifdef SHADOW_DITHER
                //     lightData.shadowPos[i].xy += ditherOffset;
                // #endif
            }

            lightData.opaqueShadowDepth = GetNearestOpaqueDepth(lightData.shadowPos, lightData.shadowTilePos, vec2(0.0), lightData.opaqueShadowCascade);
            lightData.transparentShadowDepth = GetNearestTransparentDepth(lightData.shadowPos, lightData.shadowTilePos, vec2(0.0), lightData.transparentShadowCascade);

            float minTransparentDepth = min(lightData.shadowPos[lightData.transparentShadowCascade].z, lightData.transparentShadowDepth);
            lightData.waterShadowDepth = max(lightData.opaqueShadowDepth - minTransparentDepth, 0.0) * 3.0 * far;
        #elif SHADOW_TYPE != SHADOW_TYPE_NONE
            lightData.shadowPos = shadowPos;
            lightData.shadowBias = shadowBias;

            // #ifdef SHADOW_DITHER
            //     lightData.shadowPos.xy += ditherOffset;
            // #endif

            lightData.opaqueShadowDepth = SampleOpaqueDepth(lightData.shadowPos, vec2(0.0));
            lightData.transparentShadowDepth = SampleTransparentDepth(lightData.shadowPos, vec2(0.0));

            lightData.waterShadowDepth = max(lightData.opaqueShadowDepth - lightData.shadowPos.z, 0.0) * 3.0 * far;
        #endif
    #endif

    vec4 color = BasicLighting(lightData, albedo, _viewNormal);
    //color = vec3(2000.0, 0.0, 0.0);

    float lum = log2(luminance(color.rgb) + EPSILON);
    outColor1 = vec4(lum, 0.0, 0.0, 1.0);

    color.rgb = clamp(color.rgb * exposure, vec3(0.0), vec3(65000));
    outColor0 = vec4(color.rgb, 1.0);
}
