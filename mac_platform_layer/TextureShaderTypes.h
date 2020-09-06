
#include <simd/simd.h>

typedef struct
{
    vector_float2 position;
    vector_float2 textureCoordinate;
    uint32_t textureID;
} TextureShaderVertex;
