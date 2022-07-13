#define RENDER_GBUFFER
#define RENDER_BEACONBEAM

#undef PARALLAX_ENABLED
#undef SHADOW_ENABLED

varying vec2 texcoord;
varying vec4 glcolor;
varying vec3 viewPos;
varying vec3 viewNormal;
varying float geoNoL;
varying mat3 matTBN;
varying vec3 tanViewPos;

#ifdef AF_ENABLED
    varying vec4 spriteBounds;
#endif

#ifdef RENDER_VERTEX
    in vec4 at_tangent;

    #ifdef AF_ENABLED
        in vec4 mc_midTexCoord;
    #endif

	#include "/lib/lighting/basic.glsl"


	void main() {
		texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
		glcolor = gl_Color;

        mat3 matViewTBN;
        BasicVertex(matViewTBN);
	}
#endif

#ifdef RENDER_FRAG
	uniform sampler2D gtexture;

    #if MC_VERSION >= 11700 && defined IS_OPTIFINE
        uniform float alphaTestRef;
    #endif

    #ifdef AF_ENABLED
    	uniform float viewHeight;
    #endif


	void main() {
		vec4 colorMap;
        #ifdef PARALLAX_ENABLED
			colorMap = textureAF(gtexture, texcoord) * glcolor;
        #else
			colorMap = texture(gtexture, texcoord) * glcolor;
        #endif

        if (colorMap.a < 0.98) discard;
        colorMap.a = 1.0;

		vec4 normalMap = vec4(viewNormal, 1.0);
		vec4 specularMap = vec4(0.0, 0.02, 0.0, 0.9);
		vec4 lightingMap = vec4(1.0, 0.0, 1.0, 0.0);

    /* DRAWBUFFERS:0123 */
        gl_FragData[0] = colorMap; //gcolor
        gl_FragData[1] = normalMap; //gdepth
        gl_FragData[2] = specularMap; //gnormal
        gl_FragData[3] = lightingMap; //composite
	}
#endif
