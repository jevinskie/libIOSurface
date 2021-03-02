//
//  ViewController.h
//  iosurface-theft
//
//  Created by Jevin Sweval on 2/26/21.
//

#import <Cocoa/Cocoa.h>
#import <VideoToolbox/VideoToolbox.h>

@interface ViewController : NSViewController {
    AVCaptureSession *mSession;
    AVCaptureMovieFileOutput *mMovieFileOutput;
    NSTimer *mTimer;
    CGDisplayStreamRef dsref;
    AVCaptureSession *captureSession;
    AVCaptureScreenInput *si;
    VTCompressionSessionRef csref;
    AVAssetWriter *videoWriter;
    AVAssetWriterInput* writerInput;
    CMTimebaseRef tb;
    int realWidth;
    int realHeight;
    int logicalWidth;
    int logicalHeight;
    CGFloat dpiScale;
}

@property (weak) IBOutlet NSButton *captureButton;
@property AVMutableMetadataItem *dpiMeta;
@property NSOutputStream *os;

@end

