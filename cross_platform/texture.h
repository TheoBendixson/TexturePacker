
enum texture_file_type
{
    TextureFileTypeNoHeader,
    TextureFileTypeWidthHeight,
    TextureFileTypeUnknown
};

struct texture_file_header
{
    uint32 FileSize;
    uint32 TextureWidth;
    uint32 TextureHeight;
    uint32 PixelBufferOffset;
};

texture_file_type
GetTextureFileTypeFor(char *Filename)
{
    char *Scan = Filename; 

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

    return (FileType);
}

