/*
    mac_os_main.mm
    Platformer Texture Packer Mac Platform Layer

    2020 TedBendixson Mooselutions, LLC
    All Rights Reserved 
*/

#import <AppKit/AppKit.h>
#import <QuartzCore/QuartzCore.h>
#import <QuartzCore/CoreAnimation.h>
#import <IOKit/hid/IOHIDLib.h>
#import <Metal/Metal.h>
#import <MetalKit/MetalKit.h>
#include <mach/mach_init.h>
#include <mach/mach_time.h>
#include <dlfcn.h>
#include <mach-o/dyld.h>
#include <sys/stat.h>

#include "../cross_platform/base_types.h"
#include "../cross_platform/texture_packer.cpp"

#include "mac_os_main.h"

global_variable MTKView *MetalKitView;

void CatStrings(size_t SourceACount, char *SourceA,
                size_t SourceBCount, char *SourceB,
                size_t DestCount, char *Dest)
{
    // TODO: Dest bounds checking!
    for(int Index = 0;
        Index < SourceACount;
        ++Index)
    {
        *Dest++ = *SourceA++;
    }

    for(int Index = 0;
        Index < SourceBCount;
        ++Index)
    {
        *Dest++ = *SourceB++;
    }

    *Dest++ = 0;
}

internal int
StringLength(char *String)
{
    int Count = 0;
    while(*String++)
    {
        ++Count;
    }
    return(Count);
}

void
MacBuildAppFilePath(mac_app_path *Path)
{
	uint32 buffsize = sizeof(Path->Filename);
    if (_NSGetExecutablePath(Path->Filename, &buffsize) == 0) {
		for(char *Scan = Path->Filename;
			*Scan;
			++Scan)
		{
			if(*Scan == '/')
			{
				Path->OnePastLastAppFileNameSlash = Scan + 1;
			}
		}
    }
}

void
MacBuildAppPathFileName(mac_app_path *Path, char *Filename, int DestCount, char *Dest)
{
	CatStrings(Path->OnePastLastAppFileNameSlash - Path->Filename, Path->Filename,
			   StringLength(Filename), Filename,
			   DestCount, Dest);
}

void PlatformFreeFileMemory(void *Memory)
{
    if (Memory) {
        free(Memory);
    }
}

// NOTE: (Ted)  For some reason, this is the only way to load a level from a file
//              dialog without any data corruption. I think this is because it bypasses
//              some sort of finder entitlements nonsense.
internal
read_file_result MacReadEntireFileFromDialog(char *Filename)
{
    read_file_result Result = {};

    FILE *FileHandle = fopen(Filename, "r+");

    if(FileHandle != NULL)
    {
		fseek(FileHandle, 0, SEEK_END);
		uint64 FileSize = ftell(FileHandle);
        if(FileSize)
        {
        	rewind(FileHandle);
            Result.Contents = malloc(FileSize);

            if(Result.Contents)
            {
                uint64 BytesRead = fread(Result.Contents, 1, FileSize, FileHandle);
                if(FileSize == BytesRead)
                {
                    Result.ContentsSize = FileSize;
                    Result.Filename = (char *)malloc(200*sizeof(char));

                    char *Dest = Result.Filename;
                    char *Scan = Filename;

                    while (*Scan != '\0')
                    {
                        *Dest++ = *Scan++;
                    }

                    *Dest++ = '\0';
                }
                else
                {                    
                    NSLog(@"File loaded size mismatch. FileSize: %llu, BytesRead: %llu",
                          FileSize, BytesRead);
                    PlatformFreeFileMemory(Result.Contents);
                    PlatformFreeFileMemory(Result.Filename);
                    Result.Contents = 0;
                }
            }
            else
            {
                NSLog(@"Missing Result Contents Pointer from file load.");
            }
        }
        else
        {
            NSLog(@"Missing File Size from file load");
        }

        fclose(FileHandle);
    }
    else
    {
        NSLog(@"Unable to acquire File handle");
    }

    return (Result);
}

internal
char * ConvertAbsoluteURLToFileURL(NSURL *FileURL)
{
    NSMutableString *FilePath = [[FileURL absoluteString] mutableCopy];
    [FilePath replaceOccurrencesOfString: @"file://" 
                              withString: @""
                                 options: NSCaseInsensitiveSearch
                                   range: NSMakeRange(0,7)]; 
    char *LocalFilename = (char *)[FilePath cStringUsingEncoding: NSUTF8StringEncoding];
    [FilePath release];
    return (LocalFilename);

}

read_file_result PlatformOpenFileDialog()
{
    read_file_result Result = {};

    @autoreleasepool
    {
        NSOpenPanel *OpenPanel = [[[NSOpenPanel alloc] init] autorelease];
        OpenPanel.canChooseFiles = true;
        OpenPanel.canChooseDirectories = true;
        OpenPanel.allowsMultipleSelection = false;

        if ([OpenPanel runModal] == NSModalResponseOK)
        {
            NSURL *FileURL = [[OpenPanel URLs] objectAtIndex: 0];
            char *LocalFilename = ConvertAbsoluteURLToFileURL(FileURL);
            Result = MacReadEntireFileFromDialog(LocalFilename);
        }
    }

    return (Result);
}

read_file_result PlatformReadEntireFile(char *Filename)
{
    read_file_result Result = {};
    Result.Filename = Filename;

    mac_app_path Path = {};
    MacBuildAppFilePath(&Path);

    char SandboxFilename[MAC_MAX_FILENAME_SIZE];
    char LocalFilename[MAC_MAX_FILENAME_SIZE];
    sprintf(LocalFilename, "Contents/Resources/%s", Filename);
    MacBuildAppPathFileName(&Path, LocalFilename,
                            sizeof(SandboxFilename), SandboxFilename);

    FILE *FileHandle = fopen(SandboxFilename, "r+");

    if(FileHandle != NULL)
    {
		fseek(FileHandle, 0, SEEK_END);
		uint64 FileSize = ftell(FileHandle);
        if(FileSize)
        {
        	rewind(FileHandle);
        	Result.Contents = malloc(FileSize);
            if(Result.Contents)
            {
                uint64 BytesRead = fread(Result.Contents, 1, FileSize, FileHandle);
                if(FileSize == BytesRead)
                {
                    Result.ContentsSize = FileSize;
                }
                else
                {                    
                    // TODO: Logging
                    PlatformFreeFileMemory(Result.Contents);
                    Result.Contents = 0;
                }
            }
            else
            {
                // TODO: Logging
            }
        }
        else
        {
            // TODO: Logging
        }

        fclose(FileHandle);
    }
    else
    {
        // TODO: Logging
    }

    return(Result);
}

@interface TexturePackerSavePanelDelegate: NSObject<NSOpenSavePanelDelegate>
@end

@implementation TexturePackerSavePanelDelegate 

- (BOOL)panel:(id)sender shouldEnableURL:(NSURL *)url {
    return true;
}

@end

bool32 PlatformWriteEntireFile(uint64 FileSize, void *Memory)
{
    bool32 Result = false;

    @autoreleasepool
    {
        NSSavePanel *SavePanel = [[[NSSavePanel alloc] init] autorelease];
        TexturePackerSavePanelDelegate *SavePanelDelegate = [[[TexturePackerSavePanelDelegate alloc] init] 
                                                               autorelease];
        [SavePanel setDelegate: SavePanelDelegate];
        SavePanel.title = @"Save Game Texture";
        SavePanel.prompt = @"Save";
        SavePanel.canCreateDirectories = true;

        if ([SavePanel runModal] == NSModalResponseOK)
        {
            NSMutableString * FilePath = [[SavePanel.URL absoluteString] mutableCopy];
            [FilePath replaceOccurrencesOfString: @"file://" 
                                      withString:@""
                                         options: NSCaseInsensitiveSearch
                                           range: NSMakeRange(0,7)]; 

            char *LocalFilename = (char *)[FilePath cStringUsingEncoding: NSUTF8StringEncoding];

            FILE *FileHandle = fopen(LocalFilename, "w");

            if(FileHandle)
            {
                size_t BytesWritten = fwrite(Memory, 1, FileSize, FileHandle);
                if(BytesWritten)
                {
                    Result = (BytesWritten == FileSize);
                }
                else
                {
                    // TODO: Logging
                }

                fclose(FileHandle);
            }
            else
            {
                // TODO: Logging
            }

        } else
        {
            Result = false;
        }

    }

    return(Result);
}

@interface MainWindowDelegate: NSObject<NSWindowDelegate>
@end

@implementation MainWindowDelegate 

- (void)windowWillClose:(id)sender 
{
    [NSApp performSelector: @selector(terminate:) withObject: nil afterDelay: 0.0];
}

@end

@interface TexturePackerWindow: NSWindow

-(void) setKeyboardInputPtr:(texture_packer_keyboard_input *)KeyboardInputPtr;

@end

@implementation TexturePackerWindow
{
    texture_packer_keyboard_input *_KeyboardInputPtr;
}

-(void) setKeyboardInputPtr: (texture_packer_keyboard_input *)KeyboardInputPtr
{
    _KeyboardInputPtr = KeyboardInputPtr;
}

- (void)keyDown:(NSEvent *)theEvent 
{ 
    if (theEvent.keyCode == AKeyCode)
    {
        _KeyboardInputPtr->A.EndedDown = true;
    } else if (theEvent.keyCode == DKeyCode)
    {
        _KeyboardInputPtr->D.EndedDown = true;
    } else if (theEvent.keyCode == F1KeyCode)
    {
        _KeyboardInputPtr->F1.EndedDown = true;
    } else if (theEvent.keyCode == F2KeyCode)
    {
        _KeyboardInputPtr->F2.EndedDown = true;
    } else if (theEvent.keyCode == HKeyCode)
    {
        _KeyboardInputPtr->H.EndedDown = true;
    } else if (theEvent.keyCode == LKeyCode)
    {
        _KeyboardInputPtr->L.EndedDown = true;
    }
}

- (void)keyUp:(NSEvent *)theEvent
{
    if (theEvent.keyCode == AKeyCode)
    {
        _KeyboardInputPtr->A.EndedDown = false;
    } else if (theEvent.keyCode == DKeyCode)
    {
        _KeyboardInputPtr->D.EndedDown = false;
    } else if (theEvent.keyCode == F1KeyCode)
    {
        _KeyboardInputPtr->F1.EndedDown = false;
    } else if (theEvent.keyCode == F2KeyCode)
    {
        _KeyboardInputPtr->F2.EndedDown = false;
    } else if (theEvent.keyCode == HKeyCode)
    {
        _KeyboardInputPtr->H.EndedDown = false;
    } else if (theEvent.keyCode == LKeyCode)
    {
        _KeyboardInputPtr->L.EndedDown = false;
    }
}

@end

@interface MetalViewDelegate: NSObject<MTKViewDelegate>

@property texture_packer_render_commands RenderCommands;
@property texture_packer_memory TexturePackerMemory;
@property texture_packer_state TexturePackerState;

@property (retain) id<MTLRenderPipelineState> ColorPipelineState;
@property (retain) id<MTLRenderPipelineState> TexturePipelineState;
@property (retain) id<MTLCommandQueue> CommandQueue;
@property (retain) NSMutableArray* ColorVertexBuffers;
@property (retain) NSMutableArray* TextureVertexBuffers;
@property (retain) NSMutableArray* BitmapTextures;

- (void)configureMetal;
- (void) setInputPtr: (texture_packer_input *)InputPtr;
- (void) setMacStatePtr: (mac_state *)MacStatePtr;

@end

static const NSUInteger kMaxInflightBuffers = 3;

@implementation MetalViewDelegate
{
    texture_packer_input *_InputPtr;
    mac_state *_MacStatePtr;

    dispatch_semaphore_t _frameBoundarySemaphore;
    NSUInteger _currentFrameIndex;
}

- (void)configureMetal
{
    _frameBoundarySemaphore = dispatch_semaphore_create(kMaxInflightBuffers);
    _currentFrameIndex = 0;
}

-(void) setInputPtr: (texture_packer_input *)InputPtr
{
    _InputPtr = InputPtr;
}

- (void) setMacStatePtr: (mac_state *)MacStatePtr
{
    _MacStatePtr = MacStatePtr;
}

- (void)drawInMTKView:(MTKView *)view 
{
    dispatch_semaphore_wait(_frameBoundarySemaphore, DISPATCH_TIME_FOREVER);

    _currentFrameIndex = (_currentFrameIndex + 1) % kMaxInflightBuffers;

    texture_packer_render_commands *RenderCommandsPtr = &_RenderCommands;
    RenderCommandsPtr->FrameIndex = (uint32)_currentFrameIndex;

    _InputPtr->dtForFrame = 1.0f/60.0f;
  
    color_vertex_command_buffer ColorCommandBuffer = RenderCommandsPtr->ColorVertexCommandBuffers[RenderCommandsPtr->FrameIndex];
    ColorCommandBuffer.NumberOfColorVertices = 0;
    RenderCommandsPtr->ColorVertexCommandBuffers[RenderCommandsPtr->FrameIndex] = ColorCommandBuffer;

    texture_vertex_command_buffer TextureCommandBuffer = RenderCommandsPtr->TextureVertexCommandBuffers[RenderCommandsPtr->FrameIndex];
    TextureCommandBuffer.NumberOfTextureVertices = 0;
    RenderCommandsPtr->TextureVertexCommandBuffers[RenderCommandsPtr->FrameIndex] = TextureCommandBuffer;

    texture_packer_memory *TexturePackerMemoryPtr = &_TexturePackerMemory;

    UpdateAndRender(TexturePackerMemoryPtr, _InputPtr, RenderCommandsPtr);

    _InputPtr->Keyboard.A.EndedDown = false;
    _InputPtr->Keyboard.F1.EndedDown = false;
    _InputPtr->Keyboard.F2.EndedDown = false;

    NSUInteger Width = (NSUInteger)RenderCommandsPtr->ViewportWidth*2;
    NSUInteger Height = (NSUInteger)RenderCommandsPtr->ViewportHeight*2;
    MTLViewport Viewport = (MTLViewport){0.0, 0.0, (real64)Width, (real64)Height, -1.0, 1.0 };

    @autoreleasepool {

        texture_packer_state *TexturePackerStatePtr = (texture_packer_state *)TexturePackerMemoryPtr->PermanentStorage;

        id<MTLCommandBuffer> CommandBuffer = [[self CommandQueue] commandBuffer];
        MTLRenderPassDescriptor *RenderPassDescriptor = [view currentRenderPassDescriptor];
        vector_uint2 ViewportSize = { (uint32)RenderCommandsPtr->ViewportWidth, 
                                      (uint32)RenderCommandsPtr->ViewportHeight };

        ColorCommandBuffer = RenderCommandsPtr->ColorVertexCommandBuffers[RenderCommandsPtr->FrameIndex];
        NSUInteger NumberOfColorVertices = (NSUInteger)ColorCommandBuffer.NumberOfColorVertices;

        id<MTLRenderCommandEncoder> RenderEncoder = [CommandBuffer renderCommandEncoderWithDescriptor:RenderPassDescriptor];

        [RenderEncoder setViewport: Viewport];

        [RenderEncoder setRenderPipelineState: [self ColorPipelineState]];

        [RenderEncoder setVertexBuffer: [[self ColorVertexBuffers] objectAtIndex: _currentFrameIndex]
                                offset: 0
                               atIndex: 0];

        [RenderEncoder setVertexBytes: &ViewportSize
                               length: sizeof(ViewportSize)
                              atIndex: 1];

        [RenderEncoder drawPrimitives: MTLPrimitiveTypeTriangle
                          vertexStart: 0
                          vertexCount: NumberOfColorVertices];

        if (RenderCommandsPtr->UniqueTextureCount > 0)
        {
            for (uint32 TextureIndex = 0; TextureIndex < [self BitmapTextures].count; TextureIndex++)
            {
                [RenderEncoder setFragmentTexture: [[self BitmapTextures] objectAtIndex: TextureIndex]
                                          atIndex: TextureIndex];
            }

            [RenderEncoder setRenderPipelineState: [self TexturePipelineState]];
            TextureCommandBuffer = RenderCommandsPtr->TextureVertexCommandBuffers[RenderCommandsPtr->FrameIndex];
            NSUInteger NumberOfTextureVertices = (NSUInteger)TextureCommandBuffer.NumberOfTextureVertices;
            

            [RenderEncoder setVertexBuffer: [[self TextureVertexBuffers] objectAtIndex: _currentFrameIndex]
                                    offset: 0
                                   atIndex: 0];

            [RenderEncoder drawPrimitives: MTLPrimitiveTypeTriangle
                              vertexStart: 0
                              vertexCount: NumberOfTextureVertices];
        }

        [RenderEncoder endEncoding];

        // Schedule a present once the framebuffer is complete using the current drawable
        id<CAMetalDrawable> NextDrawable = [view currentDrawable];
        [CommandBuffer presentDrawable: NextDrawable];

        __block dispatch_semaphore_t semaphore = _frameBoundarySemaphore;
        [CommandBuffer addCompletedHandler:^(id<MTLCommandBuffer> commandBuffer) {
            dispatch_semaphore_signal(semaphore);
        }];

        [CommandBuffer commit];
    }
}

- (void)mtkView:(MTKView *)view drawableSizeWillChange:(CGSize)size
{

}

@end

global_variable MetalViewDelegate *ViewDelegate;
void PlatformClearAllTextures()
{
    NSMutableArray *BitmapTextures = [[NSMutableArray alloc] init];
    [ViewDelegate setBitmapTextures: BitmapTextures];
}

void PlatformAddTexture(texture *Texture)
{
    MTLTextureDescriptor *TextureDescriptor = [[MTLTextureDescriptor alloc] init];
    TextureDescriptor.pixelFormat = MTLPixelFormatBGRA8Unorm;
    TextureDescriptor.usage = MTLTextureUsageShaderRead;

    NSUInteger TextureWidth = (NSUInteger)Texture->Width;
    NSUInteger BytesPerRow = TextureWidth*sizeof(uint32);
    NSUInteger TextureHeight = (NSUInteger)Texture->Height;

    MTLRegion MetalRegion = {
        { 0, 0, 0 },
        { TextureWidth, TextureHeight, 1 }
    };

    TextureDescriptor.width = TextureWidth;
    TextureDescriptor.height = TextureHeight;

    id<MTLTexture> BitmapTexture = [[MetalKitView.device newTextureWithDescriptor: TextureDescriptor] autorelease];

    [BitmapTexture replaceRegion: MetalRegion
                     mipmapLevel: 0
                       withBytes: (void *)Texture->Data 
                     bytesPerRow: BytesPerRow];

    if (ViewDelegate.BitmapTextures == nil)
    {
        NSMutableArray *BitmapTextures = [[NSMutableArray alloc] init];
        [BitmapTextures addObject: BitmapTexture];
        [ViewDelegate setBitmapTextures: BitmapTextures];
    } else
    {
        [ViewDelegate.BitmapTextures addObject: BitmapTexture];
    }
}

void PlatformReplaceTextureAtIndex(texture *Texture, uint32 TextureIndex)
{
    NSUInteger TextureWidth = (NSUInteger)Texture->Width;
    NSUInteger BytesPerRow = TextureWidth*sizeof(uint32);
    NSUInteger TextureHeight = (NSUInteger)Texture->Height;

    MTLRegion MetalRegion = {
        { 0, 0, 0 },
        { TextureWidth, TextureHeight, 1 }
    };

    id<MTLTexture> BitmapTexture = [ViewDelegate.BitmapTextures objectAtIndex: TextureIndex];

    [BitmapTexture replaceRegion: MetalRegion
                     mipmapLevel: 0
                       withBytes: (void *)Texture->Data 
                     bytesPerRow: BytesPerRow];
}

void PlatformRemoveTexturesFromIndexToEnd(uint32 NumberOfTexturesToRemove)
{
    for (uint32 TexturesRemoved = 0;
         TexturesRemoved < NumberOfTexturesToRemove;
         TexturesRemoved++)
     {
        [ViewDelegate.BitmapTextures removeLastObject];
     }
}

internal void
SetupAlphaBlendForRenderPipelineColorAttachment(MTLRenderPipelineColorAttachmentDescriptor *ColorRenderBufferAttachment)
{
    ColorRenderBufferAttachment.blendingEnabled = YES;
    ColorRenderBufferAttachment.rgbBlendOperation = MTLBlendOperationAdd;
    ColorRenderBufferAttachment.alphaBlendOperation = MTLBlendOperationAdd;
    ColorRenderBufferAttachment.sourceRGBBlendFactor = MTLBlendFactorSourceAlpha;
    ColorRenderBufferAttachment.sourceAlphaBlendFactor = MTLBlendFactorSourceAlpha;
    ColorRenderBufferAttachment.destinationRGBBlendFactor = MTLBlendFactorOneMinusSourceAlpha;
    ColorRenderBufferAttachment.destinationAlphaBlendFactor = MTLBlendFactorOneMinusSourceAlpha;
}


int main(int argc, const char * argv[]) 
{
    MainWindowDelegate *WindowDelegate = [[MainWindowDelegate alloc] init];

    NSRect ScreenRect = [[NSScreen mainScreen] frame];

#if LAPTOP
    float GlobalRenderWidth = 750;
    float GlobalRenderHeight = 750;
#else
    float GlobalRenderWidth = 1024;
    float GlobalRenderHeight = 1024;
#endif

    NSRect InitialFrame = NSMakeRect((ScreenRect.size.width - GlobalRenderWidth) * 0.5,
                                     (ScreenRect.size.height - GlobalRenderHeight) * 0.5,
                                     GlobalRenderWidth, GlobalRenderHeight);
  
    TexturePackerWindow *Window = [[TexturePackerWindow alloc] 
                                        initWithContentRect: InitialFrame
                                                  styleMask: NSWindowStyleMaskTitled |
                                                             NSWindowStyleMaskClosable
                                                    backing: NSBackingStoreBuffered
                                                      defer: NO];    

    [Window setBackgroundColor: NSColor.blackColor];
    [Window setTitle: @"Texture Packer"];

    [Window makeKeyAndOrderFront: nil];
    [Window setDelegate: WindowDelegate];
    Window.contentView.layerContentsPlacement = NSViewLayerContentsPlacementCenter;
    Window.contentView.layer.contentsGravity = kCAGravityCenter;
    Window.contentView.wantsLayer = YES;

    MetalKitView = [[MTKView alloc] init];
    MetalKitView.frame = CGRectMake(0, 0, 
                                    GlobalRenderWidth, GlobalRenderHeight); 

    MetalKitView.device = MTLCreateSystemDefaultDevice(); 
    MetalKitView.framebufferOnly = false;
    MetalKitView.layer.contentsGravity = kCAGravityCenter;
    MetalKitView.preferredFramesPerSecond = 60;

    [Window setContentView: MetalKitView];

    ViewDelegate = [[MetalViewDelegate alloc] init];

    // TODO: (Ted)  Create some notion of a maximum texture count here.
    texture_packer_render_commands RenderCommands = {}; 
    RenderCommands.ViewportWidth = (int)GlobalRenderWidth;
    RenderCommands.ViewportHeight = (int)GlobalRenderHeight;
    RenderCommands.UniqueTextureCount = 0;

    // TODO: (Ted)  Create some notion of a maximum texture count here.
    texture_packer_texture_buffer TextureBuffer = {};
    TextureBuffer.NumberOfTextures = RenderCommands.UniqueTextureCount;
    TextureBuffer.TexturesLoaded = 0;

    uint32 PageSize = getpagesize();
    uint32 ColorVertexBufferSize = PageSize*1000;
    uint32 TextureVertexBufferSize = PageSize*1000;

    NSMutableArray *ColorVertexBuffers = [[NSMutableArray alloc] init];
    NSMutableArray *TextureVertexBuffers = [[NSMutableArray alloc] init];

    for(uint32 FrameIndex = 0; FrameIndex < 3; FrameIndex++)
    {
        color_vertex_command_buffer ColorVertexCommandBuffer = {};
        ColorVertexCommandBuffer.NumberOfColorVertices = 0;

        ColorVertexCommandBuffer.ColorVertices = (texture_packer_color_vertex *) mmap(0, ColorVertexBufferSize,
                                                                                      PROT_READ | PROT_WRITE,
                                                                                      MAP_PRIVATE | MAP_ANON, -1, 0);

        RenderCommands.ColorVertexCommandBuffers[FrameIndex] = ColorVertexCommandBuffer;

        id<MTLBuffer> ColorVertexBuffer = [MetalKitView.device newBufferWithBytesNoCopy: ColorVertexCommandBuffer.ColorVertices
                                                                                 length: ColorVertexBufferSize
                                                                                options: MTLResourceStorageModeShared
                                                                            deallocator: nil];

        [ColorVertexBuffers addObject: ColorVertexBuffer];

        texture_vertex_command_buffer TextureVertexCommandBuffer = {};
        TextureVertexCommandBuffer.NumberOfTextureVertices = 0;

        TextureVertexCommandBuffer.TextureVertices = (texture_packer_texture_vertex *) mmap(0, TextureVertexBufferSize,
                                                                                            PROT_READ | PROT_WRITE,
                                                                                            MAP_PRIVATE | MAP_ANON, -1, 0);

        RenderCommands.TextureVertexCommandBuffers[FrameIndex] = TextureVertexCommandBuffer;

        id<MTLBuffer> TextureVertexBuffer = [MetalKitView.device newBufferWithBytesNoCopy: TextureVertexCommandBuffer.TextureVertices
                                                                                   length: TextureVertexBufferSize
                                                                                  options: MTLResourceStorageModeShared
                                                                              deallocator: nil];

        [TextureVertexBuffers addObject: TextureVertexBuffer]; 
    }

    ViewDelegate.RenderCommands = RenderCommands; 

    NSString *LibraryFile = [[NSBundle mainBundle] pathForResource: @"ColorShaders" ofType: @"metallib"];
    id<MTLLibrary> ShaderLibrary = [MetalKitView.device newLibraryWithFile: LibraryFile error: nil];
    id<MTLFunction> VertexFunction = [ShaderLibrary newFunctionWithName:@"vertexShader"];
    id<MTLFunction> FragmentFunction = [ShaderLibrary newFunctionWithName:@"fragmentShader"];

    MTLRenderPipelineDescriptor *ColorPipelineStateDescriptor = [[MTLRenderPipelineDescriptor alloc] init];
    ColorPipelineStateDescriptor.label = @"Texture Packer Color Vertices";
    ColorPipelineStateDescriptor.vertexFunction = VertexFunction;
    ColorPipelineStateDescriptor.fragmentFunction = FragmentFunction;
    MTLRenderPipelineColorAttachmentDescriptor *ColorRenderBufferAttachment = ColorPipelineStateDescriptor.colorAttachments[0];
    ColorRenderBufferAttachment.pixelFormat = MetalKitView.colorPixelFormat;
    SetupAlphaBlendForRenderPipelineColorAttachment(ColorRenderBufferAttachment);

    NSError *error = NULL;
    id<MTLRenderPipelineState> ColorPipelineState  = [MetalKitView.device 
                                                        newRenderPipelineStateWithDescriptor:ColorPipelineStateDescriptor
                                                                                       error:&error];

    NSString *TextureShaderLibraryFile = [[NSBundle mainBundle] pathForResource: @"TextureShader" ofType: @"metallib"];
    id<MTLLibrary> TextureShaderLibrary = [MetalKitView.device newLibraryWithFile: TextureShaderLibraryFile error: nil];
    id<MTLFunction> TextureShaderVertexFunction = [TextureShaderLibrary newFunctionWithName:@"vertexShader"];
    id<MTLFunction> TextureShaderFragmentFunction = [TextureShaderLibrary newFunctionWithName:@"fragmentShader"];

    MTLRenderPipelineDescriptor *TexturePipelineDescriptor = [[MTLRenderPipelineDescriptor alloc] init];
    TexturePipelineDescriptor.label = @"Texture Packer Texture Vertices";
    TexturePipelineDescriptor.vertexFunction = TextureShaderVertexFunction;
    TexturePipelineDescriptor.fragmentFunction = TextureShaderFragmentFunction; 
    MTLRenderPipelineColorAttachmentDescriptor *TextureRenderBufferAttachment = TexturePipelineDescriptor.colorAttachments[0];
    TextureRenderBufferAttachment.pixelFormat = MetalKitView.colorPixelFormat;
    SetupAlphaBlendForRenderPipelineColorAttachment(TextureRenderBufferAttachment);

    id<MTLRenderPipelineState> TexturePipelineState = [MetalKitView.device 
                                                        newRenderPipelineStateWithDescriptor: TexturePipelineDescriptor
                                                                                       error: &error];

    // TODO: (Ted)  Should probably fatal error here.
    if (error != nil)
    {
        NSLog(@"Error creating texture pipeline");
        [NSException raise: @"Texture Pipeline Not Created"
                     format: @"Failed to create texture rendering pipeline"];
    }

    id<MTLCommandQueue> CommandQueue = [MetalKitView.device newCommandQueue]; 

    mac_state MacState = {};
    mac_app_path Path = {};
    MacState.Path = &Path;
    MacBuildAppFilePath(MacState.Path);

    [ViewDelegate setMacStatePtr: &MacState];

    texture_packer_input Input = {};
    texture_packer_keyboard_input KeyboardInput = {};
    Input.Keyboard = KeyboardInput;

    [Window setKeyboardInputPtr: &Input.Keyboard];
    [ViewDelegate setInputPtr: &Input];

    texture_packer_memory TexturePackerMemory = {};
    TexturePackerMemory.PermanentStorageSize = Megabytes(64);

    void* BaseAddress = 0;
    uint32 AllocationFlags = MAP_PRIVATE | MAP_ANON;

    TexturePackerMemory.PermanentStorage = mmap(BaseAddress,
                                                TexturePackerMemory.PermanentStorageSize,
                                                PROT_READ | PROT_WRITE,
                                                AllocationFlags, -1, 0); 

    if (TexturePackerMemory.PermanentStorage == MAP_FAILED) 
    {
		printf("mmap error: %d  %s", errno, strerror(errno));
        [NSException raise: @"Permanent Memory Not Allocated"
                     format: @"Failed to allocate permanent storage"];
    }

    TexturePackerMemory.TemporaryStorageSize = Megabytes(64);
    TexturePackerMemory.TemporaryStorage = mmap(BaseAddress,
                                                TexturePackerMemory.TemporaryStorageSize,
                                                PROT_READ | PROT_WRITE,
                                                AllocationFlags, -1, 0); 

    if (TexturePackerMemory.TemporaryStorage == MAP_FAILED) 
    {
		printf("mmap error: %d  %s", errno, strerror(errno));
        [NSException raise: @"Temporary Memory Not Allocated"
                     format: @"Failed to allocate temporary storage"];
    }

    ViewDelegate.TexturePackerMemory = TexturePackerMemory; 
    ViewDelegate.CommandQueue = CommandQueue;
    ViewDelegate.ColorPipelineState = ColorPipelineState;
    ViewDelegate.TexturePipelineState = TexturePipelineState;
    ViewDelegate.ColorVertexBuffers = ColorVertexBuffers;
    ViewDelegate.TextureVertexBuffers = TextureVertexBuffers;
    [ViewDelegate configureMetal];

    [MetalKitView setDelegate: ViewDelegate];

    return NSApplicationMain(argc, argv);
}
