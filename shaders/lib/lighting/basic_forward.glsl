#ifdef RENDER_VERTEX
    <empty>
#endif

#ifdef RENDER_FRAG
    vec4 BasicLighting() {
        vec4 albedo = texture(gtexture, texcoord);

        #if !defined RENDER_TEXTURED && !defined RENDER_WEATHER
            if (albedo.a < alphaTestRef) discard;
        #endif

        albedo.rgb = RGBToLinear(albedo.rgb * glcolor.rgb);

        float blockLight = clamp((lmcoord.x - (0.5/16.0)) / (15.0/16.0), 0.0, 1.0);
        float skyLight = clamp((lmcoord.y - (0.5/16.0)) / (15.0/16.0), 0.0, 1.0);

        //blockLight = blockLight*blockLight*blockLight;
        //skyLight = skyLight*skyLight*skyLight;

        float shadow = step(EPSILON, geoNoL) * step(1.0 / 32.0, skyLight);
        //vec3 lightColor = skyLightColor;

        vec3 skyAmbient = vec3(pow(skyLight, 5.0));
        #ifdef SKY_ENABLED
            skyAmbient *= GetSkyAmbientLight(viewNormal);
        #endif

        float blockAmbient = pow(blockLight, 5.0) * BlockLightLux;
        vec3 ambient = 0.1 + blockAmbient + skyAmbient;

        vec3 shadowColorMap = vec3(1.0);
        #if defined SHADOW_ENABLED && SHADOW_TYPE != SHADOW_TYPE_NONE
            #if defined SHADOW_PARTICLES || (!defined RENDER_TEXTURED && !defined RENDER_WEATHER)
                if (shadow > EPSILON) {
                    #if SHADOW_TYPE == SHADOW_TYPE_CASCADED
                        shadow *= GetShadowing(shadowPos);
                    #else
                        shadow *= GetShadowing(shadowPos, shadowBias);
                    #endif

                    // #if SHADOW_COLORS == 1
                    //     vec3 shadowColor = GetShadowColor();

                    //     shadowColor = mix(vec3(1.0), shadowColor, shadow);

                    //     //also make colors less intense when the block light level is high.
                    //     shadowColor = mix(shadowColor, vec3(1.0), blockLight);

                    //     lightColor *= shadowColor;
                    // #endif

                    skyLight = max(skyLight, shadow);
                }

                #ifdef SHADOW_COLOR
                    #if SHADOW_TYPE == SHADOW_TYPE_CASCADED
                        shadowColorMap = GetShadowColor(shadowPos);
                    #else
                        shadowColorMap = GetShadowColor(shadowPos.xyz, shadowBias);
                    #endif
                    
                    shadowColorMap = RGBToLinear(shadowColorMap);
                #endif
            #endif
        #else
            shadow = glcolor.a;
        #endif
        
        //vec2 lmCoord = vec2(blockLight, skyLight) * (15.0/16.0) + (0.5/16.0);
        //vec3 lmColor = RGBToLinear(texture(lightmap, lmCoord).rgb);

        vec4 final = albedo;
        final.rgb *= ambient;

        #ifdef SKY_ENABLED
            final.rgb += albedo.rgb * skyLightColor * shadowColorMap * shadow;
        #endif

        ApplyFog(final, viewPos, skyLight, EPSILON);

        return final;
    }
#endif
