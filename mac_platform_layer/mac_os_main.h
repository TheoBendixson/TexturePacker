/*

   Platform Game Texture Packer
   2020 Ted Bendixson
   Mooselutions, LLC

    mac_os_main.h

    A platform layer for the Mac.
*/

const unsigned short AKeyCode = 0x00;
const unsigned short CKeyCode = 0x08;
const unsigned short SKeyCode = 0x01;
const unsigned short FKeyCode = 0x03;
const unsigned short HKeyCode = 0x04;
const unsigned short LKeyCode = 0x25;

const unsigned short LeftArrowKeyCode = 0x7B;
const unsigned short RightArrowKeyCode = 0x7C;
const unsigned short DownArrowKeyCode = 0x7D;
const unsigned short UpArrowKeyCode = 0x7E;
const unsigned short F1KeyCode = 0x7A;
const unsigned short F2KeyCode = 0x78;
const unsigned short F5KeyCode = 0x60;
const unsigned short F6KeyCode = 0x61;
const unsigned short F7KeyCode = 0x62;

#include "../../common/platformer_strings.h"
#include "../../common/mac_platform/mac_file.h"

/*
#define MAC_MAX_FILENAME_SIZE 4096

struct mac_app_path
{
    char Filename[MAC_MAX_FILENAME_SIZE];
    char *OnePastLastAppFileNameSlash;
};

struct mac_state
{
    mac_app_path *Path;

	char ResourcesDirectory[MAC_MAX_FILENAME_SIZE];
	int ResourcesDirectorySize;

};*/
