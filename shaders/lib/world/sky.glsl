//const float[5] moonPhaseLevels = float[](0.50, 0.65, 0.80, 0.90, 1.00);

#if SHADER_PLATFORM == PLATFORM_OPTIFINE && (defined RENDER_SKYBASIC || defined RENDER_SKYTEXTURED || defined RENDER_CLOUDS)
    // by BuilderBoy
    vec3 GetFixedSunPosition() {
        const vec2 sunRotationData = vec2(cos(sunPathRotation * 0.01745329251994), -sin(sunPathRotation * 0.01745329251994));

        float ang = fract(worldTime / 24000.0 - 0.25);
        ang = (ang + (cos(ang * PI) * -0.5 + 0.5 - ang) / 3.0) * (2.0*PI); //0-2pi, rolls over from 2pi to 0 at noon.

        return mat3(gbufferModelView) * vec3(-sin(ang), cos(ang) * sunRotationData);
    }
#endif

// returns: x:sun y:moon
vec2 GetSkyLightLevels() {
    vec3 moonLightDir = normalize(moonPosition);

    #if SHADER_PLATFORM == PLATFORM_OPTIFINE && (defined RENDER_SKYBASIC || defined RENDER_SKYTEXTURED || defined RENDER_CLOUDS)
        vec3 upDir = gbufferModelView[1].xyz;
        vec3 sunLightDir = GetFixedSunPosition();
    #else
        vec3 upDir = normalize(upPosition);
        vec3 sunLightDir = normalize(sunPosition);
    #endif

    return vec2(
        dot(upDir, sunLightDir),
        dot(upDir, moonLightDir));
}

// float GetMoonPhaseLevel() {
//     return moonPhaseLevels[abs(moonPhase - 4)];
// }

// float GetSunLightLevel(const in float skyLightLevel) {
//     //float rainLevel = 1.0 - 0.85 * rainStrength;

//     //float angularDiameter = mix(0.526, 0.545, max(skyLightLevel, 0.0));
//     //return GetSolidAngle(angularDiameter);

//     // TODO: This angle is wrong and sucks
//     return pow(max(skyLightLevel, 0.0), 0.4);

//     //return pow4(max(cos(clamp(pow4(x), -PI, PI)), 0));
// }

// float GetMoonLightLevel(const in float skyLightLevel) {
//     //float rainLevel = 1.0 - 0.9 * rainStrength;
//     //float moonPhaseLevel = moonPhaseLevels[abs(moonPhase-4)];

//     //float angularDiameter = mix(0.49, 0.55, max(skyLightLevel, 0.0));
//     //return GetSolidAngle(angularDiameter) * moonPhaseLevel;

//     // TODO: This angle is wrong and sucks
//     return pow(max(skyLightLevel, 0.0), 0.4);// * moonPhaseLevel;

//     //return pow4(max(cos(clamp(pow4(x), -PI, PI)), 0)) * moonPhaseLevel;
// }

// returns: x:sun y:moon temp in kelvin
// vec2 GetSkyLightTemp(const in vec2 skyLightLevels) {
//     const float temp_sunrise = 2000; // 2000
//     const float temp_day = 5500; // 5000
//     const float temp_rain = 7600; // 8000
//     const float temp_moon = 4600; // 5500

//     float sunElevation = pow(max(skyLightLevels.x, 0.0), 0.5);
//     float sunTemp = mix(temp_sunrise, temp_day, sunElevation);
//     sunTemp = mix(sunTemp, temp_rain, rainStrength);

//     return vec2(sunTemp, temp_moon);
// }

// vec3 GetSunLightColor(const in float temp, const in float skyLightLevel) {
//     return blackbody(temp) * GetSunLightLevel(skyLightLevel);
// }

// vec3 GetMoonLightColor(const in float temp, const in float skyLightLevel) {
//     return blackbody(temp) * GetMoonLightLevel(skyLightLevel);
// }

// float GetMoonLux() {
//     float moonPhaseLevel = GetMoonPhaseLevel();
//     return mix(MoonLux, MoonOvercastLux, rainStrength) * moonPhaseLevel;
// }

// float GetMoonLightLux(const in float skyLightLevel) {
//     return GetMoonLightLevel(skyLightLevel) * GetMoonLux();
// }

// vec3 GetMoonLightLuxColor(const in float temp, const in float skyLightLevel) {
//     return GetMoonLightColor(temp, skyLightLevel) * GetMoonLux();
// }

// float GetSunLightLuminance(const in float skyLightLevel) {
//     float luminance = mix(DaySkyLumen, DaySkyOvercastLumen, rainStrength);
//     return GetSunLightLevel(skyLightLevel) * luminance;
// }

// float GetMoonLightLuminance(const in float skyLightLevel) {
//     float luminance = mix(NightSkyLumen, NightSkyOvercastLumen, rainStrength);
//     return GetMoonLightLevel(skyLightLevel) * luminance;
// }

// float GetSkyLightLuminance(const in vec2 skyLightLevels) {
//     vec2 skyLightTemp = GetSkyLightTemp(skyLightLevels);

//     float sunLum = GetSunLightLuminance(skyLightLevels.x);
//     float moonLum = GetMoonLightLuminance(skyLightLevels.y);

//     return sunLum + moonLum;
// }

#ifdef RENDER_FRAG
    #ifdef WORLD_OVERWORLD
        const vec3 skyTint = vec3(0.6, 0.8, 1.0);
    #else
        const vec3 skyTint = vec3(1.0);
    #endif

    float GetVanillaSkyFog(const in float x, const in float w) {
        return w / (x * x + w);
    }

    vec3 GetVanillaSkyLuminance(const in vec3 viewDir) {//, const in vec3 sunTransmittance, const in vec3 moonTransmittance) {
        vec2 skyLightLevels = GetSkyLightLevels();
        //vec3 sunSkyLumen = 0.001*sunTransmittance * sunLumen;//GetSunLightLuminance(skyLightLevels.x);
        //float moonSkyLumen = GetMoonLightLuminance(skyLightLevels.y);
        //float skyLumen = 8000;// sunSkyLumen + moonSkyLumen;

        float lightLevel = saturate(skyLightLevels.x);
        float dayNightF = smoothstep(0.1, 0.6, lightLevel);
        float daySkyLumenFinal = mix(DaySkyLumen, DaySkyOvercastLumen, rainStrength);
        float nightSkyLumenFinal = mix(NightSkyLumen, NightSkyOvercastLumen, rainStrength);
        float skyLumen = mix(nightSkyLumenFinal, daySkyLumenFinal, dayNightF);
        
        // Darken atmosphere
        skyLumen *= 1.0 - saturate((cameraPosition.y - SEA_LEVEL) / (ATMOSPHERE_LEVEL - SEA_LEVEL));

        vec3 skyColorLinear = RGBToLinear(skyColor);
        if (dot(skyColorLinear, skyColorLinear) < EPSILON) skyColorLinear = vec3(1.0);
        skyColorLinear = normalize(skyColorLinear);

        vec3 fogColorLinear = RGBToLinear(fogColor);
        if (dot(fogColorLinear, fogColorLinear) < EPSILON) fogColorLinear = vec3(1.0);
        fogColorLinear = normalize(fogColorLinear) * 0.8;

        // #ifdef RENDER_SKYBASIC
        //     if (isEyeInWater == 1) {
        //         // TODO: change fogColor to water
        //         fogColorLinear = vec3(0.0178, 0.0566, 0.0754);
        //     }
        // #endif

        fogColorLinear *= 1.0 - 0.8 * rainStrength;

        #if SHADER_PLATFORM == PLATFORM_OPTIFINE && (defined RENDER_SKYBASIC || defined RENDER_SKYTEXTURED || defined RENDER_CLOUDS)
            vec3 upDir = gbufferModelView[1].xyz;
        #else
            vec3 upDir = normalize(upPosition);
        #endif

        float VoUm = max(dot(viewDir, upDir), 0.0);
        float skyFogFactor = GetVanillaSkyFog(VoUm, 0.25);
        return mix(skyColorLinear, fogColorLinear, skyFogFactor) * skyLumen;// * skyTint;
    }

    vec3 GetVanillaSkyLux(const in vec3 viewDir) {
        //float sunLightLux = GetSunLightLux(skyLightLevels.x);
        //float moonLightLux = GetMoonLightLux(skyLightLevels.y);
        //float skyLux = sunLightLux + moonLightLux;

        vec2 skyLightLevels = GetSkyLightLevels();
        float lightLevel = saturate(skyLightLevels.x);
        float dayNightF = smoothstep(0.0, 0.6, lightLevel);
        vec3 skyLuxColor = mix(vec3(GetMoonLux()), GetSunLuxColor(), dayNightF);
        
        vec3 skyColorLinear = RGBToLinear(skyColor);
        if (dot(skyColorLinear, skyColorLinear) < EPSILON) skyColorLinear = vec3(1.0);
        skyColorLinear = normalize(skyColorLinear);

        vec3 fogColorLinear = RGBToLinear(fogColor);
        if (dot(fogColorLinear, fogColorLinear) < EPSILON) fogColorLinear = vec3(1.0);
        fogColorLinear = normalize(fogColorLinear) * 0.8;

        #ifdef RENDER_SKYBASIC
            if (isEyeInWater == 1) {
                // TODO: change fogColor to water
                fogColorLinear = vec3(0.0178, 0.0566, 0.0754);
            }
        #endif

        fogColorLinear *= 1.0 - 0.8 * rainStrength;

        #if SHADER_PLATFORM == PLATFORM_OPTIFINE && (defined RENDER_SKYBASIC || defined RENDER_SKYTEXTURED)
            vec3 upDir = gbufferModelView[1].xyz;
        #else
            vec3 upDir = normalize(upPosition);
        #endif
        
        float VoUm = max(dot(viewDir, upDir), 0.0);
        float skyFogFactor = GetVanillaSkyFog(VoUm, 0.25);
        return mix(skyColorLinear, fogColorLinear, skyFogFactor) * skyLuxColor;
    }
#endif
