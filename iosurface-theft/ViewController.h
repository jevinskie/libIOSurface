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
}

@property (weak) IBOutlet NSButton *captureButton;

-(void)screenRecording:(NSURL *)destPath;

@end

