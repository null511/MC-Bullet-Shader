#ifdef RENDER_VERTEX
    void PbrVertex(const in vec3 viewPos) {
        viewTangent = normalize(gl_NormalMatrix * at_tangent.xyz);
        tangentW = at_tangent.w;

        #if defined PARALLAX_ENABLED && !defined RENDER_TEXTURED
            vec3 viewBinormal = normalize(cross(viewTangent, viewNormal) * at_tangent.w);
            mat3 matTBN = mat3(viewTangent, viewBinormal, viewNormal);

            vec2 coordMid = (gl_TextureMatrix[0] * mc_midTexCoord).xy;
            vec2 coordNMid = texcoord - coordMid;

            atlasBounds[0] = min(texcoord, coordMid - coordNMid);
            atlasBounds[1] = abs(coordNMid) * 2.0;
 
            localCoord = sign(coordNMid) * 0.5 + 0.5;

            #if defined SHADOW_ENABLED
                vec3 lightViewPos = GetShadowLightViewPosition();
                tanLightPos = lightViewPos * matTBN;
            #endif

            tanViewPos = viewPos * matTBN;
        #endif
    }
#endif

#ifdef RENDER_FRAG
    #ifdef SKY_ENABLED
        vec3 GetSkyReflectionColor(const in vec3 worldPos, const in vec3 viewDir, const in vec3 reflectDir, const in float rough) {
            vec3 sunColorFinalEye = sunTransmittanceEye * skySunColor * SunLux * max(skyLightLevels.x, 0.0);

            #ifdef WORLD_MOON_ENABLED
                vec3 moonColorFinalEye = moonTransmittanceEye * skyMoonColor * max(skyLightLevels.y, 0.0);
            #else
                const vec3 moonColorFinalEye = vec3(0.0);
            #endif

            #ifdef RENDER_WATER
                if (materialId == MATERIAL_WATER && isEyeInWater == 1) {
                    vec2 waterScatteringF = GetWaterScattering(reflectDir);
                    return GetWaterFogColor(sunColorFinalEye, moonColorFinalEye, waterScatteringF);
                }
            #endif

            vec3 localReflectDir = normalize(mat3(gbufferModelViewInverse) * reflectDir);
            float horizonFogF = 1.0 - abs(localReflectDir.y);

            //float lod = rough * (8.0 - EPSILON);
            vec3 reflectSkyColor = GetFancySkyLuminance(worldPos.y, localReflectDir, 0.0);

            vec3 starF = GetStarLight(localReflectDir);
            starF *= 1.0 - horizonFogF;
            reflectSkyColor += starF * StarLumen;

            #if defined WORLD_CLOUDS_ENABLED && SKY_CLOUD_LEVEL > 0
                if (HasClouds(worldPos, localReflectDir)) {
                    vec3 cloudPos = GetCloudPosition(worldPos, localReflectDir);
                    float cloudF = GetCloudFactor(cloudPos, localReflectDir, 0.0);
                    cloudF *= 1.0 - blindness;
                    
                    vec3 cloudColor = GetCloudColor(cloudPos, localReflectDir, skyLightLevels);
                    reflectSkyColor = mix(reflectSkyColor, cloudColor, cloudF);
                }
            #endif

            // darken lower horizon
            vec3 downDir = normalize(-upPosition);
            float RoDm = max(dot(reflectDir, downDir), 0.0);
            reflectSkyColor *= (1.0 - RoDm);

            return reflectSkyColor;
        }
    #endif

    vec4 PbrLighting2(const in PbrMaterial material, const in LightData lightData, const in vec3 viewPos) {
        vec2 viewSize = vec2(viewWidth, viewHeight);
        vec3 viewNormal = normalize(material.normal);
        vec3 viewDir = normalize(viewPos);
        float viewDist = length(viewPos);

        vec3 localPos = (gbufferModelViewInverse * vec4(viewPos, 1.0)).xyz;

        #ifdef RENDER_DEFERRED
            vec2 screenUV = texcoord;
        #else
            vec2 screenUV = gl_FragCoord.xy / viewSize;
        #endif

        //return vec4(viewNormal * 1000.0, 1.0);

        #ifdef SKY_ENABLED
            vec3 sunColorFinalEye = sunTransmittanceEye * skySunColor * SunLux;// * max(lightData.skyLightLevels.x, 0.0);
            vec3 sunColorFinal = lightData.sunTransmittance * skySunColor * SunLux;// * max(lightData.skyLightLevels.x, 0.0);

            vec3 skyLightColorFinal = sunColorFinal;

            #ifdef WORLD_MOON_ENABLED
                vec3 moonColorFinalEye = moonTransmittanceEye * skyMoonColor * MoonLux;// * max(lightData.skyLightLevels.y, 0.0);
                vec3 moonColorFinal = lightData.moonTransmittance * skyMoonColor * MoonLux * GetMoonPhaseLevel();// * max(lightData.skyLightLevels.y, 0.0);

                skyLightColorFinal += moonColorFinal;
            #endif

            vec3 viewLightDir = GetShadowLightViewDir();
            float NoL = dot(viewNormal, viewLightDir);

            vec3 halfDir = normalize(viewLightDir + -viewDir);
            float LoHm = max(dot(viewLightDir, halfDir), 0.0);
        #else
            float NoL = 1.0;
            float LoHm = 1.0;
        #endif

        float NoLm = max(NoL, 0.0);
        float NoV = dot(viewNormal, -viewDir);
        float NoVm = max(NoV, 0.0);
        vec3 viewUpDir = normalize(upPosition);

        #if DEBUG_VIEW == DEBUG_VIEW_WHITEWORLD
            vec3 albedo = vec3(1.0);
        #else
            vec3 albedo = material.albedo.rgb;

            #if defined WATER_POROSITY_DARKEN && defined WORLD_WATER_ENABLED && defined SKY_ENABLED && defined RENDER_COMPOSITE
                albedo = WetnessDarkenSurface(albedo, material.porosity, 1.0);
            #endif
        #endif

        float smoothness = material.smoothness;

        float rough = 1.0 - smoothness;
        float roughL = max(rough * rough, 0.005);

        float shadow = lightData.parallaxShadow;
        vec3 shadowColor = vec3(1.0);
        float shadowSSS = 0.0;

        float lightLeakFix = 1.0;
        #ifdef LIGHTLEAK_FIX
            lightLeakFix = saturate(lightData.skyLight * 15.0);
            shadow *= lightLeakFix;
        #endif

        #if !(defined RENDER_WATER || defined RENDER_HAND_WATER || defined RENDER_ENTITIES_TRANSLUCENT)
            #if defined SHADOW_ENABLED && SHADOW_TYPE != SHADOW_TYPE_NONE && defined SHADOW_BLUR
                float shadowDeferredSigma = 3.0 / (viewDist + 1.0);

                #ifdef SHADOW_COLOR
                    vec4 shadowDeferred = BilateralGaussianDepthBlurRGBA_5x(BUFFER_SHADOW, viewSize, depthtex0, viewSize, lightData.opaqueScreenDepthLinear, shadowDeferredSigma);
                    shadowDeferred.rgb *= shadowDeferred.a;
                #else
                    vec4 shadowDeferred = vec4(BilateralGaussianDepthBlur_5x(BUFFER_SHADOW, viewSize, depthtex0, viewSize, lightData.opaqueScreenDepthLinear, shadowDeferredSigma, 3));
                #endif
            #endif

            #if AO_TYPE == AO_TYPE_SS
                float giaoDeferredSigma = 3.0 / (viewDist + 1.0);
                vec4 giaoDeferred = BilateralGaussianDepthBlurRGBA_5x(BUFFER_GI_AO, viewSize, depthtex0, viewSize, lightData.opaqueScreenDepthLinear, giaoDeferredSigma);
            #endif
        #endif

        #ifdef SKY_ENABLED
            vec3 worldPos = cameraPosition + localPos;
            //float sssDist = 0.0;

            // #ifdef RENDER_WATER
            //     if (materialId != MATERIAL_WATER) {
            // #endif

            #if defined SHADOW_ENABLED && SHADOW_TYPE != SHADOW_TYPE_NONE
                #if defined SHADOW_BLUR && !(defined RENDER_WATER || defined RENDER_HAND_WATER || defined RENDER_ENTITIES_TRANSLUCENT)
                    shadowColor *= shadowDeferred.rgb;
                    shadow *= shadowDeferred.a;
                #else
                    shadow *= step(EPSILON, lightData.geoNoL);
                    shadow *= step(EPSILON, NoL);

                    // TODO: more stuff needs to go in here!
                #endif
            #endif

                vec3 localLightDir = mat3(gbufferModelViewInverse) * viewLightDir;

                #if defined WORLD_CLOUDS_ENABLED && SKY_CLOUD_LEVEL > 0 && defined SHADOW_CLOUD
                    float cloudF = GetCloudFactor(worldPos, localLightDir, 4.0);
                    float cloudShadow = 1.0 - cloudF;
                    skyLightColorFinal *= (0.2 + 0.8 * cloudShadow);
                #endif

                float contactShadow = 1.0;
                float contactLightDist = 0.0;
                #if SHADOW_CONTACT != SHADOW_CONTACT_NONE
                    #if SHADOW_CONTACT == SHADOW_CONTACT_FAR
                        const float minContactShadowDist = 0.6 * shadowDistance;
                    #else
                        const float minContactShadowDist = 0.0;
                    #endif

                    if (viewDist >= minContactShadowDist) {
                        float contactMinDist = 0.0;
                        contactShadow = GetContactShadow(depthtex1, viewPos, viewLightDir, contactMinDist, contactLightDist);
                    }
                #endif

                #if defined SHADOW_ENABLED && SHADOW_TYPE != SHADOW_TYPE_NONE && (!defined SHADOW_BLUR || defined RENDER_WATER)
                    if (shadow > EPSILON)
                        shadow *= GetShadowing(lightData);

                    #ifdef SHADOW_COLOR
                        #if SHADOW_TYPE == SHADOW_TYPE_CASCADED
                            if (lightData.shadowPos[lightData.shadowCascade].z - lightData.transparentShadowDepth > lightData.shadowBias[lightData.shadowCascade])
                                shadowColor = GetShadowColor(lightData.shadowPos[lightData.shadowCascade].xy);
                        #else
                            if (lightData.shadowPos.z - lightData.transparentShadowDepth > lightData.shadowBias)
                                shadowColor = GetShadowColor(lightData.shadowPos.xy);
                        #endif
                    #endif

                    shadowColor *= shadow;
                #endif

                #if defined SHADOW_ENABLED && SHADOW_TYPE != SHADOW_TYPE_NONE
                    #ifdef SSS_ENABLED
                        if (material.scattering > EPSILON) {
                            shadowSSS = GetShadowSSS(lightData, material.scattering);
                        }
                    #endif
                #else
                    shadow = pow4(lightData.skyLight);// * lightData.occlusion;
                    shadowSSS = pow4(lightData.skyLight) * material.scattering;
                #endif

                #if SHADOW_CONTACT != SHADOW_CONTACT_NONE
                    float contactShadowMix = saturate(0.2 * (viewDist - minContactShadowDist));

                    #if SHADOW_CONTACT == SHADOW_CONTACT_FAR
                        contactShadow = mix(1.0, contactShadow, contactShadowMix);
                    #endif

                    shadow = min(shadow, contactShadow);
                    //sssDist = max(sssDist, contactLightDist);

                    float maxDist = SSS_MAXDIST * material.scattering;
                    float contactSSS = 0.7 * pow2(material.scattering) * max(1.0 - contactLightDist / maxDist, 0.0);
                    shadowSSS = mix(shadowSSS, contactSSS, contactShadowMix);
                #endif

            // #ifdef RENDER_WATER
            //     }
            // #endif
            
            vec3 skyLightColorShadow = skyLightColorFinal * shadowColor;

            #if !defined SHADOW_ENABLED || SHADOW_TYPE == SHADOW_TYPE_NONE
                float skyLightX = saturate(lightData.skyLight * (16.0/15.0) - (0.5/16.0));
                skyLightColorShadow *= pow(skyLightX, 5.0);
            #endif
        #endif

        float shadowFinal = shadow;

        #ifdef LIGHTLEAK_FIX
            // Make areas without skylight fully shadowed (light leak fix)
            shadowFinal *= lightLeakFix;
            shadowSSS *= lightLeakFix;
        #endif

        float skyLight = lightData.skyLight;
        float occlusion = lightData.occlusion;

        #if AO_TYPE == AO_TYPE_SS && !(defined RENDER_WATER || defined RENDER_HAND_WATER || defined RENDER_ENTITIES_TRANSLUCENT)
            occlusion = min(occlusion, giaoDeferred.a);
        #endif

        occlusion = saturate(occlusion * material.occlusion);

        #if defined SHADOW_ENABLED && SHADOW_TYPE != SHADOW_TYPE_NONE
            // Increase skylight when in direct sunlight
            if (isEyeInWater != 1)
                skyLight = max(skyLight, shadowFinal);
        #endif

        #if !(defined SKY_ENABLED && defined SHADOW_ENABLED && SHADOW_TYPE != SHADOW_TYPE_NONE)
            skyLight *= occlusion;
        #endif

        float skyLight2 = pow2(skyLight);
        float skyLight3 = pow3(skyLight);

        float reflectF = 0.0;
        vec3 reflectColor = vec3(0.0);
        #if REFLECTION_MODE != REFLECTION_MODE_NONE
            vec3 reflectDir = reflect(viewDir, viewNormal);

            if (smoothness > EPSILON) {
                #if REFLECTION_MODE == REFLECTION_MODE_SCREEN
                    vec3 viewPosPrev = (gbufferPreviousModelView * vec4(localPos + (cameraPosition - previousCameraPosition), 1.0)).xyz;

                    vec3 localReflectDir = mat3(gbufferModelViewInverse) * reflectDir;
                    vec3 reflectDirPrev = mat3(gbufferPreviousModelView) * localReflectDir;

                    // TODO: move to vertex shader?
                    //int maxHdrPrevLod = textureQueryLevels(BUFFER_HDR_PREVIOUS);
                    ivec2 texHdrPrevSize = textureSize(BUFFER_HDR_PREVIOUS, 0);
                    int maxHdrPrevLod = int(log2(minOf(texHdrPrevSize)));
                    int lod = int(rough * max(maxHdrPrevLod - EPSILON, 0.0));

                    vec4 roughReflectColor = GetReflectColor(BUFFER_DEPTH_PREV, viewPosPrev, reflectDirPrev, lod);
                    reflectF = roughReflectColor.a;

                    reflectColor = roughReflectColor.rgb * roughReflectColor.a;

                    #ifdef SKY_ENABLED
                        if (roughReflectColor.a + EPSILON < 1.0) {
                            vec3 skyReflectColor = GetSkyReflectionColor(worldPos, viewDir, reflectDir, rough) * skyLight;
                            reflectColor += skyReflectColor * (1.0 - roughReflectColor.a);
                        }
                    #endif
                #elif REFLECTION_MODE == REFLECTION_MODE_SKY && defined SKY_ENABLED
                    reflectColor = GetSkyReflectionColor(worldPos, viewDir, reflectDir, rough) * skyLight;
                #endif
            }
        #endif

        #if MATERIAL_FORMAT == MATERIAL_FORMAT_LABPBR || MATERIAL_FORMAT == MATERIAL_FORMAT_DEFAULT
            float metalDarkF = 1.0;
            if (material.hcm >= 0) {
                metalDarkF = roughL * METAL_AMBIENT; //1.0 - material.f0 * (1.0 - METAL_AMBIENT);
            }
        #else
            float metalDarkF = mix(roughL * METAL_AMBIENT, 1.0, 1.0 - pow2(material.f0));
        #endif

        #if DIRECTIONAL_LIGHTMAP_STRENGTH > 0
            vec3 blockLightDiffuse = pow2(lightData.blockLight)*blockLightColor;
        #else
            vec3 blockLightDiffuse = pow4(lightData.blockLight)*blockLightColor;
        #endif

        #if MATERIAL_FORMAT == MATERIAL_FORMAT_LABPBR || MATERIAL_FORMAT == MATERIAL_FORMAT_DEFAULT
            vec3 specularTint = GetHCM_Tint(material.albedo.rgb, material.hcm);
        #else
            vec3 specularTint = mix(vec3(1.0), material.albedo.rgb, material.f0);
        #endif

        #ifdef WORLD_WATER_ENABLED
            vec3 waterExtinctionInv = 1.0 - waterAbsorbColor;
        #endif

        vec4 final = vec4(albedo, material.albedo.a);
        vec3 ambient = vec3(MinWorldLux);
        vec3 diffuse = albedo * blockLightDiffuse * metalDarkF;
        vec3 specular = vec3(0.0);

        vec3 iblF = vec3(0.0);
        vec3 iblSpec = vec3(0.0);
        #if REFLECTION_MODE != REFLECTION_MODE_NONE
            iblF = GetFresnel(material.albedo.rgb, material.f0, material.hcm, NoVm, roughL);

            if (any(greaterThan(reflectColor, vec3(EPSILON)))) {
                vec2 envBRDF = textureLod(TEX_BRDF, vec2(NoVm, rough), 0).rg;

                iblSpec = min(iblF * envBRDF.r + envBRDF.g, 1.0);
                iblSpec *= (1.0 - roughL) * reflectColor * occlusion;

                float iblFmax = maxOf(iblF);
                //final.a += iblFmax * max(1.0 - final.a, 0.0);
                //final.a = min(final.a + iblFmax * sceneExposure * final.a, 1.0);
                final.a = max(final.a, iblFmax);

                reflectF *= iblFmax;
            }
        #endif

        #ifdef SKY_ENABLED
            vec3 localNormal = mat3(gbufferModelViewInverse) * normalize(viewNormal);

            vec2 sphereCoord = DirectionToUV(localNormal);
            sphereCoord.y = clamp(sphereCoord.y, 0.5/16.0, 15.5/16.0);

            vec3 skyAmbient = GetFancySkyAmbientLight(localNormal) * smoothstep(0.0, 1.0, skyLight);

            #ifdef WORLD_END
                skyAmbient *= 0.1;
            #endif

            bool applyWaterAbsorption = isEyeInWater == 1;

            #ifdef RENDER_WATER
                if (materialId == MATERIAL_WATER) applyWaterAbsorption = false;
            #endif

            #ifdef RENDER_COMPOSITE
                if (lightData.transparentScreenDepth < lightData.opaqueScreenDepth)
                    applyWaterAbsorption = false;
            #endif

            if (applyWaterAbsorption) {
                vec3 sunAbsorption = exp(-max(lightData.waterShadowDepth, 0.0) * waterExtinctionInv) * shadowFinal;
                skyLightColorFinal *= sunAbsorption;
                skyLightColorShadow *= sunAbsorption;
                iblSpec *= sunAbsorption;

                //vec3 viewAbsorption = exp(-max(lightData.opaqueScreenDepthLinear, 0.0) * waterExtinctionInv);
                //skyAmbient *= viewAbsorption;
            }

            ambient += skyAmbient;

            vec3 sunF = GetFresnel(material.albedo.rgb, material.f0, material.hcm, LoHm, roughL);

            vec3 sunDiffuse = GetDiffuse_Burley(albedo, NoVm, NoLm, LoHm, roughL);
            sunDiffuse *= skyLightColorShadow * max(1.0 - sunF, 0.0);

            float VoL = dot(viewDir, viewLightDir);
            vec3 localViewDir = mat3(gbufferModelViewInverse) * viewDir;

            #if defined SSS_ENABLED && defined SKY_ENABLED
                if (material.scattering > 0.0 && shadowSSS > 0.0) {
                    vec3 sssAlbedo = material.albedo.rgb;

                    #ifdef SSS_NORMALIZE_ALBEDO
                        if (all(lessThan(sssAlbedo, vec3(EPSILON)))) albedo = vec3(1.0);
                        albedo = 1.73 * normalize(albedo);
                    #endif

                    float scatter = mix(
                        ComputeVolumetricScattering(VoL, -0.2),
                        ComputeVolumetricScattering(VoL, 0.4),
                        0.65);

                    //sssDist = max(sssDist / (shadowSSS * SSS_MAXDIST), 0.0001);
                    //vec3 sssExt = CalculateExtinction(material.albedo.rgb, sssDist);

                    vec3 sssDiffuseLight = shadowSSS * skyLightColorFinal * max(scatter, 0.0);

                    sssDiffuseLight += GetFancySkyAmbientLight(localViewDir) * smoothstep(0.0, 1.0, skyLight) * occlusion;

                    sssDiffuseLight *= sssAlbedo * material.scattering;

                    //sunDiffuse = GetDiffuseBSDF(sunDiffuse, sssDiffuseLight, material.scattering, NoVm, NoLm, LoHm, roughL);
                    sunDiffuse += sssDiffuseLight * NoVm * (0.01 * SSS_STRENGTH);
                    //return vec4(sssAlbedo * shadowSSS * skyLightColorFinal, 1.0);
                }
            #endif

            diffuse += sunDiffuse * metalDarkF;

            if (NoLm > EPSILON) {
                float NoHm = max(dot(viewNormal, halfDir), 0.0);

                vec3 sunSpec = GetSpecularBRDF(sunF, NoVm, NoLm, NoHm, roughL) * skyLightColorShadow * skyLight2;// * final.a;
                
                specular += sunSpec;// * material.albedo.a;

                final.a = min(final.a + luminance(sunSpec) * sceneExposure, 1.0);
            }
        #endif

        #if defined SKY_ENABLED && defined WORLD_WATER_ENABLED
            vec3 localSunDir = GetSunLocalDir();
            float sun_VoL = dot(localSunDir, localViewDir);

            vec3 localMoonDir = GetMoonLocalDir();
            float moon_VoL = dot(localMoonDir, localViewDir);

            vec2 waterScatteringF = GetWaterScattering(sun_VoL, moon_VoL);
            vec3 waterSunColorEye = sunColorFinalEye * max(skyLightLevels.x, 0.0);

            #ifdef WORLD_MOON_ENABLED
                vec3 waterMoonColorEye = moonColorFinalEye * max(skyLightLevels.y, 0.0);
            #else
                const vec3 waterMoonColorEye = vec3(0.0);
            #endif
        #endif

        #if defined HANDLIGHT_ENABLED
            if (heldBlockLightValue + heldBlockLightValue2 > EPSILON) {
                vec3 handViewPos = viewPos.xyz;

                #ifdef IS_IRIS
                    if (!firstPersonCamera) {
                        vec3 playerCameraOffset = cameraPosition - eyePosition;
                        playerCameraOffset = (gbufferModelView * vec4(playerCameraOffset, 1.0)).xyz;
                        handViewPos += playerCameraOffset;
                    }
                #endif

                vec3 handDiffuse, handSpecular;
                ApplyHandLighting(handDiffuse, handSpecular, material.albedo.rgb, material.f0, material.hcm, material.scattering, viewNormal, handViewPos, -viewDir, NoVm, roughL);

                diffuse += handDiffuse;
                specular += handSpecular;

                final.a = min(final.a + luminance(handSpecular) * sceneExposure, 1.0);
            }
        #endif

        #if defined RENDER_WATER && defined WORLD_WATER_ENABLED
            if (materialId == MATERIAL_WATER) {
                float waterRefractEta = isEyeInWater == 1
                    ? IOR_WATER / IOR_AIR
                    : IOR_AIR / IOR_WATER;
                
                vec3 refractDir = refract(viewDir, viewNormal, waterRefractEta);

                if (isEyeInWater != 1) {
                    float refractOpaqueScreenDepth = lightData.opaqueScreenDepth;
                    float refractOpaqueScreenDepthLinear = lightData.opaqueScreenDepthLinear;
                    vec3 refractColor = vec3(0.0);
                    vec2 refractUV = screenUV;

                    if (dot(refractDir, refractDir) > EPSILON) {
                        #if REFRACTION_STRENGTH > 0
                            float refractDist = max(lightData.opaqueScreenDepthLinear - lightData.transparentScreenDepthLinear, 0.0);

                            #ifdef WATER_REFRACTION_FANCY
                                vec3 refractClipPos = unproject(gbufferProjection * vec4(viewPos + refractDir, 1.0)) * 0.5 + 0.5;
                                
                                vec2 refractOffset = refractClipPos.xy - screenUV;

                                refractOffset *= 16.0 * saturate(0.5 * refractDist);
                                refractUV += refractOffset * 0.01 * RefractionStrengthF;
                                
                                vec2 alphaXY = saturate(10.0 * abs(vec2(0.5) - refractUV) - 4.0);
                                float rf = smoothstep(0.0, 1.0, 1.0 - maxOf(alphaXY));
                                refractUV = mix(screenUV, refractUV, rf);
                            #else
                                vec2 stepSize = rcp(viewSize) * RefractionStrengthF * 100.0;
                                refractUV -= (viewNormal.xz - vec2(0.0, 0.5)) * stepSize * saturate(refractDist);
                            #endif

                            refractOpaqueScreenDepth = textureLod(depthtex1, refractUV, 0).r;
                            refractOpaqueScreenDepthLinear = linearizeDepthFast(refractOpaqueScreenDepth, near, far);

                            #ifdef WATER_REFRACTION_FANCY
                                //vec2 startUV = refractUV;
                                // vec2 d = refractUV - screenUV;
                                // vec2 dp = d * viewSize;

                                // float stepCount = abs(dp.x) > abs(dp.y) ? abs(dp.x) : abs(dp.y);

                                // if (stepCount > 1.0) {
                                //     vec2 step = d / stepCount;

                                //     float traceDepth = 0.0;
                                //     for (int i = 0; i <= stepCount && traceDepth < waterSolidDepthFinal.x; i++) {
                                //         refractUV = screenUV + i * step;
                                //         refractOpaqueScreenDepth = textureLod(depthtex1, refractUV, 0).r;
                                //         refractOpaqueScreenDepthLinear = linearizeDepthFast(refractOpaqueScreenDepth, near, far);
                                //     }

                                //     //solidViewDepthLinear = solidViewDepth;//linearizeDepthFast(solidViewDepth, near, far);
                                // }
                            #else
                                if (refractOpaqueScreenDepthLinear < lightData.transparentScreenDepthLinear) {
                                    // reset UV & depths to original point
                                    refractUV = screenUV;
                                    //refractUV = (refractUV + screenUV) * 0.5;
                                    refractOpaqueScreenDepth = lightData.opaqueScreenDepth;
                                    refractOpaqueScreenDepthLinear = lightData.opaqueScreenDepthLinear;
                                }
                            #endif
                        #endif

                        refractColor = textureLod(BUFFER_HDR_OPAQUE, refractUV, 0).rgb / sceneExposure;
                    }
                    else {
                        // TIR
                        refractUV = screenUV;
                        refractOpaqueScreenDepth = lightData.transparentScreenDepth;
                        refractOpaqueScreenDepthLinear = lightData.transparentScreenDepthLinear;
                    }

                    vec3 waterOpaqueClipPos = vec3(refractUV, refractOpaqueScreenDepth) * 2.0 - 1.0;
                    vec3 waterOpaqueViewPos = unproject(gbufferProjectionInverse * vec4(waterOpaqueClipPos, 1.0));

                    float waterOpaqueViewDist = length(waterOpaqueViewPos);
                    float waterViewDepthFinal = max(waterOpaqueViewDist - viewDist, 0.0);

                    #if defined SHADOW_ENABLED && SHADOW_TYPE != SHADOW_TYPE_NONE
                        vec3 waterOpaqueLocalPos = (gbufferModelViewInverse * vec4(waterOpaqueViewPos, 1.0)).xyz;

                        // WARN: This doesn't work right when the dFdxy pos is skewed by refraction
                        // vec3 dX = dFdx(waterOpaqueLocalPos);
                        // vec3 dY = dFdy(waterOpaqueLocalPos);
                        // vec3 geoNormal = normalize(cross(dX, dY));
                        // waterOpaqueLocalPos += geoNormal * waterOpaqueViewDist * SHADOW_NORMAL_BIAS * max(1.0 - lightData.geoNoL, 0.0);

                        #ifndef IRIS_FEATURE_SSBO
                            mat4 shadowModelViewEx = BuildShadowViewMatrix();
                        #endif

                        vec3 waterOpaqueShadowViewPos = (shadowModelViewEx * vec4(waterOpaqueLocalPos, 1.0)).xyz;

                        vec3 waterOpaqueShadowPos;
                        float waterOpaqueShadowDepth;
                        float waterTransparentShadowDepth;

                        #if SHADOW_TYPE == SHADOW_TYPE_CASCADED
                            vec3 waterShadowPos[4];
                            waterShadowPos[0] = (cascadeProjection[0] * vec4(waterOpaqueShadowViewPos, 1.0)).xyz;
                            waterShadowPos[1] = (cascadeProjection[1] * vec4(waterOpaqueShadowViewPos, 1.0)).xyz;
                            waterShadowPos[2] = (cascadeProjection[2] * vec4(waterOpaqueShadowViewPos, 1.0)).xyz;
                            waterShadowPos[3] = (cascadeProjection[3] * vec4(waterOpaqueShadowViewPos, 1.0)).xyz;

                             // TODO: overlap should not be 0!
                            int waterCascade = GetShadowSampleCascade(waterShadowPos, 0.0);

                            if (waterCascade >= 0) {
                                waterOpaqueShadowPos = waterShadowPos[waterCascade] * 0.5 + 0.5;
                                waterOpaqueShadowPos.xy = waterOpaqueShadowPos.xy * 0.5 + shadowProjectionPos[waterCascade];

                                // float waterOpaqueShadowDepth = GetNearestOpaqueDepth(waterOpaqueShadowPos, vec2(0.0));
                                // float waterTransparentShadowDepth = GetNearestTransparentDepth(waterOpaqueShadowPos, vec2(0.0));
                                // TODO: This should be using the lines above, but that requires calulcating waterShadowPos 4x!
                                waterOpaqueShadowDepth = SampleOpaqueDepth(waterOpaqueShadowPos.xy, vec2(0.0));
                                waterTransparentShadowDepth = SampleTransparentDepth(waterOpaqueShadowPos.xy, vec2(0.0));
                            }
                            else {
                                // TODO: IDK?!
                                waterOpaqueShadowPos = vec3(0.0);
                                waterOpaqueShadowDepth = 0.0;
                                waterTransparentShadowDepth = 0.0;
                            }

                            float ShadowMaxDepth = far * 3.0;
                        #else
                            #ifndef IRIS_FEATURE_SSBO
                                mat4 shadowProjectionEx = BuildShadowProjectionMatrix();
                            #endif
                        
                            waterOpaqueShadowPos = (shadowProjectionEx * vec4(waterOpaqueShadowViewPos, 1.0)).xyz;

                            waterOpaqueShadowPos = distort(waterOpaqueShadowPos) * 0.5 + 0.5;

                            waterOpaqueShadowDepth = SampleOpaqueDepth(waterOpaqueShadowPos.xy, vec2(0.0));
                            waterTransparentShadowDepth = SampleTransparentDepth(waterOpaqueShadowPos.xy, vec2(0.0));

                            float ShadowMaxDepth = far * 2.0;
                        #endif

                        #ifdef PHYSICS_OCEAN
                            // IDK WTF is wrong here, but this breaks with PhysicsMod ocean
                            const float waterShadowDepth = 0.0;
                        #else
                            float waterShadowDepth = max(waterOpaqueShadowPos.z - waterTransparentShadowDepth, 0.0) * ShadowMaxDepth;
                        #endif
                    #else
                        const float waterShadowDepth = 0.0;
                    #endif

                    //uvec4 deferredData = texelFetch(BUFFER_DEFERRED, ivec2(gl_FragCoord.xy), 0);
                    //vec4 waterLightingMap = unpackUnorm4x8(deferredData.a);
                    //float waterGeoNoL = 1.0;//waterLightingMap.z * 2.0 - 1.0; //lightData.geoNoL;

                    // TODO: This should be based on the refracted opaque fragment!
                    #if SHADOW_TYPE == SHADOW_TYPE_CASCADED
                        float waterShadowBias = lightData.shadowBias[lightData.shadowCascade];
                    #else
                        float waterShadowBias = lightData.shadowBias;
                    #endif

                    refractColor *= max(1.0 - sunF, 0.0);

                    // sun absorption
                    float sunVerticalDepth = waterViewDepthFinal * max(-localViewDir.y, 0.0);
                    float fakeSunDist = sunVerticalDepth / max(localLightDir.y, EPSILON);
                    refractColor *= exp(-fakeSunDist * waterExtinctionInv);
                    
                    #if defined WATER_VL_ENABLED && defined SHADOW_ENABLED && SHADOW_TYPE != SHADOW_TYPE_NONE
                        vec3 vlScatter, vlExt;
                        float minWaterVLDist = min(viewDist, 60.0);
                        float maxWaterVLDist = min(waterOpaqueViewDist, min(shadowDistance, viewDist + 64.0));
                        GetWaterVolumetricLighting(vlScatter, vlExt, waterScatteringF, localViewDir, minWaterVLDist, maxWaterVLDist);
                        refractColor = refractColor * vlExt + vlScatter;
                    #else
                        // view absorption
                        refractColor *= exp(-waterViewDepthFinal * waterExtinctionInv);

                        vec3 waterFogColor = GetWaterFogColor(waterSunColorEye, waterMoonColorEye, waterScatteringF);
                        ApplyWaterFog(refractColor, waterFogColor, waterViewDepthFinal);
                    #endif

                    // #if defined WATER_VL_ENABLED && defined SHADOW_ENABLED && SHADOW_TYPE != SHADOW_TYPE_NONE
                    //     refractColor += vlScatter;
                    // #endif
                    
                    // TODO: refract out shadowing
                    refractColor *= max(1.0 - iblF, 0.0);

                    ambient *= material.albedo.a;
                    diffuse = mix(refractColor, diffuse, material.albedo.a);
                    final.a = 1.0; //saturate(10.0*waterViewDepthFinal - 0.2);
                }
                else {
                    //vec3 waterFogColor = GetWaterFogColor(waterSunColorEye, waterMoonColorEye, waterScatteringF);
                    ambient *= material.albedo.a;
                    diffuse *= material.albedo.a;
                    final.a = mix(maxOf(iblF), 1.0, material.albedo.a);

                    if (dot(refractDir, refractDir) < EPSILON) {
                        iblSpec = reflectColor;
                        reflectF = 1.0;

                        final.a = 1.0;//0.8 + 0.2 * final.a;
                    }
                    else {
                        //final.a = maxOf(iblF);
                    }
                }
            }
        #endif

        //diffuse *= metalDarkF;
        ambient *= metalDarkF;

        vec3 emissive = material.albedo.rgb * pow(material.emission, EMISSIVE_POWER) * EmissionLumens;

        //return vec4(ambient, 1.0);
        //return vec4(final.rgb * (ambient * (1.0 - iblF) * occlusion), 1.0);

        // #if !(defined SKY_ENABLED && defined SHADOW_ENABLED && SHADOW_TYPE != SHADOW_TYPE_NONE)
        //     diffuse *= occlusion;
        // #endif

        final.rgb = final.rgb * (ambient * occlusion * (1.0 - iblF))
            + diffuse + emissive
            + (specular + iblSpec) * specularTint;

        //#ifdef RENDER_WATER
            if (isEyeInWater == 0) {
                #ifndef SKY_VL_ENABLED
                    float fogF = 1.0;
                    #ifdef RENDER_WATER
                        if (materialId == MATERIAL_WATER)
                            fogF = 1.0 - reflectF;
                    #endif

                    #ifdef SKY_ENABLED
                        vec3 localLightDir = GetShadowLightLocalDir();
                        float VoL = dot(localLightDir, localViewDir);

                        vec4 scatteringTransmittance = GetFancyFog(localPos, localSunDir, VoL);
                        final.rgb = final.rgb * scatteringTransmittance.a + scatteringTransmittance.rgb;
                        //final = mix(final, vec4(final.rgb, 1.0), fogF);
                        // TODO: increase alpha with fog
                    #else
                        float fogFactor;
                        vec3 fogColorFinal;
                        GetVanillaFog(lightData, viewPos, fogColorFinal, fogFactor);
                        ApplyFog(final, fogColorFinal, fogFactor * fogF, 1.0/255.0);
                    #endif
                #endif
            }
        //#endif

        return final;
    }
#endif
