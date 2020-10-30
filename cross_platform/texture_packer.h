/*
    texture_packer.h

    Platformer Texture Packer
    2020 Ted Bendixson
    Mooselutions, LLC
*/

#include "platform.h"
#include "memory_arena.h"
#include "texture_pack.h"

struct read_file_result 
{
    void *Contents;
    uint64 ContentsSize;
    char *Filename;
};

struct texture
{
    uint32 *Data;
    uint32 Width;
    uint32 Height;
};

read_file_result PlatformOpenFileDialog();
void PlatformFreeFileMemory(void *Memory);

void PlatformAddTexture(texture *Texture);
void PlatformReplaceTextureAtIndex(texture *Texture, uint32 TextureIndex);
void PlatformRemoveTexturesFromIndexToEnd(uint32 NumberOfTexturesToRemove);
void PlatformClearAllTextures();

read_file_result PlatformReadEntireFile(char *Filename);
bool32 PlatformWriteEntireFile(uint64 FileSize, void *Memory);

struct texture_packer_memory
{
    bool32 IsInitialized;
    uint64 PermanentStorageSize;
    uint64 TemporaryStorageSize; 

    // NOTE: (Ted)  This must be cleared to zero at startup!!!
    void *PermanentStorage;
    void *TemporaryStorage;
};

#include "texture_packer_input.h"
#include "texture.h"

struct texture_packer_state
{
    uint8 ActionSlopFrames;
    uint8 NavigationSlopFrames;

    uint32 SelectedTexture;
};

struct texture_pack
{
    uint32 NumberOfTextures;
    uint32 MaxTextures;
    texture Textures[128];
};

struct texture_packer_texture_storage
{
    memory_arena TextureDataArena;
    texture_pack TexturePack;
    texture_pack_file_header_new *SaveFileHeader;
};
