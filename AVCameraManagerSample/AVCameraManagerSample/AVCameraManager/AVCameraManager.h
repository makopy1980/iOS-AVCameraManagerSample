//
//  AVCameraManager.h
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <MediaPlayer/MediaPlayer.h>
#import <CoreMedia/CMBufferQueue.h>

@class AVCameraManager;

@protocol AVCameraManagerDelegate <NSObject>

@optional
-(void)didFinishRecordingToOutputFileAtURL:(NSURL *)outputFileURL error:(NSError *)error;
//@optional
//-(void)videoFrameUpdate:(CGImageRef)cgImage from:(CameraManager*)manager;
@end

//////////////////////////////////////////////////
@interface AVCameraManager : NSObject
<
AVCaptureFileOutputRecordingDelegate,
AVCaptureAudioDataOutputSampleBufferDelegate,
AVCaptureVideoDataOutputSampleBufferDelegate
>
{
    CMTime                          _defaultVideoMaxFrameDuration;
    AVCaptureSession*               _captureSession;
    AVCaptureDeviceInput*           _videoInput;             //  現在のビデオ入力デバイス
    AVCaptureStillImageOutput*      _imageOutput;            //  静止画出力デバイス
    AVCaptureAudioDataOutput*       _audioOutput;            //  オーディオ出力デバイス
    AVCaptureVideoDataOutput*       _videoOutput;            //  ビデオ出力デバイス
    dispatch_queue_t                _videoOutputQueue;       //  ビデオ出力用スレッド
    dispatch_queue_t                _audioOutputQueue;       //  オーディオ出力用スレッド
}

typedef void (^takePictureHandler)(UIImage *image, NSError *error);

@property(nonatomic, assign) id <AVCameraManagerDelegate> delegate;
@property (nonatomic, readonly) BOOL isRecording;

@property AVCaptureVideoPreviewLayer* previewLayer;
@property AVCaptureDevice*            backCameraDevice;
@property AVCaptureDevice*            frontCameraDevice;
@property UIImage*                    videoImage;
@property UIDeviceOrientation         videoOrientaion;

@property AVCaptureMovieFileOutput*   fileOutput;
@property AVCaptureDeviceFormat*      defaultFormat;

- (id)init;
- (id)initWithPreset:(NSString*)preset;
- (void)setUpPreviewlayer:(UIView*)view;
- (void)setupAVCaptureWithPreset:(NSString*)preset;
- (BOOL)setupImageCapture;
- (BOOL)setupVideoCapture;
- (BOOL)setupAudioCapture;
#pragma mark - Camera Control
- (void)enableFrontCamera:(BOOL)useFront;
- (void)switchCamera;
- (BOOL)isUsingFrontCamera;
#pragma mark - Flash Control
-(void)enableFlash:(BOOL)useFlash;
-(void)switchFlash;
-(BOOL)isFlashOn;
#pragma mark - Focus Control
-(void)autoFocusWithPoint:(CGPoint)point;
-(void)consecutiveFocusWithPoint:(CGPoint)point;
#pragma mark - Capture
-(void)takePicture:(takePictureHandler)handler;
-(void)startRecording;
-(void)stopRecording;
#pragma mark - Utilities
-(NSUInteger) cameraCount;
-(NSUInteger) micCount;
-(AVCaptureDevice *)cameraWithPosition:(AVCaptureDevicePosition)pos;
-(AVCaptureDevice *)frontCamera;
-(AVCaptureDevice *)backCamera;
-(AVCaptureDevice *)audioDevice;
+ (CGImageRef)imageFromSampleBuffer:(CMSampleBufferRef) sampleBuffer;
+ (UIImage*)rotateImage:(UIImage*)image angle:(int)angle;
/*
- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection;
- (void)captureOutput:(AVCaptureFileOutput *)captureOutput didStartRecordingToOutputFileAtURL:(NSURL *)fileURL fromConnections:(NSArray *)connections;
- (void)captureOutput:(AVCaptureFileOutput *)captureOutput didFinishRecordingToOutputFileAtURL:(NSURL *)outputFileURL fromConnections:(NSArray *)connections error:(NSError *)error;
*/
@end
