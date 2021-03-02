//
//  ViewController.m
//  iosurface-theft
//
//  Created by Jevin Sweval on 2/26/21.
//

//#import <CoreGraphics/CoreGraphics.h>
#import <AVFoundation/AVFoundation.h>
#include <libkern/OSByteOrder.h>

#import "ViewController.h"
#import "NSView+ImageRepresentation.h"

@interface CALayer (MyCALayer)
@property NSView *NS_view;
@end

extern void hexdump(const void *data, size_t len);

typedef uint32_t CGConnectionID;

const uint8_t nalu_hdr[] = {0, 0, 0, 1};

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

//extern CFStringRef kFigMetadataBaseDataType_PixelDensity;
//extern CFStringRef kFigQuickTimeMetadata_PixelDensityKey_WidthPixels;
//extern CFStringRef kFigQuickTimeMetadata_PixelDensityKey_HeightPixels;
//extern CFStringRef kFigQuickTimeMetadata_PixelDensityKey_WidthPoints;
//extern CFStringRef kFigQuickTimeMetadata_PixelDensityKey_HeightPoints;

// Lie and call them NSStrings.. they're toll free bridged... right? =/
extern const NSString *kFigQuickTimeMetadataKey_PixelDensity;
extern const NSString *kFigMetadataBaseDataType_PixelDensity;
extern const NSString *kFigQuickTimeMetadata_PixelDensityKey_WidthPixels;
extern const NSString *kFigQuickTimeMetadata_PixelDensityKey_HeightPixels;
extern const NSString *kFigQuickTimeMetadata_PixelDensityKey_WidthPoints;
extern const NSString *kFigQuickTimeMetadata_PixelDensityKey_HeightPoints;


@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    NSLog(@"kFigQuickTimeMetadataKey_PixelDensity: %@", kFigQuickTimeMetadataKey_PixelDensity);
    NSLog(@"kFigMetadataBaseDataType_PixelDensity: %@", kFigMetadataBaseDataType_PixelDensity);
    NSLog(@"kFigQuickTimeMetadata_PixelDensityKey_WidthPixels: %@", kFigQuickTimeMetadata_PixelDensityKey_WidthPixels);
    NSLog(@"kFigQuickTimeMetadata_PixelDensityKey_HeightPixels: %@", kFigQuickTimeMetadata_PixelDensityKey_HeightPixels);
    NSLog(@"kFigQuickTimeMetadata_PixelDensityKey_WidthPoints: %@", kFigQuickTimeMetadata_PixelDensityKey_WidthPoints);
    NSLog(@"kFigQuickTimeMetadata_PixelDensityKey_HeightPoints: %@", kFigQuickTimeMetadata_PixelDensityKey_HeightPoints);
    self.dpiMeta = AVMutableMetadataItem.alloc.init;
    NSLog(@"dpiMeta blank: %@", self.dpiMeta);
    self.dpiMeta.keySpace = AVMetadataKeySpaceQuickTimeMetadata;
    self.dpiMeta.key = kFigQuickTimeMetadataKey_PixelDensity;
    self.dpiMeta.dataType = kFigMetadataBaseDataType_PixelDensity;
    NSLog(@"dpiMeta: %@", self.dpiMeta);
}

- (void)viewWillDisappear {
    [super viewWillDisappear];
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
//    NSLog(@"origPb pixelBuffer: %@", pbref);
//    AVAssetWriterInput* writerInput = (__bridge AVAssetWriterInput*)outputCallbackRefCon;
    CVPixelBufferRef pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    CMBlockBufferRef blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer);
    size_t blockBufferLen = CMBlockBufferGetDataLength(blockBuffer);
    size_t lo = 243;
    size_t tlo = 244;
    char *dbo = NULL;
    OSStatus bbps = CMBlockBufferGetDataPointer(blockBuffer, 0, &lo, &tlo, &dbo);
//    NSLog(@"compPb pixelBuffer: %@", pixelBuffer);
    NSLog(@"compPb sampleBuffer: %@", sampleBuffer);
    NSLog(@"compPb blockBuffer: sz: %zu bbps: %d lo: %zu tlo: %zu dbo: %p %@", blockBufferLen, (int)bbps, lo, tlo, dbo, blockBuffer);
    hexdump(dbo, MIN(blockBufferLen, 128));

    CMFormatDescriptionRef fdref = CMSampleBufferGetFormatDescription(sampleBuffer);
//    NSLog(@"fdref: %@", fdref);

    size_t ps_cnt = 0;
    OSStatus psres = CMVideoFormatDescriptionGetH264ParameterSetAtIndex(fdref, 0, NULL, NULL, &ps_cnt, NULL);
    assert(!psres);
    NSLog(@"ps_cnt: %zu psres: %d", ps_cnt, psres);

    for (size_t psi = 0; psi < ps_cnt; ++psi) {
        const uint8_t *psb = NULL;
        size_t psb_sz = 0;
        int psb_nal_hdr_len = 0;
        psres = CMVideoFormatDescriptionGetH264ParameterSetAtIndex(fdref, psi, &psb, &psb_sz, NULL, &psb_nal_hdr_len);
        NSLog(@"psres: %d psi: %zu psb: %p psb_sz: %zu psb_nal_hdr_len: %d", psres, psi, psb, psb_sz, psb_nal_hdr_len);
        assert(!psres);
        assert(psb_nal_hdr_len == 4);
        [self.os write:nalu_hdr maxLength:sizeof(nalu_hdr)];
        [self.os write:psb maxLength:psb_sz];
    }


    const uint8_t *p = (const uint8_t*)dbo;
    const uint8_t *pe = (const uint8_t*)(dbo + blockBufferLen);
    while (p < pe) {
        uint32_t nalu_sz_be;
        memcpy(&nalu_sz_be, p, sizeof(nalu_sz_be));
        uint32_t nalu_sz = OSSwapBigToHostInt(nalu_sz_be);
        NSLog(@"nalu_sz: %u", nalu_sz);
        [self.os write:nalu_hdr maxLength:sizeof(nalu_hdr)];
        [self.os write:p + sizeof(nalu_sz) maxLength:nalu_sz];
        p += sizeof(uint32_t) + nalu_sz;
    }
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
        NSString *h264_path = @"/tmp/dump.h264";
        NSURL *h264_url = [NSURL fileURLWithPath:h264_path];
        if ([NSFileManager.defaultManager fileExistsAtPath:h264_path]) {
            [NSFileManager.defaultManager removeItemAtPath:h264_path error:&error];
            assert(!error);
        }
        self.os = [NSOutputStream outputStreamToFileAtPath:h264_path append:NO];
        [self.os open];

        NSString *m4v_path = @"/tmp/dump.mov";
        NSURL *m4v_url = [NSURL fileURLWithPath:m4v_path];
        if ([NSFileManager.defaultManager fileExistsAtPath:m4v_path]) {
            [NSFileManager.defaultManager removeItemAtPath:m4v_path error:&error];
            assert(!error);
        }
        videoWriter = [[AVAssetWriter alloc] initWithURL:m4v_url fileType:AVFileTypeQuickTimeMovie error:&error];
        NSParameterAssert(videoWriter);

        self->dpiScale = l.contentsScale;
        self->logicalWidth = (int)w.frame.size.width;
        self->logicalHeight = (int)w.frame.size.height;
        self->realWidth = (int)(w.frame.size.width * self->dpiScale);
        self->realHeight = (int)(w.frame.size.height * self->dpiScale);

        self.dpiMeta.value = @{
            kFigQuickTimeMetadata_PixelDensityKey_WidthPixels:  @(self->realWidth),
            kFigQuickTimeMetadata_PixelDensityKey_HeightPixels: @(self->realHeight),
            kFigQuickTimeMetadata_PixelDensityKey_WidthPoints:  @(self->logicalWidth),
            kFigQuickTimeMetadata_PixelDensityKey_HeightPoints: @(self->logicalHeight),
        };
        NSLog(@"dpiMeta: %@", self.dpiMeta);
        videoWriter.metadata = [videoWriter.metadata arrayByAddingObject:self.dpiMeta];

        writerInput = [AVAssetWriterInput
            assetWriterInputWithMediaType:AVMediaTypeVideo
                                           outputSettings:nil];

        NSParameterAssert(writerInput);
        NSParameterAssert([videoWriter canAddInput:writerInput]);
        [videoWriter addInput:writerInput];

        [videoWriter startWriting];

//        [videoWriter startSessionAtSourceTime:CMTimeFromMachAbsoluteTime(mach_absolute_time())];

        CMClockRef hc = CMClockGetHostTimeClock();
        NSLog(@"CMClockGetHostTimeClock() = %@", hc);
        OSStatus tbcs = CMTimebaseCreateWithMasterClock(NULL, hc, &tb);
        assert(!tbcs);
        assert(tb);
        NSLog(@"tb: %@", tb);
        OSStatus tbsrs = CMTimebaseSetRateAndAnchorTime(tb, 1.0, kCMTimeZero, CMClockMakeHostTimeFromSystemUnits(mach_absolute_time()));
        assert(!tbsrs);
        NSLog(@"tb: %@", tb);
//        CMTimebaseSetAnchorTime(tb, kCMTimeZero, CMSyncGetTime(CMTimebaseCopyMaster(tb)));
//        CMTimebaseSetTime(tb, CMClockGetTime(CMClockGetHostTimeClock()));
        CMTime now = CMTimebaseGetTime(tb);
        NSLog(@"now: numer: %lld denom: %d", now.value, now.timescale);
        usleep(1000*100);
        now = CMTimebaseGetTime(tb);
        NSLog(@"now: numer: %lld denom: %d", now.value, now.timescale);
        [videoWriter startSessionAtSourceTime:CMTimebaseGetTime(tb)];

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
            CMTime ht = CMClockMakeHostTimeFromSystemUnits(displayTime);
            CMTime my_time = CMSyncConvertTime(ht, CMClockGetHostTimeClock(), self->tb);
            NSLog(@"my_time numer: %lld denom: %d", my_time.value, my_time.timescale);
            VTEncodeInfoFlags infoFlagsOut;
            OSStatus compFrameStatus = VTCompressionSessionEncodeFrame(self->csref, pbref, my_time, kCMTimeInvalid, (__bridge CFDictionaryRef)frameProps, pbref, &infoFlagsOut);
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
    [videoWriter endSessionAtSourceTime:CMTimeFromMachAbsoluteTime(mach_absolute_time())];
//    [videoWriter endSessionAtSourceTime:…]; //optional can call finishWriting without specifying endTime
    [videoWriter finishWritingWithCompletionHandler:^{
        NSLog(@"finished writing video");
        NSLog(@"videoWriter.status: %ld", (long)self->videoWriter.status);
        NSLog(@"videoWriter.error: %@", self->videoWriter.error);
    }];
    [self.os close];
    mTimer = nil;
}

- (void)setRepresentedObject:(id)representedObject {
    [super setRepresentedObject:representedObject];

    // Update the view, if already loaded.
}


@end
