#extension GL_ARB_shading_language_packing : enable

#define RENDER_COMPOSITE

varying vec2 texcoord;

#ifdef RENDER_VERTEX
    void main() {
        gl_Position = ftransform();
        texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    }
#endif

#ifdef RENDER_FRAG
    uniform sampler2D colortex0;

    #if DEBUG_SHADOW_BUFFER == DEBUG_VIEW_SHADOW_ALBEDO
        // Shadow Albedo
        uniform usampler2D shadowcolor0;
    #elif DEBUG_SHADOW_BUFFER == DEBUG_VIEW_SHADOW_NORMAL
        // Shadow Normal
        uniform usampler2D shadowcolor0;
    #elif DEBUG_SHADOW_BUFFER == DEBUG_VIEW_SHADOW_SSS
        // Shadow SSS
        uniform usampler2D shadowcolor0;
    #elif DEBUG_SHADOW_BUFFER == DEBUG_VIEW_SHADOW_DEPTH0
        // Shadow Depth [0]
        uniform sampler2D shadowtex0;
    #elif DEBUG_SHADOW_BUFFER == DEBUG_VIEW_SHADOW_DEPTH1
        // Shadow Depth [1]
        uniform sampler2D shadowtex1;
    #elif DEBUG_SHADOW_BUFFER == DEBUG_VIEW_RSM_LOWRES
        // RSM Low-Res
        uniform sampler2D colortex5;
    #elif DEBUG_SHADOW_BUFFER == DEBUG_VIEW_RSM_FULLRES
        // RSM Full-Res
        uniform sampler2D colortex7;
    #endif


    void main() {
        vec3 color = vec3(0.0);
        #if DEBUG_SHADOW_BUFFER == DEBUG_VIEW_SHADOW_ALBEDO
            // Shadow Albedo
            uint data = texture2D(shadowcolor0, texcoord).r;
            color = unpackUnorm4x8(data).rgb;
        #elif DEBUG_SHADOW_BUFFER == DEBUG_VIEW_SHADOW_NORMAL
            // Shadow Normal
            uint data = texture2D(shadowcolor0, texcoord).g;
            color = RestoreNormalZ(unpackUnorm2x16(data)) * 0.5 + 0.5;
        #elif DEBUG_SHADOW_BUFFER == DEBUG_VIEW_SHADOW_SSS
            // Shadow SSS
            uint data = texture2D(shadowcolor0, texcoord).r;
            color = unpackUnorm4x8(data).aaa;
        #elif DEBUG_SHADOW_BUFFER == DEBUG_VIEW_SHADOW_DEPTH0
            // Shadow Depth [0]
            color = texture2D(shadowtex0, texcoord).rrr;
        #elif DEBUG_SHADOW_BUFFER == DEBUG_VIEW_SHADOW_DEPTH1
            // Shadow Depth [1]
            color = texture2D(shadowtex1, texcoord).rrr;
        #elif DEBUG_SHADOW_BUFFER == DEBUG_VIEW_RSM_LOWRES
            // RSM Low-Res
            color = texture2D(colortex5, texcoord).rgb;
        #elif DEBUG_SHADOW_BUFFER == DEBUG_VIEW_RSM_FULLRES
            // RSM Full-Res
            color = texture2D(colortex7, texcoord).rgb;
        #else
            // None
            color = texture2D(colortex0, texcoord).rgb;
        #endif

    /* DRAWBUFFERS:4 */
        gl_FragData[0] = vec4(color, 1.0); //colortex4
    }
#endif
