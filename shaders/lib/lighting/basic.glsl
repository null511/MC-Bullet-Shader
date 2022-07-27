#ifdef RENDER_VERTEX
    void BasicVertex(out vec3 viewPos) {
        vec3 pos = gl_Vertex.xyz;
        vec3 normal = gl_Normal;

        #if defined RENDER_TERRAIN || defined RENDER_WATER
            float skyLight = saturate((lmcoord.y - (0.5/16.0)) / (15.0/16.0));
        #endif

        #if defined RENDER_TERRAIN && defined ENABLE_WAVING
            if (mc_Entity.x >= 10001.0 && mc_Entity.x <= 10004.0) {
                float wavingRange = GetWavingRange(skyLight);
                pos += GetWavingOffset(wavingRange);
            }
        #endif

        #ifdef RENDER_WATER
            if (mc_Entity.x == 100.0) {
                if (gl_Normal.y > 0.01) {
                    //the bottom face doesn't have a backface.
                }
                else if (gl_Normal.y < -0.01) {
                    //sneaky back face of top needs weird checks.
                    //if (at_midBlock.y < 30.75) {
                    //    gl_Position = vec4(10.0);
                    //    return;
                    //}
                }
                else {
                    if (dot(gl_Normal, at_midBlock) > 0.0) {
                        gl_Position = vec4(10.0);
                        return;
                    }
                }

                #if WATER_WAVE_TYPE == WATER_WAVE_VERTEX && !defined WORLD_NETHER
                    if (gl_Normal.y > 0.01) {
                        float windSpeed = GetWindSpeed();
                        float waveSpeed = GetWaveSpeed(windSpeed, skyLight);
                        
                        float waterWorldScale = WATER_SCALE * rcp(2.0*WATER_RADIUS);
                        vec2 waterWorldPos = waterWorldScale * (pos.xz + cameraPosition.xz);
                        float depth = GetWaves(waterWorldPos, waveSpeed, WATER_OCTAVES_VERTEX);
                        pos.y -= (1.0 - depth) * WATER_WAVE_DEPTH;

                        #ifndef WATER_FANCY
                            vec2 waterWorldPosX = waterWorldPos + vec2(waterWorldScale, 0.0);
                            float depthX = GetWaves(waterWorldPosX, waveSpeed, WATER_OCTAVES_VERTEX);
                            vec3 pX = vec3(1.0, 0.0, (depthX - depth) * WATER_WAVE_DEPTH);

                            vec2 waterWorldPosY = waterWorldPos + vec2(0.0, waterWorldScale);
                            float depthY = GetWaves(waterWorldPosY, waveSpeed, WATER_OCTAVES_VERTEX);
                            vec3 pY = vec3(0.0, 1.0, (depthY - depth) * WATER_WAVE_DEPTH);

                            normal = normalize(cross(pX, pY)).xzy;
                        #endif
                    }
                #endif
            }
        #endif

        viewPos = (gl_ModelViewMatrix * vec4(pos, 1.0)).xyz;
        viewNormal = normalize(gl_NormalMatrix * normal);
        gl_Position = gl_ProjectionMatrix * vec4(viewPos, 1.0);

        #if defined RENDER_TEXTURED || defined RENDER_WEATHER || defined RENDER_BEACONBEAM
            // TODO: extract billboard direction from view matrix?

            geoNoL = 1.0;
        #else
            #ifdef SHADOW_ENABLED
                vec3 lightDir = normalize(shadowLightPosition);
                geoNoL = dot(lightDir, viewNormal);
            #else
                geoNoL = 1.0;
            #endif
        #endif

        #if defined SHADOW_ENABLED && !defined RENDER_SHADOW && SHADOW_TYPE != SHADOW_TYPE_NONE
            #if defined SHADOW_PARTICLES || (!defined RENDER_TEXTURED && !defined RENDER_WEATHER)
                vec3 localPos = pos;

                #if defined RENDER_ENTITIES || defined RENDER_BLOCK
                    localPos = (gbufferModelViewInverse * vec4(localPos, 1.0)).xyz;
                #endif

                vec3 viewDir = -normalize(viewPos);
                ApplyShadows(localPos, viewDir);
            #endif
        #endif

        #ifdef AF_ENABLED
            vec2 spriteRadius = abs(texcoord - mc_midTexCoord.xy);
            vec2 bottomLeft = mc_midTexCoord.xy - spriteRadius;
            vec2 topRight = mc_midTexCoord.xy + spriteRadius;
            spriteBounds = vec4(bottomLeft, topRight);
        #endif
    }
#endif

#ifdef RENDER_FRAG
    vec3 GetSkyAmbientLight(const in vec3 normal) {
        vec3 upDir = normalize(upPosition);
        vec3 sunLightDir = normalize(sunPosition);
        vec3 moonLightDir = normalize(moonPosition);

        vec2 skyLightLevels;
        skyLightLevels.x = dot(upDir, sunLightDir);
        skyLightLevels.y = dot(upDir, moonLightDir);

        vec2 skyLightTemp = GetSkyLightTemp(skyLightLevels);

        vec3 sunLightLux = GetSunLightLuxColor(skyLightTemp.x, skyLightLevels.x);
        sunLightLux *= dot(normal, sunLightDir) * 0.5 + 0.5;

        vec3 moonLightLux = GetMoonLightLuxColor(skyLightTemp.y, skyLightLevels.y);
        moonLightLux *= dot(normal, moonLightDir) * 0.5 + 0.5;

        vec3 skyLightLux = RGBToLinear(skyColor); // TODO: multiply by sky lux?

        return 0.1 * (skyLightLux + sunLightLux + moonLightLux);
    }
#endif
