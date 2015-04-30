//
//  AVCameraManager.m
//

#import "AVCameraManager.h"

@implementation AVCameraManager

#pragma mark - Initializer

- (id)init {
    
    self = [super init];
    
    if (self) {
        [self setupAVCaptureWithPreset:AVCaptureSessionPreset640x480];
    }
    
    return self;
}

- (id)initWithPreset:(NSString *)preset {
    
    self = [super init];
    
    if (self) {
        [self setupAVCaptureWithPreset:preset];
    }
    
    return self;
}

#pragma mark - Setting Up

- (void)setUpPreviewlayer:(UIView *)view {
    
    [_previewLayer setFrame:[view bounds]];
    [[view layer] addSublayer:_previewLayer];
}

- (void)setupAVCaptureWithPreset:(NSString *)preset {
    
    [self setBackCameraDevice:nil];
    [self setFrontCameraDevice:nil];

    NSArray *cameras = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    
    for (AVCaptureDevice *camera in cameras) {
        
        AVCaptureDevicePosition pos = [camera position];
        
        switch (pos) {
            case AVCaptureDevicePositionBack:
                [self setBackCameraDevice:camera];
                break;
            case AVCaptureDevicePositionFront:
                [self setFrontCameraDevice:camera];
            default:
                break;
        }
    }
    
    // Default->BackCamera
    _videoInput = [AVCaptureDeviceInput deviceInputWithDevice:[self backCameraDevice]
                                                        error:nil];
    
    // Format
    AVCaptureDevice *device = [_videoInput device];
    [self setDefaultFormat:[device activeFormat]];
    _defaultVideoMaxFrameDuration = [device activeVideoMaxFrameDuration];
    
    // Create Capture Session
    _captureSession = [[AVCaptureSession alloc] init];
    [_captureSession setSessionPreset:preset];
    [_captureSession addInput:_videoInput];
    
    // Output
    _fileOutput = [[AVCaptureMovieFileOutput alloc] init];
    [_captureSession addOutput:_fileOutput];
    
    // Preview
  	_previewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:_captureSession];
	[_previewLayer setBackgroundColor:[[UIColor blackColor] CGColor]];
    [_previewLayer setVideoGravity:AVLayerVideoGravityResizeAspect];
    
    // Others
    [self setupImageCapture];
    [self setupVideoCapture];
    
    [_captureSession startRunning];
}

- (BOOL)setupImageCapture {
    
    _imageOutput = [AVCaptureStillImageOutput new];
    
    if(_imageOutput){
        if([_captureSession canAddOutput:_imageOutput]){
            [_captureSession addOutput:_imageOutput];
            return YES;
        }
    }
    
    return NO;
}

- (BOOL)setupVideoCapture {

    _videoOutput = [AVCaptureVideoDataOutput new];
	[_videoOutput setVideoSettings:@{(id)kCVPixelBufferPixelFormatTypeKey: @(kCMPixelFormat_32BGRA)}];
    [_videoOutput setAlwaysDiscardsLateVideoFrames:YES];
  	_videoOutputQueue = dispatch_queue_create("VideoOutputQueue", DISPATCH_QUEUE_SERIAL);
	[_videoOutput setSampleBufferDelegate:self
                                    queue:_videoOutputQueue];
    
	if (_videoOutput) {
        if ([_captureSession canAddOutput:_videoOutput]) {
            [_captureSession addOutput:_videoOutput];
            return YES;
        }
    }
    
    return NO;
}

- (BOOL)setupAudioCapture {
    
    _audioOutput = [AVCaptureAudioDataOutput new];
    
    _audioOutputQueue = dispatch_queue_create("AudioCaptureQueue", DISPATCH_QUEUE_SERIAL);
	[_audioOutput setSampleBufferDelegate:self
                                    queue:_audioOutputQueue];
    
    if (_audioOutput) {
        if ([_captureSession canAddOutput:_audioOutput]) {
            [_captureSession addOutput:_audioOutput];
            return YES;
        }
    }
    
    return NO;
}

#pragma mark - Camera Control

- (void)enableFrontCamera:(BOOL)useFront {
    
    if (useFront == YES) {
        [self enableCamera:AVCaptureDevicePositionFront];
    } else {
        [self enableCamera:AVCaptureDevicePositionBack];
    }
}

// カメラ切り替え
- (void)switchCamera {
    
    if(self.isUsingFrontCamera) {
        [self enableFrontCamera:NO];
    } else {
        [self enableFrontCamera:YES];
    }
}

// カメラ有効化
- (void)enableCamera:(AVCaptureDevicePosition)pos {
    
    [_captureSession stopRunning];
    
    NSArray *devices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    
    for (AVCaptureDevice *device in devices) {
        if ([device position] == pos) {
            [_captureSession beginConfiguration];
            _videoInput= [AVCaptureDeviceInput deviceInputWithDevice:device
                                                               error:nil];
            
            NSArray *inputs = [[_previewLayer session] inputs];
            for (AVCaptureInput *input in inputs) {
                [_captureSession removeInput:input];
            }
            
            [_captureSession addInput:_videoInput];
            [_captureSession commitConfiguration];
            
            break;
        }
    }
    
    
    [_captureSession startRunning];
}

- (BOOL)isUsingFrontCamera {
    
    AVCaptureDevicePosition pos = [[_videoInput device] position];
    
    if(pos == AVCaptureDevicePositionFront) {
        return YES;
    } else {
        return NO;
    }
}

#pragma mark - Flash Control

- (void)enableFlash:(BOOL)useFlash {
    
    if(![_backCameraDevice hasTorch]) {
        return;
    }
    
    if(self.isUsingFrontCamera) {
        [self enableFrontCamera:NO];
    }
    
    NSError* error;
    [_backCameraDevice lockForConfiguration:&error];
    
    if (useFlash) {
        [_backCameraDevice setTorchMode:AVCaptureTorchModeOn];
    } else {
        [_backCameraDevice setTorchMode:AVCaptureTorchModeOff];
    }
    
    [_backCameraDevice unlockForConfiguration];
}

- (void)switchFlash {
    
    if ([self isFlashOn]) {
        [self enableFlash:NO];
    } else {
        [self enableFlash:YES];
    }
}

- (BOOL)isFlashOn {
    
    if(![_backCameraDevice hasTorch]) {
        return NO;
    }
    
    if([_backCameraDevice isTorchActive]) {
        return YES;
    } else {
        return NO;
    }
}

#pragma mark - Focus Control

- (void)autoFocusWithPoint:(CGPoint)point {
    
    AVCaptureDevice *device = [_videoInput device];
    
    if ([device isFocusPointOfInterestSupported]
        && [device isFocusModeSupported:AVCaptureFocusModeAutoFocus]) {
        NSError *error;
        if ([device lockForConfiguration:&error]) {
            [device setFocusPointOfInterest:point];
            [device setFocusMode:AVCaptureFocusModeAutoFocus];
            [device unlockForConfiguration];
        }
    }
}

- (void)consecutiveFocusWithPoint:(CGPoint)point {
    
    AVCaptureDevice *device = [_videoInput device];
    
    if ([device isFocusPointOfInterestSupported]
        && [device isFocusModeSupported:AVCaptureFocusModeContinuousAutoFocus]) {
		NSError *error;
		if ([device lockForConfiguration:&error]) {
			[device setFocusPointOfInterest:point];
			[device setFocusMode:AVCaptureFocusModeContinuousAutoFocus];
			[device unlockForConfiguration];
		}
	}
}

#pragma mark - Capture

- (void)takePicture:(takePictureHandler)handler {
    
    AVCaptureConnection* connection = [_imageOutput connectionWithMediaType:AVMediaTypeVideo];
    
    // Picture Orientation
    if ([connection isVideoOrientationSupported]) {
        AVCaptureVideoOrientation orientation = (AVCaptureVideoOrientation)[[UIDevice currentDevice] orientation];
        [connection setVideoOrientation:orientation];
    }
    
    [_imageOutput captureStillImageAsynchronouslyFromConnection:connection
                                              completionHandler:^(CMSampleBufferRef imageDataSampleBuffer, NSError *error) {
                                                 
                                                 if (imageDataSampleBuffer == nil){
                                                     if (handler) {
                                                         handler(nil,error);
                                                     }
                                                     return;
                                                 }
                                                 
                                                 NSData *data = [AVCaptureStillImageOutput jpegStillImageNSDataRepresentation:imageDataSampleBuffer];
                                                 UIImage *image = [UIImage imageWithData:data];
                                                 
                                                 if (handler) {
                                                     handler(image,error);
                                                 }
                                             }];
}

- (void)startRecording {
    
    NSDateFormatter* formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"yyyy-MM-dd-HH-mm-ss"];
    NSString* dateTimePrefix = [formatter stringFromDate:[NSDate date]];
    
    int fileNameSuffixNum = 0;
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    NSString *filePath = nil;
    
    do {
        filePath =[NSString stringWithFormat:@"/%@/%@-%i.mp4",
                   documentsDirectory, dateTimePrefix, fileNameSuffixNum++];
    } while ([[NSFileManager defaultManager] fileExistsAtPath:filePath]);
    
    NSURL *fileURL = [NSURL URLWithString:[@"file://" stringByAppendingString:filePath]];
    
    [_fileOutput startRecordingToOutputFileURL:fileURL
                             recordingDelegate:self];
}

- (void)stopRecording {
    
    [_fileOutput stopRecording];
}

#pragma mark - Utilities

- (NSUInteger)cameraCount {
    
    NSArray *cameras = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    
    return [cameras count];
}

- (NSUInteger)micCount {
    
    NSArray *mics = [AVCaptureDevice devicesWithMediaType:AVMediaTypeAudio];
    
    return [mics count];
}

- (AVCaptureDevice *)cameraWithPosition:(AVCaptureDevicePosition)pos {
    
    NSArray *devices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    
    for (AVCaptureDevice *device in devices) {
        if ([device position] == pos) {
            return device;
        }
    }
    
    return nil;
}

- (AVCaptureDevice *)frontCamera {
    
    return [self cameraWithPosition:AVCaptureDevicePositionFront];
}

- (AVCaptureDevice *)backCamera {
    
    return [self cameraWithPosition:AVCaptureDevicePositionBack];
}

- (AVCaptureDevice *)audioDevice {
    
    NSArray *devices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeAudio];
    
    if ([devices count] > 0) {
        return [devices objectAtIndex:0];
    }
    
    return nil;
}

+ (CGImageRef)imageFromSampleBuffer:(CMSampleBufferRef) sampleBuffer {
    
    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    CVPixelBufferLockBaseAddress(imageBuffer,0);
    
    uint8_t *baseAddress = (uint8_t *)CVPixelBufferGetBaseAddressOfPlane(imageBuffer, 0);
    size_t bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer);
    size_t width = CVPixelBufferGetWidth(imageBuffer);
    size_t height = CVPixelBufferGetHeight(imageBuffer);
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    
    CGContextRef newContext = CGBitmapContextCreate(baseAddress, width, height, 8, bytesPerRow, colorSpace, kCGBitmapByteOrder32Little | kCGImageAlphaPremultipliedFirst);
    CGImageRef newImage = CGBitmapContextCreateImage(newContext);
    CGContextRelease(newContext);
    
    CGColorSpaceRelease(colorSpace);
    CVPixelBufferUnlockBaseAddress(imageBuffer,0);
    
    return newImage;
}

+ (UIImage *)rotateImage:(UIImage*)image angle:(int)angle {
    
    UIImage *retImage;
    
    CGImageRef imageRef = [image CGImage];
    CGContextRef context;
    
    switch (angle) {
        case 90:
            UIGraphicsBeginImageContextWithOptions(CGSizeMake(image.size.height, image.size.width), YES, image.scale);
            context = UIGraphicsGetCurrentContext();
            CGContextTranslateCTM(context, image.size.height, image.size.width);
            CGContextScaleCTM(context, 1, -1);
            CGContextRotateCTM(context, M_PI_2);
            break;
        case 180:
            UIGraphicsBeginImageContextWithOptions(CGSizeMake(image.size.width, image.size.height), YES, image.scale);
            context = UIGraphicsGetCurrentContext();
            CGContextTranslateCTM(context, image.size.width, 0);
            CGContextScaleCTM(context, 1, -1);
            CGContextRotateCTM(context, -M_PI);
            break;
        case 270:
            UIGraphicsBeginImageContextWithOptions(CGSizeMake(image.size.height, image.size.width), YES, image.scale);
            context = UIGraphicsGetCurrentContext();
            CGContextScaleCTM(context, 1, -1);
            CGContextRotateCTM(context, -M_PI_2);
            break;
        default:
            return image;
            break;
    }
    
    CGContextDrawImage(context, CGRectMake(0, 0, image.size.width, image.size.height), imageRef);
    retImage = UIGraphicsGetImageFromCurrentImageContext();
    
    UIGraphicsEndImageContext();
    
    return retImage;
}

#pragma mark - AVCaptureVideoDataOutputSampleBufferDelegate

- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection {
    
    @autoreleasepool {
        CGImageRef cgImage = [AVCameraManager imageFromSampleBuffer:sampleBuffer];
        UIImage* captureImage = [UIImage imageWithCGImage:cgImage];
        CGImageRelease(cgImage);
        
        dispatch_async(dispatch_get_main_queue(), ^(void) {
            
            [self setVideoImage:captureImage];
            UIDeviceOrientation orientation = [[UIDevice currentDevice] orientation];
            [self setVideoOrientaion:orientation];
        });
    } // @autoreleasepool
}

#pragma mark - AVCaptureFileOutputRecordingDelegate

- (void) captureOutput:(AVCaptureFileOutput *)captureOutput didStartRecordingToOutputFileAtURL:(NSURL *)fileURL fromConnections:(NSArray *)connections {
    
    _isRecording = YES;
}

- (void) captureOutput:(AVCaptureFileOutput *)captureOutput didFinishRecordingToOutputFileAtURL:(NSURL *)outputFileURL fromConnections:(NSArray *)connections error:(NSError *)error {
    
    _isRecording = NO;
    
    if ([self.delegate respondsToSelector:@selector(didFinishRecordingToOutputFileAtURL:error:)]) {
        [self.delegate didFinishRecordingToOutputFileAtURL:outputFileURL error:error];
    }
}

@end
