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

typedef uint32_t CGConnectionID;

CGDisplayStreamRef _Nullable
SLSHWCaptureStreamCreateWithWindow(CGWindowID wid,
                                   uint32_t /*CGSWindowCaptureOptions*/ options,
                                   CFDictionaryRef properties,
                                   dispatch_queue_t _Nullable queue,
                                   CGDisplayStreamFrameAvailableHandler handler);

CGConnectionID SLSMainConnectionID(void);

CGError CGSGetWindowResolution(CGConnectionID cid, CGWindowID wid,
                                         CGFloat * _Nonnull resolution, CGSize * _Nullable size);

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
    NSLog(@"compCb status: %d infoFlags: 0x%x", (int)status, infoFlags);
    ViewController *self = (__bridge ViewController*)outputCallbackRefCon;
    CVPixelBufferRef pbref = (CVBufferRef)sourceFrameRefCon;
    NSLog(@"origPb pixelBuffer: %@", pbref);
//    AVAssetWriterInput* writerInput = (__bridge AVAssetWriterInput*)outputCallbackRefCon;
//    CVPixelBufferRef pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
//    CMBlockBufferRef blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer);
//    size_t blockBufferLen = CMBlockBufferGetDataLength(blockBuffer);
//    size_t lo = 243;
//    size_t tlo = 244;
//    char *dbo = NULL;
//    OSStatus bbps = CMBlockBufferGetDataPointer(blockBuffer, 0, &lo, &tlo, &dbo);
//    NSLog(@"compPb pixelBuffer: %@", pixelBuffer);
    NSLog(@"compPb sampleBuffer: %@", sampleBuffer);
//    NSLog(@"compPb blockBuffer: sz: %zu bbps: %d lo: %zu tlo: %zu dbo: %p %@", blockBufferLen, (int)bbps, lo, tlo, dbo, blockBuffer);
    [self->writerInput appendSampleBuffer:sampleBuffer];
}


- (IBAction)captureClicked:(id)sender {
    CGError cge;
    NSLog(@"sender: %@", sender);
    for (NSWindow *w in NSApplication.sharedApplication.windows) {
        NSLog(@"window: %@ w: %f h: %f wid: %ld", w, w.frame.size.width, w.frame.size.height, (long)w.windowNumber);
        NSView *v = w.contentView;
        NSLog(@"view: %@ wantsLayer: %d wantsUpdateLayer: %d", v, v.wantsLayer, v.wantsUpdateLayer);
//        v.wantsLayer = YES;
        NSLog(@"view: %@ wantsLayer: %d wantsUpdateLayer: %d", v, v.wantsLayer, v.wantsUpdateLayer);
        CALayer *l = v.layer;
        NSLog(@"layer: %@", l);

        NSLog(@"wild begin");

        NSError *error = nil;
        NSURL *m4v_url = [NSURL fileURLWithPath:@"/tmp/dump.mov"];
        if ([NSFileManager.defaultManager fileExistsAtPath:m4v_url.path]) {
            [NSFileManager.defaultManager removeItemAtPath:m4v_url.path  error:&error];
            assert(!error);
        }
        videoWriter = [[AVAssetWriter alloc] initWithURL:m4v_url fileType:AVFileTypeQuickTimeMovie error:&error];
        NSParameterAssert(videoWriter);

        NSDictionary *videoSettings = @{
            AVVideoCodecKey: AVVideoCodecTypeH264,
            AVVideoWidthKey: @(w.frame.size.width*2),
            AVVideoHeightKey: @(w.frame.size.height*2),
        };
        writerInput = [AVAssetWriterInput
            assetWriterInputWithMediaType:AVMediaTypeVideo
                                           outputSettings:nil];

        NSParameterAssert(writerInput);
        NSParameterAssert([videoWriter canAddInput:writerInput]);
        [videoWriter addInput:writerInput];

        [videoWriter startWriting];
        [videoWriter startSessionAtSourceTime:CMTimeFromMachAbsoluteTime(mach_absolute_time())];

        NSDictionary *encSpec = @{};
        NSDictionary *srcImgAttr = @{};
        OSStatus oss = VTCompressionSessionCreate(NULL, (int32_t)w.frame.size.width*2, (int32_t)w.frame.size.height*2, kCMVideoCodecType_H264, (__bridge CFDictionaryRef _Nullable)(encSpec), (__bridge CFDictionaryRef _Nullable)(srcImgAttr), NULL, compCb, (__bridge void * _Nullable)(self), &csref);
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
        CGFloat resolution;
        CGConnectionID cid = SLSMainConnectionID();
        CGWindowID wid = (CGWindowID)w.windowNumber;
        cge = CGSGetWindowResolution(cid, wid, &resolution, NULL);
        NSLog(@"cge: %d cid: 0x%08x wid: 0x%08x resolution: %f", cge, cid, wid, resolution);
        NSDictionary *dsprops = @{};
//        dispatch_queue_t dsq = dispatch_queue_create("iosurface-theft-dsq", DISPATCH_QUEUE_SERIAL);
//        dispatch_resume(dsq);
        dsref = SLSHWCaptureStreamCreateWithWindow((CGWindowID)w.windowNumber, 0, (__bridge CFDictionaryRef)(dsprops), dispatch_get_main_queue(), ^(CGDisplayStreamFrameStatus status, uint64_t displayTime, IOSurfaceRef  _Nullable frameSurface, CGDisplayStreamUpdateRef  _Nullable updateRef) {
            IOSurface *fs = (__bridge IOSurface*)frameSurface;
            NSLog(@"callback lol surface: %@ w: %ld h: %ld attachments: %@, update: %@", fs, (long)fs.width, (long)fs.height, fs.allAttachments, updateRef);
            NSDictionary *pbAttr = @{};
            CVPixelBufferRef pbref;
            CVReturn pbres = CVPixelBufferCreateWithIOSurface(NULL, frameSurface, (__bridge CFDictionaryRef _Nullable)(pbAttr), &pbref);
            if (pbres) {
                NSLog(@"bad pbres: %d\n", pbres);
                return;
            }
            NSLog(@"pbres: %d pbref: %@", pbres, pbref);
            NSDictionary *frameProps = @{};
            VTEncodeInfoFlags infoFlagsOut;
            OSStatus compFrameStatus = VTCompressionSessionEncodeFrame(self->csref, pbref, CMTimeFromMachAbsoluteTime(displayTime), kCMTimeInvalid, (__bridge CFDictionaryRef)frameProps, pbref, &infoFlagsOut);
            NSLog(@"VTCompressionSessionEncodeFrame: %d flags: 0x%x", compFrameStatus, infoFlagsOut);
            NSImage *img3 = fromIOSurface(frameSurface);
            saveImage_atPath(img3, @"dump3.png");
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
    [videoWriter endSessionAtSourceTime:CMTimeFromMachAbsoluteTime(mach_absolute_time())];
//    [videoWriter endSessionAtSourceTime:…]; //optional can call finishWriting without specifying endTime
    [videoWriter finishWritingWithCompletionHandler:^{
        NSLog(@"finished writing video");
        NSLog(@"videoWriter.status: %ld", (long)self->videoWriter.status);
        NSLog(@"videoWriter.error: %@", self->videoWriter.error);
    }];
    mTimer = nil;
}

- (void)setRepresentedObject:(id)representedObject {
    [super setRepresentedObject:representedObject];

    // Update the view, if already loaded.
}


@end
