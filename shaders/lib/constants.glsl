#define PLATFORM_OPTIFINE 0
#define PLATFORM_IRIS 1

#define BLOCK_OUTLINE_NONE 0
#define BLOCK_OUTLINE_BLACK 1
#define BLOCK_OUTLINE_WHITE 2
#define BLOCK_OUTLINE_FANCY 3

#define WATER_WAVE_NONE 0
#define WATER_WAVE_VERTEX 1

#define WEATHER_MODE_NONE 0
#define WEATHER_MODE_SKY 1
#define WEATHER_MODE_FULL 2

#define AO_TYPE_NONE 0
#define AO_TYPE_VANILLA 1
#define AO_TYPE_SS 2

#define MATERIAL_FORMAT_DEFAULT 0
#define MATERIAL_FORMAT_LABPBR 1
#define MATERIAL_FORMAT_OLDPBR 2
#define MATERIAL_FORMAT_PATRIX 3

#define REFLECTION_MODE_NONE 0
#define REFLECTION_MODE_SKY 1
#define REFLECTION_MODE_SCREEN 2

#define SHADOW_TYPE_NONE 0
#define SHADOW_TYPE_BASIC 1
#define SHADOW_TYPE_DISTORTED 2
#define SHADOW_TYPE_CASCADED 3

#define SHADOW_CONTACT_NONE 0
#define SHADOW_CONTACT_FAR 1
#define SHADOW_CONTACT_ALL 2

#define EXPOSURE_MODE_MANUAL 0
#define EXPOSURE_MODE_EYEBRIGHTNESS 1
#define EXPOSURE_MODE_MIPMAP 2
#define EXPOSURE_MODE_HISTOGRAM 3

#define DEBUG_VIEW_NONE 0
#define DEBUG_VIEW_GBUFFER_COLOR 1
#define DEBUG_VIEW_GBUFFER_NORMAL 2
#define DEBUG_VIEW_GBUFFER_OCCLUSION 3
#define DEBUG_VIEW_GBUFFER_SPECULAR 4
#define DEBUG_VIEW_GBUFFER_LIGHTING 5
#define DEBUG_VIEW_GBUFFER_SHADOW 6
#define DEBUG_VIEW_DEFERRED_SHADOW 7
#define DEBUG_VIEW_DEFERRED_A0 8
#define DEBUG_VIEW_SHADOW_COLOR 9
#define DEBUG_VIEW_SHADOW_DEPTH0 10
#define DEBUG_VIEW_SHADOW_DEPTH1 11
#define DEBUG_VIEW_HDR 12
#define DEBUG_VIEW_LUMINANCE 13
#define DEBUG_VIEW_BLOOM 14
#define DEBUG_VIEW_PREV_COLOR 15
#define DEBUG_VIEW_PREV_LUMINANCE 16
#define DEBUG_VIEW_PREV_DEPTH 17
#define DEBUG_VIEW_DEPTH_TILES 18
#define DEBUG_VIEW_LUT_BRDF 19
#define DEBUG_VIEW_LUT_SUN_TRANSMISSION 20
#define DEBUG_VIEW_LUT_SKY 21
#define DEBUG_VIEW_WHITEWORLD 22
#define DEBUG_VIEW_IRRADIANCE 23

#define BUFFER_DEFERRED colortex0
#define BUFFER_LUM_TRANS colortex1
#define BUFFER_HDR_TRANS colortex2
#define BUFFER_LUM_OPAQUE colortex3
#define BUFFER_HDR_OPAQUE colortex4
#define BUFFER_HDR_PREVIOUS colortex5
#define BUFFER_DEPTH_PREV colortex6
#define BUFFER_SKY_LUT colortex7
#define BUFFER_AO colortex10
#define BUFFER_IRRADIANCE colortex11

#define BUFFER_BLOOM colortex2

#define MATERIAL_WATER 100
#define MATERIAL_NETHER_PORTAL 102
#define MATERIAL_LAVA 110

#define MATERIAL_LIGHTNING_BOLT 100
#define MATERIAL_ITEM_FRAME 101
#define MATERIAL_PHYSICS_SNOW 829925
#define MATERIAL_BOAT 103

#ifdef IS_IRIS
	#define TEX_CLOUD_NOISE texCloudNoise
	#define TEX_BRDF texBRDF
#else
	#define TEX_CLOUD_NOISE colortex14
	#define TEX_BRDF colortex15
#endif
