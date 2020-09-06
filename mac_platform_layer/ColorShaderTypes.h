/*
    Platform Game Texture Packer
    Color Shader Types
    2020 Ted Bendixson

    NOTE:   Contains types for flat color shading on the Mac Platform layer for this game tool.
*/

#ifndef ShaderTypes_h
#define ShaderTypes_h

#include <simd/simd.h>

typedef struct
{
    vector_float2 position;
    vector_float4 color;
} FlatColorShaderVertex;

#endif /* ShaderTypes_h */
