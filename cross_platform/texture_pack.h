/*
    platformer_texture_pack.h
    Platforming Game and Level Editor

    2020 Ted Bendixson, Mooselutions LLC
    All Rights Reserved
 
 */

enum texture_pack_type
{
    TexturePackTypeUnknown,
    TexturePackTypeLegacy,
    TexturePackTypeNew
};

struct texture_pack_file_header_legacy
{
    uint64 FileSize;
    uint32 TextureWidth;
    uint32 TextureHeight;
    uint32 NumberOfTextures;
};

struct texture_pack_file_header_new
{
    uint64 FileSize;
    uint32 TextureWidth;
    uint32 TextureHeight;
    uint32 MaxTextures;
    uint32 NumberOfTextures;
};

struct texture_pack_serialized
{
    bool32 IsValid;
    uint32 *PixelBufferSource;
    uint32 NumberOfTextures;
    uint32 TextureWidth;
    uint32 TextureHeight;
    uint32 MaxTextures;
};

texture_pack_type
TexturePackTypeFromFilename(char *Filename)
{
    char *Scan = Filename;

    texture_pack_type FileType = TexturePackTypeUnknown; 

    while(Scan++)
    {
        if(*Scan == '.')
        {
            char First = *(Scan + 1);
            char Second = *(Scan + 2);
            char Third = *(Scan + 3);
            char Fourth = *(Scan + 4);
            char Fifth = *(Scan + 5);

            if (First == 'p' && Second == 'g' && Third == 't' && Fourth == 'p' && Fifth == '\0')
            {
                FileType = TexturePackTypeLegacy;
            } else if (First == 'p' && Second == 'g' && Third == 't' && Fourth == 'p' && Fifth == 'n')
            {
                FileType = TexturePackTypeNew;
            } 

            break;
        }
    }

    return FileType;
}

texture_pack_serialized
GetTexturePackFromFile(char *Filename, void *FileContents)
{
    uint8 *BaseTexturePackData = (uint8 *)FileContents;
    texture_pack_type FileType = TexturePackTypeFromFilename(Filename);
    texture_pack_serialized TexturePack = {};
    TexturePack.IsValid = false;
    TexturePack.PixelBufferSource = NULL;
    TexturePack.NumberOfTextures = 0;
    TexturePack.TextureWidth = 0;
    TexturePack.TextureHeight = 0;
    TexturePack.MaxTextures = 0;

    if (FileType == TexturePackTypeLegacy)
    {
        texture_pack_file_header_legacy *FileHeader = (texture_pack_file_header_legacy *)FileContents;
        TexturePack.PixelBufferSource = (uint32 *)(BaseTexturePackData + sizeof(texture_pack_file_header_legacy));
        TexturePack.NumberOfTextures = FileHeader->NumberOfTextures;
        TexturePack.TextureWidth = FileHeader->TextureWidth;
        TexturePack.TextureHeight = FileHeader->TextureHeight;
        TexturePack.MaxTextures = 128;
        TexturePack.IsValid = true;
    } else if (FileType == TexturePackTypeNew)
    {
        texture_pack_file_header_new *FileHeader = (texture_pack_file_header_new *)FileContents;
        TexturePack.PixelBufferSource = (uint32 *)(BaseTexturePackData + sizeof(texture_pack_file_header_new));
        TexturePack.NumberOfTextures = FileHeader->NumberOfTextures;
        TexturePack.TextureWidth = FileHeader->TextureWidth;
        TexturePack.TextureHeight = FileHeader->TextureHeight;
        TexturePack.MaxTextures = FileHeader->MaxTextures;
        TexturePack.IsValid = true;
    }

    return TexturePack;
}
