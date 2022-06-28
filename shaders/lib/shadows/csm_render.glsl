#extension GL_ARB_texture_gather : enable

const float tile_dist_bias_factor = 0.012288;

#ifdef RENDER_VERTEX
	void ApplyShadows(const in vec3 viewPos) {
        #ifndef SSS_ENABLED
            if (geoNoL > 0.0) {
        #endif
            #ifdef RENDER_SHADOW
                mat4 matShadowModelView = gl_ModelViewMatrix;
            #else
                mat4 matShadowModelView = shadowModelView;
            #endif

			vec3 localPos = (gbufferModelViewInverse * vec4(viewPos, 1.0)).xyz;
            vec3 shadowViewPos = (matShadowModelView * vec4(localPos, 1.0)).xyz;

            #if defined PARALLAX_ENABLED && !defined RENDER_SHADOW && defined PARALLAX_SHADOW_FIX
                vec3 viewDir = -normalize(viewPos);
                float geoNoV = dot(vNormal, viewDir);

                vec3 localViewDir = normalize(cameraPosition);
                vec3 parallaxLocalPos = localPos + (localViewDir / geoNoV) * PARALLAX_DEPTH;
                vec3 parallaxShadowViewPos = (matShadowModelView * vec4(parallaxLocalPos, 1.0)).xyz;
            #endif

            cascadeSizes[0] = GetCascadeDistance(0);
            cascadeSizes[1] = GetCascadeDistance(1);
            cascadeSizes[2] = GetCascadeDistance(2);
            cascadeSizes[3] = GetCascadeDistance(3);

            mat4 matShadowProjections[4];
            matShadowProjections[0] = GetShadowCascadeProjectionMatrix(0);
            matShadowProjections[1] = GetShadowCascadeProjectionMatrix(1);
            matShadowProjections[2] = GetShadowCascadeProjectionMatrix(2);
            matShadowProjections[3] = GetShadowCascadeProjectionMatrix(3);

			for (int i = 0; i < 4; i++) {
				shadowProjectionSizes[i] = 2.0 / vec2(
					matShadowProjections[i][0].x,
					matShadowProjections[i][1].y);
				
				shadowPos[i] = (matShadowProjections[i] * vec4(shadowViewPos, 1.0)).xyz;

				vec2 shadowCascadePos = GetShadowCascadeClipPos(i);
				shadowPos[i] = shadowPos[i] * 0.5 + 0.5;

				shadowPos[i].xy = shadowPos[i].xy * 0.5 + shadowCascadePos;

                #if defined PARALLAX_ENABLED && !defined RENDER_SHADOW && defined PARALLAX_SHADOW_FIX
                    // TODO: Get shadow position with max parallax offset
                    shadowParallaxPos[i] = (matShadowProjections[i] * vec4(parallaxShadowViewPos, 1.0)).xyz;
                    shadowParallaxPos[i] = shadowParallaxPos[i] * 0.5 + 0.5;

                    shadowParallaxPos[i].xy = shadowParallaxPos[i].xy * 0.5 + shadowCascadePos;
                #endif
			}

			shadowCascade = GetShadowCascade(matShadowProjections);
        #ifndef SSS_ENABLED
            }
            else {
                shadowCascade = -1;
            }
        #endif
	}
#endif

#ifdef RENDER_FRAG
	#define PCF_MAX_RADIUS 0.16

    const float cascadeTexSize = shadowMapSize * 0.5;
	const int pcf_sizes[4] = int[](4, 3, 2, 1);
	const int pcf_max = 4;

	float SampleDepth(const in vec2 shadowPos, const in vec2 offset) {
        #if !defined IS_OPTIFINE && defined SHADOW_ENABLE_HWCOMP
            return texture2D(shadowtex1, shadowPos + offset).r;
        #else
            return texture2D(shadowtex0, shadowPos + offset).r;
        #endif
	}

	float GetNearestDepth(const in vec3 shadowPos[4], const in vec2 blockOffset, out int cascade) {
		float depth = 1.0;
		cascade = -1;

		float shadowResScale = tile_dist_bias_factor * shadowPixelSize;

		for (int i = 0; i < 4; i++) {
			// Ignore if outside cascade bounds
			vec2 shadowTilePos = GetShadowCascadeClipPos(i);
			if (shadowPos[i].x < shadowTilePos.x || shadowPos[i].x >= shadowTilePos.x + 0.5) continue;
			if (shadowPos[i].y < shadowTilePos.y || shadowPos[i].y >= shadowTilePos.y + 0.5) continue;

			vec2 pixelPerBlockScale = (cascadeTexSize / shadowProjectionSizes[i]) * shadowPixelSize;
			
			vec2 pixelOffset = blockOffset * pixelPerBlockScale;
			float texDepth = SampleDepth(shadowPos[i].xy, pixelOffset);

			if (i != shadowCascade) {
				vec2 ratio = (shadowProjectionSizes[shadowCascade] / shadowProjectionSizes[i]) * shadowPixelSize;

				vec4 samples;
				samples.x = SampleDepth(shadowPos[i].xy, pixelOffset + vec2(-1.0, 0.0)*ratio);
				samples.y = SampleDepth(shadowPos[i].xy, pixelOffset + vec2( 1.0, 0.0)*ratio);
				samples.z = SampleDepth(shadowPos[i].xy, pixelOffset + vec2( 0.0,-1.0)*ratio);
				samples.w = SampleDepth(shadowPos[i].xy, pixelOffset + vec2( 0.0, 1.0)*ratio);

				texDepth = min(texDepth, samples.x);
				texDepth = min(texDepth, samples.y);
				texDepth = min(texDepth, samples.z);
				texDepth = min(texDepth, samples.w);
			}

            if (texDepth < depth) {
				depth = texDepth;
				cascade = i;
			}
		}

		return depth;
	}

    #ifdef SSS_ENABLED
        float SampleShadowSSS(const in vec2 shadowPos) {
            return texture2D(shadowcolor0, shadowPos).r;
        }
    #endif

    float GetCascadeBias(const in int cascade) {
        float blocksPerPixelScale = max(shadowProjectionSizes[cascade].x, shadowProjectionSizes[cascade].y) / cascadeTexSize;

        #if SHADOW_FILTER == 1
            float zRangeBias = 0.00004;
            float xySizeBias = blocksPerPixelScale * tile_dist_bias_factor * 4.0;
        #else
            float zRangeBias = 0.00001;
            float xySizeBias = blocksPerPixelScale * tile_dist_bias_factor;
        #endif

        return mix(xySizeBias, zRangeBias, geoNoL) * SHADOW_BIAS_SCALE;
    }

    vec2 GetPixelRadius(const in vec2 blockRadius) {
        float texSize = shadowMapSize * 0.5;
        return blockRadius * (texSize / shadowProjectionSizes[shadowCascade]) * shadowPixelSize;
    }

    #ifdef SHADOW_ENABLE_HWCOMP
        // returns: [0] when depth occluded, [1] otherwise
        float CompareDepth(const in vec3 shadowPos, const in vec2 offset, const in float bias) {
            #ifndef IS_OPTIFINE
                return shadow2D(shadowtex1HW, shadowPos + vec3(offset, -bias)).r;
            #else
                return shadow2D(shadowtex1, shadowPos + vec3(offset, -bias)).r;
            #endif
        }

        // returns: [0] when depth occluded, [1] otherwise
        float CompareNearestDepth(const in vec3 shadowPos[4], const in vec2 blockOffset) {
            float texComp = 1.0;
            for (int i = 0; i < 4 && texComp > 0.0; i++) {
                // Ignore if outside tile bounds
                vec2 shadowTilePos = GetShadowCascadeClipPos(i);
                if (shadowPos[i].x < shadowTilePos.x || shadowPos[i].x >= shadowTilePos.x + 0.5) continue;
                if (shadowPos[i].y < shadowTilePos.y || shadowPos[i].y >= shadowTilePos.y + 0.5) continue;

                float bias = GetCascadeBias(i);

                vec2 pixelPerBlockScale = (cascadeTexSize / shadowProjectionSizes[i]) * shadowPixelSize;
                
                vec2 pixelOffset = blockOffset * pixelPerBlockScale;
                texComp = min(texComp, CompareDepth(shadowPos[i], pixelOffset, bias));
            }

            return max(texComp, 0.0);
        }

        // #ifdef SSS_ENABLED
        //     // returns: [0] when depth occluded, [1] otherwise
        //     float CompareNearestDepth_SSS(const in vec3 shadowPos[4], const in vec2 blockOffset) {
        //         float texComp = 1.0;
        //         for (int i = 0; i < 4 && texComp > 0.0; i++) {
        //             // Ignore if outside tile bounds
        //             vec2 shadowTilePos = GetShadowCascadeClipPos(i);
        //             if (shadowPos[i].x < shadowTilePos.x || shadowPos[i].x >= shadowTilePos.x + 0.5) continue;
        //             if (shadowPos[i].y < shadowTilePos.y || shadowPos[i].y >= shadowTilePos.y + 0.5) continue;

        //             float shadow_sss = SampleShadowSSS(shadowPos[i].xy);
        //             float sss_bias = 1.2 * shadow_sss / (far * 3.0);
        //             float bias = sss_bias + GetCascadeBias(i);

        //             vec2 pixelPerBlockScale = (cascadeTexSize / shadowProjectionSizes[i]) * shadowPixelSize;
                    
        //             vec2 pixelOffset = blockOffset * pixelPerBlockScale;
        //             texComp = min(texComp, CompareDepth(shadowPos[i], pixelOffset, bias));
        //         }

        //         return max(texComp, 0.0);
        //     }
        // #endif
    #endif

    #if SHADOW_FILTER != 0
        #ifdef SHADOW_ENABLE_HWCOMP
            float GetShadowing_PCF(const in vec3 shadowPos[4], const in float blockRadius, const in int sampleCount) {
                float shadow = 0.0;
                for (int i = 0; i < sampleCount; i++) {
                    vec2 blockOffset = poissonDisk[i] * blockRadius;
                    shadow += 1.0 - CompareNearestDepth(shadowPos, blockOffset);
                }

                return shadow / sampleCount;
            }

            // #ifdef SSS_ENABLED
            //     float GetShadowing_PCF_SSS(const in vec3 shadowPos[4], const in float blockRadius, const in int sampleCount) {
            //         float shadow = 0.0;
            //         for (int i = 0; i < sampleCount; i++) {
            //             vec2 blockOffset = poissonDisk[i] * blockRadius;
            //             shadow += 1.0 - CompareNearestDepth_SSS(shadowPos, blockOffset);
            //         }

            //         return shadow / sampleCount;
            //     }
            // #endif
        #else
            float GetShadowing_PCF(const in vec3 shadowPos[4], const in float blockRadius, const in int sampleCount) {
                float shadow = 0.0;
                for (int i = 0; i < sampleCount; i++) {
                    int cascade;
                    vec2 blockOffset = poissonDisk[i] * blockRadius;
                    float texDepth = GetNearestDepth(shadowPos, blockOffset, cascade);
                    float bias = GetCascadeBias(cascade);
                    shadow += step(texDepth, shadowPos[cascade].z - bias);
                }

                return shadow / sampleCount;
            }
        #endif

        #ifdef SSS_ENABLED
            float GetShadowing_PCF_SSS(const in vec3 shadowPos[4], const in float blockRadius, const in int sampleCount) {
                float light = 0.0;
                for (int i = 0; i < sampleCount; i++) {
                    int cascade;
                    vec2 blockOffset = poissonDisk[i] * blockRadius;
                    float texDepth = GetNearestDepth(shadowPos, blockOffset, cascade);

                    vec2 pixelPerBlockScale = (cascadeTexSize / shadowProjectionSizes[cascade]) * shadowPixelSize;
                    vec2 pixelOffset = blockOffset * pixelPerBlockScale;

                    float bias = GetCascadeBias(cascade);
                    float shadow_sss = SampleShadowSSS(shadowPos[cascade].xy + pixelOffset);
                    float dist = max(shadowPos[cascade].z - bias - texDepth, 0.0) * far * 3.0;
                    light += max(shadow_sss - dist / SSS_MAXDIST, 0.0);
                }

                return light / sampleCount;
            }
        #endif
    #endif

	#if SHADOW_COLORS == 1
		vec3 GetShadowColor() {
			int cascade = -1;
			float depthLast = 1.0;
			for (int i = 0; i < 4; i++) {
				vec2 shadowTilePos = GetShadowCascadeClipPos(i);
				if (shadowPos[i].x < shadowTilePos.x || shadowPos[i].x > shadowTilePos.x + 0.5) continue;
				if (shadowPos[i].y < shadowTilePos.y || shadowPos[i].y > shadowTilePos.y + 0.5) continue;

				//when colored shadows are enabled and there's nothing OPAQUE between us and the sun,
				//perform a 2nd check to see if there's anything translucent between us and the sun.
				float depth = texture2D(shadowtex0, shadowPos[i].xy).r;
				if (depth + EPSILON < 1.0 && depth < shadowPos[i].z && depth < depthLast) {
					depthLast = depth;
					cascade = i;
				}
			}

			if (cascade < 0) return vec3(1.0);

			//surface has translucent object between it and the sun. modify its color.
			//if the block light is high, modify the color less.
			vec4 shadowLightColor = texture2D(shadowcolor0, shadowPos[cascade].xy);
			vec3 color = RGBToLinear(shadowLightColor.rgb);

			//make colors more intense when the shadow light color is more opaque.
			return mix(vec3(1.0), color, shadowLightColor.a);
		}
	#endif

	#if SHADOW_FILTER == 2
		// PCF + PCSS
		float FindBlockerDistance(const in vec3 shadowPos[4], const in float blockRadius, const in int sampleCount) {
			//float blockRadius = SearchWidth(uvLightSize, shadowPos.z);
			//float blockRadius = 6.0; //SHADOW_LIGHT_SIZE * (shadowPos.z - PCSS_NEAR) / shadowPos.z;
			float avgBlockerDistance = 0.0;
			int blockers = 0;

			for (int i = 0; i < sampleCount; i++) {
                int cascade;
				vec2 blockOffset = poissonDisk[i] * blockRadius;
				float texDepth = GetNearestDepth(shadowPos, blockOffset, cascade);

                float bias = GetCascadeBias(cascade);

				if (texDepth < shadowPos[cascade].z - bias) {
					avgBlockerDistance += texDepth;
					blockers++;
				}
			}

            if (blockers == sampleCount) return 1.0;
			return blockers > 0 ? avgBlockerDistance / blockers : -1.0;
		}

		float GetShadowing(const in vec3 shadowPos[4], out float lightSSS) {
            #ifdef SSS_ENABLED
                int cascade;
                float texDepth = GetNearestDepth(shadowPos, vec2(0.0), cascade);
                float dist = max(shadowPos[cascade].z - texDepth, 0.0) * far * 3.0;
                float shadow_sss = SampleShadowSSS(shadowPos[cascade].xy);
                lightSSS = max(shadow_sss - dist / SSS_MAXDIST, 0.0);
            #else
                lightSSS = 0.0;
            #endif

			// blocker search
			int blockerSampleCount = POISSON_SAMPLES;
			float blockerDistance = FindBlockerDistance(shadowPos, SHADOW_PCF_SIZE, blockerSampleCount);
			if (blockerDistance <= 0.0) return 1.0;
            if (blockerDistance == 1.0) return 0.0;

			// penumbra estimation
			float penumbraWidth = (shadowPos[shadowCascade].z - blockerDistance) / blockerDistance;

			// percentage-close filtering
			float blockRadius = min(penumbraWidth * SHADOW_PENUMBRA_SCALE, 1.0) * SHADOW_PCF_SIZE; // * SHADOW_LIGHT_SIZE * PCSS_NEAR / shadowPos.z;

            int pcfSampleCount = POISSON_SAMPLES;
			vec2 pixelRadius = GetPixelRadius(vec2(blockRadius));
			if (pixelRadius.x <= shadowPixelSize && pixelRadius.y <= shadowPixelSize) pcfSampleCount = 1;

			return 1.0 - GetShadowing_PCF(shadowPos, blockRadius, pcfSampleCount);
		}
	#elif SHADOW_FILTER == 1
		// PCF
		float GetShadowing(const in vec3 shadowPos[4]) {
            int sampleCount = POISSON_SAMPLES;
            vec2 pixelRadius = GetPixelRadius(vec2(SHADOW_PCF_SIZE));
            if (pixelRadius.x <= shadowPixelSize && pixelRadius.y <= shadowPixelSize) sampleCount = 1;

			return 1.0 - GetShadowing_PCF(shadowPos, SHADOW_PCF_SIZE, sampleCount);
		}

        float GetShadowSSS(const in vec3 shadowPos[4]) {
            //int cascade;
            //GetNearestDepth(shadowPos, vec2(0.0), cascade);
            //float center_sss = SampleShadowSSS(shadowPos[cascade].xy);

            float size = SHADOW_PCF_SIZE;// * (1.0 - center_sss);

            int sampleCount = POISSON_SAMPLES;
            vec2 pixelRadius = GetPixelRadius(vec2(size));
            if (pixelRadius.x <= shadowPixelSize && pixelRadius.y <= shadowPixelSize) sampleCount = 1;

            return GetShadowing_PCF_SSS(shadowPos, size, sampleCount);
        }
	#elif SHADOW_FILTER == 0
		// Unfiltered
		float GetShadowing(const in vec3 shadowPos[4]) {
            #ifdef SHADOW_ENABLE_HWCOMP
                return CompareNearestDepth(shadowPos, vec2(0.0));
            #else
    			int cascade;
    			float texDepth = GetNearestDepth(shadowPos, vec2(0.0), cascade);

                float bias = GetCascadeBias(cascade);
    			return step(shadowPos[cascade].z - bias, texDepth);
            #endif
		}

        #ifdef SSS_ENABLED
            float GetShadowSSS(const in vec3 shadowPos[4]) {
                int cascade;
                float texDepth = GetNearestDepth(shadowPos, vec2(0.0), cascade);
                float bias = GetCascadeBias(cascade);
                float dist = max(shadowPos[cascade].z - bias - texDepth, 0.0) * far * 3.0;
                float shadow_sss = SampleShadowSSS(shadowPos[cascade].xy);
                return max(shadow_sss - dist / SSS_MAXDIST, 0.0);
            }
        #endif
	#endif
#endif
