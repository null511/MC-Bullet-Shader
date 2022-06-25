#define RENDER_DEFERRED

varying vec2 texcoord;
//varying vec3 viewLightDir;

#ifdef SHADOW_ENABLED
    flat varying vec3 worldLightPos;
    flat varying vec3 skyLightColor;
#endif

#ifdef RENDER_VERTEX
    uniform vec3 sunPosition;
    uniform vec3 moonPosition;
    uniform vec3 upPosition;

    #ifdef SHADOW_ENABLED
        uniform mat4 gbufferModelViewInverse;
        uniform vec3 shadowLightPosition;
    #endif

    #include "/lib/world/sky.glsl"


	void main() {
		gl_Position = ftransform();
		texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;

        #ifdef SHADOW_ENABLED
            worldLightPos = (gbufferModelViewInverse * vec4(shadowLightPosition, 1.0)).xyz;
            skyLightColor = GetSkyLightColor();
        #endif
	}
#endif

#ifdef RENDER_FRAG
	uniform sampler2D colortex0;
    uniform sampler2D colortex1;
    uniform sampler2D colortex2;
    uniform sampler2D colortex3;
    uniform sampler2D lightmap;
    uniform sampler2D depthtex0;

    uniform mat4 gbufferProjectionInverse;
    uniform int heldBlockLightValue;

    uniform int fogMode;
    uniform float fogStart;
    uniform float fogEnd;
    uniform int fogShape;
    uniform vec3 fogColor;

    #ifdef SHADOW_ENABLED
        uniform mat4 gbufferModelViewInverse;
        uniform vec3 skyColor;
    #endif

    #include "/lib/world/fog.glsl"
    #include "/lib/lighting/material.glsl"
    #include "/lib/lighting/material_reader.glsl"
    #include "/lib/lighting/hcm.glsl"
    #include "/lib/lighting/pbr.glsl"
    #include "/lib/lighting/pbr_deferred.glsl"
    #include "/lib/tonemap.glsl"


	void main() {
        vec3 final = PbrLighting();

        //final = LinearToRGB(final);
        final = ApplyTonemap(final);

	/* DRAWBUFFERS:0 */
		gl_FragData[0] = vec4(final, 1.0); //gcolor
	}
#endif
