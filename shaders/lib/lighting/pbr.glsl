#ifdef RENDER_VERTEX
    void PbrVertex(const in mat3 matViewTBN) {
        #ifdef PARALLAX_ENABLED
            tanViewPos = matViewTBN * viewPos;

            vec2 coordMid = (gl_TextureMatrix[0] * mc_midTexCoord).xy;
            vec2 coordNMid = texcoord - coordMid;

            atlasBounds[0] = min(texcoord, coordMid - coordNMid);
            atlasBounds[1] = abs(coordNMid) * 2.0;
 
            localCoord = sign(coordNMid) * 0.5 + 0.5;
        #endif
    }
#endif

#ifdef RENDER_FRAG
    float F_schlick(const in float cos_theta, const in float f0, const in float f90)
    {
        return f0 + (f90 - f0) * pow(1.0 - cos_theta, 5.0);
    }

    float SchlickRoughness(const in float f0, const in float cos_theta, const in float rough) {
        return f0 + (max(1.0 - rough, f0) - f0) * pow(clamp(1.0 - cos_theta, 0.0, 1.0), 5.0);
    }

    vec3 F_conductor(const in float VoH, const in float n1, const in vec3 n2, const in vec3 k)
    {
        vec3 eta = n2 / n1;
        vec3 eta_k = k / n1;

        float cos_theta2 = VoH * VoH;
        float sin_theta2 = 1.0f - cos_theta2;
        vec3 eta2 = eta * eta;
        vec3 eta_k2 = eta_k * eta_k;

        vec3 t0 = eta2 - eta_k2 - sin_theta2;
        vec3 a2_plus_b2 = sqrt(t0 * t0 + 4.0f * eta2 * eta_k2);
        vec3 t1 = a2_plus_b2 + cos_theta2;
        vec3 a = sqrt(0.5f * (a2_plus_b2 + t0));
        vec3 t2 = 2.0f * a * VoH;
        vec3 rs = (t1 - t2) / (t1 + t2);

        vec3 t3 = cos_theta2 * a2_plus_b2 + sin_theta2 * sin_theta2;
        vec3 t4 = t2 * sin_theta2;
        vec3 rp = rs * (t3 - t4) / (t3 + t4);

        return 0.5f * (rp + rs);
    }

    float GGX(const in float NoH, const in float roughL)
    {
        const float a = NoH * roughL;
        const float k = roughL / (1.0 - NoH * NoH + a * a);
        return k * k * (1.0 / PI);
    }

    float GGX_Fast(const in float NoH, const in vec3 NxH, const in float roughL)
    {
        float a = NoH * roughL;
        float k = roughL / (dot(NxH, NxH) + a * a);
        return min(k * k * invPI, 65504.0);
    }

    float SmithGGXCorrelated(const in float NoV, const in float NoL, const in float roughL) {
        float a2 = roughL * roughL;
        float GGXV = NoL * sqrt(max(NoV * NoV * (1.0 - a2) + a2, EPSILON));
        float GGXL = NoV * sqrt(max(NoL * NoL * (1.0 - a2) + a2, EPSILON));
        return clamp(0.5 / (GGXV + GGXL), 0.0, 1.0);
    }

    float SmithGGXCorrelated_Fast(const in float NoV, const in float NoL, const in float roughL) {
        float GGXV = NoL * (NoV * (1.0 - roughL) + roughL);
        float GGXL = NoV * (NoL * (1.0 - roughL) + roughL);
        return clamp(0.5 / (GGXV + GGXL), 0.0, 1.0);
    }

    float SmithHable(const in float LdotH, const in float alpha)
    {
        return 1.0 / mix(LdotH * LdotH, 1.0, alpha * alpha * 0.25);
    }

    vec3 GetSpecularBRDF(const in PbrMaterial material, const in float NoV, const in float NoL, const in float NoH, const in float VoH, const in float roughL)
    {
        // Fresnel
        vec3 F;
        if (material.hcm >= 0) {
            vec3 iorN, iorK;
            GetHCM_IOR(material.albedo.rgb, material.hcm, iorN, iorK);
            F = F_conductor(VoH, IOR_AIR, iorN, iorK);
        }
        else {
            F = vec3(SchlickRoughness(material.f0, VoH, roughL));
        }

        // Distribution
        float D = GGX(NoH, roughL);

        // Geometric Visibility
        //float G = SmithHable(LoH, roughL);
        float G = SmithGGXCorrelated(NoV, NoL, roughL);

        return clamp(D * F * G, 0.0, 6.0);
    }

    vec3 GetDiffuse_Burley(const in vec3 albedo, const in float NoV, const in float NoL, const in float LoH, const in float roughL)
    {
        float f90 = 0.5 + 2.0 * roughL * LoH * LoH;
        float light_scatter = F_schlick(NoL, 1.0, f90);
        float view_scatter = F_schlick(NoV, 1.0, f90);
        return (albedo * invPI) * light_scatter * view_scatter * NoL;
    }

    vec3 GetSubsurface(const in vec3 albedo, const in float NoV, const in float NoL, const in float LoH, const in float roughL) {
        float sssF90 = roughL * pow(LoH, 2);
        float sssF_In = F_schlick(NoV, 1.0, sssF90);
        float sssF_Out = F_schlick(NoL, 1.0, sssF90);

        return (1.25 * albedo * invPI) * (sssF_In * sssF_Out * (1.0 / (NoV + NoL) - 0.5) + 0.5) * NoL;
    }

    vec3 GetDiffuseBSDF(const in PbrMaterial material, const in float NoV, const in float NoL, const in float LoH, const in float roughL) {
        vec3 diffuse = GetDiffuse_Burley(material.albedo.rgb, NoV, NoL, LoH, roughL);

        #ifdef SSS_ENABLED
            if (material.scattering < EPSILON) return diffuse;

            vec3 subsurface = GetSubsurface(material.albedo.rgb, NoV, NoL, LoH, roughL);
            return (1.0 - material.scattering) * diffuse + material.scattering * subsurface;
        #else
            return diffuse;
        #endif
    }


    // Common Usage Pattern

    #ifdef HANDLIGHT_ENABLED
        const vec3 handLightColor = vec3(0.851, 0.712, 0.545);

        float GetHandLightAttenuation(const in float lightLevel, const in float lightDist) {
            float diffuseAtt = max(0.16*lightLevel - 0.5*lightDist, 0.0);
            return diffuseAtt*diffuseAtt;
        }

        void ApplyHandLighting(inout vec3 diffuse, inout vec3 specular, const in PbrMaterial material, const in vec3 viewNormal, const in vec3 viewPos, const in vec3 viewDir, const in float NoVm, const in float roughL) {
            vec3 lightPos = handOffset - viewPos.xyz;
            vec3 lightDir = normalize(lightPos);

            float NoLm = max(dot(viewNormal, lightDir), EPSILON);
            if (NoLm < EPSILON) return;

            float lightDist = length(lightPos);
            float attenuation = GetHandLightAttenuation(heldBlockLightValue, lightDist);
            if (attenuation < EPSILON) return;

            vec3 halfDir = normalize(lightDir + viewDir);
            float LoHm = max(dot(lightDir, halfDir), EPSILON);

            float NoHm = max(dot(viewNormal, halfDir), EPSILON);
            //float NoVm = max(dot(viewNormal, viewDir), EPSILON);
            float VoHm = max(dot(viewDir, halfDir), EPSILON);
            //vec3 NxH = cross(viewNormal, halfDir);

            diffuse += GetDiffuseBSDF(material, NoVm, NoLm, LoHm, roughL) * attenuation * handLightColor;
            specular += GetSpecularBRDF(material, NoVm, NoLm, NoHm, VoHm, roughL) * attenuation * handLightColor;
        }
    #endif

    vec4 PbrLighting2(const in PbrMaterial material, const in vec2 lmValue, const in float shadow, const in float shadowSSS, const in vec3 viewPos) {
        vec3 viewNormal = normalize(material.normal);
        vec3 viewDir = -normalize(viewPos.xyz);

        #ifdef SHADOW_ENABLED
            vec3 viewLightDir = normalize(shadowLightPosition);
            float NoL = dot(viewNormal, viewLightDir);

            vec3 halfDir = normalize(viewLightDir + viewDir);
            float LoHm = max(dot(viewLightDir, halfDir), EPSILON);
        #else
            float NoL = 1.0;
            float LoHm = 1.0;
        #endif

        float NoLm = max(NoL, EPSILON);
        float NoVm = max(dot(viewNormal, viewDir), EPSILON);

        float rough = 1.0 - material.smoothness;
        float roughL = max(rough * rough, 0.005);

        float blockLight = (lmValue.x - (0.5/16.0)) / (15.0/16.0);
        float skyLight = (lmValue.y - (0.5/16.0)) / (15.0/16.0);

        // blockLight = blockLight*blockLight*blockLight;
        // skyLight = skyLight*skyLight*skyLight;

        // Increase skylight when in direct sunlight
        skyLight = max(skyLight, shadow);

        // Make areas without skylight fully shadowed (light leak fix)
        float lightLeakFix = step(1.0 / 32.0, skyLight);
        float shadowFinal = shadow * lightLeakFix;

        vec3 reflectColor = vec3(0.0);
        #ifdef SSR_ENABLED
            vec3 reflectDir = reflect(viewDir, viewNormal);
            vec2 reflectCoord = GetReflectCoord(reflectDir);

            ivec2 iTexReflect = ivec2(reflectCoord * vec2(viewWidth, viewHeight));
            reflectColor = texelFetch(BUFFER_HDR_PREVIOUS, iTexReflect, 0);
        #endif

        #if defined RSM_ENABLED && defined RENDER_DEFERRED
            vec2 viewSize = vec2(viewWidth, viewHeight);

            #if RSM_SCALE == 0 || defined RSM_UPSCALE
                ivec2 iuv = ivec2(texcoord * viewSize);
                vec3 rsmColor = texelFetch(BUFFER_RSM_COLOR, iuv, 0).rgb;
            #else
                const float rsm_scale = 1.0 / exp2(RSM_SCALE);
                vec3 rsmColor = texture2DLod(BUFFER_RSM_COLOR, texcoord * rsm_scale, 0).rgb;
            #endif
        #endif

        vec3 skyAmbient = GetSkyAmbientLight(viewNormal) * skyLight*skyLight; //skyLightColor;

        vec3 blockAmbient = 0.002 + max(vec3(blockLight*blockLight), skyAmbient);
        //return vec4(blockAmbient, 1.0);

        vec3 ambient = blockAmbient * material.occlusion;

        vec3 diffuseLight = skyLightColor * shadowFinal;

        #if defined RSM_ENABLED && defined RENDER_DEFERRED
            diffuseLight += 20.0 * rsmColor * skyLightColor * material.scattering;
        #endif

        vec3 diffuse = GetDiffuseBSDF(material, NoVm, NoLm, LoHm, roughL) * diffuseLight;

        vec3 specular = vec3(0.0);

        #ifdef SHADOW_ENABLED
            float NoHm = max(dot(viewNormal, halfDir), EPSILON);
            float VoHm = max(dot(viewDir, halfDir), EPSILON);
            //vec3 NxH = cross(viewNormal, halfDir);

            specular = GetSpecularBRDF(material, NoVm, NoLm, NoHm, VoHm, roughL) * skyLightColor * shadowFinal;
        #endif

        #ifdef HANDLIGHT_ENABLED
            if (heldBlockLightValue > EPSILON)
                ApplyHandLighting(diffuse, specular, material, viewNormal, viewPos.xyz, viewDir, NoVm, roughL);
        #endif

        #if defined RSM_ENABLED && defined RENDER_DEFERRED
            ambient += rsmColor * skyLightColor;
        #endif

        if (material.hcm >= 0) {
            if (material.hcm < 8) specular *= material.albedo.rgb;

            ambient *= HCM_AMBIENT;
            diffuse *= HCM_AMBIENT;
        }

        //ambient += minLight;

        float emissive = material.emission*material.emission * 256.0;

        vec4 final = material.albedo;
        final.rgb = final.rgb * (ambient + emissive) + diffuse + specular;

        #ifdef SSS_ENABLED
            //float ambientShadowBrightness = 1.0 - 0.5 * (1.0 - SHADOW_BRIGHTNESS);
            vec3 ambient_sss = skyAmbient * material.scattering * material.occlusion;

            // Transmission
            vec3 sss = (1.0 - shadowFinal) * shadowSSS * material.scattering * skyLightColor;// * max(-NoL, 0.0);
            final.rgb += material.albedo.rgb * invPI * (ambient_sss + sss) * 1.25;
        #endif

        #ifdef SHADOW_ENABLED
            if (final.a < 1.0 - EPSILON) {
                //float F = SchlickRoughness(0.04, VoHm, roughL);
                float F = F_schlick(NoVm, material.f0, 1.0);
                final.a = mix(final.a, 1.0, F);
            }
        #endif

        final.a = min(final.a + luminance(specular), 1.0);

        #if defined RENDER_DEFERRED && !defined ATMOSPHERE_ENABLED
            ApplyFog(final.rgb, viewPos.xyz, skyLight);
        #elif defined RENDER_GBUFFER
            #ifdef RENDER_WATER
                ApplyFog(final, viewPos.xyz, skyLight, EPSILON);
            #else
                ApplyFog(final, viewPos.xyz, skyLight, alphaTestRef);
            #endif
        #endif

        //return mix(final, reflectColor, 0.5);
        return final;
    }
#endif
