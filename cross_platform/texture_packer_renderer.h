/*
    texture_packer_renderer.h
    Platformer Texture Packer

    2020 Ted Bendixson
    Mooselutions, LLC
    All Rights Reserved
 

 */

#if CLANG
typedef vector_float2 texture_packer_2d_vertex;
typedef vector_float2 texture_packer_2d_texture_coordinate;
typedef vector_float4 texture_packer_color;
#endif

struct texture_packer_texture
{
    uint32 *Data;
    uint32 Type;
};

struct texture_packer_texture_buffer
{
    texture_packer_texture Textures[50];
    uint32 NumberOfTextures;
    uint32 TexturesLoaded;
};

struct texture_packer_color_vertex
{
    texture_packer_2d_vertex Position;
    texture_packer_color Color;
};

struct texture_packer_texture_vertex
{
    texture_packer_2d_vertex Position;
    texture_packer_2d_texture_coordinate TextureCoordinate;
    uint32 TextureID;
};

struct color_vertex_command_buffer
{
    texture_packer_color_vertex *ColorVertices;
    uint32 NumberOfColorVertices;
};

struct texture_vertex_command_buffer
{
    texture_packer_texture_vertex *TextureVertices;
    uint32 NumberOfTextureVertices;
};

struct texture_packer_render_commands
{
    color_vertex_command_buffer ColorVertexCommandBuffers[3];
    texture_vertex_command_buffer TextureVertexCommandBuffers[3];

    uint32 FrameIndex;

    int ViewportWidth;
    int ViewportHeight;

    uint32 UniqueTextureCount;
};

void
DrawRectangle(texture_packer_render_commands *RenderCommands, 
              v2 vMin, v2 vMax, texture_packer_color Color)
{

    texture_packer_color_vertex QuadVertices[] =
    {
        // Pixel positions, Color
        { { vMin.X, vMin.Y }, Color },
        { { vMin.X, vMax.Y }, Color },
        { { vMax.X, vMax.Y }, Color },

        { { vMin.X, vMin.Y }, Color },
        { { vMax.X, vMin.Y }, Color },
        { { vMax.X, vMax.Y }, Color }
    };

    color_vertex_command_buffer ColorCommandBuffer = RenderCommands->ColorVertexCommandBuffers[RenderCommands->FrameIndex];

    texture_packer_color_vertex *Source = QuadVertices;
    texture_packer_color_vertex *Dest = ColorCommandBuffer.ColorVertices + ColorCommandBuffer.NumberOfColorVertices;

    for (uint32 Index = 0; Index < 6; Index++)
    {
        *Dest++ = *Source++;
        ColorCommandBuffer.NumberOfColorVertices++;
    }

    RenderCommands->ColorVertexCommandBuffers[RenderCommands->FrameIndex] = ColorCommandBuffer;
}

void DrawTexturedRectangle(texture_packer_render_commands *RenderCommands,
                           v2 vMin, v2 vMax, uint32 TextureID)
{
    texture_packer_texture_vertex QuadVertices[] =
    {
        // Pixel positions, Texture coordinates, TextureID
        { { vMin.X, vMax.Y }, { 0.0f, 1.0f }, TextureID },
        { { vMin.X, vMin.Y }, { 0.0f, 0.0f }, TextureID },
        { { vMax.X, vMax.Y }, { 1.0f, 1.0f }, TextureID },

        { { vMax.X, vMax.Y }, { 1.0f, 1.0f }, TextureID },
        { { vMin.X, vMin.Y }, { 0.0f, 0.0f }, TextureID },
        { { vMax.X, vMin.Y }, { 1.0f, 0.0f }, TextureID },
    };

    texture_vertex_command_buffer TextureCommandBuffer = RenderCommands->TextureVertexCommandBuffers[RenderCommands->FrameIndex];

    texture_packer_texture_vertex *Source = QuadVertices;
    texture_packer_texture_vertex *Dest = TextureCommandBuffer.TextureVertices + TextureCommandBuffer.NumberOfTextureVertices;

    for (uint32 Index = 0; Index < 6; Index++)
    {
        *Dest++ = *Source++;
        TextureCommandBuffer.NumberOfTextureVertices++;
    }

    RenderCommands->TextureVertexCommandBuffers[RenderCommands->FrameIndex] = TextureCommandBuffer;
}
