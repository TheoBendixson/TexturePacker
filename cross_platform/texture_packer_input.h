
struct texture_packer_key_state
{
    bool32 EndedDown;
};

struct texture_packer_keyboard_input
{
    union
    {
        texture_packer_key_state Keys[12];
        struct
        {
            texture_packer_key_state A;
            texture_packer_key_state C;
            texture_packer_key_state S;
            texture_packer_key_state F;
            texture_packer_key_state H;
            texture_packer_key_state L;
            texture_packer_key_state LeftArrow;
            texture_packer_key_state RightArrow;
            texture_packer_key_state UpArrow;
            texture_packer_key_state DownArrow;
            texture_packer_key_state F1;
            texture_packer_key_state F2;
        };
    };
};

struct texture_packer_input 
{
    real32 dtForFrame;
    texture_packer_keyboard_input Keyboard;
};
