#define RENDER_COMPOSITE_FINAL
#define RENDER_COMPOSITE
#define RENDER_FRAG

#include "/lib/constants.glsl"
#include "/lib/common.glsl"

in vec2 texcoord;

#ifndef IRIS_FEATURE_SSBO
    flat in float sceneExposure;
    
    flat in vec3 blockLightColor;

    #ifdef SKY_ENABLED
        flat in vec2 skyLightLevels;

        flat in vec3 skySunColor;
        flat in vec3 sunTransmittanceEye;

        #ifdef WORLD_MOON_ENABLED
            flat in vec3 skyMoonColor;
            flat in vec3 moonTransmittanceEye;
        #endif
    #endif
#endif

#ifdef SKY_ENABLED
    uniform sampler2D BUFFER_SKY_LUT;
    uniform sampler2D BUFFER_IRRADIANCE;

    #ifdef IS_IRIS
        uniform sampler3D texSunTransmittance;
        uniform sampler3D texMultipleScattering;
    #else
        uniform sampler3D colortex12;
        uniform sampler3D colortex13;
    #endif

    #ifdef SHADOW_COLOR
        uniform sampler2D BUFFER_DEFERRED2;
    #endif

    #if defined SHADOW_COLOR || defined SSS_ENABLED
        uniform sampler2D shadowcolor0;
    #endif
#endif

#if AO_TYPE == AO_TYPE_SS || (defined SHADOW_ENABLED && SHADOW_TYPE != SHADOW_TYPE_NONE)
    uniform sampler2D BUFFER_AO;
#endif

uniform usampler2D BUFFER_DEFERRED;
uniform sampler2D BUFFER_LUM_OPAQUE;
uniform sampler2D BUFFER_HDR_OPAQUE;
uniform sampler2D BUFFER_LUM_TRANS;
uniform sampler2D BUFFER_HDR_TRANS;
uniform sampler3D TEX_CLOUD_NOISE;
uniform sampler2D TEX_BRDF;
uniform sampler2D depthtex0;
uniform sampler2D depthtex1;
uniform sampler2D noisetex;

#if REFLECTION_MODE == REFLECTION_MODE_SCREEN
    uniform mat4 gbufferPreviousModelView;
    uniform mat4 gbufferPreviousProjection;
    uniform vec3 previousCameraPosition;

    uniform sampler2D BUFFER_HDR_PREVIOUS;
    uniform sampler2D BUFFER_DEPTH_PREV;
#endif

uniform float frameTimeCounter;
uniform int worldTime;

uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelView;
uniform mat4 gbufferProjection;

uniform vec3 cameraPosition;
uniform vec3 upPosition;
uniform float viewWidth;
uniform float viewHeight;
uniform float near;
uniform float far;

uniform int isEyeInWater;
uniform ivec2 eyeBrightnessSmooth;
uniform ivec2 eyeBrightness;

uniform int fogMode;
uniform int fogShape;
uniform vec3 fogColor;
uniform float fogStart;
uniform float fogEnd;

#ifdef HANDLIGHT_ENABLED
    uniform int heldBlockLightValue;
    uniform int heldBlockLightValue2;
    
    #ifdef IS_IRIS
        uniform bool firstPersonCamera;
        uniform vec3 eyePosition;
    #endif
#endif

#ifdef SKY_ENABLED
    uniform vec3 skyColor;
    uniform float rainStrength;
    uniform float wetness;
    uniform vec3 sunPosition;
    uniform vec3 moonPosition;
    uniform int moonPhase;

    uniform vec3 shadowLightPosition;

    #ifdef IS_IRIS
        uniform vec4 lightningBoltPosition;
    #endif

    #if defined SHADOW_ENABLED && SHADOW_TYPE != SHADOW_TYPE_NONE
        uniform sampler2D shadowtex0;
        uniform sampler2D shadowtex1;
        uniform usampler2D shadowcolor1;

        uniform mat4 shadowProjection;
        uniform mat4 shadowModelView;
        uniform mat4 shadowModelViewInverse;

        #ifdef IRIS_FEATURE_SEPARATE_HARDWARE_SAMPLERS
            uniform sampler2DShadow shadowtex1HW;
        #endif
    #endif
#endif

uniform float blindness;

#if MC_VERSION >= 11900
    uniform float darknessFactor;
#endif

uniform float eyeHumidity;

#ifdef WORLD_WATER_ENABLED
    uniform vec3 waterScatterColor;
    uniform vec3 waterAbsorbColor;
    uniform float waterFogDistSmooth;
#endif

#include "/lib/depth.glsl"
#include "/lib/matrix.glsl"
#include "/lib/sampling/bayer.glsl"
#include "/lib/sampling/linear.glsl"
#include "/lib/sampling/noise.glsl"
#include "/lib/sampling/erp.glsl"
#include "/lib/lighting/blackbody.glsl"
#include "/lib/lighting/light_data.glsl"

#include "/lib/material/hcm.glsl"
#include "/lib/material/material.glsl"
#include "/lib/material/material_reader.glsl"
#include "/lib/lighting/fresnel.glsl"
#include "/lib/lighting/brdf.glsl"

//#if AO_TYPE == AO_TYPE_SS || (defined RSM_ENABLED && defined RSM_UPSCALE)
    #include "/lib/sampling/bilateral_gaussian.glsl"
//#endif

#ifdef SKY_ENABLED
    #include "/lib/sky/hillaire_common.glsl"
    #include "/lib/celestial/position.glsl"
    #include "/lib/celestial/transmittance.glsl"
    #include "/lib/world/sky.glsl"
    #include "/lib/world/scattering.glsl"

    #ifdef IS_IRIS
        #include "/lib/sky/lightning.glsl"
    #endif
#endif

#ifdef SKY_ENABLED
    #include "/lib/sky/hillaire_render.glsl"
    #include "/lib/sky/stars.glsl"

    #ifdef WORLD_CLOUDS_ENABLED
        #include "/lib/sky/clouds.glsl"
    #endif
#endif

#include "/lib/lighting/basic.glsl"
#include "/lib/world/fog_vanilla.glsl"

#ifdef SKY_ENABLED
    #include "/lib/sky/hillaire.glsl"
    #include "/lib/world/fog_fancy.glsl"

    #ifdef WORLD_WATER_ENABLED
        #include "/lib/world/weather.glsl"
    #endif

    #if defined SHADOW_ENABLED && SHADOW_TYPE != SHADOW_TYPE_NONE
        #include "/lib/sampling/ign.glsl"
        #include "/lib/shadows/common.glsl"

        #if SHADOW_TYPE == SHADOW_TYPE_CASCADED
            #include "/lib/shadows/csm.glsl"
            #include "/lib/shadows/csm_render.glsl"
        #else
            #include "/lib/shadows/basic.glsl"
            #include "/lib/shadows/basic_render.glsl"
        #endif

        #if defined SKY_VL_ENABLED || defined VL_WATER_ENABLED
            #include "/lib/lighting/volumetric.glsl"
        #endif
    #endif

    #if SHADOW_CONTACT != SHADOW_CONTACT_NONE
        #include "/lib/shadows/contact.glsl"
    #endif
#endif

#if !defined SKY_ENABLED && defined SMOKE_ENABLED
    #include "/lib/camera/bloom.glsl"
    #include "/lib/world/smoke.glsl"
#endif

#if REFLECTION_MODE == REFLECTION_MODE_SCREEN
    #include "/lib/ssr.glsl"
#endif

#ifdef HANDLIGHT_ENABLED
    #include "/lib/lighting/handlight_common.glsl"
    #include "/lib/lighting/pbr_handlight.glsl"
#endif

#include "/lib/lighting/pbr.glsl"

/* RENDERTARGETS: 4,3 */
layout(location = 0) out vec4 outColor0;
layout(location = 1) out float outColor1;


void main() {
    ivec2 iTex = ivec2(gl_FragCoord.xy);
    //vec3 colorFinal;
    //float lumFinal;
    vec3 final = vec3(0.0);

    LightData lightData;

    lightData.opaqueScreenDepth = texelFetch(depthtex1, iTex, 0).r;
    lightData.opaqueScreenDepthLinear = linearizeDepthFast(lightData.opaqueScreenDepth, near, far);

    lightData.transparentScreenDepth = texelFetch(depthtex0, iTex, 0).r;
    lightData.transparentScreenDepthLinear = linearizeDepthFast(lightData.transparentScreenDepth, near, far);

    vec3 clipPos = vec3(texcoord, lightData.opaqueScreenDepth) * 2.0 - 1.0;
    vec3 viewPos = unproject(gbufferProjectionInverse * vec4(clipPos, 1.0));
    vec3 localPos = (gbufferModelViewInverse * vec4(viewPos, 1.0)).xyz;
    vec3 localViewDir = normalize(localPos);
    vec3 viewDir = normalize(viewPos);

    #ifdef SKY_ENABLED
        //lightData.skyLightLevels = skyLightLevels;
        //lightData.sunTransmittanceEye = sunTransmittanceEye;

        vec3 sunColorFinalEye = sunTransmittanceEye * skySunColor * SunLux;// * max(skyLightLevels.x, 0.0);

        #ifdef WORLD_MOON_ENABLED
            //lightData.moonTransmittanceEye = moonTransmittanceEye;

            vec3 moonColorFinalEye = moonTransmittanceEye * skyMoonColor * MoonLux * GetMoonPhaseLevel();// * max(skyLightLevels.y, 0.0);
        #endif

        #ifdef WORLD_WATER_ENABLED
            vec3 waterSunColorEye = sunColorFinalEye * max(skyLightLevels.x, 0.0);

            #ifdef WORLD_MOON_ENABLED
                vec3 waterMoonColorEye = moonColorFinalEye * max(skyLightLevels.y, 0.0);
            #else
                const vec3 waterMoonColorEye = vec3(0.0);
            #endif

            vec2 waterScatteringF = GetWaterScattering(viewDir);
        #endif
    #endif

    #ifdef WORLD_WATER_ENABLED
        if (isEyeInWater == 1) {
            vec2 viewSize = vec2(viewWidth, viewHeight);
            vec3 worldPos = cameraPosition + localPos;

            PbrMaterial material;

            // SKY
            if (lightData.opaqueScreenDepth > 1.0 - EPSILON) {
                lightData.parallaxShadow = 1.0;
                lightData.skyLight = 1.0;
                lightData.blockLight = 1.0;
                lightData.occlusion = 1.0;
                lightData.geoNoL = 1.0;
            }
            else {
                uvec4 deferredData = texelFetch(BUFFER_DEFERRED, iTex, 0);
                vec4 colorMap = unpackUnorm4x8(deferredData.r);
                vec4 normalMap = unpackUnorm4x8(deferredData.g);
                vec4 specularMap = unpackUnorm4x8(deferredData.b);
                vec4 lightingMap = unpackUnorm4x8(deferredData.a);
                
                lightData.occlusion = normalMap.a;
                lightData.blockLight = lightingMap.x;
                lightData.skyLight = lightingMap.y;
                lightData.geoNoL = lightingMap.z * 2.0 - 1.0;
                lightData.parallaxShadow = lightingMap.w;
                
                PopulateMaterial(material, colorMap.rgb, normalMap, specularMap);
            }

            #ifdef SKY_ENABLED
                vec3 upDir = normalize(upPosition);
                float fragElevation = GetAtmosphereElevation(worldPos);

                #ifdef IS_IRIS
                    lightData.sunTransmittance = GetTransmittance(texSunTransmittance, fragElevation, skyLightLevels.x);
                    lightData.moonTransmittance = GetTransmittance(texSunTransmittance, fragElevation, skyLightLevels.y);
                #else
                    lightData.sunTransmittance = GetTransmittance(colortex12, fragElevation, skyLightLevels.x);
                    lightData.moonTransmittance = GetTransmittance(colortex12, fragElevation, skyLightLevels.y);
                #endif

                #if defined SHADOW_ENABLED && SHADOW_TYPE != SHADOW_TYPE_NONE
                    vec3 dX = dFdx(localPos);
                    vec3 dY = dFdy(localPos);

                    vec3 shadowLocalPos = localPos;

                    vec3 geoNormal = normalize(cross(dX, dY));
                    vec3 localLightDir = GetShadowLightLocalDir();
                    float geoNoL = max(dot(geoNormal, localLightDir), 0.0);

                    float viewDist = length(viewPos);
                    shadowLocalPos += geoNormal * viewDist * SHADOW_NORMAL_BIAS * max(1.0 - geoNoL, 0.0);

                    #ifndef IRIS_FEATURE_SSBO
                        mat4 shadowModelViewEx = BuildShadowViewMatrix();
                    #endif

                    vec3 shadowViewPos = (shadowModelViewEx * vec4(shadowLocalPos, 1.0)).xyz;

                    #if SHADOW_TYPE == SHADOW_TYPE_CASCADED
                        vec3 shadowPos = GetCascadeShadowPosition(shadowViewPos, lightData.shadowCascade);

                        lightData.shadowPos[lightData.shadowCascade] = shadowPos;
                        lightData.shadowBias[lightData.shadowCascade] = GetCascadeBias(geoNoL, shadowProjectionSize[lightData.shadowCascade]);

                        if (lightData.shadowCascade >= 0) {
                            lightData.opaqueShadowDepth = SampleOpaqueDepth(lightData.shadowPos[lightData.shadowCascade].xy, vec2(0.0));
                            lightData.transparentShadowDepth = SampleTransparentDepth(lightData.shadowPos[lightData.shadowCascade].xy, vec2(0.0));
                            
                            float minOpaqueDepth = min(lightData.shadowPos[lightData.shadowCascade].z, lightData.opaqueShadowDepth);
                            lightData.waterShadowDepth = (minOpaqueDepth - lightData.transparentShadowDepth) * 3.0 * far;
                        }
                        else {
                            lightData.opaqueShadowDepth = 1.0;
                            lightData.transparentShadowDepth = 1.0;
                            lightData.waterShadowDepth = 0.0;
                        }
                    #else
                        #ifndef IRIS_FEATURE_SSBO
                            mat4 shadowProjectionEx = BuildShadowProjectionMatrix();
                        #endif
                    
                        lightData.shadowPos = (shadowProjectionEx * vec4(shadowViewPos, 1.0)).xyz;

                        #if SHADOW_TYPE == SHADOW_TYPE_DISTORTED
                            float distortFactor = getDistortFactor(lightData.shadowPos.xy);
                            lightData.shadowPos = distort(lightData.shadowPos, distortFactor);
                            lightData.shadowBias = GetShadowBias(lightData.geoNoL, distortFactor);
                        #else
                            lightData.shadowBias = GetShadowBias(lightData.geoNoL);
                        #endif

                        lightData.shadowPos = lightData.shadowPos * 0.5 + 0.5;

                        lightData.opaqueShadowDepth = SampleOpaqueDepth(lightData.shadowPos.xy, vec2(0.0));
                        lightData.transparentShadowDepth = SampleTransparentDepth(lightData.shadowPos.xy, vec2(0.0));

                        #if SHADOW_TYPE == SHADOW_TYPE_DISTORTED
                            const float ShadowMaxDepth = 512.0;
                        #else
                            const float ShadowMaxDepth = 256.0;
                        #endif

                        lightData.waterShadowDepth = max(lightData.opaqueShadowDepth - lightData.transparentShadowDepth, 0.0) * ShadowMaxDepth;
                    #endif

                    //lightData.waterShadowDepth = max(lightData.waterShadowDepth - GetScreenBayerValue(), 0.0);
                #endif
            #endif

            if (lightData.opaqueScreenDepth < 1.0) {
                final = PbrLighting2(material, lightData, viewPos).rgb;

                if (lightData.transparentScreenDepth < lightData.opaqueScreenDepth) {
                    #if defined SKY_ENABLED && !defined SKY_VL_ENABLED
                        vec3 viewLightDir = GetShadowLightViewDir();
                        float VoL = dot(viewLightDir, viewDir);
                        vec3 localSunDir = GetSunLocalDir();
                        vec4 scatteringTransmittance = GetFancyFog(localPos, localSunDir, VoL);
                        final = final * scatteringTransmittance.a + scatteringTransmittance.rgb;
                    #else
                        // TODO: ?
                    #endif
                }
            }
            else if (lightData.transparentScreenDepth >= 1.0) {
                final = GetWaterFogColor(waterSunColorEye, waterMoonColorEye, waterScatteringF);
                //final = vec3(0.0);
            }
        }
    #endif

    if (isEyeInWater == 0 || (lightData.opaqueScreenDepth >= 1.0 && lightData.transparentScreenDepth < 1.0)) {
        //float lum = texelFetch(BUFFER_LUM_OPAQUE, iTex, 0).r;
        final = texelFetch(BUFFER_HDR_OPAQUE, iTex, 0).rgb / sceneExposure;

        #if defined WORLD_CLOUDS_ENABLED && defined SKY_CLOUDS_ENABLED
            if (isEyeInWater == 1) {
                if (HasClouds(cameraPosition, localViewDir)) {
                    vec3 cloudPos = GetCloudPosition(cameraPosition, localViewDir);

                    float cloudF = GetCloudFactor(cloudPos, localViewDir, 0);
                    //cloudF *= max(localViewDir.y, 0.0);
                    cloudF *= 1.0 - blindness;

                    vec3 cloudColor = GetCloudColor(cloudPos, localViewDir, skyLightLevels);
                    final = mix(final, cloudColor, cloudF);
                }
            }
        #endif
    }

    float minViewDist = min(lightData.opaqueScreenDepthLinear, lightData.transparentScreenDepthLinear);

    #if defined SKY_ENABLED && defined SKY_VL_ENABLED && defined SHADOW_ENABLED && SHADOW_TYPE != SHADOW_TYPE_NONE
        if (isEyeInWater == 1 && lightData.opaqueScreenDepth > lightData.transparentScreenDepth) {
            vec3 vlScatter, vlExt;
            GetVolumetricLighting(vlScatter, vlExt, localViewDir, lightData.transparentScreenDepthLinear, lightData.opaqueScreenDepthLinear);
            final = final * vlExt + vlScatter;

            // TODO: increase alpha with VL?
        }
    #endif

    //float lumTrans = texelFetch(BUFFER_LUM_TRANS, iTex, 0).r;
    vec4 colorTrans = texelFetch(BUFFER_HDR_TRANS, iTex, 0);

    //outColor0 = vec4(mix(vec3(0.0), colorTrans.rgb, colorTrans.a), 1.0);
    //return;

    final = mix(final, colorTrans.rgb / sceneExposure, colorTrans.a);

    #ifdef WORLD_WATER_ENABLED
        if (isEyeInWater == 1) {
            #if defined SKY_ENABLED && defined SHADOW_ENABLED && defined VL_WATER_ENABLED && SHADOW_TYPE != SHADOW_TYPE_NONE
                vec3 vlScatter, vlExt;
                GetWaterVolumetricLighting(vlScatter, vlExt, waterScatteringF, localViewDir, near, minViewDist);
                final *= vlExt;
            #else
                if (lightData.transparentScreenDepth >= lightData.opaqueScreenDepth) {
                    // TODO: get actual linear distance
                    //float viewDist = min(lightData.opaqueScreenDepthLinear, lightData.transparentScreenDepthLinear);
                    vec3 waterExtinctionInv = WATER_ABSROPTION_RATE * (1.0 - waterAbsorbColor);
                    final *= exp(-minViewDist * waterExtinctionInv);
                }
            #endif

            //if (lightData.transparentScreenDepth >= lightData.opaqueScreenDepth) {
                vec3 waterFogColor = GetWaterFogColor(waterSunColorEye, waterMoonColorEye, waterScatteringF);

                float waterFogF = GetWaterFogFactor(0.0, minViewDist);
                //waterFogF *= 1.0 - reflectF;
                final = mix(final, waterFogColor, waterFogF);
            //}

            #if defined SKY_ENABLED && defined SHADOW_ENABLED && defined VL_WATER_ENABLED && SHADOW_TYPE != SHADOW_TYPE_NONE
                final += vlScatter;
            #endif
        }
    #endif

    outColor1 = log2(luminance(final) + EPSILON);

    final = clamp(final * sceneExposure, vec3(0.0), vec3(65000.0));
    outColor0 = vec4(final, 1.0);
}
