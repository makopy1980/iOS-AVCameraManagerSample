//
//  ViewController.h
//

#import <UIKit/UIKit.h>
#import "AVCameraManager.h"

@interface ViewController : UIViewController
<
AVCameraManagerDelegate
>

@property (nonatomic, retain) AVCameraManager *cameraManager;
@property (nonatomic, retain) IBOutlet UIImageView *preview;

@end

