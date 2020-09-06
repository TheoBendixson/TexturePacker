/*
    Platform Game Texture Packer
    2020 Ted Bendixson
    Mooselutions LLC

    Describes an API between C and Metal to draw flat shaded blocks of color
*/

#ifndef ShaderTypes_h
#define ShaderTypes_h

#include <simd/simd.h>

// Buffer index values shared between shader and C code to ensure Metal shader buffer inputs match
//   Metal API buffer set calls
typedef enum VertexInputIndex
{
    MacVertexInputIndexVertices     = 0,
    MacVertexInputIndexViewportSize = 1,
} VertexInputIndex;

//  This structure defines the layout of each vertex in the array of vertices set as an input to the
//    Metal vertex shader.  Since this header is shared between the .metal shader and C code,
//    you can be sure that the layout of the vertex array in the code matches the layout that
//    the vertex shader expects

typedef struct
{
    // Positions in pixel space. A value of 100 indicates 100 pixels from the origin/center.
    vector_float2 position;

    // Color 
    vector_float4 color;
} FlatColorShaderVertex;

#endif /* ShaderTypes_h */
