/*
    texture_packer.cpp 
    Platformer Texture Packer

    2020 Ted Bendixson
    Mooselutions, LLC
    All Rights Reserved

 */

#include "texture_packer_math.h"
#include "texture_packer_renderer.h"
#include "texture_packer.h"

internal void
LoadTexturesFromFile(texture_packer_texture_storage *TextureStorage, uint32 NumberOfTextures,
                     uint32 *PixelBufferSource, texture_packer_render_commands *RenderCommands)
{
    texture_pack TexturePack = TextureStorage->TexturePack;
    TexturePack.NumberOfTextures = 0;

    PlatfromClearAllTextures();

    for (uint32 TextureIndex = 0; TextureIndex < NumberOfTextures; TextureIndex++)
    {
        texture Texture = {};

        Texture.Width = 24;
        Texture.Height = 24;
        uint32 PixelCount = Texture.Width*Texture.Height;
        Texture.Data = PushArray(&TextureStorage->TextureDataArena, PixelCount, uint32);
        uint32 *PixelBufferDest = (uint32 *)Texture.Data;

        for (uint32 Index = 0; Index < PixelCount; Index++)
        {
            *PixelBufferDest++ = *PixelBufferSource++;
        }

        TexturePack.Textures[TextureIndex] = Texture;
        TexturePack.NumberOfTextures++;
        RenderCommands->UniqueTextureCount++;
        PlatformAddTexture(&Texture);
    }

    TextureStorage->TexturePack = TexturePack;
}

internal void
AddNewTextureOrReplaceAtCurrentIndex(texture *Texture, uint32 TextureIndex, texture_pack *TexturePack,
                                     uint32 *PixelBufferSource, texture_packer_texture_storage *TextureStorage, 
                                     texture_packer_render_commands *RenderCommands)
{
    uint32 PixelCount = Texture->Width*Texture->Height;

    if (TexturePack->NumberOfTextures == TextureIndex)
    {
        Texture->Data = PushArray(&TextureStorage->TextureDataArena, PixelCount, uint32);
    } else
    {
        Texture->Data = TexturePack->Textures[TextureIndex].Data;
    }

    uint32 *PixelBufferDest = (uint32 *)Texture->Data;

    for (uint32 Index = 0; Index < PixelCount; Index++)
    {
        *PixelBufferDest++ = *PixelBufferSource++;
    }

    TexturePack->Textures[TextureIndex] = *Texture;

    if (TexturePack->NumberOfTextures == TextureIndex)
    {
        TexturePack->NumberOfTextures++;
        RenderCommands->UniqueTextureCount++;
        PlatformAddTexture(Texture);
    } else
    {
        PlatformReplaceTextureAtIndex(Texture, TextureIndex);
    }
}

internal
void UpdateAndRender(texture_packer_memory *Memory, texture_packer_input *Input, 
                     texture_packer_render_commands *RenderCommands)
{
    Assert(sizeof(texture_packer_state) <= Memory->PermanentStorageSize);
    Assert(sizeof(texture_packer_texture_storage) <= Memory->TemporaryStorageSize);

    texture_packer_state *TexturePackerState = (texture_packer_state *)Memory->PermanentStorage;
    texture_packer_texture_storage *TextureStorage = (texture_packer_texture_storage *)Memory->TemporaryStorage;

    if(!Memory->IsInitialized)
    {
        TexturePackerState->SelectedTexture = 0;

        InitializeArena(&TextureStorage->TextureDataArena, Memory->TemporaryStorageSize - sizeof(texture_packer_texture_storage), 
                        (uint8 *)Memory->TemporaryStorage + sizeof(texture_packer_texture_storage));

        TextureStorage->SaveFileHeader = PushStruct(&TextureStorage->TextureDataArena, texture_pack_file_header_new);

        Memory->IsInitialized = true;
    }

    uint8 ActionPauseFrames = 10;

    if (Input->Keyboard.A.EndedDown &&
        TexturePackerState->ActionSlopFrames == 0)
    {
        read_file_result ReadResult = PlatformOpenFileDialog();

        char *Scan = ReadResult.Filename; 

        texture_file_type FileType = TextureFileTypeUnknown;

        while(Scan++)
        {
            if(*Scan == '.')
            {
                char First = *(Scan + 1);
                char Second = *(Scan + 2);
                char Third = *(Scan + 3);
                char Fourth = *(Scan + 4);

                if (First == 'p' && Second == 'g' && Third == 't' && Fourth == 'n')
                {
                    FileType = TextureFileTypeWidthHeight;
                } else if (First == 'p' && Second == 'g' && Third == 't' && Fourth == '\0')
                {
                    FileType = TextureFileTypeNoHeader;
                } 

                break;
            }
        }

        texture_pack TexturePack = TextureStorage->TexturePack;
        uint32 TextureIndex = TexturePackerState->SelectedTexture;
        texture Texture = {};

        if (ReadResult.ContentsSize > 0 && FileType == TextureFileTypeNoHeader)
        {
            uint32 *PixelBufferSource = (uint32 *)ReadResult.Contents;
          
            Texture.Width = 24;
            Texture.Height = 24;

            AddNewTextureOrReplaceAtCurrentIndex(&Texture, TextureIndex, &TexturePack,
                                                 PixelBufferSource, TextureStorage, RenderCommands);

        } else if (ReadResult.ContentsSize > 0 && FileType == TextureFileTypeWidthHeight)
        {
            texture_file_header *FileHeader = (texture_file_header *)ReadResult.Contents;
            uint8 *BaseTextureData = (uint8 *)ReadResult.Contents;

            uint32 *PixelBufferSource = (uint32 *)(BaseTextureData + FileHeader->PixelBufferOffset);

            Texture.Width = FileHeader->TextureWidth;
            Texture.Height = FileHeader->TextureHeight;
            AddNewTextureOrReplaceAtCurrentIndex(&Texture, TextureIndex, &TexturePack,
                                                 PixelBufferSource, TextureStorage, RenderCommands);
        } 

        TextureStorage->TexturePack = TexturePack;

        PlatformFreeFileMemory(ReadResult.Contents);
        PlatformFreeFileMemory(ReadResult.Filename);

        TexturePackerState->ActionSlopFrames = ActionPauseFrames;
    }

    if (Input->Keyboard.F1.EndedDown &&
        TexturePackerState->ActionSlopFrames == 0)
    {
        read_file_result ReadResult = PlatformOpenFileDialog();

        if (ReadResult.ContentsSize > 0)
        {
            texture_pack_type FileType = TexturePackTypeFromFilename(ReadResult.Filename);

            InitializeArena(&TextureStorage->TextureDataArena, 
                            Memory->TemporaryStorageSize - sizeof(texture_packer_texture_storage), 
                            (uint8 *)Memory->TemporaryStorage + sizeof(texture_packer_texture_storage));
                
            if (FileType == TexturePackTypeLegacy)
            {
                texture_pack_file_header_legacy *FileHeader = (texture_pack_file_header_legacy *)ReadResult.Contents;
                uint8 *BaseTexturePackData = (uint8 *)ReadResult.Contents;

                texture_pack_file_header_new NewFileHeader = {};
                NewFileHeader.TextureWidth = FileHeader->TextureWidth;
                NewFileHeader.TextureHeight = FileHeader->TextureHeight;
                NewFileHeader.MaxTextures = 128; 
                NewFileHeader.NumberOfTextures = FileHeader->NumberOfTextures;

                TextureStorage->SaveFileHeader = PushStruct(&TextureStorage->TextureDataArena, texture_pack_file_header_new);
                *TextureStorage->SaveFileHeader = NewFileHeader;

                uint32 *PixelBufferSource = (uint32 *)(BaseTexturePackData + sizeof(texture_pack_file_header_legacy));

                LoadTexturesFromFile(TextureStorage, FileHeader->NumberOfTextures, 
                                     PixelBufferSource, RenderCommands);

                TextureStorage->SaveFileHeader->FileSize = TextureStorage->TextureDataArena.Used;

            } else if (FileType == TexturePackTypeNew)
            {
                texture_pack_file_header_new *FileHeader = (texture_pack_file_header_new *)ReadResult.Contents;
                uint8 *BaseTexturePackData = (uint8 *)ReadResult.Contents;

                TextureStorage->SaveFileHeader = PushStruct(&TextureStorage->TextureDataArena, texture_pack_file_header_new);
                *TextureStorage->SaveFileHeader = *FileHeader;

                uint32 *PixelBufferSource = (uint32 *)(BaseTexturePackData + sizeof(texture_pack_file_header_new));

                LoadTexturesFromFile(TextureStorage, FileHeader->NumberOfTextures, 
                                     PixelBufferSource, RenderCommands);
            }
        }

        TexturePackerState->ActionSlopFrames = ActionPauseFrames;
    }

    uint8 NavigationPauseFrames = 8;
    
    if (Input->Keyboard.L.EndedDown &&
        TexturePackerState->NavigationSlopFrames == 0)
    {
        uint32 NumberOfTextures = TextureStorage->TexturePack.NumberOfTextures;

        if (NumberOfTextures > 0)
        {
            if (TexturePackerState->SelectedTexture == NumberOfTextures)
            {
                TexturePackerState->SelectedTexture = 0;
            } else
            {
                TexturePackerState->SelectedTexture++;
            }
        }

        TexturePackerState->NavigationSlopFrames = NavigationPauseFrames;
    }

    if (Input->Keyboard.H.EndedDown &&
        TexturePackerState->NavigationSlopFrames == 0)
    {
        uint32 NumberOfTextures = TextureStorage->TexturePack.NumberOfTextures;

        if (NumberOfTextures > 0)
        {
            if (TexturePackerState->SelectedTexture == 0)
            {
                TexturePackerState->SelectedTexture = NumberOfTextures;
            } else
            {
                TexturePackerState->SelectedTexture--;
            }
        }

        TexturePackerState->NavigationSlopFrames = NavigationPauseFrames;
    }

    if (Input->Keyboard.F2.EndedDown &&
        TexturePackerState->ActionSlopFrames == 0)
    {
        TextureStorage->SaveFileHeader->TextureWidth = 24;
        TextureStorage->SaveFileHeader->TextureHeight = 24;
        TextureStorage->SaveFileHeader->NumberOfTextures = TextureStorage->TexturePack.NumberOfTextures;
        TextureStorage->SaveFileHeader->FileSize = TextureStorage->TextureDataArena.Used;

        uint8 *StartOfFileData = TextureStorage->TextureDataArena.Base;

        bool32 Written = PlatformWriteEntireFile(TextureStorage->SaveFileHeader->FileSize, 
                                                 (void*)StartOfFileData);

        TexturePackerState->ActionSlopFrames = ActionPauseFrames;
    }

    if (TexturePackerState->ActionSlopFrames > 0)
    {
        TexturePackerState->ActionSlopFrames--;
    }

    if (TexturePackerState->NavigationSlopFrames > 0)
    {
        TexturePackerState->NavigationSlopFrames--;
    }

    texture_packer_color BackgroundColor = { .973f, 0.369f, 0.533f, 1.0f };
    v2 BackgroundMin = { 0.0f, 0.0f };
    v2 BackgroundMax = V2((real32)RenderCommands->ViewportWidth, 
                          (real32)RenderCommands->ViewportHeight);
    DrawRectangle(RenderCommands, BackgroundMin, BackgroundMax, BackgroundColor);

    // TODO: (Ted)  This is just test code. It needs to accomodate the texture width
    //              and height of each texture in a pack.
    //              
    //              Assuming a 24 by 24 size for now.
    //
    //              It will probably be a good idea to constrain the width/height to the same
    //              value for all textures in a pack, and then include that information in the header.
    real32 TextureSideInPixels = 24.0f;
    real32 ScaleFactor = 2.0f;
    real32 TextureWidth = TextureSideInPixels*ScaleFactor;
    v2 StartingMin = { 10.0f, 10.0f }; 
    v2 StartingMax = StartingMin + V2(TextureWidth, TextureWidth);

    real32 TextureSpacing = 10.0f;
    uint32 TexturesPerRow = ((uint32)RenderCommands->ViewportWidth/((uint32)TextureWidth + (uint32)TextureSpacing));

    if (TextureStorage->TexturePack.NumberOfTextures > 0)
    {
        uint32 SelectedTextureRow = TexturePackerState->SelectedTexture/TexturesPerRow;
        uint32 SelectedTextureColumn = (TexturePackerState->SelectedTexture - SelectedTextureRow);

        real32 SelectedTextureXOffset = TextureWidth*SelectedTextureColumn + TextureSpacing*SelectedTextureColumn - 0.5f*TextureSpacing;
        real32 SelectedTextureYOffset = TextureWidth*SelectedTextureRow + TextureSpacing*SelectedTextureRow - 0.5f*TextureSpacing;

        v2 SelectedTextureMin = StartingMin;
        SelectedTextureMin.X += SelectedTextureXOffset;
        SelectedTextureMin.Y += SelectedTextureYOffset;

        v2 SelectedTextureWidthHeight = V2(TextureWidth + 10, TextureWidth + 10);
        v2 SelectedTextureMax = SelectedTextureMin + SelectedTextureWidthHeight;

        texture_packer_color BorderColor = { .301f, 0.314f, 0.314f, 1.0f };
        DrawRectangle(RenderCommands, SelectedTextureMin, 
                      SelectedTextureMax, BorderColor);
    }

    for (uint32 TextureIndex = 0; TextureIndex < TextureStorage->TexturePack.NumberOfTextures;
         TextureIndex++)
    {
        uint32 RowNumber = TextureIndex/TexturesPerRow;
        uint32 ColumnNumber = (TextureIndex - RowNumber*TexturesPerRow);

        real32 XOffset = TextureWidth*ColumnNumber + TextureSpacing*ColumnNumber;
        real32 YOffset = TextureWidth*RowNumber + TextureSpacing*RowNumber; 

        v2 Min = StartingMin;
        Min.X += XOffset;
        Min.Y += YOffset; 

        v2 Max = StartingMax;
        Max.X += XOffset;
        Max.Y += YOffset; 

        DrawTexturedRectangle(RenderCommands,
                              Min, Max, TextureIndex);
    }
}
