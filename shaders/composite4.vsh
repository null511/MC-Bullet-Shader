#version 400 compatibility

#extension GL_ARB_texture_query_levels : enable

#ifndef GL_ARB_texture_query_levels
    #include "/lib/compatibility/texture_query_levels.glsl"
#endif

#include "overworld.glsl"
#include "program/composite4.vsh"
