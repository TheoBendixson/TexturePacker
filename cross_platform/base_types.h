// Texture Packer Base Types
//
// A collection of custom type definitions we will use throughout the game.
#include <stdint.h> 
#include <stddef.h>

#define ArrayCount(Array) (sizeof(Array) / sizeof((Array)[0]))

#define internal static
#define local_persist static
#define global_variable static

typedef int8_t int8;
typedef int16_t int16;
typedef int32_t int32;
typedef int64_t int64;

typedef uint8_t uint8;
typedef uint16_t uint16;
typedef uint32_t uint32;
typedef uint64_t uint64;

typedef size_t memory_index;

typedef int32_t bool32;

typedef float real32;
typedef double real64;
