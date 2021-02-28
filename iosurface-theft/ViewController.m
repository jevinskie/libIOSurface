//
//  ViewController.m
//  iosurface-theft
//
//  Created by Jevin Sweval on 2/26/21.
//

//#import <CoreGraphics/CoreGraphics.h>
#import <AVFoundation/AVFoundation.h>

#import "ViewController.h"
#import "NSView+ImageRepresentation.h"

@interface CALayer (MyCALayer)
@property NSView *NS_view;
@end

CGDisplayStreamRef _Nullable
SLSHWCaptureStreamCreateWithWindow(CGWindowID wid,
                                   uint32_t /*CGSWindowCaptureOptions*/ options,
                                   CFDictionaryRef properties,
                                   dispatch_queue_t _Nullable queue,
                                   CGDisplayStreamFrameAvailableHandler handler);

static const uint32_t kSLSCaptureAllowNonIntersectingWindows = (uint32_t)0x8000;
static const uint32_t kSLSCaptureDisablePromptingValue = (uint32_t)0x10000;
static const uint32_t kSLSCaptureIgnoreTCCPermissionsValue = (uint32_t)0x20000;
static const uint32_t kSLSCaptureExcludeCursorWindow = (uint32_t)0x40000;
static const uint32_t kSLSWorkspaceWindowsDoNotFilterDesktopPictureWindows = (uint32_t)(1UL << 31);

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
//    [self screenRecording:[NSURL URLWithString:@"file:///tmp/dump.m4v"]];
    // Do any additional setup after loading the view.
}

- (void)viewWillDisappear {
    [super viewWillDisappear];
//    [self finishRecord:<#(NSTimer *)#>]
}

-(void)screenRecording:(NSURL *)destPath
{
    // Create a capture session
    mSession = [[AVCaptureSession alloc] init];

    // Set the session preset as you wish
    mSession.sessionPreset = AVCaptureSessionPreset1920x1080;

    // If you're on a multi-display system and you want to capture a secondary display,
    // you can call CGGetActiveDisplayList() to get the list of all active displays.
    // For this example, we just specify the main display.
    // To capture both a main and secondary display at the same time, use two active
    // capture sessions, one for each display. On Mac OS X, AVCaptureMovieFileOutput
    // only supports writing to a single video track.
    CGDirectDisplayID displayId = kCGDirectMainDisplay;

    // Create a ScreenInput with the display and add it to the session
    AVCaptureScreenInput *input = [[AVCaptureScreenInput alloc] initWithDisplayID:displayId];
    if (!input) {
        mSession = nil;
        return;
    }
    if ([mSession canAddInput:input])
        [mSession addInput:input];

    // Create a MovieFileOutput and add it to the session
    mMovieFileOutput = [[AVCaptureMovieFileOutput alloc] init];
    if ([mSession canAddOutput:mMovieFileOutput])
        [mSession addOutput:mMovieFileOutput];

    // Start running the session
    [mSession startRunning];

    // Delete any existing movie file first
    if ([[NSFileManager defaultManager] fileExistsAtPath:[destPath path]])
    {
        NSError *err;
        if (![[NSFileManager defaultManager] removeItemAtPath:[destPath path] error:&err])
        {
            NSLog(@"Error deleting existing movie %@",[err localizedDescription]);
        }
    }

    // Start recording to the destination movie file
    // The destination path is assumed to end with ".mov", for example, @"/users/master/desktop/capture.mov"
    // Set the recording delegate to self
    [mMovieFileOutput startRecordingToOutputFileURL:destPath recordingDelegate:self];

    // Fire a timer in 5 seconds
    mTimer = [NSTimer scheduledTimerWithTimeInterval:5 target:self selector:@selector(finishRecord:) userInfo:nil repeats:NO];
}

-(void)finishRecord:(NSTimer *)timer
{
    // Stop recording to the destination movie file
    [mMovieFileOutput stopRecording];

    mTimer = nil;
}

// AVCaptureFileOutputRecordingDelegate methods

- (void)captureOutput:(AVCaptureFileOutput *)captureOutput didFinishRecordingToOutputFileAtURL:(NSURL *)outputFileURL fromConnections:(NSArray *)connections error:(NSError *)error
{
    NSLog(@"Did finish recording to %@ due to error %@", [outputFileURL description], [error description]);
    CGDisplayStreamStop(dsref);
    [mSession stopRunning];

    OSStatus finStatus = VTCompressionSessionCompleteFrames(csref, kCMTimeInvalid);
    NSLog(@"finStatus: %d", finStatus);
    VTCompressionSessionInvalidate(csref);
    CFRelease(csref);
    // Stop running the session
//    [mSession stopRunning];

    // Release the session
    mSession = nil;
}

CMTime CMTimeFromMachAbsoluteTime(uint64_t t) {
    mach_timebase_info_data_t tb_info;
    mach_timebase_info(&tb_info);
    CMTime res = CMTimeMake(t * tb_info.numer, tb_info.denom);
    return res;
}

NSImage* fromContext (CGContextRef context)
{
    CGImageRef imageRef = CGBitmapContextCreateImage(context);
    NSImage* newImage = [[NSImage alloc] initWithCGImage:imageRef
                                                    size:NSMakeSize(
                                                                    CGBitmapContextGetWidth(context),
                                                                    CGBitmapContextGetHeight(context))];
    return newImage;
}

NSImage* fromIOSurface (IOSurfaceRef surface)
{
    CIImage *ci = [[CIImage alloc] initWithIOSurface:surface];
    CGImageRef img = [CIContext.context createCGImage:ci fromRect:[ci extent]];
    NSImage* newImage = [[NSImage alloc] initWithCGImage:img
                                                    size:ci.extent.size];
    return newImage;
}

void saveImage_atPath(NSImage *image, NSString *path) {
    CGImageRef cgRef = [image CGImageForProposedRect:NULL
                                            context:nil
                                              hints:nil];
    NSBitmapImageRep *newRep = [[NSBitmapImageRep alloc] initWithCGImage:cgRef];
    [newRep setSize:[image size]];   // if you want the same resolution
    NSData *pngData = [newRep representationUsingType:NSBitmapImageFileTypePNG properties:@{}];
    NSString *outPath = [NSString stringWithFormat:@"/tmp/%@", path];
    NSLog(@"outPath: %@", outPath);
    [pngData writeToFile:outPath atomically:YES];
}

void compCb(void *outputCallbackRefCon, void *sourceFrameRefCon, OSStatus status, VTEncodeInfoFlags infoFlags, CMSampleBufferRef sampleBuffer) {
    NSLog(@"compCb");
    AVAssetWriterInput* writerInput = (__bridge AVAssetWriterInput*)outputCallbackRefCon;
    CVPixelBufferRef pixelBuffer = CMSampleBufferGetImageBuffer( sampleBuffer );
    NSLog(@"compPb pixelBuffer: %@", pixelBuffer);
    NSLog(@"compPb sampleBuffer: %@", sampleBuffer);
    [writerInput appendSampleBuffer:sampleBuffer];
}


- (IBAction)captureClicked:(id)sender {
    NSLog(@"sender: %@", sender);
    for (NSWindow *w in NSApplication.sharedApplication.windows) {
        NSLog(@"window: %@ wid: %ld", w, (long)w.windowNumber);
        NSView *v = w.contentView;
        NSLog(@"view: %@ wantsLayer: %d wantsUpdateLayer: %d", v, v.wantsLayer, v.wantsUpdateLayer);
//        v.wantsLayer = YES;
        NSLog(@"view: %@ wantsLayer: %d wantsUpdateLayer: %d", v, v.wantsLayer, v.wantsUpdateLayer);
        CALayer *l = v.layer;
        NSLog(@"layer: %@", l);

        NSLog(@"wild begin");

        NSError *error = nil;
        videoWriter = [[AVAssetWriter alloc] initWithURL:
            [NSURL fileURLWithPath:@"/tmp/dump.m4v"] fileType:AVFileTypeQuickTimeMovie
            error:&error];
        NSParameterAssert(videoWriter);

        NSDictionary *videoSettings = [NSDictionary dictionaryWithObjectsAndKeys:
                                       AVVideoCodecTypeH264, AVVideoCodecKey,
            [NSNumber numberWithInt:v.bounds.size.width], AVVideoWidthKey,
            [NSNumber numberWithInt:v.bounds.size.height], AVVideoHeightKey,
            nil];
        writerInput = [AVAssetWriterInput
            assetWriterInputWithMediaType:AVMediaTypeVideo
                                           outputSettings:videoSettings];

        NSParameterAssert(writerInput);
        NSParameterAssert([videoWriter canAddInput:writerInput]);
        [videoWriter addInput:writerInput];

        [videoWriter startWriting];
        [videoWriter startSessionAtSourceTime:CMTimeFromMachAbsoluteTime(mach_absolute_time())];

        NSDictionary *encSpec = @{};
        NSDictionary *srcImgAttr = @{};
        OSStatus oss = VTCompressionSessionCreate(NULL, v.bounds.size.width, v.bounds.size.height, kCMVideoCodecType_H264, (__bridge CFDictionaryRef _Nullable)(encSpec), (__bridge CFDictionaryRef _Nullable)(srcImgAttr), NULL, compCb, (__bridge void * _Nullable)(writerInput), &csref);
        NSLog(@"VTCompressionSessionCreate: %d", oss);
        NSLog(@"csref: %@", csref);
        VTCompressionSessionPrepareToEncodeFrames(csref);
//        CGDirectDisplayID did = CGMainDisplayID();
//        AVCaptureScreenInput *si = [[AVCaptureScreenInput alloc] initWithDisplayID:did];
//        captureSession = [[AVCaptureSession alloc] init];
//        si = AVCaptureScreenInput.new;
//        [captureSession addInput:si];
//        [captureSession startRunning];
//        NSLog(@"did: 0x%x si: %@", did, si);
        NSDictionary *dsprops = @{};
//        dispatch_queue_t dsq = dispatch_queue_create("iosurface-theft-dsq", DISPATCH_QUEUE_SERIAL);
//        dispatch_resume(dsq);
        dsref = SLSHWCaptureStreamCreateWithWindow((CGWindowID)w.windowNumber, kSLSCaptureDisablePromptingValue | kSLSCaptureIgnoreTCCPermissionsValue, (__bridge CFDictionaryRef)(dsprops), dispatch_get_main_queue(), ^(CGDisplayStreamFrameStatus status, uint64_t displayTime, IOSurfaceRef  _Nullable frameSurface, CGDisplayStreamUpdateRef  _Nullable updateRef) {
            NSLog(@"callback lol surface: %@ update: %@", frameSurface, updateRef);
            NSDictionary *pbAttr = @{};
            CVPixelBufferRef pbref;
            CVReturn pbres = CVPixelBufferCreateWithIOSurface(NULL, frameSurface, (__bridge CFDictionaryRef _Nullable)(pbAttr), &pbref);
            if (pbres) {
                return;
            }
            NSLog(@"pbres: %d pbref: %@", pbres, pbref);
            NSDictionary *frameProps = @{};
            VTEncodeInfoFlags infoFlagsOut;
            OSStatus compFrameStatus = VTCompressionSessionEncodeFrame(self->csref, pbref, CMTimeFromMachAbsoluteTime(displayTime), kCMTimeInvalid, (__bridge CFDictionaryRef)frameProps, NULL, &infoFlagsOut);
            NSLog(@"VTCompressionSessionEncodeFrame: %d flags: 0x%x", compFrameStatus, infoFlagsOut);
//            NSImage *img3 = fromIOSurface(frameSurface);
//            saveImage_atPath(img3, @"dump3.png");
        });
        CGDisplayStreamStart(dsref);
        NSLog(@"dsref: %@", dsref);
        mTimer = [NSTimer scheduledTimerWithTimeInterval:5 target:self selector:@selector(finishRecord2:) userInfo:nil repeats:NO];
        NSLog(@"wild end");
    }
}

-(void)finishRecord2:(NSTimer *)timer
{
    NSLog(@"finishRecord2");
    // Stop recording to the destination movie file
    CGDisplayStreamStop(dsref);

    OSStatus finStatus = VTCompressionSessionCompleteFrames(csref, kCMTimeInvalid);
    NSLog(@"finStatus: %d", finStatus);
    VTCompressionSessionInvalidate(csref);
    CFRelease(csref);
    [writerInput markAsFinished];
//    [videoWriter endSessionAtSourceTime:…]; //optional can call finishWriting without specifying endTime
    [videoWriter finishWritingWithCompletionHandler:^{
        NSLog(@"finished writing video");
    }];
    mTimer = nil;
}

- (void)setRepresentedObject:(id)representedObject {
    [super setRepresentedObject:representedObject];

    // Update the view, if already loaded.
}


@end
